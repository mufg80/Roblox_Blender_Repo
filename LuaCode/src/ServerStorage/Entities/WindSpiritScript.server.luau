--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverstorage = game:GetService("ServerStorage")
local runservice = game:GetService("RunService")
local model: Model = script.Parent

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local pathMod = require(ReplicatedStorage.Shared.pathMod)
local aggroMod = require(ReplicatedStorage.Shared.aggroMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local petControlMod = require(ReplicatedStorage.Shared.petControlMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)
local stateMod = require(ReplicatedStorage.Shared.stateMod)
local actionsMod = require(ReplicatedStorage.Shared.actionsMod)

local thisMob: string = utilMod.customTrim(model.Name)
local random = Random.new(utilMod.GetSeedFromName(thisMob))

local MINATTACKDELAY = 0
local humanoid: Humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp: BasePart = model:FindFirstChild("HumanoidRootPart")

if not humanoid or not hrp then
	return
end
local dervishmodel: Model = nil
if string.sub(thisMob, 1, 5) == "Feral" then
	-- it's a Feral mob
	dervishmodel = serverstorage:FindFirstChild("FeralEntities").FeralDervish:Clone()
else
	dervishmodel = serverstorage:FindFirstChild("Entities").Dervish:Clone()
end

local dervhumanoid = dervishmodel:FindFirstChild("Humanoid")
local dervAnimator = dervhumanoid:FindFirstChild("Animator")
local dervhrp: BasePart = dervishmodel:FindFirstChild("HumanoidRootPart") :: BasePart
if not dervishmodel or not dervhumanoid or not dervAnimator or not dervhrp then
	warn("Should not reach me")
	return
end
dervishmodel.Parent = model

local aggro = aggroMod.Setup(model)
local pet = petControlMod.Setup(model)

local sourceStats: { [string]: any } = combatMod.ShallowTableCopy(thisMob)
utilMod.CopyStatsToFolder(model, sourceStats)
-- NEW: Let buffMod take over event creation + stat refreshing + base stat restoration
buffMod.Setup(model, sourceStats)

-- === Animations ===
local animator: Animator? = humanoid:FindFirstChildOfClass("Animator")

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

local animTracks: AnimTrackDict = {
	idle = {},
	delayConnection = nil,
	idleConnection = nil,
	move = nil,
	blink = nil,
	death = nil,
	attacks = {},
	cast = nil,
	favoredAttack = nil,
	moveSpeed = nil,
	idleSpeed = nil,
	deathSpeed = 1,
	castSpeed = nil,
	attackSpeeds = { 1, 1, 1, 1 },
}

local dervanimTracks: AnimTrackDict = {
	idle = {},
	delayConnection = nil,
	idleConnection = nil,
	move = nil,
	blink = nil,
	death = nil,
	attacks = {},
	cast = nil,
	favoredAttack = nil,
	moveSpeed = nil,
	idleSpeed = nil,
	deathSpeed = 2,
	castSpeed = nil,
	attackSpeeds = { 1, 1, 1, 1, 1, 1 },
}

if animator then
	if not dervAnimator then
		warn("should not reach me.")
		return
	end
	local function load(name: string, looped: boolean?): AnimationTrack?
		local anim: Animation? = model:WaitForChild(name, 5)
		if anim then
			local track: AnimationTrack = animator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
		return nil
	end

	local function loadDervish(name: string, looped: boolean?): AnimationTrack?
		local anim: Animation? = dervishmodel:WaitForChild(name, 5)
		if anim then
			local track: AnimationTrack = dervAnimator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
		return nil
	end

	table.insert(animTracks.idle, load("WSIdle", true))
	animTracks.move = load("WSRun", true)
	animTracks.death = load("WSFall", false)
	table.insert(animTracks.attacks, load("WSPunch1", false))
	table.insert(animTracks.attacks, load("WSPunch2", false))
	table.insert(animTracks.attacks, load("WSKick1", false))
	table.insert(animTracks.attacks, load("WSKick2", false))
	animTracks.favoredAttack = 1

	dervanimTracks.death = loadDervish("FallAnim", false)

	local idleTrack = loadDervish("IdleAnim", true) -- explicitly looped
	if idleTrack then
		table.insert(dervanimTracks.idle, idleTrack)
		idleTrack:Play(0, 1, dervanimTracks.idleSpeed or 1) -- fadeTime 0, weight 1 for instant/full
	end
	-- Get minAttackDelay (longest animation length)
	for i, attack: AnimationTrack? in animTracks.attacks do
		if attack then
			while attack.Length <= 0 do
				task.wait()
			end
			if MINATTACKDELAY < attack.Length / (dervanimTracks.attackSpeeds[i] or 1) then
				MINATTACKDELAY = attack.Length / (dervanimTracks.attackSpeeds[i] or 1)
			end
		end
	end
end

runservice.Heartbeat:Connect(function()
	dervhrp:PivotTo(hrp.CFrame)
end)

-- === MAIN LOOP ===
task.spawn(function()
	local lithDefendRandomLoc: Vector3? = nil
	local lithTakeRandomLoc: Vector3? = nil

	-- Blink loop (no blink animation loaded, so just random cache clear)
	task.spawn(function()
		while task.wait(random:NextInteger(15, 25)) do
			if not utilMod.GetAttribute(model, "HasFallen") then
				if random:NextInteger(1, 100) > 10 then
					lithTakeRandomLoc = nil
					lithDefendRandomLoc = nil
				end
			end
		end
	end)

	local lastAttackTime: number = 0
	local homewardBound: boolean = false
	local deathPlayed = false

	-- Main loop for npc state
	while task.wait(0.03) do
		local ATTACK_COOLDOWN: number = statsMod.DELAY * model.Data.attackDelay.Value
		if ATTACK_COOLDOWN < MINATTACKDELAY then
			ATTACK_COOLDOWN = MINATTACKDELAY
			warn("slow anims on "..thisMob)
		end
		local ownerInstance: Model? = pet.GetOwnerModel()
		local combatTargetModel: Model? = nil
		local acceptableDistance: boolean? = nil
		local movingDirection: string = "NotMoving"

		local petAttack = pet.IsAttackEnabled()
		local petFollow = pet.IsFollowEnabled()
		local petTakeLith = pet.IsTakeLithEnabled()
		local petDefendLith = pet.IsDefendLithEnabled()
		local lithTakePosition = pet.GetLithTakePosition()
		local lithDefendPosition = pet.GetLithDefendPosition()

		if not utilMod.GetAttribute(model, "HasFallen") then
			----------------------------------------------------------------
			-- Aggro
			----------------------------------------------------------------

			aggro.Update()

			----------------------------------------------------------------
			-- SetStates
			----------------------------------------------------------------
			local targetid: any = utilMod.GetAttribute(model, "TargetIDorName")
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
				ownerInstance = ownerInstance,
				combatTargetModel = combatTargetModel,
				acceptableDistance = acceptableDistance,
				spawnPosition = pet.GetSpawnPoint(),
				hrp = hrp,
				random = random,
				petAttack = petAttack,
				petFollow = petFollow,
				petTakeLith = petTakeLith,
				petDefendLith = petDefendLith,
				lithTakePosition = lithTakePosition,
				lithDefendPosition = lithDefendPosition,

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

			local actionContext = {
				model = model,
				hrp = hrp,
				animTracks = animTracks,
				combatTargetModel = combatTargetModel,
				movingDirection = movingDirection,
				ownerInstance = ownerInstance,
				lastAttackTime = { value = lastAttackTime },
				ATTACK_COOLDOWN = ATTACK_COOLDOWN,
				spawnPosition = pet.GetSpawnPoint(),
				random = random,

				petAttack = petAttack,
				petTakeLith = petTakeLith,
				petDefendLith = petDefendLith,
				lithTakePosition = lithTakePosition,
				lithDefendPosition = lithDefendPosition,

				lithTakeRandomLoc = lithTakeRandomLoc,
				lithDefendRandomLoc = lithDefendRandomLoc,
				homewardBound = homewardBound,

				pathMod = pathMod,
				combatMod = combatMod,
				utilMod = utilMod,
				pet = pet,
			}

			actionsMod.PerformActions(actionContext)

			-- Sync back mutables
			lastAttackTime = actionContext.lastAttackTime
			homewardBound = actionContext.homewardBound
			lithDefendRandomLoc = actionContext.lithDefendRandomLoc
			lithTakeRandomLoc = actionContext.lithTakeRandomLoc
		else
			----------------------------------------------------------------
			-- Death
			----------------------------------------------------------------
			-- if animTracks.death then
			-- 	if not animTracks.death.IsPlaying and not deathPlayed then
			-- 		deathPlayed = true
			-- 		local deathanim: AnimationTrack = animTracks.death
			-- 		deathanim:Play(0.3, 1, animTracks.deathSpeed or 1)
			-- 		deathanim.Stopped:Connect(function()
			-- 			local length = deathanim.Length - 0.01
			-- 			deathanim:AdjustSpeed(0)
			-- 			deathanim.TimePosition = length
			-- 			task.wait(3)
			-- 			utilMod.SetAttribute(model, "RecycleMe", true)
			-- 		end)

			-- 		local deathdervanim: AnimationTrack = dervanimTracks.death
			-- 		if deathdervanim then
			-- 			local idlean = dervanimTracks.idle
			-- 			for _, track in ipairs(idlean) do
			-- 				if track and track.IsPlaying then
			-- 					track:Stop(0.3)
			-- 				end
			-- 			end

			-- 			deathdervanim:Play(0.3, 1, (dervanimTracks.deathSpeed or 1))
			-- 			deathdervanim.Stopped:Connect(function()
			-- 				local length = deathanim.Length - 0.01
			-- 				deathanim:AdjustSpeed(0)
			-- 				deathanim.TimePosition = length
			-- 				dervishmodel.Parent = nil
			-- 			end)
			-- 		end
			-- 	end
			-- else
			-- 	warn("Should not reach me.")
			-- 	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			-- 	humanoid.PlatformStand = true
			-- 	utilMod.SetAttribute(model, "RecycleMe", true)
			-- end
			 if animTracks.death then
                if not animTracks.death.IsPlaying and not deathPlayed then
                    deathPlayed = true

					-- dervish stop

					local deathdervanim: AnimationTrack = dervanimTracks.death
					if deathdervanim then
						local idlean = dervanimTracks.idle
						for _, track in ipairs(idlean) do
							if track and track.IsPlaying then
								track:Stop(0.1)
							end
						end

						deathdervanim:Play(0.3, 1, (dervanimTracks.deathSpeed or 1))
						deathdervanim.Stopped:Connect(function()
							deathdervanim:Play(0.3, 1, (dervanimTracks.deathSpeed or 1))
							local length = deathdervanim.Length - 0.1
							deathdervanim:AdjustSpeed(0)
							deathdervanim.TimePosition = length
							dervishmodel.Parent = nil
						end)
					end

                    for _,idleanim in animTracks.idle do
                        if idleanim.IsPlaying then
                            idleanim:Stop(0.1)
                        end
                    end
                     for _,attanim in animTracks.attacks do
                        if attanim.IsPlaying then
                            attanim:Stop(0.1)
                        end
                    end
                    if animTracks.move.IsPlaying then
                        animTracks.move:Stop(.1)
                    end
                    local deathanim: AnimationTrack = animTracks.death
                    deathanim:Play(0.3, 1, animTracks.deathSpeed or 1)
                    deathanim.Stopped:Connect(function()
                        deathanim:Play(0.3, 1, animTracks.deathSpeed or 1)
                        local length = deathanim.Length - 0.2
                        deathanim:AdjustSpeed(0)
                        deathanim.TimePosition = length
                        task.wait(2)
                        utilMod.SetAttribute(model, "RecycleMe", true)
                    end)
                end
            else
                warn("Should not reach me.")
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                humanoid.PlatformStand = true
                utilMod.SetAttribute(model, "RecycleMe", true)
            end
		end
	end
end)
