-- ArtifactGuardian NPC (Standalone Enemy with combat integration, no StateEvents)
local thisMob = "FeralArtifactGuardian"
local model = script.Parent

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathMod = require(game.ReplicatedStorage.Shared.pathMod)

local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then return end

-- === Creature stats from combatMod ===
local baseStats = combatMod.ShallowTableCopy(thisMob)

-- Apply stats to humanoid
humanoid.MaxHealth = baseStats.hitPoints
humanoid.Health = baseStats.hitPoints
humanoid.WalkSpeed = 16 * baseStats.speed   -- Roblox default WalkSpeed is 16

-- === Configurable NPC Settings ===
local IsStationary = model:GetAttribute("IsStationary") or true
local AggroRadius = model:GetAttribute("AggroRadius") or baseStats.aggroRadius or 40
local RangeLimit = model:GetAttribute("RangeLimit") or 80
local IdleReset = model:GetAttribute("IdleReset") or 5   -- seconds before returning to spawn
local spawnPosition = hrp.Position

-- === Animations ===
local animator = humanoid:FindFirstChildOfClass("Animator")
local animTracks = {}
if animator then
    animTracks.idle = animator:LoadAnimation(model:FindFirstChild("ArtGuardIdle")); animTracks.idle.Looped = true
    animTracks.blink = animator:LoadAnimation(model:FindFirstChild("ArtGuardBlink")); animTracks.blink.Looped = false
    animTracks.death = animator:LoadAnimation(model:FindFirstChild("ArtGuardFall")); animTracks.death.Looped = false
    animTracks.attack1 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt1")); animTracks.attack1.Looped = false
    animTracks.attack2 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt2")); animTracks.attack2.Looped = false
    animTracks.attack3 = animator:LoadAnimation(model:FindFirstChild("ArtGuardAtt3")); animTracks.attack3.Looped = false
end

-- === Main Loop ===
task.spawn(function()
    -- Blink loop
    task.spawn(function()
        while task.wait(math.random(4,15)) do
            if animTracks.blink and not model:GetAttribute("HasFallen") then
                animTracks.blink:Play()
            end
        end
    end)

    local lastAttackTime = 0
    local ATTACK_COOLDOWN = combatMod.DELAY * baseStats.attackDelay

    -- Track idle time
    local idleStartTime = tick()

    while task.wait(0.03) do
        -- Death check
        if humanoid.Health <= 0 then
            if not model:GetAttribute("HasFallen") then
                utilMod.SetFlagsForDeath(model)
            end
            continue
        end

        -- Target validity
        local identifier = model:GetAttribute("TargetIDorName")
        if identifier ~= "None" and model:GetAttribute("InCombat") then
            local target = utilMod.GetModelByIDorName(identifier)
            if not target or target:GetAttribute("HasFallen") then
                model:SetAttribute("TargetIDorName","None")
                utilMod.SetFlagsForIdle(model)
            end
        end

        -- Aggro check
        if not model:GetAttribute("InCombat") then
            local enemiescloseby = {}
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local phrp = char and char:FindFirstChild("HumanoidRootPart")
                if phrp then
                    local distance = utilMod.GetMagnitude(phrp, hrp)
                    if distance < AggroRadius then
                        table.insert(enemiescloseby, player.UserId)
                    end
                end
            end
            if #enemiescloseby > 0 then
                local randomTarget = enemiescloseby[math.random(1,#enemiescloseby)]
                model:SetAttribute("TargetIDorName", randomTarget)
                utilMod.SetFlagsForCombat(model)
            end
        else
            -- Range limit check
            local target = utilMod.GetModelByIDorName(model:GetAttribute("TargetIDorName"))
            if target and target:FindFirstChild("HumanoidRootPart") then
                local distance = utilMod.GetMagnitude(target.HumanoidRootPart, hrp)
                if distance > RangeLimit then
                    model:SetAttribute("TargetIDorName","None")
                    utilMod.SetFlagsForIdle(model)
                end
            end
        end

        -- Pathfinding
        local targetPosition = nil
        if model:GetAttribute("InCombat") and model:GetAttribute("TargetIDorName") ~= "None" then
            targetPosition = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"))
            idleStartTime = tick() -- reset idle timer when in combat
        elseif not IsStationary and model:GetAttribute("IsIdle") and not model:GetAttribute("IsMoving") and not pathMod.IsPathActive(model) then
            -- roam near spawn
            local offset = Vector3.new(math.random(-20,20),0,math.random(-20,20))
            targetPosition = spawnPosition + offset
            idleStartTime = tick() -- reset idle timer when roaming
        else
            -- Idle reset check
            if model:GetAttribute("IsIdle") and (tick() - idleStartTime) >= IdleReset then
                local distanceFromSpawn = (hrp.Position - spawnPosition).Magnitude
                if distanceFromSpawn > 5 and not pathMod.IsPathActive(model) then
                    pathMod.PathfindToPosition(model, spawnPosition)
                    idleStartTime = tick() -- reset timer after sending home
                end
            end
        end

        if targetPosition and not pathMod.IsPathActive(model) then
            pathMod.PathfindToPosition(model, targetPosition)
        end

        -- Animation & Combat
        if model:GetAttribute("HasFallen") then
            -- death handled
        elseif model:GetAttribute("InCombat") then
            if animTracks.idle.IsPlaying then animTracks.idle:Stop() end
            local now = tick()
            if now - lastAttackTime > ATTACK_COOLDOWN then
                local attackChoice = math.random(1,3)
                local track = animTracks["attack"..attackChoice]
                if track and not track.IsPlaying then
                    track:Play()
                    lastAttackTime = now

                    -- Damage application
                    local targetModel = utilMod.GetModelByIDorName(model:GetAttribute("TargetIDorName"))
                    if targetModel then
                        local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
                        if targetHumanoid then
                            local defenderStats = utilMod.GetStatsSafelyForPlrorNpc(targetHumanoid.Parent)
                            local damage = combatMod.MeleeAttackResult(baseStats, defenderStats)
                            targetHumanoid.Health = math.max(targetHumanoid.Health - damage, 0)
                        end
                    end
                end
            end
        elseif model:GetAttribute("IsMoving") or model:GetAttribute("IsIdle") then
            if not animTracks.idle.IsPlaying then animTracks.idle:Play() end
            animTracks.idle:AdjustSpeed(model:GetAttribute("IsMoving") and 1.5 or 1.0)
        end
    end
end)
