--!strict

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Workspace = game:GetService("Workspace")

-- local utilMod = require(ReplicatedStorage.Shared.utilMod)
-- local statsMod = require(ReplicatedStorage.Shared.statsMod)

-- export type EffectMod = {
-- 	SummonCreatureEffect: (spawnpoint: Vector3, creatureName: string, secs: number) -> (),
-- 	DirectDamageEffect: (hrp: BasePart, spellName: string) -> (),
-- 	AOEDamageEffect: (hrp: BasePart, spellName: string) -> (),
-- 	BuffEffects: (targets: { Model }, spellName: string) -> (),
-- 	DeBuffEffects: (targets: { Model }, spellName: string) -> (),
-- 	SoulGrabbedEffect: (pos: Vector3) -> (),
-- 	LithBaneEffect: (player: Player, building: Model, spellname: string) -> (),
-- 	DesummonEvent:(hrp:BasePart, spellname:string) -> (),
-- 	LithSummonEffect:(player:Player, pos:Vector3, spellname:string) ->(),
-- }

-- local effectMod = {}

-- --==============================================================================
-- -- Summon effect with scaling based on creature size
-- --==============================================================================
-- function effectMod.SummonCreatureEffect(spawnpoint: Vector3, creatureName: string, secs: number): ()
-- 	local groundY = utilMod.DistancetoGround(spawnpoint) or spawnpoint.Y
-- 	local adjustedPoint = Vector3.new(spawnpoint.X, groundY, spawnpoint.Z)

-- 	local creatureStats = statsMod.creatureStats[creatureName]
-- 	local magictype = creatureStats and creatureStats.magicType
-- 	if not magictype then
-- 		return
-- 	end

-- 	local effectName = tostring(magictype) .. "SummonEffect"
-- 	local template = ReplicatedStorage.Effects:FindFirstChild(effectName)
-- 	if not template then
-- 		return
-- 	end

-- 	local effectclone = template:Clone()
-- 	local basepart = effectclone:FindFirstChildWhichIsA("BasePart")
-- 	if basepart then
-- 		local width = creatureStats.width or 8
-- 		basepart.Size = Vector3.new(width, 10, width)
-- 		for _, effect in basepart:GetChildren() do
-- 			if effect:IsA("ParticleEmitter") then
-- 				effect.Rate = effect.Rate * (width / 8) -- scale rate proportionally
-- 			end
-- 		end
-- 	end

-- 	effectclone:PivotTo(CFrame.new(adjustedPoint))
-- 	effectclone.Parent = Workspace.Effects


-- 	task.delay(secs + 3, function()
-- 		if not effectclone.Parent then
-- 			return
-- 		end
-- 		for _, effect in basepart:GetChildren() do
-- 			if effect:IsA("ParticleEmitter") then
-- 				effect.Enabled = false
-- 			end
-- 		end
-- 		task.delay(5, function()
-- 			if effectclone.Parent then
-- 				effectclone:Destroy()
-- 			end
-- 		end)
-- 	end)
-- end

-- --==============================================================================
-- -- Single target damage effect (now follows NPC via HRP)
-- --==============================================================================
-- function effectMod.DirectDamageEffect(hrp: BasePart, spellName: string): ()
-- 	-- Validate HRP
-- 	if not hrp or not hrp:IsA("BasePart") then
-- 		warn("DirectDamageEffect: Invalid HumanoidRootPart provided")
-- 		return
-- 	end

-- 	local spellinfo = statsMod.SpellInfo[spellName]
-- 	if not spellinfo then
-- 		warn("Spell info not found for " .. spellName)
-- 		return
-- 	end

-- 	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
-- 	if not template then
-- 		warn("Effect not found: " .. spellName .. "Effect")
-- 		return
-- 	end

-- 	local spelleffect = template:Clone()
-- 	spelleffect.Parent = Workspace.Effects

-- 	-- Initial positioning
-- 	local function updatePosition()
-- 		if not hrp.Parent then
-- 			return
-- 		end

-- 		local currentPos = hrp.Position
-- 		local groundY = utilMod.DistancetoGround(currentPos) or 0

-- 		-- Apply the same XZ offset as before, but now relative to current HRP position
-- 		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
-- 		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
-- 		local effectY = groundY -- Stick to ground level

-- 		local effectorigin = Vector3.new(effectX, effectY, effectZ)
-- 		spelleffect:PivotTo(CFrame.new(effectorigin))
-- 	end

-- 	-- Initial placement
-- 	updatePosition()

-- 	-- Emit particles immediately
-- 	for _, eff in spelleffect:GetDescendants() do
-- 		if eff:IsA("ParticleEmitter") then
-- 			eff:Emit(20)
-- 		end
-- 	end

-- 	-- Start updating position every frame while the effect is alive
-- 	local connection
-- 	connection = game:GetService("RunService").Heartbeat:Connect(function()
-- 		if not spelleffect.Parent or not hrp.Parent then
-- 			connection:Disconnect()
-- 			return
-- 		end
-- 		updatePosition()
-- 	end)

-- 	-- Cleanup after effectTime
-- 	task.delay(spellinfo.effectTime, function()
-- 		if not spelleffect.Parent then
-- 			if connection then
-- 				connection:Disconnect()
-- 			end
-- 			return
-- 		end

-- 		-- Disable new particle emission
-- 		for _, child in spelleffect:GetDescendants() do
-- 			if child:IsA("ParticleEmitter") then
-- 				child.Enabled = false
-- 			end
-- 		end

-- 		-- Disconnect position updates
-- 		if connection then
-- 			connection:Disconnect()
-- 		end

-- 		-- Final destroy after particles die out
-- 		task.delay(2, function()
-- 			if spelleffect.Parent then
-- 				spelleffect:Destroy()
-- 			end
-- 		end)
-- 	end)
-- end
-- --==============================================================================
-- -- AOE damage effect (now follows NPC via HRP, centered with offset)
-- --==============================================================================
-- function effectMod.AOEDamageEffect(hrp: BasePart, spellName: string): ()
-- 	-- Validate HRP
-- 	if not hrp or not hrp:IsA("BasePart") then
-- 		warn("AOEDamageEffect: Invalid HumanoidRootPart provided")
-- 		return
-- 	end

-- 	local spellinfo = statsMod.SpellInfo[spellName]
-- 	if not spellinfo then
-- 		warn("Spell info not found for " .. spellName)
-- 		return
-- 	end

-- 	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
-- 	if not template then
-- 		warn("Effect not found: " .. spellName .. "Effect")
-- 		return
-- 	end

-- 	local spelleffect = template:Clone()
-- 	spelleffect.Parent = Workspace.Effects

-- 	-- Resize cylinder emitter (once, based on spell range)
-- 	local emitterPart = spelleffect:FindFirstChild("CylinderEmitter")
-- 	if emitterPart then
-- 		emitterPart.Size = Vector3.new(15, spellinfo.range * 2, spellinfo.range * 2)
-- 	end

-- 	-- Position update function (runs every frame)
-- 	local function updatePosition()
-- 		if not hrp.Parent or not spelleffect.Parent then
-- 			return true -- Signal to stop updating
-- 		end

-- 		local currentPos = hrp.Position
-- 		local groundY = utilMod.DistancetoGround(currentPos) or 0

-- 		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
-- 		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
-- 		local effectY = groundY -- Stick to ground level

-- 		local effectorigin = Vector3.new(effectX, effectY, effectZ)
-- 		spelleffect:PivotTo(CFrame.new(effectorigin))
-- 		return false
-- 	end

-- 	-- Initial placement
-- 	if updatePosition() then
-- 		spelleffect:Destroy()
-- 		return
-- 	end

-- 	-- Emit particles immediately
-- 	for _, eff in spelleffect:GetDescendants() do
-- 		if eff:IsA("ParticleEmitter") then
-- 			eff:Emit(20)
-- 		end
-- 	end

-- 	-- Heartbeat connection for position updates
-- 	local connection
-- 	connection = game:GetService("RunService").Heartbeat:Connect(function()
-- 		if updatePosition() then
-- 			connection:Disconnect()
-- 		end
-- 	end)

-- 	-- Cleanup after effectTime
-- 	task.delay(spellinfo.effectTime, function()
-- 		if not spelleffect.Parent then
-- 			if connection then
-- 				connection:Disconnect()
-- 			end
-- 			return
-- 		end

-- 		-- Disable new particle emission
-- 		for _, child in spelleffect:GetDescendants() do
-- 			if child:IsA("ParticleEmitter") then
-- 				child.Enabled = false
-- 			end
-- 		end

-- 		-- Stop position updates
-- 		if connection then
-- 			connection:Disconnect()
-- 		end

-- 		-- Final destroy after particles die out
-- 		task.delay(2, function()
-- 			if spelleffect.Parent then
-- 				spelleffect:Destroy()
-- 			end
-- 		end)
-- 	end)
-- end

-- --==============================================================================
-- -- Buff effect on multiple targets (adjusted for ground-level Model pivot)
-- --==============================================================================
-- function effectMod.BuffEffects(targets: { Model }, spellName: string)
-- 	local spellinfo = statsMod.SpellInfo[spellName]
-- 	if not spellinfo then
-- 		warn("Buff spell info missing: " .. spellName)
-- 		return
-- 	end

-- 	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
-- 	if not template then
-- 		warn("Buff effect template not found: " .. spellName .. "Effect")
-- 		return
-- 	end

-- 	for _, targetModel in targets do
-- 		local hrp = targetModel:FindFirstChild("HumanoidRootPart")
-- 		if not hrp then
-- 			continue
-- 		end

-- 		local spelleffect = template:Clone()
-- 		spelleffect.Parent = Workspace.Effects

-- 		-- Get creature dimensions
-- 		local creatureWidth = 3
-- 		local creatureHeight = 6

-- 		if utilMod.IsPlayerCharacter(targetModel) then
-- 			local magictype = utilMod.GetPlayerType(utilMod.GetPlayerFromCharacter(targetModel))
-- 			if magictype and statsMod.creatureStats[magictype] then
-- 				creatureWidth = statsMod.creatureStats[magictype].width or 3
-- 				creatureHeight = statsMod.creatureStats[magictype].height or 6
-- 			end
-- 		else
-- 			local trimmedName = utilMod.customTrim(targetModel.Name)
-- 			if statsMod.creatureStats[trimmedName] then
-- 				creatureWidth = statsMod.creatureStats[trimmedName].width or 3
-- 				creatureHeight = statsMod.creatureStats[trimmedName].height or 6
-- 			end
-- 		end

-- 		local emitterPart = spelleffect:FindFirstChild("EmitterBox")
-- 		if emitterPart then
-- 			-- Only resize — do NOT manually offset position
-- 			emitterPart.Size = Vector3.new(creatureWidth, creatureHeight, creatureWidth)

-- 			local ground = utilMod.DistancetoGround(emitterPart.Position)
-- 			local emitterpoint = ground + (emitterPart.Size.Y / 2)
-- 			emitterPart.CFrame = CFrame.new(Vector3.new(emitterPart.Position.X, emitterpoint, emitterPart.Position.Z))
-- 		end

-- 		-- Position update function (Model pivot stays at ground level)
-- 		local function updatePosition()
-- 			if not hrp.Parent or not spelleffect.Parent or not hrp:IsA("BasePart") then
-- 				return true -- Signal to disconnect
-- 			end

-- 			local currentPos = hrp.Position
-- 			local groundY = utilMod.DistancetoGround(currentPos) or 0

-- 			local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
-- 			local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
-- 			local effectY = groundY -- Pivot is already at bottom/ground

-- 			local effectorigin = Vector3.new(effectX, effectY, effectZ)
-- 			spelleffect:PivotTo(CFrame.new(effectorigin))
-- 			return false
-- 		end

-- 		-- Initial placement
-- 		if updatePosition() then
-- 			spelleffect:Destroy()
-- 			continue
-- 		end

-- 		-- Initial particle burst
-- 		for _, eff in spelleffect:GetDescendants() do
-- 			if eff:IsA("ParticleEmitter") then
-- 				eff:Emit(50)
-- 			end
-- 		end

-- 		-- Follow target every frame
-- 		local connection
-- 		connection = game:GetService("RunService").Heartbeat:Connect(function()
-- 			if updatePosition() then
-- 				connection:Disconnect()
-- 			end
-- 		end)

-- 		-- Cleanup after duration
-- 		task.delay(spellinfo.effectTime, function()
-- 			if not spelleffect.Parent then
-- 				if connection then
-- 					connection:Disconnect()
-- 				end
-- 				return
-- 			end

-- 			for _, child in spelleffect:GetDescendants() do
-- 				if child:IsA("ParticleEmitter") then
-- 					child.Enabled = false
-- 				end
-- 			end

-- 			if connection then
-- 				connection:Disconnect()
-- 			end

-- 			task.delay(2, function()
-- 				if spelleffect.Parent then
-- 					spelleffect:Destroy()
-- 				end
-- 			end)
-- 		end)
-- 	end
-- end

-- --==============================================================================
-- -- Debuff effect on multiple targets (identical to buff visually)
-- --==============================================================================
-- function effectMod.DeBuffEffects(targets: { Model }, spellName: string): ()
-- 	-- Intentionally identical to BuffEffects — reuse logic if desired
-- 	effectMod.BuffEffects(targets, spellName) -- or copy-paste if visuals differ later
-- end

-- --==============================================================================

-- function effectMod.SoulGrabbedEffect(pos: Vector3): ()
-- 	if not pos then
-- 		warn("should not reach me")
-- 		return
-- 	end

-- 	local emitterclone: BasePart = ReplicatedStorage.Effects.SoulEmitterEffect:Clone()
-- 	if emitterclone and emitterclone:IsA("Model") then
-- 		emitterclone:PivotTo(CFrame.new(pos))
-- 		emitterclone.Parent = workspace.Effects
-- 		local emitter = emitterclone:FindFirstChild("ParticleEmitter")
-- 		if emitter and emitter:IsA("ParticleEmitter") then
-- 			emitter:Emit(500)
-- 			task.delay(0.5, function()
-- 				emitter.Enabled = false
-- 				task.delay(1, function()
-- 					emitterclone.Parent = nil
-- 				end)
-- 			end)
-- 		else
-- 			emitterclone.Parent = nil
-- 			warn("should not reach me")
-- 		end
-- 	end
-- end

-- -- Spawns a one-shot visual effect (particle burst) on an enemy building using the player's current magic color.
-- -- Handles graceful shutdown: stops emission halfway, then cleans up after full lifetime.
-- function effectMod.LithBaneEffect(player: Player, building: Model, spellname: string): ()
-- 	if not player or not player:IsA("Player") then
-- 		warn("LithBaneEffect → Invalid player")
-- 		return
-- 	end

-- 	if not building or not building:IsA("Model") or not building.PrimaryPart then
-- 		warn("LithBaneEffect → Invalid building or missing PrimaryPart")
-- 		return
-- 	end

-- 	-- Magic type & color
-- 	local magictype = utilMod.GetAttribute(player, "Magic") or statsMod.MagicType.None
-- 	local colorHex = statsMod.Colors[magictype] or "#ffffff"
-- 	local color = Color3.fromHex(colorHex)

-- 	-- Lifetime
-- 	local spellinfo = statsMod.SpellInfo[spellname]
-- 	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
-- 		and spellinfo.effectTime
-- 		or 3

-- 	-- Template
-- 	local template = ReplicatedStorage.Effects:FindFirstChild("LithBaneEffect")
-- 	if not template or not template:IsA("Model") then
-- 		warn("LithBaneEffect → Missing or invalid template 'LithBaneEffect'")
-- 		return
-- 	end

-- 	local clone = template:Clone()
-- 	if not clone then
-- 		return
-- 	end

-- 	local emitter = clone:FindFirstChildWhichIsA("ParticleEmitter", true)
-- 	if not emitter or not emitter:IsA("ParticleEmitter") then
-- 		warn("LithBaneEffect → No ParticleEmitter found in effect")
-- 		clone:Destroy()
-- 		return
-- 	end

-- 	-- Apply color & position
-- 	emitter.Color = ColorSequence.new(color)
-- 	clone:PivotTo(building.PrimaryPart.CFrame)
-- 	clone.Parent = workspace.Effects

-- 	-- Burst!
-- 	emitter:Emit(500)

-- 	-- Graceful shutdown sequence
-- 	task.spawn(function()
-- 		-- Wait until halfway point → stop emitting new particles
-- 		task.wait(lifetime / 2)

-- 		-- Only stop if the effect still exists
-- 		if emitter and emitter.Parent then
-- 			emitter.Enabled = false   -- Prevents new particles from spawning
-- 			-- Optional: you could also reduce Lifetime or Rate here for extra fade, but usually not needed
-- 		end

-- 		-- Wait the remaining half so existing particles can finish
-- 		task.wait(lifetime / 2)

-- 		-- Clean up
-- 		if clone and clone.Parent then
-- 			clone:Destroy()
-- 		end
-- 	end)
-- end
-- -- Spawns a following "Desummon" visual effect attached to a pet's HumanoidRootPart.
-- -- Effect follows the pet until it dies/despawns, then finishes at last position.
-- -- Graceful fade: stops both emitters at halfway point, destroys model after full lifetime.
-- function effectMod.DesummonEvent(hrp: BasePart, spellname: string): ()
-- 	if not hrp or not hrp:IsA("BasePart") then
-- 		warn("DesummonEvent → Invalid or missing HumanoidRootPart")
-- 		return
-- 	end

-- 	-- Get duration from spell info (fallback to 3s)
-- 	local spellinfo = statsMod.SpellInfo[spellname]
-- 	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
-- 		and spellinfo.effectTime
-- 		or 3

-- 	-- Find template
-- 	local template = ReplicatedStorage.Effects:FindFirstChild("DesummonEffect")
-- 	if not template or not template:IsA("Model") then
-- 		warn("DesummonEvent → Missing or invalid 'DesummonEffect' template in ReplicatedStorage.Effects")
-- 		return
-- 	end

-- 	-- Clone and prepare
-- 	local effect = template:Clone()
-- 	if not effect then
-- 		warn("DesummonEvent → Failed to clone DesummonEffect")
-- 		return
-- 	end

-- 	-- Collect both emitters (expected: one per part)
-- 	local emitters: {ParticleEmitter} = {}
-- 	for _, emitter in effect:GetDescendants() do
-- 		if emitter:IsA("ParticleEmitter") then
-- 			table.insert(emitters, emitter)
-- 		end
-- 	end

-- 	if #emitters == 0 then
-- 		warn("DesummonEvent → No ParticleEmitters found in DesummonEffect")
-- 		effect:Destroy()
-- 		return
-- 	elseif #emitters ~= 2 then
-- 		warn("DesummonEvent → Expected 2 ParticleEmitters, found " .. #emitters)
-- 		-- Still proceed — better than failing entirely
-- 	end

-- 	-- Initial position + parent to workspace
-- 	effect:PivotTo(hrp.CFrame)
-- 	effect.Parent = workspace.Effects

-- 	-- Optional: If the emitters have Enabled = true by default in template, they start emitting immediately.
-- 	-- If you want a burst instead, call :Emit(N) here on each emitter.

-- 	-- Main update & cleanup loop
-- 	task.spawn(function()
-- 		local lastCFrame = hrp.CFrame
-- 		local halfway = lifetime / 2
-- 		local startTime = tick()

-- 		while tick() - startTime < lifetime do
-- 			if hrp and hrp.Parent then
-- 				-- Pet still alive → follow
-- 				lastCFrame = hrp.CFrame
-- 				effect:PivotTo(lastCFrame)
-- 			else
-- 				-- Pet despawned → freeze at last position, continue fade-out
-- 				effect:PivotTo(lastCFrame)
-- 			end

-- 			-- At halfway: disable all emitters
-- 			if tick() - startTime >= halfway then
-- 				for _, emitter in emitters do
-- 					if emitter and emitter.Parent then
-- 						emitter.Enabled = false
-- 					end
-- 				end
-- 			end

-- 			task.wait(0.08)  -- ~12 Hz update — smooth enough, low overhead
-- 		end

-- 		-- Full lifetime passed → cleanup
-- 		if effect and effect.Parent then
-- 			effect:Destroy()
-- 		end
-- 	end)
-- end

-- -- Spawns a static "LithSummon" particle effect at the given position, colored by player's magic type.
-- -- Graceful fade: bursts particles on spawn, stops emission at halfway, destroys after full lifetime.
-- function effectMod.LithSummonEffect(player: Player, pos: Vector3, spellname: string): ()
-- 	if not player or not player:IsA("Player") then
-- 		warn("LithSummonEffect → Invalid player")
-- 		return
-- 	end

-- 	if typeof(pos) ~= "Vector3" then
-- 		warn("LithSummonEffect → Invalid pos (must be Vector3)")
-- 		return
-- 	end

-- 	-- Get magic type & color
-- 	local magictype = utilMod.GetAttribute(player, "Magic") or statsMod.MagicType.None
-- 	local colorHex = statsMod.Colors[magictype] or "#ffffff"
-- 	local color = Color3.fromHex(colorHex)

-- 	-- Get lifetime
-- 	local spellinfo = statsMod.SpellInfo[spellname]
-- 	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
-- 		and spellinfo.effectTime
-- 		or 3

-- 	-- Template
-- 	local template = ReplicatedStorage.Effects:FindFirstChild("LithSummonEffect")
-- 	if not template or not template:IsA("Model") then
-- 		warn("LithSummonEffect → Missing or invalid 'LithSummonEffect' template in ReplicatedStorage.Effects")
-- 		return
-- 	end

-- 	local clone = template:Clone()
-- 	if not clone then
-- 		warn("LithSummonEffect → Failed to clone template")
-- 		return
-- 	end

-- 	-- Find the single nested emitter (model > part > emitter)
-- 	local emitter = clone:FindFirstChildWhichIsA("ParticleEmitter", true)
-- 	if not emitter or not emitter:IsA("ParticleEmitter") then
-- 		warn("LithSummonEffect → No ParticleEmitter found in cloned effect (expected nested under child)")
-- 		clone:Destroy()
-- 		return
-- 	end

-- 	-- Customize & position
-- 	emitter.Color = ColorSequence.new(color)
-- 	clone:PivotTo(CFrame.new(pos))
-- 	clone.Parent = workspace.Effects

-- 	-- Initial burst for summon "pop"
-- 	emitter:Emit(1000)

-- 	-- Graceful shutdown: non-blocking
-- 	task.spawn(function()
-- 		-- Halfway: stop new particles
-- 		task.wait(lifetime / 2)
-- 		if emitter and emitter.Parent then
-- 			emitter.Enabled = false
-- 		end

-- 		-- Full lifetime: cleanup (lets existing particles fade)
-- 		task.wait(lifetime / 2)
-- 		if clone and clone.Parent then
-- 			clone:Destroy()
-- 		end
-- 	end)
-- end

-- return effectMod :: EffectMod

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

-- Ensure the Effects folder exists (one-time setup)
local EffectsFolder = Workspace:FindFirstChild("Effects")
if not EffectsFolder then
	EffectsFolder = Instance.new("Folder")
	EffectsFolder.Name = "Effects"
	EffectsFolder.Parent = Workspace
end

export type EffectMod = {
	SummonCreatureEffect: (spawnpoint: Vector3, creatureName: string, secs: number) -> (),
	DirectDamageEffect: (hrp: BasePart, spellName: string) -> (),
	AOEDamageEffect: (hrp: BasePart, spellName: string) -> (),
	BuffEffects: (targets: { Model }, spellName: string) -> (),
	DeBuffEffects: (targets: { Model }, spellName: string) -> (),
	SoulGrabbedEffect: (pos: Vector3) -> (),
	LithBaneEffect: (player: Player, building: Model, spellname: string) -> (),
	DesummonEvent: (hrp: BasePart, spellname: string) -> (),
	LithSummonEffect: (player: Player, pos: Vector3, spellname: string) -> (),
}

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
	effectclone.Parent = EffectsFolder

	task.delay(secs + 3, function()
		if not effectclone.Parent then
			return
		end
		if basepart then
			for _, effect in basepart:GetChildren() do
				if effect:IsA("ParticleEmitter") then
					effect.Enabled = false
				end
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
-- Single target damage effect (follows NPC via HRP)
--==============================================================================
function effectMod.DirectDamageEffect(hrp: BasePart, spellName: string): ()
	if not hrp or not hrp:IsA("BasePart") then
		warn("DirectDamageEffect: Invalid HumanoidRootPart provided")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Spell info not found for " .. spellName)
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spelleffect = template:Clone()
	spelleffect.Parent = EffectsFolder

	-- Initial positioning
	local function updatePosition()
		if not hrp.Parent then
			return true
		end

		local currentPos = hrp.Position
		local groundY = utilMod.DistancetoGround(currentPos) or 0

		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
		local effectY = groundY

		local effectorigin = Vector3.new(effectX, effectY, effectZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))
		return false
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

	-- Start updating position every frame
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not spelleffect.Parent or not hrp.Parent then
			if connection then connection:Disconnect() end
			return
		end
		updatePosition()
	end)

	-- Cleanup after effectTime
	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			if connection then connection:Disconnect() end
			return
		end

		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end

		if connection then connection:Disconnect() end

		task.delay(2, function()
			if spelleffect.Parent then
				spelleffect:Destroy()
			end
		end)
	end)
end

--==============================================================================
-- AOE damage effect (follows NPC via HRP, centered with offset)
--==============================================================================
function effectMod.AOEDamageEffect(hrp: BasePart, spellName: string): ()
	if not hrp or not hrp:IsA("BasePart") then
		warn("AOEDamageEffect: Invalid HumanoidRootPart provided")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Spell info not found for " .. spellName)
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
	if not template then
		warn("Effect not found: " .. spellName .. "Effect")
		return
	end

	local spelleffect = template:Clone()
	spelleffect.Parent = EffectsFolder

	local emitterPart = spelleffect:FindFirstChild("CylinderEmitter")
	if emitterPart then
		emitterPart.Size = Vector3.new(15, spellinfo.range * 2, spellinfo.range * 2)
	end

	local function updatePosition()
		if not hrp.Parent or not spelleffect.Parent then
			return true
		end

		local currentPos = hrp.Position
		local groundY = utilMod.DistancetoGround(currentPos) or 0

		local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
		local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
		local effectY = groundY

		local effectorigin = Vector3.new(effectX, effectY, effectZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))
		return false
	end

	if updatePosition() then
		spelleffect:Destroy()
		return
	end

	for _, eff in spelleffect:GetDescendants() do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end

	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if updatePosition() then
			connection:Disconnect()
		end
	end)

	task.delay(spellinfo.effectTime, function()
		if not spelleffect.Parent then
			if connection then connection:Disconnect() end
			return
		end

		for _, child in spelleffect:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end

		if connection then connection:Disconnect() end

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
function effectMod.BuffEffects(targets: { Model }, spellName: string)
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("Buff spell info missing: " .. spellName)
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild(spellinfo.effectName)
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
		spelleffect.Parent = EffectsFolder

		local creatureWidth = 3
		local creatureHeight = 6

		if utilMod.IsPlayerCharacter(targetModel) then
			local magictype = utilMod.GetPlayerType(utilMod.GetPlayerFromCharacter(targetModel))
			if magictype and statsMod.creatureStats[magictype] then
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
			emitterPart.Size = Vector3.new(creatureWidth, creatureHeight, creatureWidth)

			local ground = utilMod.DistancetoGround(emitterPart.Position)
			local emitterpoint = ground + (emitterPart.Size.Y / 2)
			emitterPart.CFrame = CFrame.new(Vector3.new(emitterPart.Position.X, emitterpoint, emitterPart.Position.Z))
		end

		local function updatePosition()
			if not hrp.Parent or not spelleffect.Parent or not hrp:IsA("BasePart") then
				return true
			end

			local currentPos = hrp.Position
			local groundY = utilMod.DistancetoGround(currentPos) or 0

			local effectX = currentPos.X + (spellinfo.effectOffsetXZ or 0)
			local effectZ = currentPos.Z + (spellinfo.effectOffsetXZ or 0)
			local effectY = groundY

			local effectorigin = Vector3.new(effectX, effectY, effectZ)
			spelleffect:PivotTo(CFrame.new(effectorigin))
			return false
		end

		if updatePosition() then
			spelleffect:Destroy()
			continue
		end

		for _, eff in spelleffect:GetDescendants() do
			if eff:IsA("ParticleEmitter") then
				eff:Emit(50)
			end
		end

		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			if updatePosition() then
				connection:Disconnect()
			end
		end)

		task.delay(spellinfo.effectTime, function()
			if not spelleffect.Parent then
				if connection then connection:Disconnect() end
				return
			end

			for _, child in spelleffect:GetDescendants() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end

			if connection then connection:Disconnect() end

			task.delay(2, function()
				if spelleffect.Parent then
					spelleffect:Destroy()
				end
			end)
		end)
	end
end

--==============================================================================
-- Debuff effect (reuses BuffEffects)
--==============================================================================
function effectMod.DeBuffEffects(targets: { Model }, spellName: string): ()
	effectMod.BuffEffects(targets, spellName)
end

--==============================================================================
-- Soul grabbed effect (now a Model with PrimaryPart)
--==============================================================================
function effectMod.SoulGrabbedEffect(pos: Vector3): ()
	if not pos then
		warn("SoulGrabbedEffect: Invalid position")
		return
	end

	local template = ReplicatedStorage.Effects:FindFirstChild("SoulEmitterEffect")
	if not template then
		warn("SoulEmitterEffect template not found in ReplicatedStorage.Effects")
		return
	end

	local emitterModel = template:Clone()
	if not emitterModel or not emitterModel:IsA("Model") then
		warn("SoulEmitterEffect clone is invalid or not a Model")
		return
	end

	emitterModel:PivotTo(CFrame.new(pos))
	emitterModel.Parent = EffectsFolder

	local emitter = emitterModel:FindFirstChildWhichIsA("ParticleEmitter", true)
	if not emitter then
		emitterModel:Destroy()
		warn("No ParticleEmitter found in SoulEmitterEffect")
		return
	end

	emitter:Emit(500)

	task.delay(0.5, function()
		if emitter and emitter.Parent then
			emitter.Enabled = false
			task.delay(1, function()
				if emitterModel and emitterModel.Parent then
					emitterModel:Destroy()
				end
			end)
		end
	end)
end

--==============================================================================
-- LithBaneEffect
--==============================================================================
function effectMod.LithBaneEffect(player: Player, building: Model, spellname: string): ()
	if not player or not player:IsA("Player") then
		warn("LithBaneEffect → Invalid player")
		return
	end

	if not building or not building:IsA("Model") or not building.PrimaryPart then
		warn("LithBaneEffect → Invalid building or missing PrimaryPart")
		return
	end

	local magictype = utilMod.GetAttribute(player, "Magic") or statsMod.MagicType.None
	local colorHex = statsMod.Colors[magictype] or "#ffffff"
	local color = Color3.fromHex(colorHex)

	local spellinfo = statsMod.SpellInfo[spellname]
	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
		and spellinfo.effectTime or 3

	local template = ReplicatedStorage.Effects:FindFirstChild("LithBaneEffect")
	if not template or not template:IsA("Model") then
		warn("LithBaneEffect → Missing or invalid template")
		return
	end

	local clone = template:Clone()
	if not clone then return end

	local emitter = clone:FindFirstChildWhichIsA("ParticleEmitter", true)
	if not emitter then
		clone:Destroy()
		warn("LithBaneEffect → No ParticleEmitter found")
		return
	end

	emitter.Color = ColorSequence.new(color)
	clone:PivotTo(building.PrimaryPart.CFrame)
	clone.Parent = EffectsFolder

	emitter:Emit(500)

	task.spawn(function()
		task.wait(lifetime / 2)
		if emitter and emitter.Parent then
			emitter.Enabled = false
		end
		task.wait(lifetime / 2)
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

--==============================================================================
-- DesummonEvent
--==============================================================================
function effectMod.DesummonEvent(hrp: BasePart, spellname: string): ()
	if not hrp or not hrp:IsA("BasePart") then
		warn("DesummonEvent → Invalid HumanoidRootPart")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellname]
	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
		and spellinfo.effectTime or 3

	local template = ReplicatedStorage.Effects:FindFirstChild("DesummonEffect")
	if not template or not template:IsA("Model") then
		warn("DesummonEvent → Missing or invalid template")
		return
	end

	local effect = template:Clone()
	if not effect then
		warn("DesummonEvent → Failed to clone")
		return
	end

	local emitters: {ParticleEmitter} = {}
	for _, em in effect:GetDescendants() do
		if em:IsA("ParticleEmitter") then
			table.insert(emitters, em)
		end
	end

	if #emitters == 0 then
		warn("DesummonEvent → No ParticleEmitters found")
		effect:Destroy()
		return
	end

	effect:PivotTo(hrp.CFrame)
	effect.Parent = EffectsFolder

	task.spawn(function()
		local lastCFrame = hrp.CFrame
		local halfway = lifetime / 2
		local startTime = tick()

		while tick() - startTime < lifetime do
			if hrp and hrp.Parent then
				lastCFrame = hrp.CFrame
				effect:PivotTo(lastCFrame)
			else
				effect:PivotTo(lastCFrame)
			end

			if tick() - startTime >= halfway then
				for _, emitter in emitters do
					if emitter and emitter.Parent then
						emitter.Enabled = false
					end
				end
			end

			task.wait(0.08)
		end

		if effect and effect.Parent then
			effect:Destroy()
		end
	end)
end

--==============================================================================
-- LithSummonEffect
--==============================================================================
function effectMod.LithSummonEffect(player: Player, pos: Vector3, spellname: string): ()
	if not player or not player:IsA("Player") then
		warn("LithSummonEffect → Invalid player")
		return
	end

	if typeof(pos) ~= "Vector3" then
		warn("LithSummonEffect → Invalid pos")
		return
	end

	local magictype = utilMod.GetAttribute(player, "Magic") or statsMod.MagicType.None
	local colorHex = statsMod.Colors[magictype] or "#ffffff"
	local color = Color3.fromHex(colorHex)

	local spellinfo = statsMod.SpellInfo[spellname]
	local lifetime = (spellinfo and typeof(spellinfo.effectTime) == "number" and spellinfo.effectTime > 0)
		and spellinfo.effectTime or 3

	local template = ReplicatedStorage.Effects:FindFirstChild("LithSummonEffect")
	if not template or not template:IsA("Model") then
		warn("LithSummonEffect → Missing or invalid template")
		return
	end

	local clone = template:Clone()
	if not clone then
		warn("LithSummonEffect → Failed to clone")
		return
	end

	local emitter = clone:FindFirstChildWhichIsA("ParticleEmitter", true)
	if not emitter then
		clone:Destroy()
		warn("LithSummonEffect → No ParticleEmitter found")
		return
	end

	emitter.Color = ColorSequence.new(color)
	clone:PivotTo(CFrame.new(pos))
	clone.Parent = EffectsFolder

	emitter:Emit(1000)

	task.spawn(function()
		task.wait(lifetime / 2)
		if emitter and emitter.Parent then
			emitter.Enabled = false
		end
		task.wait(lifetime / 2)
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

return effectMod :: EffectMod