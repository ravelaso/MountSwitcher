-- MountSwitcher.lua
-- WOTLK 3.3.5a Compatible
--
-- SECURE BUTTON / ACTION BAR INTEGRATION
-- ───────────────────────────────────────
-- The secureButton (SecureActionButtonTemplate) is wrapped in a plain
-- draggable "bar" frame.  The bar can be freely repositioned; its position
-- is saved across sessions.  The secure button fills the bar slot and is
-- registered in the WoW Key Bindings UI under the category "MountSwitcher"
-- so the player can bind any key to it exactly like an action bar button.
--
-- Dragging works in the same way Bartender4 / Dominos expose their bars:
--   • Right-click the button → context menu (lock / unlock drag, open options)
--   • While unlocked a gold border appears and the bar is draggable
--   • Locking snaps it in place; the border disappears
--
-- The secure button itself is NEVER touched by tainted code while in combat.
-- All attribute writes happen through UpdateSecureButton(), which is always
-- guarded by InCombatLockdown().

-- ============================================================
-- SAVED VARIABLES  (## SavedVariables: MountSwitcherDB in .toc)
-- ============================================================
MountSwitcherDB = MountSwitcherDB or {}

-- ============================================================
-- CONSTANTS
-- ============================================================
local ADDON_NAME   = "MountSwitcher"
local BUTTON_SIZE  = 36   -- pixels, matches standard action bar slot size
local IsDebug      = false

-- ============================================================
-- CLASS-SPECIFIC MOUNT SPELLS
-- ============================================================
-- These are learned as spells (not companion mounts) and need to be
-- injected into OwnedMounts manually, exactly like Druid forms.
-- isFlying drives which slot they default-suggest in, but the player
-- can assign them to either slot — the dropdowns show everything.
--
-- Paladin:
--   33391 Summon Charger          (epic ground, learned ~level 61 via class quest / trainer)
--    --   Summon Warhorse is companion-registered via GetCompanionInfo in most 3.3.5 builds,
--         so we only inject the ones that are NOT reliably in the companion list.
-- Warlock:
--   23161 Summon Dreadsteed       (epic ground, from Warlock mount quest)
--    --   Summon Felsteed (5784) is companion-registered in most builds; skip.
-- Death Knight:
--   48778 Deathcharger's Reins (Acherus Deathcharger) — granted automatically
--         during the DK starting-zone questline; IS in the companion list on
--         most realms, but some private-server builds miss it, so we inject
--         it defensively.  Duplicate-checking below prevents double entries.
--
-- NOTE: If a spell is ALSO returned by GetCompanionInfo the duplicate-check
-- (OwnedMounts[spellID] already exists → skip) prevents it appearing twice.

local CLASS_SPELL_LIST = {
    PALADIN = {
        { spellID = 33391, name = "Summon Charger",       icon = "Interface\\Icons\\Spell_Holy_SummonCharger",    isFlying = false },
        -- Summon Warhorse (13819) is almost always in companion list; add only as fallback
        { spellID = 13819, name = "Summon Warhorse",      icon = "Interface\\Icons\\Spell_Holy_SummonCharger",    isFlying = false },
    },
    WARLOCK = {
        { spellID = 23161, name = "Summon Dreadsteed",    icon = "Interface\\Icons\\Spell_Shadow_SummonFelsteed", isFlying = false },
        -- Summon Felsteed (5784) is almost always in companion list; add only as fallback
        { spellID =  5784, name = "Summon Felsteed",      icon = "Interface\\Icons\\Spell_Shadow_SummonFelsteed", isFlying = false },
    },
    DEATHKNIGHT = {
        { spellID = 48778, name = "Acherus Deathcharger", icon = "Interface\\Icons\\Ability_Mount_Deathknight",   isFlying = false },
    },
    DRUID = {
        { spellID =   783, name = "Travel Form",          icon = "Interface\\Icons\\Ability_Druid_TravelForm",    isFlying = false },
        { spellID = 33943, name = "Flight Form",          icon = "Interface\\Icons\\Ability_Druid_FlightForm",    isFlying = true  },
        { spellID = 40120, name = "Swift Flight Form",    icon = "Interface\\Icons\\Ability_Druid_FlightForm",    isFlying = true  },
    },
}

-- ============================================================
-- UTILITY
-- ============================================================
local function Debug(...)
    if IsDebug then print("|cff00ccff[MS]|r", ...) end
end

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function CanFlyHere()
    if not IsFlyableArea() then return false end
    if GetZoneText() == "Dalaran" and GetSubZoneText() ~= "Krasus' Landing" then
        return false
    end
    return true
end

-- ============================================================
-- MOUNT DATABASE
-- ============================================================
local OwnedMounts = {}

local function RebuildMountDatabase()
    wipe(OwnedMounts)

    -- 1. All companion mounts (no isFlying filtering — player decides assignment)
    local total = GetNumCompanions("MOUNT") or 0
    for i = 1, total do
        local _, name, spellID, icon = GetCompanionInfo("MOUNT", i)
        if spellID and name then
            OwnedMounts[spellID] = {
                name           = name,
                spellID        = spellID,
                icon           = icon,
                isFlying       = false,   -- unused for filtering; kept for compat
                isDruidForm    = false,
                isClassSpell   = false,
                companionIndex = i,
            }
        end
    end

    -- 2. Class-specific spells (Druid forms, Paladin/Warlock mounts, DK mount, etc.)
    local class = PlayerClass()
    local classSpells = CLASS_SPELL_LIST[class]
    if classSpells then
        for _, spell in ipairs(classSpells) do
            if IsSpellKnown(spell.spellID) and not OwnedMounts[spell.spellID] then
                -- Only inject if not already present from GetCompanionInfo
                OwnedMounts[spell.spellID] = {
                    name         = spell.name,
                    spellID      = spell.spellID,
                    icon         = spell.icon,
                    isFlying     = spell.isFlying,
                    isDruidForm  = (class == "DRUID"),
                    isClassSpell = true,
                }
                Debug("Injected class spell:", spell.name, spell.spellID)
            end
        end
    end

    MountSwitcherDB.OwnedMounts = OwnedMounts
    Debug("Mount database rebuilt. Total entries:", #OwnedMounts)
end

-- ============================================================
-- BAR FRAME  (draggable shell around the secure button)
-- ============================================================
local barFrame = CreateFrame("Frame", "MountSwitcherBar", UIParent)
barFrame:SetSize(BUTTON_SIZE + 12, BUTTON_SIZE + 12)
barFrame:SetClampedToScreen(true)
barFrame:SetMovable(true)

-- Gold "unlocked" border
local unlockBorder = barFrame:CreateTexture(nil, "OVERLAY")
unlockBorder:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
unlockBorder:SetBlendMode("ADD")
unlockBorder:SetAllPoints(barFrame)
unlockBorder:Hide()

local function SaveBarPosition()
    local point, _, relPoint, x, y = barFrame:GetPoint()
    MountSwitcherDB.BarPosition = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestoreBarPosition()
    barFrame:ClearAllPoints()
    local saved = MountSwitcherDB.BarPosition
    if saved then
        barFrame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    else
        barFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230)
    end
end

local barLocked = true

local function SetBarLocked(locked)
    barLocked = locked
    MountSwitcherDB.BarLocked = locked
    if locked then
        barFrame:EnableMouse(false)
        barFrame:RegisterForDrag()
        unlockBorder:Hide()
    else
        barFrame:EnableMouse(true)
        barFrame:RegisterForDrag("LeftButton")
        unlockBorder:Show()
    end
end

barFrame:SetScript("OnDragStart", function(self)
    if not barLocked then self:StartMoving() end
end)
barFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveBarPosition()
end)

-- ============================================================
-- SECURE BUTTON  (child of barFrame)
-- ============================================================
local secureButton = CreateFrame("Button", "MountSwitcherSecureButton", barFrame,
                                  "SecureActionButtonTemplate")
secureButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
secureButton:SetPoint("CENTER", barFrame, "CENTER")
secureButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")

-- Right-click: secure side is a no-op macro so WoW doesn't try to cast anything
secureButton:SetAttribute("type2",       "macro")
secureButton:SetAttribute("macrotext2",  "")

-- Icon (inset 2px, action-button style)
local iconTexture = secureButton:CreateTexture(nil, "BACKGROUND")
iconTexture:SetPoint("TOPLEFT",     2,  -2)
iconTexture:SetPoint("BOTTOMRIGHT", -2,  2)
iconTexture:SetTexture("Interface\\Icons\\Ability_Mount_MountedHorse")

-- Slot border (the normal "empty slot" look)
local normalBorder = secureButton:CreateTexture(nil, "BORDER")
normalBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
normalBorder:SetPoint("TOPLEFT",     -7,  7)
normalBorder:SetPoint("BOTTOMRIGHT",  7, -7)

-- Pushed overlay
local pushedTex = secureButton:CreateTexture(nil, "OVERLAY")
pushedTex:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
pushedTex:SetAllPoints(secureButton)
pushedTex:Hide()
secureButton:SetScript("OnMouseDown", function() pushedTex:Show() end)
secureButton:SetScript("OnMouseUp",   function() pushedTex:Hide() end)

-- Highlight
local highlightTex = secureButton:CreateTexture(nil, "HIGHLIGHT")
highlightTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
highlightTex:SetBlendMode("ADD")
highlightTex:SetAllPoints(secureButton)

-- Hotkey label (top-right corner, shows bound key just like action bars)
local hotkeyLabel = secureButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
hotkeyLabel:SetPoint("TOPRIGHT", secureButton, "TOPRIGHT", -2, -2)
hotkeyLabel:SetText("")

local function RefreshHotkeyLabel()
    local key = GetBindingKey("CLICK MountSwitcherSecureButton:LeftButton")
    hotkeyLabel:SetText(key and GetBindingText(key, "KEY_") or "")
end

-- Tooltip
secureButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local spellAttr = self:GetAttribute("spell")
    if spellAttr then
        GameTooltip:SetText(spellAttr, 1, 1, 1)
        GameTooltip:AddLine(CanFlyHere() and "|cff00ff88Flying zone|r"
                                          or "|cffaaaaaaGround zone|r", 1, 1, 1)
    else
        GameTooltip:SetText("MountSwitcher", 1, 1, 1)
        GameTooltip:AddLine("No mount configured — use /ms options", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(barLocked and "|cffaaaaaa(Right-click for options)|r"
                                   or "|cffffff00Drag to move|r  · Right-click to lock", 1, 1, 1)
    GameTooltip:Show()
end)
secureButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ============================================================
-- RIGHT-CLICK CONTEXT MENU
-- ============================================================
-- Forward-declare optionsFrame so the menu can reference it
local optionsFrame

local contextMenu = CreateFrame("Frame", "MSSContextMenu", UIParent, "UIDropDownMenuTemplate")
local function ShowContextMenu()
    UIDropDownMenu_Initialize(contextMenu, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text         = barLocked and "Unlock Bar" or "Lock Bar"
        info.notCheckable = true
        info.func         = function()
            SetBarLocked(not barLocked)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)

        info.text         = "Options"
        info.notCheckable = true
        info.func         = function()
            if optionsFrame:IsShown() then optionsFrame:Hide() else optionsFrame:Show() end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, contextMenu, "cursor", 0, 0)
end

-- Hook right-click (non-secure side only — we already made type2 a no-op)
secureButton:HookScript("OnClick", function(self, btn)
    if btn == "RightButton" and not InCombatLockdown() then
        ShowContextMenu()
    end
end)

-- ============================================================
-- SECURE BUTTON ATTRIBUTE UPDATE
-- ============================================================
local function UpdateSecureButton()
    if InCombatLockdown() then
        Debug("UpdateSecureButton: skipped (in combat)")
        return
    end

    local flyID    = MountSwitcherDB.FlyingMountSpellID
    local groundID = MountSwitcherDB.GroundMountSpellID

    if not flyID and not groundID then
        secureButton:SetAttribute("type",      "macro")
        secureButton:SetAttribute("macrotext", "")
        iconTexture:SetTexture("Interface\\Icons\\Ability_Mount_MountedHorse")
        Debug("No mounts configured")
        return
    end

    -- Slot 1 (FlyingMountSpellID) is used in flying zones,
    -- Slot 2 (GroundMountSpellID) is used everywhere else.
    -- The player is responsible for assigning the right mount to each slot.
    local targetID  = CanFlyHere() and (flyID or groundID) or (groundID or flyID)
    local mountData = OwnedMounts[targetID]

    if not mountData then
        Debug("SpellID", targetID, "not found in OwnedMounts")
        return
    end

    local spellName = GetSpellInfo(mountData.spellID)
    if not spellName then
        Debug("GetSpellInfo nil for spellID", mountData.spellID)
        return
    end

    secureButton:SetAttribute("type",  "spell")
    secureButton:SetAttribute("spell", spellName)
    iconTexture:SetTexture(mountData.icon)

    Debug("→", spellName, CanFlyHere() and "[SLOT1/FLY]" or "[SLOT2/GROUND]")
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================
local eventFrame = CreateFrame("Frame", "MountSwitcherEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("COMPANION_LEARNED")
eventFrame:RegisterEvent("COMPANION_UNLEARNED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        RebuildMountDatabase()
        RestoreBarPosition()
        SetBarLocked(MountSwitcherDB.BarLocked ~= false)
        if MountSwitcherDB.HideBar then
            barFrame:SetAlpha(0)
            barFrame:EnableMouse(false)
        end
        UpdateSecureButton()
        RefreshHotkeyLabel()

    elseif event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" then
        RebuildMountDatabase()
        UpdateSecureButton()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
        or event == "PLAYER_REGEN_ENABLED" then
        UpdateSecureButton()

    elseif event == "UPDATE_BINDINGS" then
        RefreshHotkeyLabel()
    end
end)

-- ============================================================
-- OPTIONS FRAME
-- ============================================================
--
-- Layout (top → bottom), all Y offsets from TOPLEFT of optionsFrame:
--
--   [ Title "MountSwitcher"          ] [X]   y= -10
--   ─────────────────────────────────────
--   Slot 1 — Flying zones:                   y= -42
--   [ Dropdown ▾                    ]        y= -57
--   ─────────────────────────────────────
--   Slot 2 — Ground zones:                   y= -102
--   [ Dropdown ▾                    ]        y= -117
--   ─────────────────────────────────────
--   Keybind hint                             y= -165
--   ─────────────────────────────────────
--   [x] Hide action bar checkbox             y= -202
--   ─────────────────────────────────────
--   [ Unlock Bar  ]        [ Save ]          y= bottom

optionsFrame = CreateFrame("Frame", "MountSwitcherOptionsFrame", UIParent)
optionsFrame:SetSize(380, 280)
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
do
    local cb = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    cb:SetSize(32, 32)
    cb:SetPoint("TOPRIGHT", -5, -5)
    cb:SetScript("OnClick", function() optionsFrame:Hide() end)
end

-- ── Title ───────────────────────────────────────────────────
local titleText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetText("MountSwitcher")
titleText:SetPoint("TOPLEFT", 15, -12)

-- ── Divider after title ──────────────────────────────────────
local div1 = optionsFrame:CreateTexture(nil, "ARTWORK")
div1:SetTexture(1, 1, 1, 0.15)
div1:SetHeight(1)
div1:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  12, -34)
div1:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -34)

-- ── Slot 1 dropdown (flying zones) ──────────────────────────
local flyLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyLabel:SetText("Slot 1 — Flying zones:")
flyLabel:SetPoint("TOPLEFT", 20, -42)

local flyDropdown = CreateFrame("Frame", "MSSFlyDropdown", optionsFrame, "UIDropDownMenuTemplate")
flyDropdown:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 0, -57)
UIDropDownMenu_SetWidth(flyDropdown, 300)

-- ── Divider ──────────────────────────────────────────────────
local div2 = optionsFrame:CreateTexture(nil, "ARTWORK")
div2:SetTexture(1, 1, 1, 0.15)
div2:SetHeight(1)
div2:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  12, -100)
div2:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -100)

-- ── Slot 2 dropdown (ground zones) ──────────────────────────
local groundLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundLabel:SetText("Slot 2 — Ground zones:")
groundLabel:SetPoint("TOPLEFT", 20, -108)

local groundDropdown = CreateFrame("Frame", "MSSGroundDropdown", optionsFrame, "UIDropDownMenuTemplate")
groundDropdown:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 0, -123)
UIDropDownMenu_SetWidth(groundDropdown, 300)

-- ── Divider before keybind hint ───────────────────────────────
local div3 = optionsFrame:CreateTexture(nil, "ARTWORK")
div3:SetTexture(1, 1, 1, 0.15)
div3:SetHeight(1)
div3:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  12, -164)
div3:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -164)

-- ── Keybind hint ─────────────────────────────────────────────
local keybindHint1 = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
keybindHint1:SetText("To set a keybind, open Key Bindings (ESC)")
keybindHint1:SetTextColor(0.7, 0.7, 0.7)
keybindHint1:SetPoint("TOPLEFT", 20, -174)

local keybindHint2 = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
keybindHint2:SetText("and look for the |cffffd700MountSwitcher|r section at the bottom.")
keybindHint2:SetPoint("TOPLEFT", 20, -188)

-- ── Hide Bar checkbox ────────────────────────────────────────
local hideBarCB = CreateFrame("CheckButton", "MSSHideBarCB", optionsFrame, "UICheckButtonTemplate")
hideBarCB:SetSize(26, 26)
hideBarCB:SetPoint("TOPLEFT", 16, -202)
local hideBarLabel = hideBarCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideBarLabel:SetText("Hide action bar (keybind still works)")
hideBarLabel:SetPoint("LEFT", hideBarCB, "RIGHT", 4, 0)
hideBarCB:SetScript("OnClick", function(self)
    MountSwitcherDB.HideBar = self:GetChecked() and true or false
    if MountSwitcherDB.HideBar then
        barFrame:SetAlpha(0)
        barFrame:EnableMouse(false)
    else
        barFrame:SetAlpha(1)
        if not barLocked then barFrame:EnableMouse(true) end
    end
end)

-- ── Divider before buttons ────────────────────────────────────
local div4 = optionsFrame:CreateTexture(nil, "ARTWORK")
div4:SetTexture(1, 1, 1, 0.15)
div4:SetHeight(1)
div4:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  12, -234)
div4:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -234)

-- ── Pending selection state (set by dropdowns, committed by Save) ───
local pendingFlyID    = nil
local pendingGroundID = nil

-- ── Bottom row: Lock button (left) + Save button (right) ────
local lockBtn = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
lockBtn:SetSize(126, 26)
lockBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 15, 12)
lockBtn:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    SetBarLocked(not barLocked)
    lockBtn:SetText(barLocked and "Unlock Bar" or "Lock Bar")
end)

local saveBtn = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
saveBtn:SetText("Save")
saveBtn:SetSize(126, 26)
saveBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 12)
saveBtn:SetScript("OnClick", function()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r Cannot save during combat.")
        return
    end
    MountSwitcherDB.FlyingMountSpellID  = pendingFlyID    or MountSwitcherDB.FlyingMountSpellID
    MountSwitcherDB.GroundMountSpellID  = pendingGroundID or MountSwitcherDB.GroundMountSpellID
    UpdateSecureButton()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff88[MountSwitcher]|r Mounts saved!")
end)

-- ── Dropdown helpers ─────────────────────────────────────────
-- Both dropdowns now show ALL mounts and class spells without filtering.
-- The player assigns whichever they want to each slot.

local function InitDropdown(dropdown, onSelect)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        -- Sort alphabetically for readability; skip any entries with a nil name
        -- (can happen on some private-server builds where GetCompanionInfo is incomplete)
        local sorted = {}
        for spellID, mountData in pairs(OwnedMounts) do
            if mountData.name and mountData.spellID then
                sorted[#sorted + 1] = mountData
            else
                Debug("Skipping mount entry with nil name/spellID, spellID=", spellID)
            end
        end
        table.sort(sorted, function(a, b)
            -- Extra safety: treat any remaining nil name as empty string
            return (a.name or "") < (b.name or "")
        end)

        for _, mountData in ipairs(sorted) do
            local info    = UIDropDownMenu_CreateInfo()
            local suffix  = mountData.isClassSpell and " *" or ""
            info.text     = (mountData.name or "Unknown") .. suffix
            info.value    = mountData.spellID
            info.icon     = mountData.icon
            info.func     = function(btn)
                UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
                UIDropDownMenu_SetText(dropdown, btn:GetText())
                onSelect(btn.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

local function PopulateDropdowns()
    InitDropdown(flyDropdown,    function(v) pendingFlyID    = v end)
    InitDropdown(groundDropdown, function(v) pendingGroundID = v end)

    local flyID    = MountSwitcherDB.FlyingMountSpellID
    local groundID = MountSwitcherDB.GroundMountSpellID
    if flyID    and OwnedMounts[flyID]    then
        UIDropDownMenu_SetSelectedValue(flyDropdown, flyID)
        UIDropDownMenu_SetText(flyDropdown, OwnedMounts[flyID].name)
        pendingFlyID = flyID
    end
    if groundID and OwnedMounts[groundID] then
        UIDropDownMenu_SetSelectedValue(groundDropdown, groundID)
        UIDropDownMenu_SetText(groundDropdown, OwnedMounts[groundID].name)
        pendingGroundID = groundID
    end
end

-- Refresh everything each time the options frame opens
local origShow = optionsFrame.Show
optionsFrame.Show = function(self)
    PopulateDropdowns()
    lockBtn:SetText(barLocked and "Unlock Bar" or "Lock Bar")
    hideBarCB:SetChecked(MountSwitcherDB.HideBar or false)
    origShow(self)
end

-- ============================================================
-- KEY BINDING LABELS
-- ============================================================
BINDING_HEADER_MOUNTSWITCHER                               = "MountSwitcher"
BINDING_NAME_CLICK_MountSwitcherSecureButton_LeftButton    = "Summon Mount"

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_MountSwitcher1 = "/ms"
SlashCmdList["MountSwitcher"] = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "options" then
        if optionsFrame:IsShown() then optionsFrame:Hide() else optionsFrame:Show() end

    elseif msg == "lock" then
        if InCombatLockdown() then return end
        SetBarLocked(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Bar locked.")

    elseif msg == "unlock" then
        if InCombatLockdown() then return end
        SetBarLocked(false)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Bar unlocked — drag to reposition.")

    elseif msg == "reload" then
        if InCombatLockdown() then return end
        RebuildMountDatabase()
        PopulateDropdowns()
        UpdateSecureButton()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Mount list reloaded.")

    elseif msg == "debug" then
        IsDebug = not IsDebug
        print("|cff00ccff[MountSwitcher]|r Debug:", IsDebug and "ON" or "OFF")
        if IsDebug then RebuildMountDatabase() UpdateSecureButton() end

    elseif msg == "mount" then
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r Use your bound key in combat.")
            return
        end
        UpdateSecureButton()
        secureButton:Click()

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms options  — Toggle options panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms unlock   — Unlock bar to drag it")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms lock     — Lock bar position")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms reload   — Refresh mount list")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms mount    — Summon mount (out of combat only)")
        DEFAULT_CHAT_FRAME:AddMessage("  /ms debug    — Toggle debug output")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffTip:|r Key Bindings → MountSwitcher → Summon Mount")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffNote:|r * = class spell (not a companion mount)")
    end
end