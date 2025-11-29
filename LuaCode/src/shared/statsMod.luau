


local statsMod = {}


statsMod.MaxSpellDamage = 100
statsMod.MaxSpellCost = 25
statsMod.DELAY = 5.0
statsMod.MaxDamageConstant = 50

-- add enum with three types, Artificer, Primordial, None
statsMod.MagicType = {
	Artificer = "Artificer",
	Primordial = "Primordial",
    Nature = "Nature",
	None = "None"
}


statsMod.MagicLevels = {
	Artificer = {
		Level1 = {
			Abilities = "StoneManaPriest",
			Spells = "ConvertSpout" -- utility
		},
		Level2 = {
			Abilities = "ArtifactGuardian",
			Spells = "StoneFall" -- damage
		},
		Level3 = {
			Abilities = "GrandPo",
			Spells = "HardSkin"  -- buff
		},
		Level4 = {
			Abilities = "CoatArms",
			Spells = "ReviveSpirit"  -- heal
		},
		Level5 = {
			Abilities = "ArtifactProtector",
			Spells = "ReclaimPet"  -- utility
		},
		Level6 = {
			Abilities = "SuitArms",
			Spells = "StoneonFoot"  -- debuff
		},
		Level7 = {
			Abilities = "FlyingGolem",
			Spells = "Avalanche"  -- aoe damage
		}
	},
	Primordial = {
		Level1 = {
			Abilities = "MudPriest",
			Spells = "ConvertSpout"
		},
		Level2 = {
			Abilities = "Dybb",
			Spells = "DormantVirus"
		},
		Level3 = {
			Abilities = "Blob",
			Spells = "AnimatedAttacks"
		},
		Level4 = {
			Abilities = "LithEater",
			Spells = "HalfLife"
		},
		Level5 = {
			Abilities = "GemEncrustedDybb",
			Spells = "ReclaimPet"
		},
		Level6 = {
			Abilities = "GiantAmoeba",
			Spells = "GooSwamp"
		},
		Level7 = {
			Abilities = "FlyingEnergyField",
			Spells = "InhostpitableAtmosphere"
		}
	},
	Nature = {
		Level1 = {
			Abilities = "Druid",
			Spells = "ConvertSpout"
		},
		Level2 = {
			Abilities = "Pog",
			Spells = "StingingSwarm"
		},
		Level3 = {
			Abilities = "WindSpirit",
			Spells = "AgilityoftheSquirrell"
		},
		Level4 = {
			Abilities = "Silverback",
			Spells = "Regenerate"
		},
		Level5 = {
			Abilities = "GreatTuskedPog",
			Spells = "ReclaimPet"
		},
		Level6 = {
			Abilities = "Carnosaur",
			Spells = "Root"
		},
		Level7 = {
			Abilities = "Griffin",
			Spells = "NaturesDefenders"
		}
	}
	
}

statsMod.SpellInfo = {
    -- Shared
    ConvertSpout      = { manaCost = .5,  magicType = "Any",     spellType = "utility", missChance = 0, range = 20, cooldown = 5, numberTargets = 1,  effectMultiplier = 0   }, -- just converts mana, no damage/heal
    ReclaimPet        = { manaCost = .0,  magicType = "Any",     spellType = "utility", missChance = 0, range = 20,  cooldown = 5, numberTargets = 1,  effectMultiplier = 0   },

    -- Artificer
    StarterStaffArtificer         = { manaCost = 0,  magicType = "Artificer", spellType = "damage", missChance = 0, range = 20,  cooldown = 5,  numberTargets = 1,  effectMultiplier = .1   }, -- L2 single-target
    StoneFall         = { manaCost = .4,  magicType = "Artificer", spellType = "damage", missChance = 0.2, range = 20,  cooldown = 5,  numberTargets = 1, effectMultiplier = .5   }, -- L2 single-target
    HardSkin          = { manaCost = .6,  magicType = "Artificer", spellType = "buff",  missChance = 0.2,   range = 20,  cooldown = 5, numberTargets = 1,  effectMultiplier = 0.4 }, -- +40% armor/def for X sec
    ReviveSpirit      = { manaCost = .7, magicType = "Artificer", spellType = "heal",  missChance = 0.2,   range = 20,  cooldown = 5, numberTargets = 1, effectMultiplier = .15  }, -- big heal
    StoneonFoot       = { manaCost = .7,  magicType = "Artificer", spellType = "debuff", missChance = 0.2,   range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = 5   }, -- slow + small DoT
    Avalanche         = { manaCost = .8, magicType = "Artificer", spellType = "areaDamage", missChance = 0.4,  range = 20,  cooldown = 5, numberTargets = 4, effectMultiplier = .2   }, -- AOE, lower per-target

    -- Primordial
    StarterStaffPrimordial      = { manaCost = 0,  magicType = "Primordial", spellType = "damage", missChance = 0, range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = .1   }, -- L2 single-target
    DormantVirus      = { manaCost = .4,  magicType = "Primordial", spellType = "damage", missChance = 0.2, range = 20, cooldown = 5, numberTargets = 1,  effectMultiplier = .4   }, -- L2 single-target
    AnimatedAttacks   = { manaCost = .5,  magicType = "Primordial", spellType = "buff", missChance = 0.2, range = 20,  cooldown = 5, numberTargets = 1, effectMultiplier = 0.5 }, -- +50% attack speed/damage
    HalfLife          = { manaCost = .6,  magicType = "Primordial", spellType = "heal", missChance = 0.2,  range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = .15 }, -- 50% max HP reduction
    GooSwamp          = { manaCost = .7, magicType = "Primordial", spellType = "debuff", missChance = 0.2, range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = 5 },
    InhostpitableAtmosphere = { manaCost = .8, magicType = "Primordial", spellType = "areaDamage", missChance = 0.4, range = 20, cooldown = 5, numberTargets = 1,  effectMultiplier = .2 },

    -- Nature
    StarterStaffNature     = { manaCost = 0,  magicType = "Nature", spellType = "damage", missChance = 0, range = 20, cooldown = 5, numberTargets = 1,   effectMultiplier = .1   },-- L2 single-target
    StingingSwarm     = { manaCost = .4,  magicType = "Nature", spellType = "damage",  missChance = 0.2, range = 20, cooldown = 5, numberTargets = 1,  effectMultiplier = .6   },-- L2 single-target
    AgilityoftheSquirrell = { manaCost = .6, magicType = "Nature", spellType = "buff", missChance = 0.2, range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = 0.6 }, -- big speed boost
    Regenerate        = { manaCost = .6,  magicType = "Nature", spellType = "heal", missChance = 0.2,   range = 20,  cooldown = 5, numberTargets = 1,  effectMultiplier = .15  }, -- HoT or burst heal
    Root              = { manaCost = .7,  magicType = "Nature", spellType = "debuff", missChance = 0.2,   range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = 4   }, -- root + small damage
    NaturesDefenders  = { manaCost = .8, magicType = "Nature", spellType = "areaDamage", missChance = 0.4, range = 20, cooldown = 5, numberTargets = 1, effectMultiplier = .3   },
}

statsMod.StaffStats = {
    StarterStaffArtificer = {
        maxRange = 100,
        bulletSpeed = 50,
        arcHeight = 5,
        bulletTrail = "#d5d506",
        visualSize = .2,
        visualTime = .5

    },
    StarterStaffPrimordial = {
        maxRange = 100,
        bulletSpeed = 50,
        arcHeight = 5,
        bulletTrail = "#1d1674",
        visualSize = .2,
        visualTime = .5
    },
    StarterStaffNature = {
        maxRange = 100,
        bulletSpeed = 50,
        arcHeight = 5,
        bulletTrail = "#217a22",
        visualSize = .2,
        visualTime = .5
    }
}



statsMod.creatureStats = {
    -- ── None ─────────────────────────────────────────────────────
    ["PlayerNone"] = {
        magicType = "None",
        hitPoints = 10,
        attack = 0.15,
        attackDelay = 0.15,
        defense = 0.15,
        armour = 0.10,
        primordialmagicdefense = 0.15,
        artificermagicdefense = 0.15,
        naturemagicdefense = 0.15,
        speed = 0.25,
        maxDamage = 0.1,
        distanceForAttacker = 5,
        height = 2.7,
        aggroRadius = 50,
        level = 1
    },
    -- ── ARTIFICER ─────────────────────────────────────────────────────
    ["PlayerArtificer"] = {
        magicType = "Artificer",
        hitPoints = 50,
        attack = 0.25,
        attackDelay = 0.75,
        defense = 0.25,
        armour = 0.30,
        primordialmagicdefense = 0.20,
        artificermagicdefense = 0.45,
        naturemagicdefense = 0.25,
        speed = 0.25,
        maxDamage = 0.35,
        distanceForAttacker = 5,
        height = 2.7,
        aggroRadius = 50,
        level = 5
    },
    ["StoneManaPriest"] = {
        magicType = "Artificer",
        hitPoints = 50,
        attack = 0.25,
        attackDelay = 0.75,
        defense = 0.25,
        armour = 0.30,
        primordialmagicdefense = 0.20,
        artificermagicdefense = 0.45,
        naturemagicdefense = 0.25,
        speed = 0.25,
        maxDamage = 0.35,
        distanceForAttacker = 5,
        height = 2.7,
        aggroRadius = 50,
        level = 1
    },
    ["ArtifactGuardian"] = {
        magicType = "Artificer",
        hitPoints = 60,
        attack = 0.35,
        attackDelay = 0.70,
        defense = 0.35,
        armour = 0.40,
        primordialmagicdefense = 0.25,
        artificermagicdefense = 0.55,
        naturemagicdefense = 0.30,
        speed = 0.30,
        maxDamage = 0.48,
        distanceForAttacker = 5,
        height = 1,
        aggroRadius = 50,
        level = 2
    },
    ["GrandPo"] = {
        magicType = "Artificer",
        hitPoints = 70,
        attack = 0.45,
        attackDelay = 0.65,
        defense = 0.45,
        armour = 0.45,
        primordialmagicdefense = 0.30,
        artificermagicdefense = 0.60,
        naturemagicdefense = 0.35,
        speed = 0.35,
        maxDamage = 0.58,
        distanceForAttacker = 5,
        height = 2.5,
        aggroRadius = 50,
        level = 3
    },
    ["CoatArms"] = {
        magicType = "Artificer",
        hitPoints = 80,
        attack = 0.50,
        attackDelay = 0.60,
        defense = 0.55,
        armour = 0.55,
        primordialmagicdefense = 0.35,
        artificermagicdefense = 0.65,
        naturemagicdefense = 0.40,
        speed = 0.38,
        maxDamage = 0.65,
        distanceForAttacker = 5,
        height = 4.1,
        aggroRadius = 50,
        level = 4
    },
    ["ArtifactProtector"] = {
        magicType = "Artificer",
        hitPoints = 90,
        attack = 0.60,
        attackDelay = 0.55,
        defense = 0.60,
        armour = 0.60,
        primordialmagicdefense = 0.40,
        artificermagicdefense = 0.70,
        naturemagicdefense = 0.45,
        speed = 0.42,
        maxDamage = 0.75,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 5
    },
    ["SuitArms"] = {
        magicType = "Artificer",
        hitPoints = 100,
        attack = 0.70,
        attackDelay = 0.50,
        defense = 0.65,
        armour = 0.65,
        primordialmagicdefense = 0.45,
        artificermagicdefense = 0.75,
        naturemagicdefense = 0.50,
        speed = 0.48,
        maxDamage = 0.82,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 6
    },
    ["FlyingGolem"] = {
        magicType = "Artificer",
        hitPoints = 110,
        attack = 0.80,
        attackDelay = 0.45,
        defense = 0.75,
        armour = 0.70,
        primordialmagicdefense = 0.50,
        artificermagicdefense = 0.80,
        naturemagicdefense = 0.55,
        speed = 0.60,
        maxDamage = 0.90,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 7
    },

    -- ── PRIMORDIAL ───────────────────────────────────────────────────
    ["PlayerPrimordial"] = {
        magicType = "Primordial",
        hitPoints = 50,
        attack = 0.22,
        attackDelay = 0.78,
        defense = 0.28,
        armour = 0.25,
        primordialmagicdefense = 0.45,
        artificermagicdefense = 0.20,
        naturemagicdefense = 0.30,
        speed = 0.30,
        maxDamage = 0.32,
        distanceForAttacker = 5,
        height = 2.9,
        aggroRadius = 50,
        level = 5
    },
    ["MudPriest"] = {
        magicType = "Primordial",
        hitPoints = 50,
        attack = 0.22,
        attackDelay = 0.78,
        defense = 0.28,
        armour = 0.25,
        primordialmagicdefense = 0.45,
        artificermagicdefense = 0.20,
        naturemagicdefense = 0.30,
        speed = 0.30,
        maxDamage = 0.32,
        distanceForAttacker = 5,
        height = 2.9,
        aggroRadius = 50,
        level = 1
    },
    ["Dybb"] = {
        magicType = "Primordial",
        hitPoints = 60,
        attack = 0.32,
        attackDelay = 0.73,
        defense = 0.35,
        armour = 0.30,
        primordialmagicdefense = 0.55,
        artificermagicdefense = 0.25,
        naturemagicdefense = 0.35,
        speed = 0.38,
        maxDamage = 0.45,
        distanceForAttacker = 5,
        height = 2.0,
        aggroRadius = 50,
        level = 2
    },
    ["Blob"] = {
        magicType = "Primordial",
        hitPoints = 70,
        attack = 0.42,
        attackDelay = 0.68,
        defense = 0.42,
        armour = 0.38,
        primordialmagicdefense = 0.60,
        artificermagicdefense = 0.30,
        naturemagicdefense = 0.40,
        speed = 0.42,
        maxDamage = 0.55,
        distanceForAttacker = 5,
        height = 0.6,
        aggroRadius = 50,
        level = 3
    },
    ["LithEater"] = {
        magicType = "Primordial",
        hitPoints = 80,
        attack = 0.48,
        attackDelay = 0.63,
        defense = 0.50,
        armour = 0.45,
        primordialmagicdefense = 0.65,
        artificermagicdefense = 0.35,
        naturemagicdefense = 0.45,
        speed = 0.48,
        maxDamage = 0.62,
        distanceForAttacker = 5,
        height = 4.3,
        aggroRadius = 50,
        level = 4
    },
    ["GemEncrustedDybb"] = {
        magicType = "Primordial",
        hitPoints = 90,
        attack = 0.58,
        attackDelay = 0.58,
        defense = 0.58,
        armour = 0.55,
        primordialmagicdefense = 0.70,
        artificermagicdefense = 0.40,
        naturemagicdefense = 0.50,
        speed = 0.52,
        maxDamage = 0.72,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 5
    },
    ["GiantAmoeba"] = {
        magicType = "Primordial",
        hitPoints = 100,
        attack = 0.68,
        attackDelay = 0.53,
        defense = 0.65,
        armour = 0.60,
        primordialmagicdefense = 0.75,
        artificermagicdefense = 0.45,
        naturemagicdefense = 0.55,
        speed = 0.58,
        maxDamage = 0.80,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 6
    },
    ["FlyingEnergyField"] = {
        magicType = "Primordial",
        hitPoints = 110,
        attack = 0.78,
        attackDelay = 0.48,
        defense = 0.72,
        armour = 0.65,
        primordialmagicdefense = 0.80,
        artificermagicdefense = 0.50,
        naturemagicdefense = 0.60,
        speed = 0.75,
        maxDamage = 0.88,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 7
    },

    -- ── NATURE ───────────────────────────────────────────────────────
    ["PlayerNature"] = {
        magicType = "Nature",
        hitPoints = 50,
        attack = 0.20,
        attackDelay = 0.80,
        defense = 0.22,
        armour = 0.22,
        primordialmagicdefense = 0.30,
        artificermagicdefense = 0.25,
        naturemagicdefense = 0.45,
        speed = 0.40,
        maxDamage = 0.30,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 5
    },
    ["Druid"] = {
        magicType = "Nature",
        hitPoints = 50,
        attack = 0.20,
        attackDelay = 0.80,
        defense = 0.22,
        armour = 0.22,
        primordialmagicdefense = 0.30,
        artificermagicdefense = 0.25,
        naturemagicdefense = 0.45,
        speed = 0.40,
        maxDamage = 0.30,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 1
    },
    ["Pog"] = {
        magicType = "Nature",
        hitPoints = 60,
        attack = 0.30,
        attackDelay = 0.75,
        defense = 0.30,
        armour = 0.28,
        primordialmagicdefense = 0.35,
        artificermagicdefense = 0.30,
        naturemagicdefense = 0.55,
        speed = 0.55,
        maxDamage = 0.42,
        distanceForAttacker = 5,
        height = 3.0,
        aggroRadius = 50,
        level = 2
    },
    ["WindSpirit"] = {
        magicType = "Nature",
        hitPoints = 70,
        attack = 0.40,
        attackDelay = 0.70,
        defense = 0.38,
        armour = 0.35,
        primordialmagicdefense = 0.40,
        artificermagicdefense = 0.35,
        naturemagicdefense = 0.60,
        speed = 0.70,
        maxDamage = 0.52,
        distanceForAttacker = 5,
        height = 0.55,
        aggroRadius = 50,
        level = 3
    },
    ["Silverback"] = {
        magicType = "Nature",
        hitPoints = 80,
        attack = 0.48,
        attackDelay = 0.65,
        defense = 0.50,
        armour = 0.48,
        primordialmagicdefense = 0.45,
        artificermagicdefense = 0.40,
        naturemagicdefense = 0.65,
        speed = 0.60,
        maxDamage = 0.64,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 4
    },
    ["GreatTuskedPog"] = {
        magicType = "Nature",
        hitPoints = 90,
        attack = 0.58,
        attackDelay = 0.60,
        defense = 0.58,
        armour = 0.58,
        primordialmagicdefense = 0.50,
        artificermagicdefense = 0.45,
        naturemagicdefense = 0.70,
        speed = 0.68,
        maxDamage = 0.76,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 5
    },
    ["Carnosaur"] = {
        magicType = "Nature",
        hitPoints = 100,
        attack = 0.70,
        attackDelay = 0.55,
        defense = 0.68,
        armour = 0.65,
        primordialmagicdefense = 0.55,
        artificermagicdefense = 0.50,
        naturemagicdefense = 0.75,
        speed = 0.72,
        maxDamage = 0.84,
        distanceForAttacker = 5,
        height = 5,
        aggroRadius = 50,
        level = 6
    },
    ["Griffin"] = {
        magicType = "Nature",
        hitPoints = 110,
        attack = 0.80,
        attackDelay = 0.50,
        defense = 0.75,
        armour = 0.70,
        primordialmagicdefense = 0.60,
        artificermagicdefense = 0.55,
        naturemagicdefense = 0.80,
        speed = 0.80,
        maxDamage = 0.90,
        distanceForAttacker = 5,
        height = 7.3,
        aggroRadius = 50,
        level = 7
    },

    -- Feral
    ["FeralArtifactGuardian"] = {
        magicType = "Artificer",
        hitPoints = 60,
        attack = 0.85, --0.35,
        attackDelay = 0.70,
        defense = 0.35,
        armour = 0.40,
        primordialmagicdefense = 0.25,
        artificermagicdefense = 0.55,
        naturemagicdefense = 0.30,
        speed = 0.30,
        maxDamage = 1.0, -- 0.48,
        distanceForAttacker = 5,
        height = 1,
        aggroRadius = 50,
        level = 2
    }
}


return statsMod