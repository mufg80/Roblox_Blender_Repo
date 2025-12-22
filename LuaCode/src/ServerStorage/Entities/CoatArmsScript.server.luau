--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local aggro = aggroMod.Setup(model)
local pet = petControlMod.Setup(model)

local sourceStats: { [string]: any } = combatMod.ShallowTableCopy(thisMob)
utilMod.CopyStatsToFolder(script.Parent, sourceStats)
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
}

if animator then
	local function load(name: string, looped: boolean?): AnimationTrack?
		local anim: Animation? = model:WaitForChild(name)
		if anim then
			local track: AnimationTrack = animator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
		return nil
	end

	table.insert(animTracks.idle, load("CoatIdle", false))
	animTracks.move = load("CoatRun", true)
	animTracks.death = load("CoatFall", false)
	table.insert(animTracks.attacks, load("CoatAttack1", false))
	table.insert(animTracks.attacks, load("CoatAttack2", false))
	table.insert(animTracks.attacks, load("CoatAttack3", false))
	animTracks.favoredAttack = 1

	-- Get minAttackDelay (longest animation length)
	for _, attack: AnimationTrack in ipairs(animTracks.attacks) do
		-- Wait until the length is loaded (it's async)
		while attack.Length <= 0 do
			task.wait() -- or RunService.Heartbeat:Wait() for more precision
		end

		if MINATTACKDELAY < attack.Length then
			MINATTACKDELAY = attack.Length
		end
	end

end

-- === MAIN LOOP ===
task.spawn(function()
	local lithDefendRandomLoc: Vector3? = nil
	local lithTakeRandomLoc: Vector3? = nil

	-- Blink loop
	task.spawn(function()
		while task.wait(random:NextInteger(4, 15)) do
			if not model:GetAttribute("HasFallen") then
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
	local idleConnection: RBXScriptConnection? = nil
	local deathPlayed = false
	-- Main loop for npc state
	while task.wait(0.03) do
		local ATTACK_COOLDOWN: number = statsMod.DELAY * model.Data.attackDelay.Value
		if ATTACK_COOLDOWN < MINATTACKDELAY then
			ATTACK_COOLDOWN = MINATTACKDELAY
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

		if not model:GetAttribute("HasFallen") then
			-- starting over using pet commands integrated into state logic.

			----------------------------------------------------------------
			-- Aggro
			----------------------------------------------------------------

			aggro.Update()

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
				spawnPosition = pet.GetSpawnPoint(),
				hrp = hrp,
				random = random,
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

				spincooldown = spincooldown,
			}

			actionsMod.PerformActions(actionContext)

			-- Sync back mutables
			lastAttackTime = actionContext.lastAttackTime.value
			spincooldown = actionContext.spincooldown
			homewardBound = actionContext.homewardBound
		else
			----------------------------------------------------------------
			-- Death
			----------------------------------------------------------------
			if animTracks.death then
				if not animTracks.death.IsPlaying and not deathPlayed then
					deathPlayed = true
					local deathanim: AnimationTrack = animTracks.death
					deathanim:Play(0.3, 1, 1)
					deathanim.Stopped:Connect(function()
						local length = deathanim.Length - 0.01
						deathanim:AdjustSpeed(0)
						deathanim.TimePosition = length
						task.wait(2)
						model:SetAttribute("RecycleMe", true)
					end)
				end
			else
				warn("Should not reach me.")
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				humanoid.PlatformStand = true
				model:SetAttribute("RecycleMe", true)
			end
		end
	end
end)
