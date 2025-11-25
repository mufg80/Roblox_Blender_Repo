
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)

local buffMod = {}


function buffMod.ApplyHeals(player, heal, mypets, spelldamagemax)
    local position = player.Character:FindFirstChild("HumanoidRootPart")
    if not position then return end
    local strenth = heal.effectMultiplier * spelldamagemax
    local range = heal.range

    for _,pet in mypets do
        local pethrp = pet:FindFirstChild("HumanoidRootPart")
        if not pethrp then continue end
        if utilMod.GetMagnitude(position, pethrp) < range then
            local hum = pet:FindFirstChild("Humanoid")
            if not hum then return end
            if hum.Health < hum.MaxHealth then
                hum.Health = math.min(hum.Health + strenth, hum.MaxHealth)
            end
        end
    end
    local myhum = player.Character:FindFirstChild("Humanoid")
    if not myhum then return end
    if myhum.Health < myhum.MaxHealth then
        
        myhum.Health = math.min(myhum.Health + strenth, myhum.MaxHealth)
    end

end








return buffMod