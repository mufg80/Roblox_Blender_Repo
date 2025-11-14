
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local creatureMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathfindingService = game:GetService("PathfindingService")

pathMod = {}

function pathMod.PathfindToPosition(pet, targetPosition)
    local humanoid = pet:FindFirstChildOfClass("Humanoid")
    local rootPart = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChild("Torso")
    
    if not humanoid or not rootPart then
        return false
    end
    local pathfindingService = game:GetService("PathfindingService")
    local path = pathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = false,
        WaypointSpacing = 3,
        Costs = {
            -- Optional: customize costs for different surfaces
            -- Water = 20
        }
    })

    -- Compute the path
    local success, errorMessage = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)

    if not success then
        warn("Path computation failed: " .. errorMessage)
        return false
    end

    if path.Status ~= Enum.PathStatus.Success then
        warn("Path blocked or no path found to target")
        return false
    end

    -- Get waypoints
    local waypoints = path:GetWaypoints()
    utilMod.SetFlagsForMoving(pet)

    -- Move through each waypoint
    for i, waypoint in ipairs(waypoints) do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(waypoint.Position)

        -- Wait until reached or timeout
        local reached = false
        local connection
        local timeout = 8 -- seconds

        connection = humanoid.MoveToFinished:Connect(function(success)
            reached = success
            if connection then
                connection:Disconnect()
            end
        end)

        -- Wait with timeout
        local elapsed = 0
        while not reached and elapsed < timeout do
            task.wait(0.1)
            elapsed += 0.1
        end

        if connection then
            connection:Disconnect()
        end

        if not reached then
            warn("Pet timed out moving to waypoint " .. i)
            return false
        end

        -- Optional: break early if target is close enough to last waypoint
        -- if i == #waypoints then
        --     local distance = (rootPart.Position - targetPosition).Magnitude
        --     if distance < 5 then
        --         break
        --     end
        -- end
    end
    utilMod.SetFlagsForIdle(pet)
    return true
end

function pathMod.GetTargetPet(pet)
    local hrp = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChildWhichIsA("BasePart")
    local HasFallen = pet:GetAttribute("HasFallen")
    if HasFallen then
        return nil
    end
    local InCombat = pet:GetAttribute("InCombat")
    if InCombat then
        local target = pet:GetAttribute("TargetIDorName")
        if not target then
            return nil
        end
        local enemyTarget = utilMod.GetModelByIDorName(target)
        if not enemyTarget then
            return nil
        end
        local enemyhrp = enemyTarget:FindFirstChild("HumanoidRootPart") or enemyTarget:FindFirstChildWhichIsA("BasePart")
        if not enemyhrp then
            return nil
        end
        local enemytable = creatureMod.GetCreatureTableFromModel(enemyTarget)
        if not enemytable then
            return nil
        end
        local distance = (hrp.Position - enemyhrp.Position).Magnitude
        if utilMod.AcceptableDistanceToOpponent(pet, enemyTarget) then
            -- find position on straightline between enemyhrp and hrp at distanceforattacker variable
            local direction = (hrp.Position - enemyhrp.Position).Unit
            local targetPosition = enemyhrp.Position + direction * enemytable.distanceForAttacker
            return targetPosition
        else
            return nil
        end
    end
    local IsMoving = pet:GetAttribute("IsMoving")
    if IsMoving then
        return nil
    end
    local IsIdle = pet:GetAttribute("IsIdle")

    if IsIdle then
        local OwnedBy = pet:GetAttribute("OwnedBy")
        if not OwnedBy then
            return nil
        end
        local player = utilMod.GetPlayerByUserId(OwnedBy)
        if not player then
            return nil
        end
        local character = player.Character
        if not character then
            return nil
        end
        local playerhrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
        if not playerhrp then
            return nil
        end
        local distance = (hrp.Position - playerhrp.Position).Magnitude
        if distance >= 20 then
            print("Pet is idle and too far from owner, moving closer.")
            -- find random location behind player within 5 to 10 studs
            local direction = -playerhrp.CFrame.LookVector
            local randomDistance = math.random(5, 20)
            local targetPosition = playerhrp.Position + direction * randomDistance

            -- add a random offset to this targetposition using rightvector and a value of -5 to 5
            local rightVector = playerhrp.CFrame.RightVector
            local randomOffset = math.random(-5, 5)
            targetPosition = targetPosition + rightVector * randomOffset
            return targetPosition
        end
    end
end

return pathMod