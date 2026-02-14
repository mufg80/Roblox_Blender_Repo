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
-- Single target damage effect (now follows NPC via HRP)
--==============================================================================
function effectMod.DirectDamageEffect(hrp: BasePart, spellName: string): ()
	-- Validate HRP
	if not hrp or not hrp:IsA("BasePart") then
		warn("DirectDamageEffect: Invalid HumanoidRootPart provided")
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Spell info not found for " .. spellName)
		return
	end

	local spelleffect = template:Clone()
	spelleffect.Parent = Workspace

	-- Initial positioning
	local function updatePosition()
		if not hrp.Parent then
			return
		end

		local currentPos = hrp.Position
		local groundY = utilMod.DistancetoGround(currentPos) or 0
		local yoffset = currentPos.Y - groundY

		-- Apply the same XZ offset as before, but now relative to current HRP position
		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
		local effectY = groundY -- Stick to ground level

		local effectorigin = Vector3.new(effectX, effectY, effectZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))
	end

	-- Initial placement
	updatePosition()

	-- Emit particles immediately
	for _, eff in spelleffect:GetDescendants() do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end

	-- Start updating position every frame while the effect is alive
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not spelleffect.Parent or not hrp.Parent then
			connection:Disconnect()
			return
		end
		updatePosition()
	end)

	-- Cleanup after effectTime
	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		-- Disable new particle emission
		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end

		-- Disconnect position updates
		if connection then
			connection:Disconnect()
		end

		-- Final destroy after particles die out
		task.delay(2, function()
			if spelleffect.Parent then
				spelleffect:Destroy()
			end
		end)
	end)
end
--==============================================================================
-- AOE damage effect (now follows NPC via HRP, centered with offset)
--==============================================================================
function effectMod.AOEDamageEffect(hrp: BasePart, spellName: string): ()
	-- Validate HRP
	if not hrp or not hrp:IsA("BasePart") then
		warn("AOEDamageEffect: Invalid HumanoidRootPart provided")
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Spell info not found for " .. spellName)
		return
	end

	local spelleffect = template:Clone()
	spelleffect.Parent = Workspace

	-- Resize cylinder emitter (once, based on spell range)
	local emitterPart = spelleffect:FindFirstChild("CylinderEmitter")
	if emitterPart then
		emitterPart.Size = Vector3.new(15, spellinfo.range * 2, spellinfo.range * 2)
	end

	-- Position update function (runs every frame)
	local function updatePosition()
		if not hrp.Parent or not spelleffect.Parent then
			return true -- Signal to stop updating
		end

		local currentPos = hrp.Position
		local groundY = utilMod.DistancetoGround(currentPos) or 0

		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
		local effectY = groundY -- Stick to ground level

		local effectorigin = Vector3.new(effectX, effectY, effectZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))
	end

	-- Initial placement
	if updatePosition() then
		spelleffect:Destroy()
		return
	end

	-- Emit particles immediately
	for _, eff in spelleffect:GetDescendants() do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end

	-- Heartbeat connection for position updates
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if updatePosition() then
			connection:Disconnect()
		end
	end)

	-- Cleanup after effectTime
	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		-- Disable new particle emission
		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end

		-- Stop position updates
		if connection then
			connection:Disconnect()
		end

		-- Final destroy after particles die out
		task.delay(2, function()
			if spelleffect.Parent then
				spelleffect:Destroy()
			end
		end)
	end)
end

--==============================================================================
-- Buff effect on multiple targets (adjusted for ground-level Model pivot)
--==============================================================================
function effectMod.BuffEffects(targets: { Model }, spellName: string)
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Buff spell info missing: " .. spellName)
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellName .. "Effect")
	if not template then
		warn("Buff effect template not found: " .. spellName .. "Effect")
		return
	end

	for _, targetModel in targets do
		local hrp = targetModel:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local spelleffect = template:Clone()
		spelleffect.Parent = Workspace

		-- Get creature dimensions
		local creatureWidth = 3
		local creatureHeight = 6

		if utilMod.IsPlayerCharacter(targetModel) then
			local magictype = utilMod.GetPlayerType(utilMod.GetPlayerFromCharacter(targetModel))
			if statsMod.creatureStats[magictype] then
				creatureWidth = statsMod.creatureStats[magictype].width or 3
				creatureHeight = statsMod.creatureStats[magictype].height or 6
			end
		else
			local trimmedName = utilMod.customTrim(targetModel.Name)
			if statsMod.creatureStats[trimmedName] then
				creatureWidth = statsMod.creatureStats[trimmedName].width or 3
				creatureHeight = statsMod.creatureStats[trimmedName].height or 6
			end
		end

		local emitterPart = spelleffect:FindFirstChild("EmitterBox")
		if emitterPart then
			-- Only resize — do NOT manually offset position
			emitterPart.Size = Vector3.new(creatureWidth, creatureHeight, creatureWidth)

			local ground = utilMod.DistancetoGround(emitterPart.Position)
			local emitterpoint = ground + (emitterPart.Size.Y / 2)
			emitterPart.CFrame = CFrame.new(Vector3.new(emitterPart.Position.X, emitterpoint, emitterPart.Position.Z))
		end

		-- Position update function (Model pivot stays at ground level)
		local function updatePosition()
			if not hrp.Parent or not spelleffect.Parent then
				return true -- Signal to disconnect
			end

			local currentPos = hrp.Position
			local groundY = utilMod.DistancetoGround(currentPos) or 0

			local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
			local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
			local effectY = groundY -- Pivot is already at bottom/ground

			local effectorigin = Vector3.new(effectX, effectY, effectZ)
			spelleffect:PivotTo(CFrame.new(effectorigin))
		end

		-- Initial placement
		if updatePosition() then
			spelleffect:Destroy()
			continue
		end

		-- Initial particle burst
		for _, eff in spelleffect:GetDescendants() do
			if eff:IsA("ParticleEmitter") then
				eff:Emit(50)
			end
		end

		-- Follow target every frame
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			if updatePosition() then
				connection:Disconnect()
			end
		end)

		-- Cleanup after duration
		task.delay(spellinfo.effectTime, function()
			if not spelleffect.Parent then
				if connection then
					connection:Disconnect()
				end
				return
			end

			for _, child in spelleffect:GetDescendants() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end

			if connection then
				connection:Disconnect()
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

function effectMod.SoulGrabbedEffect(pos: Vector3): ()
	if not pos then
		warn("should not reach me")
		return
	end
	if not typeof(pos) == "Vector3" then
		warn("Should not reach me.")
		return
	end
	local emitterclone: BasePart = ReplicatedStorage.Effects.SoulEmitterPart:Clone()
	if emitterclone then
		emitterclone:PivotTo(CFrame.new(pos))
		emitterclone.Parent = workspace
		local emitter = emitterclone:FindFirstChild("ParticleEmitter")
		if emitter then
			emitter:Emit(500)
			task.delay(0.5, function()
				emitter.Enabled = false
				task.delay(1, function()
					emitterclone.Parent = nil
				end)
			end)
		else
			emitterclone.Parent = nil
			warn("should not reach me")
		end
	end
end

export type EffectMod = {
	SummonCreatureEffect: (spawnpoint: Vector3, creatureName: string, secs: number) -> (),
	DirectDamageEffect: (hrp: BasePart, spellName: string) -> (),
	AOEDamageEffect: (hrp: BasePart, spellName: string) -> (),
	BuffEffects: (targets: { Model }, spellName: string) -> (),
	DeBuffEffects: (targets: { Model }, spellName: string) -> (),
	SoulGrabbedEffect: (pos: Vector3) -> (),
}

return effectMod :: EffectMod
