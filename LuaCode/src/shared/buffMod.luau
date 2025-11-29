
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