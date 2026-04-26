-- MountSwitcher.lua
-- WOTLK 3.3.5 Compatible Version
-- Backported from Modern API to Classic 3.3.5 API

-- Declare MountSwitcherDB as a global variable
MountSwitcherDB = MountSwitcherDB or {}
MountSwitcherDB.OwnedMounts = {}
local IsDebug = false

-- Druid Flight Form definitions (spellID, name, icon, isFlying)
local DRUID_FORMS = {
    {
        spellID = 783, -- Travel Form (ground, but usable in flight areas)
        name = "Travel Form",
        icon = "Interface\\Icons\\Ability_Druid_TravelForm",
        isFlying = false,
        isDruidForm = true
    },
    {
        spellID = 33943, -- Flight Form
        name = "Flight Form",
        icon = "Interface\\Icons\\Ability_Druid_FlightForm",
        isFlying = true,
        isDruidForm = true
    },
    {
        spellID = 40120, -- Swift Flight Form (better flying speed)
        name = "Swift Flight Form",
        icon = "Interface\\Icons\\Ability_Druid_FlightForm",
        isFlying = true,
        isDruidForm = true
    }
}

-- Function to check if player is a Druid
local function IsPlayerDruid()
    local _, class = UnitClass("player")
    local isDruid = (class == "DRUID")
    if IsDebug then
        print("IsPlayerDruid: class =", class, ", isDruid =", isDruid)
    end
    return isDruid
end

-- Function to get Druid flight forms the player has learned
local function GetDruidForms()
    local forms = {}
    if IsDebug then
        print("GetDruidForms: Checking for known Druid forms...")
    end
    for _, form in ipairs(DRUID_FORMS) do
        local isKnown = IsSpellKnown(form.spellID)
        if IsDebug then
            print("  Checking", form.name, "- SpellID:", form.spellID, "- IsSpellKnown:", isKnown)
        end
        if isKnown then
            table.insert(forms, form)
            if IsDebug then
                print("    -> Added", form.name, "to forms list")
            end
        end
    end
    if IsDebug then
        print("GetDruidForms: Total forms found:", #forms)
    end
    return forms
end

-- Create the frame
local myFrame = CreateFrame("Frame", "MountSwitcherFrame", UIParent)
myFrame:SetSize(260, 220)
myFrame:SetPoint("CENTER")
myFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
myFrame:SetMovable(true)
myFrame:EnableMouse(true)
myFrame:RegisterForDrag("LeftButton")
myFrame:SetScript("OnDragStart", myFrame.StartMoving)
myFrame:SetScript("OnDragStop", myFrame.StopMovingOrSizing)
myFrame:SetScript("OnHide", myFrame.StopMovingOrSizing)
myFrame:Hide()

-- Add a close button (X button top-right corner)
local closeButton = CreateFrame("Button", nil, myFrame, "UIPanelCloseButton")
closeButton:SetSize(32, 32)
closeButton:SetPoint("TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function()
    myFrame:Hide()
end)

-- Addon Title
local title = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("MountSwitcher")
title:SetPoint("TOPLEFT", 5, -5)

-- Create dropdown menus and labels
local yOffset = -40

local flyingMountLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyingMountLabel:SetText("Flying Mount/Form:")
flyingMountLabel:SetPoint("TOPLEFT", 30, yOffset)

local flyingMountDropdown = CreateFrame("Frame", "FlyingMountDropdown", myFrame, "UIDropDownMenuTemplate")
flyingMountDropdown:SetPoint("TOPLEFT", flyingMountLabel, "BOTTOMLEFT", -20, -5)
UIDropDownMenu_SetWidth(flyingMountDropdown, 180)

yOffset = yOffset - 60

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
mountButton:SetPoint("BOTTOMLEFT", groundMountDropdown, "BOTTOMLEFT", 22, -40)

local saveButton = CreateFrame("Button", nil, myFrame, "GameMenuButtonTemplate")
saveButton:SetText("Save")
saveButton:SetSize(90, 30)
saveButton:SetPoint("LEFT", mountButton, "RIGHT", 5, 0)

-- Small Text Label
local smallTextLabel = myFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
smallTextLabel:SetText("Macro: /ms mount")
smallTextLabel:SetPoint("TOPLEFT", mountButton, "BOTTOMLEFT", 38, -10)

-- Track mount indices for 3.3.5 (companion index, not spell ID)
local flyingMountIndex = nil
local groundMountIndex = nil

-- Function to save the input data
local function SaveData()
    MountSwitcherDB = MountSwitcherDB or {}

    -- Save by spellID (works for both regular mounts and Druid forms)
    if flyingMountIndex and MountSwitcherDB.OwnedMounts[flyingMountIndex] then
        MountSwitcherDB["FlyingMountSpellID"] = MountSwitcherDB.OwnedMounts[flyingMountIndex].spellID
    end

    if groundMountIndex and MountSwitcherDB.OwnedMounts[groundMountIndex] then
        MountSwitcherDB["GroundMountSpellID"] = MountSwitcherDB.OwnedMounts[groundMountIndex].spellID
    end

    DEFAULT_CHAT_FRAME:AddMessage("Mounts saved! :)")
    if IsDebug then
        print("Saved Fly SpellID - ", MountSwitcherDB["FlyingMountSpellID"])
        print("Saved Ground SpellID - ", MountSwitcherDB["GroundMountSpellID"])
    end
end

-- Function to get all mounts that the player owns (3.3.5 API)
local function GetOwnedMounts()
    MountSwitcherDB = MountSwitcherDB or {}
    MountSwitcherDB.OwnedMounts = {}

    local numCompanions = GetNumCompanions("MOUNT")

    if IsDebug then
        print("Total mounts found:", numCompanions)
    end

    for i = 1, numCompanions do
        -- 3.3.5 API: GetCompanionInfo("type", index)
        -- Returns: creatureID, creatureName, creatureSpellID, icon, issummoned, mountTypeID
        local creatureID, creatureName, creatureSpellID, icon, issummoned, mountTypeID = GetCompanionInfo("MOUNT", i)

        -- Handle case where mountTypeID is nil (some mounts don't return it)
        -- Default to ground mount if mountTypeID is nil
        local isFlying = false
        if mountTypeID then
            -- mountTypeID in 3.3.5 is a bitmask:
            -- bit.band(mountTypeID, 3) == 0 : Water mount
            -- bit.band(mountTypeID, 3) == 1 : Ground mount
            -- bit.band(mountTypeID, 3) == 3 : Flying mount
            isFlying = (bit.band(mountTypeID, 3) == 3)
        end

        -- Store by spellID as key (stable, works for both regular mounts and Druid forms)
        MountSwitcherDB.OwnedMounts[creatureSpellID] = {
            name = creatureName,
            spellID = creatureSpellID,
            icon = icon,
            isFlying = isFlying,
            mountTypeID = mountTypeID,
            isDruidForm = false,
            companionIndex = i
        }

        if IsDebug then
            local typeString = isFlying and "Flying" or "Ground/Water"
            print("Found Mount [" .. i .. "]:", creatureName, "-", typeString, "- SpellID:", creatureSpellID)
        end
    end

    -- Add Druid flight forms if player is a Druid
    if IsPlayerDruid() then
        if IsDebug then
            print("GetOwnedMounts: Player is a Druid, getting flight forms...")
        end
        local druidForms = GetDruidForms()
        if IsDebug then
            print("GetOwnedMounts: druidForms returned", #druidForms, "forms")
        end
        for _, form in ipairs(druidForms) do
            MountSwitcherDB.OwnedMounts[form.spellID] = {
                name = form.name,
                spellID = form.spellID,
                icon = form.icon,
                isFlying = form.isFlying,
                mountTypeID = nil,
                isDruidForm = true,
                companionIndex = nil
            }

            if IsDebug then
                local typeString = form.isFlying and "Flying Druid Form" or "Ground Druid Form"
                print("Added Druid form:", form.name, "-", typeString, "- SpellID:", form.spellID)
            end
        end
    end
end

-- Set the OnClick script of the Save button to our SaveData function
saveButton:SetScript("OnClick", SaveData)

-- Function to be executed when the button is clicked
local function OnMountButton()
    local flySpellID = MountSwitcherDB["FlyingMountSpellID"]
    local groundSpellID = MountSwitcherDB["GroundMountSpellID"]

    local function UseMount(spellID)
        if not spellID then
            return false
        end

        local mountData = MountSwitcherDB.OwnedMounts[spellID]
        if not mountData then
            return false
        end

        if IsDebug then
            print("Using mount:", mountData.name, "- isDruidForm:", mountData.isDruidForm)
        end

        if mountData.isDruidForm then
            -- Druid forms: cannot cast from addon, show message
            DEFAULT_CHAT_FRAME:AddMessage("MountSwitcher: Druid forms cannot be auto-cast by the addon. Please use a manual macro.")
            return true
        else
            -- Regular mounts use CallCompanion
            CallCompanion("MOUNT", mountData.companionIndex)
            return true
        end
    end

    -- 3.3.5 API: CallCompanion("MOUNT", index)
    if (GetZoneText() == "Dalaran") then
        if (GetSubZoneText() == "Krasus' Landing") then
            if not UseMount(flySpellID) then
                UseMount(groundSpellID)
            end
        else
            UseMount(groundSpellID)
        end
    elseif IsFlyableArea() then
        if not UseMount(flySpellID) then
            UseMount(groundSpellID)
        end
    else
        UseMount(groundSpellID)
    end
end

-- Set the OnClick script of the button to our function
mountButton:SetScript("OnClick", OnMountButton)

-- Function to populate the dropdown menus with owned mounts (3.3.5 API)
local function PopulateDropdownMenus()
    local flyingCount = 0
    local groundCount = 0

    UIDropDownMenu_Initialize(flyingMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for spellID, mountData in pairs(ownedMounts) do
                if IsDebug then
                    print("PopulateDropdownMenus: Checking", mountData.name, "- isFlying:", mountData.isFlying, "- isDruidForm:", mountData.isDruidForm)
                end
                if mountData.isFlying then -- Only flying mounts
                    flyingCount = flyingCount + 1
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = mountData.name .. (mountData.isDruidForm and " (Druid)" or "")
                    info.value = spellID
                    info.icon = mountData.icon
                    info.func = function(self)
                        UIDropDownMenu_SetSelectedValue(flyingMountDropdown, self.value)
                        UIDropDownMenu_SetText(flyingMountDropdown, self:GetText())
                        flyingMountIndex = self.value
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
        if IsDebug then
            print("PopulateDropdownMenus: Added", flyingCount, "flying mounts to dropdown")
        end
    end)

    UIDropDownMenu_Initialize(groundMountDropdown, function(self, level)
        local ownedMounts = MountSwitcherDB.OwnedMounts
        if ownedMounts then
            for spellID, mountData in pairs(ownedMounts) do
                if not mountData.isFlying then -- Only ground/water mounts
                    groundCount = groundCount + 1
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = mountData.name .. (mountData.isDruidForm and " (Druid)" or "")
                    info.value = spellID
                    info.icon = mountData.icon
                    info.func = function(self)
                        UIDropDownMenu_SetSelectedValue(groundMountDropdown, self.value)
                        UIDropDownMenu_SetText(groundMountDropdown, self:GetText())
                        groundMountIndex = self.value
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
        if IsDebug then
            print("PopulateDropdownMenus: Added", groundCount, "ground mounts to dropdown")
        end
    end)
end

-- Function to load the saved data and update the dropdown menus
local function LoadSavedData()
    local flySpellID = MountSwitcherDB and MountSwitcherDB["FlyingMountSpellID"] or nil
    local groundSpellID = MountSwitcherDB and MountSwitcherDB["GroundMountSpellID"] or nil

    -- Update the dropdown menus and select the correct items
    if flySpellID and MountSwitcherDB.OwnedMounts[flySpellID] then
        local mountData = MountSwitcherDB.OwnedMounts[flySpellID]
        UIDropDownMenu_SetSelectedValue(flyingMountDropdown, flySpellID)
        UIDropDownMenu_SetText(flyingMountDropdown, mountData.name)
        flyingMountIndex = flySpellID
    end

    if groundSpellID and MountSwitcherDB.OwnedMounts[groundSpellID] then
        local mountData = MountSwitcherDB.OwnedMounts[groundSpellID]
        UIDropDownMenu_SetSelectedValue(groundMountDropdown, groundSpellID)
        UIDropDownMenu_SetText(groundMountDropdown, mountData.name)
        groundMountIndex = groundSpellID
    end

    if IsDebug then
        print("Loaded Flying Mount SpellID:", flySpellID)
        print("Loaded Ground Mount SpellID:", groundSpellID)
    end
end

-- Track whether mounts have been loaded
local mountsLoaded = false
local initDelayFrames = 0

-- Function to initialize everything after mounts are available
local function InitializeMountSwitcher(forceReload)
    if mountsLoaded and not forceReload then
        if IsDebug then
            print("InitializeMountSwitcher: Already loaded, skipping")
        end
        return
    end

    local numCompanions = GetNumCompanions("MOUNT")
    if IsDebug then
        print("InitializeMountSwitcher: numCompanions =", numCompanions or "nil")
    end

    -- Clear existing mounts if force reloading
    if forceReload then
        MountSwitcherDB.OwnedMounts = {}
        mountsLoaded = false
    end

    if numCompanions and numCompanions >= 0 then
        if IsDebug then
            print("InitializeMountSwitcher: Calling GetOwnedMounts...")
        end
        GetOwnedMounts()

        local mountCount = 0
        for _ in pairs(MountSwitcherDB.OwnedMounts) do mountCount = mountCount + 1 end
        if IsDebug then
            print("InitializeMountSwitcher: OwnedMounts table has", mountCount, "entries")
        end

        if IsDebug then
            print("InitializeMountSwitcher: Calling LoadSavedData...")
        end
        LoadSavedData()

        if IsDebug then
            print("InitializeMountSwitcher: Calling PopulateDropdownMenus...")
        end
        PopulateDropdownMenus()

        mountsLoaded = true

        if IsDebug then
            print("InitializeMountSwitcher: Done!")
        end
    end
end

-- OnUpdate script for delayed initialization
myFrame:SetScript("OnUpdate", function(self, elapsed)
    if not mountsLoaded then
        initDelayFrames = initDelayFrames + 1
        -- Try initializing after ~1 second (assuming 60fps, that's ~60 frames)
        if initDelayFrames >= 60 then
            InitializeMountSwitcher()
        end
    end
end)

-- Register the event to load saved data when the player logs in or reloads the UI
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
myFrame:RegisterEvent("COMPANION_LEARNED") -- Fires when a new mount is learned
myFrame:RegisterEvent("COMPANION_UNLEARNED") -- Fires when a mount is unlearned
myFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Try to initialize immediately first
        InitializeMountSwitcher()
    elseif event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" then
        -- Refresh mount list when mounts change
        GetOwnedMounts()
        PopulateDropdownMenus()
    end
end)

-- Slash command handler
local function SlashCommandHandler(msg)
    msg = strlower(msg) -- Normalize to lowercase

    if msg == "debug" then
        if IsDebug then
            IsDebug = false
            print("Debug mode Off")
        else
            IsDebug = true
            print("Debug mode On - Reloading mounts...")
            InitializeMountSwitcher(true) -- Force reload with debug
        end
    elseif msg == "mount" then
        OnMountButton()
    elseif msg == "options" then
        if myFrame:IsShown() then
            myFrame:Hide()
        else
            myFrame:Show()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("MountSwitcher - Usage:")
        DEFAULT_CHAT_FRAME:AddMessage("/ms mount - Summon your selected mount")
        DEFAULT_CHAT_FRAME:AddMessage("/ms options - Open/close options panel")
        DEFAULT_CHAT_FRAME:AddMessage("/ms debug - Toggle debug mode")
    end
end

-- Register slash command /ms (3.3.5 compatible syntax)
SLASH_MountSwitcher1 = "/ms"
SlashCmdList["MountSwitcher"] = SlashCommandHandler