local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local creatureMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local pathMod = {}

-- SIMPLE & SAFE unique identifier system (no PluginSecurity needed)
local activePaths = {}        -- [model] = true / connection
local modelToKey = {}         -- [model] = unique string key (for cleanup)

local function getKey(model)
    if not modelToKey[model] then
        modelToKey[model] = tostring(model) .. "_" .. tick() .. "_" .. math.random(1, 1e6)
    end
    return modelToKey[model]
end

-- NON-BLOCKING Pathfinding (unchanged logic, safe key)
function pathMod.PathfindToPosition(model, targetPosition)
    local key = getKey(model)
    if activePaths[key] then return false end
    
    activePaths[key] = true
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    
    if not humanoid or not rootPart then
        activePaths[key] = nil
        return false
    end

    local path = pathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = false,
        WaypointSpacing = 3,
    })

    local success, err = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        activePaths[key] = nil
        return false
    end

    local waypoints = path:GetWaypoints()
    local currentWaypointIndex = 1
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not model.Parent then
            connection:Disconnect()
            activePaths[key] = nil
            return
        end
        
        if currentWaypointIndex > #waypoints then
            connection:Disconnect()
            activePaths[key] = nil
            return
        end
        
        local waypoint = waypoints[currentWaypointIndex]
        local distanceToWaypoint = (rootPart.Position - waypoint.Position).Magnitude
        
        if distanceToWaypoint < 4 then
            currentWaypointIndex += 1
        else
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid:MoveTo(waypoint.Position)
        end
    end)
    
    -- Auto-cleanup if model is destroyed
    model.AncestryChanged:Connect(function()
        if not model.Parent then
            if connection then connection:Disconnect() end
            activePaths[key] = nil
            modelToKey[model] = nil
        end
    end)
    
    return true
end

-- Safe public checker
function pathMod.IsPathActive(model)
    return activePaths[getKey(model)] ~= nil
end

-- (GetTargetPet stays exactly the same as my previous fixed version)
function pathMod.GetTargetPet(model, targetIdOrName)
    -- ... [same as before – no changes needed here] ...
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not hrp then return nil end
    
    local owningId = model:GetAttribute("OwnedBy")
    if owningId == targetIdOrName then
        local player = utilMod.GetPlayerByUserId(owningId)
        if not player or not player.Character then return nil end
        
        local playerhrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChildWhichIsA("BasePart")
        if not playerhrp then return nil end
        
        local distance = utilMod.GetMagnitude(playerhrp, hrp)
        if distance >= 25 then
            local direction = -playerhrp.CFrame.LookVector
            local randomDistance = math.random(5, 20)
            local targetPosition = playerhrp.Position + direction * randomDistance
            local rightVector = playerhrp.CFrame.RightVector
            local randomOffset = math.random(-5, 5)
            targetPosition = targetPosition + rightVector * randomOffset
            return targetPosition
        end
        return nil
    end
    
    local enemyTarget = utilMod.GetModelByIDorName(targetIdOrName)
    if not enemyTarget then return nil end
    
    local enemyhrp = enemyTarget:FindFirstChild("HumanoidRootPart") or enemyTarget:FindFirstChildWhichIsA("BasePart")
    if not enemyhrp then return nil end
    
    if not utilMod.AcceptableDistanceToOpponent(model, enemyTarget) then
        local enemyTable = utilMod.GetStatsSafelyForPlrorNpc(enemyTarget)
        local distanceForAttacker = enemyTable and enemyTable.distanceForAttacker or 4
        local direction = (enemyhrp.Position - hrp.Position).Unit
        local targetPosition = enemyhrp.Position - direction * distanceForAttacker
        return targetPosition
    end
    
    return nil
end

return pathMod