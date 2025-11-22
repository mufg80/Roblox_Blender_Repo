local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local pathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local pathMod = {}

local activePaths = {}        -- [model] = true / connection

local function addModel(model)
    if not activePaths[model] then
        activePaths[model] = true
    end
end


function pathMod.PathfindToPosition(model, targetPosition, targetIdOrName)

    
    if activePaths[model.Name] then
        return false
    end
    
    addModel(model.Name)
    
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    local lastpos = rootPart.Position
    local startTick = tick()
    if not humanoid or not rootPart then
        activePaths[model.Name] = nil
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
        activePaths[model.Name] = nil
        return false
    end

    local waypoints = path:GetWaypoints()
    local currentWaypointIndex = 1
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not activePaths[model.Name] then
            connection:Disconnect()
            return
        end


        if not model.Parent then
            connection:Disconnect()
            activePaths[model.Name] = nil
            return
        end
        
        if currentWaypointIndex > #waypoints then
            connection:Disconnect()
            activePaths[model.Name] = nil
            return
        end
        if tick() - startTick > 1 then
    startTick = tick()
    if (rootPart.Position - lastpos).Magnitude < 1 then
        -- warn(string.format(
        --     "NOT MOVING! model=%s | rootPos=%s | lastPos=%s | targetPos=%s | targetIdOrName=%s | currentWaypointIndex=%d/%d | waypointPos=%s | distToWaypoint=%.2f | distToTarget=%.2f | humanoidState=%s",
        --     model.Name,
        --     tostring(rootPart.Position),
        --     tostring(lastpos),
        --     tostring(targetPosition),
        --     tostring(targetIdOrName),
        --     currentWaypointIndex,
        --     #waypoints,
        --     tostring(waypoints[currentWaypointIndex] and waypoints[currentWaypointIndex].Position or "nil"),
        --     utilMod.GetMagnitude(rootPart.Position, waypoints[currentWaypointIndex] and waypoints[currentWaypointIndex].Position or rootPart.Position),
        --     utilMod.GetMagnitude(rootPart.Position, targetPosition),
        --     tostring(humanoid:GetState())
        -- ))
        -- keep/disconnect depending on your test setup
        connection:Disconnect()
        activePaths[model.Name] = nil
    else
        lastpos = rootPart.Position
    end
end


       if targetIdOrName ~= "SpawnPoint" then
        local mob = utilMod.GetModelByIDorName(targetIdOrName)
        if mob then
            local mobhrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
            if mobhrp then
                local waysoff = utilMod.GetMagnitude(mobhrp.Position, targetPosition)
                
                if waysoff > 10 then  -- I recommend 10–15, not 5
                    -- RECURSIVE REPATH — seamless!
                    connection:Disconnect()
                    activePaths[model.Name] = nil
                    task.spawn(function()
                        -- Tiny delay so the stack doesn't grow during the same frame
                        task.wait()
                        pathMod.PathfindToPosition(model, mobhrp.Position, targetIdOrName)
                    end)
                    return
                end

            end
        end
    end
       



        local waypoint = waypoints[currentWaypointIndex]
        local distanceToWaypoint = utilMod.GetMagnitude(rootPart.Position, waypoint.Position)
        --local distancetoTargetPos = utilMod.GetMagnitude(rootPart.Position, targetPosition)

        
        if distanceToWaypoint < 3 and currentWaypointIndex ~= #waypoints then
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
            activePaths[model.Name] = nil
        end
    end)    
    return true
end

-- Safe public checker
function pathMod.IsPathActive(model)
    if not model then
        warn("should not reach here.")
    end
    return activePaths[model.Name] ~= nil
end


-- short circuit travel
function pathMod.ShortCircutTravel(model)
    if activePaths[model.Name] then
        activePaths[model.Name] = nil
    end
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
            local randomDistance = math.random(10, 20)
            local targetPosition = playerhrp.Position + direction * randomDistance
            local rightVector = playerhrp.CFrame.RightVector
            local randomOffset = math.random(-15, 15)
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
        local distanceForAttacker = enemyTable and enemyTable.distanceForAttacker - 1 or 4
        local direction = (enemyhrp.Position - hrp.Position).Unit
        local targetPosition = enemyhrp.Position - direction * distanceForAttacker
        return targetPosition
    end
    
    return nil
end

return pathMod