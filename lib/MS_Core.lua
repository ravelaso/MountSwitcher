-- MS_Core.lua
-- Main loader and event handler for MountSwitcher
-- This file MUST be loaded first as it creates the MS global table

local addonName, MS = ...
MountSwitcherDB = MountSwitcherDB or {}

-- Make MS accessible globally for debugging (optional but useful)
_G.MS = MS

-- ============================================================
-- CONSTANTS
-- ============================================================
MS.ADDON_NAME   = addonName
MS.BUTTON_SIZE  = 36
MS.IsDebug      = false

-- ============================================================
-- DEBUG
-- ============================================================
function MS:Debug(...)
    if self.IsDebug then
        print("|cff00ccff[MS]|r", ...)
    end
end

-- ============================================================
-- EVENT FRAME (loaded after all modules)
-- ============================================================
MS.eventFrame = CreateFrame("Frame", "MountSwitcherEventFrame")

-- Forward declarations for functions that will be defined in other modules
MS.UpdateSecureButton = nil
MS.RefreshHotkeyLabel = nil
MS.PopulateDropdowns = nil
MS.RestoreBarPosition = nil
MS.SetBarLocked = nil

-- ============================================================
-- INITIALIZATION
-- ============================================================
function MS:Initialize()
    self:Debug("Initializing MountSwitcher...")
    
    -- Rebuild mount database
    if self.MountDB and self.MountDB.Rebuild then
        self.MountDB:Rebuild()
    end
    
    -- Restore UI state
    if self.RestoreBarPosition then self:RestoreBarPosition() end
    if self.SetBarLocked then self:SetBarLocked(MountSwitcherDB.BarLocked ~= false) end
    
    -- Handle hide bar setting
    if MountSwitcherDB.HideBar and self.barFrame then
        self.barFrame:SetAlpha(0)
        self.barFrame:EnableMouse(false)
    end
    
    -- Update secure button
    if self.UpdateSecureButton then self:UpdateSecureButton() end
    if self.RefreshHotkeyLabel then self:RefreshHotkeyLabel() end
    
    self:Debug("Initialization complete")
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================
MS.eventFrame:RegisterEvent("PLAYER_LOGIN")
MS.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
MS.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
MS.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
MS.eventFrame:RegisterEvent("ZONE_CHANGED")
MS.eventFrame:RegisterEvent("COMPANION_LEARNED")
MS.eventFrame:RegisterEvent("COMPANION_UNLEARNED")
MS.eventFrame:RegisterEvent("UPDATE_BINDINGS")

MS.eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        MS:Initialize()
    elseif event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" then
        if MS.MountDB and MS.MountDB.Rebuild then
            MS.MountDB:Rebuild()
        end
        if MS.UpdateSecureButton then MS:UpdateSecureButton() end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
        or event == "PLAYER_REGEN_ENABLED" then
        if MS.UpdateSecureButton then MS:UpdateSecureButton() end
    elseif event == "UPDATE_BINDINGS" then
        if MS.RefreshHotkeyLabel then MS:RefreshHotkeyLabel() end
    end
end)

MS:Debug("Core module loaded")