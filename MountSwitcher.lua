-- MountSwitcher.lua
-- Declare MountSwitcherDB as a global variable
MountSwitcherDB = MountSwitcherDB or {}
MountSwitcherDB.OwnedMounts = {}
local IsDebug = false

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

    local flyingMountIndex = UIDropDownMenu_GetSelectedID(flyingMountDropdown)
    local groundMountIndex = UIDropDownMenu_GetSelectedID(groundMountDropdown)

    if flyingMountIndex then
        MountSwitcherDB["FlyingMount"] = UIDropDownMenu_GetSelectedValue(flyingMountDropdown)
    end

    if groundMountIndex then
        MountSwitcherDB["GroundMount"] = UIDropDownMenu_GetSelectedValue(groundMountDropdown)
    end

    DEFAULT_CHAT_FRAME:AddMessage("Mounts saved! :)")
    if IsDebug then
        print("Saved Fly ID - ", MountSwitcherDB["FlyingMount"])
        print("Saved Ground ID - ", MountSwitcherDB["GroundMount"])
    end
end

-- Function to get all mounts that the player owns
local function GetOwnedMounts()
    MountSwitcherDB = MountSwitcherDB or {}
    MountSwitcherDB.OwnedMounts = {}
    local playerFaction = UnitFactionGroup("player")    
    local mountIDs = C_MountJournal.GetMountIDs()
    for i = 1, #mountIDs do
        local name, creatureSpellID, icon, _, _, _, _, _, faction, _, isCollected = C_MountJournal.GetMountInfoByID(mountIDs[i])
    
        if isCollected then
           
            local extraInfo = {C_MountJournal.GetMountInfoExtraByID(mountIDs[i])}
            local mTypeID = extraInfo[5] -- Extract the mount type ID from the Extra Info table
            if faction == nil or (playerFaction == "Horde" and faction == 0) or (playerFaction == "Alliance" and faction == 1) then
                MountSwitcherDB.OwnedMounts[creatureSpellID] = { name = name, icon = icon, mountTypeID = mTypeID } -- Include mount type ID in stored data
            end
        end
        if IsDebug then
            print("Found OwnedMount - ", creatureSpellID, name, icon, "Mount Type ID:", mTypeID) -- Print mount type ID for debugging
        end
    end
end


-- Set the OnClick script of the Save button to our SaveData function
saveButton:SetScript("OnClick", SaveData)

-- Function to be executed when the button is clicked
local function OnMountButton()
    local fly = MountSwitcherDB["FlyingMount"]
    local ground = MountSwitcherDB["GroundMount"]

    local flySpellName = GetSpellInfo(fly)
    local groundSpellName = GetSpellInfo(ground)

    -- Attempt to cast the flying mount spell
    if (GetZoneText() == "Dalaran") then
        if (GetSubZoneText() == "Krasus' Landing") then
            if IsDebug then
                print("Casting: ", flySpellName)
            end
            CastSpellByName(flySpellName)
        else
            if IsDebug then
                print("Casting: ", groundSpellName)
            end
            CastSpellByName(groundSpellName)
        end
    elseif IsFlyableArea() then
        if IsDebug then
            print("Casting: ", flySpellName)
        end
        CastSpellByName(flySpellName)
    else
        if IsDebug then
            print("Casting: ", groundSpellName)
        end
        CastSpellByName(groundSpellName)
    end
    
    -- Fail-Over
    CastSpellByName(groundSpellName)

end

-- Set the OnClick script of the button to our function
mountButton:SetScript("OnClick", OnMountButton)

-- Function to populate the dropdown menus with owned mounts
local function PopulateDropdownMenus()
    UIDropDownMenu_Initialize(flyingMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for creatureSpellID, mountData in pairs(ownedMounts) do
                if mountData.mountTypeID == 248 then -- Check if mount type ID is 248 (flying mount)
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = mountData.name
                    info.value = creatureSpellID
                    info.icon = mountData.icon
                    info.func = function(self)
                        UIDropDownMenu_SetSelectedValue(flyingMountDropdown, self.value)
                        UIDropDownMenu_SetText(flyingMountDropdown, self:GetText())
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end)

    UIDropDownMenu_Initialize(groundMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for creatureSpellID, mountData in pairs(ownedMounts) do
                if mountData.mountTypeID ~= 248 then -- Check if mount type ID is 248 (flying mount)
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = mountData.name
                    info.value = creatureSpellID
                    info.icon = mountData.icon
                    info.func = function(self)
                        UIDropDownMenu_SetSelectedValue(groundMountDropdown, self.value)
                        UIDropDownMenu_SetText(groundMountDropdown, self:GetText())
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end)
end
-- Function to load the saved data and update the dropdown menus
local function LoadSavedData()
    -- Retrieve the data from SavedVariables
    local flyingMount = MountSwitcherDB and MountSwitcherDB["FlyingMount"] or nil
    local groundMount = MountSwitcherDB and MountSwitcherDB["GroundMount"] or nil

    -- Update the dropdown menus and select the correct items
    if flyingMount then
        UIDropDownMenu_SetSelectedValue(flyingMountDropdown, flyingMount)
        UIDropDownMenu_SetText(flyingMountDropdown, GetSpellInfo(flyingMount))
    end

    if groundMount then
        UIDropDownMenu_SetSelectedValue(groundMountDropdown, groundMount)
        UIDropDownMenu_SetText(groundMountDropdown, GetSpellInfo(groundMount))
    end

    if IsDebug then
        print("Loaded Value - MountSwitcherDB - FlyingMount: ", flyingMount)
        print("Loaded Value - MountSwitcherDB - GroundMount: ", groundMount)
        if flyingMount then
            print("DropDown Set Value - ", GetSpellInfo(flyingMount))
        end
        if groundMount then
            print("DropDown Set Value - ", GetSpellInfo(groundMount))
        end
    end
end

-- Register the event to load saved data when the player logs in or reloads the UI
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
myFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        GetOwnedMounts()
        LoadSavedData()         -- Load saved data from MountSwitcherDB
        PopulateDropdownMenus() -- Populate dropdown menus with owned mounts
    end
end)

-- Slash command handler
local function SlashCommandHandler(msg)
    if msg == "debug" then -- Set Debug Mode -- For printing log
        if IsDebug then
            IsDebug = false
            print("Debug mode Off")
        else
            IsDebug = true
            print("Debug mode On")
            GetOwnedMounts()
        end
    end
 
    if msg == "mount" then
        OnMountButton()
    
    elseif msg == "options" then
        if myFrame:IsShown() then
            myFrame:Hide()
        else
            myFrame:Show()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Unknown command. Usage: /ms mount, /ms options")
    end
end

-- Register slash command /ms to show the frame
SLASH_MountSwitcher1 = "/ms"
SlashCmdList["MountSwitcher"] = SlashCommandHandler
