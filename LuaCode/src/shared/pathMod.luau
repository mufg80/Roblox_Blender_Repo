--!strict

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local pathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

-- Exported types for better IntelliSense and type safety
export type TargetIdentifier = number | string | Model | "SpawnPoint" | "Lith"

export type PathMod = {
	GetTakeLithLoc: (model: Model, hrp: BasePart) -> Vector3?,
	GetDefendLithLoc: (model: Model, hrp: BasePart) -> Vector3?,
	GetCurrentTarget: (model: Model) -> Model | nil | "SpawnPoint" | "Lith",
	PathfindToPosition: (model: Model, targetPosition: Vector3, targetIdOrName: TargetIdentifier) -> boolean,
	IsPathActive: (model: Model) -> boolean,
	ShortCircuitTravel: (model: Model) -> (),
	GetTargetPet: (model: Model, targetIdOrName: number | string, random: Random) -> Vector3?,
	GetTargetLith: (pos: Vector3) -> Vector3?,
}

local pathMod: PathMod = {} :: any

function pathMod.GetTakeLithLoc(model: Model, hrp: BasePart): Vector3?
	-- Validate inputs
	if not model or not hrp then
		return nil
	end

	local ownedById = model:GetAttribute("OwnedBy")
	if not ownedById or ownedById == "" or ownedById == "None" or ownedById == "none" then
		return nil
	end

	local plr = game.Players:GetPlayerByUserId(ownedById)
	if not plr then
		return nil
	end

	local manaPointsFolder = workspace:FindFirstChild("ManaPoints")
	if not manaPointsFolder then
		return nil
	end

	local points = manaPointsFolder:GetChildren()
	if #points == 0 then
		return nil
	end

	local closestPoint: MeshPart? = nil
	local closestDist: number = math.huge
	local playerUserId: number = plr.UserId

	for _, point in ipairs(points) do
		-- Skip if it's a ManaSpout or owned by the same player
		if point.Name == "ManaSpout" then
			continue
		end
		if point:GetAttribute("OwnedBy") == playerUserId then
			continue
		end

		local meshPart = point:FindFirstChildOfClass("MeshPart")
		if not meshPart then
			continue
		end

		local dist = utilMod.GetDistance(meshPart.Position, hrp.Position)
		if dist < closestDist then
			closestDist = dist
			closestPoint = meshPart
		end
	end

	if closestPoint then
		return closestPoint.Position
	else
		return nil
	end
end

function pathMod.GetDefendLithLoc(model: Model, hrp: BasePart): Vector3?
	-- Validate core inputs
	if not model or not hrp then
		return nil
	end

	local ownedById = model:GetAttribute("OwnedBy")
	if not ownedById or ownedById == "" or ownedById == "None" or ownedById == "none" then
		return nil
	end

	local plr = game.Players:GetPlayerByUserId(ownedById)
	if not plr then
		return nil
	end

	local manaPointsFolder = workspace:FindFirstChild("ManaPoints")
	if not manaPointsFolder then
		return nil
	end

	local points = manaPointsFolder:GetChildren()
	if #points == 0 then
		return nil
	end

	local playerUserId: number = plr.UserId
	local underAttackLiths: { MeshPart } = {}
	local ownedLiths: { MeshPart } = {}

	-- Collect owned liths and those under attack
	for _, point in ipairs(points) do
		if point.Name == "ManaSpout" then
			continue
		end

		local meshPart = point:FindFirstChildOfClass("MeshPart")
		if not meshPart then
			continue
		end

		local ownedBy = point:GetAttribute("OwnedBy")
		if ownedBy ~= playerUserId then
			continue
		end

		table.insert(ownedLiths, meshPart)

		local isUnderAttack = point:GetAttribute("IsUnderAttack")
		if isUnderAttack then
			table.insert(underAttackLiths, meshPart)
		end
	end

	-- Priority 1: Defend liths under attack
	if #underAttackLiths > 0 then
		if #underAttackLiths == 1 then
			return underAttackLiths[1].Position
		else
			-- Find closest under-attack lith
			local closest: MeshPart? = nil
			local closestDist: number = math.huge
			for _, mesh in ipairs(underAttackLiths) do
				local dist = utilMod.GetDistance(hrp.Position, mesh.Position)
				if dist < closestDist then
					closestDist = dist
					closest = mesh
				end
			end
			return closest and closest.Position or nil
		end
	end

	-- Priority 2: No attacks → go to closest owned lith
	if #ownedLiths == 0 then
		return nil
	elseif #ownedLiths == 1 then
		return ownedLiths[1].Position
	else
		local closest: MeshPart? = nil
		local closestDist: number = math.huge
		for _, mesh in ipairs(ownedLiths) do
			local dist = utilMod.GetDistance(hrp.Position, mesh.Position)
			if dist < closestDist then
				closestDist = dist
				closest = mesh
			end
		end
		return closest and closest.Position or nil
	end
end

-- Internal tracking
local activePaths: { [Model]: { connection: RBXScriptConnection, targetIdOrName: TargetIdentifier } } = {}

local function addModel(model: Model, targetIdOrName: TargetIdentifier, connection: RBXScriptConnection?)
	if not activePaths[model] then
		activePaths[model] = { connection = connection :: RBXScriptConnection, targetIdOrName = targetIdOrName }
	end
end

function pathMod.GetCurrentTarget(model: Model): Model | nil | "SpawnPoint" | "Lith"
	local entry = activePaths[model]
	if not entry then
		return nil
	end

	local targetIdOrName = entry.targetIdOrName

	if targetIdOrName == "SpawnPoint" then
		return "SpawnPoint"
	end

	if targetIdOrName == "Lith" then
		return "Lith"
	end

	if typeof(targetIdOrName) == "Instance" and targetIdOrName:IsA("Model") then
		if targetIdOrName.Parent then
			return targetIdOrName
		else
			return nil
		end
	end

	local targetModel = utilMod.GetModelByIDorName(targetIdOrName)
	if targetModel and targetModel.Parent then
		return targetModel
	end

	return nil
end

function pathMod.PathfindToPosition(model: Model, targetPosition: Vector3, targetIdOrName: TargetIdentifier): boolean
	if activePaths[model] then
		return false
	end
	local connection: RBXScriptConnection? = nil
	addModel(model, targetIdOrName, connection)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
	if not humanoid or not rootPart then
		activePaths[model] = nil
		return false
	end

	local lastpos: Vector3 = rootPart.Position
	local startTick: number = time()

	local pathTable = statsMod.Pathing[utilMod.customTrim(model.Name)]
	local path = pathfindingService:CreatePath(pathTable)

	local targetPosOnFloor = targetPosition
		and Vector3.new(targetPosition.X, utilMod.DistancetoGround(targetPosition), targetPosition.Z)
	local success, err = pcall(function()
		path:ComputeAsync(rootPart.Position, targetPosOnFloor)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		activePaths[model] = nil
		return false
	end

	local waypoints = path:GetWaypoints()
	local currentWaypointIndex: number = 1
	-- for _, waypoint in ipairs(waypoints) do
	-- 	utilMod.TempMarker(waypoint.Position)
	-- end
	--utilMod.TempMarker(targetPosition)

	local Recalculate = time() + 1
	connection = RunService.Heartbeat:Connect(function()
		if not activePaths[model] then
			if connection then
				print("disconnect1")
				connection:Disconnect()
			end
			return
		end

		if not model.Parent then
			if connection then
				print("disconnect2")
				connection:Disconnect()
			end
			activePaths[model] = nil
			return
		end

		if currentWaypointIndex > #waypoints then
			if connection then
				print("disconnect3")
				connection:Disconnect()
			end
			activePaths[model] = nil
			return
		end

		-- Stuck detection
		if time() - startTick > 1 then
			startTick = time()
			if utilMod.GetDistance(lastpos, rootPart.Position) < 1 then
				if connection then
					print("stuck disconnect")
					connection:Disconnect()
				end
				activePaths[model] = nil
				return
			else
				lastpos = rootPart.Position
			end
		end

		-- Re-path if target moved too far (for mobile targets)
		if targetIdOrName ~= "SpawnPoint" and targetIdOrName ~= "Lith" and time() > Recalculate then
			Recalculate = time() + 0.5
			local newPos = pathMod.GetTargetPet(model, targetIdOrName, Random.new(time()))
			local newPosOnFloor = newPos and Vector3.new(newPos.X, utilMod.DistancetoGround(newPos), newPos.Z)
			local dis = newPos and utilMod.GetDistance(newPos, targetPosition)
			if dis and dis > 2 then
				if connection then
					--print("disconnect5 within pathmod heartbeat")
					connection:Disconnect()
				end
				activePaths[model] = nil
				task.spawn(function()
					task.wait()
					local random: Random = Random.new(time())
					pathMod.PathfindToPosition(model, newPosOnFloor, targetIdOrName)
				end)
				return
			end
		end

		local waypoint = waypoints[currentWaypointIndex]
		local rootpartatground =
			Vector3.new(rootPart.Position.X, utilMod.DistancetoGround(rootPart.Position), rootPart.Position.Z)
		local distanceToWaypoint = utilMod.GetDistance(rootpartatground, waypoint.Position)

		if distanceToWaypoint < 1 and currentWaypointIndex == #waypoints then
			currentWaypointIndex += 1
		elseif distanceToWaypoint < 3 and currentWaypointIndex ~= #waypoints then
			currentWaypointIndex += 1
		else
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			utilMod.TempMarker(waypoint.Position)
			humanoid:MoveTo(waypoint.Position)
		end
	end)

	-- Update the stored connection
	if activePaths[model] then
		activePaths[model].connection = connection
	end

	-- Cleanup on destruction
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			if connection then
				connection:Disconnect()
			end
			activePaths[model] = nil
		end
	end)

	return true
end

function pathMod.IsPathActive(model: Model): boolean
	return activePaths[model] ~= nil
end

function pathMod.ShortCircuitTravel(model: Model)
	if activePaths[model] then
		if activePaths[model].connection then
			activePaths[model].connection:Disconnect()
		end
		activePaths[model] = nil
	end
end

local petOffset: { string: Vector3 } = {}

local function GetRandomPos(model: Model, random: Random)
	local counter = 0
	local finished = false
	local randomOffset = nil
	while not finished do
		counter += 1
		randomOffset = Vector3.new(random:NextInteger(-12, 12), 0, random:NextInteger(5, 15))
		local good = true
		for key, pos in pairs(petOffset) do
			if utilMod.GetDistance(randomOffset, pos) < 5 then
				good = false
			end
		end
		if good then
			finished = true
		end
	end

	petOffset[model.Name] = randomOffset
end

function pathMod.GetTargetPet(model: Model, targetIdOrName: number | string, random: Random): Vector3?
	local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	if not hrp then
		return nil
	end

	local owningId = model:GetAttribute("OwnedBy")
	if owningId == targetIdOrName then
		local player = game.Players:GetPlayerByUserId(owningId)
		if not player or not player.Character then
			return nil
		end

		local playerhrp = player.Character:FindFirstChild("HumanoidRootPart")
			or player.Character:FindFirstChildWhichIsA("BasePart")
		if not playerhrp then
			return nil
		end

		local distance = utilMod.GetDistance(playerhrp.Position, hrp.Position)
		if distance >= 30 then
			if not petOffset[model.Name] then
				GetRandomPos(model, random)
			end
			local direction = -playerhrp.CFrame.LookVector
			local direction1 = playerhrp.CFrame.RightVector
			local targetPosition = playerhrp.Position
				+ (direction * petOffset[model.Name].Z)
				+ (direction1 * petOffset[model.Name].X)
			--utilMod.TempMarker(targetPosition)
			return targetPosition
		end
		return nil
	end

	local enemyTarget = utilMod.GetModelByIDorName(targetIdOrName)
	if not enemyTarget then
		return nil
	end

	local enemyhrp = enemyTarget:FindFirstChild("HumanoidRootPart") or enemyTarget:FindFirstChildWhichIsA("BasePart")
	if not enemyhrp then
		return nil
	end

	if not combatMod.AcceptableDistanceToOpponent(model, enemyTarget) then
		local enemyTable = combatMod.GetStatsSafelyForPlrorNpc(enemyTarget)
		local distanceForAttacker = ((enemyTable and enemyTable.distanceForAttacker) or 4) - 2
		local direction = (enemyhrp.Position - hrp.Position).Unit
		local targetPosition = enemyhrp.Position - direction * distanceForAttacker
		--targetPosition = Vector3.new(targetPosition.X, utilMod.DistancetoGround(targetPosition) , targetPosition.Z)
		return targetPosition
	end

	return nil
end

function pathMod.GetTargetLith(pos: Vector3): Vector3?
	for i = 1, 50 do
		local distance = 10 + math.random() * 5
		local angle = math.random() * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local candidate = pos + offset
		local testPos = Vector3.new(candidate.X, pos.Y + 10, candidate.Z)
		local groundY = utilMod.DistancetoGround(testPos)

		if groundY then
			return Vector3.new(candidate.X, groundY, candidate.Z)
		end
	end

	for i = 1, 30 do
		local distance = 8 + math.random() * 4
		local angle = math.random() * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local candidate = pos + offset
		local testPos = Vector3.new(candidate.X, pos.Y + 10, candidate.Z)
		local groundY = utilMod.DistancetoGround(testPos)

		if groundY and groundY > -5 and groundY < 5 then
			return Vector3.new(candidate.X, groundY, candidate.Z)
		end
	end

	return nil
end

return pathMod :: PathMod
