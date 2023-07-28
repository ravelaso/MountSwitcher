-- MountSwitcher.lua
-- Declare MountSwitcherDB as a global variable
MountSwitcherDB = MountSwitcherDB or {}

-- Create the frame
local myFrame = CreateFrame("Frame", "MountSwitcherFrame", UIParent, "BasicFrameTemplate")
myFrame:SetSize(240, 200) -- Adjusted the frame size to fit the items
myFrame:SetPoint("CENTER")
myFrame:SetMovable(true)
myFrame:EnableMouse(true)
myFrame:RegisterForDrag("LeftButton")
myFrame:SetScript("OnDragStart", myFrame.StartMoving)
myFrame:SetScript("OnDragStop", myFrame.StopMovingOrSizing)
myFrame:SetScript("OnHide", myFrame.StopMovingOrSizing)

-- Addon Title
local title = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("MountSwitcher")
title:SetPoint("TOPLEFT", 5, -5) -- Center the title at the top of the frame

-- Create text inputs and labels
local yOffset = -30 -- Adjust the vertical offset for each item

local flyingMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyingMountLabel:SetText("Flying Mount Name:")
flyingMountLabel:SetPoint("TOPLEFT", 20, yOffset)

local flyingMountInput = CreateFrame("EditBox", nil, myFrame, "InputBoxTemplate")
flyingMountInput:SetAutoFocus(false)
flyingMountInput:SetSize(200, 20)                                           -- Smaller height for the input
flyingMountInput:SetPoint("TOPLEFT", flyingMountLabel, "BOTTOMLEFT", 0, -5) -- Align below the label

yOffset = yOffset - 40                                                      -- Increase the offset for the next item

local groundMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundMountLabel:SetText("Ground Mount Name:")
groundMountLabel:SetPoint("TOPLEFT", 20, yOffset)

local groundMountInput = CreateFrame("EditBox", nil, myFrame, "InputBoxTemplate")
groundMountInput:SetAutoFocus(false)
groundMountInput:SetSize(200, 20)                                           -- Smaller height for the input
groundMountInput:SetPoint("TOPLEFT", groundMountLabel, "BOTTOMLEFT", 0, -5) -- Align below the label

yOffset = yOffset - 30

-- Create the buttons
local mountButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
mountButton:SetText("Mount!")
mountButton:SetSize(95, 30)
mountButton:SetPoint("BOTTOMLEFT", groundMountInput, "BOTTOMLEFT", 0, -35) -- Position the button below the flyingMountInput with a bit of margin

local saveButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
saveButton:SetText("Save")
saveButton:SetSize(95, 30)
saveButton:SetPoint("LEFT", mountButton, "RIGHT", 5, 0) -- Position the Save button on the right side of the mountButton

-- Small Text Label
local smallTextLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
smallTextLabel:SetText("Macro: /ms mount")
smallTextLabel:SetPoint("TOPLEFT", mountButton, "BOTTOMLEFT", 38, -10) -- Center the smallTextLabel below the row of buttons

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
