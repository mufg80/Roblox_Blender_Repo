--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local actionsMod = require(script.Parent.actionsMod)
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local buffMod = require(game.ReplicatedStorage.Shared.buffMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local effectMod = require(ReplicatedStorage.Shared.effectMod)

export type FallAnimArgs = {	
    model: Model,
    animTracks: actionsMod.AnimTrackDict,
    dervanimTracks: actionsMod.AnimTrackDict?,
    deathPlayedRef: { value: boolean }  -- mutable reference to avoid re-triggering
}

export type CombatMod = {
	SpellAttackResult: (attackerCreature: Model, defenderCreature: Model, spellName: string) -> number,
	AcceptableDistanceToOpponent: (model: Model, enemy: Model) -> boolean,
	MeleeAttackResult: (attacker: Instance, defender: Instance) -> number,
	ShallowTableCopy: (name: any) -> {},
	ApplyStaffDamage: (hitPart: BasePart, ownerPlayer: Player, staffType: string) -> boolean,
	ExecuteSpellDamageToBody: (source: Model, target: Model, damage: number?) -> boolean,
	ApplyAbility:(player: Player, creatureName: string, recyleMod: any, spawnpoint: Vector3)-> Model?,
	ApplySpell: (player: Player, spellname: string) -> (),
	ApplyMeleeDamage: (attackerModel: Model, targetModel: Model) -> boolean,
	CalculateAggro: (damageTaken: number) -> number,
	ApplyPriestSpell: (model: Model, target: Model, spellname: string, combatTargetModel: Model?) ->(),
	AdjustSpeedOfHumanoid: (player:Player, casttime:number)-> (),
	FallAnimation:(args: FallAnimArgs ) -> (),
}


local combatMod = {} :: CombatMod



local random = Random.new(time())

function combatMod.SpellAttackResult(attackerCreature: Model, defenderCreature: Model, spellName: string): number
    -- Resolve attacker stats (supports both character model and player folder)
    local attackerStats = utilMod.GetStatsFromFolder(attackerCreature)
    if not attackerStats or next(attackerStats) == nil then
        local plr = Players:GetPlayerFromCharacter(attackerCreature)
        if plr then
            attackerStats = utilMod.GetStatsFromFolder(plr)
        end
    end

    -- Resolve defender stats (same fallback logic)
    local defenderStats = utilMod.GetStatsFromFolder(defenderCreature)
    if not defenderStats or next(defenderStats) == nil then
        local plr = Players:GetPlayerFromCharacter(defenderCreature)
        if plr then
            defenderStats = utilMod.GetStatsFromFolder(plr)
        end
    end

    -- Unified spell lookup (SpellInfo OR StaffStats)
    local spell: statsMod.AttackSpell? = statsMod.GetAttackSpell(spellName)

    if not attackerStats or not defenderStats or not spell then
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
    local levelPenalty = math.clamp(levelDiff + 0.15, 0.0, 0.30)
    local finalMissChance = math.clamp(spell.missChance + levelPenalty, 0.10, 0.65)

    if random:NextNumber() < finalMissChance then
        return 0 -- Miss / fully resisted
    end

    -- Base damage before reductions
    local base = spell.effectMultiplier * statsMod.MaxSpellDamage

    -- Resistance reduction (random between half and full defense)
    local reduction = random:NextNumber(relevantDefense / 2, relevantDefense)
    local afterResist = base * (1 - reduction)

    -- Level difference bonus/penalty
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
	if not hrp or not enemyhrp or not hrp:IsA("BasePart") or not enemyhrp:IsA("BasePart") then
		return false
	end

	local distance = utilMod.GetDistance(hrp.Position, enemyhrp.Position)
	if not distance or not enemyTable.distanceForAttacker then
		warn("should not reach me")
		return false
	end
	return distance <= enemyTable.distanceForAttacker
end

--==============================================================================
-- Calculates melee damage with miss chance, defense, armour, variance, etc.
-- Returns final integer damage (0 = miss)
--==============================================================================
function combatMod.MeleeAttackResult(attacker: Instance, defender: Instance): number
	local attackerstats = utilMod.GetStatsFromFolder(attacker)
	local defenderstats = utilMod.GetStatsFromFolder(defender)

	if not attackerstats or not defenderstats or not attackerstats.defense or not defenderstats.defense then
		warn("Should not reach me.")
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
function combatMod.ShallowTableCopy(name: any): {}
	local trimmed = utilMod.customTrim(tostring(name))
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
-- Applies staff spell damage (called from tool hit detection)
--==============================================================================
function combatMod.ApplyStaffDamage(hitPart: BasePart, ownerPlayer: Player, staffType: string): boolean
	local hitCharacter = hitPart:FindFirstAncestorWhichIsA("Model")
	if not hitCharacter or not hitCharacter:FindFirstChild("Humanoid") then
		return false
	end
	if not ownerPlayer or not ownerPlayer.Character or not staffType then
		warn("Should not reach me.")
		return false
	end

	-- Prevent self-damage and damage to owned entities
	if ownerPlayer.Character == hitCharacter then
		return false
	end
	if utilMod.IsAlly(ownerPlayer.Character, hitCharacter) then
		return false
	end

	local damage = combatMod.SpellAttackResult(ownerPlayer.Character, hitCharacter, staffType)

	if not damage or damage <= 0 then
		-- Still generate threat on miss/block
		utilMod.ApplyThreat(ownerPlayer.Character, hitCharacter, 25)
		return false
	else
		utilMod.ApplyThreat(ownerPlayer.Character, hitCharacter, combatMod.CalculateAggro(damage))
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
-- Generic damage application used by spells/abilities (works for Players AND Pets)
--==============================================================================
function combatMod.ExecuteSpellDamageToBody(source: Model, target: Model, damage: number?): boolean
	if not source or not target or not damage then
		warn("Should not reach me.")
	end

	if not source:IsA("Model") or not target:IsA("Model") then
		warn("Should not reach me.")
	end

	if utilMod.IsAlly(source, target) then
		return false
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Apply threat (even if damage is 0 or nil, for "poke" threat)
	local threatAmount = if not damage or damage <= 0 then 25 else combatMod.CalculateAggro(damage)

	utilMod.ApplyThreat(source, target, threatAmount)

	-- Only apply actual damage if damage > 0
	if damage and damage > 0 then
		-- Tag the humanoid so damager gets credit (for quests, etc.)
		local creator = Instance.new("ObjectValue")
		creator.Name = "creator"
		creator.Value = source
		creator.Parent = humanoid

		task.delay(0.5, function()
			if creator and creator.Parent then
				creator:Destroy()
			end
		end)

		print("DamageDonebySpell: " .. damage .. " (from " .. source.Name)
		humanoid.Health = math.max(humanoid.Health - damage, 1)
	end

	return true
end

function combatMod.AdjustSpeedOfHumanoid(player:Player, casttime:number):()
	if not player or not casttime or casttime < .1 then return end
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum and hum:IsA("Humanoid") then
			hum.WalkSpeed = 4
			task.spawn(function()
				task.wait(casttime)
				hum.WalkSpeed = 16
			end)
		end
	end
end

--==============================================================================
-- Summons or recycles a creature/pet for a player
--==============================================================================
function combatMod.ApplyAbility(player: Player, creatureName: string, recyleMod: any, spawnpoint: Vector3): Model?
	if not player or not creatureName or not recyleMod or not spawnpoint or not player:IsA("Player") then
		warn("should not reach me")
		return
	end
	local cost = utilMod.LeveltoManaCost(creatureName)
	local mana = utilMod.GetAttribute(player, "Mana") or 0
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
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	local height = statsMod.creatureStats[creatureName].height

	local groundY = utilMod.DistancetoGround(spawnpoint) or 0
	local mobPos = Vector3.new(spawnpoint.X, groundY + height + 1, spawnpoint.Z)
	local lookAt = (mobPos - hrp.Position) * 2

	local summonedCreature: Model

	if recyleMod.CheckIfExistsPet(creatureName) then
		summonedCreature = recyleMod.ReturnPet(creatureName)
		utilMod.SetAttribute(summonedCreature, "OwnedBy", player.UserId)
		summonedCreature.Parent = workspace:WaitForChild("Pets")
		utilMod.SetAttribute(player, "Mana", mana - cost)
	else
		summonedCreature = creature:Clone()
		utilMod.InitNPC(summonedCreature)
		summonedCreature.Name = utilMod.uniqueName(creatureName)
		utilMod.SetAttribute(summonedCreature, "OwnedBy", player.UserId)
		summonedCreature.Parent = workspace:WaitForChild("Pets")
		utilMod.SetAttribute(player, "Mana", mana - cost)
	end
	if utilMod.customTrim(summonedCreature.Name) ~= utilMod.customTrim("WindSpirit") and utilMod.customTrim(summonedCreature.Name) ~= utilMod.customTrim("GiantAmoeba")  then
		for _, part in pairs(summonedCreature:GetDescendants()) do
			if part:IsA("MeshPart") then
				part.Transparency = 1
			end
		end
		local isFinished = false
		RunService.Heartbeat:Connect(function(delta)
			if isFinished then
				for _, part in pairs(summonedCreature:GetDescendants()) do
					if part:IsA("MeshPart") then
						part.Transparency = 0
					end
				end
				return
			end
			if summonedCreature.Parent == nil then
				return
			end
			task.wait(1)
			for _, part in pairs(summonedCreature:GetDescendants()) do
				if part:IsA("MeshPart") then
					if part.Transparency > 0 then
						part.Transparency = math.clamp(part.Transparency - delta, 0, 1)
					else
						isFinished = true
					end
				end
			end
		end)
	end

	local creatureHRP = summonedCreature:FindFirstChild("HumanoidRootPart")
	if creatureHRP and creatureHRP:IsA("BasePart") then
		creatureHRP.CFrame = CFrame.new(mobPos, mobPos + lookAt)
		return summonedCreature
	else
		warn("Summoned creature has no HumanoidRootPart:", creatureName)
		return nil
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
	local mana = utilMod.GetAttribute(player, "Mana") or 0
	if mana < cost then
		warn("Not enough mana")
		return
	end
	if not player or not player.Character then
		warn("Should not reach me.")
		return
	end

	if info.spellType == "damage" then
		local target = utilMod.GetClosestPlayerSkipAlly(player.Character)
			or utilMod.GetClosestModelSkipAllyPets(player.Character, "Pets")
			or utilMod.GetClosestModelSkipAllyPets(player.Character, "Ferals")
		local dis = math.huge
		if target and target:IsA("Model") then
			local hrp = target:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart")then
				dis = utilMod.GetDistance(player.Character, hrp.Position) or math.huge
			end
			
		end
		
		if target and dis and dis < info.range then
			local isPlayer = false
			if target:IsA("Player") then
				target = target.Character
				isPlayer = true
			end
			local damage = combatMod.SpellAttackResult(player.Character, target, spellname)
			task.delay(0.5, function()
				combatMod.ExecuteSpellDamageToBody(player.Character, target, damage)
			end)
			utilMod.SetAttribute(player, "Mana", mana - cost)
			local targhrp = target:FindFirstChild("HumanoidRootPart")
			if targhrp and targhrp:IsA("BasePart") then
				effectMod.DirectDamageEffect(targhrp, spellname)
			end
			
			if not isPlayer then
				buffMod.ApplyBillboardBuffLabel(info.spellType, spellname, statsMod.BuffInfo[spellname].seconds, target)
			end
		end
	elseif info.spellType == "areaDamage" then
		local affected = 0
		local playersInRange = utilMod.GetEnemyPlayersWithinRange(player.Character, info.range)
		local modelsInRange = utilMod.GetEnemyModelsWithinRange(player.Character, info.range)

		for _, plr in playersInRange do
			if affected < info.numberTargets then
				local dmg = combatMod.SpellAttackResult(player.Character, plr, spellname)

				task.delay(0.5, function()
					combatMod.ExecuteSpellDamageToBody(player.Character, plr, dmg)
				end)
				affected += 1
			end
		end
		for _, mob in modelsInRange do
			if affected < info.numberTargets then
				local dmg = combatMod.SpellAttackResult(player.Character, mob, spellname)

				task.delay(0.5, function()
					combatMod.ExecuteSpellDamageToBody(player.Character, mob, dmg)
				end)
				buffMod.ApplyBillboardBuffLabel(info.spellType, spellname, statsMod.BuffInfo[spellname].seconds, mob)
				affected += 1
			end
		end

		if affected > 0 then
			utilMod.SetAttribute(player, "Mana", mana - cost)
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				effectMod.AOEDamageEffect(hrp, spellname)
			end
		end
	elseif info.spellType == "buff" or info.spellType == "debuff" or info.spellType == "heal" then
		local applied = false
		if info.spellType == "heal" or info.spellType == "buff" then
			local charcontainer = {}
			applied = buffMod.BuffDebuffHeal(player.Character, player.Character, spellname) or applied
			if applied then
				table.insert(charcontainer, player.Character)
			end
			if player.Character then
				for _, pet in utilMod.MyPets(player.Character) do
					applied = buffMod.BuffDebuffHeal(player.Character, pet, spellname) or applied
					if applied then
						table.insert(charcontainer, pet)
						buffMod.ApplyBillboardBuffLabel(
							info.spellType,
							spellname,
							statsMod.BuffInfo[spellname].seconds,
							pet
						)
					end
				end
				if applied then
					effectMod.BuffEffects(charcontainer, spellname)
				end
			end
		end

		if info.spellType == "debuff" then
			local charcontainer = {}

			for _, plr in utilMod.GetEnemyPlayersWithinRange(player.Character, info.range) do
				applied = buffMod.BuffDebuffHeal(player.Character, plr, spellname) or applied
				if applied then
					table.insert(charcontainer, plr)
				end
			end
			for _, mob in utilMod.GetEnemyModelsWithinRange(player.Character, info.range) do
				applied = buffMod.BuffDebuffHeal(player.Character, mob, spellname) or applied
				if applied then
					table.insert(charcontainer, mob)
					buffMod.ApplyBillboardBuffLabel(
						info.spellType,
						spellname,
						statsMod.BuffInfo[spellname].seconds,
						mob
					)
				end
			end
			if applied then
				effectMod.DeBuffEffects(charcontainer, spellname)
			end
		end
		if applied then
			buffMod.SelectTargetsForAggro(player.Character, info)
			utilMod.SetAttribute(player, "Mana", mana - cost)
		end
	elseif info.spellType == "utility" then
		local applied = false
		if info.spellline == "ReclaimPet" then
			if player.Character then
				local pets = utilMod.MyPets(player.Character)
				if pets then
					applied = buffMod.ReclaimPet(player.Character, spellname, pets)
				end
			end
		elseif info.spellline == "ConvertSpout" then
			applied = buffMod.ConvertSpout(player.Character, spellname)
		elseif info.spellline == "TheftOfSoul" then
			applied = buffMod.TheftSoul(player.Character, spellname)
		end

		if applied then
			buffMod.SelectTargetsForAggro(player.Character, info)
			mana = utilMod.GetAttribute(player, "Mana")
			utilMod.SetAttribute(player, "Mana", mana - cost)
		end
	end
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

	local attackerOwnerId = utilMod.GetAttribute(attackerModel, "OwnedBy")
	if attackerOwnerId and typeof(attackerOwnerId) == "number" then
		local ownerPlayer = Players:GetPlayerByUserId(attackerOwnerId)
		if ownerPlayer and ownerPlayer.Character == targetModel then
			return false
		end

		local targetOwnerId = utilMod.GetAttribute(targetModel, "OwnedBy")
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
	--print(targetModel.Name .. " has " .. targetHum.Health .. " health remaining.")
	return true
end

--==============================================================================
-- Simple aggro calculation based on damage taken
--==============================================================================
function combatMod.CalculateAggro(damageTaken: number): number
	return damageTaken * 1.5 + 30
end

function combatMod.ApplyPriestSpell(model: Model, target: Model, spellname: string, combatTargetModel: Model?):()
	local ownedby = utilMod.GetAttribute(model, "OwnedBy")
	local plrOwner = ownedby and game.Players:GetPlayerByUserId(ownedby)
	if not plrOwner or not plrOwner.Character then
		return
	end

	local info = statsMod.SpellInfo[spellname]
	if not info then
		warn("Spell not found:", spellname)
		return
	end

	local cost = info.manaCost * statsMod.MaxSpellCost
	local mana = utilMod.GetAttribute(model, "Mana") or 0
	if mana < cost then
		warn("Not enough mana")
		return
	end

	if info.spellType == "damage" then
		if not combatTargetModel then
			return
		end

		local modhrp = model:FindFirstChild("HumanoidRootPart")
		local targhrp = target:FindFirstChild("HumanoidRootPart")
		local dis:number? = nil
		if modhrp and targhrp and modhrp:IsA("BasePart") and targhrp:IsA("BasePart") then
			dis = utilMod.GetDistance(modhrp.Position, targhrp.Position)
		end

		if combatTargetModel and dis and dis < info.range then
			local isPlayer = false
			if combatTargetModel:IsA("Player") then
				target = combatTargetModel.Character
				isPlayer = true
			end
			local damage = combatMod.SpellAttackResult(model, combatTargetModel, spellname)
			task.delay(0.5, function()
				combatMod.ExecuteSpellDamageToBody(model, combatTargetModel, damage)
			end)
			utilMod.SetAttribute(model, "Mana", mana - cost)

			if targhrp and targhrp:IsA("BasePart") then
				effectMod.DirectDamageEffect(targhrp, spellname)
			end
			
			if not isPlayer then
				buffMod.ApplyBillboardBuffLabel(info.spellType, spellname, statsMod.BuffInfo[spellname].seconds, combatTargetModel)
			end
		end
	elseif info.spellType == "areaDamage" then
		warn("Should not reach me.")
	elseif info.spellType == "buff" or info.spellType == "debuff" or info.spellType == "heal" then
		local applied = false
		if info.spellType == "heal" or info.spellType == "buff" then
			local charcontainer = {}
			applied = buffMod.BuffDebuffHeal(model, plrOwner.Character, spellname)
			if applied then
				table.insert(charcontainer, plrOwner.Character)
			end
			for _, pet in utilMod.MyPets(plrOwner.Character) do
				applied = buffMod.BuffDebuffHeal(model, pet, spellname)
				if applied then
					table.insert(charcontainer, pet)
				end
			end
			if applied then
				effectMod.BuffEffects(charcontainer, spellname)
			end
		end

		if info.spellType == "debuff" then
			warn("Should not reach me.")
		end
		if applied then
			buffMod.SelectTargetsForAggro(model, info)
			mana = utilMod.GetAttribute(model, "Mana")
			utilMod.SetAttribute(model, "Mana", mana - cost)
			local repevent = ReplicatedStorage.Events.PetManaEvent
			if repevent then
				repevent:FireClient(
					plrOwner,
					model.Name,
					utilMod.GetAttribute(model, "Mana"),
					utilMod.GetAttribute(model, "MaxMana")
				)
			end
		end
	elseif info.spellType == "utility" then
		warn("Should not reach me.")
	end
end

function combatMod.FallAnimation(args: FallAnimArgs): ()
	if not args.animTracks or not args.animTracks.death then return end

    if args.deathPlayedRef.value or args.animTracks.death.IsPlaying then
        return
    end


    -- ────────────────────────────────────────────────────────────────
    --  Dervish-specific death handling (only if dervanimTracks exists)
    -- ────────────────────────────────────────────────────────────────
    if args.dervanimTracks and args.dervanimTracks.death then
        local deathDerv = args.dervanimTracks.death

        -- Stop dervish idle animations
        for _, idleTrack in args.dervanimTracks.idle do
            if idleTrack and idleTrack.IsPlaying then
                idleTrack:Stop(0.1)
            end
        end

        -- Play dervish death
        deathDerv:Play(0.3, 1, args.dervanimTracks.deathSpeed or 1)

        deathDerv.Stopped:Connect(function()
            -- Replay once to ensure full playback
            deathDerv:Play(0.3, 1, args.dervanimTracks.deathSpeed or 1)
            
            local length = deathDerv.Length - 0.1
            deathDerv:AdjustSpeed(0)
            deathDerv.TimePosition = length
            
            -- Hide dervish model (assuming dervishmodel is stored somewhere)
            -- If you don't have a global dervishmodel, pass it as a parameter or find it
            local dervishModel = args.model:FindFirstChild("DervishPart") -- ← adjust name
            if dervishModel then
                dervishModel.Parent = nil
            end
        end)
    end

    -- ────────────────────────────────────────────────────────────────
    --  Common: stop all main animations
    -- ────────────────────────────────────────────────────────────────
    for _, idleAnim in args.animTracks.idle do
        if idleAnim and idleAnim.IsPlaying then
            idleAnim:Stop(0.1)
        end
    end

    for _, attackAnim in args.animTracks.attacks do
        if attackAnim and attackAnim.IsPlaying then
            attackAnim:Stop(0.1)
        end
    end

    if args.animTracks.move and args.animTracks.move.IsPlaying then
        args.animTracks.move:Stop(0.1)
    end

    -- ────────────────────────────────────────────────────────────────
    --  Play main death animation & freeze near end
    -- ────────────────────────────────────────────────────────────────
    local deathAnim = args.animTracks.death
    deathAnim:Play(0.3, 1, args.animTracks.deathSpeed or 1)

    deathAnim.Stopped:Connect(function()
        -- Replay to reach full length
        deathAnim:Play(0.3, 1, args.animTracks.deathSpeed or 1)
        
        local freezePoint = deathAnim.Length - 0.2
        deathAnim:AdjustSpeed(0)
        deathAnim.TimePosition = freezePoint
        
        -- Wait a bit then recycle
        task.wait(2)
        utilMod.SetAttribute(args.model, "RecycleMe", true)
    end)
end




return combatMod
