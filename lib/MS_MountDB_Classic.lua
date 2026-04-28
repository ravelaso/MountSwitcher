-- MS_MountDB_Classic.lua
-- Mount database for WoW Classic (uses C_MountJournal API)
-- This file is loaded when using MountSwitcher_Classic.toc (Interface: 40400)

local _, MS = ...

MS.MountDB = {}
local DB = MS.MountDB

DB.OwnedMounts = {}

function DB:Rebuild()
    wipe(self.OwnedMounts)

    -- Check if C_MountJournal is available (should be in Classic)
    if not C_MountJournal then
        MS:Debug("C_MountJournal not available!")
        return
    end

    -- Get player faction for filtering faction-specific mounts
    local playerFaction = UnitFactionGroup("player") -- "Horde" or "Alliance"

    -- Get all mount IDs
    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then
        MS:Debug("No mount IDs found")
        return
    end

    for i = 1, #mountIDs do
        local mountID = mountIDs[i]
        -- GetMountInfoByID returns: name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isCollected, mountID
        local name, spellID, icon, _, _, _, _, _, faction, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        
        -- Skip if no spellID or name
        if not spellID or not name then
            MS:Debug("Skipping mountID", mountID, "missing spellID or name")
            goto continue
        end

        -- Check if the mount is collected (owned by player)
        if not isCollected and not IsSpellKnown(spellID) then
            goto continue
        end

        -- Faction filtering: faction is nil for neutral mounts, 0 for Horde, 1 for Alliance?
        -- From the old code: faction == 0 (Horde), faction == 1 (Alliance)
        if faction then
            if playerFaction == "Horde" and faction ~= 0 then
                goto continue
            elseif playerFaction == "Alliance" and faction ~= 1 then
                goto continue
            end
        end

        -- Get extra info to retrieve mount type ID (for flying detection)
        local extraInfo = {C_MountJournal.GetMountInfoExtraByID(mountID)}
        local mountTypeID = extraInfo[5] -- mount type ID is the 5th return

        -- NOTE: We do NOT trust the API to classify flying vs ground.
        -- The user decides which mount goes in each slot (Slot 1 = flying zones, Slot 2 = ground).
        -- We store mountTypeID for DEBUG purposes only (developers can use /ms debug).
        -- Setting isFlying = false to match WOTLK behavior.
        local isFlying = false  -- User decides, not the API

        self.OwnedMounts[spellID] = {
            name           = name,
            spellID        = spellID,
            icon           = icon,
            isFlying       = isFlying,      -- Always false, user decides assignment
            isDruidForm    = false,
            isClassSpell   = false,
            companionIndex = mountID,       -- Keep for compatibility
            mountTypeID    = mountTypeID,   -- Stored for DEBUG only (Classic API)
        }
        MS:Debug("Mount:", name, "spellID:", spellID, "mountTypeID:", mountTypeID)

        ::continue::
    end

    -- Add class-specific spells (Druid forms, Paladin/Warlock mounts, etc.)
    local class = MS:PlayerClass()
    local classSpells = MS.CLASS_SPELL_LIST[class]

    if classSpells then
        for _, spell in ipairs(classSpells) do
            if IsSpellKnown(spell.spellID) and not self.OwnedMounts[spell.spellID] then
                -- Only inject if not already present
                self.OwnedMounts[spell.spellID] = {
                    name         = spell.name,
                    spellID      = spell.spellID,
                    icon         = spell.icon,
                    isFlying     = spell.isFlying,
                    isDruidForm  = (class == "DRUID"),
                    isClassSpell = true,
                }
                MS:Debug("Injected class spell:", spell.name, spell.spellID)
            end
        end
    end

    MountSwitcherDB.OwnedMounts = self.OwnedMounts
    MS:Debug("MountDB Classic rebuilt. Total entries:", self:CountOwnedMounts())
end

-- Helper to count owned mounts (since #table doesn't work for dictionary with spellID keys)
function DB:CountOwnedMounts()
    local count = 0
    for _ in pairs(self.OwnedMounts) do
        count = count + 1
    end
    return count
end

MS:Debug("MountDB Classic module loaded")