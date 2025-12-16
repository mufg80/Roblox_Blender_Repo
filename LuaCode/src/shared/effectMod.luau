--!strict
local replicatedstorage = game:GetService("ReplicatedStorage")
local utilMod = require(replicatedstorage.Shared.utilMod)
local statsMod = require(replicatedstorage.Shared.statsMod)
local effectMod = {}

function effectMod.SummonCreatureEffect(spawnpoint: Vector3, creatureName: string, secs: number)
	-- Start effects here
	local groundY = utilMod.DistancetoGround(spawnpoint)
	if not groundY then
		groundY = spawnpoint.Y
	end
	spawnpoint = Vector3.new(spawnpoint.X, groundY, spawnpoint.Z)
	local magictype = statsMod.creatureStats[creatureName] and statsMod.creatureStats[creatureName].magicType
	if magictype then
		local effectname = tostring(magictype) .. "SummonEffect"
		local effectclone = replicatedstorage.Effects:FindFirstChild(effectname):Clone()
		local basepart = effectclone:FindFirstChildWhichIsA("BasePart")
		if basepart then
			local width = statsMod.creatureStats[creatureName] and statsMod.creatureStats[creatureName].width or 8
			basepart.Size = Vector3.new(width, 10, width)
			for _, effect in pairs(basepart:GetChildren()) do
				if effect:IsA("ParticleEmitter") then
					effect.Rate = effect.Rate * width
				end
			end
		end
		effectclone.Parent = workspace
		effectclone:PivotTo(CFrame.new(spawnpoint))
		task.delay(secs + 3, function()
			for _, effect in pairs(basepart:GetChildren()) do
				if effect:IsA("ParticleEmitter") then
					effect.Enabled = false
				end
			end
			task.delay(secs + 5, function()
				effectclone:Destroy()
			end)
		end)
	end
end

function effectMod.DirectDamageEffect(spawnpoint: Vector3, spellName: string)
	local spelleffect = replicatedstorage.Effects:FindFirstChild(spellName .. "Effect"):Clone()
	if not spelleffect then
		warn("effect not found.")
		return
	end
	local spellinfo = statsMod.SpellInfo[spellName]
	local num = utilMod.DistancetoGround(spawnpoint)
	if not num then
		num = 0
	end
	local yoffset = spawnpoint.Y - num
	local effectorigin = spawnpoint + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)
	spelleffect:PivotTo(CFrame.new(effectorigin))
	spelleffect.Parent = workspace
	for _, eff in pairs(spelleffect:GetDescendants()) do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end
	task.delay(spellinfo.effectTime, function()
		for _, child in pairs(spelleffect:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		task.delay(2, function()
			spelleffect:Destroy()
		end)
	end)
end

function effectMod.AOEDamageEffect(spawnpoint: Vector3, spellName: string)
	local spelleffect = replicatedstorage.Effects:FindFirstChild(spellName .. "Effect"):Clone()
	if not spelleffect then
		warn("effect not found.")
		return
	end
	local spellinfo = statsMod.SpellInfo[spellName]
	local num = utilMod.DistancetoGround(spawnpoint)
	if not num then
		num = 0
	end
	local yoffset = spawnpoint.Y - num
	local effectorigin = spawnpoint + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)
	spelleffect:PivotTo(CFrame.new(effectorigin))
	local emitterPart = spelleffect:FindFirstChild("CylinderEmitter")
	if emitterPart then
		emitterPart.Size = Vector3.new(15, spellinfo.range * 2, spellinfo.range * 2)
	end
	spelleffect.Parent = workspace
	for _, eff in pairs(spelleffect:GetDescendants()) do
		if eff:IsA("ParticleEmitter") then
			eff:Emit(20)
		end
	end
	task.delay(spellinfo.effectTime, function()
		for _, child in pairs(spelleffect:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		task.delay(2, function()
			spelleffect:Destroy()
		end)
	end)
end

function effectMod.BuffEffects(locs: {Model}, spellName: string)
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("should not reach me")
        return
	end

	for _, item in pairs(locs) do
		local spelleffect = replicatedstorage.Effects:FindFirstChild(spellName .. "Effect"):Clone()
		if not spelleffect then
			warn("effect not found.")
			return
		end
		local hrp = item:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local num = utilMod.DistancetoGround(hrp.Position)
		if not num then
			num = 0
		end
		local yoffset = hrp.Position.Y - num
		local effectorigin = hrp.Position + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))

		local emitterPart = spelleffect:FindFirstChild("EmitterBox")
		local creaturesize = statsMod.creatureStats[utilMod.customTrim(item)]
				and statsMod.creatureStats[utilMod.customTrim(item)].width
			or 3
		if emitterPart then
			emitterPart.Size = Vector3.new(creaturesize, 10, creaturesize)
		end
		spelleffect.Parent = workspace
		for _, eff in pairs(spelleffect:GetDescendants()) do
			if eff:IsA("ParticleEmitter") then
				eff:Emit(50)
			end
		end
		task.delay(spellinfo.effectTime, function()
			for _, child in pairs(spelleffect:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			task.delay(2, function()
				spelleffect:Destroy()
			end)
		end)
	end
end

function effectMod.DeBuffEffects(locs: {Model}, spellName: string)
	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("should not reach me")
        return
	end

	for _, item in pairs(locs) do
		local spelleffect = replicatedstorage.Effects:FindFirstChild(spellName .. "Effect"):Clone()
		if not spelleffect then
			warn("effect not found.")
			return
		end
		local hrp = item:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local num = utilMod.DistancetoGround(hrp.Position)
		if not num then
			num = 0
		end
		local yoffset = hrp.Position.Y - num
		local effectorigin = hrp.Position + Vector3.new(spellinfo.effectOffsetXZ, -yoffset, spellinfo.effectOffsetXZ)
		spelleffect:PivotTo(CFrame.new(effectorigin))

		local emitterPart = spelleffect:FindFirstChild("EmitterBox")
		local creaturesize = statsMod.creatureStats[utilMod.customTrim(item)]
				and statsMod.creatureStats[utilMod.customTrim(item)].width
			or 3
		if emitterPart then
			emitterPart.Size = Vector3.new(creaturesize, 10, creaturesize)
		end
		spelleffect.Parent = workspace
		for _, eff in pairs(spelleffect:GetDescendants()) do
			if eff:IsA("ParticleEmitter") then
				eff:Emit(50)
			end
		end
		task.delay(spellinfo.effectTime, function()
			for _, child in pairs(spelleffect:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			task.delay(2, function()
				spelleffect:Destroy()
			end)
		end)
	end
end

export type effectMod = {
	SummonCreatureEffect: (spawnpoint: Vector3, creatureName: string, secs: number) -> (),
	DirectDamageEffect: (spawnpoint: Vector3, spellName: string) -> (),
	AOEDamageEffect: (locs: Vector3, spellName: string) -> (),
	BuffEffects: (locs: {Model}, spellName: string) -> (),
	DeBuffEffects: (locs: {Model}, spellName: string) -> (),
}

return effectMod