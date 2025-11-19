
local combatMod = {}

-- add enum with three types, Artificer, Primordial, None
combatMod.MagicType = {
	Artificer = "Artificer",
	Primordial = "Primordial",
	None = "None"
}

combatMod.MagicLevels = {
	Artificer = {
		Level1 = {
			Abilities = "StoneManaPriest",
			Spells = "Staff"
		},
		Level2 = {
			Abilities = "ArtifactGuardian",
			Spells = "Nuke"
		},
		Level3 = {
			Abilities = "GrandPo",
			Spells = "Buff"
		},
		Level4 = {
			Abilities = "CoatArms",
			Spells = "Heal"
		},
		Level5 = {
			Abilities = "ArtifactProtector",
			Spells = "Aoe"
		},
		Level6 = {
			Abilities = "SuitArms",
			Spells = "Root"
		},
		Level7 = {
			Abilities = "FlyingGolem",
			Spells = "Aoe2"
		}
	},
	Primordial = {
		Level1 = {
			Abilities = "MudPriest",
			Spells = "Staff"
		},
		Level2 = {
			Abilities = "Dybb",
			Spells = "Nuke"
		},
		Level3 = {
			Abilities = "Blob",
			Spells = "Buff"
		},
		Level4 = {
			Abilities = "LithEater",
			Spells = "Heal"
		},
		Level5 = {
			Abilities = "GemEncrustedDybb",
			Spells = "Aoe"
		},
		Level6 = {
			Abilities = "GiantAmoeba",
			Spells = "Root"
		},
		Level7 = {
			Abilities = "FlyingEnergyField",
			Spells = "Aoe2"
		}
	},
	Nature = {
		Level1 = {
			Abilities = "Druid",
			Spells = "Staff"
		},
		Level2 = {
			Abilities = "Pog",
			Spells = "Nuke"
		},
		Level3 = {
			Abilities = "WindSpirit",
			Spells = "Buff"
		},
		Level4 = {
			Abilities = "Silverback",
			Spells = "Heal"
		},
		Level5 = {
			Abilities = "GreatTuskedPog",
			Spells = "Aoe"
		},
		Level6 = {
			Abilities = "Carnosaur",
			Spells = "Root"
		},
		Level7 = {
			Abilities = "Griffin",
			Spells = "Aoe2"
		}
	}
	
}

combatMod.StaffStats = {
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

combatMod.DELAY = 5.0

combatMod.creatureStats = {
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
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
        aggroRadius = 50
    }
}


function combatMod.MeleeAttackResult(attacker, defender)

    -- MISS CHANCE CALCULATION (15% floor, 30% ceiling)
    local defenseAdvantage = defender.defense - attacker.attack
    local missChance = math.clamp(defenseAdvantage * 25, 0.15, 0.30)
    local MAXDAMAGECONSTANT = 50
    
    -- Roll for miss
    if math.random() < missChance then
        return 0  -- Complete miss!
    end

    -- Base damage from attack stat
    local baseDamage = attacker.attack * MAXDAMAGECONSTANT

    -- Max possible damage cap
    local maxPossibleDamage = attacker.maxDamage * (MAXDAMAGECONSTANT * 1.5)

    -- Defense reduces damage (diminishing returns)
    local defenseReduction = defender.defense * 12
    local damageAfterDefense = math.max(baseDamage - defenseReduction, baseDamage * 0.3)

    -- Armour reduces percentage of remaining damage
    local armourReduction = defender.armour
    local damageAfterArmour = damageAfterDefense * (1 - armourReduction)

    -- Final calculated damage: clamp between 1 and maxPossibleDamage
    local calculatedDamage = math.clamp(damageAfterArmour, 1, maxPossibleDamage)

    -- **RANDOM DAMAGE MULTIPLIER** (50% to 100% of calculated damage)
    local damageMultiplier = math.random() * 0.5 + 0.5  -- 0.5 to 1.0
    local finalDamage = calculatedDamage * damageMultiplier

    -- Ensure minimum 1 damage
    finalDamage = math.clamp(finalDamage, 1, maxPossibleDamage)

    -- Return as integer
    return math.floor(finalDamage + 0.5)
end

function combatMod.ShallowTableCopy(name)
    local trimmed = combatMod.customTrim(tostring(name))
    local t = combatMod.creatureStats[trimmed]
    if not t then
        print(trimmed)
        warn(name)
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

-- Put this in your combatMod (or wherever you keep utilities)
function combatMod.customTrim(input: string?): string
    if typeof(input) ~= "string" then
        return ""
    end

    -- Remove trailing underscore + any non-empty sequence of alphanumeric characters
    -- Also removes a lone trailing underscore
    return input:gsub("_[%w]*$", "")
end

return combatMod