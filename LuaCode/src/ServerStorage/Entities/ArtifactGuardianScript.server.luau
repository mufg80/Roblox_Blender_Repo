-- ArtifactGuardian Pet Script - FINAL POLISHED VERSION (Nov 19, 2025)
local thisMob = "ArtifactGuardian"
local thisFeralMob = "FeralArtifactGuardian"
local model = script.Parent

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathMod = require(game.ReplicatedStorage.Shared.pathMod)
local aggroMod = require(game.ReplicatedStorage.Shared.aggroMod)

local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then return end

local baseStats= combatMod.ShallowTableCopy(thisMob)

local IsStationary = model:GetAttribute("IsStationary") ~= false
local IdleReset = model:GetAttribute("IdleReset") or 5
local spawnPosition = hrp.Position

function setStats()
    if model:GetAttribute("OwnedBy") == "None" or model:GetAttribute("OwnedBy") == "" then
        baseStats = combatMod.ShallowTableCopy(thisFeralMob)
        humanoid.MaxHealth = baseStats.hitPoints
        humanoid.Health = baseStats.hitPoints
        humanoid.WalkSpeed = 16 * baseStats.speed
        IsStationary = model:GetAttribute("IsStationary") ~= false
        IdleReset = model:GetAttribute("IdleReset") or 5
        spawnPosition = hrp.Position
    else
        baseStats = combatMod.ShallowTableCopy(thisMob)
        humanoid.MaxHealth = baseStats.hitPoints
        humanoid.Health = baseStats.hitPoints
        humanoid.WalkSpeed = 16 * baseStats.speed
    end
end

model:GetAttributeChangedSignal("OwnedBy"):Connect(setStats)


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

-- === THREAT FROM TAKING DAMAGE (NOW WORKING) ===
humanoid.HealthChanged:Connect(function(health)
    -- Compare old vs new health
    local damageTaken = humanoid:GetAttribute("LastHealth") and (humanoid:GetAttribute("LastHealth") - health) or 0

    -- Store the new health for next time
    humanoid:SetAttribute("LastHealth", health)

    if damageTaken > 0 then
        local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")
        if creator and creator.Value then
            local attacker = creator.Value
            local attackerId = attacker:IsA("Player") and attacker.UserId or attacker.Name
            AddThreatEvent:Fire(attackerId, damageTaken * 2.5 + 30)
            if creator.Parent then creator:Destroy() end
        end
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
    
    local ownedby = model:GetAttribute("OwnedBy")

    while task.wait(0.03) do

-- set flags
-- death if hum below 0
-- combat if hateList > 0 and target is less than acceptable
-- move if hateList > 0 and target is more than acceptable or
-- move if movemod returns target pos for owner
-- idle if none other are true

        if humanoid.Health <= 0 then
            if not model:GetAttribute("HasFallen") then
                utilMod.SetFlagsForDeath(model)
            end
        end
        local isPet = false;
        local ownerInstance = nil
        local combatTargetModel = nil
        local acceptableDistance = nil
        local useDirectMove = false
        if not model:GetAttribute("HasFallen") then
            
            
            ----------------------------------------------------------------
            -- Aggro
            ----------------------------------------------------------------
            
            if ownedby == "" or ownedby == "None" or ownedby == "none" then
                isPet = false
            end
            
            if isPet then
                ownerInstance = utilMod.GetModelByIDorName(model:GetAttribute("OwnedBy"))
            end

            if isPet then
                aggroMod.hateListPet(baseStats, hateList, model, hrp)
            else
                aggroMod.hateListFeral(baseStats, hateList, model, hrp)
            end
            if #hateList > 0 then
                if model:GetAttribute("TargetIDorName") == "None" then
                    warn("Should not reach me.")
                end
            end
            
            
            if not model:GetAttribute("TargetIDorName") == "None" then
                combatTargetModel = utilMod.GetModelByIDorName(model:GetAttribute("TargetIDorName"))
            end

            if combatTargetModel then
                acceptableDistance = utilMod.AcceptableDistanceToOpponent(model, combatTargetModel)
            end
            

            if #hateList > 0 and acceptableDistance then
                if not model:GetAttribute("InCombat") then
                    utilMod.SetFlagsForCombat(model)
                end
            end
            
            if #hateList > 0 and not acceptableDistance then
                if not model:GetAttribute("IsMoving")then
                    utilMod.SetFlagsForMoving(model)
                end
            end

            if #hateList == 0 then
                if isPet then
                    if pathMod.GetTargetPet(model, ownerInstance.name) then
                        if not model:GetAttribute("IsMoving") then
                            utilMod.SetFlagsForMoving(model)
                        end
                    else
                        if not model:GetAttribute("IsIdle") then
                            utilMod.SetFlagsForIdle(model)
                        end
                    end
                else
                    if IsStationary then
                        if utilMod.GetMagnitude(spawnPosition, hrp) > 3 and (model:GetAttribute("IdleStartTime") - tick()) > IdleReset then
                            if not model:GetAttribute("IsMoving")then
                                utilMod.SetFlagsForMoving(model)
                            end
                        else 
                            if not model:GetAttribute("IsIdle") then
                                utilMod.SetFlagsForIdle(model)
                            end
                        end
                    else
                        if (model:GetAttribute("IdleStartTime") - tick()) > IdleReset then
                            if not model:GetAttribute("IsMoving") then
                                utilMod.SetFlagsForMoving(model)
                            else
                                if not model:GetAttribute("IsIdle") then
                                    utilMod.SetFlagsForMoving(model)
                                end
                            end
                        end
                    end
                end
            end


            if model:GetAttribute("InCombat") then
                ----------------------------------------------------------------
                -- FACE TARGET / OWNER
                ----------------------------------------------------------------
                if combatTargetModel and not pathMod.IsPathActive(model) then
                    
                    local tHRP = combatTargetModel and (combatTargetModel:FindFirstChild("HumanoidRootPart") or combatTargetModel:FindFirstChild("Torso"))
                    if tHRP then
                        local dir = (tHRP.Position - hrp.Position)
                        dir = Vector3.new(dir.X, 0, dir.Z)
                        if dir.Magnitude > 0.1 then
                            hrp.CFrame = hrp.CFrame:lerp(CFrame.lookAt(hrp.Position, hrp.Position + dir), 0.3)
                        end
                    end

                    if animTracks.idle and animTracks.idle.IsPlaying then
                            animTracks.idle:Stop()
                    end

                    if tick() - lastAttackTime >= ATTACK_COOLDOWN then
                        local track = animTracks["attack" .. math.random(1,3)]
                        if track and not track.IsPlaying then
                            track:Play()
                            lastAttackTime = tick()

                            local targetHum = combatTargetModel:FindFirstChildOfClass("Humanoid")
                            if targetHum then
                                -- Creator tag
                                local creator = Instance.new("ObjectValue")
                                creator.Name = "creator"
                                creator.Value = model
                                creator.Parent = targetHum
                                task.delay(0.5, function()
                                    if creator.Parent then creator:Destroy() end
                                end)

                                local defStats = utilMod.GetStatsSafelyForPlrorNpc(combatTargetModel)
                                local damage = combatMod.MeleeAttackResult(baseStats, defStats)
                                targetHum.Health = math.max(targetHum.Health - damage, 0)

                                -- Build threat
                                --hateList[currentTargetId] = (hateList[currentTargetId] or 0) + damage * 1.4 + 10
                            end
                        end
                    end
                end
            end
            ----------------------------------------------------------------
                -- Moving
            ----------------------------------------------------------------
            if model:GetAttribute("IsMoving") then
                
            end
            ----------------------------------------------------------------
                -- Idle
            ----------------------------------------------------------------
            if model:GetAttribute("IsIdle") then
                if not animTracks.idle.IsPlaying then
                    animTracks.idle:Play()
                end
            end
        else
            ----------------------------------------------------------------
                -- Death
            ----------------------------------------------------------------
            if animTracks.death and not animTracks.death.IsPlaying then
                animTracks.blink:Stop()
                animTracks.idle:Stop()
                animTracks.death:Play()
                task.wait(2)
                model:SetAttribute("RecycleMe", true)
                
            else
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                humanoid.PlatformStand = true
                model:SetAttribute("RecycleMe", true)
            end
        end
    end
end)

