local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsService = game:GetService("PhysicsService")
local recyleMod = require(ReplicatedStorage.Shared.recycleMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local spawnMod = {}

local FERAL_GROUP_NAME = "FeralCG"

-- One-time setup (can be called from a server init script or ModuleScript init)
local function ensureFeralCollisionGroup()
	local groups = PhysicsService:GetRegisteredCollisionGroups()
	for _, group in groups do
		if group.name == FERAL_GROUP_NAME then
			return -- already exists
		end
	end

	-- Create the group and make ferals non-collidable with each other
	PhysicsService:RegisterCollisionGroup(FERAL_GROUP_NAME)
	PhysicsService:CollisionGroupSetCollidable(FERAL_GROUP_NAME, FERAL_GROUP_NAME, false)

	-- Optional: also make ferals collide normally with players & player-owned pets
	-- (default behavior is already collide unless you set otherwise)
	-- If you want ferals to pass through players too, uncomment:
	-- PhysicsService:CollisionGroupSetCollidable(FERAL_GROUP_NAME, "Default", false)
	-- or use your per-player group names if you have them
end

-- Main function – call this for each feral/NPC model you spawn
local function setFeralCollisionGroup(model: Model)
	if model.Name == "Dervish" or model.Name == "FeralDervish" then return end
	if not model or not model:IsA("Model") then
		warn("setFeralCollisionGroup: Expected a Model, got", model and model.ClassName)
		return
	end

	-- Ensure the group exists (safe to call multiple times)
	ensureFeralCollisionGroup()

	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
			descendant.CollisionGroup = FERAL_GROUP_NAME
			count += 1
		end
	end

	if count == 0 then
		warn("setFeralCollisionGroup: No BaseParts/MeshParts found in model", model:GetFullName())
	end

	-- Optional debug
	-- print("Applied FeralCG to", count, "parts in", model.Name)
end

-- Feral spawning
local feralSpawnPoints = workspace:WaitForChild("FeralSpawnPoints"):GetChildren()

local function spawnFeral()
	if #feralSpawnPoints == 0 then
		return
	end

	local rand = math.random(1, #feralSpawnPoints)
	local point = feralSpawnPoints[rand]

	local creature
	if recyleMod.CheckIfExistsFeral("FeralArtifactGuardian") then
		creature = recyleMod.ReturnFeral("FeralArtifactGuardian")
	else
		local template = ServerStorage.FeralEntities:FindFirstChild("FeralGiantAmoeba")
		--local templates = ServerStorage.FeralEntities:GetChildren()

		-- if not templates then
		-- 	return
		-- end
		-- coatarms, flyinggargoyle, grandpo, litheater, stonemanapriest, 
		--local randomized = math.random(23,23)
		--local template = templates[randomized]
		creature = template:Clone()
		utilMod.InitNPC(creature)
		creature.Name = utilMod.uniqueName(creature.Name)
		utilMod.SetAttribute(creature, "OwnedBy", "None")
		for i, val in ipairs(workspace:FindFirstChild("FeralSpawnPoints"):GetChildren()) do
			if i < 6 then
				local attr = "SpawnChoice_" .. tostring(i)
				utilMod.SetAttribute(creature, attr, val.Position)
			end
		end
		utilMod.SetAttribute(creature, "StationaryStatus", "StationaryTraveler")
	end
	setFeralCollisionGroup(creature)
	creature.Parent = workspace:WaitForChild("Ferals")

	local height = statsMod.creatureStats.ArtifactGuardian.height
	local offsetHeight = height - point.Position.Y
	local offsetCFrame = CFrame.new(point.Position.X, offsetHeight, point.Position.Z)

	local creatureHRP = creature:FindFirstChild("HumanoidRootPart")
	if creatureHRP then
		creatureHRP.CFrame = offsetCFrame
	else
		warn("Feral missing HRP:", creature.Name)
	end
end

-- Spawn initial ferals if none exist
task.spawn(function()
	while true do
		task.wait(1)
		local ferals = workspace:FindFirstChild("Ferals")
		if ferals and #ferals:GetChildren() < 4 then
			spawnFeral()
		end
		task.wait(10)
	end
end)

return spawnMod
