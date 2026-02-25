--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local serverstorage = game:GetService("ServerStorage")
local runservice = game:GetService("RunService")
local model: Model = script.Parent

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local pathMod = require(ReplicatedStorage.Shared.pathMod)
local aggroMod = require(ReplicatedStorage.Shared.aggroMod)
local petControlMod = require(ReplicatedStorage.Shared.petControlMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)
local stateMod = require(ReplicatedStorage.Shared.stateMod)
local actionsMod = require(ReplicatedStorage.Shared.actionsMod)

local thisMob: string = utilMod.customTrim(model.Name)
local random = Random.new(utilMod.GetSeedFromName(thisMob))

local MINATTACKDELAY = 0
local humanoid: Instance? = model:FindFirstChildOfClass("Humanoid")
if not humanoid or not humanoid:IsA("Humanoid") then
	warn("Should not reach me")
end
local hrp: Instance? = model:FindFirstChild("HumanoidRootPart")
if not hrp or not hrp:IsA("BasePart") then
	warn("Should not reach me")
end

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
local dervAnimator = dervhumanoid and dervhumanoid:FindFirstChild("Animator")
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


local animTracks: actionsMod.AnimTrackDict  = {
	idle = {},
	delayConnection = nil,
	idleConnection = nil,
	move = nil,
	blink = nil,
	death = nil,
	attacks = {},
	cast = nil,
	favoredAttack = 1,
	moveSpeed = nil,
	idleSpeed = nil,
	deathSpeed = 1,
	castSpeed = nil,
	attackSpeeds = { 1, 1, 1, 1 },
}

local dervanimTracks: actionsMod.AnimTrackDict  = {
	idle = {},
	delayConnection = nil,
	idleConnection = nil,
	move = nil,
	blink = nil,
	death = nil,
	attacks = {},
	cast = nil,
	favoredAttack = 1,
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
		local anim: Instance? = model:WaitForChild(name, 5)
		if anim and anim:IsA("Animation") and animator:IsA("Animator") then
			local track: AnimationTrack = animator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
		return nil
	end

	local function loadDervish(name: string, looped: boolean?): AnimationTrack?
		local anim: Instance? = dervishmodel:WaitForChild(name, 5)
		if anim and anim:IsA("Animation") and dervAnimator:IsA("Animator") then
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
	if hrp and hrp:IsA("BasePart") then
		dervhrp:PivotTo(hrp.CFrame)
	end
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
	local deathPlayed = {value = false}

	-- Main loop for npc state
	while task.wait(0.03) do
		local ATTACK_COOLDOWN = utilMod.GetCooldown(model)

		if ATTACK_COOLDOWN < MINATTACKDELAY then
			ATTACK_COOLDOWN = MINATTACKDELAY
			warn("slow anims on " .. thisMob)
		end
		if not pet then
			continue
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
			if not aggro then
				warn("should not reach me")
				continue
			end
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
			if not hrp or not hrp:IsA("BasePart") then
				continue
			end
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
			local actionresult = actionsMod.PerformActions(actionContext)

			-- Sync back mutables
			lastAttackTime = actionresult.lastAttackTime.value
			homewardBound = actionresult.homewardBound
			lithDefendRandomLoc = actionresult.lithDefendRandomLoc.value
			lithTakeRandomLoc = actionresult.lithTakeRandomLoc.value
		else
			----------------------------------------------------------------
			-- Death
			----------------------------------------------------------------

			if animTracks.death then
				combatMod.FallAnimation(model, animTracks, dervanimTracks, deathPlayed)
			else
				warn("Should not reach me.")
				if humanoid and humanoid:IsA("Humanoid") then
					humanoid:ChangeState(Enum.HumanoidStateType.Physics)
					humanoid.PlatformStand = true
					utilMod.SetAttribute(model, "RecycleMe", true)
				end
			end
		end
	end
end)
