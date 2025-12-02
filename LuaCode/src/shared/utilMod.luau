-- local collectionService = game:GetService("CollectionService")
-- local RunService = game:GetService("RunService")
-- local utilMod = {}

-- -- Cache for performance
-- local CharacterList = {}
-- local CharacterSet = {}

-- local function addCharacter(inst)
--     if not CharacterSet[inst] then
--         CharacterSet[inst] = true
--         table.insert(CharacterList, inst)
--     end
-- end

-- local function removeCharacter(inst)
--     if CharacterSet[inst] then
--         CharacterSet[inst] = nil
--         for i = #CharacterList, 1, -1 do
--             if CharacterList[i] == inst then
--                 table.remove(CharacterList, i)
--                 break
--             end
--         end
--     end
-- end

-- -- Initialize
-- for _, inst in ipairs(collectionService:GetTagged("Character")) do
--     addCharacter(inst)
-- end
-- collectionService:GetInstanceAddedSignal("Character"):Connect(addCharacter)
-- collectionService:GetInstanceRemovedSignal("Character"):Connect(removeCharacter)

-- function utilMod.GetCharactersTagged()
--     return CharacterList
-- end


-- local function GetPosition(obj)
--     if typeof(obj) == "Instance" then
--         if obj:IsA("BasePart") then
--             return obj.Position
--         else
--             return nil, "Object is not a BasePart"
--         end
--     elseif typeof(obj) == "Vector3" then
--         return obj
--     else
--         return nil, "Expected BasePart or Vector3"
--     end
-- end

-- function utilMod.GetMagnitude(a, b)
--     if not a or not b then return math.huge end
    
--     local posA, errA = GetPosition(a)
--     local posB, errB = GetPosition(b)
    
--     if not posA then
--         warn("GetMagnitude: First argument invalid -", errA, a)
--         return math.huge
--     end
--     if not posB then
--         warn("GetMagnitude: Second argument invalid -", errB, b)
--         return math.huge
--     end
    
--     return (posA - posB).Magnitude
-- end

-- function utilMod.GetMagnitudeHelper(model: Model, othermodel: Model)
--     if not model and not othermodel then return nil end
--     local modelhrp = model:FindFirstChild("HumanoidRootPart")
--     local othermodelhrp = othermodel:FindFirstChild("HumanoidRootPart") or othermodel:FindFirstChildOfClass("MeshPart")

--     if not modelhrp and not othermodelhrp then return nil end

--     return utilMod.GetMagnitude(modelhrp,othermodelhrp)
-- end

-- function utilMod.GetModelByIDorName(targetIdOrName)
--     -- targetIdOrName is ALWAYS a string (pet.Name) or number (UserId)
--     local targetType = type(targetIdOrName)
    
--     for _, character in ipairs(CharacterList) do
--         -- Check by Name (for pets)
--         if character.Name == targetIdOrName then
--             return character
--         end
        
--         -- Check by UserId (for players)
--         local player = game.Players:GetPlayerFromCharacter(character)
--         if player and player.UserId == targetIdOrName then
--             return character
--         end
--     end
--     return nil
-- end

-- function utilMod.GetPlayerByUserId(userId)
--     for _, player in ipairs(game.Players:GetPlayers()) do
--         if player.UserId == userId then return player end
--     end
--     return nil
-- end


-- function utilMod.IsPlayer(plr)
--     for _, plrtest in ipairs(game.Players:GetPlayers())do
--         if plrtest.Name == plr.Name then
--             return true
--         end
--     end
--     return false

-- end

-- function utilMod.SetFlagsForMoving(model)
--     model:SetAttribute("IsMoving", true)
--     model:SetAttribute("IsIdle", false)
--     model:SetAttribute("HasFallen", false)
--     model:SetAttribute("InCombat", false)
-- end

-- function utilMod.SetFlagsForCombat(model)
--     model:SetAttribute("IsMoving", false)
--     model:SetAttribute("IsIdle", false)
--     model:SetAttribute("HasFallen", false)
--     model:SetAttribute("InCombat", true)
-- end

-- function utilMod.SetFlagsForDeath(model)
--     model:SetAttribute("IsMoving", false)
--     model:SetAttribute("IsIdle", false)
--     model:SetAttribute("HasFallen", true)
--     model:SetAttribute("InCombat", false)
-- end

-- function utilMod.SetFlagsForIdle(model)
--     model:SetAttribute("IsMoving", false)
--     model:SetAttribute("IsIdle", true)
--     model:SetAttribute("HasFallen", false)
--     model:SetAttribute("InCombat", false)
--     model:SetAttribute("IdleStartTime", tick())
-- end


-- -- Keep your existing utility functions unchanged
-- function utilMod.HexToColor3(hex)
--     hex = hex:gsub("#","")
--     local r = tonumber(hex:sub(1,2), 16) / 255
--     local g = tonumber(hex:sub(3,4), 16) / 255
--     local b = tonumber(hex:sub(5,6), 16) / 255
--     return Color3.new(r, g, b)
-- end

-- -- Smoothly rotates a model to face a target during combat
-- -- Handles both HumanoidRootPart and legacy Torso
-- -- Only rotates on Y axis (no tilting)
-- function utilMod.SpinToTargetInCombat(model: Model, targetModel: Model, lerpAlpha: number?)
--     if not model or not targetModel then return end
--     lerpAlpha = lerpAlpha or 0.3

--     local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
--     local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso")
--     if not hrp or not targetRoot then return end

--     local direction = (targetRoot.Position - hrp.Position)
--     direction = Vector3.new(direction.X, 0, direction.Z)  -- Flatten to horizontal plane

--     if direction.Magnitude > 0.1 then
--         local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
--         hrp.CFrame = hrp.CFrame:lerp(targetCFrame, lerpAlpha)
--     end
-- end

-- -- Makes a pet smoothly spin/fidget to face its owner while idle
-- -- Only runs during true idle state (not following, not in combat)
-- -- Includes random delays and natural feel
-- function utilMod.IdleSpinToOwner(model: Model, ownerModel: Model)
--     if not model or not ownerModel then return end
--     if not model:GetAttribute("IsIdle") then return end

--     local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
--     local ownerRoot = ownerModel:FindFirstChild("HumanoidRootPart") or ownerModel:FindFirstChild("Torso")
--     if not hrp or not ownerRoot then return end

--     -- Prevent spam
--     if not model:GetAttribute("CanIdleSpin") then return end
--     model:SetAttribute("CanIdleSpin", false)

--     task.spawn(function()
--         -- Direction to owner (horizontal only)
--         local toOwner = (ownerRoot.Position - hrp.Position)
--         toOwner = Vector3.new(toOwner.X, 0, toOwner.Z)

--         if toOwner.Magnitude < 0.3 then
--             -- Too close or already aligned → skip
--             model:SetAttribute("CanIdleSpin", true)
--             return
--         end

--         local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + toOwner)

--         local connection
--         connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
--             -- Safety checks
--             if not model:GetAttribute("IsIdle") then
--                 connection:Disconnect()
--                 return
--             end
--             if not ownerModel.Parent then
--                 connection:Disconnect()
--                 model:SetAttribute("CanIdleSpin", true)
--                 return
--             end

--             -- Smooth lerp with delta-time scaling
--             local alpha = math.min(4 * dt, 1)  -- Feels snappy but natural (~0.25s total)
--             hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

--             -- Done when close enough
--             if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
--                 hrp.CFrame = targetCFrame  -- Snap to perfect
--                 connection:Disconnect()
--             end
--         end)

--         -- Random cooldown before next spin (8–15 seconds)
--         local nextSpinDelay = Random.new():NextInteger(8, 15)
--         task.delay(nextSpinDelay, function()
--             if model.Parent and model:GetAttribute("IsIdle") then
--                 model:SetAttribute("CanIdleSpin", true)
--             end
--         end)
--     end)
-- end



-- function utilMod.SpinToOwner(model: Model, hrp: BasePart, ownerInstance: Model, rng: Random, spinCooldown: boolean?)
--     -- Optional external cooldown check (kept for backward compatibility)
--     if spinCooldown ~= nil and spinCooldown == true then
--         return
--     end

--     -- Prevent multiple simultaneous spins
--     if model:GetAttribute("SpinningToOwner") then
--         return
--     end
--     model:SetAttribute("SpinningToOwner", true)

--     task.spawn(function()
--         local tHRP = ownerInstance:FindFirstChild("HumanoidRootPart") or ownerInstance:FindFirstChild("Torso")
--         if not tHRP or not tHRP.Parent then
--             model:SetAttribute("SpinningToOwner", false)
--             return
--         end

--         -- Flat direction to owner (ignore Y)
--         local direction = Vector3.new(
--             tHRP.Position.X - hrp.Position.X,
--             0,
--             tHRP.Position.Z - hrp.Position.Z
--         )

--         if direction.Magnitude < 0.1 then
--             model:SetAttribute("SpinningToOwner", false)
--             return
--         end

--         local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)

--         local connection
--         connection = RunService.Heartbeat:Connect(function(dt)
--             -- Cancel conditions
--             if not model:GetAttribute("IsIdle")
--                 or not ownerInstance.Parent
--                 or not hrp.Parent then
--                 if connection then connection:Disconnect() end
--                 model:SetAttribute("SpinningToOwner", false)
--                 return
--             end

--             -- Smooth lerp (you can tweak the speed multiplier)
--             local alpha = math.min(12 * dt, 1)  -- ~80-100ms response time, feels snappy
--             hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

--             -- Close enough → snap and finish
--             if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
--                 hrp.CFrame = targetCFrame
--                 if connection then connection:Disconnect() end
--                 model:SetAttribute("SpinningToOwner", false)
--             end
--         end)

--         -- Safety cleanup in case something weird happens
--         task.delay(5, function()
--             if connection and connection.Connected then
--                 connection:Disconnect()
--                 model:SetAttribute("SpinningToOwner", false)
--             end
--         end)
--     end)
-- end

-- function utilMod.DistancetoGround(vector)
--     local rayOrigin = vector
--     local ignoreList = utilMod.GetCharactersTagged()
--     local rayDirection = Vector3.new(0, -10000, 0)
--     local raycastParams = RaycastParams.new()
--     raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
--     raycastParams.FilterDescendantsInstances = ignoreList or {}
--     raycastParams.RespectCanCollide = false
--     local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
--     if raycastResult then
--         return raycastResult.Position.Y
--     end
--     return nil
-- end



-- function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?

--     -- Services
--     local Workspace = game:GetService("Workspace")

--     -- Configuration
--     local RAYCAST_PARAMS = RaycastParams.new()
--     RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
--     RAYCAST_PARAMS.IgnoreWater = true

--     if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
--         return nil
--     end

--     local rootPart = player.Character.HumanoidRootPart
--     local origin = rootPart.Position

--     -- Update raycast params to ignore the player's character
--     RAYCAST_PARAMS.FilterDescendantsInstances = {player.Character}

--     local stepDegrees = 40

--     -- Rotate around Y axis in steps
--     for angle = 0, 360 - stepDegrees, stepDegrees do
--         local radians = math.rad(angle)
--         local direction = Vector3.new(math.cos(radians), 0, -math.sin(radians))
--         local targetPos = origin + direction * distance

--         -- Cast ray forward to check for obstacles
--         local rayOrigin = origin + Vector3.new(0, 2, 0) -- Start ray a bit above ground
--         local rayDirection = direction * (distance * 1.5)
--         local result = Workspace:Raycast(rayOrigin, rayDirection, RAYCAST_PARAMS)

--         local isClear = true

--         if result then
--             -- There's something in the way
--             local distToObstacle = (result.Position - origin).Magnitude
--             if distToObstacle < distance - 1 then
--                 isClear = false
--             end
--         end

--         if isClear then
--            return targetPos
--         end
--     end

--     return nil
-- end


-- function utilMod.createCustomExplosion(position, visualSize, time, color)
--     local attachment = Instance.new("Attachment")
--     attachment.Position = position
--     attachment.Parent = workspace.Terrain

--     local pe = Instance.new("ParticleEmitter")
--     pe.Parent = attachment
--     pe.Color = ColorSequence.new(color, color)
--     pe.Size = NumberSequence.new{
--         NumberSequenceKeypoint.new(0, 0),
--         NumberSequenceKeypoint.new(0.5, visualSize),
--         NumberSequenceKeypoint.new(1, 0)
--     }
--     pe.Lifetime = NumberRange.new(0.1, 0.4)
--     pe.Rate = 1000
--     pe.SpreadAngle = Vector2.new(360, 360)
--     pe.Speed = NumberRange.new(5, 20)
--     pe.Drag = 5

--     game:GetService("Debris"):AddItem(attachment, time)
-- end

-- -- Generate a unique name based on baseofname by scanning workspace.Pets and workspace.Ferals
-- function utilMod.uniqueName(baseofname)
--     local highest = 0

--     -- Helper to scan a folder for matching names
--     local function scanFolder(folder)
--         if not folder then return end
--         for _, item in ipairs(folder:GetChildren()) do
--             if item.Name:sub(1, #baseofname) == baseofname then
--                 -- Match pattern baseofname_### (numeric suffix)
--                 local suffix = item.Name:match("^" .. baseofname .. "_(%d+)$")
--                 if suffix then
--                     local num = tonumber(suffix)
--                     if num and num > highest then
--                         highest = num
--                     end
--                 end
--             end
--         end
--     end

--     -- Scan both Pets and Ferals folders
--     scanFolder(workspace:FindFirstChild("Pets"))
--     scanFolder(workspace:FindFirstChild("Ferals"))

--     -- Return next name, padded to 3 digits
--     local newNum = highest + 1
--     return string.format("%s_%03d", baseofname, newNum)
-- end

-- -- Fully Luau-compatible version (no ~ operator)
-- function utilMod.GetSeedFromName(name: string, useTime: boolean?): number
--     if not name or name == "" then
--         return math.random(1, 2^30)
--     end

--     local seed = 5381 -- DJB2 start value
--     local nameUpper = string.upper(name)

--     -- DJB2 hash (works perfectly in Luau)
--     for i = 1, #nameUpper do
--         local byte = string.byte(nameUpper, i)
--         seed = (seed * 33 + byte) % 0xFFFFFFFF   -- keep it 32-bit
--     end

--     -- Replace ~ (XOR) with bit32.bxor – fully supported in Roblox Luau
--     seed = bit32.bxor(seed, tonumber(tostring({}):sub(8), 16) or 0)

--     if useTime then
--         seed = bit32.bxor(seed, math.floor(tick() % 1 * 1e6))
--     end

--     -- Final avalanche (makes low bits random too) – using only bit32 functions
--     seed = bit32.bxor(seed, bit32.rshift(seed, 16))
--     seed = (seed * 0x7FE73CE1) % 0xFFFFFFFF
--     seed = bit32.bxor(seed, bit32.rshift(seed, 13))
--     seed = (seed * 0x5A7D3F15) % 0xFFFFFFFF
--     seed = bit32.bxor(seed, bit32.rshift(seed, 16))

--     return seed
-- end

-- function utilMod.GetClosestPlayer(thisplayer)
--     local thischar = thisplayer.Character
--     if not thischar then return end
--     local thisHRP = thischar:FindFirstChild("HumanoidRootPart")
--     if not thisHRP then return end
--     local thispos = thisHRP.Position

--     local closest = nil
--     local closestMag = math.huge  -- Use huge for first comparison

--     for _, plr in pairs(game.Players:GetPlayers()) do
--         if plr ~= thisplayer then  -- Use ~= for objects (safer than UserId)
--             local char = plr.Character
--             if char then
--                 local hrp = char:FindFirstChild("HumanoidRootPart")
--                 if hrp then
--                     local mag = utilMod.GetMagnitude(hrp.Position, thispos)  -- Assumes this works
--                     -- Or inline: (hrp.Position - thispos).Magnitude
--                     if mag < closestMag then
--                         closest = plr
--                         closestMag = mag
--                     end
--                 end
--             end
--         end
--     end
--     return closest
-- end


-- function utilMod.GetClosestModelSkipownPets(thisplayer, folderName)
--     local character = thisplayer.Character
--     if not character then return end
    
--     local thisHRP = character:FindFirstChild("HumanoidRootPart")
--     if not thisHRP then return end
--     local thisPos = thisHRP.Position

--     local folder = workspace:FindFirstChild(folderName)
--     if not folder then return end

--     local isPetFolder = (folderName == "Pets")  -- Cleaner check
--     local closestModel = nil
--     local closestDist = math.huge

--     for _, model in pairs(folder:GetChildren()) do
--         if model:IsA("Model") then
--             local hrp = model:FindFirstChild("HumanoidRootPart")
--             if hrp then
--                 -- Skip player's own pet in Pets folder
--                 if isPetFolder then
--                     local ownerId = model:GetAttribute("OwnedBy")
--                     if ownerId and ownerId == thisplayer.UserId then
--                         continue  -- Skip own pet
--                     end
--                 end

--                 local dist = (hrp.Position - thisPos).Magnitude
--                 if dist < closestDist then
--                     closestDist = dist
--                     closestModel = model
--                 end
--             end
--         end
--     end

--     return closestModel
-- end


-- function utilMod.GetEnemyModelsWithinRange(player, range)
--     local character = player.Character
--     if not character then return {} end
    
--     local thisHRP = character:FindFirstChild("HumanoidRootPart")
--     if not thisHRP then return {} end
--     local thisPos = thisHRP.Position

--     local petsFolder = workspace:FindFirstChild("Pets")
--     local feralsFolder = workspace:FindFirstChild("Ferals")
    
--     local enemies = {}

--     -- Add other players' pets within range (exclude own pets)
--     if petsFolder then
--         for _, model in pairs(petsFolder:GetChildren()) do
--             if model:IsA("Model") then
--                 local hrp = model:FindFirstChild("HumanoidRootPart")
--                 if hrp then
--                     local ownerId = model:GetAttribute("OwnedBy")
--                     if ownerId ~= player.UserId then  -- Include if not owned by this player (or nil)
--                         local dist = (hrp.Position - thisPos).Magnitude
--                         if dist < range then
--                             table.insert(enemies, model)
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     -- Add all ferals within range
--     if feralsFolder then
--         for _, model in pairs(feralsFolder:GetChildren()) do
--             if model:IsA("Model") then
--                 local hrp = model:FindFirstChild("HumanoidRootPart")
--                 if hrp then
--                     local dist = (hrp.Position - thisPos).Magnitude
--                     if dist < range then
--                         table.insert(enemies, model)
--                     end
--                 end
--             end
--         end
--     end

--     return enemies
-- end

-- function utilMod.GetEnemyPlayersWithinRange(player, range)
--     local character = player.Character
--     if not character then return {} end
    
--     local thisHRP = character:FindFirstChild("HumanoidRootPart")
--     if not thisHRP then return {} end
--     local thisPos = thisHRP.Position

--     local petsFolder = workspace:FindFirstChild("Pets")
--     local feralsFolder = workspace:FindFirstChild("ferals")
    
--     local enemies = {}

--     for _, enemyplr in game.Players:GetPlayers() do
--         local enemhrp = enemyplr.Character:FindFirstChild("HumanoidRootPart")
--         if not enemhrp then continue end
--         if utilMod.GetMagnitude(thisHRP, enemhrp) < range then
--             table.insert(enemies, enemyplr.Character)
--         end
--     end
-- end

-- function utilMod.MyPets(plr)
--     local allpets = workspace:WaitForChild("Pets"):GetChildren()
--     local pets = {}
--     for _,pet in allpets do
--         if pet:GetAttribute("OwnedBy") == plr.UserId then
--             table.insert(pets, pet)
--         end
--     end
--     return pets
-- end

-- -- Copies a flat table of stats into a "Data" Folder with Value objects inside the target Instance
-- -- Returns the created/existing Data folder for convenience
-- function utilMod.CopyStatsToFolder(targetInstance: Instance, statsTable: { [string]: any }, folderName: string?)
--     folderName = folderName or "Data"
    
--     -- Find or create the Data folder
--     local dataFolder = targetInstance:FindFirstChild(folderName)
--     if not dataFolder then
--         dataFolder = Instance.new("Folder")
--         dataFolder.Name = folderName
--         dataFolder.Parent = targetInstance
--     else
--         -- Optional: clear old values to prevent duplicates/stale data
--         for _, child in ipairs(dataFolder:GetChildren()) do
--             if child:IsA("ValueBase") then
--                 child:Destroy()
--             end
--         end
--     end

--     -- Helper to pick correct ValueBase type
--     local function createValue(name, value)
--         local valueType = typeof(value)
--         local valueObj

--         if valueType == "number" then
--             valueObj = Instance.new("NumberValue")
--         elseif valueType == "string" then
--             valueObj = Instance.new("StringValue")
--         elseif valueType == "boolean" then
--             valueObj = Instance.new("BoolValue")
--         elseif valueType == "Vector3" then
--             valueObj = Instance.new("Vector3Value")
--         --elseif valueType == "UDim2" then
--         --    valueObj = Instance.new("UDim2Value")
--         elseif valueType == "Color3" then
--             valueObj = Instance.new("Color3Value")
--         elseif valueType == "CFrame" then
--             valueObj = Instance.new("CFrameValue")
--         elseif valueType == "BrickColor" then
--             valueObj = Instance.new("BrickColorValue")
--         elseif valueType == "EnumItem" then
--             valueObj = Instance.new("StringValue") -- store as string, or use ObjectValue if you prefer
--             value = tostring(value)
--         else
--             warn(string.format("[utilMod.CopyStatsToFolder] Unsupported type '%s' for stat '%s' (value: %s)", valueType, name, tostring(value)))
--             return nil
--         end

--         valueObj.Name = name
--         valueObj.Value = value
--         valueObj.Parent = dataFolder
--         return valueObj
--     end

--     -- Copy each stat
--     for statName, statValue in pairs(statsTable) do
--         createValue(statName, statValue)
--     end

--     return dataFolder
-- end

-- function utilMod.GetStatsFromFolder(instance: Instance, folderName: string?)
--     folderName = folderName or "Data"
--     local folder = instance:FindFirstChild(folderName)
--     if not folder then return {} end

--     local stats = {}
--     for _, child in ipairs(folder:GetChildren()) do
--         if child:IsA("ValueBase") then
--             stats[child.Name] = child.Value
--         end
--     end
--     return stats
-- end

-- return utilMod


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
	if not subject or not subject.Parent then return nil end
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
	if not posA or not posB then return nil end
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

	for _, folder in {pets, ferals} do
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
	local r = tonumber(hex:sub(1,2), 16) or 0
	local g = tonumber(hex:sub(3,4), 16) or 0
	local b = tonumber(hex:sub(5,6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

--==============================================================================
-- Smoothly rotates model to face target (combat facing)
--==============================================================================
function utilMod.SpinToTargetInCombat(model: Model, targetModel: Model, lerpAlpha: number?)
	if not model or not targetModel then return end
	lerpAlpha = lerpAlpha or 0.3

	local hrp = utilMod.GetRootPart(model)
	local targetRoot = utilMod.GetRootPart(targetModel)
	if not hrp or not targetRoot then return end

	local direction = Vector3.new(
		targetRoot.Position.X - hrp.Position.X,
		0,
		targetRoot.Position.Z - hrp.Position.Z
	)

	if direction.Magnitude > 0.1 then
		local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
		hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, lerpAlpha)
	end
end

--==============================================================================
-- Idle fidget spin toward owner (natural pet behavior)
--==============================================================================
function utilMod.IdleSpinToOwner(model: Model, ownerModel: Model)
	if not model or not ownerModel or not model:GetAttribute("IsIdle") then return end
	if model:GetAttribute("CanIdleSpin") == false then return end
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
				if connection then connection:Disconnect() end
				model:SetAttribute("CanIdleSpin", true)
				return
			end

			local alpha = math.min(4 * dt, 1)
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

			if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
				hrp.CFrame = targetCFrame
				if connection then connection:Disconnect() end
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
	if spinCooldown == true or model:GetAttribute("SpinningToOwner") then return end
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
				if connection then connection:Disconnect() end
				model:SetAttribute("SpinningToOwner", false)
				return
			end

			local alpha = math.min(12 * dt, 1)
			hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

			if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
				hrp.CFrame = targetCFrame
				if connection then connection:Disconnect() end
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
	params.FilterDescendantsInstances = {Workspace.Pets, Workspace.Ferals, Workspace.Players}
	params.IgnoreWater = true

	local result = Workspace:Raycast(rayOrigin, rayDirection, params)
	return result and result.Position.Y
end

--==============================================================================
-- Finds a clear spawn point around player (40° steps)
--==============================================================================
function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?
	if not player.Character then return nil end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local origin = root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character}
	params.IgnoreWater = true

	for angle = 0, 359, 40 do
		local rad = math.rad(angle)
		local dir = Vector3.new(math.cos(rad), 0, -math.sin(rad))
		local target = origin + dir * distance

		local rayOrigin = origin + Vector3.new(0, 2, 0)
		local result = Workspace:Raycast(rayOrigin, dir * (distance * 1.5), params)
		if not result or (result.Position - origin).Magnitude > distance - 1 then
			return target
		end
	end
	return nil
end

--==============================================================================
-- Simple visual explosion effect
--==============================================================================
function utilMod.createCustomExplosion(position: Vector3, visualSize: number, lifetime: number, color: Color3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://241359587" -- Default explosion texture
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, visualSize * 1.5),
		NumberSequenceKeypoint.new(1, 0)
	}
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Rate = 500
	pe.Speed = NumberRange.new(10, 40)
	pe.SpreadAngle = Vector2.new(360, 360)
	pe.Parent = attachment

	Debris:AddItem(attachment, lifetime)
end

--==============================================================================
-- Generates unique pet name: "FireWolf_001", "FireWolf_002", etc.
--==============================================================================
function utilMod.uniqueName(baseName: string): string
	local highest = 0
	for _, folderName in {"Pets", "Ferals"} do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, child in folder:GetChildren() do
				local num = child.Name:match("^" .. baseName .. "_(%d+)$")
				if num then highest = math.max(highest, tonumber(num) or 0) end
			end
		end
	end
	return string.format("%s_%03d", baseName, highest + 1)
end

--==============================================================================
-- Deterministic seed from name (used for pet appearance variation)
--==============================================================================
function utilMod.GetSeedFromName(name: string, useTime: boolean?): number
	if not name or name == "" then return math.random(1, 2^30) end

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
	if not player.Character then return nil end
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then return nil end

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
	if not myPos then return nil end

	local folder = Workspace:FindFirstChild(folderName)
	if not folder then return nil end

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

function utilMod.GetEnemyModelsWithinRange(player: Player, range: number): {Model}
	local result = {}
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then return result end

	for _, folderName in {"Pets", "Ferals"} do
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

function utilMod.GetEnemyPlayersWithinRange(player: Player, range: number): {Model}
	local result = {}
	local myPos = utilMod.GetPosition(player.Character)
	if not myPos then return result end

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

function utilMod.MyPets(player: Player): {Model}
	local result = {}
	local petsFolder = Workspace:FindFirstChild("Pets")
	if not petsFolder then return result end

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
	if not folder then return {} end

	local stats = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ValueBase") then
			stats[child.Name] = child.Value
		end
	end
	return stats
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
	uniqueName: (baseName: string) -> string,
	GetSeedFromName: (name: string, useTime: boolean?) -> number,

	GetClosestPlayer: (player: Player) -> Player?,
	GetClosestModelSkipOwnPets: (player: Player, folderName: "Pets" | "Ferals") -> Model?,
	GetEnemyModelsWithinRange: (player: Player, range: number) -> {Model},
	GetEnemyPlayersWithinRange: (player: Player, range: number) -> {Model},
	MyPets: (player: Player) -> {Model},

	CopyStatsToFolder: (target: Instance, stats: { [string]: any }, folderName: string?) -> Folder,
	GetStatsFromFolder: (instance: Instance, folderName: string?) -> { [string]: any },
}

return utilMod :: UtilMod