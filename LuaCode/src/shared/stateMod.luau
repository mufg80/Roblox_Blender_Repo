--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local pathMod = require(ReplicatedStorage.Shared.pathMod)

local stateMod = {}

export type Context = {
	-- Read-only data (updated each frame)
	hasEnemies: boolean,
	ownerInstance: Model?,
	combatTargetModel: Model?,
	acceptableDistance: boolean?,
	spawnPosition: Vector3,
	hrp: BasePart,

	petAttack: boolean,
	petFollow: boolean,
	petTakeLith: boolean,
	petDefendLith: boolean,
	lithTakePosition: Vector3?,
	lithDefendPosition: Vector3?,

	aggro: any, -- your aggroMod instance
	pet: any, -- your petControlMod instance

	-- Mutable persistent state (shared across frames)
	mutable: {
		lithTakeRandomLoc: Vector3?,
		lithDefendRandomLoc: Vector3?,
		homewardBound: boolean,
	},
}

export type StateResult = {
	movingDirection: string,
}

local healerCache: { [string]: boolean } = {}

-- Main function called every loop from the NPC script
function stateMod.UpdateState(model: Model, context: Context): StateResult
	if not model or not context then
		warn("Should not reach me.")
		return
	end
	local mutable = context.mutable

	local hasEnemies = context.hasEnemies
	local ownerInstance = context.ownerInstance
	local combatTargetModel = context.combatTargetModel
	local acceptableDistance = context.acceptableDistance
	local spawnPosition = context.spawnPosition
	local hrp = context.hrp
	local random = context.random
	local petAttack = context.petAttack
	local petFollow = context.petFollow
	local petTakeLith = context.petTakeLith
	local petDefendLith = context.petDefendLith
	local lithTakePosition = context.lithTakePosition
	local lithDefendPosition = context.lithDefendPosition
	local aggro = context.aggro

	local movingDirection = "NotMoving"
	if not healerCache[model.Name] then
		healerCache[model.Name] = utilMod.IsMobHealer(model)
	end

	-- === PET STATE LOGIC ===

	local isPet: boolean = utilMod.GetAttribute(model, "OwnedBy") ~= nil
		and utilMod.GetAttribute(model, "OwnedBy") ~= ""
		and utilMod.GetAttribute(model, "OwnedBy") ~= "None"
		and utilMod.GetAttribute(model, "OwnedBy") ~= "none"

	if healerCache[model.Name] then
		acceptableDistance = utilMod.GetAcceptableDistanceForCaster(combatTargetModel, model)
	end

	if petDefendLith and lithDefendPosition and not mutable.lithDefendRandomLoc then
		while not mutable.lithDefendRandomLoc do
			mutable.lithDefendRandomLoc = pathMod.GetTargetLith(lithDefendPosition)
			local issafe = pathMod.CanIPathFindtoPosition(model, mutable.lithDefendRandomLoc)
			if not issafe then
				print("not good random position")
				mutable.lithDefendRandomLoc = nil
			end
		end
	end
	if petTakeLith and lithTakePosition and not mutable.lithTakeRandomLoc then
		while not mutable.lithTakeRandomLoc do
			mutable.lithTakeRandomLoc = pathMod.GetTargetLith(lithTakePosition)
			local issafe = pathMod.CanIPathFindtoPosition(model, mutable.lithTakeRandomLoc)
			if not issafe then
				mutable.lithTakeRandomLoc = nil
			end
		end
	end

	if isPet then
		-- Clear lith caches when following (as in original blink logic and follow mode)
		if petFollow then
			mutable.lithDefendRandomLoc = nil
			mutable.lithTakeRandomLoc = nil
		end

		if
			petAttack and petFollow
			or (petAttack and petDefendLith and lithDefendPosition == nil)
			or (petAttack and petTakeLith and lithTakePosition == nil)
		then
			-- Attack + Follow (or invalid lith command): fight enemies, otherwise follow owner
			if hasEnemies then
				if acceptableDistance then
					if not utilMod.GetAttribute(model, "InCombat") then
						utilMod.SetFlagsForCombat(model)
					end
				else
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							utilMod.SetFlagsForIdle(model)
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			else
				-- No enemies → follow owner
				local check: Vector3? = ownerInstance
					and pathMod.GetTargetPet(model, game.Players:GetPlayerFromCharacter(ownerInstance).UserId, random)
				if check then
					utilMod.SetFlagsForMoving(model)
					movingDirection = "MovingToOwner"
				else
					if pathMod.IsPathActive(model) then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToOwner"
					else
						utilMod.SetFlagsForIdle(model)
					end
				end
			end
		elseif petAttack and petDefendLith then
			-- Attack + Defend Lith: finish combat first, then move to defend position
			if hasEnemies then
				if acceptableDistance then
					utilMod.SetFlagsForCombat(model)
				else
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							utilMod.SetFlagsForIdle(model)
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			else
				aggro.ClearHateList()

				if lithDefendPosition then
					if mutable.lithDefendRandomLoc then
						if utilMod.GetDistance(mutable.lithDefendRandomLoc, hrp.Position) > 5 then
							if not utilMod.GetAttribute(model, "IsMoving") then
								utilMod.SetFlagsForMoving(model)
								movingDirection = "MovingToNearestLith"
							else
								local targ = pathMod.GetCurrentTarget(model)
								if targ and targ ~= "Lith" then
									utilMod.SetFlagsForIdle(model)
								else
									utilMod.SetFlagsForMoving(model)
									movingDirection = "MovingToNearestLith"
								end
							end
						else
							utilMod.SetFlagsForIdle(model)
						end
					else
						utilMod.SetFlagsForIdle(model)
					end
				else
					utilMod.SetFlagsForIdle(model)
				end
			end
		elseif petAttack and petTakeLith then
			-- Attack + Take Lith: finish combat first, then move to take position
			if hasEnemies then
				if acceptableDistance then
					if not utilMod.GetAttribute(model, "InCombat") then
						utilMod.SetFlagsForCombat(model)
					end
				else
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							utilMod.SetFlagsForIdle(model)
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			else
				aggro.ClearHateList()

				if lithTakePosition then
					if mutable.lithTakeRandomLoc then
						if utilMod.GetDistance(mutable.lithTakeRandomLoc, hrp.Position) > 5 then
							if not utilMod.GetAttribute(model, "IsMoving") then
								utilMod.SetFlagsForMoving(model)
								movingDirection = "MovingToNearestLith"
							else
								local targ = pathMod.GetCurrentTarget(model)
								if targ and targ ~= "Lith" then
									utilMod.SetFlagsForIdle(model)
								else
									utilMod.SetFlagsForMoving(model)
									movingDirection = "MovingToNearestLith"
								end
							end
						else
							utilMod.SetFlagsForIdle(model)
						end
					else
						utilMod.SetFlagsForIdle(model)
					end
				else
					utilMod.SetFlagsForIdle(model)
				end
			end
		elseif petAttack and not petFollow then
			-- Guard position: attack enemies, but return to spawnPosition if drifted
			if hasEnemies then
				if acceptableDistance then
					if not utilMod.GetAttribute(model, "InCombat") then
						utilMod.SetFlagsForCombat(model)
					end
				else
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							utilMod.SetFlagsForIdle(model)
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			else
				local distanceFromGuardSpot = utilMod.GetDistance(spawnPosition, hrp.Position)
				if distanceFromGuardSpot > 10 then
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
					end
					movingDirection = "MovingToSpawnPosition"
				else
					utilMod.SetFlagsForIdle(model)
					if pathMod.IsPathActive(model) then
						pathMod.ShortCircuitTravel(model)
					end
				end
			end
		elseif not petAttack and petFollow then
			-- Passive follow only
			aggro.ClearHateList()

			if ownerInstance then
				local check: Vector3? =
					pathMod.GetTargetPet(model, game.Players:GetPlayerFromCharacter(ownerInstance).UserId)
				if check then
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
					end
					movingDirection = "MovingToOwner"
				else
					utilMod.SetFlagsForIdle(model)
				end
			else
				utilMod.SetFlagsForIdle(model)
			end
		elseif not petAttack and not petFollow then
			-- Stay planted
			aggro.ClearHateList()

			if utilMod.GetDistance(spawnPosition, hrp.Position) > 3 then
				-- Update spawnPosition to current if slightly pushed
				-- (Note: spawnPosition is read-only in context; main script must apply this if desired)
			end

			utilMod.SetFlagsForIdle(model)
			if pathMod.IsPathActive(model) then
				pathMod.ShortCircuitTravel(model)
			end
			movingDirection = "NotMoving"
		else
			warn("Unhandled pet command combination")
		end
	else
		-- === FERAL (NON-PET) LOGIC ===
		if hasEnemies then
			if acceptableDistance then
				if not utilMod.GetAttribute(model, "InCombat") then
					utilMod.SetFlagsForCombat(model)
				end
			else
				if not utilMod.GetAttribute(model, "IsMoving") then
					utilMod.SetFlagsForMoving(model)
					movingDirection = "MovingToCombatTarget"
				else
					local targ = pathMod.GetCurrentTarget(model)
					if targ ~= combatTargetModel then
						utilMod.SetFlagsForIdle(model)
					else
						movingDirection = "MovingToCombatTarget"
					end
				end
			end
		else
			-- No enemies
			if utilMod.GetAttribute(model, "StationaryStatus") == "Stationary" then
				if
					utilMod.GetDistance(spawnPosition, hrp.Position) > 3
					and time() - (utilMod.GetAttribute(model, "IdleStartTime") or 0)
						> (utilMod.GetAttribute(model, "IdleReset") or 15)
				then
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
					end
					movingDirection = "MovingToSpawnPosition"
				else
					utilMod.SetFlagsForIdle(model)
				end
			elseif
				utilMod.GetAttribute(model, "StationaryStatus") == "Roaming"
				or utilMod.GetAttribute(model, "StationaryStatus") == "Traveler"
			then
				-- Roaming feral
				local tooFar = utilMod.GetDistance(hrp.Position, spawnPosition)
					> (utilMod.GetAttribute(model, "RangeLimit") or 50)

				if tooFar and not mutable.homewardBound then
					mutable.homewardBound = true
					if pathMod.IsPathActive(model) then
						pathMod.ShortCircuitTravel(model)
					end
					utilMod.SetFlagsForIdle(model)
				elseif mutable.homewardBound then
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
					end
					movingDirection = "HomewardBound"
				elseif
					time() - (utilMod.GetAttribute(model, "IdleStartTime") or 0)
					> (utilMod.GetAttribute(model, "IdleReset") or 15)
				then
					if not utilMod.GetAttribute(model, "IsMoving") then
						utilMod.SetFlagsForMoving(model)
					elseif utilMod.GetAttribute(model, "IsMoving") and not pathMod.IsPathActive(model) then
						utilMod.SetFlagsForIdle(model)
					end
					movingDirection = "MovingToRandom"
				else
					utilMod.SetFlagsForIdle(model)
				end

				-- Traveler-only: occasionally pick a completely new home location
				if utilMod.GetAttribute(model, "StationaryStatus") == "Traveler" then
					local lastReassign = utilMod.GetAttribute(model, "LastReassignTime") or 0
					local reassignInterval = math.random(75, 150) -- 75–150 seconds (~1.25–2.5 min), tune as desired

					-- Only attempt when truly idle / not doing anything else
					if
						not mutable.homewardBound
						and not utilMod.GetAttribute(model, "IsMoving")
						and time() - lastReassign > reassignInterval
					then
						-- Optional safety: only reassign if close to current spawn (prevents mid-journey jumps)
						if utilMod.GetDistance(hrp.Position, spawnPosition) < 8 then
							local newSpawn = utilMod.ReassignSpawn(model, spawnPosition)

							if newSpawn and typeof(newSpawn) == "Vector3" then
								spawnPosition = newSpawn
								context.pet.SetSpawnPoint(spawnPosition)
								-- Reset homeward state since we have a new legal home
								mutable.homewardBound = false

								-- Update timestamp
								utilMod.SetAttribute(model, "LastReassignTime", time())

								-- Optional: give it a gentle nudge so it doesn't look frozen
								-- (especially useful if the new point is very close)
								if math.random() < 0.6 then
									utilMod.SetFlagsForMoving(model)
									movingDirection = "MovingToRandom"
								end

								-- Optional debug print (remove later)
								-- warn(model.Name .. " Traveler reassigned spawn to " .. tostring(newSpawn))
							end
						end
					end
				end
			end
		end
	end
	return {
		movingDirection = movingDirection,
	}
end

return stateMod
