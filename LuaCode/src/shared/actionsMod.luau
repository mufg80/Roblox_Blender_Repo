--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local petControlMod = require(script.Parent.petControlMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

export type AnimTrackDict = {
	idle: { AnimationTrack? },
	delayConnection: RBXScriptConnection?,
	idleConnection: thread?,
	move: AnimationTrack?,
	blink: AnimationTrack?,
	death: AnimationTrack?,
	attacks: { AnimationTrack? },
	cast: AnimationTrack?,
	favoredAttack: number,
	moveSpeed: number?,
	idleSpeed: number?,
	deathSpeed: number?,
	castSpeed: number?,
	attackSpeeds: { number? },
}

export type MutablePetSync = {
	lastAttackTime: { value: number },

	homewardBound: boolean,

	lithDefendRandomLoc: { value: Vector3? },

	lithTakeRandomLoc: { value: Vector3? },
}

export type ActionContext = {
	-- Core character/model references
	model: Model,
	hrp: BasePart, -- HumanoidRootPart

	-- Animation & combat related
	animTracks: AnimTrackDict, -- or whatever your actual key type is (string? number?)
	combatTargetModel: Model?,

	-- Movement & direction
	movingDirection: string,

	-- Ownership & timing
	ownerInstance: Instance?, -- e.g. Player, Model, etc.
	lastAttackTime: { value: number }, -- common wrapper pattern
	ATTACK_COOLDOWN: number,

	-- Spawning / positioning
	spawnPosition: Vector3?,

	-- Randomness (very common in Roblox combat/AI)
	random: Random,

	-- Pet / Lith-related flags & positions (assuming boolean or similar)
	petAttack: boolean?,
	petTakeLith: boolean?,
	petDefendLith: boolean?,

	lithTakePosition: Vector3?,
	lithDefendPosition: Vector3?,

	-- Mutable / shared state references (very typical pattern)
	lithTakeRandomLoc: Vector3?,
	lithDefendRandomLoc: Vector3?,
	homewardBound: boolean?,

	-- Module references (dependency injection style)
	pathMod: any, -- ideally: typeof(require(pathModule))
	combatMod: any,
	utilMod: any,

	-- The pet instance itself
	pet: petControlMod.PetControlAPI,
}

export type ActionMod = {
	PerformActions: (context: ActionContext) -> MutablePetSync,
}

local actionsMod = {}

local priestkey = {
	["MudPriest"] = { Heal = "PrimordialPriestHeal", Nuke = "PrimordialPriestNuke", Buff = "PrimordialPriestBuff" },
	["UnkemptDruid"] = { Heal = "NaturePriestHeal", Nuke = "NaturePriestNuke", Buff = "NaturePriestBuff" },
	["StonePriest"] = { Heal = "ArtificerPriestHeal", Nuke = "ArtificerPriestNuke", Buff = "ArtificerPriestBuff" },
}

local healerCache: { [string]: boolean } = {}
local healerType: string? = nil
local healerHealed: { [string]: number } = {}
local healerNuked: { [string]: number } = {}
local healerBuffed: { [string]: number } = {}

-- Unified function to cast any Priest spell (Heal, Buff, Nuke, etc.)
local function CastPriestSpell(
	animTracks: AnimTrackDict,
	model: Model,
	combatMod: any, -- your combat module
	spellname: string, -- "PriestHeal", "PriestBuff", "PriestNuke", etc.
	combatTargetModel: Model? -- Optional: only used if spell needs a direct target
)
	if not animTracks or not model or not combatMod or not spellname then
		warn("Should not reach me.")
		return
	end

	-- Play the cast animation
	local trackToPlay: AnimationTrack? = animTracks.cast
	if not trackToPlay then
		warn("Should not reach me.")
		return
	end
	trackToPlay:Play(0.3, 1, animTracks.castSpeed or 1)

	--print("Cast " .. spellname .. " - Pet")

	-- Delay the actual spell application (simulates cast time / impact)
	task.delay(0.5, function()
		local userId = utilMod.GetAttribute(model, "OwnedBy")
		if userId then
			local plr = game.Players:GetPlayerByUserId(userId)
			if plr and plr.Character then
				-- Apply the spell (your existing logic handles targeting/healing/damage/buffs)
				combatMod.ApplyPriestSpell(model, plr.Character, spellname, combatTargetModel)
			end
		end
	end)
end

local function DecideToBuff(model: Model, mana: number, maxmana: number, inCombat:boolean): boolean
	if not model or not mana or not maxmana or maxmana == 0 or not healerType then
		warn("Should not reach me.")
		return false
	end
	local buffSpell = statsMod.SpellInfo[healerType .. "PriestBuff"]
	local manaCost = buffSpell.manaCost * statsMod.MaxSpellCost
	local castTime = buffSpell.castTime
	local durationTime = statsMod.BuffInfo[healerType .. "PriestBuff"].seconds
	local extraDuration = inCombat and 1 or 10

	-- Condition 1: Mana below 60% of maxmana
	if mana < maxmana * 0.3 then
		return false
	end

	-- Ensure enough mana to cast
	if mana < manaCost then
		return false
	end

	-- Condition 2: Check if buff is on cooldown
	local modelName = model.Name
	local lastBuffTime = healerBuffed[modelName] or 0
	local cooldownEnd = lastBuffTime + castTime + durationTime + extraDuration


	if time() < cooldownEnd then
		return false
	end

	if inCombat then
		if mana < maxmana * 0.5 then
			return false
		end
	end

	-- All conditions met: Buff will be cast, store the current time
	healerBuffed[modelName] = time()
	return true
end

-- In the module that owns the priest AI / decision loop
local NearbyPartyCache = {}          -- [healerModelName] = {lastUpdateTime, members = {Model,...}}
local CACHE_UPDATE_INTERVAL = 1      -- seconds

local function GetNearbyPartyMembers(healerModel: Model, range:number): {Model}
    if not healerModel then return {} end
    
    local name = healerModel.Name
    local cacheEntry = NearbyPartyCache[name]
    local now = time()
    
    -- Return cached value if still fresh
    if cacheEntry and now - cacheEntry.lastUpdateTime < CACHE_UPDATE_INTERVAL then
        return cacheEntry.members
    end
    
    -- Cache miss or stale → recompute
    local fullParty = utilMod.GetPartyMembers(healerModel)
    if not fullParty or not fullParty.pets then
        NearbyPartyCache[name] = {lastUpdateTime = now, members = {}}
        return {}
    end
    
    local hrp = healerModel:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        NearbyPartyCache[name] = {lastUpdateTime = now, members = {}}
        return {}
    end
    
    local healerPos = hrp.Position
    local nearby = {}

    
    -- Player character
    if fullParty.Character then
        local pHrp = fullParty.Character:FindFirstChild("HumanoidRootPart")
        if pHrp and pHrp:IsA("BasePart") and (pHrp.Position - healerPos).Magnitude <= (range + 5) then
            table.insert(nearby, fullParty.Character)
        end
    end
    
    -- Pets
    for _, pet in ipairs(fullParty.pets) do
        if pet then
            local pHrp = pet:FindFirstChild("HumanoidRootPart")
            if pHrp and pHrp:IsA("BasePart") and (pHrp.Position - healerPos).Magnitude <= 50 then
                table.insert(nearby, pet)
            end
        end
    end
    
    NearbyPartyCache[name] = {
        lastUpdateTime = now,
        members = nearby
    }
    
    return nearby
end

local function DecideToHeal(thisModel: Model, mana: number, maxmana: number, inCombat: boolean): boolean
	if not thisModel or not mana or not maxmana or not healerType then
		warn("DecideToHeal: Invalid parameters")
		return false
	end

	if not healerType then return false end
	local healSpell = statsMod.SpellInfo[healerType .. "PriestHeal"]
	-- Get cached nearby party members (updates max once per second)
	local partyTable = GetNearbyPartyMembers(thisModel, healSpell.range)
	if #partyTable == 0 then
		return false
	end

	-- Early mana check
	
	local manaCost = healSpell.manaCost * statsMod.MaxSpellCost
	if mana < manaCost then
		return false
	end

	-- Cooldown check
	local modelName = thisModel.Name
	local lastHealTime = healerHealed[modelName] or 0
	local castTime = healSpell.castTime or 0
	local healDuration = statsMod.BuffInfo[healerType .. "PriestHeal"].seconds or 0
	local extraDuration = inCombat and 1 or 5
	local cooldownEnd = lastHealTime + castTime + healDuration + extraDuration

	if time() < cooldownEnd then
		return false
	end

	-- Find lowest health percentage among nearby members
	local lowestPercent = 1
	local anyAlive = false

	for _, member in ipairs(partyTable) do
		local humanoid = member:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			anyAlive = true
			local maxH = humanoid.MaxHealth
			local percent = maxH > 0 and (humanoid.Health / maxH) or 0
			if percent < lowestPercent then
				lowestPercent = percent
			end
		end
	end

	if not anyAlive then
		return false
	end

	-- Critical priority — always heal
	if lowestPercent < 0.2 then
		healerHealed[modelName] = time()
		return true
	end

	-- Out of combat: heal if lowest <80%
	if not inCombat then
		if lowestPercent < 0.8 then
			healerHealed[modelName] = time()
			return true
		end
		return false
	end

	-- In combat: heal if lowest <60%
	if lowestPercent < 0.6 then
		healerHealed[modelName] = time()
		return true
	end

	return false
end

-- Constants (move to a shared Constants module if you have one)
local MIN_NUKE_MANA_RATIO = 0.40   -- Below this mana % → too low to bother nuking
local NUKE_BASE_COOLDOWN = 8       -- seconds added after cast time

-- Decides whether this healer model should cast its nuke spell right now.
-- Returns true if conditions are met (enough mana, off cooldown, etc.)
local function DecideToNuke(thisModel: Model, mana: number, maxmana: number): boolean
	-- Input validation
	if not thisModel or not thisModel:IsA("Model") then
		warn("DecideToNuke → Invalid model")
		return false
	end

	if typeof(mana) ~= "number" or typeof(maxmana) ~= "number" or mana < 0 or maxmana < 0 then
		warn("DecideToNuke → Invalid mana values", mana, maxmana)
		return false
	end

	if typeof(healerType) ~= "string" or healerType == "" then
		warn("DecideToNuke → Missing or invalid healerType (must be non-empty string)")
		return false
	end

	-- Early exit: mana too low to consider nuking
	local manaRatio = if maxmana > 0 then mana / maxmana else 0
	if manaRatio <= MIN_NUKE_MANA_RATIO then
		return false
	end

	-- Get spell data
	local nukeSpellName = healerType .. "PriestNuke"
	local nukeSpell = statsMod.SpellInfo[nukeSpellName]
	if not nukeSpell then
		warn("DecideToNuke → Spell not found:", nukeSpellName)
		return false
	end

	-- Calculate actual mana cost
	local baseCost = nukeSpell.manaCost or 0
	local maxSpellCost = statsMod.MaxSpellCost or 1
	local manaCost = baseCost * maxSpellCost

	if manaCost <= 0 then
		warn("DecideToNuke → Invalid mana cost for", nukeSpellName, "(cost <= 0)")
		return false
	end

	-- Not enough mana to cast
	if mana < manaCost then
		return false
	end

	-- Cooldown check
	local castTime = nukeSpell.castTime or 5
	local cooldownDuration = castTime + NUKE_BASE_COOLDOWN

	-- Use GetFullName() to avoid cooldown sharing between models with same .Name
	local modelKey = thisModel:GetFullName()

	-- healerNuked should be a module-level table: { [string] = number }
	local lastNukeTime = healerNuked[modelKey] or 0

	if time() < lastNukeTime + cooldownDuration then
		return false
	end

	-- All conditions met → allow nuke and record timestamp
	healerNuked[modelKey] = time()
	return true
end

local function StopIdle(animTracks: any)
	if not animTracks then
		warn("Should not reach me.")
		return
	end
	local canceled = false
	-- Handle idleConnection (could be thread or connection)
	if animTracks.idleConnection then
		if typeof(animTracks.idleConnection) == "thread" then
			task.cancel(animTracks.idleConnection)
			canceled = true
		elseif typeof(animTracks.idleConnection) == "RBXScriptConnection" then
			animTracks.idleConnection:Disconnect()
			canceled = true
		end
		animTracks.idleConnection = nil
	end

	-- Handle delayConnection (same safety)
	if animTracks.delayConnection then
		if typeof(animTracks.delayConnection) == "thread" then
			task.cancel(animTracks.delayConnection)
			canceled = true
		elseif typeof(animTracks.delayConnection) == "RBXScriptConnection" then
			animTracks.delayConnection:Disconnect()
			canceled = true
		end
		animTracks.delayConnection = nil
	end
	if canceled then
		--print("long tasks for idle canceled.")
	end

	-- Stop all idle animation tracks
	if #animTracks.idle > 0 then
		for _, track in ipairs(animTracks.idle) do
			if track and track.IsPlaying then
				track:Stop(0.5) -- Optional: smooth fade out
			end
		end
	end
end

-- Simplified: only starts the long idle (or single idle). Transition handled externally.
local function PlayIdles(animTracks: any, model: Model)
	if not animTracks or not model then
		warn("Should not reach me.")
		return
	end
	for _, idle in ipairs(animTracks.idle) do
		if idle and idle.IsPlaying then
			return
		end
	end
	local inCombat = utilMod.GetAttribute(model, "InCombat") or false

	if #animTracks.idle == 1 or inCombat then
		local idleToPlay: AnimationTrack = animTracks.idle[1]
		idleToPlay.Looped = true
		if idleToPlay then
			idleToPlay:Play(0.2, 1, animTracks.idleSpeed or 1)
		end
	elseif #animTracks.idle == 2 then
		-- Check if appriate to play longidle

		local tracktoplay1: AnimationTrack = animTracks.idle[1]
		local tracktoplay2: AnimationTrack = animTracks.idle[2]
		tracktoplay2.Looped = false
		tracktoplay1.Looped = true
		local total = math.random(15, 30)
		tracktoplay1:Play(1, 1, animTracks.idleSpeed or 1)
		animTracks.idleConnection = task.delay(total, function()
			if tracktoplay1 and tracktoplay1.IsPlaying then
				tracktoplay1:Stop(0.2)
				tracktoplay2:Play(0.2, 1, animTracks.idleSpeed or 1)
				animTracks.delayConnection = tracktoplay2.Stopped:Connect(function()
					tracktoplay1:Play(0.2, 1, animTracks.idleSpeed or 1)
				end)
			end
		end)
	end
end

local function StopMove(animTracks: any)
	if not animTracks then
		warn("Should not reach me.")
		return
	end
	if animTracks.move and animTracks.move.IsPlaying then
		local tracktostop: AnimationTrack = animTracks.move
		tracktostop:Stop(1)
	end
end

local function GetRandomAttack(animTracks: any, random: Random): { anim: AnimationTrack, index: number }?
	if not animTracks or not random then
		warn("Should not reach me.")
		return nil
	end
	if #animTracks.attacks == 0 then
		return nil
	end
	local doPrimary = random:NextInteger(1, 3) == 1
	if doPrimary and animTracks.favoredAttack ~= 0 then
		--print("Doing favoredattack")
		local ind = animTracks.favoredAttack or 1
		return { anim = animTracks.attacks[ind] or animTracks.attacks[1], index = ind }
	else
		local ind = random:NextInteger(1, #animTracks.attacks) or 1
		return { anim = animTracks.attacks[ind] or animTracks.attacks[1], index = ind }
	end
end

local function NoAttacksPlaying(animTracks: any): boolean
	for _, anim in ipairs(animTracks.attacks) do
		if anim.IsPlaying then
			return false
		end
	end
	return true
end

local function GetHealerType(name: string): string?
	if not name then
		warn("Should not reach me.")
		return nil
	end
	local trimmed = utilMod.customTrim(name)
	if trimmed == "UnkemptDruid" then
		return "Nature"
	elseif trimmed == "StoneManaPriest" then
		return "Artificer"
	elseif trimmed == "MudPriest" then
		return "Primordial"
	else
		warn("Should not reach me.")
	end
	return nil
end

function actionsMod.PerformActions(context: ActionContext): MutablePetSync
	local result: MutablePetSync = {
		lastAttackTime = { value = 0 },
		homewardBound = false,
		lithDefendRandomLoc = { value = Vector3.new(0, 0, 0) },
		lithTakeRandomLoc = { value = Vector3.new(0, 0, 0) },
	}

	if not context then
		warn("Should not reach me.")
		return result
	end
	local model = context.model
	local hrp = context.hrp
	local animTracks = context.animTracks
	local combatTargetModel = context.combatTargetModel
	local movingDirection = context.movingDirection
	local ownerInstance = context.ownerInstance
	local lastAttackWrapper = context.lastAttackTime -- {value = number}
	local ATTACK_COOLDOWN = context.ATTACK_COOLDOWN
	local spawnPosition = context.spawnPosition
	local random = context.random

	--local petAttack = context.petAttack
	local petTakeLith = context.petTakeLith
	local petDefendLith = context.petDefendLith
	local lithTakePosition = context.lithTakePosition
	local lithDefendPosition = context.lithDefendPosition

	-- Mutable references
	local lithTakeRandomLoc = context.lithTakeRandomLoc
	local lithDefendRandomLoc = context.lithDefendRandomLoc
	local homewardBound = context.homewardBound

	local pathMod = context.pathMod
	local combatMod = context.combatMod
	local utilMod = context.utilMod
	--local pet = context.pet

	if not healerCache[model.Name] then
		healerCache[model.Name] = utilMod.IsMobHealer(model)
		if healerCache[model.Name] then
			healerType = GetHealerType(model.Name)
		end
	end
	----------------------------------------------------------------
	-- Combat Actions
	----------------------------------------------------------------
	if utilMod.GetAttribute(model, "InCombat") and not healerCache[model.Name] then
		StopMove(animTracks)
		PlayIdles(animTracks, model)
		if combatTargetModel then
			if pathMod.IsPathActive(model) then
				if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
					pathMod.ShortCircuitTravel(model)
				end
			end

			if not pathMod.IsPathActive(model) then
				utilMod.SpinToOwner(model, hrp, combatTargetModel, random)
				if time() - lastAttackWrapper.value >= ATTACK_COOLDOWN then
					local track = GetRandomAttack(animTracks, random)

					if not track then
						print("should not reach me.")
					end
					if track and NoAttacksPlaying(animTracks) then
						local speed: number? = animTracks.attackSpeeds[track.index or 1]
						track.anim:Play(0.2, 1, speed or 1)
						lastAttackWrapper.value = time()

						task.delay(0.5, function()
							combatMod.ApplyMeleeDamage(model, combatTargetModel)
						end)
					end
				end
			end
		end
	elseif utilMod.GetAttribute(model, "InCombat") and healerCache[model.Name] then
		StopMove(animTracks)
		PlayIdles(animTracks, model)
		if combatTargetModel then
			if pathMod.IsPathActive(model) then
				if utilMod.GetAcceptableDistanceForCaster(model, combatTargetModel) then
					pathMod.ShortCircuitTravel(model)
				end
			end

			if not pathMod.IsPathActive(model) then
				if time() - lastAttackWrapper.value >= ATTACK_COOLDOWN then
					local mana = utilMod.GetAttribute(model, "Mana") or 0
					local maxMana = utilMod.GetAttribute(model, "MaxMana") or 1

					if DecideToHeal(model, mana, maxMana, true) then
						utilMod.SpinToOwner(model, hrp, ownerInstance, random)
						local sname = priestkey[utilMod.customTrim(model.Name)].Heal
						CastPriestSpell(animTracks, model, combatMod, sname)
						lastAttackWrapper.value = time()
					elseif DecideToBuff(model, mana, maxMana, true) then
						utilMod.SpinToOwner(model, hrp, ownerInstance, random)
						local sname = priestkey[utilMod.customTrim(model.Name)].Buff
						CastPriestSpell(animTracks, model, combatMod, sname)
						lastAttackWrapper.value = time()
					elseif DecideToNuke(model, mana, maxMana) then
						utilMod.SpinToOwner(model, hrp, combatTargetModel, random)
						local sname = priestkey[utilMod.customTrim(model.Name)].Nuke
						CastPriestSpell(animTracks, model, combatMod, sname, combatTargetModel)
						lastAttackWrapper.value = time()
					end
				end
			end
		end
	end

	----------------------------------------------------------------
	-- Moving Actions
	----------------------------------------------------------------
	if utilMod.GetAttribute(model, "IsMoving") then
		if pathMod.IsPathActive(model) then
			StopIdle(animTracks)
			if animTracks.move and not animTracks.move.IsPlaying then
				local tracktoplay: AnimationTrack = animTracks.move
				tracktoplay:Play(0.3, 1, animTracks.moveSpeed or 1)
			end
		else
			PlayIdles(animTracks, model)
		end

		if movingDirection == "MovingToCombatTarget" and not healerCache[model.Name] then
			local target = pathMod.GetTargetPet(model, utilMod.GetAttribute(model, "TargetIDorName"), random)
			if target and not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, target, utilMod.GetAttribute(model, "TargetIDorName"))
			elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, target, utilMod.GetAttribute(model, "TargetIDorName"))
			end
		elseif movingDirection == "MovingToCombatTarget" and healerCache[model.Name] then
			-- move to within 45 studs (logic unchanged)
		elseif movingDirection == "MovingToNearestLith" then
			if petDefendLith then
				if lithDefendPosition then
					if not lithDefendRandomLoc then
						lithDefendRandomLoc = pathMod.GetTargetLith(lithDefendPosition)
					end
					if lithDefendRandomLoc and not pathMod.IsPathActive(model) then
						local pathset = pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
						if not pathset then
							--print("loc no good for defend pos, resetting")
							lithDefendRandomLoc = nil
						end
					elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
						pathMod.ShortCircuitTravel(model)
						local pathset = pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
						if not pathset then
							--print("loc no good for defend pos, resetting")
							lithDefendRandomLoc = nil
						end
					end
				end
			elseif petTakeLith then
				if lithTakePosition then
					if not lithTakeRandomLoc then
						lithTakeRandomLoc = pathMod.GetTargetLith(lithTakePosition)
					end
					if lithTakeRandomLoc and not pathMod.IsPathActive(model) then
						local pathset = pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
						if not pathset then
							--print("loc no good for take pos, resetting")
							lithTakeRandomLoc = nil
						end
					elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
						pathMod.ShortCircuitTravel(model)
						local pathset = pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
						if not pathset then
							--print("loc no good for take pos, resetting")
							lithTakeRandomLoc = nil
						end
					end
				end
			end
		elseif movingDirection == "MovingToOwner" then
			local ownerId = utilMod.GetAttribute(model, "OwnedBy")
			local target = pathMod.GetTargetPet(model, ownerId, random)
			if target and not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, target, ownerId)
			elseif pathMod.GetCurrentTarget(model) ~= utilMod.GetModelByIDorName(ownerId) then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, target, ownerId)
			end
		elseif movingDirection == "MovingToSpawnPosition" then
			if not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
			elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
			end
		elseif movingDirection == "MovingToRandom" then
			local vec =
				Vector3.new(spawnPosition and spawnPosition.X, hrp.Position.Y, spawnPosition and spawnPosition.Z)

			if random:NextInteger(1, 10) < 8 then
				local limit = utilMod.GetAttribute(model, "RangeLimit") or 50
				if limit > 11 then
					limit = limit - 5
				end

				local maxDistance = math.max(1, limit - 1) -- avoid invalid range
				local distance = random:NextInteger(5, maxDistance)

				local directionDeg = random:NextInteger(0, 359) -- 0 to 359 is cleaner than 1-359

				-- Convert degrees to radians for math functions
				local angleRad = math.rad(directionDeg)

				-- Calculate offset using polar → cartesian coordinates
				local offsetX = math.cos(angleRad) * distance
				local offsetZ = math.sin(angleRad) * distance

				-- Apply the offset to the base position
				vec = vec + Vector3.new(offsetX, 0, offsetZ)
			end

			if not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, vec, "SpawnPoint")
			elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, vec, "SpawnPoint")
			end
		elseif movingDirection == "HomewardBound" then
			if not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
			elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
			elseif utilMod.GetDistance(hrp.Position, spawnPosition) < 5 then
				pathMod.ShortCircuitTravel(model)
				homewardBound = false
			end
		end
	end

	----------------------------------------------------------------
	-- Idle Actions
	----------------------------------------------------------------
	if utilMod.GetAttribute(model, "IsIdle") then
		StopMove(animTracks)
		PlayIdles(animTracks, model)

		if pathMod.IsPathActive(model) then
			pathMod.ShortCircuitTravel(model)
			--print("shorting travel10")
		end

		local timeNumber = time() - (utilMod.GetAttribute(model, "IdleStartTime") or 0)
		local cool = time() > (utilMod.GetAttribute(model, "SpinCoolDown") or 0)

		if ownerInstance and cool and timeNumber > random:NextInteger(10, 20) then
			utilMod.SetAttribute(model, "SpinCoolDown", time() + random:NextInteger(10, 25))
			utilMod.SpinToOwner(model, hrp, ownerInstance, random)
		end

		if healerCache[model.Name] then
			local mana = utilMod.GetAttribute(model, "Mana") or 0
			local maxMana = utilMod.GetAttribute(model, "MaxMana") or 1

			local nextCastTime = utilMod.GetAttribute(model, "IdleCastCoolDown") or (time() + 20)
			if
				DecideToHeal(model, mana, maxMana, false)
				and time() > nextCastTime
				and time() - lastAttackWrapper.value >= ATTACK_COOLDOWN
			then
				nextCastTime = time() + random:NextInteger(10, 40)
				utilMod.SetAttribute(model, "IdleCastCoolDown", nextCastTime)
				lastAttackWrapper.value = time()
				local sname = priestkey[utilMod.customTrim(model.Name)].Heal
				CastPriestSpell(animTracks, model, combatMod, sname, nil)
			elseif
				DecideToBuff(model, mana, maxMana, false)
				and time() > nextCastTime
				and time() - lastAttackWrapper.value >= ATTACK_COOLDOWN
			then
				nextCastTime = time() + random:NextInteger(10, 40)
				utilMod.SetAttribute(model, "IdleCastCoolDown", nextCastTime)
				lastAttackWrapper.value = time()
				local sname = priestkey[utilMod.customTrim(model.Name)].Buff
				CastPriestSpell(animTracks, model, combatMod, sname, nil)
			end
		end
	end

	result.lastAttackTime.value = lastAttackWrapper.value
	result.homewardBound = homewardBound ~= false
	result.lithDefendRandomLoc.value = lithDefendRandomLoc
	result.lithTakeRandomLoc.value = lithTakeRandomLoc
	return result
end

return actionsMod
