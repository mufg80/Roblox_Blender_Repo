-- recycleMod.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Require combatMod (for customTrim and other utilities)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)

local recycleMod = {}
recycleMod.thedead = {}
recycleMod.theferaldead = {}

----------------------------------------------------------------
-- Helper: reset an NPC back to its default state
----------------------------------------------------------------
function recycleMod.resetNPC(npc)
    if not npc then return end

    -- Reset attributes
    npc:SetAttribute("TargetIDorName", "None")
    npc:SetAttribute("HasFallen", false)
    npc:SetAttribute("InCombat", false)
    npc:SetAttribute("IsIdle", true)
    npc:SetAttribute("IsMoving", false)
    npc:SetAttribute("OwnedBy", false)
    npc:SetAttribute("RecycleMe", false)

    -- Reset humanoid
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.PlatformStand = false
    end

    -- Disable + re-enable scripts (restart clean)
    for _, s in ipairs(npc:GetDescendants()) do
        if s:IsA("Script") then
            s.Disabled = true
            s.Disabled = false
        end
    end
end

----------------------------------------------------------------
-- EXISTENCE CHECKS
----------------------------------------------------------------
function recycleMod.CheckIfExistsPet(baseName)
    local storagePets = ServerStorage:FindFirstChild("Pets")
    if not storagePets then return false end

    for _, npc in ipairs(storagePets:GetChildren()) do
        if combatMod.customTrim(npc.Name) == baseName then
            return true
        end
    end
    return false
end

function recycleMod.CheckIfExistsFeral(baseName)
    local storageFerals = ServerStorage:FindFirstChild("Ferals")
    if not storageFerals then return false end

    for _, npc in ipairs(storageFerals:GetChildren()) do
        if combatMod.customTrim(npc.Name) == baseName then
            return true
        end
    end
    return false
end

----------------------------------------------------------------
-- RETURN FUNCTIONS
----------------------------------------------------------------
function recycleMod.ReturnPet(baseName)
    local storagePets = ServerStorage:FindFirstChild("Pets")
    if not storagePets then return nil end

    for _, npc in ipairs(storagePets:GetChildren()) do
        if combatMod.customTrim(npc.Name) == baseName then
            npc.Parent = workspace:WaitForChild("Pets")
            recycleMod.resetNPC(npc)
            return npc
        end
    end
    return nil
end

function recycleMod.ReturnFeral(baseName)
    local storageFerals = ServerStorage:FindFirstChild("Ferals")
    if not storageFerals then return nil end

    for _, npc in ipairs(storageFerals:GetChildren()) do
        if combatMod.customTrim(npc.Name) == baseName then
            npc.Parent = workspace:WaitForChild("Ferals")
            recycleMod.resetNPC(npc)
            return npc
        end
    end
    return nil
end

----------------------------------------------------------------
-- FLAG DEAD LOOP
----------------------------------------------------------------
function recycleMod.flagAsDead()
    while true do
        -- Track fallen pets
        for _, pet in ipairs(workspace:WaitForChild("Pets"):GetChildren()) do
            if pet:GetAttribute("RecycleMe") and not recycleMod.thedead[pet.Name] then
                recycleMod.thedead[pet.Name] = tick()
            end
        end

        -- Track fallen ferals
        for _, feral in ipairs(workspace:WaitForChild("Ferals"):GetChildren()) do
            if feral:GetAttribute("RecycleMe") and not recycleMod.theferaldead[feral.Name] then
                recycleMod.theferaldead[feral.Name] = tick()
            end
        end

        -- Recycle pets
        for name, t in pairs(recycleMod.thedead) do
            if (tick() - t) > 3 then
                local npc = workspace.Pets:FindFirstChild(name)
                if npc then
                    local storagePets = ServerStorage:FindFirstChild("Pets")
                    if storagePets then
                        npc.Parent = storagePets
                        recycleMod.resetNPC(npc)
                    end
                end
                recycleMod.thedead[name] = nil
            end
        end

        -- Recycle ferals
        for name, t in pairs(recycleMod.theferaldead) do
            if (tick() - t) > 3 then
                local npc = workspace.Ferals:FindFirstChild(name)
                if npc then
                    local storageFerals = ServerStorage:FindFirstChild("Ferals")
                    if storageFerals then
                        npc.Parent = storageFerals
                        recycleMod.resetNPC(npc)
                    end
                end
                recycleMod.theferaldead[name] = nil
            end
        end
        task.wait(.5)
    end
end

task.spawn(function() recycleMod.flagAsDead() end)

return recycleMod
