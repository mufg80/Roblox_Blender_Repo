-- ReplicatedStorage.Shared.actionsMod
--!strict

local actionsMod = {}

local function StopIdle(animTracks: any)
	-- Handle idleConnection (could be thread or connection)
	if animTracks.idleConnection then
		if typeof(animTracks.idleConnection) == "thread" then
			task.cancel(animTracks.idleConnection)
		elseif typeof(animTracks.idleConnection) == "RBXScriptConnection" then
			animTracks.idleConnection:Disconnect()
		end
		animTracks.idleConnection = nil
	end

	-- Handle delayConnection (same safety)
	if animTracks.delayConnection then
		if typeof(animTracks.delayConnection) == "thread" then
			task.cancel(animTracks.delayConnection)
		elseif typeof(animTracks.delayConnection) == "RBXScriptConnection" then
			animTracks.delayConnection:Disconnect()
		end
		animTracks.delayConnection = nil
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
local function PlayIdles(animTracks: any)
	for _, idle in ipairs(animTracks.idle) do
		if idle and idle.IsPlaying then
			return
		end
	end

	if #animTracks.idle == 1 then
		-- Prefer long idle (index 2) if it exists, otherwise use the only one
		local idleToPlay: AnimationTrack = animTracks.idle[1]
		idleToPlay.Looped = true
		if idleToPlay then
			idleToPlay:Play(0.3, 1, animTracks.idleSpeed or 1)
		end
	elseif #animTracks.idle == 2 then
		local tracktoplay1: AnimationTrack = animTracks.idle[1]
		local tracktoplay2: AnimationTrack = animTracks.idle[2]
		tracktoplay2.Looped = true
		tracktoplay1.Looped = false
		local total = math.random(15, 30)
		tracktoplay2:Play(1, 1, animTracks.idleSpeed or 1)
		animTracks.idleConnection = task.delay(total, function()
			if tracktoplay2 and tracktoplay2.IsPlaying then
				tracktoplay2:Stop(0.5)
				tracktoplay1:Play(0.5, 1, animTracks.idleSpeed or 1)
				animTracks.delayConnection = tracktoplay1.Stopped:Connect(function()
					tracktoplay2:Play(0.5, .9, animTracks.idleSpeed or 1)
				end)
			end
		end)
	end
end

local function StopMove(animTracks: any)
	if animTracks.move and animTracks.move.IsPlaying then
		local tracktostop: AnimationTrack = animTracks.move
		tracktostop:Stop(1)
	end
end

local function GetRandomAttack(animTracks: any, random: Random): {anim: AnimationTrack?, index:number?}
	if #animTracks.attacks == 0 then
		return nil
	end
	local doPrimary = random:NextInteger(1, 3) == 1
	if doPrimary then
		local index = animTracks.favoredAttack
		return {animTracks.attacks[index], index}
	else
		local index = random:NextInteger(1, #animTracks.attacks)
		return {animTracks.attacks[index], index}
	end
end

local healerCache: { string: boolean } = {}

function actionsMod.PerformActions(context: table)
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

	local petAttack = context.petAttack
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
	local pet = context.pet

	if not healerCache[model.Name] then
		healerCache[model.Name] = utilMod.IsMobHealer(model)
	end

	----------------------------------------------------------------
	-- Combat Actions
	----------------------------------------------------------------
	if model:GetAttribute("InCombat") and not healerCache[model.Name] then
		StopMove(animTracks)
		PlayIdles(animTracks)
		if combatTargetModel then
			if pathMod.IsPathActive(model) then
				if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
					pathMod.ShortCircuitTravel(model)
				end
			end

			if not pathMod.IsPathActive(model) then
				utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)

				if time() - lastAttackWrapper.value >= ATTACK_COOLDOWN then
					local track = GetRandomAttack(animTracks, random)
					if track.anim and not track.anim.IsPlaying then
						track.anim:Play(0.2, 1, animTracks.attackSpeeds[track.index])
						lastAttackWrapper.value = time()

						task.delay(0.5, function()
							combatMod.ApplyMeleeDamage(model, combatTargetModel)
						end)
					end
				end
			end
		end
	elseif model:GetAttribute("InCombat") and healerCache[model.Name] then
		StopMove(animTracks)
		PlayIdles(animTracks)
		if combatTargetModel then
			if pathMod.IsPathActive(model) then
				if utilMod.GetAcceptableDistanceForCaster(model, combatTargetModel) then
					pathMod.ShortCircuitTravel(model)
				end
			end

			if not pathMod.IsPathActive(model) then
				utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)

				-- Attack or regen mana
			end
		end
	end

	----------------------------------------------------------------
	-- Moving Actions
	----------------------------------------------------------------
	if model:GetAttribute("IsMoving") then
		StopIdle(animTracks)
		if animTracks.move and not animTracks.move.IsPlaying then
			local tracktoplay:AnimationTrack = animTracks.move
			print("moving at "..animTracks.moveSpeed)
			tracktoplay:Play(.3,.9,animTracks.moveSpeed or 1)
		end

		if movingDirection == "MovingToCombatTarget" and not healerCache[model.Name] then
			local target = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"), random)
			if target and not pathMod.IsPathActive(model) then
				pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
			elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
				pathMod.ShortCircuitTravel(model)
				pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
			end
		elseif movingDirection == "MovingToCombatTarget" and healerCache[model.Name] then
			-- move to within 45 studs
		elseif movingDirection == "MovingToNearestLith" then
			if petDefendLith then
				if lithDefendPosition then
					if not lithDefendRandomLoc then
						lithDefendRandomLoc = pathMod.GetTargetLith(lithDefendPosition)
					end
					if lithDefendRandomLoc and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
					elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
					end
				end
			elseif petTakeLith then
				if lithTakePosition then
					if not lithTakeRandomLoc then
						lithTakeRandomLoc = pathMod.GetTargetLith(lithTakePosition)
					end
					if lithTakeRandomLoc and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
					elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
					end
				end
			end
		elseif movingDirection == "MovingToOwner" then
			local ownerId = model:GetAttribute("OwnedBy")
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
			local vec = Vector3.new(spawnPosition.X, hrp.Position.Y, spawnPosition.Z)
			if random:NextInteger(1, 10) < 5 then
				local xpos = random:NextInteger(-10, 10)
				local zpos = random:NextInteger(-10, 10)
				vec = vec + Vector3.new(xpos, 0, zpos)
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
	-- Idle Actions (partial — spin to owner stays here)
	----------------------------------------------------------------
	if model:GetAttribute("IsIdle") then
		StopMove(animTracks)
		PlayIdles(animTracks) -- starts long idle or single idle

		if pathMod.IsPathActive(model) then
			pathMod.ShortCircuitTravel(model)
			print("shorting travel10")
		end
		local timeNumber = time() - (model:GetAttribute("IdleStartTime") or 0)
		local cool = time() > (model:GetAttribute("SpinCoolDown") or 0)

		if ownerInstance and cool and timeNumber > random:NextInteger(10, 20) then
			model:SetAttribute("SpinCoolDown", time() + random:NextInteger(10, 25))
			utilMod.SpinToOwner(model, hrp, ownerInstance, random)
		end
		if healerCache[model.Name] then
			local mana = model:GetAttribute("Mana") or 0
			local maxMana = model:GetAttribute("MaxMana") or 1
			local nextCastTime = model:GetAttribute("IdleCastCoolDown") or 0
			if mana / maxMana > 0.8 and time() > nextCastTime then
				nextCastTime = time() + random:NextInteger(20, 40)
				model:SetAttribute("IdleCastCoolDown", nextCastTime)
				local tracktoplay: AnimationTrack = animTracks.cast
				tracktoplay:Play(0.3, 0.9, animTracks.castSpeed or 1)
				print("CastHeal - Pet")
				task.delay(0.5, function()
					local spellname = nil
					if random:NextInteger(1, 2) == 5 then
						spellname = "PriestBuff"
					else
						spellname = "PriestHeal"
					end
					local userId = model:GetAttribute("OwnedBy")
					if userId and typeof(userId) == "number" then
						local plr = game.Players:GetPlayerByUserId(userId)
						if plr and plr.Character then
							combatMod.ApplyPriestSpell(model, plr.Character, spellname)
						end
					end
				end)
			end
		end
	end
end

return actionsMod
