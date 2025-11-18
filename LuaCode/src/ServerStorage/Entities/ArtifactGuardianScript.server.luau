-- ArtifactGuardian Pet Script (with combat integration, no StateEvents)
local thisMob = "ArtifactGuardian"
local model = script.Parent

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local utilMod = require(game:GetService("ReplicatedStorage").Shared.utilMod)
local combatMod = require(game:GetService("ReplicatedStorage").Shared.combatMod)
local pathMod = require(game:GetService("ReplicatedStorage").Shared.pathMod)

local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then return end

-- === Creature stats from combatMod ===
local baseStats = combatMod.ShallowTableCopy(thisMob)

-- Apply stats to humanoid
humanoid.MaxHealth = baseStats.hitPoints
humanoid.Health = baseStats.hitPoints
humanoid.WalkSpeed = 16 * baseStats.speed   -- Roblox default WalkSpeed is 16

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

-- === Threads ===
local threads = {}

-- === Main Loop ===
threads.stateAndAnim = task.spawn(function()
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
            local allpets = workspace:WaitForChild("Pets"):GetChildren()
            local allferals = workspace:WaitForChild("Ferals"):GetChildren()
            for _, pet in pairs(allpets) do
                local enemyhrp = pet:FindFirstChild("HumanoidRootPart")
                if enemyhrp then
                    local dis = utilMod.GetMagnitude(enemyhrp, hrp)
                    if dis < baseStats.aggroRadius and pet:GetAttribute("OwnedBy") ~= model:GetAttribute("OwnedBy") then
                        table.insert(enemiescloseby, pet.Name)
                    end
                end
            end
            for _, feral in pairs(allferals) do
                local enemyhrp = feral:FindFirstChild("HumanoidRootPart")
                if enemyhrp then
                    local dis = utilMod.GetMagnitude(enemyhrp, hrp)
                    if dis < baseStats.aggroRadius then
                        table.insert(enemiescloseby, feral.Name)
                    end
                end
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local playerhrp = player.Character.HumanoidRootPart
                    local distance = utilMod.GetMagnitude(playerhrp, hrp)
                    if player.UserId ~= model:GetAttribute("OwnedBy") and distance < baseStats.aggroRadius then
                        table.insert(enemiescloseby, player.UserId)
                    end
                end
            end
            if #enemiescloseby > 0 then
                local randomTarget = enemiescloseby[math.random(1,#enemiescloseby)]
                model:SetAttribute("TargetIDorName", randomTarget)
                utilMod.SetFlagsForCombat(model)
            end
        end

        -- Pathfinding
        local targetPosition = nil
        if model:GetAttribute("InCombat") and model:GetAttribute("TargetIDorName") ~= "None" then
            targetPosition = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"))
        elseif model:GetAttribute("IsIdle") and not model:GetAttribute("IsMoving") and not pathMod.IsPathActive(model) then
            targetPosition = pathMod.GetTargetPet(model, model:GetAttribute("OwnedBy"))
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

-- === Cleanup ===
model.AncestryChanged:Connect(function()
    if not model.Parent then
        for _, thread in pairs(threads) do
            if task.is_running(thread) then task.cancel(thread) end
        end
    end
end)
