--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local statsMod = require(ReplicatedStorage.Shared.statsMod)
export type explosionMod = {
	GetConfig: (key: string) -> ExplosionConfig,
}

export type ExplosionConfig = {
	Lifetime: number,
	Color: Color3,

	Texture: string,
	LightEmission: number,
	LightInfluence: number,
	Orientation: Enum.ParticleOrientation,

	Transparency: NumberSequence,
	Squash: NumberSequence,
	Size: NumberSequence,

	ZOffset: number,
	Rate: number,
	Speed: NumberRange,
	SpreadAngle: Vector2,
	EmissionDirection: Enum.NormalId,
	Rotation: NumberRange,
	RotSpeed: NumberRange,
	Shape: Enum.ParticleEmitterShape,
	ShapeInOut: Enum.ParticleEmitterShapeInOut,
	ShapeStyle: Enum.ParticleEmitterShapeStyle,
	ShapePartial: number,

	BurstCount: number,
	EnableDelay: number,
	DebrisLifetime: number,
}

local explosionMod = {}

-- Deep copy function (handles tables recursively, but not functions/metatables for simplicity)
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Table for custom overrides (partial configs that merge into default)
explosionMod.Overrides = {}

-- Public API: Register a new explosion type with overrides
-- overrideTable: A table with only the properties you want to change (e.g. { Color = ..., Squash = ... })
function RegisterExplosion(key: string, overrideTable: any)
	if explosionMod.Overrides[key] then
		warn("Overwriting existing explosion override for key:", key)
	end
	explosionMod.Overrides[key] = overrideTable
end

-- Public API: Get the full config for an explosion key
-- Merges default with overrides (if any), and returns a fresh copy
function explosionMod.GetConfig(key: string): ExplosionConfig
	local config: ExplosionConfig = {
		Lifetime = 1.5,
		Color = Color3.fromHex("#222222"), -- Default yellow-ish

		-- ParticleEmitter properties
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		LightEmission = 0.6,
		LightInfluence = 1.0,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,

		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Squash = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 5),
			NumberSequenceKeypoint.new(1, 1),
		}),

		ZOffset = 0,
		Rate = 500,
		Speed = NumberRange.new(5, 5),
		SpreadAngle = Vector2.new(45, 45),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(-45, 45),
		RotSpeed = NumberRange.new(-90, 90),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapePartial = 1,

		-- Burst behavior
		BurstCount = 100,
		EnableDelay = 0.2,
		DebrisLifetime = 1.5,
	}

	local override = explosionMod.Overrides[key]
	if override then
		for k, v in pairs(override) do
			config[k] = deepCopy(v) -- Deep copy overrides to avoid shared references
		end
	end

	return config :: ExplosionConfig
end

-- starters
RegisterExplosion("naturestarterbomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.2),
	}),
	--Texture = "rbxassetid://112468401764349",
	Lifetime = 0.5,
	ZOffset = 1,
})

RegisterExplosion("artificerstarterbomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.2),
	}),

	--Texture = "rbxassetid://112468401764349",
	Lifetime = 0.5,
	ZOffset = 1,
})

RegisterExplosion("primordialstarterbomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.2),
	}),

	--Texture = "rbxassetid://112468401764349",
	Lifetime = 0.5,
	ZOffset = 1,
})

-- medium staffs
RegisterExplosion("primordialmediumbomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 0.9,
	ZOffset = 1,
})

RegisterExplosion("naturemediumbomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 0.9,
	ZOffset = 1,
})

RegisterExplosion("artificermediumbomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 0.9,
	ZOffset = 1,
})

-- major wands
RegisterExplosion("primordialmajorbomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 1.2,
	ZOffset = 1,
})

RegisterExplosion("naturemajorbomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 1.2,
	ZOffset = 1,
})

RegisterExplosion("artificermajorbomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),

	Texture = "rbxassetid://112468401764349",
	Lifetime = 1.2,
	ZOffset = 1,
})

-- rods
RegisterExplosion("primordialmajor1bomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1.9),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 1.0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.3),
	}),
	Speed = NumberRange.new(5, 10),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://79043863870129",
	Lifetime = 0.5,
	ZOffset = 1,
})

RegisterExplosion("naturemajor1bomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1.9),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 1.0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.3),
	}),
	Speed = NumberRange.new(5, 10),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://79043863870129",
	Lifetime = 0.5,
	ZOffset = 1,
})

RegisterExplosion("artificermajor1bomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1.9),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 1.0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.3),
	}),
	Speed = NumberRange.new(5, 10),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://79043863870129",
	Lifetime = 0.5,
	ZOffset = 1,
})

-- wands
RegisterExplosion("primordialmajor2bomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1.5),
		NumberSequenceKeypoint.new(1, 3),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(3, 6),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://122159530593272",

	Lifetime = 0.4,
	ZOffset = 1,
})

RegisterExplosion("naturemajor2bomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1.5),
		NumberSequenceKeypoint.new(1, 3),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(3, 6),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://122159530593272",

	Lifetime = 0.4,
	ZOffset = 1,
})

RegisterExplosion("artificermajor2bomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1.5),
		NumberSequenceKeypoint.new(1, 3),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(3, 6),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://122159530593272",

	Lifetime = 0.4,
	ZOffset = 1,
})

-- staffs
RegisterExplosion("primordialmajor3bomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(1, 4),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://100508899001107",
	Lifetime = 0.4,
	ZOffset = 1,
	Rate = 1000,
	BurstCount = 200,
})

RegisterExplosion("naturemajor3bomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(1, 4),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://100508899001107",
	Lifetime = 0.4,
	ZOffset = 1,
	Rate = 1000,
	BurstCount = 200,
})

RegisterExplosion("artificermajor3bomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	Speed = NumberRange.new(1, 4),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://100508899001107",
	Lifetime = 0.4,
	ZOffset = 1,
	Rate = 1000,
	BurstCount = 200,
})

-- scepters
RegisterExplosion("primordialmajor4bomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),
	Speed = NumberRange.new(1, 3),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://73621565802849",
	Lifetime = 0.2,
	ZOffset = 1,
	Rate = 150,
	BurstCount = 50,
})

RegisterExplosion("naturemajor4bomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),
	Speed = NumberRange.new(1, 3),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://73621565802849",
	Lifetime = 0.2,
	ZOffset = 1,
	Rate = 150,
	BurstCount = 50,
})

RegisterExplosion("artificermajor4bomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- Bigger start
		NumberSequenceKeypoint.new(1, 0.5),
	}),
	Speed = NumberRange.new(1, 3),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	}),

	Texture = "rbxassetid://73621565802849",
	Lifetime = 0.2,
	ZOffset = 1,
	Rate = 150,
	BurstCount = 50,
})

-- beams
RegisterExplosion("primordialmajor5bomb", {
	Color = Color3.fromHex(statsMod.Colors["Primordial"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 3),
		NumberSequenceKeypoint.new(1, 5),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1), -- Bigger start
		NumberSequenceKeypoint.new(1, .4),
	}),
	Speed = NumberRange.new(1, 1),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
	RotSpeed = NumberRange.new(-100, 190),
	Texture = "rbxassetid://98794461869600",
	Lifetime = 0.8,
	ZOffset = 1,
	Rate = 500,
	BurstCount = 500,
})

RegisterExplosion("naturemajor5bomb", {
	Color = Color3.fromHex(statsMod.Colors["Nature"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 3),
		NumberSequenceKeypoint.new(1, 5),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1), -- Bigger start
		NumberSequenceKeypoint.new(1, .4),
	}),
	Speed = NumberRange.new(1, 1),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
	RotSpeed = NumberRange.new(-100, 190),
	Texture = "rbxassetid://98794461869600",
	Lifetime = 0.8,
	ZOffset = 1,
	Rate = 500,
	BurstCount = 500,
})

RegisterExplosion("artificermajor5bomb", {
	Color = Color3.fromHex(statsMod.Colors["Artificer"]),
	Squash = NumberSequence.new({ -- Custom squash sequence
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 3),
		NumberSequenceKeypoint.new(1, 5),
	}),
	-- Override the Size function entirely (or just provide values)
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1), -- Bigger start
		NumberSequenceKeypoint.new(1, .4),
	}),
	Speed = NumberRange.new(1, 1),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
	RotSpeed = NumberRange.new(-100, 190),
	Texture = "rbxassetid://98794461869600",
	Lifetime = 0.8,
	ZOffset = 1,
	Rate = 500,
	BurstCount = 500,
})

return explosionMod
