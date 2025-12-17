--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local effectMod = {}

--==============================================================================
-- Summon effect with scaling based on creature size
--==============================================================================
function effectMod.SummonCreatureEffect(spawnpoint: Vector3, creatureName: string, secs: number): ()
	local groundY = utilMod.DistancetoGround(spawnpoint) or spawnpoint.Y
	local adjustedPoint = Vector3.new(spawnpoint.X, groundY, spawnpoint.Z)

	local creatureStats = statsMod.creatureStats[creatureName]
	local magictype = creatureStats and creatureStats.magicType
	if not magictype then
		return
	end

	local effectName = tostring(magictype) .. "SummonEffect"
	local template = ReplicatedStorage.Effects:FindFirstChild(effectName)
	if not template then
		return
	end

	local effectclone = template:Clone()
	local basepart = effectclone:FindFirstChildWhichIsA("BasePart")
	if basepart then
		local width = creatureStats.width or 8
		basepart.Size = Vector3.new(width, 10, width)
		for _, effect in basepart:GetChildren() do
			if effect:IsA("ParticleEmitter") then
				effect.Rate = effect.Rate * (width / 8) -- scale rate proportionally
			end
		end
	end

	effectclone:PivotTo(CFrame.new(adjustedPoint))
	effectclone.Parent = Workspace

	task.delay(secs + 3, function()
		if not effectclone.Parent then
			return
		end
		for _, effect in basepart:GetChildren() do
			if effect:IsA("ParticleEmitter") then
				effect.Enabled = false
			end
		end
		task.delay(5, function()
			if effectclone.Parent then
				effectclone:Destroy()
			end
		end)
	end)
end

--==============================================================================
-- Single target damage effect
--==============================================================================
function effectMod.DirectDamageEffect(spawnpoint: Vector3, spellName: string): ()
	local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spelleffect = template:Clone()
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		return
	end

	local groundY = utilMod.DistancetoGround(spawnpoint) or 0
	local yoffset = spawnpoint.Y - groundY
	local effectorigin = spawnpoint + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)

	spelleffect:PivotTo(CFrame.new(effectorigin))
	spelleffect.Parent = Workspace

	for _, eff in spelleffect:GetDescendants() do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end

	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			return
		end
		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		task.delay(2, function()
			if spelleffect.Parent then
				spelleffect:Destroy()
			end
		end)
	end)
end

--==============================================================================
-- AOE damage effect (centered on point)
--==============================================================================
function effectMod.AOEDamageEffect(spawnpoint: Vector3, spellName: string): ()
	-- Same as DirectDamageEffect but with cylinder scaling
	local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spelleffect = template:Clone()
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		return
	end

	local groundY = utilMod.DistancetoGround(spawnpoint) or 0
	local yoffset = spawnpoint.Y - groundY
	local effectorigin = spawnpoint + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)

	spelleffect:PivotTo(CFrame.new(effectorigin))
	spelleffect.Parent = Workspace

	local emitterPart = spelleffect:FindFirstChild("CylinderEmitter")
	if emitterPart then
		emitterPart.Size = Vector3.new(15, spellinfo.range * 2, spellinfo.range * 2)
	end

	for _, eff in spelleffect:GetDescendants() do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end

	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			return
		end
		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		task.delay(2, function()
			if spelleffect.Parent then
				spelleffect:Destroy()
			end
		end)
	end)
end

--==============================================================================
-- Buff effect on multiple targets
--==============================================================================
function effectMod.BuffEffects(targets: { Model }, spellName: string): ()
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Buff spell info missing: " .. spellName)
		return
	end

	for _, targetModel in targets do
		local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
		if not template then
			continue
		end

		local spelleffect = template:Clone()
		local hrp = targetModel:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local groundY = utilMod.DistancetoGround(hrp.Position) or 0
		local yoffset = hrp.Position.Y - groundY
		local effectorigin = hrp.Position + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)

		spelleffect:PivotTo(CFrame.new(effectorigin))
		spelleffect.Parent = Workspace

		local emitterPart = spelleffect:FindFirstChild("EmitterBox")
		local creatureWidth = statsMod.creatureStats[utilMod.customTrim(targetModel)]
				and statsMod.creatureStats[utilMod.customTrim(targetModel)].width
			or 3
		if emitterPart then
			emitterPart.Size = Vector3.new(creatureWidth, 10, creatureWidth)
		end

		for _, eff in spelleffect:GetDescendants() do
			if eff:IsA("ParticleEmitter") then
				eff:Emit(50)
			end
		end

		task.delay(spellinfo.effectTime, function()
			if not spelleffect.Parent then
				return
			end
			for _, child in spelleffect:GetDescendants() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			task.delay(2, function()
				if spelleffect.Parent then
					spelleffect:Destroy()
				end
			end)
		end)
	end
end

--==============================================================================
-- Debuff effect on multiple targets (identical to buff visually)
--==============================================================================
function effectMod.DeBuffEffects(targets: { Model }, spellName: string): ()
	-- Intentionally identical to BuffEffects — reuse logic if desired
	effectMod.BuffEffects(targets, spellName) -- or copy-paste if visuals differ later
end

--==============================================================================

export type EffectMod = {
	SummonCreatureEffect: (spawnpoint: Vector3, creatureName: string, secs: number) -> (),
	DirectDamageEffect: (spawnpoint: Vector3, spellName: string) -> (),
	AOEDamageEffect: (spawnpoint: Vector3, spellName: string) -> (),
	BuffEffects: (targets: { Model }, spellName: string) -> (),
	DeBuffEffects: (targets: { Model }, spellName: string) -> (),
}

return effectMod :: EffectMod
