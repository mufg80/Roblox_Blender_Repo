local thisMob = "ArtifactGuardian"
local model = script.Parent

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local height = game:GetService("ServerStorage"):FindFirstChild("Entities"):FindFirstChild(thisMob):FindFirstChild("HumanoidRootPart").Position.Y

local utilMod = require(game:GetService("ReplicatedStorage").Shared.utilMod)
local combatMod = require(game:GetService("ReplicatedStorage").Shared.combatMod)
local pathMod = require(game:GetService("ReplicatedStorage").Shared.pathMod)

local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then return end

local baseStats = combatMod.ShallowTableCopy(thisMob)

-- === 4. BindableEvents for real-time state changes ===
local StateEvents = Instance.new("Folder")
StateEvents.Name = "StateEvents"
StateEvents.Parent = model

local OwnedByChanged = Instance.new("BindableEvent"); OwnedByChanged.Name = "OwnedByChanged"; OwnedByChanged.Parent = StateEvents
local HasFallenChanged = Instance.new("BindableEvent"); HasFallenChanged.Name = "HasFallenChanged"; HasFallenChanged.Parent = StateEvents
local InCombatChanged = Instance.new("BindableEvent"); InCombatChanged.Name = "InCombatChanged"; InCombatChanged.Parent = StateEvents
local IsIdleChanged = Instance.new("BindableEvent"); IsIdleChanged.Name = "IsIdleChanged"; IsIdleChanged.Parent = StateEvents
local IsMovingChanged = Instance.new("BindableEvent"); IsMovingChanged.Name = "IsMovingChanged"; IsMovingChanged.Parent = StateEvents

-- === Initial state ===
local owningId = model:GetAttribute("OwnedBy")
local hasFallen = model:GetAttribute("HasFallen")
local inCombat = model:GetAttribute("InCombat")
local isIdle = model:GetAttribute("IsIdle")
local isMoving = model:GetAttribute("IsMoving")

-- === Sync attributes → fire events ===
for _, attrName in pairs({"OwnedBy", "HasFallen", "InCombat", "IsIdle", "IsMoving"}) do
    model:GetAttributeChangedSignal(attrName):Connect(function()
        local value = model:GetAttribute(attrName)
        local event = StateEvents:FindFirstChild(attrName .. "Changed")
        if event then
            event:Fire(value)
        end
    end)
end

-- === 5. Preloaded Animation Tracks ===
local animator = humanoid:FindFirstChildOfClass("Animator")
local animTracks = {}
if animator then
    animTracks.idle = animator:LoadAnimation(model:FindFirstChild("ArtGuardIdle"))
    animTracks.idle.Looped = true
    animTracks.blink = animator:LoadAnimation(model:FindFirstChild("ArtGuardBlink"))
    animTracks.blink.Looped = false
    animTracks.death = animator:LoadAnimation(model:FindFirstChild("ArtGuardFall"))
    animTracks.death.Looped = false
    animTracks.attack1 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt1"))
    animTracks.attack1.Looped = false
    animTracks.attack2 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt2"))
    animTracks.attack2.Looped = false
    animTracks.attack3 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt3"))
    animTracks.attack3.Looped = false
end

-- === 3. Single Heartbeat: Main Loop (Ground, Turn, Anim, State) ===
local connections = {}
local threads = {}

-- connections.heartbeat = RunService.Heartbeat:Connect(function(dt)
--     -- === Ground Snap ===
--    if not isMoving then  -- Not moving to waypoint
--         local charactertags = utilMod.GetCharactersTagged()
--         local hrploc = utilMod.DistancetoGround(hrp.Position.X, hrp.Position.Z, charactertags, height)
--         if hrploc then
--             local movement = hrp.Position.Y - hrploc
--             hrp.CFrame = hrp.CFrame - Vector3.new(0, movement, 0)
--         end
--     end

--     -- === Smooth Turn in Combat ===
--     if inCombat then
--         local targetID = model:GetAttribute("TargetIDorName")
--         local enemyTarget = utilMod.GetModelByIDorName(targetID)

--         if enemyTarget and enemyTarget.PrimaryPart and utilMod.AcceptableDistanceToOpponent(hrp, enemyTarget) then
--             local myPos = hrp.Position
--             local enemyPos = enemyTarget.PrimaryPart.Position
--             local lookDir = (enemyPos - myPos) * Vector3.new(1, 0, 1)

--             if lookDir.Magnitude > 0.01 then
--                 local desiredCFrame = CFrame.new(myPos, myPos + lookDir)
--                 local currentForward = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
--                 currentForward = currentForward.Unit

--                 local angle = math.acos(math.clamp(currentForward:Dot(lookDir.Unit), -1, 1))
--                 if angle > 0.01 then
--                     local turnThisFrame = math.min(angle, 8 * dt, math.rad(15))
--                     local axis = currentForward:Cross(lookDir.Unit)
--                     local rotIncrement = CFrame.fromAxisAngle(axis, turnThisFrame)
--                     hrp.CFrame = CFrame.new(hrp.Position) * (rotIncrement * hrp.CFrame - hrp.Position)
--                 end
--             end
--         end
--     end
-- end)

-- === 1. & 2. Character State & Animation Logic (task.wait + :Once) ===
threads.stateAndAnim = task.spawn(function()
    -- === Blink Loop (random blink) ===
    task.spawn(function()
        while task.wait(math.random(4, 15)) do
            if animTracks.blink and not hasFallen then
                animTracks.blink:Play()
                animTracks.blink.Stopped:Once(function() end)
            end
        end
    end)

    -- === Main State + Animation Loop ===
    while task.wait(0.1) do
        -- Exit if fallen or dead
        if hasFallen or baseStats.hitPoints < 1 then
            if baseStats.hitPoints < 1 then
                utilMod.SetFlagsForDeath(model)
            end
            break
        end

        -- === Pathfinding & Movement ===
        local targetPosition = pathMod.GetTargetPet(model)
        if targetPosition then
            local success = pathMod.PathfindToPosition(model, targetPosition)
            local target = model:GetAttribute("TargetIDorName")
            if success and inCombat and utilMod.AcceptableDistanceToOpponent(model, target) then
                utilMod.SetFlagsForCombat(model)
            else
                utilMod.SetFlagsForIdle(model)
            end
        else
            utilMod.SetFlagsForIdle(model)
        end

        -- === Animation State Machine ===
        if hasFallen then
            if animTracks.death and not animTracks.death.IsPlaying then
                animTracks.death:Play()
                animTracks.death.Stopped:Once(function()
                    Debris:AddItem(model, 5)
                end)
            end
        elseif inCombat then
            -- Stop idle animations
            if animTracks.idle.IsPlaying then animTracks.idle:Stop() end

            -- Play random attack
            local attackChoice = math.random(1, 3)
            local attackTrack = animTracks["attack" .. attackChoice]
            if attackTrack and not attackTrack.IsPlaying then
                attackTrack:Play()
                attackTrack.Stopped:Once(function() end)
            end
        elseif isMoving then
            -- Idle / Moving
            if not animTracks.idle.IsPlaying then
				animTracks.idle:Stop()
            else
                animTracks.idle:Play()
            end
        elseif isIdle then
            if not animTracks.idle.IsPlaying then
                 animTracks.idle:Play()
            end
           
        end
    end
end)

-- === State Event Listeners (Real-time Updates) ===
connections.ownedBy = OwnedByChanged.Event:Connect(function(value) owningId = value end)
connections.hasFallen = HasFallenChanged.Event:Connect(function(value) hasFallen = value end)
connections.inCombat = InCombatChanged.Event:Connect(function(value) inCombat = value end)
connections.isIdle = IsIdleChanged.Event:Connect(function(value) isIdle = value end)
connections.isMoving = IsMovingChanged.Event:Connect(function(value) isMoving = value end)

-- === Cleanup on Destruction ===
model.AncestryChanged:Connect(function()
    if not model.Parent then
        -- Disconnect all
        for _, conn in pairs(connections) do
            if conn.Connected then
                conn:Disconnect()
            end
        end

        -- Cancel all threads
        for _, thread in pairs(threads) do
            if task.is_running(thread) then
                task.cancel(thread)
            end
        end

        -- Clean up BindableEvents
        StateEvents:Destroy()
    end
end)