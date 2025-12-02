local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local pathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local pathMod = {}

local activePaths = {}        -- [model] = true / connection

local function addModel(model, targetIdOrName, connection)
    if not activePaths[model] then
        activePaths[model] = { connection = connection, targetIdOrName = targetIdOrName }
    end
end

-- NEW & FINAL VERSION – returns the real Instance when possible
function pathMod.GetCurrentTarget(model)
    local entry = activePaths[model]
    if not entry then
        return nil
    end

    local targetIdOrName = entry.targetIdOrName

    -- Case 1: We're pathfinding to the literal "SpawnPoint" string
    if targetIdOrName == "SpawnPoint" then
        return "SpawnPoint"
    end

    -- Case 2: targetIdOrName is already an Instance (Model) → return it directly
    if typeof(targetIdOrName) == "Instance" and targetIdOrName:IsA("Model") then
        -- Double-check it's still in the game (in case it was destroyed)
        if targetIdOrName.Parent then
            return targetIdOrName
        else
            return nil
        end
    end

    -- Case 3: It's a UserId (number) or name string → try to resolve the model
    local targetModel = utilMod.GetModelByIDorName(targetIdOrName)
    if targetModel and targetModel.Parent then
        return targetModel
    end

    -- Nothing valid found
    return nil
end


function pathMod.PathfindToPosition(model, targetPosition, targetIdOrName)

    
    if activePaths[model] then
        return false
    end
    local connection = nil
    addModel(model, targetIdOrName, connection)
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    local lastpos = rootPart.Position
    local startTick = tick()
    if not humanoid or not rootPart then
        activePaths[model] = nil
        return false
    end
    local pathTable = statsMod.Pathing[combatMod.customTrim(model.Name)]
    local path = pathfindingService:CreatePath(pathTable)

    local success, err = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        activePaths[model] = nil
        return false
    end

    local waypoints = path:GetWaypoints()
    local currentWaypointIndex = 1
    
    
    connection = RunService.Heartbeat:Connect(function()
        if not activePaths[model] then
            connection:Disconnect()
            return
        end

        if not model.Parent then
            connection:Disconnect()
            activePaths[model] = nil
            return
        end
        
        if currentWaypointIndex > #waypoints then
            connection:Disconnect()
            activePaths[model] = nil
            return
        end

-- REPLACE your entire stuck detection block (the if tick() - startTick > 1 and not lastchance ... end) with this FIXED version:

        if tick() - startTick > 1 then
            startTick = tick()
            if utilMod.GetDistance(lastpos, rootPart.Position) < 1 then
                connection:Disconnect()
                activePaths[model] = nil
                return
            else
                lastpos = rootPart.Position
            end
        end

       if targetIdOrName ~= "SpawnPoint" then
        local mob = utilMod.GetModelByIDorName(targetIdOrName)
        if mob then
            local mobhrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
            if mobhrp then
                local waysoff = utilMod.GetDistance(mobhrp.Position, targetPosition)
                
                if waysoff > 10 then  -- I recommend 10–15, not 5
                    -- RECURSIVE REPATH — seamless!
                    connection:Disconnect()
                    activePaths[model] = nil
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
        local distanceToWaypoint = utilMod.GetDistance(rootPart.Position, waypoint.Position)

        
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
            activePaths[model] = nil
        end
    end)
    return true
end

-- Safe public checker
function pathMod.IsPathActive(model)
    if not model then
        warn("should not reach here.")
    end
    return activePaths[model] ~= nil
end


-- short circuit travel
function pathMod.ShortCircuitTravel(model)
    if activePaths[model] then
        if activePaths[model].connection then
            activePaths[model].connection:Disconnect()
        end
        activePaths[model] = nil
    end
end

-- (GetTargetPet stays exactly the same as my previous fixed version)
function pathMod.GetTargetPet(model, targetIdOrName)
    -- ... [same as before – no changes needed here] ...
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not hrp then return nil end
    
    local owningId = model:GetAttribute("OwnedBy")
    if owningId == targetIdOrName then
        local player = game.Players:GetPlayerByUserId(owningId)
        if not player or not player.Character then return nil end
        
        local playerhrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChildWhichIsA("BasePart")
        if not playerhrp then return nil end
        
        local distance = utilMod.GetDistance(playerhrp.Position, hrp.Position)
        if distance >= 25 then

            local random = Random.new(utilMod.GetSeedFromName(model.Name))

            local direction = -playerhrp.CFrame.LookVector
            local randomDistance = random:NextInteger(10,20)
            local targetPosition = playerhrp.Position + direction * randomDistance
            local rightVector = playerhrp.CFrame.RightVector
            local randomOffset = random:NextInteger(-15,15)
            targetPosition = targetPosition + rightVector * randomOffset
            return targetPosition
        end
        return nil
    end
    
    local enemyTarget = utilMod.GetModelByIDorName(targetIdOrName)
    if not enemyTarget then return nil end
    
    local enemyhrp = enemyTarget:FindFirstChild("HumanoidRootPart") or enemyTarget:FindFirstChildWhichIsA("BasePart")
    if not enemyhrp then return nil end
    
    if not combatMod.AcceptableDistanceToOpponent(model, enemyTarget) then
        local enemyTable = combatMod.GetStatsSafelyForPlrorNpc(enemyTarget)
        local distanceForAttacker = ((enemyTable and enemyTable.distanceForAttacker) or 4) - 2
        local direction = (enemyhrp.Position - hrp.Position).Unit
        local targetPosition = enemyhrp.Position - direction * distanceForAttacker
        return targetPosition
    end
    
    return nil
end

return pathMod
