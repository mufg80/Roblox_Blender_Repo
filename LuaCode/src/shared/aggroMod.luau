local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utilMod = require(ReplicatedStorage.Shared.utilMod)

local aggroMod = {}

-- Add this helper function inside the module, above the main functions
local function isAlly(model, targetId)
    local ownerId = model:GetAttribute("OwnedBy")
    if not ownerId then return false end

    -- Case 1: Target is a player (UserId)
    if typeof(targetId) == "number" then
        return targetId == ownerId
    end

    -- Case 2: Target is a pet/NPC (by Name)
    local targetModel = utilMod.GetModelByIDorName(targetId)
    if not targetModel then return false end

    local targetOwnerId = targetModel:GetAttribute("OwnedBy")
    return targetOwnerId and targetOwnerId == ownerId
end

function aggroMod.hateListPet(aggroRadius, hateList, model, hrp)
    local aggroSqr = aggroRadius ^ 2
    local leashSqr = (aggroRadius * 3) ^ 2

    -- Add nearby threats
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.UserId ~= model:GetAttribute("OwnedBy") then
            local root = player.Character and (player.Character.HumanoidRootPart or player.Character:FindFirstChild("Torso"))
            if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr and not hateList[player.UserId] then
                hateList[player.UserId] = 8
            end
        end
    end

    local petsFolder = workspace:FindFirstChild("Pets")
    if petsFolder then
        for _, pet in ipairs(petsFolder:GetChildren()) do
            if pet ~= model and pet:GetAttribute("OwnedBy") ~= model:GetAttribute("OwnedBy") then
                local root = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChild("Torso")
                if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr and not hateList[pet.Name] then
                    hateList[pet.Name] = 4
                end
            end
        end
    end

    local feralsFolder = workspace:FindFirstChild("Ferals")
    if feralsFolder then
        for _, feral in ipairs(feralsFolder:GetChildren()) do
            local root = feral:FindFirstChild("HumanoidRootPart") or feral:FindFirstChild("Torso")
            if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr and not hateList[feral.Name] then
                hateList[feral.Name] = 6
            end
        end
    end

    -- AFTER adding players + pets + ferals to hateList
    -- BEFORE leash/decay and target selection

    -- REMOVE ALLIES (owner + owner's other pets/NPCs)
    local ownerId = model:GetAttribute("OwnedBy")
    if ownerId then
        for id, _ in pairs(hateList) do
            if isAlly(model, id) then
                hateList[id] = nil
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
    elseif currentTargetId ~= "None" then
        model:SetAttribute("TargetIDorName", "None")
    end
end

function aggroMod.hateListFeral(aggroRadius, hateList, model, hrp)
 ----------------------------------------------------------------
        -- THREAT / TARGET SELECTION
        ----------------------------------------------------------------
        local aggroSqr = aggroRadius ^ 2
        local leashSqr = (aggroRadius * 3) ^ 2

        -- Add nearby threats
        for _, player in ipairs(game.Players:GetPlayers()) do
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

                
        -- EARLY ALLY REMOVAL (for ferals that might be owned, e.g. tamed ones)
        local ownerId = model:GetAttribute("OwnedBy")
        if ownerId then
            for id, _ in pairs(hateList) do
                if isAlly(model, id) then
                    hateList[id] = nil
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
        elseif currentTargetId ~= "None" then
            model:SetAttribute("TargetIDorName", "None")
        end

end



return aggroMod