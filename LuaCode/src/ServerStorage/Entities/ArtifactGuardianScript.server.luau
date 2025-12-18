--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local model: Model = script.Parent
local random: Random = Random.new()

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local pathMod = require(ReplicatedStorage.Shared.pathMod)
local aggroMod = require(ReplicatedStorage.Shared.aggroMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local petControlMod = require(ReplicatedStorage.Shared.petControlMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)
local stateMod = require(ReplicatedStorage.Shared.stateMod)
local thisMob: string = utilMod.customTrim(model.Name)
random = Random.new(utilMod.GetSeedFromName(thisMob))

local humanoid: Humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp: BasePart = model:FindFirstChild("HumanoidRootPart")

if not humanoid or not hrp then
	return
end

local aggro = aggroMod.Setup(model)
local pet = petControlMod.Setup(model)

local sourceStats: { [string]: any } = combatMod.ShallowTableCopy(thisMob)
utilMod.CopyStatsToFolder(script.Parent, sourceStats)
-- NEW: Let buffMod take over event creation + stat refreshing + base stat restoration
buffMod.Setup(model, sourceStats)
local spawnPosition: Vector3 = hrp.Position

-- === Animations ===
local animator: Animator? = humanoid:FindFirstChildOfClass("Animator")

type AnimTrackDict = {
	idle: AnimationTrack?,
	blink: AnimationTrack?,
	death: AnimationTrack?,
	attack1: AnimationTrack?,
	attack2: AnimationTrack?,
	attack3: AnimationTrack?,
}

local animTracks: AnimTrackDict = {
	idle = nil,
	blink = nil,
	death = nil,
	attack1 = nil,
	attack2 = nil,
	attack3 = nil,
}

if animator then
	local function load(name: string, looped: boolean?): AnimationTrack?
		local anim: Animation? = model:FindFirstChild(name)
		if anim then
			local track: AnimationTrack = animator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
		return nil
	end

	animTracks.idle = load("ArtGuardIdle", true)
	animTracks.blink = load("ArtGuardBlink", false)
	animTracks.death = load("ArtGuardFall", false)
	animTracks.attack1 = load("ArtGuardAtt1", false)
	animTracks.attack2 = load("ArtGuardAtt2", false)
	animTracks.attack3 = load("ArtGuardAtt3", false)
end

-- === MAIN LOOP ===
task.spawn(function()
	local lithDefendRandomLoc: Vector3? = nil
	local lithTakeRandomLoc: Vector3? = nil

	-- Blink loop
	task.spawn(function()
		while task.wait(random:NextInteger(4, 15)) do
			if animTracks.blink and not model:GetAttribute("HasFallen") then
				animTracks.blink:Play()
				if random:NextInteger(1, 20) > 10 then
					lithTakeRandomLoc = nil
					lithDefendRandomLoc = nil
				end
			end
		end
	end)

	local lastAttackTime: number = 0
	local homewardBound: boolean = false
	local spincooldown: boolean = true

	-- Main loop for npc state
	while task.wait(0.03) do
		local ATTACK_COOLDOWN: number = statsMod.DELAY * model.Data.attackDelay.Value

		local ownerInstance: Model? = pet.GetOwnerModel()
		local combatTargetModel: Model? = nil
		local acceptableDistance: boolean? = nil
		local movingDirection: string = "NotMoving"

		local petAttack = pet.IsAttackEnabled()
		local petFollow = pet.IsFollowEnabled()
		local petTakeLith = pet.IsTakeLithEnabled()
		local petDefendlith = pet.IsDefendLithEnabled()
		local lithTakePosition = pet.GetLithTakePosition()
		local lithDefendPosition = pet.GetLithDefendPosition()

		if not model:GetAttribute("HasFallen") then
			-- starting over using pet commands integrated into state logic.

			----------------------------------------------------------------
			-- Aggro
			----------------------------------------------------------------

			aggro.Update()

			local hasEnemies: boolean = next(aggro.GetHateList()) ~= nil

			----------------------------------------------------------------
			-- SetStates
			----------------------------------------------------------------
			-- Inside your main loop, after updating aggro and pet values:
			local targetid: any = model:GetAttribute("TargetIDorName")
			if targetid and targetid ~= "" and targetid ~= "None" and targetid ~= "none" then
				combatTargetModel = utilMod.GetModelByIDorName(targetid)
			end

			if combatTargetModel then
				acceptableDistance = combatMod.AcceptableDistanceToOpponent(model, combatTargetModel)
			end

			local mutable = {
				lithTakeRandomLoc = lithTakeRandomLoc,
				lithDefendRandomLoc = lithDefendRandomLoc,
				homewardBound = homewardBound,
			}

			local context = {
				hasEnemies = next(aggro.GetHateList()) ~= nil,
				ownerInstance = pet.GetOwnerModel(),
				combatTargetModel = combatTargetModel,
				acceptableDistance = acceptableDistance,
				spawnPosition = spawnPosition,
				hrp = hrp,

				petAttack = pet.IsAttackEnabled(),
				petFollow = pet.IsFollowEnabled(),
				petTakeLith = pet.IsTakeLithEnabled(),
				petDefendLith = pet.IsDefendLithEnabled(),
				lithTakePosition = pet.GetLithTakePosition(),
				lithDefendPosition = pet.GetLithDefendPosition(),

				aggro = aggro,
				pet = pet,

				mutable = mutable,
			}

			local stateResult = stateMod.UpdateState(model, context)

			movingDirection = stateResult.movingDirection

			-- Sync mutable state back to locals (important!)
			lithTakeRandomLoc = mutable.lithTakeRandomLoc
			lithDefendRandomLoc = mutable.lithDefendRandomLoc
			homewardBound = mutable.homewardBound
			----------------------------------------------------------------
			-- Actions
			----------------------------------------------------------------

			if model:GetAttribute("InCombat") then
				----------------------------------------------------------------
				-- FACE TARGET / OWNER
				----------------------------------------------------------------

				if combatTargetModel and pathMod.IsPathActive(model) then
					if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
						pathMod.ShortCircuitTravel(model)
					end
				end
				if combatTargetModel and not pathMod.IsPathActive(model) then
					-- Face target smoothly during combat
					utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)

					if animTracks.idle and animTracks.idle.IsPlaying then
						animTracks.idle:Stop()
					end

					if tick() - lastAttackTime >= ATTACK_COOLDOWN then
						local track: AnimationTrack? = animTracks["attack" .. random:NextInteger(1, 3)]
						if track and not track.IsPlaying then
							track:Play()
							lastAttackTime = tick()
							-- NEW: All damage + threat + creator tag is now handled centrally
							task.delay(0.5, function()
								combatMod.ApplyMeleeDamage(model, combatTargetModel)
							end)
						end
					end
				end
			end
			----------------------------------------------------------------
			-- Moving
			----------------------------------------------------------------
			if model:GetAttribute("IsMoving") then
				if not animTracks.idle.IsPlaying then
					animTracks.idle:Play()
					animTracks.idle:AdjustSpeed(1.5)
				else
					animTracks.idle:AdjustSpeed(1.5)
				end

				if movingDirection == "MovingToCombatTarget" then
					local target: Vector3? = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"))
					if target and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
					elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
					end
				elseif movingDirection == "MovingToNearestLith" then
					if petDefendlith then
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
						else
							warn("should not reach me.")
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
						else
							warn("should not reach me.")
						end
					else
						warn("should not reach me.")
					end
				elseif movingDirection == "MovingToOwner" then
					local owner: any = model:GetAttribute("OwnedBy")
					local target: Vector3? = pathMod.GetTargetPet(model, owner)
					if target and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, target, owner)
					elseif pathMod.GetCurrentTarget(model) ~= utilMod.GetModelByIDorName(owner) then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, target, owner)
					end
				elseif movingDirection == "MovingToSpawnPosition" then
					if not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					end
				elseif movingDirection == "MovingToRandom" then
					local vec: Vector3 = Vector3.new(spawnPosition.X, hrp.Position.Y, spawnPosition.Z)
					if random:NextInteger(1, 10) < 5 then
						local xpos: number = random:NextInteger(-10, 10)
						local zpos: number = random:NextInteger(-10, 10)
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
				elseif movingDirection == "NotMoving" then
					warn("flag is moving but not target.")
				else
					warn("Should not reach me.")
				end
			end
			----------------------------------------------------------------
			-- Idle
			----------------------------------------------------------------
			if model:GetAttribute("IsIdle") then
				if not animTracks.idle.IsPlaying then
					animTracks.idle:Play()
					animTracks.idle:AdjustSpeed(1.0)
				else
					animTracks.idle:AdjustSpeed(1.0)
				end
				if pathMod.IsPathActive(model) then
					pathMod.ShortCircuitTravel(model)
				end

				if
					ownerInstance
					and (tick() - model:GetAttribute("IdleStartTime")) > random:NextInteger(10, 20)
					and spincooldown
				then
					spincooldown = false

					utilMod.SpinToOwner(model, hrp, ownerInstance, random, spincooldown)

					-- Allow next turn after a random delay
					task.delay(random:NextInteger(8, 15), function()
						spincooldown = true
					end)
				end
			end
		else
			----------------------------------------------------------------
			-- Death
			----------------------------------------------------------------
			if animTracks.death and not animTracks.death.IsPlaying then
				if animTracks.blink then
					animTracks.blink:Stop()
				end
				if animTracks.idle then
					animTracks.idle:Stop()
				end
				animTracks.death:Play()
				task.wait(3)
				model:SetAttribute("RecycleMe", true)
			else
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				humanoid.PlatformStand = true
				model:SetAttribute("RecycleMe", true)
			end
		end
	end
end)
