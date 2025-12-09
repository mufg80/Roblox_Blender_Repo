local replicatedstorage = game:GetService("ReplicatedStorage")
local utilMod = require(replicatedstorage.Shared.utilMod)
local statsMod = require(replicatedstorage.Shared.statsMod)
local serverstorage = game:GetService("ServerStorage")
local effectMod = {}

function effectMod.SummonCreatureEffect(spawnpoint:Vector3, creatureName: string, secs:number)


	-- Start effects here
	local groundY = utilMod.DistancetoGround(spawnpoint)
	if not groundY then groundY = spawnpoint.Y end
	spawnpoint = Vector3.new(spawnpoint.X, groundY, spawnpoint.Z)
	local magictype = statsMod.creatureStats[creatureName] and statsMod.creatureStats[creatureName].magicType
	if magictype then
		local effectname = tostring(magictype).."SummonEffect"
		local effectclone = serverstorage.Effects:FindFirstChild(effectname):Clone()
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

function effectMod.DirectDamageEffect(spawnpoint:Vector3, spellName:string)
    local spelleffect = serverstorage.Effects:FindFirstChild(spellName.."Effect"):Clone()
    if not spelleffect then warn("effect not found.") return end
    local spellinfo = statsMod.SpellInfo[spellName]
    local num = utilMod.DistancetoGround(spawnpoint)
    if not num then num = 0 end
    local yoffset = spawnpoint.Y - num
    print(yoffset)
    local effectorigin = spawnpoint + Vector3.new(spellinfo.effectOffsetXZ, spawnpoint.Y - yoffset, spellinfo.effectOffsetXZ)
    spelleffect:PivotTo(CFrame.new(effectorigin))
    spelleffect.Parent = workspace
    task.delay(spellinfo.effectTime, function()
        for _,child in pairs(spelleffect:GetDescendants()) do
            if child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end
        task.delay(2, function()
            spelleffect:Destroy()
        end)
    end)
end

function effectMod.AOEDamageEffect(locs: table, spellName:string)
    local spelleffect = serverstorage.Effects:FindFirstChild(spellName.."Effect")
    if not spelleffect then warn("effect not found.") return end
end

function effectMod.BuffEffects(locs: table, spellName:string)
    local spelleffect = serverstorage.Effects:FindFirstChild(spellName.."Effect")
    if not spelleffect then warn("effect not found.") return end
end

function effectMod.DeBuffEffects(locs: table, spellName:string)
    local spelleffect = serverstorage.Effects:FindFirstChild(spellName.."Effect")
    if not spelleffect then warn("effect not found.") return end

end


export type effectMod = {
    SummonCreatureEffect: (spawnpoint:Vector3, creatureName: string, secs:number) -> (),
    DirectDamageEffect: (spawnpoint:Vector3, spellName:string) -> (),
    AOEDamageEffect: (locs: table, spellName:string) -> (),
    BuffEffects: (locs: table, spellName:string) -> (),
    DeBuffEffects: (locs: table, spellName:string) -> (),
}

return effectMod