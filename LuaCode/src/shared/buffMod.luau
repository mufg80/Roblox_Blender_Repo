
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local serverStorage = game:GetService("ServerStorage")
local buffMod = {}

function buffMod.ConvertSpout(player):boolean
    if not player.Character then return end
    local spouts = workspace:WaitForChild("ManaPoints"):GetChildren()
    for _,spout in pairs(spouts) do

        if spout.Name ~= "ManaSpout" then continue end

        local dist = utilMod.GetMagnitudeHelper(player.Character, spout)
        if dist < statsMod.SpellInfo.ConvertSpout.range then
            local magictype = player:GetAttribute("Magic")
            if magictype == statsMod.MagicType.None then
                return false
            elseif magictype == statsMod.MagicType.Artificer then
                local building: Model = serverStorage:WaitForChild("Buildings").ArtificerLith:Clone()
                local spoutCFrame = spout:GetPivot()
                building:PivotTo(spoutCFrame)
                building.Parent = workspace.ManaPoints
                building:SetAttribute("OwnedBy", player.UserId)
                spout.Parent = nil
                return true
            elseif magictype == statsMod.MagicType.Primordial then
                local building: Model = serverStorage:WaitForChild("Buildings").PrimordialLith:Clone()
                local spoutCFrame = spout:GetPivot()
                building:PivotTo(spoutCFrame)
                building.Parent = workspace.ManaPoints
                building:SetAttribute("OwnedBy", player.UserId)
                spout.Parent = nil
                return true
            elseif magictype == statsMod.MagicType.Nature then
                local building: Model = serverStorage:WaitForChild("Buildings").NatureLith:Clone()
                local spoutCFrame = spout:GetPivot()
                building:PivotTo(spoutCFrame)
                building.Parent = workspace.ManaPoints
                building:SetAttribute("OwnedBy", player.UserId)
                spout.Parent = nil
                return true
            else
                warn("Should not reach me.")
            end
            return false
        end
    end
    return false
end

function buffMod.ReclaimPet(player, spellname, mypets):boolean
    local spell = statsMod.SpellInfo[spellname]
    local range = spell.range
    local closestDis = math.huge
    local mypet = nil
    for i,pet in mypets do
        if pet:GetAttribute("RecycleMe") == true then
            continue
        end
        local mag = utilMod.GetMagnitudeHelper(player.Character, pet)
        if mag < closestDis then
            closestDis = mag
            mypet = mypets[i]
        end
    end
    if not mypet then return end
    local thismags = utilMod.GetMagnitudeHelper(player.Character, mypet)
    if thismags < range then
        print("destroy pet")
        mypet:SetAttribute("RecycleMe", true)
        local currentmana = player:GetAttribute("Mana")
        player:SetAttribute("Mana", math.min(currentmana + 50, player:GetAttribute("MaxMana")))
        return true
    else
        return false
    end

    
end

local RUNNING_EFFECTS = {} -- [model] = { [spellname] = true } -- prevents duplicate coroutines

-- Helper: Apply or remove stat changes directly to the Value objects
local function ApplyStatChanges(model: Model, spellname: string, multiplier: number)
    local buffInfo = statsMod.BuffInfo[spellname]
    if not buffInfo then return end

    local dataFolder = model:FindFirstChild("Data")
    if not dataFolder then return end

    for statName, changeValue in pairs(buffInfo) do
        local valueObj = dataFolder:FindFirstChild(statName)
        if valueObj and valueObj:IsA("ValueBase") then
            -- Only modify if it's a number!
            if typeof(valueObj.Value) == "number" then
                valueObj.Value += changeValue * multiplier
            end
        end
    end
end

-- Main function
function buffMod.BuffDebuffHeal(target: Model | Player, caster: Player?, spellname: string)
    local modelInstance: Model
    local player: Player?

    -- Support both Player and NPC Model
    if target:IsA("Player") then
        player = target
        modelInstance = target.Character
    else
        modelInstance = target
        player = game.Players:GetPlayerFromCharacter(modelInstance)
    end

    if not modelInstance or not modelInstance.Parent then return end

    -- Prevent duplicate application
    local key = tostring(modelInstance) .. spellname
    if RUNNING_EFFECTS[key] then
        return -- Already active
    end
    RUNNING_EFFECTS[key] = true

    -- Mark as active
    modelInstance:SetAttribute("Buff_" .. spellname, true)

    local spellinfo = statsMod.SpellInfo[spellname]
    local buffinfo = statsMod.BuffInfo[spellname]

    if not spellinfo or not buffinfo then
        RUNNING_EFFECTS[key] = nil
        modelInstance:SetAttribute("Buff_" .. spellname, nil)
        return
    end

    local duration = buffinfo.seconds or 0
    local isHeal = spellinfo.spellType == "heal"
    local isBuff = spellinfo.spellType == "buff"
    local isDebuff = spellinfo.spellType == "debuff"

    -- Apply instant changes
    if isBuff then
        ApplyStatChanges(modelInstance, spellname, 1)
    elseif isDebuff then
        ApplyStatChanges(modelInstance, spellname, 1) -- debuffs are usually negative values in BuffInfo
    end

    -- Start timer
    task.spawn(function()
        local elapsed = 0
        local tickRate = 1 -- seconds

        while elapsed < duration do
            task.wait(tickRate)
            elapsed += tickRate

            if not modelInstance or not modelInstance.Parent then break end

            -- Heal over time
            if isHeal then
                local hum = modelInstance:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    local healPerTick = buffinfo.hitPoints / duration -- smooth heal
                    if not healPerTick or healPerTick <= 0 then
                        healPerTick = buffinfo.hitPoints -- fallback: heal all at once?
                    end
                    hum.Health = math.clamp(hum.Health + healPerTick, 0, hum.MaxHealth)
                end
            end
        end

        -- Remove effects when done
        if isBuff or isDebuff then
            ApplyStatChanges(modelInstance, spellname, -1)
        end

        -- Cleanup
        modelInstance:SetAttribute("Buff_" .. spellname, nil)
        RUNNING_EFFECTS[key] = nil
    end)
end








return buffMod