-- MS_Options.lua
-- Options frame for MountSwitcher addon

local _, MS = ...

-- ============================================================
-- OPTIONS FRAME
-- ============================================================
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

MS.optionsFrame = CreateFrame("Frame", "MountSwitcherOptionsFrame", UIParent)
local optionsFrame = MS.optionsFrame

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

MS.flyDropdown = CreateFrame("Frame", "MSSFlyDropdown", optionsFrame, "UIDropDownMenuTemplate")
MS.flyDropdown:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 0, -57)
UIDropDownMenu_SetWidth(MS.flyDropdown, 300)

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

MS.groundDropdown = CreateFrame("Frame", "MSSGroundDropdown", optionsFrame, "UIDropDownMenuTemplate")
MS.groundDropdown:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 0, -123)
UIDropDownMenu_SetWidth(MS.groundDropdown, 300)

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
MS.hideBarCB = CreateFrame("CheckButton", "MSSHideBarCB", optionsFrame, "UICheckButtonTemplate")
MS.hideBarCB:SetSize(26, 26)
MS.hideBarCB:SetPoint("TOPLEFT", 16, -202)
local hideBarLabel = MS.hideBarCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hideBarLabel:SetText("Hide action bar (keybind still works)")
hideBarLabel:SetPoint("LEFT", MS.hideBarCB, "RIGHT", 4, 0)
MS.hideBarCB:SetScript("OnClick", function(self)
    MountSwitcherDB.HideBar = self:GetChecked() and true or false
    if MountSwitcherDB.HideBar then
        MS.barFrame:SetAlpha(0)
        MS.barFrame:EnableMouse(false)
    else
        MS.barFrame:SetAlpha(1)
        if MS.barLocked ~= nil and not MS.barLocked then 
            MS.barFrame:EnableMouse(true) 
        end
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
MS.lockBtn = CreateFrame("Button", nil, optionsFrame, "GameMenuButtonTemplate")
MS.lockBtn:SetSize(126, 26)
MS.lockBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 15, 12)
MS.lockBtn:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    MS:SetBarLocked(not MS.barLocked)
    MS.lockBtn:SetText(MS.barLocked and "Unlock Bar" or "Lock Bar")
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
    MS:UpdateSecureButton()
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
        local ownedMounts = MS.MountDB.OwnedMounts
        for spellID, mountData in pairs(ownedMounts) do
            if mountData.name and mountData.spellID then
                sorted[#sorted + 1] = mountData
            else
                MS:Debug("Skipping mount entry with nil name/spellID, spellID=", spellID)
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

function MS:PopulateDropdowns()
    InitDropdown(self.flyDropdown,    function(v) pendingFlyID    = v end)
    InitDropdown(self.groundDropdown, function(v) pendingGroundID = v end)

    local flyID    = MountSwitcherDB.FlyingMountSpellID
    local groundID = MountSwitcherDB.GroundMountSpellID
    if flyID    and self.MountDB.OwnedMounts[flyID] then
        UIDropDownMenu_SetSelectedValue(self.flyDropdown, flyID)
        UIDropDownMenu_SetText(self.flyDropdown, self.MountDB.OwnedMounts[flyID].name)
        pendingFlyID = flyID
    end
    if groundID and self.MountDB.OwnedMounts[groundID] then
        UIDropDownMenu_SetSelectedValue(self.groundDropdown, groundID)
        UIDropDownMenu_SetText(self.groundDropdown, self.MountDB.OwnedMounts[groundID].name)
        pendingGroundID = groundID
    end
end

-- Refresh everything each time the options frame opens
local origShow = optionsFrame.Show
optionsFrame.Show = function(self)
    if MS.PopulateDropdowns then MS:PopulateDropdowns() end
    if MS.lockBtn then
        MS.lockBtn:SetText(MS.barLocked and "Unlock Bar" or "Lock Bar")
    end
    if MS.hideBarCB then
        MS.hideBarCB:SetChecked(MountSwitcherDB.HideBar or false)
    end
    origShow(self)
end

MS:Debug("Options module loaded")