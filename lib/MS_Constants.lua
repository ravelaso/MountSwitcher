local _, MS = ...

-- ============================================================
-- CLASS SPELLS (MOUNTS)
-- ============================================================


MS.CLASS_SPELL_LIST = {
    PALADIN = {
        { spellID = 33391, name = "Summon Charger",       icon = "Interface\\Icons\\Spell_Holy_SummonCharger",    isFlying = false },
        -- Summon Warhorse (13819) is almost always in companion list; add only as fallback
        { spellID = 13819, name = "Summon Warhorse",      icon = "Interface\\Icons\\Spell_Holy_SummonCharger",    isFlying = false },
    },
    WARLOCK = {
        { spellID = 23161, name = "Summon Dreadsteed",    icon = "Interface\\Icons\\Spell_Shadow_SummonFelsteed", isFlying = false },
        -- Summon Felsteed (5784) is almost always in companion list; add only as fallback
        { spellID =  5784, name = "Summon Felsteed",      icon = "Interface\\Icons\\Spell_Shadow_SummonFelsteed", isFlying = false },
    },
    DEATHKNIGHT = {
        { spellID = 48778, name = "Acherus Deathcharger", icon = "Interface\\Icons\\Ability_Mount_Deathknight",   isFlying = false },
    },
    DRUID = {
        { spellID =   783, name = "Travel Form",          icon = "Interface\\Icons\\Ability_Druid_TravelForm",    isFlying = false },
        { spellID = 33943, name = "Flight Form",          icon = "Interface\\Icons\\Ability_Druid_FlightForm",    isFlying = true  },
        { spellID = 40120, name = "Swift Flight Form",    icon = "Interface\\Icons\\Ability_Druid_FlightForm",    isFlying = true  },
    },
}