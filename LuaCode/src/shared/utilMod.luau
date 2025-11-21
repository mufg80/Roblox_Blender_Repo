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

-- utilMod.GetMagnitude(a, b)
-- a and b can each be: Instance (Part/BasePart) or Vector3
-- Returns the distance between the two points, or math.huge if invalid

local function GetPosition(obj)
    if typeof(obj) == "Instance" then
        if obj:IsA("BasePart") then
            return obj.Position
        else
            return nil, "Object is not a BasePart"
        end
    elseif typeof(obj) == "Vector3" then
        return obj
    else
        return nil, "Expected BasePart or Vector3"
    end
end

function utilMod.GetMagnitude(a, b)
    if not a or not b then return math.huge end
    
    local posA, errA = GetPosition(a)
    local posB, errB = GetPosition(b)
    
    if not posA then
        warn("GetMagnitude: First argument invalid -", errA, a)
        return math.huge
    end
    if not posB then
        warn("GetMagnitude: Second argument invalid -", errB, b)
        return math.huge
    end
    
    return (posA - posB).Magnitude
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
    model:SetAttribute("IdleStartTime", tick())
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

-- Generate a unique name based on baseofname by scanning workspace.Pets and workspace.Ferals
function utilMod.uniqueName(baseofname)
    local highest = 0

    -- Helper to scan a folder for matching names
    local function scanFolder(folder)
        if not folder then return end
        for _, item in ipairs(folder:GetChildren()) do
            if item.Name:sub(1, #baseofname) == baseofname then
                -- Match pattern baseofname_### (numeric suffix)
                local suffix = item.Name:match("^" .. baseofname .. "_(%d+)$")
                if suffix then
                    local num = tonumber(suffix)
                    if num and num > highest then
                        highest = num
                    end
                end
            end
        end
    end

    -- Scan both Pets and Ferals folders
    scanFolder(workspace:FindFirstChild("Pets"))
    scanFolder(workspace:FindFirstChild("Ferals"))

    -- Return next name, padded to 3 digits
    local newNum = highest + 1
    return string.format("%s_%03d", baseofname, newNum)
end


return utilMod