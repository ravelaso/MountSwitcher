-- MS_SecureButton.lua
-- Secure button creation and management for MountSwitcher
-- Handles the secure action button that can be used in combat

local _, MS = ...

-- ============================================================
-- SECURE BUTTON (child of barFrame)
-- ============================================================
MS.secureButton = CreateFrame("Button", "MountSwitcherSecureButton", MS.barFrame,
                               "SecureActionButtonTemplate")
local secureButton = MS.secureButton

secureButton:SetSize(MS.BUTTON_SIZE, MS.BUTTON_SIZE)
secureButton:SetPoint("CENTER", MS.barFrame, "CENTER")
secureButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")

-- Right-click: secure side is a no-op macro so WoW doesn't try to cast anything
secureButton:SetAttribute("type2",       "macro")
secureButton:SetAttribute("macrotext2",  "")

-- Icon (inset 2px, action-button style)
local iconTexture = secureButton:CreateTexture(nil, "BACKGROUND")
iconTexture:SetPoint("TOPLEFT",     2,  -2)
iconTexture:SetPoint("BOTTOMRIGHT", -2,  2)
iconTexture:SetTexture("Interface\\Icons\\Ability_Mount_MountedHorse")

-- Store iconTexture reference for updates
MS.iconTexture = iconTexture

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

-- Store hotkeyLabel reference
MS.hotkeyLabel = hotkeyLabel

-- ============================================================
-- HOTKEY LABEL
-- ============================================================
function MS:RefreshHotkeyLabel()
    local key = GetBindingKey("CLICK MountSwitcherSecureButton:LeftButton")
    hotkeyLabel:SetText(key and GetBindingText(key, "KEY_") or "")
end

-- ============================================================
-- TOOLTIP
-- ============================================================
secureButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local spellAttr = self:GetAttribute("spell")
    if spellAttr then
        GameTooltip:SetText(spellAttr, 1, 1, 1)
        GameTooltip:AddLine(MS:CanFlyHere() and "|cff00ff88Flying zone|r"
                                           or "|cffaaaaaaGround zone|r", 1, 1, 1)
    else
        GameTooltip:SetText("MountSwitcher", 1, 1, 1)
        GameTooltip:AddLine("No mount configured — use /ms options", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(MS.barLocked and "|cffaaaaaa(Right-click for options)|r"
                                   or "|cffffff00Drag to move|r  · Right-click to lock", 1, 1, 1)
    GameTooltip:Show()
end)
secureButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ============================================================
-- SECURE BUTTON ATTRIBUTE UPDATE
-- ============================================================
function MS:UpdateSecureButton()
    if InCombatLockdown() then
        self:Debug("UpdateSecureButton: skipped (in combat)")
        return
    end

    local flyID    = MountSwitcherDB.FlyingMountSpellID
    local groundID = MountSwitcherDB.GroundMountSpellID

    if not flyID and not groundID then
        secureButton:SetAttribute("type",      "macro")
        secureButton:SetAttribute("macrotext", "")
        iconTexture:SetTexture("Interface\\Icons\\Ability_Mount_MountedHorse")
        self:Debug("No mounts configured")
        return
    end

    -- Slot 1 (FlyingMountSpellID) is used in flying zones,
    -- Slot 2 (GroundMountSpellID) is used everywhere else.
    -- The player is responsible for assigning the right mount to each slot.
    local targetID  = self:CanFlyHere() and (flyID or groundID) or (groundID or flyID)
    local mountData = self.MountDB.OwnedMounts[targetID]

    if not mountData then
        self:Debug("SpellID", targetID, "not found in OwnedMounts")
        return
    end

    local spellName = GetSpellInfo(mountData.spellID)
    if not spellName then
        self:Debug("GetSpellInfo nil for spellID", mountData.spellID)
        return
    end

    secureButton:SetAttribute("type",  "spell")
    secureButton:SetAttribute("spell", spellName)
    iconTexture:SetTexture(mountData.icon)

    self:Debug("→", spellName, self:CanFlyHere() and "[SLOT1/FLY]" or "[SLOT2/GROUND]")
end

-- ============================================================
-- CONTEXT MENU HOOK (right-click)
-- ============================================================
-- Forward-declare for context menu
MS.ShowContextMenu = nil

secureButton:HookScript("OnClick", function(self, btn)
    if btn == "RightButton" and not InCombatLockdown() then
        if MS.ShowContextMenu then
            MS:ShowContextMenu()
        end
    end
end)

MS:Debug("SecureButton module loaded")