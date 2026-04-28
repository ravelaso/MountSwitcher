local _, MS = ...

MS.MountDB = {}
local DB = MS.MountDB

DB.OwnedMounts = {}

function DB:Rebuild()
    wipe(self.OwnedMounts)

    -- 1. All companion mounts with all required fields
    local total = GetNumCompanions("MOUNT") or 0
    for i = 1, total do
        local _, name, spellID, icon = GetCompanionInfo("MOUNT", i)
        if spellID and name then
            self.OwnedMounts[spellID] = {
                name           = name,
                spellID        = spellID,
                icon           = icon,
                isFlying       = false,   -- unused for filtering; kept for compat
                isDruidForm    = false,
                isClassSpell   = false,
                companionIndex = i,
            }
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
                    isFlying     = spell.isFlying,
                    isDruidForm  = (class == "DRUID"),
                    isClassSpell = true,
                }
                MS:Debug("Injected class spell:", spell.name, spell.spellID)
            end
        end
    end
    
    MountSwitcherDB.OwnedMounts = self.OwnedMounts
    MS:Debug("Mount DB rebuilt. Total entries:", #self.OwnedMounts)
end