-- MountSwitcher.lua
-- Declare MountSwitcherDB as a global variable
MountSwitcherDB = MountSwitcherDB or {}
MountSwitcherDB.OwnedMounts = {}

-- Create the frame
local myFrame = CreateFrame("Frame", "MountSwitcherFrame", UIParent, "BasicFrameTemplate")
myFrame:SetSize(260, 220) -- Adjusted the frame size to fit the items
myFrame:SetPoint("CENTER")
myFrame:SetMovable(true)
myFrame:EnableMouse(true)
myFrame:RegisterForDrag("LeftButton")
myFrame:SetScript("OnDragStart", myFrame.StartMoving)
myFrame:SetScript("OnDragStop", myFrame.StopMovingOrSizing)
myFrame:SetScript("OnHide", myFrame.StopMovingOrSizing)
myFrame:SetShown(false)
-- Addon Title
local title = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("MountSwitcher")
title:SetPoint("TOPLEFT", 5, -5) -- Center the title at the top of the frame

-- Create dropdown menus and labels
local yOffset = -40 -- Adjust the vertical offset for each item

local flyingMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyingMountLabel:SetText("Flying Mount:")
flyingMountLabel:SetPoint("TOPLEFT", 30, yOffset)

local flyingMountDropdown = CreateFrame("Frame", "FlyingMountDropdown", myFrame, "UIDropDownMenuTemplate")
flyingMountDropdown:SetPoint("TOPLEFT", flyingMountLabel, "BOTTOMLEFT", -20, -5)
UIDropDownMenu_SetWidth(flyingMountDropdown, 180)

yOffset = yOffset - 60 -- Increase the offset for the next item

local groundMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundMountLabel:SetText("Ground Mount:")
groundMountLabel:SetPoint("TOPLEFT", 30, yOffset)

local groundMountDropdown = CreateFrame("Frame", "GroundMountDropdown", myFrame, "UIDropDownMenuTemplate")
groundMountDropdown:SetPoint("TOPLEFT", groundMountLabel, "BOTTOMLEFT", -20, -5)
UIDropDownMenu_SetWidth(groundMountDropdown, 180)


-- Create the buttons
local mountButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
mountButton:SetText("Mount")
mountButton:SetSize(90, 30)
mountButton:SetPoint("BOTTOMLEFT", groundMountDropdown, "BOTTOMLEFT", 22, -40) -- Position the button below the ground mount dropdown

local saveButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
saveButton:SetText("Save")
saveButton:SetSize(90, 30)
saveButton:SetPoint("LEFT", mountButton, "RIGHT", 5, 0) -- Position the Save button on the right side of the mountButton

-- Small Text Label
local smallTextLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
smallTextLabel:SetText("Macro: /ms mount")
smallTextLabel:SetPoint("TOPLEFT", mountButton, "BOTTOMLEFT", 38, -10) -- Center the smallTextLabel below the row of buttons

-- Function to save the input data
local function SaveData()
    -- Save the data using SavedVariables
    MountSwitcherDB = MountSwitcherDB or {} -- Create the table if it doesn't exist
    MountSwitcherDB["FlyingMount"] = UIDropDownMenu_GetValue(flyingMountDropdown)
    MountSwitcherDB["GroundMount"] = UIDropDownMenu_GetValue(groundMountDropdown)

    DEFAULT_CHAT_FRAME:AddMessage("Data saved!")
end

-- Function to get all mounts that the player owns
local function GetOwnedMounts()
    MountSwitcherDB = MountSwitcherDB or {}
    MountSwitcherDB.OwnedMounts = {}
    local numMounts = GetNumCompanions("MOUNT")
    for i = 1, numMounts do
        local _,_,creatureSpellID = GetCompanionInfo("MOUNT", i)
        local name,_,icon = GetSpellInfo(creatureSpellID)
        MountSwitcherDB.OwnedMounts[creatureSpellID] = {name = name, icon = icon}
    end
end

-- Set the OnClick script of the Save button to our SaveData function
saveButton:SetScript("OnClick", SaveData)

-- Function to be executed when the button is clicked
local function OnMountButton()
    local fly = MountSwitcherDB["FlyingMount"]
    local ground = MountSwitcherDB["GroundMount"]
    if (GetZoneText() == "Dalaran") then
        if (GetSubZoneText() == "Krasus' Landing") then
            CastSpellByName(GetSpellInfo(fly))
        else
            CastSpellByName(ground)
        end
    elseif IsFlyableArea() then
        CastSpellByName(GetSpellInfo(fly))
    else
        CastSpellByName(GetSpellInfo(ground))
    end
end
-- Set the OnClick script of the button to our function
mountButton:SetScript("OnClick", OnMountButton)

-- Function to populate the dropdown menus with owned mounts
local function PopulateDropdownMenus()
    UIDropDownMenu_Initialize(flyingMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for creatureSpellID, name in (ownedMounts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = creatureSpellID
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(flyingMountDropdown, self.value)
                    UIDropDownMenu_SetText(flyingMountDropdown,self.name)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)

    UIDropDownMenu_Initialize(groundMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for creatureSpellID, name in (ownedMounts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = creatureSpellID
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(groundMountDropdown, self.value)
                    UIDropDownMenu_SetText(groundMountDropdown,self.name)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
end

-- Function to load the saved data and update the dropdown menus
local function LoadSavedData()
    -- Retrieve the data from SavedVariables
    local flyingMount = MountSwitcherDB and MountSwitcherDB["FlyingMount"] or ""
    local groundMount = MountSwitcherDB and MountSwitcherDB["GroundMount"] or ""
    -- Update the dropdown menus
    UIDropDownMenu_SetText(flyingMountDropdown, GetSpellInfo(flyingMount))
    UIDropDownMenu_SetText(groundMountDropdown, GetSpellInfo(groundMount))
    -- Check if the frame should be shown or hidden
    if not MountSwitcherDB.ShowFrame then
        myFrame:Hide()
    end
end

-- Register the event to load saved data when the player logs in or reloads the UI
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
myFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        GetOwnedMounts()
        LoadSavedData() -- Load saved data from MountSwitcherDB
        PopulateDropdownMenus() -- Populate dropdown menus with owned mounts
    end
end)

-- Slash command handler
local function SlashCommandHandler(msg)
    if msg == "mount" then
        OnMountButton()
    elseif msg == "options" then
        if myFrame:IsShown() then
            myFrame:Hide()
            MountSwitcherDB.ShowFrame = false
        else
            myFrame:Show()
            MountSwitcherDB.ShowFrame = true
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Unknown command. Usage: /ms mount, /ms options")
    end
end

-- Register slash command /ms to show the frame
SLASH_MountSwitcher1 = "/ms"
SlashCmdList["MountSwitcher"] = SlashCommandHandler
