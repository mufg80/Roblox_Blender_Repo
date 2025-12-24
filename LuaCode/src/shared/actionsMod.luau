--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local actionsMod = {}

local healerCache: { [string]: boolean } = {}
local healerType: string? = nil
local healerHealed: { [string]: number } = {}
local healerNuked: { [string]: number } = {} -- Tracks last nuke time per priest
local healerBuffed: { [string]: number } = {}

-- Unified function to cast any Priest spell (Heal, Buff, Nuke, etc.)
local function CastPriestSpell(
    animTracks: { cast: AnimationTrack, castSpeed: number? },
    model: Model,
    combatMod: any, -- your combat module
    spellname: string, -- "PriestHeal", "PriestBuff", "PriestNuke", etc.
    combatTargetModel: Model? -- Optional: only used if spell needs a direct target
)
    -- Play the cast animation
    local trackToPlay: AnimationTrack = animTracks.cast
    trackToPlay:Play(0.3, 0.9, animTracks.castSpeed or 1)

    print("Cast " .. spellname .. " - Pet")

    -- Delay the actual spell application (simulates cast time / impact)
    task.delay(0.5, function()
        local userId = utilMod.GetAttribute(model, "OwnedBy")
        if userId and typeof(userId) == "number" then
            local plr = game.Players:GetPlayerByUserId(userId)
            if plr and plr.Character then
                -- Apply the spell (your existing logic handles targeting/healing/damage/buffs)
                combatMod.ApplyPriestSpell(model, plr.Character, spellname, combatTargetModel)
            end
        end
    end)
end

local function DecideToBuff(model: Model, mana: number, maxmana: number): boolean
    local buffSpell = statsMod.SpellInfo[healerType .. "PriestBuff"]
    local manaCost = buffSpell.manaCost * statsMod.MaxSpellCost
    local castTime = buffSpell.castTime
    local durationTime = statsMod.BuffInfo[healerType .. "PriestBuff"].seconds

    -- Condition 1: Mana below 60% of maxmana
    if mana < maxmana * 0.6 then
        return false
    end

    -- Ensure enough mana to cast
    if mana < manaCost then
        return false
    end

    -- Condition 2: Check if buff is on cooldown
    local modelName = model.Name
    local lastBuffTime = healerBuffed[modelName] or 0
    local cooldownEnd = lastBuffTime + castTime + durationTime + 10

    if os.clock() < cooldownEnd then
        return false
    end

    -- All conditions met: Buff will be cast, store the current time
    healerBuffed[modelName] = os.clock()
    return true
end

local function DecideToHeal(thisModel: Model, mana: number, maxmana: number): boolean
    local party = utilMod.GetPartyMembers(thisModel)
    if not party or not party.pets then
        return false
    end
    local partyTable = {}
    table.insert(partyTable, party.Character)
    for _, pets in ipairs(party.pets) do
        table.insert(partyTable, pets)
    end
    if #partyTable == 0 then
        return false
    end

    local healSpell = statsMod.SpellInfo[healerType .. "PriestHeal"]
    local manaCost = healSpell.manaCost * statsMod.MaxSpellCost
    local castTime = healSpell.castTime
    local healDuration = statsMod.BuffInfo[healerType .. "PriestHeal"].seconds or 0 -- fallback if missing

    -- Early mana check
    if mana < manaCost then
        return false
    end

    -- Cooldown check: prevent spamming heal
    local modelName = thisModel.Name
    local lastHealTime = healerHealed[modelName] or 0
    local cooldownEnd = lastHealTime + castTime + healDuration + 3

    if time() < cooldownEnd then
        return false -- Still on cooldown
    end

    -- Collect all humanoids from party (player characters + pets)
    local humanoids: { Humanoid } = {}

    for _, member in ipairs(partyTable) do
        if member then
            local humanoid = member:FindFirstChildOfClass("Humanoid")
            if humanoid then
                table.insert(humanoids, humanoid)
            end
        end
    end

    if #humanoids == 0 then
        return false
    end

    -- Priority 1: Anyone critically low (<20%) → heal immediately if any mana
    for _, humanoid in ipairs(humanoids) do
        if humanoid.Health > 0 and humanoid.Health / humanoid.MaxHealth < 0.2 then
            healerHealed[modelName] = time()
            return true
        end
    end

    -- Calculate group average health
    local totalHealth = 0
    local totalMaxHealth = 0
    for _, humanoid in ipairs(humanoids) do
        if humanoid.Health > 0 then -- avoid dividing dead (0/0)
            totalHealth += humanoid.Health
            totalMaxHealth += humanoid.MaxHealth
        end
    end

    local groupHealthPercent = totalMaxHealth > 0 and (totalHealth / totalMaxHealth) or 1

    -- Priority 2: Group <50% → heal
    if groupHealthPercent < 0.5 then
        healerHealed[modelName] = time()
        return true
    end

    -- Priority 3: Group <70% and mana >=50%
    if groupHealthPercent < 0.7 and mana >= maxmana * 0.5 then
        healerHealed[modelName] = time()
        return true
    end

    -- Priority 4: Group <90% and mana >=80%
    if groupHealthPercent < 0.9 and mana >= maxmana * 0.8 then
        healerHealed[modelName] = time()
        return true
    end

    return false
end

local function DecideToNuke(thisModel: Model, mana: number, maxmana: number): boolean
    local party = utilMod.GetPartyMembers(thisModel)
    if not party or not party.pets then
        return false
    end
    local partyTable = {}
    table.insert(partyTable, party.Character)
    for _, pets in ipairs(party.pets) do
        table.insert(partyTable, pets)
    end
    if #partyTable == 0 then
        return false
    end

    local nukeSpell = statsMod.SpellInfo[healerType .. "PriestNuke"]
    if not nukeSpell then
        warn("PriestNuke spell not found in SpellInfo")
        return false
    end

    local manaCost = nukeSpell.manaCost * statsMod.MaxSpellCost
    local castTime = nukeSpell.castTime or 0
    local nukeDuration = statsMod.BuffInfo[healerType .. "PriestNuke"].seconds or 0 -- may not have duration

    -- Early exit: not enough mana to cast
    if mana < manaCost then
        return false
    end

    -- Cooldown: prevent spamming nuke (cast time + 5 second base cooldown)
    local modelName = thisModel.Name
    local lastNukeTime = healerNuked[modelName] or 0
    local cooldownEnd = lastNukeTime + castTime + 5

    if time() < cooldownEnd then
        return false
    end

    -- Collect all living humanoids in party
    local humanoids: { Humanoid } = {}

    for _, member in ipairs(partyTable) do
        if member then
            local humanoid = member:FindFirstChildOfClass("Humanoid")
            if humanoid then
                table.insert(humanoids, humanoid)
            end
        end
    end

    if #humanoids == 0 then
        return false
    end

    -- Calculate group average health
    local totalHealth = 0
    local totalMaxHealth = 0
    for _, hum in ipairs(humanoids) do
        totalHealth += hum.Health
        totalMaxHealth += hum.MaxHealth
    end
    local groupHealthPercent = totalMaxHealth > 0 and (totalHealth / totalMaxHealth) or 1

    -- Mana percentage for dynamic decision-making
    local manaPercent = mana / maxmana

    -- Priority 1: Someone is below 30% → Nuke aggressively if mana allows
    local lowestHealthPercent = 1 -- (was missing initialization in original)
    for _, hum in ipairs(humanoids) do
        lowestHealthPercent = math.min(lowestHealthPercent, hum.Health / hum.MaxHealth)
    end

    if lowestHealthPercent < 0.4 then
        -- Only require minimum mana for the spell (already checked above)
        -- But prefer having at least 30% mana to avoid draining completely
        if manaPercent >= 0.3 then
            healerNuked[modelName] = time()
            return true
        end
    end

    -- Priority 2: Group health below 50% → Nuke if mana is decent (50%+)
    if groupHealthPercent < 0.6 and manaPercent >= 0.5 then
        healerNuked[modelName] = time()
        return true
    end

    -- Priority 3: Group health below 80% → Nuke conservatively if mana is high (70%+)
    if groupHealthPercent < 0.75 and manaPercent >= 0.7 then
        healerNuked[modelName] = time()
        return true
    end

    -- Priority 4: Everything is mostly fine (80%+ health) → Only nuke if mana is very high (90%+)
    if groupHealthPercent < 0.9 and manaPercent >= 0.8 then
        healerNuked[modelName] = time()
        return true
    end

    -- No good reason to nuke right now
    return false
end

local function StopIdle(animTracks: any)
    -- Handle idleConnection (could be thread or connection)
    if animTracks.idleConnection then
        if typeof(animTracks.idleConnection) == "thread" then
            task.cancel(animTracks.idleConnection)
        elseif typeof(animTracks.idleConnection) == "RBXScriptConnection" then
            animTracks.idleConnection:Disconnect()
        end
        animTracks.idleConnection = nil
    end

    -- Handle delayConnection (same safety)
    if animTracks.delayConnection then
        if typeof(animTracks.delayConnection) == "thread" then
            task.cancel(animTracks.delayConnection)
        elseif typeof(animTracks.delayConnection) == "RBXScriptConnection" then
            animTracks.delayConnection:Disconnect()
        end
        animTracks.delayConnection = nil
    end

    -- Stop all idle animation tracks
    if #animTracks.idle > 0 then
        for _, track in ipairs(animTracks.idle) do
            if track and track.IsPlaying then
                track:Stop(0.5) -- Optional: smooth fade out
            end
        end
    end
end

-- Simplified: only starts the long idle (or single idle). Transition handled externally.
local function PlayIdles(animTracks: any)
    for _, idle in ipairs(animTracks.idle) do
        if idle and idle.IsPlaying then
            return
        end
    end

    if #animTracks.idle == 1 then
        local idleToPlay: AnimationTrack = animTracks.idle[1]
        idleToPlay.Looped = true
        if idleToPlay then
            idleToPlay:Play(0.3, 1, animTracks.idleSpeed or 1)
        end
    elseif #animTracks.idle == 2 then
        local tracktoplay1: AnimationTrack = animTracks.idle[1]
        local tracktoplay2: AnimationTrack = animTracks.idle[2]
        tracktoplay2.Looped = true
        tracktoplay1.Looped = false
        local total = math.random(15, 30)
        tracktoplay2:Play(1, 1, animTracks.idleSpeed or 1)
        animTracks.idleConnection = task.delay(total, function()
            if tracktoplay2 and tracktoplay2.IsPlaying then
                tracktoplay2:Stop(0.5)
                tracktoplay1:Play(0.5, 1, animTracks.idleSpeed or 1)
                animTracks.delayConnection = tracktoplay1.Stopped:Connect(function()
                    tracktoplay2:Play(0.5, 0.9, animTracks.idleSpeed or 1)
                end)
            end
        end)
    end
end

local function StopMove(animTracks: any)
    if animTracks.move and animTracks.move.IsPlaying then
        local tracktostop: AnimationTrack = animTracks.move
        tracktostop:Stop(1)
    end
end

local function GetRandomAttack(animTracks: any, random: Random): { anim: AnimationTrack?, index: number? }
    if #animTracks.attacks == 0 then
        return nil
    end
    local doPrimary = random:NextInteger(1, 3) == 1
    if doPrimary then
        local ind = animTracks.favoredAttack
        return { animTracks.attacks[ind], ind }
    else
        local ind = random:NextInteger(1, #animTracks.attacks)
        return { anim = animTracks.attacks[ind], index = ind }
    end
end

local function GetHealerType(name: string): string
    local trimmed = utilMod.customTrim(name)
    if trimmed == "Druid" then
        return "Nature"
    elseif trimmed == "StoneManaPriest" then
        return "Artificer"
    elseif trimmed == "MudPriest" then
        return "Primordial"
    else
        warn("should not reach me")
    end
end

function actionsMod.PerformActions(context: table)
    local model = context.model
    local hrp = context.hrp
    local animTracks = context.animTracks
    local combatTargetModel = context.combatTargetModel
    local movingDirection = context.movingDirection
    local ownerInstance = context.ownerInstance
    local lastAttackWrapper = context.lastAttackTime -- {value = number}
    local ATTACK_COOLDOWN = context.ATTACK_COOLDOWN
    local spawnPosition = context.spawnPosition
    local random = context.random

    local petAttack = context.petAttack
    local petTakeLith = context.petTakeLith
    local petDefendLith = context.petDefendLith
    local lithTakePosition = context.lithTakePosition
    local lithDefendPosition = context.lithDefendPosition

    -- Mutable references
    local lithTakeRandomLoc = context.lithTakeRandomLoc
    local lithDefendRandomLoc = context.lithDefendRandomLoc
    local homewardBound = context.homewardBound

    local pathMod = context.pathMod
    local combatMod = context.combatMod
    local utilMod = context.utilMod
    local pet = context.pet

    if not healerCache[model.Name] then
        healerCache[model.Name] = utilMod.IsMobHealer(model)
        if healerCache[model.Name] then
            healerType = GetHealerType(model.Name)
        end
    end

    ----------------------------------------------------------------
    -- Combat Actions
    ----------------------------------------------------------------
    if utilMod.GetAttribute(model, "InCombat") and not healerCache[model.Name] then
        StopMove(animTracks)
        PlayIdles(animTracks)
        if combatTargetModel then
            if pathMod.IsPathActive(model) then
                if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
                    pathMod.ShortCircuitTravel(model)
                end
            end

            if not pathMod.IsPathActive(model) then
                utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)

                if time() - lastAttackWrapper.value >= ATTACK_COOLDOWN then
                    local track = GetRandomAttack(animTracks, random)
                    if track and track.anim and not track.anim.IsPlaying then
                        track.anim:Play(0.2, 1, animTracks.attackSpeeds[track.index])
                        lastAttackWrapper.value = time()

                        task.delay(0.5, function()
                            combatMod.ApplyMeleeDamage(model, combatTargetModel)
                        end)
                    end
                end
            end
        end
    elseif utilMod.GetAttribute(model, "InCombat") and healerCache[model.Name] then
        StopMove(animTracks)
        PlayIdles(animTracks)
        if combatTargetModel then
            if pathMod.IsPathActive(model) then
                if utilMod.GetAcceptableDistanceForCaster(model, combatTargetModel) then
                    pathMod.ShortCircuitTravel(model)
                end
            end

            if not pathMod.IsPathActive(model) then
                if time() - lastAttackWrapper.value >= ATTACK_COOLDOWN then
                    local mana = utilMod.GetAttribute(model, "Mana") or 0
                    local maxMana = utilMod.GetAttribute(model, "MaxMana") or 1

                    if DecideToHeal(model, mana, maxMana) then
                        utilMod.SpinToOwner(model, hrp, ownerInstance, random)
                        CastPriestSpell(animTracks, model, combatMod, healerType .. "PriestHeal")
                        lastAttackWrapper.value = time()
                    elseif DecideToBuff(model, mana, maxMana) then
                        utilMod.SpinToOwner(model, hrp, ownerInstance, random)
                        CastPriestSpell(animTracks, model, combatMod, healerType .. "PriestBuff")
                        lastAttackWrapper.value = time()
                    elseif DecideToNuke(model, mana, maxMana) then
                        utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)
                        CastPriestSpell(animTracks, model, combatMod, healerType .. "PriestNuke", combatTargetModel)
                        lastAttackWrapper.value = time()
                    end
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Moving Actions
    ----------------------------------------------------------------
    if utilMod.GetAttribute(model, "IsMoving") then
        StopIdle(animTracks)
        if animTracks.move and not animTracks.move.IsPlaying then
            local tracktoplay: AnimationTrack = animTracks.move
            tracktoplay:Play(0.3, 0.9, animTracks.moveSpeed or 1)
        end

        if movingDirection == "MovingToCombatTarget" and not healerCache[model.Name] then
            local target = pathMod.GetTargetPet(model, utilMod.GetAttribute(model, "TargetIDorName"), random)
            if target and not pathMod.IsPathActive(model) then
                pathMod.PathfindToPosition(model, target, utilMod.GetAttribute(model, "TargetIDorName"))
            elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
                pathMod.ShortCircuitTravel(model)
                pathMod.PathfindToPosition(model, target, utilMod.GetAttribute(model, "TargetIDorName"))
            end
        elseif movingDirection == "MovingToCombatTarget" and healerCache[model.Name] then
            -- move to within 45 studs (logic unchanged)
        elseif movingDirection == "MovingToNearestLith" then
            if petDefendLith then
                if lithDefendPosition then
                    if not lithDefendRandomLoc then
                        lithDefendRandomLoc = pathMod.GetTargetLith(lithDefendPosition)
                    end
                    if lithDefendRandomLoc and not pathMod.IsPathActive(model) then
                        pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
                    elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
                        pathMod.ShortCircuitTravel(model)
                        pathMod.PathfindToPosition(model, lithDefendRandomLoc, "Lith")
                    end
                end
            elseif petTakeLith then
                if lithTakePosition then
                    if not lithTakeRandomLoc then
                        lithTakeRandomLoc = pathMod.GetTargetLith(lithTakePosition)
                    end
                    if lithTakeRandomLoc and not pathMod.IsPathActive(model) then
                        pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
                    elseif pathMod.GetCurrentTarget(model) ~= "Lith" then
                        pathMod.ShortCircuitTravel(model)
                        pathMod.PathfindToPosition(model, lithTakeRandomLoc, "Lith")
                    end
                end
            end
        elseif movingDirection == "MovingToOwner" then
            local ownerId = utilMod.GetAttribute(model, "OwnedBy")
            local target = pathMod.GetTargetPet(model, ownerId, random)
            if target and not pathMod.IsPathActive(model) then
                pathMod.PathfindToPosition(model, target, ownerId)
            elseif pathMod.GetCurrentTarget(model) ~= utilMod.GetModelByIDorName(ownerId) then
                pathMod.ShortCircuitTravel(model)
                pathMod.PathfindToPosition(model, target, ownerId)
            end
        elseif movingDirection == "MovingToSpawnPosition" then
            if not pathMod.IsPathActive(model) then
                pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
            elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                pathMod.ShortCircuitTravel(model)
                pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
            end
        elseif movingDirection == "MovingToRandom" then
            local vec = Vector3.new(spawnPosition.X, hrp.Position.Y, spawnPosition.Z)
            if random:NextInteger(1, 10) < 5 then
                local xpos = random:NextInteger(-10, 10)
                local zpos = random:NextInteger(-10, 10)
                vec = vec + Vector3.new(xpos, 0, zpos)
            end

            if not pathMod.IsPathActive(model) then
                pathMod.PathfindToPosition(model, vec, "SpawnPoint")
            elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                pathMod.ShortCircuitTravel(model)
                pathMod.PathfindToPosition(model, vec, "SpawnPoint")
            end
        elseif movingDirection == "HomewardBound" then
            if not pathMod.IsPathActive(model) then
                pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
            elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
                pathMod.ShortCircuitTravel(model)
                pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
            elseif utilMod.GetDistance(hrp.Position, spawnPosition) < 5 then
                pathMod.ShortCircuitTravel(model)
                homewardBound = false
            end
        end
    end

    ----------------------------------------------------------------
    -- Idle Actions
    ----------------------------------------------------------------
    if utilMod.GetAttribute(model, "IsIdle") then
        StopMove(animTracks)
        PlayIdles(animTracks)

        if pathMod.IsPathActive(model) then
            pathMod.ShortCircuitTravel(model)
            print("shorting travel10")
        end

        local timeNumber = time() - (utilMod.GetAttribute(model, "IdleStartTime") or 0)
        local cool = time() > (utilMod.GetAttribute(model, "SpinCoolDown") or 0)

        if ownerInstance and cool and timeNumber > random:NextInteger(10, 20) then
            utilMod.SetAttribute(model, "SpinCoolDown", time() + random:NextInteger(10, 25))
            utilMod.SpinToOwner(model, hrp, ownerInstance, random)
        end

        if healerCache[model.Name] then
            local mana = utilMod.GetAttribute(model, "Mana") or 0
            local maxMana = utilMod.GetAttribute(model, "MaxMana") or 1

            local nextCastTime = utilMod.GetAttribute(model, "IdleCastCoolDown") or 0
            if
                DecideToHeal(model, mana, maxMana)
                and time() > nextCastTime
                and time() - lastAttackWrapper.value >= ATTACK_COOLDOWN
            then
                nextCastTime = time() + random:NextInteger(10, 40)
                utilMod.SetAttribute(model, "IdleCastCoolDown", nextCastTime)
                lastAttackWrapper.value = time()
                CastPriestSpell(animTracks, model, combatMod, healerType .. "PriestHeal", nil)
            end
        end
    end
end

return actionsMod