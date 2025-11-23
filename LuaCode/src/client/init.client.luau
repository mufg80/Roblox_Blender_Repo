local replicatedstorage = game:GetService("ReplicatedStorage")
local combatMod = require(replicatedstorage.Shared.combatMod)
local runservice = game:GetService("RunService")

local players = game:GetService("Players")
local startergui = game:GetService("StarterGui")
local uis = game:GetService("UserInputService")
local guiroot = players.LocalPlayer:WaitForChild("PlayerGui")
local magicgui = guiroot:WaitForChild("MagicGui")
local designFolder = replicatedstorage:WaitForChild("Design")
local designSheet = designFolder:WaitForChild("StyleSheet")
local themes = designFolder:WaitForChild("ClassThemes")
local artificertheme = themes:WaitForChild("ArtificerTheme")
local primordialtheme = themes:WaitForChild("PrimordialTheme")
local naturetheme = themes:WaitForChild("NatureTheme")
local player = players.LocalPlayer


function updateMagicUI()
    local magic = player:GetAttribute("Magic")
    local magicLevel = player:GetAttribute("MagicLevel")
    local typeTable = combatMod.MagicLevels[magic]


    if magic == combatMod.MagicType.Artificer then
        designSheet:SetDerives({artificertheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    elseif magic == combatMod.MagicType.Primordial then
        designSheet:SetDerives({primordialtheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    elseif magic == combatMod.MagicType.Nature then
        designSheet:SetDerives({naturetheme})
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
    else
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
player:GetAttributeChangedSignal("MagicLevel"):Connect(function()
    updateMagicUI()
end)

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
    local adminGui = guiroot:WaitForChild("AdminGui")
    local levelbutton = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
    local typebutton = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
    levelbutton.MouseButton1Click:Connect(function()
        print("Firing LevelUp")
        replicatedstorage.Events.AdminEvent:FireServer("LevelUp")
        levelbutton.Text = "Magic Level: "..tostring(player:GetAttribute("MagicLevel"))
    end)
    typebutton.MouseButton1Click:Connect(function()
        print("Firing IncrementMagic")
        replicatedstorage.Events.AdminEvent:FireServer("IncrementMagic")
        typebutton.Text = "Magic Type: "..tostring(player:GetAttribute("Magic"))
    end)
end