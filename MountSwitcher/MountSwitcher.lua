-- MySimpleAddon.lua
-- Declare MountSwitcherDB as a global variable
MountSwitcherDB = MountSwitcherDB or {}

-- Create the frame
local myFrame = CreateFrame("Frame", "MySimpleAddonFrame", UIParent, "BasicFrameTemplate")
myFrame:SetSize(200, 200) -- Adjusted the frame size to accommodate the smaller items
myFrame:SetPoint("CENTER")
myFrame:SetMovable(true)
myFrame:EnableMouse(true)
myFrame:RegisterForDrag("LeftButton")
myFrame:SetScript("OnDragStart", myFrame.StartMoving)
myFrame:SetScript("OnDragStop", myFrame.StopMovingOrSizing)
myFrame:SetScript("OnHide", myFrame.StopMovingOrSizing)

-- Create text inputs and labels
local yOffset = -40 -- Adjust the vertical offset for each item

local flyingMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyingMountLabel:SetText("Flying Mount Name:")
flyingMountLabel:SetPoint("TOPLEFT", 20, yOffset)

local flyingMountInput = CreateFrame("EditBox", nil, myFrame, "InputBoxTemplate")
flyingMountInput:SetAutoFocus(false)
flyingMountInput:SetSize(150, 20)                                           -- Smaller height for the input
flyingMountInput:SetPoint("TOPLEFT", flyingMountLabel, "BOTTOMLEFT", 0, -5) -- Align below the label

yOffset = yOffset - 40                                                      -- Increase the offset for the next item

local groundMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundMountLabel:SetText("Ground Mount Name:")
groundMountLabel:SetPoint("TOPLEFT", 20, yOffset)

local groundMountInput = CreateFrame("EditBox", nil, myFrame, "InputBoxTemplate")
groundMountInput:SetAutoFocus(false)
groundMountInput:SetSize(150, 20)                                           -- Smaller height for the input
groundMountInput:SetPoint("TOPLEFT", groundMountLabel, "BOTTOMLEFT", 0, -5) -- Align below the label

yOffset = yOffset - 20
-- Create the button
local mountButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
mountButton:SetText("Mount!")
mountButton:SetSize(100, 30)
mountButton:SetPoint("TOPLEFT", groundMountInput, "BOTTOMLEFT", 0, -10) -- Position the button below the inputs

-- Create the Save button
local saveButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
saveButton:SetText("Save")
saveButton:SetSize(100, 30)
saveButton:SetPoint("TOPLEFT", mountButton, "BOTTOMLEFT", 0, -10) -- Position the Save button below the "Mount!" button
-- Increase the offset for the next item


-- Function to save the input data
local function SaveData()
    -- Save the data using SavedVariables
    MountSwitcherDB = MountSwitcherDB or {} -- Create the table if it doesn't exist
    MountSwitcherDB["FlyingMount"] = flyingMountInput:GetText()
    MountSwitcherDB["GroundMount"] = groundMountInput:GetText()

    DEFAULT_CHAT_FRAME:AddMessage("Data saved!")
end

-- Set the OnClick script of the Save button to our SaveData function
saveButton:SetScript("OnClick", SaveData)

-- Function to be executed when the button is clicked
local function OnMountButton()
    if (GetZoneText() == "Dalaran") then
        if (GetSubZoneText() == "Krasus' Landing") then
            CastSpellByName(MountSwitcherDB["FlyingMount"])
            DEFAULT_CHAT_FRAME:AddMessage("You´re in Krasus' Landing, using flying mount")
        else
            CastSpellByName(MountSwitcherDB["GroundMount"])
            DEFAULT_CHAT_FRAME:AddMessage("You´re in Dalaran, using ground mount")
        end
    elseif IsFlyableArea() then
        CastSpellByName(MountSwitcherDB["FlyingMount"])
        DEFAULT_CHAT_FRAME:AddMessage("You can fly here, using fly mount")
    else
        CastSpellByName(MountSwitcherDB["GroundMount"])
        DEFAULT_CHAT_FRAME:AddMessage("You can not fly here, using ground mount")
    end
end
-- Set the OnClick script of the button to our function
mountButton:SetScript("OnClick", OnMountButton)

-- Function to load the saved data and update the input fields
local function LoadSavedData()
    -- Retrieve the data from SavedVariables
    flyingMountInput:SetText(MountSwitcherDB and MountSwitcherDB["FlyingMount"] or "")
    groundMountInput:SetText(MountSwitcherDB and MountSwitcherDB["GroundMount"] or "")

    -- Check if the frame should be shown or hidden
    if not MountSwitcherDB.ShowFrame then
        myFrame:Hide()
    end
end

local function PerformAction()
    if (GetZoneText() == "Dalaran") then
        if (GetSubZoneText() == "Krasus' Landing") then
            CastSpellByName(MountSwitcherDB["FlyingMount"])
        else
            CastSpellByName(MountSwitcherDB["GroundMount"])
        end
    elseif IsFlyableArea() then
        CastSpellByName(MountSwitcherDB["FlyingMount"])
    else
        CastSpellByName(MountSwitcherDB["GroundMount"])
    end
end

-- Register the event to load saved data when the player logs in or reloads the UI
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
myFrame:SetScript("OnEvent", LoadSavedData)

-- Slash command handler
local function SlashCommandHandler(msg)
    if msg == "mount" then
        PerformAction()
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
