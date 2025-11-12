


local magicMod = {}

-- add enum with three types, Artificer, Primordial, None
magicMod.MagicType = {
	Artificer = "Artificer",
	Primordial = "Primordial",
	None = "None"
}

magicMod.MagicLevels = {
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
			Abilities = "Protector",
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
			Abilities = "Protector",
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
	}
	
}





return magicMod