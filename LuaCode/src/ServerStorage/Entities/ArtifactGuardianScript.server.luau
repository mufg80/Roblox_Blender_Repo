-- ArtifactGuardian Pet Script - FINAL POLISHED VERSION (Nov 19, 2025)

local model = script.Parent
local random = Random.new()

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathMod = require(game.ReplicatedStorage.Shared.pathMod)
local aggroMod = require(game.ReplicatedStorage.Shared.aggroMod)

local thisMob = combatMod.customTrim(model.Name)
random = Random.new(utilMod.GetSeedFromName(thisMob))
local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then return end
local baseStats= combatMod.ShallowTableCopy(thisMob)

local IsStationary = model:GetAttribute("IsStationary") ~= false
local IdleReset = model:GetAttribute("IdleReset") or 5
local rangeLimit = model:GetAttribute("RangeLimit") or 50
local spawnPosition = hrp.Position
function setStats()
    baseStats = combatMod.ShallowTableCopy(thisMob)
    humanoid.MaxHealth = baseStats.hitPoints
    humanoid.Health = baseStats.hitPoints
    humanoid.WalkSpeed = 16 * baseStats.speed
    IsStationary = model:GetAttribute("IsStationary") ~= false
    IdleReset = model:GetAttribute("IdleReset") or 5
    spawnPosition = hrp.Position
end


model:GetAttributeChangedSignal("OwnedBy"):Connect(setStats)
setStats()

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


-- task.spawn(function()
--     while true do
--        print(hateList)
--         task.wait(2)
--     end

-- end)

-- === MAIN LOOP ===
task.spawn(function()
    -- Blink loop
    task.spawn(function()
        while task.wait(random:NextInteger(6,14)) do
            if animTracks.blink and not model:GetAttribute("HasFallen") then
                animTracks.blink:Play()
            end
        end
    end)
    model:SetAttribute("IdleStartTime", tick())
    local lastAttackTime = 0
    local ATTACK_COOLDOWN = combatMod.DELAY * baseStats.attackDelay
    local homewardBound = false
    local ownedby = model:GetAttribute("OwnedBy")
    local spincooldown = true
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
        local isPet = true;
        local ownerInstance = nil
        local combatTargetModel = nil
        local acceptableDistance = nil
        local movingDirection = "NotMoving"
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

            local hasEnemies = next(hateList) ~= nil   -- true if table has at least one entry

            if hasEnemies then
                if model:GetAttribute("TargetIDorName") == "None" then
                    warn("Should not reach me.")
                end
            end

            ----------------------------------------------------------------
            -- SetStates
            ----------------------------------------------------------------
            
            local targetid = model:GetAttribute("TargetIDorName")

            if targetid and targetid ~= "" and targetid ~= "None" and targetid ~= "none" then
                combatTargetModel = utilMod.GetModelByIDorName(targetid)
            end

            if combatTargetModel then
                acceptableDistance = combatMod.AcceptableDistanceToOpponent(model, combatTargetModel)
            end
            

            if hasEnemies and acceptableDistance then   -- next() returns nil if table is empty
                if not model:GetAttribute("InCombat") then
                    utilMod.SetFlagsForCombat(model)
                end
            end
            
            if hasEnemies and not acceptableDistance then   -- next() returns nil if table is empty

                if not model:GetAttribute("IsMoving") then
                    utilMod.SetFlagsForMoving(model)
                    movingDirection = "MovingToCombatTarget"
                else
                    local targ = pathMod.GetCurrentTarget(model)
                    if targ ~= combatTargetModel then
                        if not model:GetAttribute("IsIdle") then
                            utilMod.SetFlagsForIdle(model)
                        end
                    else
                        movingDirection = "MovingToCombatTarget"
                    end
                end
                
                
            end

            if not hasEnemies then
                if isPet then
                    local check = ownerInstance and pathMod.GetTargetPet(model, game.Players:GetPlayerFromCharacter(ownerInstance).UserId)
                    if check then
                        if not model:GetAttribute("IsMoving") then
                            utilMod.SetFlagsForMoving(model)
                        end
                        movingDirection = "MovingToOwner"
                    else
                        if not model:GetAttribute("IsIdle") then
                            utilMod.SetFlagsForIdle(model)
                        end
                    end
                else
                    if IsStationary then
                        if utilMod.GetMagnitude(spawnPosition, hrp) > 3 and tick() - (model:GetAttribute("IdleStartTime")) > IdleReset then
                            if not model:GetAttribute("IsMoving")then
                                utilMod.SetFlagsForMoving(model)                                
                            end
                            movingDirection = "MovingToSpawnPosition"
                        else 
                            if not model:GetAttribute("IsIdle") then
                                utilMod.SetFlagsForIdle(model)
                            end
                        end
                    else
                        local tooFar = utilMod.GetMagnitude(hrp, spawnPosition) > rangeLimit

                        if tooFar and not homewardBound then
                            homewardBound = true
                            if pathMod.IsPathActive(model) then
                                pathMod.ShortCircutTravel(model)
                            end
                            if not model:GetAttribute("IsIdle") then
                                utilMod.SetFlagsForIdle(model)
                            end
                        elseif homewardBound then
                            if not model:GetAttribute("IsMoving") then
                                utilMod.SetFlagsForMoving(model)
                            end
                            movingDirection = "HomewardBound"
                        elseif (tick() - model:GetAttribute("IdleStartTime")) > IdleReset then
                            if not model:GetAttribute("IsMoving") then
                                utilMod.SetFlagsForMoving(model)
                            elseif model:GetAttribute("IsMoving") and not pathMod.IsPathActive(model) then
                                if not model:GetAttribute("IsIdle") then
                                    utilMod.SetFlagsForIdle(model)
                                end
                            end
                            movingDirection = "MovingToRandom"
                        else
                            if not model:GetAttribute("IsIdle") then
                                utilMod.SetFlagsForIdle(model)
                            end
                        end
                    end
                end
            end

            ----------------------------------------------------------------
                -- Actions
            ----------------------------------------------------------------

            if model:GetAttribute("InCombat") then
                ----------------------------------------------------------------
                -- FACE TARGET / OWNER
                ----------------------------------------------------------------

                if combatTargetModel and pathMod.IsPathActive(model) then
                    if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
                        pathMod.ShortCircutTravel(model)
                    end
                end
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
                        local track = animTracks["attack" .. random:NextInteger(1,3)]
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

                                local damage = combatMod.MeleeAttackResult(model, combatTargetModel)
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
                if not animTracks.idle.IsPlaying then
                    animTracks.idle:Play()
                    animTracks.idle:AdjustSpeed(1.5)
                else
                    animTracks.idle:AdjustSpeed(1.5)
                end

                if movingDirection == "MovingToCombatTarget" then
                    local target = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"))
                    if target and not pathMod.IsPathActive(model) then
                        pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
                    elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
                        pathMod.ShortCircutTravel(model)
                        pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
                    end
                    
                elseif movingDirection == "MovingToOwner" then
                    local owner = model:GetAttribute("OwnedBy")
                    local target = pathMod.GetTargetPet(model, owner)
                    if target and not pathMod.IsPathActive(model)then
                        pathMod.PathfindToPosition(model, target, owner)
                    elseif pathMod.GetCurrentTarget(model) ~= utilMod.GetModelByIDorName(owner) then
                        pathMod.ShortCircutTravel(model)
                        pathMod.PathfindToPosition(model, target, owner)
                    end

                elseif movingDirection == "MovingToSpawnPosition" then
                    if not pathMod.IsPathActive(model)then
                        pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
                    elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                        pathMod.ShortCircutTravel(model)
                        pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
                    end

                elseif movingDirection == "MovingToRandom" then
                    local vec = Vector3.new(spawnPosition.X, hrp.Position.Y, spawnPosition.Z)
                    if random:NextInteger(1,10) < 5 then
                        local xpos = random:NextInteger(-10,10)
                        local zpos = random:NextInteger(-10,10)
                        vec = vec + Vector3.new(xpos, 0, zpos)
                    end
                    
                    if not pathMod.IsPathActive(model) then
                        pathMod.PathfindToPosition(model, vec, "SpawnPoint")
                    elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                        pathMod.ShortCircutTravel(model)
                        pathMod.PathfindToPosition(model, vec, "SpawnPoint")
                    end
                elseif movingDirection == "HomewardBound" then
                    if not pathMod.IsPathActive(model)then
                        pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
                    elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                        pathMod.ShortCircutTravel(model)
                        pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
                    elseif utilMod.GetMagnitude(hrp, spawnPosition) < 5 then
                        pathMod.ShortCircutTravel(model)
                        homewardBound = false
                    end
                elseif movingDirection == "NotMoving" then
                    warn("flag is moving but not target.")
                else
                    warn("Should not reach me.")
                end



            end
            ----------------------------------------------------------------
                -- Idle
            ----------------------------------------------------------------
            if model:GetAttribute("IsIdle") then
                if not animTracks.idle.IsPlaying then
                    animTracks.idle:Play()
                    animTracks.idle:AdjustSpeed(1.0)
                else
                    animTracks.idle:AdjustSpeed(1.0)
                end
                if pathMod.IsPathActive(model) then
                    pathMod.ShortCircutTravel(model)
                end

                if ownerInstance and (tick() - model:GetAttribute("IdleStartTime")) > random:NextInteger(10,20) and spincooldown then
                    spincooldown = false
                    task.spawn(function()
                        local tHRP = ownerInstance:FindFirstChild("HumanoidRootPart") or ownerInstance:FindFirstChild("Torso")
                        if not tHRP then
                            spincooldown = true
                            return
                        end

                        -- Direction to owner (ignore Y axis so it doesn’t tilt)
                        local toOwner = (tHRP.Position - hrp.Position)
                        toOwner = Vector3.new(toOwner.X, 0, toOwner.Z)
                        if toOwner.Magnitude < 0.1 then
                            spincooldown = true
                            return
                        end

                        local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + toOwner)

                        local connection
                        connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
                            -- Cancel if no longer idle or owner disappeared
                            if not model:GetAttribute("IsIdle") or not ownerInstance.Parent then
                                connection:Disconnect()
                                return
                            end

                            -- Lerp toward the target facing direction
                            local speed = 2 * dt
                            hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, speed)  
                            
                            -- Stop when we’re basically facing the owner
                            if (hrp.CFrame.LookVector - targetCFrame.LookVector).Magnitude < 0.05 then
                                hrp.CFrame = targetCFrame  -- snap to exact
                                connection:Disconnect()
                            end
                        end)
                    end)

                    -- Allow next turn after a random delay
                    task.delay(random:NextInteger(8,15), function()
                        spincooldown = true
                    end)
                end
            end
        else
            ----------------------------------------------------------------
                -- Death
            ----------------------------------------------------------------
            if animTracks.death and not animTracks.death.IsPlaying then
                if animTracks.blink then
                    animTracks.blink:Stop()
                end
                if animTracks.idle then
                    animTracks.idle:Stop()
                end
                animTracks.death:Play()
                task.wait(3)
                model:SetAttribute("RecycleMe", true)
            else
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                humanoid.PlatformStand = true
                model:SetAttribute("RecycleMe", true)
            end
        end
    end
end)

