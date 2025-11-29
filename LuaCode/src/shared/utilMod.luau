local collectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local utilMod = {}

-- Cache for performance
local CharacterList = {}
local CharacterSet = {}

local function addCharacter(inst)
    if not CharacterSet[inst] then
        CharacterSet[inst] = true
        table.insert(CharacterList, inst)
    end
end

local function removeCharacter(inst)
    if CharacterSet[inst] then
        CharacterSet[inst] = nil
        for i = #CharacterList, 1, -1 do
            if CharacterList[i] == inst then
                table.remove(CharacterList, i)
                break
            end
        end
    end
end

-- Initialize
for _, inst in ipairs(collectionService:GetTagged("Character")) do
    addCharacter(inst)
end
collectionService:GetInstanceAddedSignal("Character"):Connect(addCharacter)
collectionService:GetInstanceRemovedSignal("Character"):Connect(removeCharacter)

function utilMod.GetCharactersTagged()
    return CharacterList
end


local function GetPosition(obj)
    if typeof(obj) == "Instance" then
        if obj:IsA("BasePart") then
            return obj.Position
        else
            return nil, "Object is not a BasePart"
        end
    elseif typeof(obj) == "Vector3" then
        return obj
    else
        return nil, "Expected BasePart or Vector3"
    end
end

function utilMod.GetMagnitude(a, b)
    if not a or not b then return math.huge end
    
    local posA, errA = GetPosition(a)
    local posB, errB = GetPosition(b)
    
    if not posA then
        warn("GetMagnitude: First argument invalid -", errA, a)
        return math.huge
    end
    if not posB then
        warn("GetMagnitude: Second argument invalid -", errB, b)
        return math.huge
    end
    
    return (posA - posB).Magnitude
end

function utilMod.GetMagnitudeHelper(model: Model, othermodel: Model)
    if not model and not othermodel then return nil end
    local modelhrp = model:FindFirstChild("HumanoidRootPart")
    local othermodelhrp = othermodel:FindFirstChild("HumanoidRootPart") or othermodel:FindFirstChildOfClass("MeshPart")

    if not modelhrp and not othermodelhrp then return nil end

    return utilMod.GetMagnitude(modelhrp,othermodelhrp)
end

function utilMod.GetModelByIDorName(targetIdOrName)
    -- targetIdOrName is ALWAYS a string (pet.Name) or number (UserId)
    local targetType = type(targetIdOrName)
    
    for _, character in ipairs(CharacterList) do
        -- Check by Name (for pets)
        if character.Name == targetIdOrName then
            return character
        end
        
        -- Check by UserId (for players)
        local player = game.Players:GetPlayerFromCharacter(character)
        if player and player.UserId == targetIdOrName then
            return character
        end
    end
    return nil
end

function utilMod.GetPlayerByUserId(userId)
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.UserId == userId then return player end
    end
    return nil
end


function utilMod.IsPlayer(plr)
    for _, plrtest in ipairs(game.Players:GetPlayers())do
        if plrtest.Name == plr.Name then
            return true
        end
    end
    return false

end

function utilMod.SetFlagsForMoving(model)
    model:SetAttribute("IsMoving", true)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForCombat(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", true)
end

function utilMod.SetFlagsForDeath(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", true)
    model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForIdle(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", true)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", false)
    model:SetAttribute("IdleStartTime", tick())
end


-- Keep your existing utility functions unchanged
function utilMod.HexToColor3(hex)
    hex = hex:gsub("#","")
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    return Color3.new(r, g, b)
end

-- Smoothly rotates a model to face a target during combat
-- Handles both HumanoidRootPart and legacy Torso
-- Only rotates on Y axis (no tilting)
function utilMod.SpinToTargetInCombat(model: Model, targetModel: Model, lerpAlpha: number?)
    if not model or not targetModel then return end
    lerpAlpha = lerpAlpha or 0.3

    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso")
    if not hrp or not targetRoot then return end

    local direction = (targetRoot.Position - hrp.Position)
    direction = Vector3.new(direction.X, 0, direction.Z)  -- Flatten to horizontal plane

    if direction.Magnitude > 0.1 then
        local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
        hrp.CFrame = hrp.CFrame:lerp(targetCFrame, lerpAlpha)
    end
end

-- Makes a pet smoothly spin/fidget to face its owner while idle
-- Only runs during true idle state (not following, not in combat)
-- Includes random delays and natural feel
function utilMod.IdleSpinToOwner(model: Model, ownerModel: Model)
    if not model or not ownerModel then return end
    if not model:GetAttribute("IsIdle") then return end

    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    local ownerRoot = ownerModel:FindFirstChild("HumanoidRootPart") or ownerModel:FindFirstChild("Torso")
    if not hrp or not ownerRoot then return end

    -- Prevent spam
    if not model:GetAttribute("CanIdleSpin") then return end
    model:SetAttribute("CanIdleSpin", false)

    task.spawn(function()
        -- Direction to owner (horizontal only)
        local toOwner = (ownerRoot.Position - hrp.Position)
        toOwner = Vector3.new(toOwner.X, 0, toOwner.Z)

        if toOwner.Magnitude < 0.3 then
            -- Too close or already aligned → skip
            model:SetAttribute("CanIdleSpin", true)
            return
        end

        local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + toOwner)

        local connection
        connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
            -- Safety checks
            if not model:GetAttribute("IsIdle") then
                connection:Disconnect()
                return
            end
            if not ownerModel.Parent then
                connection:Disconnect()
                model:SetAttribute("CanIdleSpin", true)
                return
            end

            -- Smooth lerp with delta-time scaling
            local alpha = math.min(4 * dt, 1)  -- Feels snappy but natural (~0.25s total)
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

            -- Done when close enough
            if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
                hrp.CFrame = targetCFrame  -- Snap to perfect
                connection:Disconnect()
            end
        end)

        -- Random cooldown before next spin (8–15 seconds)
        local nextSpinDelay = Random.new():NextInteger(8, 15)
        task.delay(nextSpinDelay, function()
            if model.Parent and model:GetAttribute("IsIdle") then
                model:SetAttribute("CanIdleSpin", true)
            end
        end)
    end)
end



function utilMod.SpinToOwner(model: Model, hrp: BasePart, ownerInstance: Model, rng: Random, spinCooldown: boolean?)
    -- Optional external cooldown check (kept for backward compatibility)
    if spinCooldown ~= nil and spinCooldown == true then
        return
    end

    -- Prevent multiple simultaneous spins
    if model:GetAttribute("SpinningToOwner") then
        return
    end
    model:SetAttribute("SpinningToOwner", true)

    task.spawn(function()
        local tHRP = ownerInstance:FindFirstChild("HumanoidRootPart") or ownerInstance:FindFirstChild("Torso")
        if not tHRP or not tHRP.Parent then
            model:SetAttribute("SpinningToOwner", false)
            return
        end

        -- Flat direction to owner (ignore Y)
        local direction = Vector3.new(
            tHRP.Position.X - hrp.Position.X,
            0,
            tHRP.Position.Z - hrp.Position.Z
        )

        if direction.Magnitude < 0.1 then
            model:SetAttribute("SpinningToOwner", false)
            return
        end

        local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)

        local connection
        connection = RunService.Heartbeat:Connect(function(dt)
            -- Cancel conditions
            if not model:GetAttribute("IsIdle")
                or not ownerInstance.Parent
                or not hrp.Parent then
                if connection then connection:Disconnect() end
                model:SetAttribute("SpinningToOwner", false)
                return
            end

            -- Smooth lerp (you can tweak the speed multiplier)
            local alpha = math.min(12 * dt, 1)  -- ~80-100ms response time, feels snappy
            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)

            -- Close enough → snap and finish
            if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
                hrp.CFrame = targetCFrame
                if connection then connection:Disconnect() end
                model:SetAttribute("SpinningToOwner", false)
            end
        end)

        -- Safety cleanup in case something weird happens
        task.delay(5, function()
            if connection and connection.Connected then
                connection:Disconnect()
                model:SetAttribute("SpinningToOwner", false)
            end
        end)
    end)
end

function utilMod.DistancetoGround(vector)
    local rayOrigin = vector
    local ignoreList = utilMod.GetCharactersTagged()
    local rayDirection = Vector3.new(0, -10000, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    raycastParams.RespectCanCollide = false
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        return raycastResult.Position.Y
    end
    return nil
end



function utilMod.FindClearSpawnPoint(player: Player, distance: number): Vector3?

    -- Services
    local Workspace = game:GetService("Workspace")

    -- Configuration
    local RAYCAST_PARAMS = RaycastParams.new()
    RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
    RAYCAST_PARAMS.IgnoreWater = true

    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local rootPart = player.Character.HumanoidRootPart
    local origin = rootPart.Position

    -- Update raycast params to ignore the player's character
    RAYCAST_PARAMS.FilterDescendantsInstances = {player.Character}

    local stepDegrees = 40

    -- Rotate around Y axis in steps
    for angle = 0, 360 - stepDegrees, stepDegrees do
        local radians = math.rad(angle)
        local direction = Vector3.new(math.cos(radians), 0, -math.sin(radians))
        local targetPos = origin + direction * distance

        -- Cast ray forward to check for obstacles
        local rayOrigin = origin + Vector3.new(0, 2, 0) -- Start ray a bit above ground
        local rayDirection = direction * (distance * 1.5)
        local result = Workspace:Raycast(rayOrigin, rayDirection, RAYCAST_PARAMS)

        local isClear = true

        if result then
            -- There's something in the way
            local distToObstacle = (result.Position - origin).Magnitude
            if distToObstacle < distance - 1 then
                isClear = false
            end
        end

        if isClear then
           return targetPos
        end
    end

    return nil
end


function utilMod.createCustomExplosion(position, visualSize, time, color)
    local attachment = Instance.new("Attachment")
    attachment.Position = position
    attachment.Parent = workspace.Terrain

    local pe = Instance.new("ParticleEmitter")
    pe.Parent = attachment
    pe.Color = ColorSequence.new(color, color)
    pe.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, visualSize),
        NumberSequenceKeypoint.new(1, 0)
    }
    pe.Lifetime = NumberRange.new(0.1, 0.4)
    pe.Rate = 1000
    pe.SpreadAngle = Vector2.new(360, 360)
    pe.Speed = NumberRange.new(5, 20)
    pe.Drag = 5

    game:GetService("Debris"):AddItem(attachment, time)
end

-- Generate a unique name based on baseofname by scanning workspace.Pets and workspace.Ferals
function utilMod.uniqueName(baseofname)
    local highest = 0

    -- Helper to scan a folder for matching names
    local function scanFolder(folder)
        if not folder then return end
        for _, item in ipairs(folder:GetChildren()) do
            if item.Name:sub(1, #baseofname) == baseofname then
                -- Match pattern baseofname_### (numeric suffix)
                local suffix = item.Name:match("^" .. baseofname .. "_(%d+)$")
                if suffix then
                    local num = tonumber(suffix)
                    if num and num > highest then
                        highest = num
                    end
                end
            end
        end
    end

    -- Scan both Pets and Ferals folders
    scanFolder(workspace:FindFirstChild("Pets"))
    scanFolder(workspace:FindFirstChild("Ferals"))

    -- Return next name, padded to 3 digits
    local newNum = highest + 1
    return string.format("%s_%03d", baseofname, newNum)
end

-- Fully Luau-compatible version (no ~ operator)
function utilMod.GetSeedFromName(name: string, useTime: boolean?): number
    if not name or name == "" then
        return math.random(1, 2^30)
    end

    local seed = 5381 -- DJB2 start value
    local nameUpper = string.upper(name)

    -- DJB2 hash (works perfectly in Luau)
    for i = 1, #nameUpper do
        local byte = string.byte(nameUpper, i)
        seed = (seed * 33 + byte) % 0xFFFFFFFF   -- keep it 32-bit
    end

    -- Replace ~ (XOR) with bit32.bxor – fully supported in Roblox Luau
    seed = bit32.bxor(seed, tonumber(tostring({}):sub(8), 16) or 0)

    if useTime then
        seed = bit32.bxor(seed, math.floor(tick() % 1 * 1e6))
    end

    -- Final avalanche (makes low bits random too) – using only bit32 functions
    seed = bit32.bxor(seed, bit32.rshift(seed, 16))
    seed = (seed * 0x7FE73CE1) % 0xFFFFFFFF
    seed = bit32.bxor(seed, bit32.rshift(seed, 13))
    seed = (seed * 0x5A7D3F15) % 0xFFFFFFFF
    seed = bit32.bxor(seed, bit32.rshift(seed, 16))

    return seed
end

function utilMod.GetClosestPlayer(thisplayer)
    local thischar = thisplayer.Character
    if not thischar then return end
    local thisHRP = thischar:FindFirstChild("HumanoidRootPart")
    if not thisHRP then return end
    local thispos = thisHRP.Position

    local closest = nil
    local closestMag = math.huge  -- Use huge for first comparison

    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= thisplayer then  -- Use ~= for objects (safer than UserId)
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local mag = utilMod.GetMagnitude(hrp.Position, thispos)  -- Assumes this works
                    -- Or inline: (hrp.Position - thispos).Magnitude
                    if mag < closestMag then
                        closest = plr
                        closestMag = mag
                    end
                end
            end
        end
    end
    return closest
end


function utilMod.GetClosestModelSkipownPets(thisplayer, folderName)
    local character = thisplayer.Character
    if not character then return end
    
    local thisHRP = character:FindFirstChild("HumanoidRootPart")
    if not thisHRP then return end
    local thisPos = thisHRP.Position

    local folder = workspace:FindFirstChild(folderName)
    if not folder then return end

    local isPetFolder = (folderName == "Pets")  -- Cleaner check
    local closestModel = nil
    local closestDist = math.huge

    for _, model in pairs(folder:GetChildren()) do
        if model:IsA("Model") then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Skip player's own pet in Pets folder
                if isPetFolder then
                    local ownerId = model:GetAttribute("OwnedBy")
                    if ownerId and ownerId == thisplayer.UserId then
                        continue  -- Skip own pet
                    end
                end

                local dist = (hrp.Position - thisPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestModel = model
                end
            end
        end
    end

    return closestModel
end


function utilMod.GetEnemyModelsWithinRange(player, range)
    local character = player.Character
    if not character then return {} end
    
    local thisHRP = character:FindFirstChild("HumanoidRootPart")
    if not thisHRP then return {} end
    local thisPos = thisHRP.Position

    local petsFolder = workspace:FindFirstChild("Pets")
    local feralsFolder = workspace:FindFirstChild("Ferals")
    
    local enemies = {}

    -- Add other players' pets within range (exclude own pets)
    if petsFolder then
        for _, model in pairs(petsFolder:GetChildren()) do
            if model:IsA("Model") then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ownerId = model:GetAttribute("OwnedBy")
                    if ownerId ~= player.UserId then  -- Include if not owned by this player (or nil)
                        local dist = (hrp.Position - thisPos).Magnitude
                        if dist < range then
                            table.insert(enemies, model)
                        end
                    end
                end
            end
        end
    end

    -- Add all ferals within range
    if feralsFolder then
        for _, model in pairs(feralsFolder:GetChildren()) do
            if model:IsA("Model") then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - thisPos).Magnitude
                    if dist < range then
                        table.insert(enemies, model)
                    end
                end
            end
        end
    end

    return enemies
end

function utilMod.GetEnemyPlayersWithinRange(player, range)
    local character = player.Character
    if not character then return {} end
    
    local thisHRP = character:FindFirstChild("HumanoidRootPart")
    if not thisHRP then return {} end
    local thisPos = thisHRP.Position

    local petsFolder = workspace:FindFirstChild("Pets")
    local feralsFolder = workspace:FindFirstChild("ferals")
    
    local enemies = {}

    for _, enemyplr in game.Players:GetPlayers() do
        local enemhrp = enemyplr.Character:FindFirstChild("HumanoidRootPart")
        if not enemhrp then continue end
        if utilMod.GetMagnitude(thisHRP, enemhrp) < range then
            table.insert(enemies, enemyplr.Character)
        end
    end
end

function utilMod.MyPets(plr)
    local allpets = workspace:WaitForChild("Pets"):GetChildren()
    local pets = {}
    for _,pet in allpets do
        if pet:GetAttribute("OwnedBy") == plr.UserId then
            table.insert(pets, pet)
        end
    end
    return pets
end

return utilMod