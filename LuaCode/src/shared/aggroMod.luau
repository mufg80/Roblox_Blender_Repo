local ReplicatedStorage = game:GetService("ReplicatedStorage")

local utilMod = require(ReplicatedStorage.Shared.utilMod)

local aggroMod = {}

function aggroMod.hateListPet(aggroRadius, hateList, model, hrp)
    local aggroSqr = aggroRadius ^ 2
    local leashSqr = (aggroRadius * 3) ^ 2

    -- Add nearby threats
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.UserId ~= model:GetAttribute("OwnedBy") then
            if player:GetAttribute("HasFallen") then
                continue
            end
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
            local mod = utilMod.GetModelByIDorName(id)
            if mod and utilMod.IsAlly(model, mod) then
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
        elseif target and hum and hum.Health <= 1 or target:GetAttribute("HasFallen") then
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
            if player:GetAttribute("HasFallen") then
                continue
            end
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
                local mod = utilMod.GetModelByIDorName(id)
                if utilMod.IsAlly(model, mod) then
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
            elseif target and hum and hum.Health <= 1 or target:GetAttribute("HasFallen") then
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
                local enemyhum = target and target:FindFirstChildOfClass("Humanoid")
                if enemyhum and enemyhum.Health > 0 then
                    if target and not target:GetAttribute("HasFallen") and enemyhum then
                        bestId = id
                        bestThreat = threat
                    else
                        hateList[id] = nil
                    end
                elseif enemyhum and enemyhum.Health < 1 then
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