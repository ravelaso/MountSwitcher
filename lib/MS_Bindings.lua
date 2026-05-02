-- MS_Bindings.lua
-- Slash commands and key bindings for MountSwitcher

local _, MS = ...

-- ============================================================
-- KEY BINDING LABELS
-- ============================================================
BINDING_HEADER_MOUNTSWITCHER                               = "MountSwitcher"
BINDING_NAME_CLICK_MountSwitcherSecureButton_LeftButton    = "Summon Mount"

-- ============================================================
-- SLASH COMMANDS
-- Register on PLAYER_LOGIN to ensure all modules are loaded
-- ============================================================
local function RegisterSlashCommands()
    SLASH_MountSwitcher1 = "/ms"
    SlashCmdList["MountSwitcher"] = function(msg)
        msg = strtrim(strlower(msg or ""))

        if msg == "options" then
            if MS.optionsFrame:IsShown() then 
                MS.optionsFrame:Hide() 
            else 
                MS.optionsFrame:Show() 
            end

        elseif msg == "lock" then
            if InCombatLockdown() then return end
            MS:SetBarLocked(true)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Bar locked.")

        elseif msg == "unlock" then
            if InCombatLockdown() then return end
            MS:SetBarLocked(false)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Bar unlocked — drag to reposition.")

        elseif msg == "reload" then
            if InCombatLockdown() then return end
            if MS.MountDB and MS.MountDB.Rebuild then
                MS.MountDB:Rebuild()
            end
            if MS.PopulateDropdowns then MS:PopulateDropdowns() end
            if MS.UpdateSecureButton then MS:UpdateSecureButton() end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[MountSwitcher]|r Mount list reloaded.")

        elseif msg == "debug" then
            MS.IsDebug = not MS.IsDebug
            print("|cff00ccff[MountSwitcher]|r Debug:", MS.IsDebug and "ON" or "OFF")
            if MS.IsDebug then 
                if MS.MountDB and MS.MountDB.Rebuild then
                    MS.MountDB:Rebuild()
                end
                if MS.UpdateSecureButton then 
                    MS:UpdateSecureButton() 
                end
            end

        elseif msg == "mount" then
            if InCombatLockdown() then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[MountSwitcher]|r Use your bound key in combat.")
                return
            end
            if MS.UpdateSecureButton then MS:UpdateSecureButton() end
            if MS.secureButton then
                MS.secureButton:Click()
            end

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
end

-- Register slash commands after all addons are loaded
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    MS:Debug("PLAYER_LOGIN fired, MS.optionsFrame:", MS.optionsFrame)
    RegisterSlashCommands()
    MS:Debug("Slash commands registered")
    frame:UnregisterEvent("PLAYER_LOGIN")
end)

MS:Debug("Bindings module loaded")