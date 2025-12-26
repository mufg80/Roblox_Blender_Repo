-- --!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local utilMod = {}

export type UtilMod = {
	GetPlayerFromCharacter: (model: Model?) -> Player?,
	GetOwnerIdFromModel: (model: Model) -> number?,
	GetId: (model: Model) -> string?,
	GetPlayerLevel: (plr: Player) -> number,
	IsMobHealer: (model: Model) -> boolean,
	IsAlly: (sourceModel: Model, targetModel: Model) -> boolean,
	GetAcceptableDistanceForCaster: (combatTargetModel: Model?, model: Model) -> boolean,
	GetRootPart: (subject: Instance?) -> BasePart?,
	GetPosition: (subject: Instance | Vector3) -> Vector3?,
	GetDistance: (a: Instance | Vector3, b: Instance | Vector3) -> number?,
	GetPartyMembers: (model: Instance) -> { Player: Player, Character: Model?, pets: { Model } },
	GetModelByIDorName: (idOrName: string | number) -> Model?,
	IsPlayer: (instance: Instance) -> boolean,
	RemoveSpaces: (input: string) -> string,
	SetFlagsForMoving: (model: Model) -> (),
	SetFlagsForCombat: (model: Model) -> (),
	SetFlagsForDeath: (model: Model) -> (),
	SetFlagsForIdle: (model: Model) -> (),
	TempMarker: (position: Vector3) -> (),
	HexToColor3: (hex: string) -> Color3,
	SpinToOwner: (model: Model, hrp: BasePart, ownerInstance: Model, rng: Random?) -> (),
	CreatureCastTime: (name: string) -> number,
	DistancetoGround: (position: Vector3) -> number?,
	IsGroundSafe:(position: Vector3) -> boolean,
	FindClearSpawnPoint: (player: Player, distance: number) -> Vector3?,
	IsPlayerCharacter: (model: Model?) -> boolean,
	createCustomExplosion: (position: Vector3, visualSize: number, lifetime: number, color: Color3) -> (),

	uniqueName: (baseName: string) -> string,
	GetSeedFromName: (name: string, useTime: boolean?) -> number,

	GetClosestPlayerSkipAlly: (char: Model) -> Model?,
	GetClosestModelSkipAllyPets: (playerChar: Model, folderName: "Pets" | "Ferals") -> Model?,
	GetEnemyModelsWithinRange: (char: Model, range: number) -> { Model },
	GetEnemyPlayersWithinRange: (char: Model, range: number) -> { Model },
	IsEnemyInRange: (char: Model, range: number) -> boolean,
	GetAttribute: (model: Model?, attr: string) -> any,
	SetAttribute: (model: Model?, attr: string, value: any) -> (),
	MyPets: (char: Model) -> { Model },

	CopyStatsToFolder: (target: Instance, stats: { [string]: any }, folderName: string?) -> Folder,
	GetStatsFromFolder: (instance: Instance, folderName: string?) -> { [string]: any },

	ApplyThreat: (attacker: Model, target: Model, threatAmount: number) -> boolean,

	GetOpposingPetsWithinRange: (char: Model, range: number, userId: number) -> { Model },

	GetCharactersModelsWithinRange: (pos: Vector3, range: number) -> { Model },

	customTrim: (input: string?) -> string,
}

-- ────────────────────────────────────────────────────────────────
-- Caches for fast lookups
-- ────────────────────────────────────────────────────────────────

local characterCache = {} -- [Model] = true (is character)
local playerFromCharacter = {} -- [Model] = Player (fast GetPlayerFromCharacter replacement)
local idStringCache = {}
local function updateCharacterCache()
	characterCache = {}
	playerFromCharacter = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			characterCache[player.Character] = true
			playerFromCharacter[player.Character] = player
			idStringCache[player.Character] = tostring(player.UserId)
		end
	end
end

-- Initial population
updateCharacterCache()

-- Update on player/character changes
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		characterCache[char] = true
		playerFromCharacter[char] = player
		idStringCache[char] = tostring(player.UserId)
	end)
	player.CharacterRemoving:Connect(function(char)
		characterCache[char] = nil
		playerFromCharacter[char] = nil
		idStringCache[char] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		characterCache[player.Character] = nil
		playerFromCharacter[player.Character] = nil
		idStringCache[player.Character] = nil
	end
end)

function utilMod.GetId(model: Model): string?
	if not model then
		warn("Should not reach me.")
		return nil
	end
	if idStringCache[model] then
		return idStringCache[model]
	else
		return model.Name
	end
end

-- also returns number if model is player.character
function utilMod.GetOwnerIdFromModel(model: Model): number?
	if not model then
		warn("Should not reach me.")
		return nil
	end
	local ownedId = utilMod.GetAttribute(model, "OwnedBy")
	if ownedId and typeof(ownedId) == "number" then
		local plr = game.Players:GetPlayerByUserId(ownedId)
		if plr then
			return plr.UserId
		end
	end
	local plrisowner = utilMod.GetPlayerFromCharacter(model)
	if plrisowner and plrisowner.UserId then
		return plrisowner.UserId
	end
	return nil
end
-- ────────────────────────────────────────────────────────────────
-- IsPlayerCharacter – now uses cache
-- ────────────────────────────────────────────────────────────────

function utilMod.IsPlayerCharacter(instance: Model?): boolean
	if not instance or not instance:IsA("Model") then
		return false
	end
	return characterCache[instance] == true
end

-- ────────────────────────────────────────────────────────────────
-- GetPlayerFromCharacter – fast cached version
-- ────────────────────────────────────────────────────────────────

function utilMod.GetPlayerFromCharacter(model: Model?): Player?
	if not model or not model:IsA("Model") then
		return nil
	end
	return playerFromCharacter[model]
end

function utilMod.CreatureCastTime(name: string): number
	if not name then
		warn("Should not reach me.")
		return 1
	end
	local level = statsMod.creatureStats[name] and statsMod.creatureStats[name].level

	if level then
		return level or 4 / 2
	end
	return 1
end

-- ────────────────────────────────────────────────────────────────
-- Safe SetAttribute – supports Player or Model
-- ────────────────────────────────────────────────────────────────

--- Sets an attribute.
--- - If `instance` is a Player → stores on the Player
--- - If `instance` is a Model that is a character → stores on its Player
--- - Otherwise → stores directly on the Model
---
--- @param instance Player | Model?
--- @param attr string
--- @param value any
function utilMod.SetAttribute(instance: Player | Model?, attr: string, value: any)
	if not instance then
		return -- silent fail
	end

	if instance:IsA("Player") then
		instance:SetAttribute(attr, value)
		return
	end

	if instance:IsA("Model") then
		if utilMod.IsPlayerCharacter(instance) then
			local player = utilMod.GetPlayerFromCharacter(instance)
			if player then
				player:SetAttribute(attr, value)
				return
			end
			-- Rare fallback: player disconnected mid-frame
			warn("SetAttribute: Character without Player:", instance.Name)
		end

		-- Default: store on the model itself
		instance:SetAttribute(attr, value)
		return
	elseif instance:IsA("Part") then
		instance:SetAttribute(attr, value)
		return
	elseif instance:IsA("Humanoid") then
		instance:SetAttribute(attr, value)
		return
	end

	warn("SetAttribute: Unsupported instance type:", instance.ClassName)
end

-- ────────────────────────────────────────────────────────────────
-- Safe GetAttribute – supports Player or Model
-- ────────────────────────────────────────────────────────────────

--- Gets an attribute.
--- - If `instance` is a Player → reads from the Player
--- - If `instance` is a Model that is a character → reads from its Player
--- - Otherwise → reads from the Model
---
--- @param instance Player | Model?
--- @param attr string
--- @return any
function utilMod.GetAttribute(instance: Player | Model?, attr: string): any
	if not instance then
		return nil
	end

	if instance:IsA("Player") then
		return instance:GetAttribute(attr)
	end

	if instance:IsA("Model") then
		if utilMod.IsPlayerCharacter(instance) then
			local player = utilMod.GetPlayerFromCharacter(instance)
			if player then
				return player:GetAttribute(attr)
			end
			-- Rare fallback
			warn("GetAttribute: Character without Player:", instance.Name)
		end

		-- Default: read from model
		return instance:GetAttribute(attr)
	elseif instance:IsA("Part") then
		return instance:GetAttribute(attr)
	elseif instance:IsA("Humanoid") then
		return instance:GetAttribute(attr)
	end

	warn("GetAttribute: Unsupported instance type:", instance.ClassName)
	return nil
end
--- Checks if the given instance is a Player's character (i.e. returns true for any character Model).
--- Uses the fast character → player cache for O(1) lookup.
---
--- @param instance Instance?
--- @return boolean
function utilMod.IsPlayer(instance: Instance?): boolean
	if not instance or not instance:IsA("Model") then
		return false
	end

	-- Fast cache check
	return playerFromCharacter[instance] ~= nil
end

-- Sets flags for a model in the "Moving" state
-- @param model Model
function utilMod.SetFlagsForMoving(model: Model)
	if utilMod.GetAttribute(model, "IsMoving") then
		return
	end
	utilMod.SetAttribute(model, "IsMoving", true)
	utilMod.SetAttribute(model, "IsIdle", false)
	utilMod.SetAttribute(model, "HasFallen", false)
	utilMod.SetAttribute(model, "InCombat", false)
end

-- Sets flags for a model in the "Combat" state
-- @param model Model
function utilMod.SetFlagsForCombat(model: Model)
	if utilMod.GetAttribute(model, "InCombat") then
		return
	end
	utilMod.SetAttribute(model, "IsMoving", false)
	utilMod.SetAttribute(model, "IsIdle", false)
	utilMod.SetAttribute(model, "HasFallen", false)
	utilMod.SetAttribute(model, "InCombat", true)
end

-- Sets flags for a model in the "Death" state
-- @param model Model
function utilMod.SetFlagsForDeath(model: Model)
	if utilMod.GetAttribute(model, "HasFallen") then
		return
	end
	utilMod.SetAttribute(model, "IsMoving", false)
	utilMod.SetAttribute(model, "IsIdle", false)
	utilMod.SetAttribute(model, "HasFallen", true)
	utilMod.SetAttribute(model, "InCombat", false)
end

-- Sets flags for a model in the "Idle" state
-- @param model Model
function utilMod.SetFlagsForIdle(model: Model)
	if utilMod.GetAttribute(model, "IsIdle") then
		return
	end
	utilMod.SetAttribute(model, "IsMoving", false)
	utilMod.SetAttribute(model, "IsIdle", true)
	utilMod.SetAttribute(model, "HasFallen", false)
	utilMod.SetAttribute(model, "InCombat", false)
	utilMod.SetAttribute(model, "IdleStartTime", time())
end

function utilMod.GetAcceptableDistanceForCaster(combatTargetModel: Model?, model: Model): boolean
	local targetHRP = combatTargetModel and combatTargetModel:FindFirstChild("HumanoidRootPart")
	local myhrp = model and model:FindFirstChild("HumanoidRootPart")
	if not myhrp or not targetHRP then
		return false
	end
	return utilMod.GetDistance(myhrp.Position, targetHRP.Position) < 45
end

function utilMod.IsMobHealer(model: Model): boolean
	local thisMob = utilMod.customTrim(model.Name)
	if thisMob == "Druid" or thisMob == "StoneManaPriest" or thisMob == "MudPriest" then
		return true
	end
	return false
end

function utilMod.GetPlayerLevel(plr: Player): number
	local magictype: any = utilMod.GetAttribute(plr, "Magic")
	if magictype == statsMod.MagicType.Artificer then
		return utilMod.GetAttribute(plr, "ArtificerLevel") or 1
	elseif magictype == statsMod.MagicType.Primordial then
		return utilMod.GetAttribute(plr, "PrimordialLevel") or 1
	elseif magictype == statsMod.MagicType.Nature then
		return utilMod.GetAttribute(plr, "NatureLevel") or 1
	else
		return 1
	end
end

function utilMod.IsAlly(sourceModel: Model, targetModel: Model): boolean
	if not sourceModel or not targetModel then
		return false
	end
	if sourceModel == targetModel then
		return true
	end

	local sourceOwnerId: number? = utilMod.GetOwnerIdFromModel(sourceModel)
	local targetOwnerId: number? = utilMod.GetOwnerIdFromModel(targetModel)

	if not sourceOwnerId or not targetOwnerId then
		return false
	end

	if sourceOwnerId == targetOwnerId then
		return true
	end

	local sourcePlayer: Player? = game.Players:GetPlayerByUserId(sourceOwnerId)
	local targetPlayer: Player? = game.Players:GetPlayerByUserId(targetOwnerId)

	if not sourcePlayer or not targetPlayer then
		return false
	end

	local sourceAllyId: any = utilMod.GetAttribute(sourcePlayer, "AllyId")
	local targetAllyId: any = utilMod.GetAttribute(targetPlayer, "AllyId")

	if typeof(sourceAllyId) == "string" then
		sourceAllyId = (sourceAllyId == "None" or sourceAllyId == "none" or sourceAllyId == "") and nil
			or tonumber(sourceAllyId)
	else
		sourceAllyId = (sourceAllyId == nil or sourceAllyId == 0) and nil or sourceAllyId
	end

	if typeof(targetAllyId) == "string" then
		targetAllyId = (targetAllyId == "None" or targetAllyId == "none" or targetAllyId == "") and nil
			or tonumber(targetAllyId)
	else
		targetAllyId = (targetAllyId == nil or targetAllyId == 0) and nil or targetAllyId
	end

	local sourceSeesTargetAsAlly: boolean = sourceAllyId ~= nil and sourceAllyId == targetOwnerId
	local targetSeesSourceAsAlly: boolean = targetAllyId ~= nil and targetAllyId == sourceOwnerId

	return sourceSeesTargetAsAlly or targetSeesSourceAsAlly
end

function utilMod.GetRootPart(subject: Instance?): BasePart?
	if not subject or not subject.Parent then
		return nil
	end
	return subject:FindFirstChild("HumanoidRootPart")
		or subject:FindFirstChild("Torso")
		or subject:FindFirstChildWhichIsA("BasePart")
end

-- Removes all spaces from the input string
function utilMod.RemoveSpaces(input: string): string
	-- Ensure input is a string (defensive programming)
	if typeof(input) ~= "string" then
		error("RemoveSpaces expected a string, got " .. typeof(input), 2)
	end

	-- Use gsub to replace all spaces (" ") with an empty string
	return string.gsub(input, " ", "")
end

function utilMod.GetPosition(subject: Instance | Vector3): Vector3?
	if typeof(subject) == "Vector3" then
		return subject
	elseif typeof(subject) == "Instance" then
		local root: BasePart? = utilMod.GetRootPart(subject)
		return root and root.Position
	end
	return nil
end

function utilMod.GetDistance(a: Instance | Vector3, b: Instance | Vector3): number?
	local posA: Vector3? = utilMod.GetPosition(a)
	local posB: Vector3? = utilMod.GetPosition(b)
	if not posA or not posB then
		return nil
	end
	return (posA - posB).Magnitude
end

function utilMod.GetModelByIDorName(idOrName: string | number): Model?
	local searchStr: string = tostring(idOrName)

	for _, player: Player in Players:GetPlayers() do
		if player.UserId == idOrName or player.Name == searchStr then
			return player.Character
		end
	end

	local folders: { Folder? } = { Workspace:FindFirstChild("Pets"), Workspace:FindFirstChild("Ferals") }
	for _, folder: Folder? in folders do
		if folder then
			for _, model: Instance in folder:GetChildren() do
				if model.Name == searchStr then
					return model :: Model
				end
			end
		end
	end

	return nil
end

function utilMod.HexToColor3(hex: string): Color3
	hex = hex:gsub("#", "")
	local r: number = tonumber(hex:sub(1, 2), 16) or 0
	local g: number = tonumber(hex:sub(3, 4), 16) or 0
	local b: number = tonumber(hex:sub(5, 6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

function utilMod.TempMarker(position: Vector3): ()
	local marker = Instance.new("Part")
	marker.Name = "TempMarker"
	marker.Size = Vector3.new(1, 1, 1)
	marker.Position = position
	marker.Anchored = true
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(0, 255, 0) -- Bright green for visibility
	marker.Parent = workspace

	task.delay(1, function()
		marker:Destroy()
	end)
end

local spinningConnections = {}
function utilMod.SpinToOwner(model: Model, hrp: BasePart, ownerInstance: Model, rng: Random?): ()
	if not model or not hrp or not ownerInstance then
		warn("should not reach me")
		return
	end
	if spinningConnections[model] then
		return
	end
	if utilMod.GetAttribute(model, "SpinningToOwner") or utilMod.GetAttribute(model, "HasFallen") then
		return
	end
	utilMod.SetAttribute(model, "SpinningToOwner", true)
	task.spawn(function()
		local tHRP: BasePart? = utilMod.GetRootPart(ownerInstance)
		if not tHRP then
			utilMod.SetAttribute(model, "SpinningToOwner", false)
			if spinningConnections[model] then
				spinningConnections[model] = nil
			end
			return
		end

		local direction: Vector3 = Vector3.new(tHRP.Position.X - hrp.Position.X, 0, tHRP.Position.Z - hrp.Position.Z)
		if direction.Magnitude < 0.1 then
			utilMod.SetAttribute(model, "SpinningToOwner", false)
			if spinningConnections[model] then
				spinningConnections[model] = nil
			end
			return
		end

		local targetCFrame: CFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
		local connection: RBXScriptConnection?
		spinningConnections[model] = true
		connection = RunService.Heartbeat:Connect(function(dt: number)
			if not utilMod.GetAttribute(model, "IsIdle") and not utilMod.GetAttribute(model, "InCombat") or not ownerInstance.Parent or not hrp.Parent then
				if connection then
					connection:Disconnect()
				end
				if spinningConnections[model] then
					spinningConnections[model] = nil
				end
				utilMod.SetAttribute(model, "SpinningToOwner", false)
				return
			end

			local alpha: number = math.min(3 * dt, 0.3)
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)
			if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
				hrp.CFrame = targetCFrame
				if connection then
					connection:Disconnect()
				end
				if spinningConnections[model] then
					spinningConnections[model] = nil
				end
				utilMod.SetAttribute(model, "SpinningToOwner", false)
			end
		end)

		task.delay(5, function()
			if connection and connection.Connected then
				connection:Disconnect()
				if spinningConnections[model] then
					spinningConnections[model] = nil
				end
				utilMod.SetAttribute(model, "SpinningToOwner", false)
			end
		end)
	end)
end

function utilMod.DistancetoGround(position: Vector3): number?
	local rayOrigin: Vector3 = position + Vector3.new(0, 500, 0)
	local rayDirection: Vector3 = Vector3.new(0, -10000, 0)

	local params: RaycastParams = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true

	local grounditems: { Instance } = CollectionService:GetTagged("Ground")
	params.FilterDescendantsInstances = grounditems

	local result: RaycastResult? = Workspace:Raycast(rayOrigin, rayDirection, params)

	if result then
		return result.Position.Y
	end
	return nil
end

-- Returns true if there is ground at this position AND it is NOT labeled "Danger"
function utilMod.IsGroundSafe(position: Vector3): boolean
    local rayOrigin = position + Vector3.new(0, 500, 0)
    local rayDirection = Vector3.new(0, -10000, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.IgnoreWater = true

    -- Only consider parts tagged "Ground"
    local groundItems = CollectionService:GetTagged("Ground")
    params.FilterDescendantsInstances = groundItems

    local result = workspace:Raycast(rayOrigin, rayDirection, params)
    if not result then
        return false  -- no ground found
    end

    local hitPart = result.Instance
    if not hitPart:IsA("BasePart") then
        return false  -- hit something strange (shouldn't happen with proper tagging)
    end

    -- Look for PathfindingModifier children
    for _, child in hitPart:GetChildren() do
        if child:IsA("PathfindingModifier") and child.Label == "Danger" then
            return false  -- explicitly marked as danger → unsafe
        end
    end

    -- Ground exists and has no "Danger" modifier
    return true
end

function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?
	if not player.Character then
		return nil
	end
	local root: BasePart? = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local origin: Vector3 = root.Position
	local params: RaycastParams = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	for angle: number = 0, 359, 40 do
		local rad: number = math.rad(angle)
		local dir: Vector3 = Vector3.new(math.cos(rad), 0, -math.sin(rad))
		local target: Vector3 = origin + dir * distance

		local rayOrigin: Vector3 = origin
		local result: RaycastResult? = Workspace:Raycast(rayOrigin, dir * (distance * 1.5), params)

		local rayOrigin1: Vector3 = origin + Vector3.new(0, 4, 0)
		local result1: RaycastResult? = Workspace:Raycast(rayOrigin1, dir * (distance * 1.5), params)

		if not result and not result1 then
			return target
		end
	end
	return nil
end

function utilMod.ShallowTableCopy(t: { [any]: any }): { [any]: any }
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

function utilMod.createCustomExplosion(position: Vector3, visualSize: number, lifetime: number, color: Color3): ()
	local container: Part = Instance.new("Part")
	container.Anchored = true
	container.CanCollide = false
	container.Transparency = 1
	container.Size = Vector3.new(0.5, 0.5, 0.5)
	container.Position = position + Vector3.new(0, 0.5, 0)
	container.Parent = Workspace

	local pe: ParticleEmitter = Instance.new("ParticleEmitter")
	pe.Parent = container

	pe.Texture = "rbxassetid://104995764302392"
	pe.LightEmission = 0.6
	pe.LightInfluence = 1
	pe.Color = ColorSequence.new(color)
	pe.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp

	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0),
	})

	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, visualSize * 0.8),
		NumberSequenceKeypoint.new(1, visualSize * 0.1),
	})
	pe.ZOffset = 0
	pe.Lifetime = NumberRange.new(0.1, lifetime)
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

	task.defer(function()
		pe:Emit(100)
	end)

	Debris:AddItem(container, lifetime)
	task.delay(0.2, function()
		pe.Enabled = false
	end)
end

function utilMod.uniqueName(baseName: string): string
	local highest: number = 0
	for _, folderName: string in { "Pets", "Ferals" } do
		local folder: Folder? = Workspace:FindFirstChild(folderName)
		if folder then
			for _, child: Instance in folder:GetChildren() do
				local num: string? = child.Name:match("^" .. baseName .. "_(%d+)$")
				if num then
					highest = math.max(highest, tonumber(num) or 0)
				end
			end
		end
	end
	return string.format("%s_%03d", baseName, highest + 1)
end

function utilMod.GetSeedFromName(name: string, useTime: boolean?): number
	if not name or name == "" then
		return math.random(1, 2 ^ 30)
	end

	local seed: number = 5381
	for i: number = 1, #name do
		seed = (seed * 33 + string.byte(name, i)) % 0xFFFFFFFF
	end

	seed = bit32.bxor(seed, bit32.rshift(seed, 16))
	seed = (seed * 0x7FE73CE1) % 0xFFFFFFFF
	seed = bit32.bxor(seed, bit32.rshift(seed, 13))
	seed = (seed * 0x5A7D3F15) % 0xFFFFFFFF
	seed = bit32.bxor(seed, bit32.rshift(seed, 16))

	if useTime then
		seed = bit32.bxor(seed, math.floor(time() % 1 * 1e6))
	end

	return seed
end

function utilMod.GetClosestPlayerSkipAlly(char: Model?): Model?
	if not char then
		warn("Should not reach me.")
		return nil
	end
	local myPos: Vector3? = utilMod.GetPosition(char)
	if not myPos then
		return nil
	end

	local closest: Model? = nil
	local bestDist: number = math.huge

	for _, other: Player in Players:GetPlayers() do
		if utilMod.GetAttribute(other, "HasFallen") then
			continue
		end
		if other ~= char and other.Character then
			if utilMod.IsAlly(other.Character, char) then
				continue
			end
			local dist: number? = utilMod.GetDistance(other.Character, myPos)
			if dist and dist < bestDist then
				bestDist = dist
				closest = other.Character
			end
		end
	end
	return closest
end

function utilMod.GetClosestModelSkipAllyPets(playerChar: Model, folderName: "Pets" | "Ferals"): Model?
	if not playerChar:IsA("Model") then
		warn("Should not reach me.")
		return nil
	end
	if folderName ~= "Pets" then
		if folderName ~= "Ferals" then
			warn("Should not reach me.")
			return nil
		end
	end

	local myPos: Vector3? = utilMod.GetPosition(playerChar)
	if not myPos then
		return nil
	end

	local folder: Folder? = Workspace:FindFirstChild(folderName)
	if not folder then
		warn("Should not reach me.")
		return nil
	end

	local closest: Model? = nil
	local bestDist: number = math.huge

	for _, model: Instance in folder:GetChildren() do
		if utilMod.GetAttribute(model, "HasFallen") then
			continue
		end
		if model:IsA("Model") and not utilMod.IsAlly(playerChar, model :: Model) then
			local dist: number? = utilMod.GetDistance(model, myPos)
			if dist and dist < bestDist then
				bestDist = dist
				closest = model :: Model
			end
		end
	end
	return closest
end

-- Returns a table like: { { Player = Player, Character = Model?, pets = {Model} } }
function utilMod.GetPartyMembers(model: Instance): { { Player: Player, Character: Model?, pets: { Model } } }
	local player: Player?

	-- Case 1: The instance is the Player itself
	if model:IsA("Player") then
		player = model

	-- Case 2: The instance is a character Model
	elseif model:IsA("Model") then
		-- First try the standard way (character with Humanoid)
		local test = utilMod.GetPlayerFromCharacter(model)

		if test then
			player = test
		end

		-- If still no player, check if this model is a pet with the OwnedBy attribute
		if not player then
			local ownedByUserId = utilMod.GetAttribute(model, "OwnedBy")
			if typeof(ownedByUserId) == "number" then
				player = Players:GetPlayerByUserId(ownedByUserId)
			end
		end
	else
		error("GetPartyMembers: Expected Player or Model instance, got " .. model.ClassName)
	end

	-- If we couldn't find a player at all
	if not player then
		return {}
	end

	-- Get the player's current character (may be nil if not spawned)
	if not player.Character then
		return {}
	end
	local character = player.Character

	-- Get all owned pet models via your existing function
	local petModels = utilMod.MyPets(character) or {}

	-- Return the party table (single entry for this player)
	return {
		Player = player,
		Character = character,
		pets = petModels,
	}
end

function utilMod.GetEnemyModelsWithinRange(char: Model, range: number): { Model }
	if not char or not char:IsA("Model") then
		warn("Should not reach me.")
		return {}
	end
	if not range or range == 0 then
		warn("Should not reach me.")
		return {}
	end

	local result: { Model } = {}

	local myPos: Vector3? = utilMod.GetPosition(char)
	if not myPos then
		warn("Should not reach me.")
		return result
	end

	for _, folderName: string in { "Pets", "Ferals" } do
		local folder: Folder? = Workspace:FindFirstChild(folderName)
		if folder then
			for _, model: Instance in folder:GetChildren() do
				if model:IsA("Model") and not utilMod.IsAlly(char, model :: Model) then
					if utilMod.GetAttribute(model, "HasFallen") then
						continue
					end
					local dist: number? = utilMod.GetDistance(model, myPos)
					if dist and dist <= range then
						table.insert(result, model :: Model)
					end
				end
			end
		end
	end
	return result
end

function utilMod.GetEnemyPlayersWithinRange(char: Model, range: number): { Model }
	if not char or not char:IsA("Model") then
		warn("Should not reach me.")
		return {}
	end
	if not range or range == 0 then
		warn("Should not reach me.")
		return {}
	end

	local result: { Model } = {}
	local myPos: Vector3? = utilMod.GetPosition(char)
	if not myPos then
		warn("Should not reach me.")
		return result
	end

	for _, other: Player in Players:GetPlayers() do
		if utilMod.GetAttribute(other, "HasFallen") then
			continue
		end
		if other and other.Character and other.Character ~= char and not utilMod.IsAlly(char, other.Character) then
			local dist: number? = utilMod.GetDistance(other.Character, myPos)
			if dist and dist <= range then
				table.insert(result, other.Character)
			end
		end
	end
	return result
end

function utilMod.IsEnemyInRange(char: Model, range: number): boolean
	if not char or not char:IsA("Model") then
		warn("Should not reach me.")
		return {}
	end
	if not range or range == 0 then
		warn("Should not reach me.")
		return {}
	end

	local myPos: Vector3? = utilMod.GetPosition(char)
	if not myPos then
		return false
	end

	for _, folderName: string in { "Pets", "Ferals" } do
		local folder: Folder? = Workspace:FindFirstChild(folderName)
		if folder then
			for _, model: Instance in folder:GetChildren() do
				if model:IsA("Model") and not utilMod.IsAlly(char, model :: Model) then
					if utilMod.GetAttribute(model, "HasFallen") then
						continue
					end
					local dist: number? = utilMod.GetDistance(model, myPos)
					if dist and dist <= range then
						return true
					end
				end
			end
		end
	end

	for _, other: Player in Players:GetPlayers() do
		if other and other.Character and other.Character ~= char and not utilMod.IsAlly(char, other.Character) then
			if utilMod.GetAttribute(other, "HasFallen") then
				continue
			end
			local dist: number? = utilMod.GetDistance(other.Character, myPos)
			if dist and dist <= range then
				return true
			end
		end
	end

	return false
end

function utilMod.MyPets(char: Model): { Model }
	if not char:IsA("Model") then
		warn("Should not reach me.")
		return {}
	end
	local user = game.Players:GetPlayerFromCharacter(char)
	if not user then
		return {}
	end
	local userId = user.UserId
	local result: { Model } = {}
	local petsFolder: Folder? = Workspace:FindFirstChild("Pets")
	if not petsFolder then
		return result
	end

	for _, pet: Instance in petsFolder:GetChildren() do
		if pet:IsA("Model") and utilMod.GetAttribute(pet, "OwnedBy") == userId then
			table.insert(result, pet :: Model)
		end
	end
	return result
end

function utilMod.CopyStatsToFolder(target: Instance, stats: { [string]: any }, folderName: string?): Folder
	folderName = folderName or "Data"
	local folder: Folder = target:FindFirstChild(folderName) or Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = target
	folder:ClearAllChildren()

	for name: string, value: any in stats do
		local valueType: string = typeof(value)
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
	local folder: Folder? = instance:FindFirstChild(folderName)
	if not folder then
		return {}
	end

	local stats: { [string]: any } = {}
	for _, child: Instance in folder:GetChildren() do
		if child:IsA("ValueBase") then
			stats[child.Name] = (child :: ValueBase).Value
		end
	end
	return stats
end

function utilMod.ApplyThreat(attacker: Model, target: Model, threatAmount: number): boolean
	if not attacker or not target then
		warn("Should not reach me.")
		return false
	end
	if not attacker:IsA("Model") then
		warn("Should not reach me.")
		return false
	end

	if target:IsA("Player") or game.Players:GetPlayerFromCharacter(target) ~= nil then
		return false
	end

	local attackerid: number | string
	local plr = utilMod.GetPlayerFromCharacter(attacker)
	if plr then
		attackerid = plr.UserId
		if utilMod.IsAlly(attacker, target) then
			return false
		end
	elseif attacker:IsA("Model") then
		if utilMod.IsAlly(attacker, target) then
			return false
		end
		attackerid = attacker.Name
	else
		return false
	end

	local addThreat: BindableEvent? = target:FindFirstChild("AddThreat")
	if addThreat and addThreat:IsA("BindableEvent") then
		addThreat:Fire(attackerid, threatAmount)
		return true
	end
	return false
end

function utilMod.GetOpposingPetsWithinRange(char: Model, range: number, userId: number): { Model }
	if not char or not char:IsA("Model") then
		warn("Should not reach me.")
		return {}
	end
	if not range or typeof(range) ~= "number" or range == 0 then
		warn("Should not reach me.")
		return {}
	end
	local hrp: BasePart? = utilMod.GetRootPart(char)
	if not hrp then
		return {}
	end
	local result: { Model } = {}
	local pets: Folder? = Workspace:FindFirstChild("Pets")
	if not pets then
		return result
	end
	for _, pet: Instance in pets:GetChildren() do
		if pet:IsA("Model") and not utilMod.IsAlly(char, pet :: Model) then
			if utilMod.GetAttribute(pet, "HasFallen") then
				continue
			end
			local petroot: BasePart? = utilMod.GetRootPart(pet)
			if petroot then
				local dist: number? = utilMod.GetDistance(petroot.Position, hrp.Position)
				if dist and dist <= range then
					table.insert(result, pet :: Model)
				end
			end
		end
	end
	return result
end

function utilMod.GetCharactersModelsWithinRange(pos: Vector3, range: number): { Model }
	if not pos or not pos:IsA("Vector3") then
		warn("Should not reach me.")
		return {}
	end
	if not range or not typeof(range) ~= "number" or range == 0 then
		warn("Should not reach me.")
		return {}
	end
	local result: { Model } = {}

	-- Player characters
	for _, player: Player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if utilMod.GetAttribute(player.Character, "HasFallen") then
				continue
			end
			local hrp: BasePart = player.Character.HumanoidRootPart
			if utilMod.GetDistance(pos, hrp.Position) <= range then
				table.insert(result, player.Character)
			end
		end
	end

	-- Pets
	local petsFolder: Folder? = Workspace:FindFirstChild("Pets")
	if petsFolder then
		for _, petModel: Instance in petsFolder:GetChildren() do
			if petModel:IsA("Model") and petModel:FindFirstChild("HumanoidRootPart") then
				if utilMod.GetAttribute(petModel, "HasFallen") then
					continue
				end
				local hrp: BasePart = petModel.HumanoidRootPart
				if utilMod.GetDistance(pos, hrp.Position) <= range then
					table.insert(result, petModel :: Model)
				end
			end
		end
	end

	return result
end

function utilMod.customTrim(input: string?): string
	if typeof(input) ~= "string" then
		return ""
	end
	return input:gsub("_[%w]*$", "")
end

return utilMod :: UtilMod
