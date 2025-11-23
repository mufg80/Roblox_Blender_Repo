local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatMod = require(ReplicatedStorage.Shared.combatMod)

local testMod = {}


-- TEST 1: Pure Artificer vs anything (great for testing Artificer spells)
-- Put this in a Script/LocalScript and run
task.wait(2) -- let everything load

local artificerMobs = {
    "PlayerArtificer"
}
local allMobs = {}
for name,_ in pairs(combatMod.creatureStats) do
    if name ~= "FeralArtifactGuardian" then -- optional: exclude ferals
        table.insert(allMobs, name)
    end
end

local artificerSpells = {"StarterStaffArtificer"}

print("=== ARTIFICER SPELL TEST (100 casts) ===")
for i = 1, 50 do
    local attacker = artificerMobs[math.random(#artificerMobs)]
    local defender = allMobs[math.random(#allMobs)]
    local spell = artificerSpells[math.random(#artificerSpells)]
    
    local dmg = combatMod.SpellAttackResult(attacker, defender, spell)
    print(string.format("%3d | %s → %s | Spell: %-22s | Damage/Heal: %d", 
          i, attacker, defender, spell, dmg))
end


-- TEST 2: Pure Primordial chaos

local primordialMobs = {
    "PlayerPrimordial"
}
local allMobs = {}
for name,_ in pairs(combatMod.creatureStats) do table.insert(allMobs, name) end

local primordialSpells = {
    "StarterStaffPrimordial"
}

print("\n=== PRIMORDIAL SPELL TEST (100 casts) ===")
for i = 1, 50 do
    local attacker = primordialMobs[math.random(#primordialMobs)]
    local defender = allMobs[math.random(#allMobs)]
    local spell = primordialSpells[math.random(#primordialSpells)]
    
    local dmg = combatMod.SpellAttackResult(attacker, defender, spell)
    print(string.format("%3d | %s → %s | Spell: %-25s | Result: %d", 
          i, attacker, defender, spell, dmg))
end


-- TEST 3: Pure Nature love & pain

local natureMobs = {
    "PlayerNature"
}
local allMobs = {}
for name,_ in pairs(combatMod.creatureStats) do table.insert(allMobs, name) end

local natureSpells = {
    "StarterStaffNature"
}

print("\n=== NATURE SPELL TEST (100 casts) ===")
for i = 1, 50 do
    local attacker = natureMobs[math.random(#natureMobs)]
    local defender = allMobs[math.random(#allMobs)]
    local spell = natureSpells[math.random(#natureSpells)]
    
    local dmg = combatMod.SpellAttackResult(attacker, defender, spell)
    print(string.format("%3d | %s → %s | Spell: %-22s | Result: %d", 
          i, attacker, defender, spell, dmg))
end


return testMod