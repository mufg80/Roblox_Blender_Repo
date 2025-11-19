-- FeralArtifactGuardian NPC - FINAL POLISHED VERSION (Nov 19, 2025)
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

-- === Stats ===
local baseStats = combatMod.ShallowTableCopy(thisMob)
humanoid.MaxHealth = baseStats.hitPoints
humanoid.Health = baseStats.hitPoints
humanoid.WalkSpeed = 16 * baseStats.speed

-- === Configurable Settings ===
local IsStationary = model:GetAttribute("IsStationary") ~= false
local AggroRadius = model:GetAttribute("AggroRadius") or baseStats.aggroRadius or 40
local IdleReset = model:GetAttribute("IdleReset") or 5
local spawnPosition = hrp.Position

-- === Threat API ===
local AddThreatEvent = Instance.new("BindableEvent")
AddThreatEvent.Name = "AddThreat"
AddThreatEvent.Parent = model

local hateList = {}

AddThreatEvent.Event:Connect(function(attackerId, amount)
    if typeof(attackerId) == "number" or typeof(attackerId) == "string" then
        hateList[attackerId] = (hateList[attackerId] or 0) + (amount or 0)
    end
end)

-- === THREAT FROM TAKING DAMAGE (FIXED & WORKING) ===
humanoid.HealthChanged:Connect(function(health)
    local damageTaken = humanoid.Health - health
    humanoid.Health = health

    local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")
    if creator and creator.Value then
        local attacker = creator.Value
        local attackerId = attacker:IsA("Player") and attacker.UserId or attacker.Name
        AddThreatEvent:Fire(attackerId, damageTaken * 2.5 + 30)
    end
end)

-- === Animations ===
local animator = humanoid:FindFirstChildOfClass("Animator")
local animTracks = {}
if animator then
    local function load(name, looped)
        local anim = model:FindFirstChild(name)
        if anim then
            local track = animator:LoadAnimation(anim)
            if looped ~= nil then track.Looped = looped end
            return track
        end
    end
    animTracks.idle    = load("ArtGuardIdle", true)
    animTracks.blink   = load("ArtGuardBlink", false)
    animTracks.death   = load("ArtGuardFall", false)
    animTracks.attack1 = load("ArtGuardAtt1", false)
    animTracks.attack2 = load("ArtGuardAtt2", false)
    animTracks.attack3 = load("ArtGuardAtt3", false)
end

task.spawn(function()
    while true do
        print(hateList)
        task.wait(5)
    end

end)

-- === MAIN LOOP ===
task.spawn(function()
    -- Blink loop
    task.spawn(function()
        while task.wait(math.random(6,14)) do
            if animTracks.blink and not model:GetAttribute("HasFallen") then
                animTracks.blink:Play()
            end
        end
    end)

    local lastAttackTime = 0
    local ATTACK_COOLDOWN = combatMod.DELAY * baseStats.attackDelay
    local idleStartTime = tick()

    while task.wait(0.03) do
        ----------------------------------------------------------------
        -- DEATH HANDLING
        ----------------------------------------------------------------
        if humanoid.Health <= 0 then
            if not model:GetAttribute("HasFallen") then
                utilMod.SetFlagsForDeath(model)

                if animTracks.death then
                    animTracks.death:Play()
                    animTracks.death.Stopped:Once(function()
                        if not model.Parent then return end
                        animTracks.death.TimePosition = animTracks.death.Length - 0.02
                        animTracks.death:AdjustSpeed(0)
                        humanoid.PlatformStand = true
                        Debris:AddItem(model, 5)
                    end)
                else
                    humanoid.PlatformStand = true
                    Debris:AddItem(model, 5)
                end
            end
            task.wait(0.1)
            continue
        end

        ----------------------------------------------------------------
        -- THREAT / TARGET SELECTION
        ----------------------------------------------------------------
        local aggroSqr = AggroRadius ^ 2
        local leashSqr = (AggroRadius * 3) ^ 2

        -- Add nearby threats
        for _, player in ipairs(Players:GetPlayers()) do
            local root = player.Character and (player.Character.HumanoidRootPart or player.Character:FindFirstChild("Torso"))
            if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr and not hateList[player.UserId] then
                hateList[player.UserId] = 10
            end
        end

        local petsFolder = workspace:FindFirstChild("Pets")
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if pet ~= model then
                    local root = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChild("Torso")
                    if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr and not hateList[pet.Name] then
                        hateList[pet.Name] = 4
                    end
                end
            end
        end

        -- Leash + decay
        for id, threat in pairs(hateList) do
            local target = utilMod.GetModelByIDorName(id)
            local root = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
            local hum = target and target:FindFirstChildOfClass("Humanoid")
            
            if not root or (root.Position - hrp.Position).Magnitude^2 > leashSqr then
                hateList[id] = nil
            elseif target and hum and hum.Health < 0 or target:GetAttribute("HasFallen") then
                hateList[id] = nil
            else
                hateList[id] = threat * 0.995
            end
        end

        -- Choose highest threat
        local bestId, bestThreat = "None", 0
        for id, threat in pairs(hateList) do
            if threat > bestThreat then
                local target = utilMod.GetModelByIDorName(id)
                if target and not target:GetAttribute("HasFallen") and target:FindFirstChildOfClass("Humanoid") then
                    bestId = id
                    bestThreat = threat
                else
                    hateList[id] = nil
                end
            end
        end

        local currentTargetId = model:GetAttribute("TargetIDorName")
        if bestThreat > 0 then
            if currentTargetId ~= bestId then
                model:SetAttribute("TargetIDorName", bestId)
            end
            if not model:GetAttribute("InCombat") then
                utilMod.SetFlagsForCombat(model)
            end
        elseif currentTargetId ~= "None" then
            model:SetAttribute("TargetIDorName", "None")
            utilMod.SetFlagsForIdle(model)
        end

        ----------------------------------------------------------------
        -- MOVEMENT & PATHFINDING
        ----------------------------------------------------------------
        local wantsToMove = false

        if model:GetAttribute("InCombat") and currentTargetId ~= "None" then
            local targetModel = utilMod.GetModelByIDorName(currentTargetId)
            local targetHRP = targetModel and (targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso"))

            if targetHRP then
                local distance = (hrp.Position - targetHRP.Position).Magnitude

                -- CLOSE RANGE HANDLING: Direct MoveTo + smart stop
                if distance <= 7 then
                    local stats = utilMod.GetStatsSafelyForPlrorNpc(targetModel)
                    local idealRange = stats and stats.distanceForAttacker or 4

                    if distance < idealRange then
                        humanoid:MoveTo(hrp.Position)
                        wantsToMove = false
                    else
                        humanoid:MoveTo(targetHRP.Position)
                        wantsToMove = true
                    end
                else
                    -- Normal pathfinding when farther away
                    if not pathMod.IsPathActive(model) or not utilMod.AcceptableDistanceToOpponent(model, targetModel) then
                        local pos = pathMod.GetTargetPet(model, currentTargetId)
                        if pos then
                            pathMod.PathfindToPosition(model, pos)
                            wantsToMove = true
                        end
                    end
                end
            end

        elseif not IsStationary and model:GetAttribute("IsIdle") then
            -- Roam or return to spawn
            if tick() - idleStartTime >= IdleReset then
                if (hrp.Position - spawnPosition).Magnitude > 5 and not pathMod.IsPathActive(model) then
                    pathMod.PathfindToPosition(model, spawnPosition)
                    idleStartTime = tick()
                    wantsToMove = true
                end
            elseif not pathMod.IsPathActive(model) then
                local offset = Vector3.new(math.random(-20,20), 0, math.random(-20,20))
                pathMod.PathfindToPosition(model, spawnPosition + offset)
                idleStartTime = tick()
                wantsToMove = true
            end
        end

        -- Update flags
        if wantsToMove then
            if not model:GetAttribute("IsMoving") then utilMod.SetFlagsForMoving(model) end
        elseif model:GetAttribute("IsMoving") then
            utilMod.SetFlagsForIdle(model)
        end

        ----------------------------------------------------------------
        -- FACE TARGET
        ----------------------------------------------------------------
        if model:GetAttribute("InCombat") and currentTargetId ~= "None" and not pathMod.IsPathActive(model) then
            local targetModel = utilMod.GetModelByIDorName(currentTargetId)
            local tHRP = targetModel and (targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso"))
            if tHRP then
                local dir = Vector3.new((tHRP.Position - hrp.Position).X, 0, (tHRP.Position - hrp.Position).Z)
                if dir.Magnitude > 0.1 then
                    hrp.CFrame = hrp.CFrame:lerp(CFrame.lookAt(hrp.Position, hrp.Position + dir), 0.3)
                end
            end
        end

        ----------------------------------------------------------------
        -- COMBAT
        ----------------------------------------------------------------
        if model:GetAttribute("InCombat") and currentTargetId ~= "None" then
            local targetModel = utilMod.GetModelByIDorName(currentTargetId)
            if targetModel and utilMod.AcceptableDistanceToOpponent(model, targetModel) then
                if animTracks.idle and animTracks.idle.IsPlaying then animTracks.idle:Stop() end

                if tick() - lastAttackTime >= ATTACK_COOLDOWN then
                    local track = animTracks["attack" .. math.random(1,3)]
                    if track and not track.IsPlaying then
                        track:Play()
                        lastAttackTime = tick()

                        local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
                        if targetHum then
                            local creator = Instance.new("ObjectValue")
                            creator.Name = "creator"
                            creator.Value = model
                            creator.Parent = targetHum
                            task.delay(0.5, function()
                                if creator.Parent then creator:Destroy() end
                            end)

                            local defStats = utilMod.GetStatsSafelyForPlrorNpc(targetModel)
                            local damage = combatMod.MeleeAttackResult(baseStats, defStats)
                            targetHum.Health = math.max(targetHum.Health - damage, 0)

                            hateList[currentTargetId] = (hateList[currentTargetId] or 0) + damage * 1.4 + 10
                        end
                    end
                end
            end
        elseif not model:GetAttribute("InCombat") and (model:GetAttribute("IsMoving") or model:GetAttribute("IsIdle")) then
            if animTracks.idle and not animTracks.idle.IsPlaying then animTracks.idle:Play() end
            if animTracks.idle then
                animTracks.idle:AdjustSpeed(model:GetAttribute("IsMoving") and 1.5 or 1.0)
            end
        end
    end
end)