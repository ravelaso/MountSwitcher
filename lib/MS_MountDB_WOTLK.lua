local _, MS = ...

MS.MountDB = {}
local DB = MS.MountDB

DB.OwnedMounts = {}

function DB:Rebuild()
    wipe(self.OwnedMounts)

    -- 1. All companion mounts with all required fields
    local total = GetNumCompanions("MOUNT") or 0
    for i = 1, total do
        local _, name, spellID, icon, _, mountType = GetCompanionInfo("MOUNT", i)
        if spellID and name then
            -- NOTE: We do NOT trust the API to classify flying vs ground.
            -- The user decides which mount goes in each slot (Slot 1 = flying zones, Slot 2 = ground).
            -- We store mountType for DEBUG purposes only (developers can use /ms debug).
            self.OwnedMounts[spellID] = {
                name           = name,
                spellID        = spellID,
                icon           = icon,
                isFlying       = false,   -- User decides, not the API
                isDruidForm    = false,
                isClassSpell   = false,
                companionIndex = i,
                mountTypeID    = mountType, -- WOTLK API provides mountType (bitfield: 0x2 = can fly)
            }
            MS:Debug("Mount:", name, "spellID:", spellID, "mountType:", mountType)
        end
    end

    -- 2. Class-specific spells (Druid forms, Paladin/Warlock mounts, DK mount, etc.)
    local class = MS:PlayerClass()
    local classSpells = MS.CLASS_SPELL_LIST[class]

    if classSpells then
        for _, spell in ipairs(classSpells) do
            if IsSpellKnown(spell.spellID) and not self.OwnedMounts[spell.spellID] then
                -- Only inject if not already present from GetCompanionInfo
                self.OwnedMounts[spell.spellID] = {
                    name         = spell.name,
                    spellID      = spell.spellID,
                    icon         = spell.icon,
                    isFlying     = spell.isFlying,  -- From CLASS_SPELL_LIST for debug
                    isDruidForm  = (class == "DRUID"),
                    isClassSpell = true,
                    mountTypeID  = nil,            -- WOTLK API does NOT provide mount type ID
                }
                MS:Debug("Injected class spell:", spell.name, spell.spellID, "isFlying:", spell.isFlying)
            end
        end
    end
    
    MountSwitcherDB.OwnedMounts = self.OwnedMounts
    MS:Debug("Mount DB rebuilt. Total entries:", self:CountOwnedMounts())
end

-- Helper to count owned mounts (since #table doesn't work for dictionary with spellID keys)
function DB:CountOwnedMounts()
    local count = 0
    for _ in pairs(self.OwnedMounts) do
        count = count + 1
    end
    return count
end