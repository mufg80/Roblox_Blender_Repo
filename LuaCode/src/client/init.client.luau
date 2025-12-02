local replicatedstorage = game:GetService("ReplicatedStorage")
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)


local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
local magicgui = playerGui:WaitForChild("MagicGui", 15)
local statsGui = playerGui:WaitForChild("StatsGui")
local designFolder = replicatedstorage:WaitForChild("Design")
local designSheet = designFolder:WaitForChild("StyleSheet")
local themes = designFolder:WaitForChild("ClassThemes")
local artificertheme = themes:WaitForChild("ArtificerTheme")
local primordialtheme = themes:WaitForChild("PrimordialTheme")
local naturetheme = themes:WaitForChild("NatureTheme")
local noneTheme = themes:WaitForChild("NoneTheme")
local player = players.LocalPlayer
local hum = player.Character:WaitForChild("Humanoid")
local healthLabel = statsGui:WaitForChild("HealthFrame"):WaitForChild("HealthLabel")
local manaLabel = statsGui:WaitForChild("HealthFrame"):WaitForChild("ManaLabel")

function ReturnLevel()
    local magictype = player:GetAttribute("Magic")

    if magictype == statsMod.MagicType.None then
        return 1
    elseif magictype == statsMod.MagicType.Artificer then
        return player:GetAttribute("ArtificerLevel")
    elseif magictype == statsMod.MagicType.Primordial then
        return player:GetAttribute("PrimordialLevel")
    elseif magictype == statsMod.MagicType.Nature then
        return player:GetAttribute("NatureLevel")

    end
end
function updateMagicUI()
    local magic = player:GetAttribute("Magic")
    local magicLevel = ReturnLevel()
    local typeTable = statsMod.MagicLevels[magic]


    if magic == statsMod.MagicType.Artificer then
        designSheet:SetDerives({artificertheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    elseif magic == statsMod.MagicType.Primordial then
        designSheet:SetDerives({primordialtheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    elseif magic == statsMod.MagicType.Nature then
        designSheet:SetDerives({naturetheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    else
        designSheet:SetDerives({noneTheme})
        magicgui.Enabled = false
        magicgui.SpellFrame.Visible = false
        magicgui.CreatureFrame.Visible = false
        return
    end

    local Creatureframeitems = magicgui.CreatureFrame:GetChildren()
    local Spellframeitems = magicgui.SpellFrame:GetChildren()

    for _, item in pairs(Creatureframeitems) do
        if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aCreaturesLabel" then
            item.Visible = false
        end
    end
    for _, item in pairs(Spellframeitems) do
        if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aSpellsLabel"  then
            item.Visible = false
        end
    end

    for i = 1, magicLevel do
        local abilityName = typeTable["Level"..tostring(i)].Abilities
        local spellName = typeTable["Level"..tostring(i)].Spells
        local abilitybutton =  magicgui.CreatureFrame:FindFirstChild("Level"..tostring(i))
        local spellbutton = magicgui.SpellFrame:FindFirstChild("Level"..tostring(i))
        if abilitybutton then
            abilitybutton.Visible = true
            abilitybutton.Text = abilityName
        end
        if spellbutton then
            spellbutton.Visible = true
            spellbutton.Text = spellName
        end
    end
end
updateMagicUI()

player:GetAttributeChangedSignal("Magic"):Connect(function()
    updateMagicUI()
end)
player:GetAttributeChangedSignal("ArtificerLevel"):Connect(function()
    updateMagicUI()
end)
player:GetAttributeChangedSignal("PrimordialLevel"):Connect(function()
    updateMagicUI()
end)
player:GetAttributeChangedSignal("NatureLevel"):Connect(function()
    --local magictype = player:GetAttribute("Magic")
    updateMagicUI()
end)

-- health and mana

player:GetAttributeChangedSignal("Mana"):Connect(function()
    local newmana = player:GetAttribute("Mana")
    manaLabel.Text = "Mana: "..tostring(math.floor(newmana))
end)

local function health(health)
 -- Compare old vs new health
        local damageTaken = hum:GetAttribute("LastHealth") and (hum:GetAttribute("LastHealth") - (health or 0)) or 0
        
        -- Store the new health for next time
        hum:SetAttribute("LastHealth", health)

        healthLabel.Text = "Health: "..tostring(math.floor(hum:GetAttribute("LastHealth")))
end
hum.HealthChanged:Connect(health)
health(hum.MaxHealth)
player:SetAttribute("Mana", player:GetAttribute("Mana") + 1)
local creaturebuttons = magicgui.CreatureFrame:GetChildren()
local spellbuttons = magicgui.SpellFrame:GetChildren()

for _, button in pairs(creaturebuttons) do
    if button:IsA("GuiButton") then
        button.MouseButton1Click:Connect(function()
            replicatedstorage.Events.SummonEvent:FireServer(button.Text)
        end)
    end
end
for _, button in pairs(spellbuttons) do
    if button:IsA("GuiButton") then
        button.MouseButton1Click:Connect(function()
            replicatedstorage.Events.SpellCastEvent:FireServer(button.Text)
        end)
    end
end


-- admin area
if players.LocalPlayer.UserId == 2484051658 then
    print("Admin detected, enabling admin GUI")
    local adminGui = playerGui:WaitForChild("AdminGui")
    local levelbutton = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
    local typebutton = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
    levelbutton.MouseButton1Click:Connect(function()
        print("Firing LevelUp")
        local level = ReturnLevel()
        if not level then return end
        replicatedstorage.Events.AdminEvent:FireServer("LevelUp")
        task.wait(.1)
        levelbutton.Text = "Magic Level: "..tostring(level + 1)
    end)
    typebutton.MouseButton1Click:Connect(function()
        print("Firing IncrementMagic")
        replicatedstorage.Events.AdminEvent:FireServer("IncrementMagic")
        task.wait(.1)
        typebutton.Text = "Magic Type: "..tostring(player:GetAttribute("Magic"))
        local level = ReturnLevel()
        if not level then return end
        levelbutton.Text = "Magic Level: "..tostring(level)
    end)
end
