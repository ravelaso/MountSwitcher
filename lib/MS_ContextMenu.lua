-- MS_ContextMenu.lua
-- Right-click context menu for MountSwitcher bar

local _, MS = ...

-- Forward-declare optionsFrame so the menu can reference it
MS.optionsFrame = nil

-- ============================================================
-- RIGHT-CLICK CONTEXT MENU
-- ============================================================
MS.contextMenu = CreateFrame("Frame", "MSSContextMenu", UIParent, "UIDropDownMenuTemplate")

function MS:ShowContextMenu()
    UIDropDownMenu_Initialize(self.contextMenu, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text         = self.barLocked and "Unlock Bar" or "Lock Bar"
        info.notCheckable = true
        info.func         = function()
            self:SetBarLocked(not self.barLocked)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)

        info.text         = "Options"
        info.notCheckable = true
        info.func         = function()
            if self.optionsFrame then
                if self.optionsFrame:IsShown() then 
                    self.optionsFrame:Hide() 
                else 
                    self.optionsFrame:Show() 
                end
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")
    ToggleDropDownMenu(1, nil, self.contextMenu, "cursor", 0, 0)
end

MS:Debug("ContextMenu module loaded")