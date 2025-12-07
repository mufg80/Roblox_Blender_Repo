--!strict
-- ReplicatedStorage.Shared.utilMod
-- Core utility functions used across combat, AI, spawning, and visuals

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local utilMod = {}

--==============================================================================
-- Returns the primary part used for positioning (HRP > Torso > any BasePart)
--==============================================================================
function utilMod.GetRootPart(subject: Instance?): BasePart?
	if not subject or not subject.Parent then
		return nil
	end
	return subject:FindFirstChild("HumanoidRootPart")
		or subject:FindFirstChild("Torso")
		or subject:FindFirstChildWhichIsA("BasePart")
end

--==============================================================================
-- Safely extracts a world position from an Instance or raw Vector3
-- Returns nil if impossible
--==============================================================================
function utilMod.GetPosition(subject: Instance | Vector3): Vector3?
	if typeof(subject) == "Vector3" then
		return subject
	elseif typeof(subject) == "Instance" then
		local root = utilMod.GetRootPart(subject)
		return root and root.Position
	end
	return nil
end

--==============================================================================
-- Returns distance between two subjects (Instance or Vector3)
-- Returns nil if either subject has no valid position
-- Replaces old GetMagnitude + GetMagnitudeHelper
--==============================================================================
function utilMod.GetDistance(a: Instance | Vector3, b: Instance | Vector3): number?
	local posA = utilMod.GetPosition(a)
	local posB = utilMod.GetPosition(b)
	if not posA or not posB then
		return nil
	end
	return (posA - posB).Magnitude
end

--==============================================================================
-- Finds a model by name (pets) or UserId (players)
-- Used for targeting by name/ID from UI or abilities
--==============================================================================
function utilMod.GetModelByIDorName(idOrName: string | number): Model?
	local searchStr = tostring(idOrName)

	-- Check player characters by UserId or Name
	for _, player in Players:GetPlayers() do
		if player.UserId == idOrName or player.Name == searchStr then
			return player.Character
		end
	end

	-- Check pets and ferals by Name
	local pets = Workspace:FindFirstChild("Pets")
	local ferals = Workspace:FindFirstChild("Ferals")

	for _, folder in { pets, ferals } do
		if folder then
			for _, model in folder:GetChildren() do
				if model.Name == searchStr then
					return model
				end
			end
		end
	end

	return nil
end

--==============================================================================
-- Simple, reliable player check
-- Replaces old loop-based version
--==============================================================================
function utilMod.IsPlayer(instance: Instance): boolean
	return Players:GetPlayerFromCharacter(instance) ~= nil
end

--==============================================================================
-- State flag helpers (used by AI state machines)
--==============================================================================
function utilMod.SetFlagsForMoving(model: Model)
	model:SetAttribute("IsMoving", true)
	model:SetAttribute("IsIdle", false)
	model:SetAttribute("HasFallen", false)
	model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForCombat(model: Model)
	model:SetAttribute("IsMoving", false)
	model:SetAttribute("IsIdle", false)
	model:SetAttribute("HasFallen", false)
	model:SetAttribute("InCombat", true)
end

function utilMod.SetFlagsForDeath(model: Model)
	model:SetAttribute("IsMoving", false)
	model:SetAttribute("IsIdle", false)
	model:SetAttribute("HasFallen", true)
	model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForIdle(model: Model)
	model:SetAttribute("IsMoving", false)
	model:SetAttribute("IsIdle", true)
	model:SetAttribute("HasFallen", false)
	model:SetAttribute("InCombat", false)
	model:SetAttribute("IdleStartTime", tick())
end

--==============================================================================
-- Converts hex string (#RRGGBB or RRGGBB) to Color3
--==============================================================================
function utilMod.HexToColor3(hex: string): Color3
	hex = hex:gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) or 0
	local g = tonumber(hex:sub(3, 4), 16) or 0
	local b = tonumber(hex:sub(5, 6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

--==============================================================================
-- Smoothly rotates model to face target (combat facing)
--==============================================================================
function utilMod.SpinToTargetInCombat(model: Model, targetModel: Model, lerpAlpha: number?)
	if not model or not targetModel then
		return
	end
	lerpAlpha = lerpAlpha or 0.3

	local hrp = utilMod.GetRootPart(model)
	local targetRoot = utilMod.GetRootPart(targetModel)
	if not hrp or not targetRoot then
		return
	end

	local direction = Vector3.new(targetRoot.Position.X - hrp.Position.X, 0, targetRoot.Position.Z - hrp.Position.Z)

	if direction.Magnitude > 0.1 then
		local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
		hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, lerpAlpha)
	end
end

--==============================================================================
-- Idle fidget spin toward owner (natural pet behavior)
--==============================================================================
function utilMod.IdleSpinToOwner(model: Model, ownerModel: Model)
	if not model or not ownerModel or not model:GetAttribute("IsIdle") then
		return
	end
	if model:GetAttribute("CanIdleSpin") == false then
		return
	end
	model:SetAttribute("CanIdleSpin", false)

	task.spawn(function()
		local hrp = utilMod.GetRootPart(model)
		local ownerRoot = utilMod.GetRootPart(ownerModel)
		if not hrp or not ownerRoot then
			model:SetAttribute("CanIdleSpin", true)
			return
		end

		local toOwner = Vector3.new(ownerRoot.Position.X - hrp.Position.X, 0, ownerRoot.Position.Z - hrp.Position.Z)
		if toOwner.Magnitude < 0.3 then
			model:SetAttribute("CanIdleSpin", true)
			return
		end

		local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + toOwner)
		local connection: RBXScriptConnection?

		connection = RunService.Heartbeat:Connect(function(dt)
			if not model:GetAttribute("IsIdle") or not ownerModel.Parent then
				if connection then
					connection:Disconnect()
				end
				model:SetAttribute("CanIdleSpin", true)
				return
			end

			local alpha = math.min(4 * dt, 1)
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

			if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
				hrp.CFrame = targetCFrame
				if connection then
					connection:Disconnect()
				end
			end
		end)

		local delayTime = Random.new():NextInteger(8, 15)
		task.delay(delayTime, function()
			if model.Parent and model:GetAttribute("IsIdle") then
				model:SetAttribute("CanIdleSpin", true)
			end
		end)
	end)
end

--==============================================================================
-- Legacy spin function (kept for compatibility, uses new GetRootPart)
--==============================================================================
function utilMod.SpinToOwner(model: Model, hrp: BasePart, ownerInstance: Model, rng: Random?, spinCooldown: boolean?)
	if spinCooldown == true or model:GetAttribute("SpinningToOwner") then
		return
	end
	model:SetAttribute("SpinningToOwner", true)

	task.spawn(function()
		local tHRP = utilMod.GetRootPart(ownerInstance)
		if not tHRP then
			model:SetAttribute("SpinningToOwner", false)
			return
		end

		local direction = Vector3.new(tHRP.Position.X - hrp.Position.X, 0, tHRP.Position.Z - hrp.Position.Z)
		if direction.Magnitude < 0.1 then
			model:SetAttribute("SpinningToOwner", false)
			return
		end

		local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
		local connection: RBXScriptConnection?

		connection = RunService.Heartbeat:Connect(function(dt)
			if not model:GetAttribute("IsIdle") or not ownerInstance.Parent or not hrp.Parent then
				if connection then
					connection:Disconnect()
				end
				model:SetAttribute("SpinningToOwner", false)
				return
			end

			local alpha = math.min(12 * dt, 1)
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

			if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
				hrp.CFrame = targetCFrame
				if connection then
					connection:Disconnect()
				end
				model:SetAttribute("SpinningToOwner", false)
			end
		end)

		task.delay(5, function()
			if connection and connection.Connected then
				connection:Disconnect()
				model:SetAttribute("SpinningToOwner", false)
			end
		end)
	end)
end

--==============================================================================
-- Raycast down to find ground Y position (ignores characters)
--==============================================================================
function utilMod.DistancetoGround(position: Vector3): number?
	local rayOrigin = position + Vector3.new(0, 5, 0)
	local rayDirection = Vector3.new(0, -10000, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace.Pets, Workspace.Ferals, Players }
	params.IgnoreWater = true

	local result = Workspace:Raycast(rayOrigin, rayDirection, params)
	return result and result.Position.Y
end

--==============================================================================
-- Finds a clear spawn point around player (40° steps)
--==============================================================================
function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?
	if not player.Character then
		return nil
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local origin = root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	for angle = 0, 359, 40 do
		local rad = math.rad(angle)
		local dir = Vector3.new(math.cos(rad), 0, -math.sin(rad))
		local target = origin + dir * distance

		local rayOrigin = origin + Vector3.new(0, 0, 0)
		local result = Workspace:Raycast(rayOrigin, dir * (distance * 1.5), params)

		local rayOrigin1 = origin + Vector3.new(0, 4, 0)
		local result1 = Workspace:Raycast(rayOrigin1, dir * (distance * 1.5), params)

		if not result and not result1 then
			return target
		end
	end
	return nil
end


function utilMod.createCustomExplosion(position: Vector3, visualSize: number, lifetime: number, color: Color3)
	local container = Instance.new("Part")
	container.Anchored = true
	container.CanCollide = false
	container.Transparency = 1
	container.Size = Vector3.new(0.5, 0.5, 0.5)
	container.Position = position + Vector3.new(0, 0.5, 0)
	container.Parent = workspace

	

	local pe = Instance.new("ParticleEmitter")
	pe.Parent = container

	pe.Texture = "rbxassetid://104995764302392"
	pe.LightEmission = 0.6

	pe.LightInfluence = 1
	pe.Color = ColorSequence.new(color)
	pe.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	
	pe.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	}
	pe.Squash = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1,0 )
	}
	
	pe.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, visualSize * 0.8),
		NumberSequenceKeypoint.new(1, visualSize * 0.1)
	}
	pe.ZOffset = 0
	pe.Lifetime = NumberRange.new(0.1, lifetime) -- slightly longer
	pe.Rate = 500
	pe.Speed = NumberRange.new(5, 6)
	pe.SpreadAngle = Vector2.new(45, 45)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Enabled = true
	pe.Rotation = NumberRange.new(-45, 45)
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.ShapePartial = 1

	-- Emit after initialization
	task.defer(function()
		pe:Emit(100)
	end)

	game.Debris:AddItem(container, lifetime)
	task.delay(0.2, function()
		pe.Enabled = false
	end)
end

--==============================================================================
-- Generates unique pet name: "FireWolf_001", "FireWolf_002", etc.
--==============================================================================
function utilMod.uniqueName(baseName: string): string
	local highest = 0
	for _, folderName in { "Pets", "Ferals" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, child in folder:GetChildren() do
				local num = child.Name:match("^" .. baseName .. "_(%d+)$")
				if num then
					highest = math.max(highest, tonumber(num) or 0)
				end
			end
		end
	end
	return string.format("%s_%03d", baseName, highest + 1)
end

--==============================================================================
-- Deterministic seed from name (used for pet appearance variation)
--==============================================================================
function utilMod.GetSeedFromName(name: string, useTime: boolean?): number
	if not name or name == "" then
		return math.random(1, 2 ^ 30)
	end

	local seed = 5381
	for i = 1, #name do
		seed = (seed * 33 + string.byte(name, i)) % 0xFFFFFFFF
	end

	seed = bit32.bxor(seed, bit32.rshift(seed, 16))
	seed = (seed * 0x7FE73CE1) % 0xFFFFFFFF
	seed = bit32.bxor(seed, bit32.rshift(seed, 13))
	seed = (seed * 0x5A7D3F15) % 0xFFFFFFFF
	seed = bit32.bxor(seed, bit32.rshift(seed, 16))

	if useTime then
		seed = bit32.bxor(seed, math.floor(tick() % 1 * 1e6))
	end

	return seed
end

--==============================================================================
-- Targeting helpers
--==============================================================================
function utilMod.GetClosestPlayer(player: Player): Player?
	if not player.Character then
		return nil
	end
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then
		return nil
	end

	local closest: Player? = nil
	local bestDist = math.huge

	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local dist = utilMod.GetDistance(other.Character, myPos)
			if dist and dist < bestDist then
				bestDist = dist
				closest = other
			end
		end
	end
	return closest
end

function utilMod.GetClosestModelSkipOwnPets(player: Player, folderName: "Pets" | "Ferals"): Model?
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then
		return nil
	end

	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local closest: Model? = nil
	local bestDist = math.huge

	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local ownerId = model:GetAttribute("OwnedBy")
			if folderName ~= "Pets" or (ownerId ~= player.UserId) then
				local dist = utilMod.GetDistance(model, myPos)
				if dist and dist < bestDist then
					bestDist = dist
					closest = model
				end
			end
		end
	end
	return closest
end

function utilMod.GetEnemyModelsWithinRange(player: Player, range: number): { Model }
	local result = {}
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then
		return result
	end

	for _, folderName in { "Pets", "Ferals" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					local ownerId = model:GetAttribute("OwnedBy")
					if folderName ~= "Pets" or (ownerId ~= player.UserId) then
						local dist = utilMod.GetDistance(model, myPos)
						if dist and dist <= range then
							table.insert(result, model)
						end
					end
				end
			end
		end
	end
	return result
end

function utilMod.GetEnemyPlayersWithinRange(player: Player, range: number): { Model }
	local result = {}
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then
		return result
	end

	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local dist = utilMod.GetDistance(other.Character, myPos)
			if dist and dist <= range then
				table.insert(result, other.Character)
			end
		end
	end
	return result
end

function utilMod.MyPets(player: Player): { Model }
	local result = {}
	local petsFolder = Workspace:FindFirstChild("Pets")
	if not petsFolder then
		return result
	end

	for _, pet in petsFolder:GetChildren() do
		if pet:GetAttribute("OwnedBy") == player.UserId then
			table.insert(result, pet)
		end
	end
	return result
end

--==============================================================================
-- Stats → Instance folder serialization
--==============================================================================
function utilMod.CopyStatsToFolder(target: Instance, stats: { [string]: any }, folderName: string?)
	folderName = folderName or "Data"
	local folder = target:FindFirstChild(folderName) or Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = target
	folder:ClearAllChildren()

	for name, value in stats do
		local valueType = typeof(value)
		local obj: any

		if valueType == "number" then
			obj = Instance.new("NumberValue")
		elseif valueType == "string" then
			obj = Instance.new("StringValue")
		elseif valueType == "boolean" then
			obj = Instance.new("BoolValue")
		elseif valueType == "Vector3" then
			obj = Instance.new("Vector3Value")
		elseif valueType == "Color3" then
			obj = Instance.new("Color3Value")
		elseif valueType == "CFrame" then
			obj = Instance.new("CFrameValue")
		else
			warn("[utilMod] Unsupported stat type:", valueType, name)
			continue
		end

		obj.Name = name
		obj.Value = value
		obj.Parent = folder
	end

	return folder
end

function utilMod.GetStatsFromFolder(instance: Instance, folderName: string?): { [string]: any }
	folderName = folderName or "Data"
	local folder = instance:FindFirstChild(folderName)
	if not folder then
		return {}
	end

	local stats = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ValueBase") then
			stats[child.Name] = child.Value
		end
	end
	return stats
end

function utilMod.ApplyThreat(attacker: Model | Player, target: Model | Player, threatAmount: number): boolean
	if not attacker or not target or threatAmount == 0 then
		return false
	end

	if target:IsA("Player") then
		-- return players dont use hatetable
		return false
	elseif not target:IsA("Model") then
		return false
	elseif target:IsA("Model") and game.Players:GetPlayerFromCharacter(target) ~= nil then
		return false
	end

	local attackerid = nil
	if attacker:IsA("Player") then
		attackerid = attacker.UserId
	elseif attacker:IsA("Model") then
		attackerid = attacker.Name
	else
		return false
	end

	local addThreat = target:FindFirstChild("AddThreat")
	if addThreat and addThreat:IsA("BindableEvent") then
		addThreat:Fire(attackerid, threatAmount)
		return true
	end
	return false
end

function utilMod.GetOpposingPetsWithinRange(player: Player, range: number, userId: number): { Model }
	local hrp = utilMod.GetRootPart(player.Character)
	if not hrp then
		return {}
	end
	local result = {}
	local pets = game.Workspace:FindFirstChild("Pets")
	for _, pet in pets:GetChildren() do
		if pet:IsA("Model") and pet:GetAttribute("OwnedBy") ~= userId then
			local petroot = utilMod.GetRootPart(pet)
			if not petroot then
				continue
			end
			local dist = utilMod.GetDistance(petroot.Position, hrp.Position)
			if dist and dist <= range then
				table.insert(result, pet)
			end
		end
	end
	return result
end

export type UtilMod = {
	GetRootPart: (subject: Instance?) -> BasePart?,
	GetPosition: (subject: Instance | Vector3) -> Vector3?,
	GetDistance: (a: Instance | Vector3, b: Instance | Vector3) -> number?,

	GetModelByIDorName: (idOrName: string | number) -> Model?,
	IsPlayer: (instance: Instance) -> boolean,

	SetFlagsForMoving: (model: Model) -> (),
	SetFlagsForCombat: (model: Model) -> (),
	SetFlagsForDeath: (model: Model) -> (),
	SetFlagsForIdle: (model: Model) -> (),

	HexToColor3: (hex: string) -> Color3,
	SpinToTargetInCombat: (model: Model, targetModel: Model, lerpAlpha: number?) -> (),
	IdleSpinToOwner: (model: Model, ownerModel: Model) -> (),
	SpinToOwner: (model: Model, hrp: BasePart, ownerInstance: Model, rng: Random?, spinCooldown: boolean?) -> (),

	DistancetoGround: (position: Vector3) -> number?,
	FindClearSpawnPoint: (player: Player, distance: number) -> Vector3?,
	createCustomExplosion: (position: Vector3, visualSize: number, lifetime: number, color: Color3) -> (),
	createColorExplosion: (position: Vector3, visualSize: number, lifetime: number, color: Color3) -> (),
	uniqueName: (baseName: string) -> string,
	GetSeedFromName: (name: string, useTime: boolean?) -> number,

	GetClosestPlayer: (player: Player) -> Player?,
	GetClosestModelSkipOwnPets: (player: Player, folderName: "Pets" | "Ferals") -> Model?,
	GetEnemyModelsWithinRange: (player: Player, range: number) -> { Model },
	GetEnemyPlayersWithinRange: (player: Player, range: number) -> { Model },
	MyPets: (player: Player) -> { Model },

	CopyStatsToFolder: (target: Instance, stats: { [string]: any }, folderName: string?) -> Folder,
	GetStatsFromFolder: (instance: Instance, folderName: string?) -> { [string]: any },
	ApplyThreat: (attacker: Model | Player, target: Model | Player, threatAmount: number) -> boolean,
	GetOpposingPetsWithinRange: (player: Player, range: number, userId: number) -> { Model },
}

return utilMod :: UtilMod
