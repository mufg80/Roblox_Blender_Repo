local collectionService = game:GetService("CollectionService")
local combatMod = require(game:GetService("ReplicatedStorage").Shared.combatMod)
local utilMod = {}

function utilMod.HexToColor3(hex)
    hex = hex:gsub("#","")
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    return Color3.new(r, g, b)
end

function utilMod.DistancetoGround(hrpX, hrpZ, ignoreList, npcHeight)
    local rayOrigin = Vector3.new(hrpX, 5000, hrpZ)
    local rayDirection = Vector3.new(0, -10000, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        local distance = raycastResult.Position.Y + npcHeight
        return distance
    else
        return nil
    end
end



local CharacterList = {}   -- array of instances with the "Character" tag
local CharacterSet = {}    -- map for fast membership checks

local function addCharacter(inst)
    if not CharacterSet[inst] then
        CharacterSet[inst] = true
        table.insert(CharacterList, inst)
    end
end

local function removeCharacter(inst)
    if CharacterSet[inst] then
        CharacterSet[inst] = nil
        for i = #CharacterList, 1, -1 do
            if CharacterList[i] == inst then
                table.remove(CharacterList, i)
                break
            end
        end
    end
end

-- initialize with already-tagged instances
for _, inst in ipairs(collectionService:GetTagged("Character")) do
    addCharacter(inst)
end

-- update on tag added/removed
collectionService:GetInstanceAddedSignal("Character"):Connect(addCharacter)
collectionService:GetInstanceRemovedSignal("Character"):Connect(removeCharacter)

-- accessor (returns the live list; return a shallow copy if you want immutable snapshot)
function utilMod.GetCharactersTagged()
    return CharacterList
end


function utilMod.GetMagnitude(part1, part2)
    if not part1 or not part2 then
        return 0
    end
    local pos1 = part1.Position
    local pos2 = part2.Position
    return (pos1 - pos2).Magnitude
end


function utilMod.FindRandomLocationByCharacter(character, hoverdistance)
    if not character then
        return nil
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        -- use waypoint service to map route to an area randomly within a radius of hoverdistance
        local hoverPos = rootPart.Position + Vector3.new(math.random(-hoverdistance, hoverdistance), 0, math.random(-hoverdistance, hoverdistance))
        return hoverPos
    end
    return nil
end

function utilMod.GetModelByIDorName(target)
    for _, character in ipairs(utilMod.GetCharactersTagged()) do
        if character.Name == target then
            return character
        end
        local idAttr = game.Players:GetPlayerFromCharacter(character) and game.Players:GetPlayerFromCharacter(character).UserId
        if idAttr and idAttr == target then
            return character
        end
    end
    return nil
end

function utilMod.GetPlayerByUserId(userId)
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.UserId == userId then
            return player
        end
    end
    return nil
end

function utilMod.SetFlagsForMoving(model)
    model:SetAttribute("IsMoving", true)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForCombat(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", true)
end

function utilMod.SetFlagsForDeath(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", false)
    model:SetAttribute("HasFallen", true)
    model:SetAttribute("InCombat", false)
end

function utilMod.SetFlagsForIdle(model)
    model:SetAttribute("IsMoving", false)
    model:SetAttribute("IsIdle", true)
    model:SetAttribute("HasFallen", false)
    model:SetAttribute("InCombat", false)
end

function utilMod.AcceptableDistanceToOpponent(model, enemy)
    local enemyTable = combatMod.GetCreatureTableFromModel(enemy)
    if not enemyTable then
        return false
    end
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    local enemyhrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
    if not hrp or not enemyhrp then
        return false
    end
    local distance = (hrp.Position - enemyhrp.Position).Magnitude
    if distance <= (enemyTable.distanceForAttacker + 1) and distance >= (enemyTable.distanceForAttacker -1) then
        return true
    else
        return false
    end
end



function utilMod.createCustomExplosion(position, visualSize, time, color)  -- visualSize = e.g., 5, 20, 50
    -- Custom visuals: Scaled fire/smoke ring
    local attachment = Instance.new("Attachment")
    attachment.Position = position
    attachment.Parent = workspace.Terrain  -- Or a part

    local pe = Instance.new("ParticleEmitter")
    pe.Parent = attachment
    --pe.Texture = "rbxasset://textures/particles/fire_main.dds"
    pe.Color = ColorSequence.new(color, color)
    pe.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, visualSize),
        NumberSequenceKeypoint.new(1, 0)
    }
    pe.Lifetime = NumberRange.new(0.1, 0.4)
    pe.Rate = 1000
    pe.SpreadAngle = Vector2.new(360, 360)
    pe.Speed = NumberRange.new(5, 20)
    pe.Drag = 5


    -- Cleanup
    game:GetService("Debris"):AddItem(attachment, time)
end

return utilMod