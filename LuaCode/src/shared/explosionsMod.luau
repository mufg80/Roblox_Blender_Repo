
-- ReplicatedStorage.ExplosionConfigs (ModuleScript)
-- This module provides a public API for managing explosion configurations.
-- It starts with a default preset, allows registering custom overrides per key,
-- and provides a GetConfig function that merges defaults with overrides.


export type explosionMod  = {
    GetConfig: (key: string) -> ExplosionConfig,
}


export type ExplosionConfig = {
    BaseSize: number,
    Lifetime: number,
    Color: Color3,

    Texture: string,
    LightEmission: number,
    LightInfluence: number,
    Orientation: Enum.ParticleOrientation,

    Transparency: NumberSequence,
    Squash: NumberSequence,
    Size: (baseSize: number) -> NumberSequence,  -- Function to generate size sequence based on base size

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

-- Default configuration (base for all explosions)
local Default  = {
    -- Core visual params
    BaseSize          = 1.0,
    Lifetime          = 0.8,
    Color             = Color3.fromHex("#d5d506"),  -- Default yellow-ish

    -- ParticleEmitter properties
    Texture           = "rbxasset://textures/particles/sparkles_main.dds",
    LightEmission     = 0.6,
    LightInfluence    = 1.0,
    Orientation       = Enum.ParticleOrientation.FacingCameraWorldUp,

    Transparency      = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    }),
    Squash            = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0),
    }),
    Size              = function(baseSize)  -- Dynamic generator
        return NumberSequence.new({
            NumberSequenceKeypoint.new(0, baseSize * 0.8),
            NumberSequenceKeypoint.new(1, baseSize * 0.1),
        })
    end,

    ZOffset           = 0,
    Rate              = 500,
    Speed             = NumberRange.new(5, 6),
    SpreadAngle       = Vector2.new(45, 45),
    EmissionDirection = Enum.NormalId.Top,
    Rotation          = NumberRange.new(-45, 45),
    RotSpeed          = NumberRange.new(-90, 90),
    Shape             = Enum.ParticleEmitterShape.Sphere,
    ShapeInOut        = Enum.ParticleEmitterShapeInOut.Outward,
    ShapeStyle        = Enum.ParticleEmitterShapeStyle.Surface,
    ShapePartial      = 1,

    -- Burst behavior
    BurstCount        = 100,
    EnableDelay       = 0.2,
    DebrisLifetime    = 1.2,
}

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
    local config = deepCopy(Default)
    
    local override = explosionMod.Overrides[key]
    if override then
        for k, v in pairs(override) do
            config[k] = deepCopy(v)  -- Deep copy overrides to avoid shared references
        end
    end
    
    return config
end

-- Example registrations (add these or more as needed)
RegisterExplosion("StarterStaffTrail", {
    -- Minimal overrides for this type (if different from default)
    Color = Color3.fromHex("#d5d506"),
    Lifetime = 0.8,
})

RegisterExplosion("naturestarterbomb", {
    Color = Color3.fromHex("#217a22"),  -- Green for nature
    Squash = NumberSequence.new({       -- Custom squash sequence
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(1, 0),
    }),
    -- Override the Size function entirely (or just provide values)
    Size = function(baseSize)
        return NumberSequence.new({
            NumberSequenceKeypoint.new(0, baseSize * 1.2),  -- Bigger start
            NumberSequenceKeypoint.new(1, baseSize * 0.2),
        })
    end,
    -- You can add/override any other properties here, e.g.
    -- BaseSize = 1.5,
    -- Rate = 700,
})

-- Add more RegisterExplosion calls for other keys...

return explosionMod