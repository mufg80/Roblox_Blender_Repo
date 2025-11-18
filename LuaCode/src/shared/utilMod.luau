local collectionService = game:GetService("CollectionService")
local combatMod = require(game:GetService("ReplicatedStorage").Shared.combatMod)
local utilMod = {}

-- Cache for performance
local CharacterList = {}
local CharacterSet = {}

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

-- Initialize
for _, inst in ipairs(collectionService:GetTagged("Character")) do
    addCharacter(inst)
end
collectionService:GetInstanceAddedSignal("Character"):Connect(addCharacter)
collectionService:GetInstanceRemovedSignal("Character"):Connect(removeCharacter)

function utilMod.GetCharactersTagged()
    return CharacterList
end

function utilMod.GetMagnitude(part1, part2)
    if not part1 or not part2 then return math.huge end
    return (part1.Position - part2.Position).Magnitude
end

function utilMod.GetModelByIDorName(targetIdOrName)
    -- targetIdOrName is ALWAYS a string (pet.Name) or number (UserId)
    local targetType = type(targetIdOrName)
    
    for _, character in ipairs(CharacterList) do
        -- Check by Name (for pets)
        if character.Name == targetIdOrName then
            return character
        end
        
        -- Check by UserId (for players)
        local player = game.Players:GetPlayerFromCharacter(character)
        if player and player.UserId == targetIdOrName then
            return character
        end
    end
    return nil
end

function utilMod.GetPlayerByUserId(userId)
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.UserId == userId then return player end
    end
    return nil
end


function utilMod.IsPlayer(plr)
    for _, plrtest in ipairs(game.Players:GetPlayers())do
        if plrtest.Name == plr.Name then
            return true
        end
    end
    return false

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

function utilMod.GetStatsSafelyForPlrorNpc(npc)
    local enemyTable = nil
    if utilMod.IsPlayer(npc)then
        local plr = game.Players:GetPlayerFromCharacter(npc)
        local magic = plr:GetAttribute("Magic")
        enemyTable = combatMod.ShallowTableCopy("Player"..magic)
    else
        enemyTable = combatMod.ShallowTableCopy(npc)
    end
    return enemyTable
end

function utilMod.AcceptableDistanceToOpponent(model, enemy)
    local enemyTable = utilMod.GetStatsSafelyForPlrorNpc(enemy)
    
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    local enemyhrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
    if not hrp or not enemyhrp then return false end
    
    local distance = utilMod.GetMagnitude(hrp, enemyhrp)
    return distance <= (enemyTable.distanceForAttacker)
end

-- Keep your existing utility functions unchanged
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
        return raycastResult.Position.Y + npcHeight
    end
    return nil
end

function utilMod.FindRandomLocationByCharacter(character, hoverdistance)
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local hoverPos = rootPart.Position + Vector3.new(
            math.random(-hoverdistance, hoverdistance), 
            0, 
            math.random(-hoverdistance, hoverdistance)
        )
        return hoverPos
    end
    return nil
end

function utilMod.createCustomExplosion(position, visualSize, time, color)
    local attachment = Instance.new("Attachment")
    attachment.Position = position
    attachment.Parent = workspace.Terrain

    local pe = Instance.new("ParticleEmitter")
    pe.Parent = attachment
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

    game:GetService("Debris"):AddItem(attachment, time)
end

return utilMod