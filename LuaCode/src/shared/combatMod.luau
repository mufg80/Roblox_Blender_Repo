local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local buffMod = require(game.ReplicatedStorage.Shared.buffMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local serverstorage = game:GetService("ServerStorage")
local combatMod = {}


local random = Random.new(tick())


function combatMod.LeveltoManaCost(creatureName:string)
    local creature = statsMod.creatureStats[creatureName]
    if not creature then return math.huge end
    local tenth = creature.level * 0.1
    return tenth * statsMod.MaxSpellCost
end

-- SpellAttackResult - now accounts for caster level vs target level
function combatMod.SpellAttackResult(attackerCreatureName, defenderCreatureName, spellName)
    local attackerStats = statsMod.creatureStats[attackerCreatureName]
    local defenderStats = statsMod.creatureStats[defenderCreatureName]
    local spell = statsMod.SpellInfo[spellName]
    
    if not (attackerStats and defenderStats and spell) then return 0 end

    -- =================================================================
    -- 1. Determine Magic Level of Attacker (Player or NPC)
    -- =================================================================
    local attackerLevel = attackerStats.level


    -- =================================================================
    -- 2. Determine Magic Level of Defender (Player or NPC)
    -- =================================================================
    local defenderLevel = defenderStats.level

    -- =================================================================
    -- 3. Determine relevant magic defense
    -- =================================================================
    local relevantDefense = defenderStats.artificermagicdefense
    if spell.magicType == "Primordial" then
        relevantDefense = defenderStats.primordialmagicdefense
    elseif spell.magicType == "Nature" then
        relevantDefense = defenderStats.naturemagicdefense
    end

    -- =================================================================
    -- 4. Miss Chance: base + level difference penalty
    --    Level 1 vs Level 7 → big disadvantage
    -- =================================================================
    
    local levelDiff = ((defenderLevel - attackerLevel) * 4) * 0.01
    local levelPenalty = math.clamp(levelDiff + 0.15, 0.0, 0.30)  -- +0% to +35% miss chance if lower level
    
    local finalMissChance = math.clamp(spell.missChance + levelPenalty, 0.10, 0.65)  -- cap at 75%

    if random:NextNumber() < finalMissChance then
        return 0  -- Miss / fully resisted
    end

    -- =================================================================
    -- 5. Base effect from spell
    -- =================================================================
    local base = spell.effectMultiplier
    local MAX_CONSTANT = statsMod.MaxSpellDamage
    base = base * MAX_CONSTANT

    -- =================================================================
    -- 6. Resistance reduction (scaled by level advantage too)
    -- =================================================================
    local reduction = random:NextNumber(relevantDefense / 2 , relevantDefense)
    local afterResist = base * (1 - reduction)

    -- Bonus damage if higher level (small boost)
    local levelBonus = math.clamp((attackerLevel - defenderLevel) * 0.08, -0.3, 0.3)  -- -30% to +40%
    local afterResist1 = afterResist * (1 + levelBonus)

    -- =================================================================
    -- 7. Random variance + AOE penalty
    -- =================================================================
    local variance = random:NextNumber(0.75, 1.25) 
    local final = afterResist1 * variance


    -- =================================================================
    -- 8. Final clamp & return
    -- =================================================================
    local finalmaxed = math.max(final, 1)
    local finalfloored = math.floor(finalmaxed + 0.5)
    print(attackerCreatureName.." hits "..defenderCreatureName.." with "..spellName.." for "..finalfloored.." points of damage.")
    return finalfloored
end


function combatMod.AcceptableDistanceToOpponent(model, enemy)
    local enemyTable = combatMod.GetStatsSafelyForPlrorNpc(enemy)
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    local enemyhrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
    if not hrp or not enemyhrp then return false end
    
    local distance = utilMod.GetMagnitude(hrp, enemyhrp)
    return distance <= (enemyTable.distanceForAttacker)
end


function combatMod.GetStatsSafelyForPlrorNpc(npc)
    local enemyTable = nil
    if utilMod.IsPlayer(npc)then
        local plr = game.Players:GetPlayerFromCharacter(npc)
        local magic = plr:GetAttribute("Magic")
        enemyTable = combatMod.ShallowTableCopy("Player"..magic)
    else
        enemyTable = combatMod.ShallowTableCopy(npc)
    end
    return enemyTable
end

function combatMod.MeleeAttackResult(attacker, defender)
    local attackerstats = combatMod.GetStatsSafelyForPlrorNpc(attacker)
    local defenderstats = combatMod.GetStatsSafelyForPlrorNpc(defender)

    -- MISS CHANCE CALCULATION (15% floor, 30% ceiling)
    local defenseAdvantage = defenderstats.defense - attackerstats.attack
    local missChance = math.clamp(defenseAdvantage * 25, 0.15, 0.30)
    local MAXDAMAGECONSTANT = statsMod.MaxDamageConstant
    
    -- Roll for miss
    if math.random() < missChance then
        return 0  -- Complete miss!
    end

    -- Base damage from attack stat
    local baseDamage = attackerstats.attack * MAXDAMAGECONSTANT

    -- Max possible damage cap
    local maxPossibleDamage = attackerstats.maxDamage * (MAXDAMAGECONSTANT * 1.5)

    -- Defense reduces damage (diminishing returns)
    local defenseReduction = defenderstats.defense * 12
    local damageAfterDefense = math.max(baseDamage - defenseReduction, baseDamage * 0.3)

    -- Armour reduces percentage of remaining damage
    local armourReduction = defenderstats.armour
    local damageAfterArmour = damageAfterDefense * (1 - armourReduction)

    -- Final calculated damage: clamp between 1 and maxPossibleDamage
    local calculatedDamage = math.clamp(damageAfterArmour, 1, maxPossibleDamage)

    -- **RANDOM DAMAGE MULTIPLIER** (50% to 100% of calculated damage)
    local damageMultiplier = math.random() * 0.5 + 0.5  -- 0.5 to 1.0
    local finalDamage = calculatedDamage * damageMultiplier

    -- Ensure minimum 1 damage
    finalDamage = math.clamp(finalDamage, 1, maxPossibleDamage)
    local final = math.floor(finalDamage + 0.5)
    print(attacker.Name.." hits "..defender.Name.." for "..final.." points of damage.")
    -- Return as integer
    return final
end

function combatMod.ShallowTableCopy(name)
    local trimmed = combatMod.customTrim(tostring(name))
    local t = statsMod.creatureStats[trimmed]
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

-- ReplicatedStorage.Shared.combatMod
function combatMod.ApplyStaffDamage(hitPart: BasePart, ownerPlayer: Player, staffType: string)
    -- Find the hit character/model
    local hitCharacter = hitPart:FindFirstAncestorWhichIsA("Model")
    if not hitCharacter then return false end

    -- === ALLY PROTECTION: Never damage own character OR anything you own ===
    local ownerUserId = ownerPlayer.UserId

    -- 1. Prevent self-damage (your character)
    if ownerPlayer.Character == hitCharacter then
        return false
    end

    -- 2. Prevent damage to any pet/NPC owned by this player
    local targetOwnerId = hitCharacter:GetAttribute("OwnedBy")
    if targetOwnerId and targetOwnerId == ownerUserId then
        return false  -- This is my pet, my summon, my minion — do NOT damage!
    end

    -- === Normal damage flow starts here ===
    local targetName = combatMod.customTrim(hitCharacter.Name)

    -- Calculate spell damage (your existing system)
    local damage = combatMod.SpellAttackResult(
        staffType:match("Artificer") and "PlayerArtificer" or
        staffType:match("Nature") and "PlayerNature" or
        "PlayerPrimordial",
        targetName,
        staffType
    )

    if not damage or damage <= 0 then
        -- Still generate threat even on block/miss (good for PvP & PvE balance)
        local addThreat = hitCharacter:FindFirstChild("AddThreat")
        if addThreat and addThreat:IsA("BindableEvent") then
            addThreat:Fire(ownerUserId, 25)
        end
        return false
    end

    local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    -- Creator tag for kill credit
    local creator = Instance.new("ObjectValue")
    creator.Name = "creator"
    creator.Value = ownerPlayer
    creator.Parent = humanoid

    task.delay(0.5, function()
        if creator and creator.Parent then
            creator:Destroy()
        end
    end)

    -- Apply damage
    humanoid.Health = math.max(humanoid.Health - damage, 0)

    -- Optional: small threat on successful hits too? (common in MMOs)
    -- local addThreat = hitCharacter:FindFirstChild("AddThreat")
    -- if addThreat then addThreat:Fire(ownerUserId, 10) end

    return true -- Damage successfully applied
end

function combatMod.ExecuteDamageToBody(playerId, target, damage)
    local owningplayer = game.Players:GetPlayerByUserId(playerId)
    if not owningplayer then warn("should not reach here.") return end
    -- 1. Prevent self-damage (your character)
    if not owningplayer.Character or owningplayer.Character == target then
        return false
    end

    -- 2. Prevent damage to any pet/NPC owned by this player
    local targetOwnerId = target:GetAttribute("OwnedBy")
    if targetOwnerId and targetOwnerId == playerId then
        return false  -- This is my pet, my summon, my minion — do NOT damage!
    end

    -- === Normal damage flow starts here ===
    local targetName = combatMod.customTrim(target.Name)

    if not damage or damage <= 0 then
        -- Still generate threat even on block/miss (good for PvP & PvE balance)
        local addThreat = target:FindFirstChild("AddThreat")
        if addThreat and addThreat:IsA("BindableEvent") then
            addThreat:Fire(playerId, 25)
        end
        return false
    end

    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    -- Creator tag for kill credit
    local creator = Instance.new("ObjectValue")
    creator.Name = "creator"
    creator.Value = owningplayer
    creator.Parent = humanoid

    task.delay(0.5, function()
        if creator and creator.Parent then
            creator:Destroy()
        end
    end)

    -- Apply damage
    humanoid.Health = math.max(humanoid.Health - damage, 0)

    -- Optional: small threat on successful hits too? (common in MMOs)
    -- local addThreat = hitCharacter:FindFirstChild("AddThreat")
    -- if addThreat then addThreat:Fire(ownerUserId, 10) end

    return true -- Damage successfully applied
end

function combatMod.ApplyAbility(player, creatureName, recyleMod)
local cost = combatMod.LeveltoManaCost(creatureName)
	local mana = player:GetAttribute("Mana")
	if mana < cost then
		warn("No mana")
		return
	end
   
    local creature = serverstorage.Entities:FindFirstChild(creatureName)
    if creature then
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
				local height = statsMod.creatureStats[creatureName].height

				local spawnpoint = utilMod.FindClearSpawnPoint(player, 10)
				if not spawnpoint then
					warn("NO place to spawn pet.")
					return
				end

				local GroundAtSpawn = utilMod.DistancetoGround(spawnpoint)
				local mobPos = GroundAtSpawn + height + 1
				local mobposvector = Vector3.new(spawnpoint.X, mobPos, spawnpoint.Z)
				local lookatVector = (mobposvector - hrp.Position) * 2
                local summonedCreature = nil
				if recyleMod.CheckIfExistsPet(creatureName) then
					summonedCreature = recyleMod.ReturnPet(creatureName)
					summonedCreature:SetAttribute("OwnedBy", player.UserId)
					summonedCreature.Parent = workspace:WaitForChild("Pets")
					player:SetAttribute("Mana", mana - cost)
				else
					summonedCreature = creature:Clone()
					local name = utilMod.uniqueName(creatureName)
					summonedCreature.Name = name
					summonedCreature:SetAttribute("OwnedBy", player.UserId)
					summonedCreature:AddTag("Character")
					summonedCreature.Parent = workspace:WaitForChild("Pets")
					player:SetAttribute("Mana", mana - cost)
				end
				
				
                local creatureHRP = summonedCreature:FindFirstChild("HumanoidRootPart")
                if creatureHRP then
                    creatureHRP.CFrame = CFrame.new(mobposvector, lookatVector)
                else
                    warn("Summoned creature "..creatureName.." has no HumanoidRootPart")
                end
            end
        end
    else
        warn("Creature "..creatureName.." not found in Serverstorate.Entities")
    end
end

function combatMod.ApplySpell(player, spellname)
    local playerType = combatMod.GetPlayerType(player)
    local info = statsMod.SpellInfo[spellname]
    if not info then warn("should not reach here.") return end

    local cost = statsMod.SpellInfo[spellname].manaCost * statsMod.MaxSpellCost
    if not cost then warn("should not reach me") return end
    local mana = player:GetAttribute("Mana")
	if mana < cost then
		warn("No mana")
		return
	end

	if info.spellType == "damage" then
		-- select target player highest priority then pets then ferals
		local targetplayer = utilMod.GetClosestPlayer(player)
        local applied = false
		if targetplayer and targetplayer.Character and utilMod.GetMagnitudeHelper(player.Character, targetplayer.Character) < info.range then
            local targetplayertype = combatMod.GetPlayerType(targetplayer)
			local damage = combatMod.SpellAttackResult(playerType, targetplayertype, spellname)
			if combatMod.ExecuteDamageToBody(player.UserId, targetplayer.Character, damage) then applied = true end
			return
		end
		local targetpet = utilMod.GetClosestModelSkipownPets(player, "Pets")
		if targetpet and utilMod.GetMagnitudeHelper(player.Character, targetpet) < info.range then
			local damage = combatMod.SpellAttackResult(playerType, combatMod.customTrim(targetpet.Name), spellname)
			if combatMod.ExecuteDamageToBody(player.UserId, targetpet, damage) then applied = true end
			return
		end

		local targetferal = utilMod.GetClosestModelSkipownPets(player, "Ferals")
		if targetferal and utilMod.GetMagnitudeHelper(player.Character, targetferal) < info.range then
			local damage = combatMod.SpellAttackResult(playerType, combatMod.customTrim(targetferal.Name), spellname)
			if combatMod.ExecuteDamageToBody(player.UserId, targetferal, damage) then applied = true end
			return
		end
        if applied then
            player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
        end

	elseif info.spellType == "areadamage" then
        local mobs = 1
        local playerchars = utilMod.GetEnemyPlayersWithinRange(player, info.range)
        local models = utilMod.GetEnemyModelsWithinRange(player, info.range)

        for i,plr in ipairs(playerchars) do
            if mobs <= info.numberTargets then
                local targetplayertype = combatMod.GetPlayerType(plr)
                local damage = combatMod.SpellAttackResult(playerType, targetplayertype, spellname)
                combatMod.ExecuteDamageToBody(player.UserId, plr.Character, damage)
            end
            mobs += 1
        end
        for i, mob in ipairs(models) do
            if mobs <= info.numberTargets then
                local damage = combatMod.SpellAttackResult(playerType, combatMod.customTrim(mob.Name), spellname)
                combatMod.ExecuteDamageToBody(player.UserId, mob, damage)                
            end
            mobs += 1
        end
        if mobs > 1 then
            player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
        end

	elseif info.spellType == "buff" then
        local mypets = utilMod.MyPets(player)
        if not mypets then warn("Nopets") return end
        local applied = false
        for _,i in ipairs(mypets) do
            if mypets[i]:GetAttribute(info) == false then
                mypets[i]:SetAttribute(info, true)
                applied = true
            end
        end
        if applied then
            player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
        end

	elseif info.spellType == "debuff" then
        local playerchars = utilMod.GetEnemyPlayersWithinRange(player, info.range)
        local models = utilMod.GetEnemyModelsWithinRange(player, info.range)
        local applied = false
        if playerchars then
            for _,plr in ipairs(playerchars) do
                if player:GetAttribute(info) == false then
                    player:SetAttribute(info, true)
                    applied = true
                end
            end
        end
        
        if models then
            for _,mob in ipairs(models) do
                if mob:GetAttribute(info) == false then
                    mob:SetAttribute(info, true)
                    applied = true
                end
            end
        end
        
        if applied then
            player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
        end
	elseif info.spellType == "heal" then
        local mypets = utilMod.MyPets(player)
        local applied = buffMod.ApplyHeals(player, info, mypets, statsMod.MaxSpellDamage)
        
        if applied then
            player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
        end
	elseif info.spellType == "utility" then
            if spellname == "ReclaimPet" then
                local mypets = utilMod.MyPets(player)
                if not mypets then warn("No pets") return end
                local applied = buffMod.ReclaimPet(player, spellname, mypets)

                if applied then
                    player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
                end
            elseif spellname == "ConvertSpout" then
                
                local applied = buffMod.ConvertSpout(player)

                if applied then
                    player:SetAttribute("Mana", player:GetAttribute("Mana") - cost)
                end
            end

        

	else
		warn("should not reach me.")
	end

end

function combatMod.GetPlayerType(player)
    if not player then return nil end
    local magictype = player:GetAttribute("Magic")
    if not magictype then return nil end
    if magictype == "Artificer" then
        return "PlayerArtificer" 
    elseif magictype == "Primordial" then
        return "PlayerPrimordial" 
    elseif magictype == "Nature" then
        return "PlayerNature"
    else 
        warn("Should not reach here.")
    end
end

-- Applies melee damage from an NPC/pet to any target
-- Handles: creator tag, damage calculation, health application, threat
function combatMod.ApplyMeleeDamage(attackerModel: Model, targetModel: Model)
    if not attackerModel or not targetModel then return false end

    local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
    if not targetHum then return false end

    -- === ALLY PROTECTION (same logic as staffs) ===
    local attackerOwnerId = attackerModel:GetAttribute("OwnedBy")
    if attackerOwnerId and typeof(attackerOwnerId) == "number" then
        -- Don't hit your owner
        local ownerPlayer = game.Players:GetPlayerByUserId(attackerOwnerId)
        if ownerPlayer and ownerPlayer.Character == targetModel then
            return false
        end

        -- Don't hit anything else owned by the same player (other pets, summons, etc.)
        local targetOwnerId = targetModel:GetAttribute("OwnedBy")
        if targetOwnerId and targetOwnerId == attackerOwnerId then
            return false
        end
    end

    -- Calculate damage using your existing system
    local damage = combatMod.MeleeAttackResult(attackerModel, targetModel)
    if not damage or damage <= 0 then
        -- Still generate threat on block/miss
        local addThreat = targetModel:FindFirstChild("AddThreat")
        if addThreat and addThreat:IsA("BindableEvent") then
            local threatSourceId = attackerModel.Name
            addThreat:Fire(threatSourceId, 5)
        end
        return false
    end

    local creator = Instance.new("ObjectValue")
    creator.Name = "creator"
    creator.Value = attackerModel
    creator.Parent = targetHum

    task.delay(0.5, function()
        if creator and creator.Parent then
            creator:Destroy()
        end
    end)

    -- Apply damage
    targetHum.Health = math.max(targetHum.Health - damage, 0)

    return true
end

function combatMod.CalculateAggro(damageTaken)
    return damageTaken * 1.5 + 30
end

return combatMod