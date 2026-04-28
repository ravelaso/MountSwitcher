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

    -- Get all mount IDs
    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then
        MS:Debug("No mount IDs found")
        return
    end

    for _, mountID in ipairs(mountIDs) do
        local name, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        
        -- In Classic, isCollected might not be reliable; check if spell is known
        if spellID and name and (isCollected or IsSpellKnown(spellID)) then
            self.OwnedMounts[spellID] = {
                name           = name,
                spellID        = spellID,
                icon           = icon,
                isFlying       = false,   -- We'll set based on mount type later if needed
                isDruidForm    = false,
                isClassSpell   = false,
                -- companionIndex not used in Classic, but keep for compat
                companionIndex = mountID,
            }
        end
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
    MS:Debug("MountDB Classic rebuilt. Total entries:", #self.OwnedMounts)
end

MS:Debug("MountDB Classic module loaded")