--!strict
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local serverStorage = game:GetService("ServerStorage")

local buffMod = {}

-- At the top of the module (next to RUNNING_EFFECTS)
local RUNNING_EFFECTS: { [string]: thread } = {}   -- now stores the coroutine thread itself
-- (change from boolean to thread)

--[[
    Attempts to convert a nearby Mana Spout into a magic-specific lith (building)
    based on the player's current Magic type.
    
    @param player The player attempting to convert a spout
    @return true if a spout was successfully converted, false otherwise
]]
function buffMod.ConvertSpout(player: Player): boolean
    if not player.Character then return false end

    local spouts = workspace:WaitForChild("ManaPoints"):GetChildren()
    for _, spout in pairs(spouts) do
        if spout.Name ~= "ManaSpout" then continue end

        local dist = utilMod.GetMagnitudeHelper(player.Character, spout)
        if dist < statsMod.SpellInfo.ConvertSpout.range then
            local magictype: number = player:GetAttribute("Magic") or statsMod.MagicType.None
            if magictype == statsMod.MagicType.None then
                return false
            end

            local buildingName = ({
                [statsMod.MagicType.Artificer] = "ArtificerLith",
                [statsMod.MagicType.Primordial] = "PrimordialLith",
                [statsMod.MagicType.Nature] = "NatureLith",
            })[magictype]

            if not buildingName then
                warn("Should not reach me - unknown magic type")
                return false
            end

            local building: Model = serverStorage:WaitForChild("Buildings")[buildingName]:Clone()
            local spoutCFrame = spout:GetPivot()
            building:PivotTo(spoutCFrame)
            building.Parent = workspace.ManaPoints
            building:SetAttribute("OwnedBy", player.UserId)
            spout:Destroy() -- safer than Parent = nil
            return true
        end
    end

    return false
end

--[[
    Reclaims the closest pet within spell range and refunds mana.
    Skips any pet already marked for recycling.
    
    @param player     The player casting the reclaim spell
    @param spellname  Name of the spell (used to get range from statsMod)
    @param mypets     Array-like table of pet Models owned by the player
    @return true if a pet was reclaimed, false if none in range or all skipped
]]
function buffMod.ReclaimPet(player: Player, spellname: string, mypets: {Model}): boolean
    local spell = statsMod.SpellInfo[spellname]
    if not spell then return false end
    local range: number = spell.range

    local closestDis = math.huge
    local mypet: Model? = nil

    for _, pet in mypets do
        if pet:GetAttribute("RecycleMe") == true then continue end
        local mag = utilMod.GetMagnitudeHelper(player.Character, pet)
        if mag < closestDis then
            closestDis = mag
            mypet = pet
        end
    end

    if not mypet then return false end

    local thismags = utilMod.GetMagnitudeHelper(player.Character, mypet)
    if thismags >= range then return false end

    print("destroy pet")
    mypet:SetAttribute("RecycleMe", true)
    local currentmana: number = player:GetAttribute("Mana") or 0
    local maxmana: number = player:GetAttribute("MaxMana") or 100
    player:SetAttribute("Mana", math.min(currentmana + 50, maxmana))
    return true
end

--[[
    Internal helper: Applies or removes stat modifications from a buff/debuff.
    
    @param model       The character Model (player or NPC)
    @param spellname   Name of the buff/debuff spell
    @param multiplier  1 to apply, -1 to remove
    @return true if changes were applied successfully
]]
local function ApplyStatChanges(model: Model, spellname: string, multiplier: number): boolean
    local buffInfo = statsMod.BuffInfo[spellname]
    if not buffInfo then return false end

    -- If it's a player character, modify Player attributes instead of Character's Data folder
    local player = game.Players:GetPlayerFromCharacter(model)
    local target = player or model

    local dataFolder = target:FindFirstChild("Data")
    if not dataFolder then return false end

    for statName: string, changeValue: number in pairs(buffInfo) do
        local valueObj = dataFolder:FindFirstChild(statName)
        if valueObj and valueObj:IsA("ValueBase") and typeof(valueObj.Value) == "number" then
            valueObj.Value += changeValue * multiplier
        end
    end

    return true
end
--[[
    Applies a buff, debuff, or heal-over-time effect to a target.
    Supports both Player objects and raw Model characters (NPCs).
    If the same spell is already active on the target it will be refreshed
    (old effect cancelled → stats reverted → new full-duration effect applied).
]]
function buffMod.BuffDebuffHeal(caster: Player?, target: Model | Player, spellname: string): boolean
    if not caster or not target or not spellname then
        warn("BuffDebuffHeal: Missing required parameter(s)")
        return false
    end
    if not caster:IsA("Player") then
        warn("BuffDebuffHeal: Caster is not a Player instance")
        return false
    end

    -- Normalize to Model instance
    local modelInstance: Model
    if typeof(target) == "Instance" and target:IsA("Player") then
        modelInstance = target.Character
    else
        modelInstance = target :: Model
    end
    if not modelInstance or not modelInstance.Parent then return false end

    local key = tostring(modelInstance) .. spellname

    -- Refresh logic: cancel existing coroutine if one exists
    if RUNNING_EFFECTS[key] then
        -- Remove old stat changes immediately
        ApplyStatChanges(modelInstance, spellname, -1)
        -- Kill the old coroutine
        task.cancel(RUNNING_EFFECTS[key])
        -- Clean up attribute so the new one can be applied
        modelInstance:SetAttribute("Buff_" .. spellname, nil)
        -- (no need to nil the table entry – we'll overwrite it)
    end

    -- Mark as active right away (prevents race conditions)
    modelInstance:SetAttribute("Buff_" .. spellname, true)

    local spellinfo = statsMod.SpellInfo[spellname]
    local buffinfo = statsMod.BuffInfo[spellname]
    if not spellinfo or not buffinfo then
        modelInstance:SetAttribute("Buff_" .. spellname, nil)
        return false
    end

    local duration: number = buffinfo.seconds or 0
    local isHeal   = spellinfo.spellType == "heal"
    local isBuff   = spellinfo.spellType == "buff"
    local isDebuff = spellinfo.spellType == "debuff"

    -- Apply instant changes (buff/debuff only)
    local applyFailed = false
    if isBuff or isDebuff then
        applyFailed = not ApplyStatChanges(modelInstance, spellname, 1)
    end

    -- Create the new coroutine
    local co = task.spawn(function()
        local elapsed = 0
        local tickRate = 1

        while elapsed < duration do
            task.wait(tickRate)
            elapsed += tickRate

            if not modelInstance or not modelInstance.Parent then break end

            -- Tick event
            local owner = game.Players:GetPlayerFromCharacter(modelInstance) or modelInstance
            local ev = owner:FindFirstChild("BuffDebuffEvent")
            if ev and ev:IsA("BindableEvent") then
                ev:Fire(caster, spellname)
            end

            -- Heal over time
            if isHeal then
                local hum = modelInstance:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    local healPerTick = (buffinfo.hitPoints and buffinfo.hitPoints > 0)
                        and (buffinfo.hitPoints / duration)
                        or buffinfo.hitPoints or 0
                    hum.Health = math.clamp(hum.Health + healPerTick, 0, hum.MaxHealth)
                end
            end
        end

        -- Final removal
        if isBuff or isDebuff then
            ApplyStatChanges(modelInstance, spellname, -1)
        end

        -- Removal event
        local owner = game.Players:GetPlayerFromCharacter(modelInstance) or modelInstance
        local ev = owner:FindFirstChild("RemoveBuffDebuffEvent")
        if ev and ev:IsA("BindableEvent") then
            ev:Fire(caster, spellname)
        end

        -- Cleanup
        modelInstance:SetAttribute("Buff_" .. spellname, nil)
        RUNNING_EFFECTS[key] = nil
    end)

    -- Store the new coroutine so we can cancel it later
    RUNNING_EFFECTS[key] = co

    -- Return value stays exactly the same as before
    return if (isBuff or isDebuff) then not applyFailed else true
end

return buffMod