--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

export type PartyInfo = {
	Player: Player?,
	Character: Model?,
	pets: { Model },
	buildings: { Model },
}

export type UtilMod = {
	LeveltoManaCost: (creaturename: string) -> number,
	customTrim: (input: string?) -> string,
	IsMaxSummoned: (char: Model, name: string) -> boolean,
	GetStatsFromFolder: (instance: Instance, folderName: string?) -> { [string]: any },
	GetId: (model: Model) -> string?,
	GetOwnerIdFromModel: (model: Model) -> number?,
	CopyStatsToFolder: (target: Instance, stats: { [string]: any }, folderName: string?) -> Folder?,
	IsPlayerCharacter: (instance: Model?) -> boolean,
	GetPlayerFromCharacter: (model: Model?) -> Player?,
	IsPlayer: (instance: Instance?) -> boolean,
	ApplyThreat: (attacker: Model, target: Model, threatAmount: number) -> boolean,
	CreatureCastTime: (name: string) -> number,
	getValue: (child: ValueBase) -> any,
	SetAttribute: (instance: Player | Model?, attr: string, value: any) -> (),
	GetAttribute: (instance: Player | Model?, attr: string) -> any,
	ReassignSpawn:(model: Model, spawnPosition: Vector3) -> Vector3,
	SetFlagsForMoving: (model: Model) -> (),
	SetFlagsForCombat: (model: Model) -> (),
	SetFlagsForDeath: (model: Model) -> (),
	SetFlagsForIdle: (model: Model) -> (),

	GetAcceptableDistanceForCaster: (combatTargetModel: Model?, model: Model) -> boolean,
	IsMobHealer: (model: Model) -> boolean,
	InitNPC: (model: Model) -> (),
	GetPlayerLevel: (plr: Player) -> number,
	IsAlly: (sourceModel: Model, targetModel: Model) -> boolean,

	GetRootPart: (subject: Instance?) -> Instance?,
	RemoveSpaces: (input: string) -> string,

	GetPosition: (subject: Instance | Vector3) -> Vector3?,
	GetDistance: (a: Instance | Vector3, b: Instance | Vector3) -> number?,

	GetModelByIDorName: (idOrName: string | number) -> Model?,
	HexToColor3: (hex: string) -> Color3,

	TempMarker: (position: Vector3) -> (),

	SpinToOwner: (model: Model, hrp: BasePart, ownerInstance: Model, rng: Random?) -> (),

	DistancetoGround: (position: Vector3) -> number?,
	IsGroundSafe: (position: Vector3) -> boolean,

	GetPlayerType: (player: Player?) -> string?,
	FindClearSpawnPoint: (player: Player, distance: number) -> Vector3?,

	ShallowTableCopy: (t: { [any]: any }) -> { [any]: any },

	createCustomExplosion: (position: Vector3, visualSize: number, lifetime: number, color: Color3) -> (),

	uniqueName: (baseName: string) -> string,
	GetSeedFromName: (name: string, useTime: boolean?) -> number,

	GetClosestPlayerSkipAlly: (char: Model?) -> Model?,
	GetClosestModelSkipAllyPets: (playerChar: Model, folderName: "Pets" | "Ferals") -> Model?,

	GetPartyMembers: (model: Instance) -> PartyInfo,

	GetEnemyModelsWithinRange: (char: Model, range: number) -> { Model },
	GetEnemyPlayersWithinRange: (char: Model, range: number) -> { Model },
	IsEnemyInRange: (char: Model, range: number) -> boolean,

	MyPets: (char: Model) -> { Model },
	GetCooldown:(model: Model) -> number,
	GetTakeLithLoc:(model: Model, hrp: BasePart) -> Vector3?,
	GetDefendLithLoc:(model: Model, hrp: BasePart) -> Vector3?,
}

local utilMod = {}
--==============================================================================
-- Calculates mana cost for summoning a creature based on its level
--==============================================================================
function utilMod.LeveltoManaCost(creaturename: string): number
	-- Retrieves the creature's stats table (or returns huge if missing)
	local creature = creaturename and statsMod.creatureStats[creaturename]
	if not creature then
		return math.huge
	end

	local tenth = creature.level * 0.1
	return tenth * statsMod.MaxSpellCost
end

function utilMod.IsMaxSummoned(char: Model, name: string): boolean
	-- Check if max is reached
	local maxAmount = statsMod.MaxCreatures[name]
	if maxAmount and maxAmount > 0 then
		local additive: number = utilMod.GetAttribute(char, "Earned_MaxBoost_" .. name) and 1 or 0
		maxAmount = maxAmount + additive
		local mypets = utilMod.MyPets(char)
		local existing = 0
		for _, pet in mypets do
			if pet and pet.Parent and utilMod.customTrim(pet.Name) == name then
				existing += 1
			end
		end
		if existing >= maxAmount then
			return true
		end
	end
	return false
end

function utilMod.GetId(model: Model): string?
	if not model then
		warn("Should not reach me.")
		return nil
	end
	local player = game.Players:GetPlayerFromCharacter(model)
	if player then
		return player.UserId
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

	local player = game.Players:GetPlayerFromCharacter(instance)
	return player ~= nil
end

-- ────────────────────────────────────────────────────────────────
-- GetPlayerFromCharacter – fast cached version
-- ────────────────────────────────────────────────────────────────

function utilMod.GetPlayerFromCharacter(model: Model?): Player?
	if not model or not model:IsA("Model") then
		return nil
	end
	local player = game.Players:GetPlayerFromCharacter(model)
	return player
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
	if not instance or not attr then
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

	local player = game.Players:GetPlayerFromCharacter(instance)
	return player ~= nil
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
	if not myhrp or not targetHRP or not myhrp:IsA("BasePart") or not targetHRP:IsA("BasePart") then
		return false
	end
	return utilMod.GetDistance(myhrp.Position, targetHRP.Position) < 45
end

function utilMod.IsMobHealer(model: Model): boolean
	local thisMob = utilMod.customTrim(model.Name)
	if thisMob == "UnkemptDruid" or thisMob == "StoneManaPriest" or thisMob == "MudPriest" then
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
		if sourceAllyId == "None" or sourceAllyId == "none" or sourceAllyId == "" then
			sourceAllyId = nil
		else
			sourceAllyId = tonumber(sourceAllyId)
		end
	else
		if sourceAllyId == nil or sourceAllyId == 0 then
			sourceAllyId = nil
		end
	end

	if typeof(targetAllyId) == "string" then
		if targetAllyId == "None" or targetAllyId == "none" or targetAllyId == "" then
			targetAllyId = nil
		else
			targetAllyId = tonumber(targetAllyId)
		end
	else
		if targetAllyId == nil or targetAllyId == 0 then
			targetAllyId = nil
		end
	end

	local sourceSeesTargetAsAlly: boolean = sourceAllyId ~= nil and sourceAllyId == targetOwnerId
	local targetSeesSourceAsAlly: boolean = targetAllyId ~= nil and targetAllyId == sourceOwnerId

	return sourceSeesTargetAsAlly or targetSeesSourceAsAlly
end

function utilMod.GetRootPart(subject: Instance?): Instance?
	if not subject or not subject.Parent then
		return nil
	end
	if subject:IsA("Model") then
		return subject:FindFirstChild("HumanoidRootPart")
			or subject:FindFirstChild("Torso")
			or subject:FindFirstChildWhichIsA("BasePart")
	end
	return nil
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
		local root: Instance? = utilMod.GetRootPart(subject)
		if root and root:IsA("BasePart") then
			return root.Position
		end
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
		local tHRP: Instance? = utilMod.GetRootPart(ownerInstance)
		if not tHRP then
			utilMod.SetAttribute(model, "SpinningToOwner", false)
			if spinningConnections[model] then
				spinningConnections[model] = nil
			end
			return
		end
		local direction: Vector3 = nil
		if tHRP and tHRP:IsA("BasePart") then
			direction = Vector3.new(tHRP.Position.X - hrp.Position.X, 0, tHRP.Position.Z - hrp.Position.Z)
		end

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
			if
				not utilMod.GetAttribute(model, "IsIdle") and not utilMod.GetAttribute(model, "InCombat")
				or not ownerInstance.Parent
				or not hrp.Parent
			then
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
		return false -- no ground found
	end

	local hitPart = result.Instance
	if not hitPart:IsA("BasePart") then
		return false -- hit something strange (shouldn't happen with proper tagging)
	end

	-- Look for PathfindingModifier children
	for _, child in hitPart:GetChildren() do
		if child:IsA("PathfindingModifier") and child.Label == "Danger" then
			return false -- explicitly marked as danger → unsafe
		end
	end

	-- Ground exists and has no "Danger" modifier
	return true
end

--==============================================================================
-- Returns the player-specific creature prefix based on their Magic attribute
--==============================================================================
function utilMod.GetPlayerType(player: Player?): string?
	if not player then
		return nil
	end
	local magictype = utilMod.GetAttribute(player, "Magic") :: string?
	if not magictype then
		return nil
	end

	if magictype == "Artificer" then
		return "PlayerArtificer"
	elseif magictype == "Primordial" then
		return "PlayerPrimordial"
	elseif magictype == "Nature" then
		return "PlayerNature"
	end
	return nil
end

function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?
	if not player.Character then
		return nil
	end
	local root: Instance? = player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
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
		local othercharacter = other.Character
		if not othercharacter then
			continue
		end
		if othercharacter ~= char then
			if utilMod.IsAlly(othercharacter, char) then
				continue
			end
			local dist: number? = utilMod.GetDistance(othercharacter, myPos)
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
		if model:IsA("Model") and utilMod.GetAttribute(model, "HasFallen") then
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

function utilMod.GetPartyMembers(model: Instance): PartyInfo
    local info: PartyInfo = {
        Player = nil,
        Character = nil,
        pets = {},
        buildings = {},
    }

    local player: Player?

    -- 1. Resolve the owning Player
    if model:IsA("Player") then
        player = model

    elseif model:IsA("Model") then
        -- Most likely: it's the character
        player = utilMod.GetPlayerFromCharacter(model)

        -- Fallback: it's probably a pet
        if not player then
            local ownedByUserId = model:GetAttribute("OwnedBy")  -- cleaner than utilMod.GetAttribute if you have it
            if typeof(ownedByUserId) == "number" then
                player = Players:GetPlayerByUserId(ownedByUserId)
            end
        end
    else
        error(`GetPartyMembers expected Player or Model, got {model.ClassName}`)
    end

    if not player then
        return info
    end

    info.Player = player

    -- 2. Character (optional — may be nil)
    info.Character = player.Character

    -- 3. Pets — only makes sense if character exists
    if info.Character then
        local petModels = utilMod.MyPets(info.Character)
        if typeof(petModels) == "table" then
            -- Optional safety: filter to only Models
            for _, pet in petModels do
                if pet:IsA("Model") then
                    table.insert(info.pets, pet)
                end
            end
        end
    end

    -- 4. Buildings (also Models)
    local manaPoints = workspace:FindFirstChild("ManaPoints")
    if manaPoints and manaPoints:IsA("Folder") then
        for _, child in manaPoints:GetChildren() do
            if child:IsA("Model") then
                local ownedBy = child:GetAttribute("OwnedBy")
                if typeof(ownedBy) == "number" and ownedBy == player.UserId then
                    table.insert(info.buildings, child)
                end
            end
        end
    end

    return info
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
		return false
	end
	if not range or range <= 0 then
		warn("Should not reach me.")
		return false
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

function utilMod.CopyStatsToFolder(target: Instance, stats: { [string]: any }, folderName: string?): Folder?
	local foldername: string = folderName or "Data"
	local folder: Instance? = target:FindFirstChild(foldername)
	if not folder then
		folder = Instance.new("Folder")
	end
	if folder and folder:IsA("Folder") then
		folder.Name = foldername
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
	return nil
end

function utilMod.getValue(child: ValueBase): any
	if child:IsA("BoolValue") then
		return child.Value :: boolean
	elseif child:IsA("BrickColorValue") then
		return child.Value :: BrickColor
	elseif child:IsA("CFrameValue") then
		return child.Value :: CFrame
	elseif child:IsA("Color3Value") then
		return child.Value :: Color3
	elseif child:IsA("IntValue") then
		return child.Value :: number
	elseif child:IsA("NumberValue") then
		return child.Value :: number
	elseif child:IsA("ObjectValue") then
		return child.Value :: Instance?
	elseif child:IsA("RayValue") then
		return child.Value :: Ray
	elseif child:IsA("StringValue") then
		return child.Value :: string
	elseif child:IsA("Vector3Value") then
		return child.Value :: Vector3
		-- add more types if you use them
	else
		warn("Unsupported ValueBase type: " .. child.ClassName)
		return nil
	end
end

function utilMod.GetStatsFromFolder(instance: Instance, folderName: string?): { [string]: any }
	local foldername: string = folderName or "Data"
	local folder: Instance? = instance:FindFirstChild(foldername)
	if not folder or not folder:IsA("Folder") then
		return {}
	end

	local stats: { [string]: any } = {}
	for _, child: Instance in folder:GetChildren() do
		if child:IsA("ValueBase") then
			local val = utilMod.getValue(child)
			if val ~= nil then
				stats[child.Name] = val
			end
		end
	end
	return stats
end

local ThreatAmountForPets = 5

function utilMod.ApplyThreat(attacker: Model, target: Model, threatAmount: number): boolean
	if not attacker or not target then
		warn("Should not reach me.")
		return false
	end
	if not attacker:IsA("Model") then
		warn("Should not reach me.")
		return false
	end
	local dealtoPets = false
	if target:IsA("Player") or game.Players:GetPlayerFromCharacter(target) ~= nil then
		dealtoPets = true
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
	if dealtoPets then
		local petsFolder = workspace:WaitForChild("Pets")
		if petsFolder then
			local allpets = petsFolder:GetChildren()
			local plrtarg = utilMod.GetPlayerFromCharacter(target)
			if allpets and plrtarg then
				for _, pet in allpets do
					local owner = pet and utilMod.GetAttribute(pet, "OwnedBy")
					if owner and owner == plrtarg.UserId then
						local addThreat: BindableEvent? = pet:FindFirstChild("AddThreat")
						if addThreat and addThreat:IsA("BindableEvent") then
							addThreat:Fire(attackerid, ThreatAmountForPets)
						end
					end
				end

				return true
			end
		end
	else
		local addThreat: Instance? = target:FindFirstChild("AddThreat")
		if addThreat and addThreat:IsA("BindableEvent") then
			addThreat:Fire(attackerid, threatAmount)
			return true
		end
		return false
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
	local hrp: Instance? = utilMod.GetRootPart(char)
	if not hrp or not hrp:IsA("BasePart") then
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
			local petroot: Instance? = utilMod.GetRootPart(pet)
			if petroot and petroot:IsA("BasePart") then
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
	if not pos then
		warn("Should not reach me.")
		return {}
	end
	if not range or typeof(range) ~= "number" or range <= 0 then
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
			local hrp: Instance? = player.Character:FindFirstChild("HumanoidRootPart")

			if hrp and hrp:IsA("BasePart") and utilMod.GetDistance(pos, hrp.Position) <= range then
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
				local hrp: Instance? = petModel:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") and utilMod.GetDistance(pos, hrp.Position) <= range then
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

--- Initializes an NPC model by setting all attributes from statsMod.InitStats[model.Name]
-- @param model The Model to initialize (must have a Name that exists in InitStats)
-- @return void
function utilMod.InitNPC(model: Model): ()
	if not model:IsA("Model") then
		warn("InitNPC: Argument is not a Model")
		return
	end

	local npcName = utilMod.RemoveFeralPrefix(utilMod.customTrim(model.Name))
	local stats = statsMod.InitStats[npcName]

	if not stats then
		warn("InitNPC: No stats found for NPC named: " .. npcName)
		return
	end

	-- Apply every key-value pair as an attribute
	for key, value in pairs(stats) do
		utilMod.SetAttribute(model, key, value)
	end
	if npcName == "StoneManaPriest" then
		utilMod.SetAttribute(model, "Mana", statsMod.creatureMana["StoneManaPriest"].Mana)
		utilMod.SetAttribute(model, "MaxMana", statsMod.creatureMana["StoneManaPriest"].MaxMana)
	elseif npcName == "MudPriest" then
		utilMod.SetAttribute(model, "Mana", statsMod.creatureMana["MudPriest"].Mana)
		utilMod.SetAttribute(model, "MaxMana", statsMod.creatureMana["MudPriest"].MaxMana)
	elseif npcName == "UnkemptDruid" then
		utilMod.SetAttribute(model, "Mana", statsMod.creatureMana["UnkemptDruid"].Mana)
		utilMod.SetAttribute(model, "MaxMana", statsMod.creatureMana["UnkemptDruid"].MaxMana)
	end

	-- Optional: You can add debug print if needed during development
	-- print("Initialized NPC:", npcName, "with", #stats, "attributes")
end

function utilMod.RemoveFeralPrefix(name: string): string
	if typeof(name) ~= "string" or name == "" then
		return name
	end

	-- Pattern to match "Feral" (case-insensitive) at the start,
	-- optionally followed by whitespace
	local prefixPattern = "^[fF][eE][rR][aA][lL]%s*"

	-- Remove the matching prefix if it exists
	local cleaned = name:gsub(prefixPattern, "")

	-- If nothing was removed, return original
	-- (this also handles cases where "feral" appears later in the name)
	return cleaned
end

function utilMod.ReassignSpawn(model: Model, spawnPosition: Vector3): Vector3
	-- Collect all possible spawn choices from attributes that start with "SpawnChoice_"
	local possibleSpawns: { Vector3 } = {}

	for key, val in pairs(model:GetAttributes()) do
		if typeof(key) == "string" and string.match(key, "SpawnChoice_") then
			local value = val
			if typeof(value) == "Vector3" then
				-- Skip the current spawn position to avoid immediately picking the same spot
				if not value:FuzzyEq(spawnPosition, 0.1) and not value:FuzzyEq(Vector3.new(0, 0, 0), 0.1) then -- small tolerance for floating-point
					table.insert(possibleSpawns, value)
				end
			end
		end
	end

	-- If we have no other choices, fall back to current position (or could error/warn)
	if #possibleSpawns == 0 then
		warn(
			"[ReassignSpawn] No other SpawnChoice_ attributes found on "
				.. model.Name
				.. " — staying at current position"
		)
		return spawnPosition
	end

	-- Pick one at random
	local randomIndex = math.random(1, #possibleSpawns)
	local chosen = possibleSpawns[randomIndex]

	return chosen
end

local MIN_ATTACK_DELAY = 0.3  -- example value; set to whatever your game needs
local BASE_DELAY = statsMod.DELAY or 1  -- fallback if statsMod.DELAY is missing

function utilMod.GetCooldown(model: Model): number
	if not model then
		warn("[utilMod.GetCooldown] Model is nil")
		return math.max(BASE_DELAY, MIN_ATTACK_DELAY)
	end

	local cooldown = BASE_DELAY

	-- Try to find the Data folder
	local dataFolder = model:FindFirstChild("Data")
	if dataFolder and dataFolder:IsA("Folder") then
		local delayValue = dataFolder:FindFirstChild("attackDelay")  -- or "AttackDelay", "DelayMultiplier", etc.

		if delayValue then
			if delayValue:IsA("NumberValue") then
				cooldown = BASE_DELAY * delayValue.Value
			else
				warn(`[utilMod.GetCooldown] Expected NumberValue for "attackDelay" in {model:GetFullName()}, got {delayValue.ClassName}`)
			end
		end
	end

	-- Always enforce minimum delay (prevents animation glitches / too-fast attacks)
	if cooldown < MIN_ATTACK_DELAY then
		cooldown = MIN_ATTACK_DELAY
	end

	return cooldown
end


function utilMod.GetTakeLithLoc(model: Model, hrp: BasePart): Vector3?
	-- Validate inputs
	if not model or not hrp then
		warn("Should not reach me.")
		return nil
	end

	local ownedById = utilMod.GetAttribute(model, "OwnedBy")
	if not ownedById or ownedById == "" or ownedById == "None" or ownedById == "none" then
		warn("Should not reach me.")
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
	local playerUserId = plr.UserId

	for _, point in ipairs(points) do
		-- Skip if it's a ManaSpout or owned by the same player
		if point.Name == "ManaSpout" then
			continue
		end
		if utilMod.GetAttribute(point, "OwnedBy") == playerUserId then
			continue
		end

		local meshPart = point:FindFirstChildOfClass("MeshPart")
		if not meshPart then
			continue
		end

		local dist = utilMod.GetDistance(meshPart.Position, hrp.Position)
		if dist and dist < closestDist then
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

function utilMod.GetDefendLithLoc(model: Model, hrp: BasePart): Vector3?
	-- Validate core inputs
	if not model or not hrp then
		return nil
	end

	local ownedById = utilMod.GetAttribute(model, "OwnedBy")
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

		local ownedBy = utilMod.GetAttribute(point, "OwnedBy")
		if ownedBy ~= playerUserId then
			continue
		end

		table.insert(ownedLiths, meshPart)

		local isUnderAttack = utilMod.GetAttribute(point, "IsUnderAttack")
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
				if dist and dist < closestDist then
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
			if dist and dist < closestDist then
				closestDist = dist
				closest = mesh
			end
		end
		return closest and closest.Position or nil
	end
end

return utilMod :: UtilMod
