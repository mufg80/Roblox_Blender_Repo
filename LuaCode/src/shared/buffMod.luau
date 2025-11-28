
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)

local buffMod = {}

function buffMod.ReclaimPet(player, spell, max, mypets):boolean

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

function buffMod.ApplyHeals(player, heal, mypets, spelldamagemax): boolean
    local position = player.Character:FindFirstChild("HumanoidRootPart")
    if not position then return end
    local strenth = heal.effectMultiplier * spelldamagemax
    local range = heal.range
    local applied = false

    for _,pet in mypets do
        local pethrp = pet:FindFirstChild("HumanoidRootPart")
        if not pethrp then continue end
        local thismags = utilMod.GetMagnitude(position, pethrp)
        if thismags < range then
            local hum = pet:FindFirstChild("Humanoid")
            if not hum then return end
            if hum.Health < hum.MaxHealth then
                hum.Health = math.min(hum.Health + strenth, hum.MaxHealth)
                applied = true
            end
        end
    end
    local myhum = player.Character:FindFirstChild("Humanoid")
    if not myhum then return end
    if myhum.Health < myhum.MaxHealth then        
        myhum.Health = math.min(myhum.Health + strenth, myhum.MaxHealth)
        applied = true
    end
    return applied
end








return buffMod