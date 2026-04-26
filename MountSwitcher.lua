-- MountSwitcher.lua
-- WOTLK 3.3.5a Compatible
--
-- SECURE TEMPLATE ARCHITECTURE:
--   The core challenge: casting spells (druid forms, paladin/warlock summons) requires
--   a SecureActionButtonTemplate. Clicking it *programmatically* from tainted Lua is
--   blocked in combat. The solution is to make the player's actual keybind/click land
--   directly on the secure button — never route through a tainted OnClick handler.
--
--   Layout:
--     [Options Frame]  — regular (non-secure) frame for UI/config
--     [secureButton]   — SecureActionButtonTemplate, VISIBLE, positioned wherever you
--                        want the clickable mount button to live. The player binds a key
--                        to it or clicks it directly. Attributes are updated outside of
--                        combat via zone/event hooks.
--     [Slash /ms]      — non-combat helper; in-combat it warns the player instead of
--                        trying to cast (avoids taint).

-- ============================================================
-- SAVED VARIABLES  (declared in .toc: ## SavedVariables: MountSwitcherDB)
-- ============================================================
MountSwitcherDB = MountSwitcherDB or {}

-- ============================================================
-- CONSTANTS
-- ============================================================
local ADDON_NAME = "MountSwitcher"
local IsDebug    = false

-- Druid forms that replace mounts (spellID → data)
-- Travel Form is treated as a ground mount; both flight forms count as flying.
local DRUID_FORM_LIST = {
    {
        spellID    = 783,
        name       = "Travel Form",
        icon       = "Interface\\Icons\\Ability_Druid_TravelForm",
        isFlying   = false,
        isDruidForm = true,
    },
    {
        spellID    = 33943,
        name       = "Flight Form",
        icon       = "Interface\\Icons\\Ability_Druid_FlightForm",
        isFlying   = true,
        isDruidForm = true,
    },
    {
        spellID    = 40120,
        name       = "Swift Flight Form",
        icon       = "Interface\\Icons\\Ability_Druid_FlightForm",
        isFlying   = true,
        isDruidForm = true,
    },
}

-- ============================================================
-- UTILITY
-- ============================================================
local function Debug(...)
    if IsDebug then
        print("|cff00ccff[MS]|r", ...)
    end
end

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Returns true if the player can use flying mounts right now.
-- Dalaran is a no-fly zone except for Krasus' Landing (subzone).
local function CanFlyHere()
    if not IsFlyableArea() then return false end
    -- Dalaran city itself is no-fly; Krasus' Landing subzone is the pad.
    if GetZoneText() == "Dalaran" and GetSubZoneText() ~= "Krasus' Landing" then
        return false
    end
    return true
end

-- ============================================================
-- MOUNT DATABASE  (populated at login / on COMPANION_LEARNED)
-- ============================================================
-- Key: spellID (number)
-- Value: { name, spellID, icon, isFlying, isDruidForm, companionIndex|nil }
local OwnedMounts = {}

local function RebuildMountDatabase()
    wipe(OwnedMounts)

    -- Regular mounts via companion API
    local total = GetNumCompanions("MOUNT") or 0
    for i = 1, total do
        local _, creatureName, creatureSpellID, icon, _, mountTypeID = GetCompanionInfo("MOUNT", i)
        if creatureSpellID then
            -- mountTypeID bitmask in 3.3.5:
            --   bit 0+1 == 0 → water mount
            --   bit 0+1 == 1 → ground mount
            --   bit 0+1 == 3 → flying mount
            local isFlying = mountTypeID and (bit.band(mountTypeID, 3) == 3) or false
            OwnedMounts[creatureSpellID] = {
                name           = creatureName,
                spellID        = creatureSpellID,
                icon           = icon,
                isFlying       = isFlying,
                isDruidForm    = false,
                companionIndex = i,
            }
            Debug("Mount found:", creatureName, isFlying and "(flying)" or "(ground)", "idx=", i)
        end
    end

    -- Druid forms (only if player is a Druid)
    if PlayerClass() == "DRUID" then
        for _, form in ipairs(DRUID_FORM_LIST) do
            if IsSpellKnown(form.spellID) then
                OwnedMounts[form.spellID] = {
                    name           = form.name,
                    spellID        = form.spellID,
                    icon           = form.icon,
                    isFlying       = form.isFlying,
                    isDruidForm    = true,
                    companionIndex = nil,
                }
                Debug("Druid form found:", form.name)
            end
        end
    end

    -- Persist a copy in SavedVariables so we can cross-reference spellIDs on reload.
    -- We do NOT persist the whole table (it rebuilds from the API); we only need the
    -- selected spellIDs, which are already stored separately.
    MountSwitcherDB.OwnedMounts = OwnedMounts
end

-- ============================================================
-- SECURE BUTTON  — the ONLY thing that casts spells
-- ============================================================
-- This button must remain visible (even 1×1 px) and must NEVER be touched by
-- tainted code while in combat.  All attribute writes happen through
-- UpdateSecureButton(), which guards with InCombatLockdown().
--
-- For class mounts (Paladin Charger, Warlock Dreadsteed) and Druid forms the
-- type is "spell". For regular mounts (items/companions) the type is "macro"
-- using /stopmacro so we can fall back to CallCompanion outside secure context,
-- OR we use type="spell" with the companion's spell name.
--
-- In 3.3.5a the cleanest approach for regular mounts is type="spell" + the
-- mount's spell name (same as /cast MountName). This works for all mount
-- categories without needing CallCompanion at all.

local secureButton = CreateFrame("Button", "MountSwitcherSecureButton", UIParent,
                                  "SecureActionButtonTemplate")
secureButton:SetSize(32, 32)
secureButton:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
secureButton:SetNormalTexture("Interface\\Icons\\Ability_Mount_MountedHorse")
secureButton:RegisterForClicks("LeftButtonDown")

-- Visual feedback texture (updated when attributes change)
local function SetSecureButtonIcon(icon)
    if icon then
        secureButton:SetNormalTexture(icon)
    end
end

-- Core logic: decide which mount to use and stamp the secure button attributes.
-- MUST only be called when NOT in combat.
local function UpdateSecureButton()
    if InCombatLockdown() then
        Debug("UpdateSecureButton: skipped, in combat")
        return
    end

    local flySpellID    = MountSwitcherDB.FlyingMountSpellID
    local groundSpellID = MountSwitcherDB.GroundMountSpellID

    if not flySpellID and not groundSpellID then
        Debug("UpdateSecureButton: no mounts configured")
        secureButton:SetAttribute("type", "macro")
        secureButton:SetAttribute("macrotext", "/run DEFAULT_CHAT_FRAME:AddMessage('MountSwitcher: No mounts configured. Use /ms options')")
        return
    end

    local targetSpellID = CanFlyHere() and (flySpellID or groundSpellID) or (groundSpellID or flySpellID)
    local mountData     = OwnedMounts[targetSpellID]

    if not mountData then
        Debug("UpdateSecureButton: spellID", targetSpellID, "not found in OwnedMounts")
        return
    end

    -- Both druid forms AND regular mount spells are cast with type="spell".
    -- GetSpellInfo returns the localised spell name which /cast expects.
    local spellName = GetSpellInfo(mountData.spellID)
    if not spellName then
        Debug("UpdateSecureButton: GetSpellInfo returned nil for spellID", mountData.spellID)
        return
    end

    secureButton:SetAttribute("type",  "spell")
    secureButton:SetAttribute("spell", spellName)
    SetSecureButtonIcon(mountData.icon)

    Debug("SecureButton set →", spellName, "|", CanFlyHere() and "FLY" or "GROUND")
end

-- ============================================================
-- EVENT HANDLER FRAME  (non-secure, handles events only)
-- ============================================================
local eventFrame = CreateFrame("Frame", "MountSwitcherEventFrame")

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- left combat → re-evaluate zone
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:RegisterEvent("COMPANION_UNLEARNED")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RebuildMountDatabase()
        UpdateSecureButton()

    elseif event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" then
        RebuildMountDatabase()
        UpdateSecureButton()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
        or event == "PLAYER_REGEN_ENABLED" then
        -- Zone changed or left combat: re-stamp attributes for new flyable state.
        -- RebuildMountDatabase is NOT needed here (companions didn't change).
        UpdateSecureButton()
    end
end)

-- ============================================================
-- OPTIONS UI  (non-secure frame — never touches secureButton in combat)
-- ============================================================
local optionsFrame = CreateFrame("Frame", "MountSwitcherOptionsFrame", UIParent)
optionsFrame:SetSize(280, 240)
optionsFrame:SetPoint("CENTER")
optionsFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    insets   = { left = 8, right = 8, top = 8, bottom = 8 },
})
optionsFrame:SetMovable(true)
optionsFrame:EnableMouse(true)
optionsFrame:RegisterForDrag("LeftButton")
optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
optionsFrame:SetScript("OnDragStop",  optionsFrame.StopMovingOrSizing)
optionsFrame:SetScript("OnHide",      optionsFrame.StopMovingOrSizing)
optionsFrame:Hide()

-- Close button
local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
closeBtn:SetSize(32, 32)
closeBtn:SetPoint("TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

-- Title
local titleText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetText("MountSwitcher")
titleText:SetPoint("TOPLEFT", 15, -10)

-- ── Flying mount dropdown ──────────────────────────────────
local flyLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyLabel:SetText("Flying Mount / Form:")
flyLabel:SetPoint("TOPLEFT", 30, -45)

local flyDropdown = CreateFrame("Frame", "MSSFlyDropdown", optionsFrame, "UIDropDownMenuTemplate")
flyDropdown:SetPoint("TOPLEFT", flyLabel, "BOTTOMLEFT", -20, -2)
UIDropDownMenu_SetWidth(flyDropdown, 190)

-- ── Ground mount dropdown ──────────────────────────────────
local groundLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundLabel:SetText("Ground Mount / Form:")
groundLabel:SetPoint("TOPLEFT", 30, -115)

local groundDropdown = CreateFrame("Frame", "MSSGroundDropdown", optionsFrame, "UIDropDownMenuTemplate")
groundDropdown:SetPoint("TOPLEFT", groundLabel, "BOTTOMLEFT", -20, -2)
UIDropDownMenu_SetWidth(groundDropdown, 190)

-- Pending selections (committed on Save)
local pendingFlySpellID    = nil
local pendingGroundSpellID = nil

-- Builds and assigns the initializer function for a dropdown.
-- filterFn(mountData) → true if this mount should appear in the list.
local function InitDropdown(dropdown, filterFn, onSelect)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for spellID, mountData in pairs(OwnedMounts) do
            if filterFn(mountData) then
                local info  = UIDropDownMenu_CreateInfo()
                info.text   = mountData.name .. (mountData.isDruidForm and " (Druid)" or "")
                info.value  = spellID
                info.icon   = mountData.icon
                info.func   = function(btn)
                    UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
                    UIDropDownMenu_SetText(dropdown, btn:GetText())
                    onSelect(btn.value)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
end

local function PopulateDropdowns()
    InitDropdown(flyDropdown,
        function(m) return m.isFlying end,
        function(v) pendingFlySpellID = v end
    )
    InitDropdown(groundDropdown,
        function(m) return not m.isFlying end,
        function(v) pendingGroundSpellID = v end
    )

    -- Restore previously saved selections into the dropdown text/value
    local flyID    = MountSwitcherDB.FlyingMountSpellID
    local groundID = MountSwitcherDB.GroundMountSpellID

    if flyID and OwnedMounts[flyID] then
        UIDropDownMenu_SetSelectedValue(flyDropdown, flyID)
        UIDropDownMenu_SetText(flyDropdown, OwnedMounts[flyID].name)
        pendingFlySpellID = flyID
    end
    if groundID and OwnedMounts[groundID] then
        UIDropDownMenu_SetSelectedValue(groundDropdown, groundID)
        UIDropDownMenu_SetText(groundDropdown, OwnedMounts[groundID].name)
        pendingGroundSpellID = groundID
    end
end

-- ── Save button ────────────────────────────────────────────
local saveBtn = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
saveBtn:SetText("Save")
saveBtn:SetSize(100, 28)
saveBtn:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 18)
saveBtn:SetScript("OnClick", function()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r Cannot save during combat.")
        return
    end

    MountSwitcherDB.FlyingMountSpellID  = pendingFlySpellID    or MountSwitcherDB.FlyingMountSpellID
    MountSwitcherDB.GroundMountSpellID  = pendingGroundSpellID or MountSwitcherDB.GroundMountSpellID

    UpdateSecureButton()

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[MountSwitcher]|r Mounts saved!")
    Debug("Saved fly=", MountSwitcherDB.FlyingMountSpellID,
          "ground=", MountSwitcherDB.GroundMountSpellID)
end)

-- Show the options frame and refresh dropdowns each time it opens
local originalShow = optionsFrame.Show
optionsFrame.Show = function(self)
    PopulateDropdowns()
    originalShow(self)
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_MountSwitcher1 = "/ms"
SlashCmdList["MountSwitcher"] = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "mount" then
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r In combat — click the mount button directly.")
            return
        end
        -- Outside combat: update then programmatically click the secure button.
        -- This is safe because we are not in combat (no lockdown).
        UpdateSecureButton()
        secureButton:Click()

    elseif msg == "options" then
        if optionsFrame:IsShown() then
            optionsFrame:Hide()
        else
            optionsFrame:Show()
        end

    elseif msg == "debug" then
        IsDebug = not IsDebug
        print("|cff00ccff[MountSwitcher]|r Debug:", IsDebug and "ON" or "OFF")
        if IsDebug then
            RebuildMountDatabase()
            UpdateSecureButton()
        end

    elseif msg == "reload" then
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r Cannot reload during combat.")
            return
        end
        RebuildMountDatabase()
        PopulateDropdowns()
        UpdateSecureButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Mount list reloaded.")

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms mount   — Summon selected mount (out of combat)")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms options — Toggle options panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms reload  — Refresh mount list")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms debug   — Toggle debug output")
        DEFAULT_CHAT_FRAME:AddMessage("Tip: Bind a key to 'MountSwitcherSecureButton' for in-combat use.")
    end
end