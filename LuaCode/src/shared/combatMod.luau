--!strict
-- ReplicatedStorage.Shared.combatMod
-- Combat calculation & damage application utilities

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local buffMod = require(game.ReplicatedStorage.Shared.buffMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)

local combatMod = {}

local random = Random.new(tick())

--==============================================================================
-- Calculates mana cost for summoning a creature based on its level
--==============================================================================
function combatMod.LeveltoManaCost(creatureInstance: Instance): number
	-- Retrieves the creature's stats table (or returns huge if missing)
	local creature = statsMod.creatureStats[creatureInstance]
	if not creature then
		return math.huge
	end

	local tenth = creature.level * 0.1
	return tenth * statsMod.MaxSpellCost
end

--==============================================================================
-- Calculates spell damage with level difference, resistances, miss chance, etc.
-- Returns final integer damage (0 = miss/resist)
--==============================================================================
function combatMod.SpellAttackResult(
	attackerCreatureInstance: Instance,
	defenderCreatureInstance: Instance,
	spellName: string
): number
	-- Resolve attacker stats (supports both character model and player folder)
	local attackerStats = utilMod.GetStatsFromFolder(attackerCreatureInstance)
	if not attackerStats or next(attackerStats) == nil then
		local plr = Players:GetPlayerFromCharacter(attackerCreatureInstance)
		if plr then
			attackerStats = utilMod.GetStatsFromFolder(plr)
		end
	end

	-- Resolve defender stats (same fallback logic)
	local defenderStats = utilMod.GetStatsFromFolder(defenderCreatureInstance)
	if not defenderStats or next(defenderStats) == nil then
		local plr = Players:GetPlayerFromCharacter(defenderCreatureInstance)
		if plr then
			defenderStats = utilMod.GetStatsFromFolder(plr)
		end
	end

	local spell = statsMod.SpellInfo[spellName]
	if not (attackerStats and defenderStats and spell) then
		return 0
	end

	local attackerLevel: number = attackerStats.level
	local defenderLevel: number = defenderStats.level

	-- Choose appropriate magic defense based on spell type
	local relevantDefense: number = defenderStats.artificermagicdefense
	if spell.magicType == "Primordial" then
		relevantDefense = defenderStats.primordialmagicdefense
	elseif spell.magicType == "Nature" then
		relevantDefense = defenderStats.naturemagicdefense
	end

	-- Miss chance: base + penalty when attacker is lower level
	local levelDiff = (defenderLevel - attackerLevel) * 4 * 0.01
	local levelPenalty = math.clamp(levelDiff + 0.15, 0.0, 0.30) -- 0% → 30%
	local finalMissChance = math.clamp(spell.missChance + levelPenalty, 0.10, 0.65)

	if random:NextNumber() < finalMissChance then
		return 0 -- Miss / fully resisted
	end

	-- Base damage before any reductions
	local base = spell.effectMultiplier * statsMod.MaxSpellDamage

	-- Resistance reduction (random between half and full defense value)
	local reduction = random:NextNumber(relevantDefense / 2, relevantDefense)
	local afterResist = base * (1 - reduction)

	-- Small bonus/penalty based on level difference
	local levelBonus = math.clamp((attackerLevel - defenderLevel) * 0.08, -0.3, 0.3)
	local afterResist1 = afterResist * (1 + levelBonus)

	-- Random variance (75%–125%)
	local variance = random:NextNumber(0.75, 1.25)
	local final = afterResist1 * variance

	-- Final clamp & rounding
	local finalmaxed = math.max(final, 1)
	return math.floor(finalmaxed + 0.5)
end

--==============================================================================
-- Checks if a model is within the attack range defined in its stats
--==============================================================================
function combatMod.AcceptableDistanceToOpponent(model: Model, enemy: Model): boolean
	local enemyTable = utilMod.GetStatsFromFolder(enemy)
	if not enemyTable or next(enemyTable) == nil then
		local plr = Players:GetPlayerFromCharacter(enemy)
		if plr then
			enemyTable = utilMod.GetStatsFromFolder(plr)
		end
	end
	if not enemyTable then
		return false
	end

	local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	local enemyhrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
	if not hrp or not enemyhrp then
		return false
	end

	local distance = utilMod.GetDistance(hrp.Position, enemyhrp.Position)
	return distance <= enemyTable.distanceForAttacker
end

--==============================================================================
-- Safely retrieves a shallow-copied stats table for player or NPC
--==============================================================================
function combatMod.GetStatsSafelyForPlrorNpc(npc: Instance): table?
	if utilMod.IsPlayer(npc) then
		local plr = Players:GetPlayerFromCharacter(npc)
		if not plr then
			return nil
		end
		local magic = plr:GetAttribute("Magic") :: string
		return combatMod.ShallowTableCopy("Player" .. magic)
	else
		return combatMod.ShallowTableCopy(npc)
	end
end

--==============================================================================
-- Calculates melee damage with miss chance, defense, armour, variance, etc.
-- Returns final integer damage (0 = miss)
--==============================================================================
function combatMod.MeleeAttackResult(attacker: Instance, defender: Instance): number
	local attackerstats = utilMod.GetStatsFromFolder(attacker)
	local defenderstats = utilMod.GetStatsFromFolder(defender)

	-- Fallback to player folder if stats not found directly on character
	if not attackerstats or next(attackerstats) == nil then
		local plr = Players:GetPlayerFromCharacter(attacker)
		if plr then
			attackerstats = utilMod.GetStatsFromFolder(plr)
		end
	end
	if not defenderstats or next(defenderstats) == nil then
		local plr = Players:GetPlayerFromCharacter(defender)
		if plr then
			defenderstats = utilMod.GetStatsFromFolder(plr)
		end
	end
	if not (attackerstats and defenderstats) then
		return 0
	end

	-- Miss chance based on defense vs attack difference
	local defenseAdvantage = defenderstats.defense - attackerstats.attack
	local missChance = math.clamp(defenseAdvantage * 25, 0.15, 0.30)

	if math.random() < missChance then
		return 0 -- Miss
	end

	local MAXDAMAGECONSTANT = statsMod.MaxDamageConstant
	local baseDamage = attackerstats.attack * MAXDAMAGECONSTANT
	local maxPossibleDamage = attackerstats.maxDamage * (MAXDAMAGECONSTANT * 1.5)

	-- Defense flat reduction (with diminishing returns floor)
	local defenseReduction = defenderstats.defense * 12
	local damageAfterDefense = math.max(baseDamage - defenseReduction, baseDamage * 0.3)

	-- Armour percentage reduction
	local damageAfterArmour = damageAfterDefense * (1 - defenderstats.armour)

	-- Clamp to max possible
	local calculatedDamage = math.clamp(damageAfterArmour, 1, maxPossibleDamage)

	-- Random multiplier 50%–100%
	local damageMultiplier = math.random() * 0.5 + 0.5
	local finalDamage = calculatedDamage * damageMultiplier

	finalDamage = math.clamp(finalDamage, 1, maxPossibleDamage)
	return math.floor(finalDamage + 0.5)
end

--==============================================================================
-- Creates a shallow copy of a creature's stats table (used for safe stat access)
--==============================================================================
function combatMod.ShallowTableCopy(name: any): table?
	local trimmed = combatMod.customTrim(tostring(name))
	local t = statsMod.creatureStats[trimmed]
	if not t then
		warn("No stats found for:", name)
	end
	local copy = {}
	for k, v in pairs(t or {}) do
		copy[k] = v
	end
	return copy
end

--==============================================================================
-- Trims trailing underscore + alphanumerics (used to normalise creature names)
--==============================================================================
function combatMod.customTrim(input: string?): string
	if typeof(input) ~= "string" then
		return ""
	end
	return input:gsub("_[%w]*$", "")
end

--==============================================================================
-- Applies staff spell damage (called from tool hit detection)
--==============================================================================
function combatMod.ApplyStaffDamage(hitPart: BasePart, ownerPlayer: Player, staffType: string): boolean
	local hitCharacter = hitPart:FindFirstAncestorWhichIsA("Model")
	if not hitCharacter or not hitCharacter:FindFirstChild("Humanoid") then
		return false
	end

	local ownerUserId = ownerPlayer.UserId

	-- Prevent self-damage and damage to owned entities
	if ownerPlayer.Character == hitCharacter then
		return false
	end
	local targetOwnerId = hitCharacter:GetAttribute("OwnedBy")
	if targetOwnerId and targetOwnerId == ownerUserId then
		return false
	end

	local damage = combatMod.SpellAttackResult(ownerPlayer, hitCharacter, staffType)

	if not damage or damage <= 0 then
		-- Still generate threat on miss/block
		utilMod.ApplyThreat(ownerPlayer, hitCharacter, 25)
		return false
	else
		utilMod.ApplyThreat(ownerPlayer, hitCharacter, combatMod.CalculateAggro(damage))
	end

	local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

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

	humanoid.Health = math.max(humanoid.Health - damage, 1)
	return true
end

--==============================================================================
-- Generic damage application used by spells/abilities
--==============================================================================
function combatMod.ExecuteSpellDamageToBody(playerId: number, target: Model, damage: number?): boolean
	local owningplayer = Players:GetPlayerByUserId(playerId)
	if not owningplayer then
		return false
	end

	if not owningplayer.Character or owningplayer.Character == target then
		return false
	end

	local targetOwnerId = target:GetAttribute("OwnedBy")
	if targetOwnerId and targetOwnerId == playerId then
		return false
	end

	if not damage or damage <= 0 then
		utilMod.ApplyThreat(owningplayer, target, 25)
		return false
	else
		utilMod.ApplyThreat(owningplayer, target, combatMod.CalculateAggro(damage))
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local creator = Instance.new("ObjectValue")
	creator.Name = "creator"
	creator.Value = owningplayer
	creator.Parent = humanoid
	task.delay(0.5, function()
		if creator and creator.Parent then
			creator:Destroy()
		end
	end)

	humanoid.Health = math.max(humanoid.Health - damage, 1)
	return true
end

--==============================================================================
-- Summons or recycles a creature/pet for a player
--==============================================================================
function combatMod.ApplyAbility(player: Player, creatureName: string, recyleMod: any)
	local cost = combatMod.LeveltoManaCost(creatureName)
	local mana = player:GetAttribute("Mana") or 0
	if mana < cost then
		warn("Not enough mana")
		return
	end

	local creature = ServerStorage.Entities:FindFirstChild(creatureName)
	if not creature then
		warn("Creature not found:", creatureName)
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local height = statsMod.creatureStats[creatureName].height
	local spawnpoint = utilMod.FindClearSpawnPoint(player, 10)
	if not spawnpoint then
		warn("No clear spawn point")
		return
	end

	local groundY = utilMod.DistancetoGround(spawnpoint)
	local mobPos = Vector3.new(spawnpoint.X, groundY + height + 1, spawnpoint.Z)
	local lookAt = (mobPos - hrp.Position) * 2

	local summonedCreature: Model

	if recyleMod.CheckIfExistsPet(creatureName) then
		summonedCreature = recyleMod.ReturnPet(creatureName)
		summonedCreature:SetAttribute("OwnedBy", player.UserId)
		summonedCreature.Parent = workspace:WaitForChild("Pets")
		player:SetAttribute("Mana", mana - cost)
	else
		summonedCreature = creature:Clone()
		summonedCreature.Name = utilMod.uniqueName(creatureName)
		summonedCreature:SetAttribute("OwnedBy", player.UserId)
		summonedCreature.Parent = workspace:WaitForChild("Pets")
		player:SetAttribute("Mana", mana - cost)
	end

	local creatureHRP = summonedCreature:FindFirstChild("HumanoidRootPart")
	if creatureHRP then
		creatureHRP.CFrame = CFrame.new(mobPos, mobPos + lookAt)
		return summonedCreature
	else
		warn("Summoned creature has no HumanoidRootPart:", creatureName)
	end
end

--==============================================================================
-- Main spell dispatcher – handles all spell types
--==============================================================================
function combatMod.ApplySpell(player: Player, spellname: string)
	local info = statsMod.SpellInfo[spellname]
	if not info then
		warn("Spell not found:", spellname)
		return
	end

	local cost = info.manaCost * statsMod.MaxSpellCost
	local mana = player:GetAttribute("Mana") or 0
	if mana < cost then
		warn("Not enough mana")
		return
	end

	if info.spellType == "damage" then
		local target = utilMod.GetClosestPlayer(player)
			or utilMod.GetClosestModelSkipOwnPets(player, "Pets")
			or utilMod.GetClosestModelSkipOwnPets(player, "Ferals")

		local dis = utilMod.GetDistance(player.Character, target)
		if target and dis and dis < info.range then
			local damage = combatMod.SpellAttackResult(player, target, spellname)
			combatMod.ExecuteSpellDamageToBody(player.UserId, target, damage)
			player:SetAttribute("Mana", mana - cost)
		end
	elseif info.spellType == "areaDamage" then
		local affected = 0
		local playersInRange = utilMod.GetEnemyPlayersWithinRange(player, info.range)
		local modelsInRange = utilMod.GetEnemyModelsWithinRange(player, info.range)

		for _, plr in playersInRange do
			if affected < info.numberTargets then
				local dmg = combatMod.SpellAttackResult(player, plr, spellname)
				combatMod.ExecuteSpellDamageToBody(player.UserId, plr.Character, dmg)
				affected += 1
			end
		end
		for _, mob in modelsInRange do
			if affected < info.numberTargets then
				local dmg = combatMod.SpellAttackResult(player, mob, spellname)
				combatMod.ExecuteSpellDamageToBody(player.UserId, mob, dmg)
				affected += 1
			end
		end

		if affected > 0 then
			player:SetAttribute("Mana", mana - cost)
		end
	elseif info.spellType == "buff" or info.spellType == "debuff" or info.spellType == "heal" then
		local applied = false
		if info.spellType == "heal" or info.spellType == "buff" then
			applied = buffMod.BuffDebuffHeal(player, player, spellname) or applied
			for _, pet in utilMod.MyPets(player) do
				applied = buffMod.BuffDebuffHeal(player, pet, spellname) or applied
			end
		end

		if info.spellType == "debuff" then
			for _, plr in utilMod.GetEnemyPlayersWithinRange(player, info.range) do
				applied = buffMod.BuffDebuffHeal(player, plr, spellname) or applied
			end
			for _, mob in utilMod.GetEnemyModelsWithinRange(player, info.range) do
				applied = buffMod.BuffDebuffHeal(player, mob, spellname) or applied
			end
		end
		if applied then
			buffMod.SelectTargetsForAggro(player, info)
			player:SetAttribute("Mana", mana - cost)
		end
	elseif info.spellType == "utility" then
		local applied = false
		if spellname == "ReclaimPet" then
			local pets = utilMod.MyPets(player)
			if pets then
				applied = buffMod.ReclaimPet(player, spellname, pets)
			end
		elseif spellname == "ConvertSpout" then
			applied = buffMod.ConvertSpout(player)
		end

		if applied then
			buffMod.SelectTargetsForAggro(player, info)
			player:SetAttribute("Mana", mana - cost)
		end
	end
end

--==============================================================================
-- Returns the player-specific creature prefix based on their Magic attribute
--==============================================================================
function combatMod.GetPlayerType(player: Player?): string?
	if not player then
		return nil
	end
	local magictype = player:GetAttribute("Magic") :: string?
	if not magictype then
		return nil
	end

	if magictype == "Artificer" then
		return "PlayerArtificer"
	elseif magictype == "Primordial" then
		return "PlayerPrimordial"
	elseif magictype == "Nature" then
		return "PlayerNature"
	end
	return nil
end

--==============================================================================
-- Applies melee damage from an NPC/pet to any valid target
--==============================================================================
function combatMod.ApplyMeleeDamage(attackerModel: Model, targetModel: Model): boolean
	if not attackerModel or not targetModel then
		return false
	end

	local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
	if not targetHum then
		return false
	end

	local attackerOwnerId = attackerModel:GetAttribute("OwnedBy")
	if attackerOwnerId and typeof(attackerOwnerId) == "number" then
		local ownerPlayer = Players:GetPlayerByUserId(attackerOwnerId)
		if ownerPlayer and ownerPlayer.Character == targetModel then
			return false
		end

		local targetOwnerId = targetModel:GetAttribute("OwnedBy")
		if targetOwnerId and targetOwnerId == attackerOwnerId then
			return false
		end
	end

	local damage = combatMod.MeleeAttackResult(attackerModel, targetModel)
	if not damage or damage <= 0 then
		utilMod.ApplyThreat(attackerModel, targetModel, 25)
		return false
	else
		utilMod.ApplyThreat(attackerModel, targetModel, combatMod.CalculateAggro(damage))
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

	targetHum.Health = math.max(targetHum.Health - damage, 1)
	print(targetModel.Name .. " has " .. targetHum.Health .. " health remaining.")
	return true
end

--==============================================================================
-- Simple aggro calculation based on damage taken
--==============================================================================
function combatMod.CalculateAggro(damageTaken: number): number
	return damageTaken * 1.5 + 30
end

export type CombatMod = {
	LeveltoManaCost: (creatureInstance: Instance) -> number,
	SpellAttackResult: (attacker: Instance, defender: Instance, spellName: string) -> number,
	AcceptableDistanceToOpponent: (model: Model, enemy: Model) -> boolean,
	GetStatsSafelyForPlrorNpc: (npc: Instance) -> table?,
	MeleeAttackResult: (attacker: Instance, defender: Instance) -> number,
	ShallowTableCopy: (name: any) -> table?,
	customTrim: (input: string?) -> string,
	ApplyStaffDamage: (hitPart: BasePart, ownerPlayer: Player, staffType: string) -> boolean,
	ExecuteSpellDamageToBody: (playerId: number, target: Model, damage: number?) -> boolean,
	ApplyAbility: (player: Player, creatureName: string, recyleMod: any) -> (),
	ApplySpell: (player: Player, spellname: string) -> (),
	GetPlayerType: (player: Player?) -> string?,
	ApplyMeleeDamage: (attackerModel: Model, targetModel: Model) -> boolean,
	CalculateAggro: (damageTaken: number) -> number,
}

return combatMod :: CombatMod
