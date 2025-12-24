--!strict

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local ContextActionService = game:GetService("ContextActionService")
local serverStorage = game:GetService("ServerStorage")
local repstore = game:GetService("ReplicatedStorage")

local buffMod = {}

-- Table to track active buff tasks per model+spell
local activeBuffs: { [string]: { thread: thread, label: ImageLabel } } = {}

-- Table to track running buff/debuff/heal coroutines
local RUNNING_EFFECTS: { [string]: thread } = {}

-- NEW: Track sourceStats and refresh function per model
local modelStatRefreshers: { [Model]: () -> () } = {}
local modelBaseStats: { [Model]: { [string]: any } } = {}

export type BuffMod = {
    Setup: (model: Model, sourceStats: { [string]: any }) -> (),
    ApplyBillboardBuffLabel: (spelltype: string, spellname: string, duration: number, caster: Model, model: Model) -> (),
    CheckDistanceOnSpouts: (player: Player) -> boolean,
    ConvertSpout: (player: Player) -> boolean,
    ReclaimPet: (player: Player, spellname: string, mypets: { Model }) -> boolean,
    BuffDebuffHeal: (caster: Player?, target: Model | Player, spellname: string) -> boolean,
    SelectTargetsForAggro: (caster: Player, spellinfo: any) -> (),
    StartBuffLabelTimer: (imageLabel: ImageLabel, duration: number, model: Model, key: string) -> (),
}

-- NEW: Setup buff events and stat refresh system on an NPC model
function buffMod.Setup(model: Model, sourceStats: { [string]: any })
    if not model or not sourceStats then
        return
    end

    -- Store base stats for later restoration
    modelBaseStats[model] = utilMod.ShallowTableCopy(sourceStats) -- deep enough for flat stats

    -- Create events if not already present
    local addEvent = model:FindFirstChild("BuffDebuffEvent") or Instance.new("BindableEvent")
    addEvent.Name = "BuffDebuffEvent"
    addEvent.Parent = model

    local removeEvent = model:FindFirstChild("RemoveBuffDebuffEvent") or Instance.new("BindableEvent")
    removeEvent.Name = "RemoveBuffDebuffEvent"
    removeEvent.Parent = model

    -- Local refresh function
    local function refreshStats(spellname: string?)
        local baseStats = utilMod.GetStatsFromFolder(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        humanoid.MaxHealth = baseStats.hitPoints or humanoid.MaxHealth
        if humanoid.Health > humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
        humanoid.WalkSpeed = 16 * (baseStats.speed or 1)

        if spellname and statsMod.BuffInfo[spellname] and statsMod.BuffInfo[spellname].hitPoints then
            humanoid.Health = math.min(humanoid.Health + statsMod.BuffInfo[spellname].hitPoints, humanoid.MaxHealth)
        end

        -- Update attributes used in AI
        utilMod.SetAttribute(model, "IsStationary", utilMod.GetAttribute(model, "IsStationary") ~= false)
        utilMod.SetAttribute(model, "IdleReset", utilMod.GetAttribute(model, "IdleReset") or 15)
    end

    -- On buff/debuff apply → just refresh
    addEvent.Event:Connect(function(player: Player, spellname: string)
        refreshStats(spellname)
    end)

    -- On buff/debuff remove → check if no buffs left → restore base stats
    removeEvent.Event:Connect(function(player: Player, spellname: string)
        local hasAnyBuff = false
        for attName, _ in pairs(model:GetAttributes()) do
            if typeof(attName) == "string" and string.sub(attName, 1, 5) == "Buff_" then
                hasAnyBuff = true
                break
            end
        end

        if not hasAnyBuff then
            -- No buffs left → restore original base stats
            utilMod.CopyStatsToFolder(model, modelBaseStats[model])
        end

        refreshStats()
    end)

    -- Store refresher for potential future use
    modelStatRefreshers[model] = refreshStats

    -- Initial apply
    refreshStats()
end

function buffMod.ApplyBillboardBuffLabel(
    spelltype: string,
    spellname: string,
    duration: number,
    caster: Model,
    model: Model
)
    -- Validate spelltype
    if not table.find({ "buff", "debuff", "heal", "areaDamage", "damage" }, spelltype) then
        warn("ApplyBuffLabel: Invalid spelltype:", spelltype)
        return
    end

    -- Map spelltype to label name
    local labelName = ({
        buff = "BuffLabel",
        debuff = "DebuffLabel",
        heal = "HealLabel",
        damage = "DamageLabel",
        areaDamage = "DamageLabel",
    })[spelltype]

    local billboard: BillboardGui? = model:FindFirstChild("BillBoardGUI")
    if not billboard then
        return
    end

    local templateLabel: ImageLabel? = billboard.Frame.ZZBuffFrame:FindFirstChild(labelName)
    if not templateLabel then
        return
    end

    local imageLabel = templateLabel:Clone()
    imageLabel.Parent = billboard.Frame.ZZBuffFrame

    -- Unique key per model + spell
    local key = model.Name .. "_" .. spellname .. "_" .. billboard.Name

    -- Start the timer (this will also cancel any previous one for the same key)
    buffMod.StartBuffLabelTimer(imageLabel, duration, model, key)
end

-- buffMod.StartBuffLabelTimer
-- Handles only the visual display: showing, blinking in the last 5 seconds, and cleanup.
-- Does NOT handle attribute changes, healing, stat copying, etc.
function buffMod.StartBuffLabelTimer(imageLabel: ImageLabel, duration: number, model: Model, key: string): ()
    -- Cancel any existing task for this key (in case of re-application)
    if activeBuffs[key] then
        task.cancel(activeBuffs[key].thread)
        activeBuffs[key].label.Visible = false
        activeBuffs[key].label.Parent = nil
        activeBuffs[key] = nil
    end

    local blinkStartDelay: number = duration > 5 and duration - 5 or 0

    local thread = task.spawn(function()
        imageLabel.Visible = true
        local startTime = os.clock()

        while true do
            task.wait(1)

            -- Check if model is dead or destroyed
            if not model or not model.Parent or utilMod.GetAttribute(model, "HasFallen") then
                if imageLabel and imageLabel.Parent then
                    imageLabel.Visible = false
                    imageLabel.Parent = nil
                end
                activeBuffs[key] = nil
                return
            end

            -- Check if UI element was removed externally
            if not imageLabel or not imageLabel.Parent then
                activeBuffs[key] = nil
                return
            end

            local elapsed = os.clock() - startTime

            -- Blink during the last 5 seconds (or entire duration if shorter)
            if elapsed >= blinkStartDelay then
                local elapsedSeconds = math.floor(elapsed)
                imageLabel.Visible = (elapsedSeconds % 2 == 1)
            end

            -- Duration expired → clean up
            if elapsed >= duration then
                if imageLabel and imageLabel.Parent then
                    imageLabel.Visible = false
                    imageLabel.Parent = nil
                end
                activeBuffs[key] = nil
                return
            end
        end
    end)
    activeBuffs[key] = {thread = thread, label = imageLabel}
end

function buffMod.CheckDistanceOnSpouts(player: Player): boolean
    if not player.Character then
        return false
    end

    local manaPoints: Folder? = workspace:FindFirstChild("ManaPoints")
    if not manaPoints then
        return false
    end

    for _, child: Instance in pairs(manaPoints:GetChildren()) do
        if child.Name ~= "ManaSpout" then
            continue
        end
        local dist: number? = utilMod.GetDistance(player.Character, child)
        if dist and dist < statsMod.SpellInfo.ConvertSpout.range then
            return true
        end
    end
    return false
end

function buffMod.ConvertSpout(player: Player): boolean
    if not player.Character then
        return false
    end

    local manaPoints: Folder? = workspace:FindFirstChild("ManaPoints")
    if not manaPoints then
        return false
    end

    local spouts: { Instance } = manaPoints:GetChildren()
    for _, spout: Instance in pairs(spouts) do
        if spout.Name ~= "ManaSpout" then
            continue
        end

        local dist: number? = utilMod.GetDistance(player.Character, spout)
        if dist and dist < statsMod.SpellInfo.ConvertSpout.range then
            local magictype: any = utilMod.GetAttribute(player, "Magic") or statsMod.MagicType.None
            if magictype == statsMod.MagicType.None then
                return false
            end

            local buildingName: string? = ({
                [statsMod.MagicType.Artificer] = "ArtificerLith",
                [statsMod.MagicType.Primordial] = "PrimordialLith",
                [statsMod.MagicType.Nature] = "NatureLith",
            })[magictype]

            if not buildingName then
                warn("Should not reach me - unknown magic type")
                return false
            end

            local template: Model? = serverStorage:FindFirstChild("Buildings"):FindFirstChild(buildingName)
            if not template then
                return false
            end

            local building: Model = template:Clone()
            local spoutCFrame: CFrame = spout:GetPivot()
            building:PivotTo(spoutCFrame)
            building.Parent = manaPoints
            utilMod.SetAttribute(building, "OwnedBy", player.UserId)
            spout:Destroy()
            return true
        end
    end

    return false
end

function buffMod.ReclaimPet(player: Player, spellname: string, mypets: { Model }): boolean
    local spell: any = statsMod.SpellInfo[spellname]
    if not spell then
        return false
    end
    local range: number = spell.range

    local closestDis: number = math.huge
    local mypet: Model? = nil

    for _, pet: Model in mypets do
        if utilMod.GetAttribute(pet, "RecycleMe") == true then
            continue
        end
        local mag: number? = utilMod.GetDistance(player.Character, pet)
        if mag and mag < closestDis then
            closestDis = mag
            mypet = pet
        end
    end

    if not mypet then
        return false
    end

    local thismags: number? = utilMod.GetDistance(player.Character, mypet)
    if not thismags or thismags >= range then
        return false
    end

    utilMod.SetAttribute(mypet, "RecycleMe", true)
    local currentmana: number = utilMod.GetAttribute(player, "Mana") or 0
    local maxmana: number = utilMod.GetAttribute(player, "MaxMana") or 100
    utilMod.SetAttribute(player, "Mana", math.min(currentmana + 50, maxmana))
    local maxSouls: number? = utilMod.GetAttribute(player, "MaxSouls")
    local currentSouls: number = utilMod.GetAttribute(player, "Souls") or 0
    utilMod.SetAttribute(player, "Souls", math.min(currentSouls + 1, maxSouls or currentSouls + 1))
    repstore.Events.GainedSoulEvent:FireClient(player, utilMod.GetAttribute(player, "Souls"), maxSouls)
    return true
end

local function ApplyStatChanges(model: Model, spellname: string, multiplier: number): boolean
    local buffInfo: any = statsMod.BuffInfo[spellname]
    if not buffInfo then
        return false
    end

    local player: Player? = game.Players:GetPlayerFromCharacter(model)
    local target: Instance = player or model

    local dataFolder: Folder? = target:FindFirstChild("Data")
    if not dataFolder then
        return false
    end
    for statName: string, changeValue: number in pairs(buffInfo) do
        local valueObj: ValueBase? = dataFolder:FindFirstChild(statName)
        if valueObj and valueObj:IsA("ValueBase") and typeof(valueObj.Value) == "number" then
            valueObj.Value += changeValue * multiplier
        end
    end

    return true
end

local function FireBuffNotificationEvent(
    isHeal: boolean,
    targetIsPlayer: boolean,
    modelInstance: Model | Player,
    spellname: string
): ()
    if targetIsPlayer then
        local player: Player? = game.Players:GetPlayerFromCharacter(modelInstance :: Model)
        if player then
            repstore.Events.BuffDebuffHealEvent:FireClient(player, player.UserId, spellname)
        end
    else
        local owner: any = utilMod.GetAttribute(modelInstance :: Model, "OwnedBy")
        if owner and owner ~= "None" and owner ~= "none" and owner ~= "" then
            local plr: Player? = game.Players:GetPlayerByUserId(owner)
            if plr then
                repstore.Events.BuffDebuffHealEvent:FireClient(plr, (modelInstance :: Model).Name, spellname)
            end
        end
    end
end

function buffMod.BuffDebuffHeal(caster: Player?, target: Model | Player, spellname: string): boolean
    if not caster or not target or not spellname then
        warn("BuffDebuffHeal: Missing required parameter(s)")
        return false
    end
    local partyTable = utilMod.GetPartyMembers(caster)
    local casterModel = nil
    if partyTable.Player.Name == caster.Name then
        casterModel = partyTable.Character
    else
        casterModel = caster
    end

    local targetisplayer: boolean = typeof(target) == "Instance" and target:IsA("Player")

    -- Normalize to Model instance
    local modelInstance: Model
    if targetisplayer then
        modelInstance = (target :: Player).Character
    else
        modelInstance = target :: Model
    end

    if not modelInstance or not modelInstance.Parent then
        return false
    end

    local key: string = tostring(modelInstance) .. spellname

    -- Refresh logic: cancel existing coroutine if one exists
    if RUNNING_EFFECTS[key] then
        print("Removingbuffstats")
        ApplyStatChanges(modelInstance, spellname, -1)
        task.cancel(RUNNING_EFFECTS[key])
        utilMod.SetAttribute(modelInstance, "Buff_" .. spellname, nil)
    end

    -- Mark as active right away
    utilMod.SetAttribute(modelInstance, "Buff_" .. spellname, true)

    local spellinfo: any = statsMod.SpellInfo[spellname]
    local buffinfo: any = statsMod.BuffInfo[spellname]
    if not spellinfo or not buffinfo then
        utilMod.SetAttribute(modelInstance, "Buff_" .. spellname, nil)
        return false
    end

    local duration: number = buffinfo.seconds or 0
    local isHeal: boolean = spellinfo.spellType == "heal"
    local isBuff: boolean = spellinfo.spellType == "buff"
    local isDebuff: boolean = spellinfo.spellType == "debuff"

    -- Apply instant changes (buff/debuff only)
    local applyFailed: boolean = false
    if isBuff or isDebuff then
        applyFailed = not ApplyStatChanges(modelInstance, spellname, 1)
    end

    -- Create the new coroutine
    local co: thread = task.spawn(function()
        local elapsed: number = 0
        local tickRate: number = 1

        -- Tick event
        local owner: Instance = game.Players:GetPlayerFromCharacter(modelInstance) or modelInstance
        local ev: BindableEvent? = owner:FindFirstChild("BuffDebuffEvent")
        if ev and ev:IsA("BindableEvent") and not isHeal then
            ev:Fire(partyTable.Player, spellname)
        end
        FireBuffNotificationEvent(isHeal, targetisplayer, modelInstance, spellname)
        if not targetisplayer then
            buffMod.ApplyBillboardBuffLabel(spellinfo.spellType, spellname, duration, casterModel, modelInstance)
        end

        while elapsed < duration do
            task.wait(tickRate)
            elapsed += tickRate
            print(elapsed .. " " .. duration)
            if not modelInstance or not modelInstance.Parent then
                break
            end

            -- Heal over time
            if isHeal then
                local hum: Humanoid? = modelInstance:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    local healPerTick: number = (buffinfo.hitPoints and buffinfo.hitPoints > 0)
                            and (buffinfo.hitPoints / duration)
                        or buffinfo.hitPoints
                        or 0
                    hum.Health = math.clamp(hum.Health + healPerTick, 1, hum.MaxHealth)
                end
            end
        end

        -- Final removal
        if isBuff or isDebuff then
            print("Removing buffs")
            ApplyStatChanges(modelInstance, spellname, -1)
        end

        -- Removal event
        local owner: Instance = game.Players:GetPlayerFromCharacter(modelInstance) or modelInstance
        local ev: BindableEvent? = owner:FindFirstChild("RemoveBuffDebuffEvent")
        if ev and ev:IsA("BindableEvent") and not isHeal then
            ev:Fire(partyTable.Player, spellname)
        end

        -- Cleanup
        utilMod.SetAttribute(modelInstance, "Buff_" .. spellname, nil)
        RUNNING_EFFECTS[key] = nil
    end)

    -- Store the new coroutine
    RUNNING_EFFECTS[key] = co

    return if isBuff or isDebuff then not applyFailed else true
end

function buffMod.SelectTargetsForAggro(caster: Player, spellinfo: any): ()
    if not caster or not spellinfo then
        return
    end

    local enemies: { Model } = utilMod.GetEnemyModelsWithinRange(caster, (spellinfo.range * 2))
    for _, enemy: Model in pairs(enemies) do
        utilMod.ApplyThreat(caster, enemy, spellinfo.aggro or 10)
    end
end

-- Optional cleanup on model destroy
game:GetService("Debris"):AddItem(task.spawn(function()
    while true do
        task.wait(60)
        for model, _ in pairs(modelBaseStats) do
            if not model.Parent then
                modelBaseStats[model] = nil
                modelStatRefreshers[model] = nil
            end
        end
    end
end))

return buffMod :: BuffMod