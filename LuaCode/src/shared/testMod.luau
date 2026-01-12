--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local testMod = {}

--==============================================================================
-- Test version of MeleeAttackResult that uses stats from statsMod.creatureStats table instead of instances.
-- Returns final integer damage (0 = miss)
--==============================================================================
local testMod = {}

--==============================================================================
-- Test version: Applies stat changes (buff/debuff) to cloned stat tables
-- Returns success (boolean) and two modified stat tables (clones)
-- Does NOT modify the original statsMod.creatureStats
--==============================================================================
function testMod.ApplyStatChangesTest(
    attackerName: string?,
    defenderName: string?,
    spellname: string,
    multiplier: number
): (boolean, { [string]: any }?, { [string]: any }?)
    
    if not spellname or not multiplier then
        warn("ApplyStatChangesTest: Missing spellname or multiplier")
        return false, nil, nil
    end

    local buffInfo = statsMod.BuffInfo[spellname]
    if not buffInfo then
        warn("ApplyStatChangesTest: No buff info found for spell:", spellname)
        return false, nil, nil
    end

    -- Clone original stats (or use empty table if name not provided)
    local attackerStats = attackerName and statsMod.creatureStats[attackerName] 
        and table.clone(statsMod.creatureStats[attackerName]) 
        or nil

    local defenderStats = defenderName and statsMod.creatureStats[defenderName] 
        and table.clone(statsMod.creatureStats[defenderName]) 
        or nil

    local success = false

    -- Apply changes to attacker if provided
    if attackerStats then
        for statName: string, changeValue: number in pairs(buffInfo) do
            if attackerStats[statName] and typeof(attackerStats[statName]) == "number" then
                --print("[TEST] Before - Attacker." .. statName .. ": " .. attackerStats[statName])
                attackerStats[statName] += changeValue * multiplier
                --print("[TEST] After  - Attacker." .. statName .. ": " .. attackerStats[statName])
                success = true
            end
        end
    end

    -- Apply changes to defender if provided
    if defenderStats then
        for statName: string, changeValue: number in pairs(buffInfo) do
            if defenderStats[statName] and typeof(defenderStats[statName]) == "number" then
                --print("[TEST] Before - Defender." .. statName .. ": " .. defenderStats[statName])
                defenderStats[statName] += changeValue * multiplier
                --print("[TEST] After  - Defender." .. statName .. ": " .. defenderStats[statName])
                success = true
            end
        end
    end

    -- If neither attacker nor defender was provided, nothing happened
    if not attackerStats and not defenderStats then
        warn("ApplyStatChangesTest: No valid attackerName or defenderName provided")
        return false, nil, nil
    end

    return success, attackerStats, defenderStats
end

local testMod = {}

--==============================================================================
-- Modified melee attack result that takes stat tables directly (cloned/modified)
-- Returns final integer damage (0 = miss)
--==============================================================================
function testMod.MeleeAttackResultWithStats(attackerstats: table, defenderstats: table): number
    if not attackerstats or not defenderstats or not attackerstats.defense or not defenderstats.defense then
        warn("Should not reach me.")
        return 0
    end

    -- Miss chance based on defense vs attack difference
    local defenseAdvantage = defenderstats.defense - attackerstats.attack
    local missChance = math.clamp(defenseAdvantage * 25, 0.15, 0.30)

    if math.random() < missChance then
        return 0 -- Miss
    end

    local MAXDAMAGECONSTANT = statsMod.MaxDamageConstant
    local baseDamage = attackerstats.attack * MAXDAMAGECONSTANT
    local maxPossibleDamage = attackerstats.maxDamage * (MAXDAMAGECONSTANT * 1.5)

    -- Defense flat reduction (with diminishing returns floor)
    local defenseReduction = defenderstats.defense * 12
    local damageAfterDefense = math.max(baseDamage - defenseReduction, baseDamage * 0.3)

    -- Armour percentage reduction
    local damageAfterArmour = damageAfterDefense * (1 - defenderstats.armour)

    -- Clamp to max possible
    local calculatedDamage = math.clamp(damageAfterArmour, 1, maxPossibleDamage)

    -- Random multiplier 50%–100%
    local damageMultiplier = math.random() * 0.5 + 0.5
    local finalDamage = calculatedDamage * damageMultiplier

    finalDamage = math.clamp(finalDamage, 1, maxPossibleDamage)
    return math.floor(finalDamage + 0.5)
end

--==============================================================================
-- Function to calculate DPS for all attackers vs a defender, with optional buffs/debuffs.
-- Applies spells (buffs/debuffs) if tables are not empty.
-- Assumes statsMod.BuffInfo[spellname] exists and contains stat changes (positive for buff, negative for debuff).
-- Multiplier is fixed at 1; adjust if needed for debuffs with positive BuffInfo values.
-- Iterates over all creatures in statsMod.creatureStats as attackers.
-- Simulates 500 attacks per attacker to average randomness.
-- DPS = avg_damage_per_attack / (attackDelay * statsMod.DELAY)
-- Prints results as specified.
--==============================================================================
function testMod.CalculateDPS(attacker_spells: {string}, defender_spells: {string}, defender_name: string)
    if not statsMod.creatureStats[defender_name] then
        warn("Invalid defender name: " .. tostring(defender_name))
        return
    end

    local DELAY = statsMod.DELAY  -- Use variable; e.g., 5.0 seconds

    -- Prepare effects strings for output
    local attacker_effects_str = if #attacker_spells > 0 then table.concat(attacker_spells, ", ") else "no effects"
    local defender_effects_str = if #defender_spells > 0 then table.concat(defender_spells, ", ") else "no effects"

    -- We'll store all results here
    local results = {}

    for attacker_name, baseStats in pairs(statsMod.creatureStats) do
        -- Skip if no level defined (just in case)
        if not baseStats.level then continue end

        -- Clone base stats
        local attacker_stats = table.clone(baseStats)
        local defender_stats = table.clone(statsMod.creatureStats[defender_name])

        -- Apply attacker spells (buffs/debuffs)
        if #attacker_spells > 0 then
            for _, spell in attacker_spells do
                local buffInfo = statsMod.BuffInfo[spell]
                if buffInfo then
                    for statName: string, changeValue: number in pairs(buffInfo) do
                        if attacker_stats[statName] and typeof(attacker_stats[statName]) == "number" then
                            attacker_stats[statName] += changeValue
                        end
                    end
                else
                    warn("No BuffInfo for spell: " .. spell)
                end
            end
        end

        -- Apply defender spells (buffs/debuffs)
        if #defender_spells > 0 then
            for _, spell in defender_spells do
                local buffInfo = statsMod.BuffInfo[spell]
                if buffInfo then
                    for statName: string, changeValue: number in pairs(buffInfo) do
                        if defender_stats[statName] and typeof(defender_stats[statName]) == "number" then
                            defender_stats[statName] += changeValue
                        end
                    end
                else
                    warn("No BuffInfo for spell: " .. spell)
                end
            end
        end

        -- Calculate effective attack delay
        local attack_delay = attacker_stats.attackDelay * DELAY

        -- Simulate 500 attacks
        local total_damage = 0
        for i = 1, 500 do
            total_damage += testMod.MeleeAttackResultWithStats(attacker_stats, defender_stats)
        end
        local avg_damage = total_damage / 500

        -- Calculate DPS
        local dps = if attack_delay > 0 then avg_damage / attack_delay else 0

        -- Store the result
        table.insert(results, {
            name = attacker_name,
            level = attacker_stats.level,
            dps = dps,
            full_line = string.format(
                "%s level %d with effects %s vs %s level %d with effects %s does %.2f damage per second",
                attacker_name, attacker_stats.level,
                attacker_effects_str,
                defender_name, defender_stats.level,
                defender_effects_str,
                dps
            )
        })
    end

    -- Sort results by level (ascending), then by name for same-level stability
    table.sort(results, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)

    -- Now print them in nice grouped order
    print("──────────────────────────────────────────────")
    print(string.format("DPS Results: %s vs %s", attacker_effects_str, defender_effects_str))
    print("──────────────────────────────────────────────")

    local current_level = -1
    for _, result in ipairs(results) do
        if result.level ~= current_level then
            current_level = result.level
            print(string.format("\nLevel %d:", current_level))
        end
        print("  " .. result.full_line)
    end

    print("──────────────────────────────────────────────")
end


-- No buffs
testMod.CalculateDPS({}, {}, "StoneManaPriest")

-- Pure buff on attacker
--testMod.CalculateDPS({"HardSkin"}, {}, "StoneManaPriest")

-- Pure debuff on defender
--testMod.CalculateDPS({}, {"StoneonFoot"}, "StoneManaPriest")

-- Both: buffed attacker vs debuffed defender
--testMod.CalculateDPS({"HardSkin"}, {"StoneonFoot"}, "StoneManaPriest")

return testMod