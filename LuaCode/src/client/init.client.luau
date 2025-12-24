--!strict

local replicatedstorage = game:GetService("ReplicatedStorage")
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local buffMod = require(game.ReplicatedStorage.Shared.buffMod)
local utilMod = require(replicatedstorage.Shared.utilMod)
local runservice = game:GetService("RunService")
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
local magicgui = playerGui:WaitForChild("MagicGui", 15)
local statsGui = playerGui:WaitForChild("StatsGui")
local petsGui = playerGui:WaitForChild("PetGui")
local designFolder = replicatedstorage:WaitForChild("Design")
local designSheet = designFolder:WaitForChild("StyleSheet")
local themes = designFolder:WaitForChild("ClassThemes")
local artificertheme = themes:WaitForChild("ArtificerTheme")
local primordialtheme = themes:WaitForChild("PrimordialTheme")
local naturetheme = themes:WaitForChild("NatureTheme")
local noneTheme = themes:WaitForChild("NoneTheme")
local player = players.LocalPlayer
local hum: Humanoid = player.Character:WaitForChild("Humanoid")
local spellCastColor: Color3? = nil
local db: boolean = true
local Frame: Frame = magicgui:FindFirstChild("CastFrame")
local globalCooldown: number = time()
local petNames: { string } = {}

-- health and mana
local function ChangeMana(): ()
    local newmana: number? = utilMod.GetAttribute(player, "Mana")
    local maxmana: number? = utilMod.GetAttribute(player, "MaxMana")
    if not newmana or not maxmana then
        return
    end
    local fraction: number
    if maxmana == 0 then
        fraction = 0
    else
        fraction = math.clamp(newmana / maxmana, 0, 1)
    end

    local inner: Frame = statsGui.HudFrame.ManaMeterBar.InnerFill
    inner.Size = UDim2.new(fraction, 0, 1, 0)
end

local function EnableButton(button: GuiButton): ()
    button.Active = true
    button.Interactable = true
    button.AutoButtonColor = true
    button.BackgroundTransparency = 0
end

local function DiableButton(button: GuiButton): ()
    button.Active = false
    button.Interactable = false
    button.AutoButtonColor = false
    button.BackgroundTransparency = 0.5
end

local function DisableButtons(): ()
    local creaturebuttons: { Instance } = magicgui.CreatureFrame:GetChildren()
    local spellbuttons: { Instance } = magicgui.SpellFrame:GetChildren()

    -- Enable all buttons first
    for _, button in pairs(creaturebuttons) do
        if button:IsA("GuiButton") then
            EnableButton(button)
        end
    end
    for _, button in pairs(spellbuttons) do
        if button:IsA("GuiButton") then
            EnableButton(button)
        end
    end

    if utilMod.GetAttribute(player, "HasFallen") then
        for _, button in pairs(creaturebuttons) do
            if button:IsA("GuiButton") then
                DiableButton(button)
            end
        end
        for _, button in pairs(spellbuttons) do
            if button:IsA("GuiButton") then
                DiableButton(button)
            end
        end
        return
    end

    -- If casting disable all buttons
    if time() < globalCooldown then
        for _, button in pairs(creaturebuttons) do
            if button:IsA("GuiButton") then
                DiableButton(button)
            end
        end
        for _, button in pairs(spellbuttons) do
            if button:IsA("GuiButton") then
                DiableButton(button)
            end
        end
    end

    -- If no souls disable creature buttons
    local souls: number = utilMod.GetAttribute(player, "Souls") or 0
    if souls < 1 then
        for _, button in pairs(creaturebuttons) do
            if button:IsA("GuiButton") then
                DiableButton(button)
            end
        end
    end
    for _, button in pairs(spellbuttons) do
        if button:IsA("GuiButton") then
            local spell = statsMod.SpellInfo[utilMod.RemoveSpaces(button.Text)]
            if spell and spell.manaCost then
                local currentMana: number = utilMod.GetAttribute(player, "Mana") or 0
                if currentMana < spell.manaCost * statsMod.MaxSpellCost then
                    DiableButton(button)
                end
            end
            if utilMod.GetAttribute(player, "button_" .. utilMod.RemoveSpaces(button.Text)) then
                DiableButton(button)
                if utilMod.GetAttribute(player, ("button_" .. utilMod.RemoveSpaces(button.Text))) < time() then
                    utilMod.SetAttribute(player, "button_" .. utilMod.RemoveSpaces(button.Text), nil)
                end
            end
            if button.Text == "Convert Spout" then
                if not buffMod.CheckDistanceOnSpouts(player) then
                    DiableButton(button)
                end
            end
            if button.Text == "Reclaim Pet" then
                local mypets = utilMod.MyPets(player)
                if not mypets or #mypets == 0 then
                    DiableButton(button)
                end
            end
            local spell = statsMod.SpellInfo[utilMod.RemoveSpaces(button.Text)]
            if spell then
                local spelltype = spell.spellType
                if spelltype and (spelltype == "damage" or spelltype == "areaDamage" or spelltype == "debuff") then
                    local target = utilMod.IsEnemyInRange(player, spell.range)
                    if not target then
                        DiableButton(button)
                    end
                end
            end
        end
    end
    for _, button in pairs(creaturebuttons) do
        if button:IsA("GuiButton") then
            local creature = statsMod.creatureStats[utilMod.RemoveSpaces(button.Text)]
            if creature then
                local currentMana: number = utilMod.GetAttribute(player, "Mana") or 0
                if currentMana < combatMod.LeveltoManaCost(utilMod.RemoveSpaces(button.Text)) then
                    DiableButton(button)
                end
                if utilMod.GetAttribute(player, "button_" .. utilMod.RemoveSpaces(button.Text)) then
                    DiableButton(button)
                    if utilMod.GetAttribute(player, ("button_" .. utilMod.RemoveSpaces(button.Text))) < time() then
                        utilMod.SetAttribute(player, "button_" .. utilMod.RemoveSpaces(button.Text), nil)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        DisableButtons()
        task.wait(0.1)
    end
end)

local function ChangeHealth(): ()
    local inner: Frame = statsGui.HudFrame.HealthMeterBar.InnerFill
    local den: number = hum.MaxHealth
    local num: number = hum.Health
    local fraction: number
    if den == 0 then
        fraction = 0
    else
        fraction = math.clamp(num / den, 0, 1)
    end
    inner.Size = UDim2.new(fraction, 0, 1, 0)
end

local function ReturnLevel(): number?
    local magictype: any = utilMod.GetAttribute(player, "Magic")

    if magictype == statsMod.MagicType.None then
        return 1
    elseif magictype == statsMod.MagicType.Artificer then
        return utilMod.GetAttribute(player, "ArtificerLevel")
    elseif magictype == statsMod.MagicType.Primordial then
        return utilMod.GetAttribute(player, "PrimordialLevel")
    elseif magictype == statsMod.MagicType.Nature then
        return utilMod.GetAttribute(player, "NatureLevel")
    end
    return nil
end

local function updateMagicUI(): ()
    local magic: any = utilMod.GetAttribute(player, "Magic")
    local magicLevel: number? = ReturnLevel()
    local typeTable: any = statsMod.MagicLevels[magic]

    if magic == statsMod.MagicType.Artificer then
        designSheet:SetDerives({ artificertheme })
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
        spellCastColor = statsMod.Colors.Artificer
    elseif magic == statsMod.MagicType.Primordial then
        designSheet:SetDerives({ primordialtheme })
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
        spellCastColor = statsMod.Colors.Primordial
    elseif magic == statsMod.MagicType.Nature then
        designSheet:SetDerives({ naturetheme })
        magicgui.Enabled = true
        magicgui.SpellFrame.Visible = true
        magicgui.CreatureFrame.Visible = true
        spellCastColor = statsMod.Colors.Nature
    else
        designSheet:SetDerives({ noneTheme })
        magicgui.Enabled = false
        magicgui.SpellFrame.Visible = false
        magicgui.CreatureFrame.Visible = false
        spellCastColor = nil
        return
    end

    local Creatureframeitems: { Instance } = magicgui.CreatureFrame:GetChildren()
    local Spellframeitems: { Instance } = magicgui.SpellFrame:GetChildren()

    for _, item in pairs(Creatureframeitems) do
        if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aCreaturesLabel" then
            item.Visible = false
        end
    end
    for _, item in pairs(Spellframeitems) do
        if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aSpellsLabel" then
            item.Visible = false
        end
    end

    if magicLevel then
        for i = 1, magicLevel do
            local abilityName: string = typeTable["Level" .. tostring(i)].Abilities
            local spellName: string = typeTable["Level" .. tostring(i)].Spells
            local abilitybutton: TextButton? = magicgui.CreatureFrame:FindFirstChild("Level" .. tostring(i))
            local spellbutton: TextButton? = magicgui.SpellFrame:FindFirstChild("Level" .. tostring(i))
            if abilitybutton then
                abilitybutton.Visible = true
                abilitybutton.Text = statsMod.creatureStats[abilityName].printedName
            end
            if spellbutton then
                spellbutton.Visible = true
                spellbutton.Text = statsMod.SpellInfo[spellName].printedName
            end
        end
    end
end
updateMagicUI()

player:GetAttributeChangedSignal("Magic"):Connect(function()
    updateMagicUI()
    ChangeHealth()
    ChangeMana()
end)
player:GetAttributeChangedSignal("ArtificerLevel"):Connect(function()
    updateMagicUI()
    ChangeHealth()
    ChangeMana()
end)
player:GetAttributeChangedSignal("PrimordialLevel"):Connect(function()
    updateMagicUI()
    ChangeHealth()
    ChangeMana()
end)
player:GetAttributeChangedSignal("NatureLevel"):Connect(function()
    updateMagicUI()
    ChangeHealth()
    ChangeMana()
end)

player:GetAttributeChangedSignal("Mana"):Connect(function()
    ChangeMana()
end)

hum.HealthChanged:Connect(ChangeHealth)
ChangeHealth()
ChangeMana()

local creaturebuttons: { Instance } = magicgui.CreatureFrame:GetChildren()
local spellbuttons: { Instance } = magicgui.SpellFrame:GetChildren()

for _, button in pairs(creaturebuttons) do
    if button:IsA("GuiButton") then
        button.MouseButton1Click:Connect(function()
            if not db then
                return
            end
            db = false
            replicatedstorage.Events.SummonEvent:FireServer(utilMod.RemoveSpaces(button.Text))
            local secs: number = statsMod.creatureStats[utilMod.RemoveSpaces(button.Text)]
                    and (statsMod.creatureStats[utilMod.RemoveSpaces(button.Text)].level or 3 / 2)
                or 1.5
            local startTime: number = time()
            local connection: RBXScriptConnection?

            Frame.Visible = true
            globalCooldown = time() + secs + 1
            utilMod.SetAttribute(player, "button_" .. utilMod.RemoveSpaces(button.Text), time() + secs + 3)
            local innerFill: Frame = Frame.InnerFill
            innerFill.BackgroundColor3 = Color3.fromHex(spellCastColor or "#FFFFFF")
            connection = runservice.RenderStepped:Connect(function(delta: number)
                local elapse: number = (time() - startTime)
                local fraction: number = elapse / secs
                innerFill.Size = UDim2.new(fraction, 0, 1, 0)
                if elapse >= secs or hum.Health <= 1 then
                    if connection then
                        connection:Disconnect()
                    end
                    Frame.Visible = false
                    db = true
                end
            end)
        end)
    end
end
for _, button in pairs(spellbuttons) do
    if button:IsA("GuiButton") then
        button.MouseButton1Click:Connect(function()
            if not db then
                return
            end
            db = false
            local secs: number = statsMod.SpellInfo[utilMod.RemoveSpaces(button.Text)].castTime or 2
            local startTime: number = time()
            local connection: RBXScriptConnection?
            local Frame: Frame = magicgui:FindFirstChild("CastFrame")
            Frame.Visible = true
            globalCooldown = time() + secs + 1
            utilMod.SetAttribute(
                player,
                "button_" .. utilMod.RemoveSpaces(button.Text),
                time() + secs + statsMod.SpellInfo[utilMod.RemoveSpaces(button.Text)].cooldown
            )
            local innerFill: Frame = Frame.InnerFill
            innerFill.BackgroundColor3 = Color3.fromHex(spellCastColor or "#FFFFFF")
            connection = runservice.RenderStepped:Connect(function(delta: number)
                local elapse: number = (time() - startTime)
                local fraction: number = elapse / secs
                innerFill.Size = UDim2.new(fraction, 0, 1, 0)
                if elapse >= secs or hum.Health <= 2 then
                    if connection then
                        connection:Disconnect()
                    end
                    Frame.Visible = false
                    db = true
                end
            end)
            replicatedstorage.Events.SpellCastEvent:FireServer(utilMod.RemoveSpaces(button.Text))
        end)
    end
end

local function Adjustsouls(soulsleft: number, maxsouls: number): ()
    local label: TextLabel? = statsGui.SoulFrame.SoulsLabel
    if label then
        label.Text = soulsleft .. "/" .. maxsouls
    end
end
replicatedstorage.Events.GainedSoulEvent.OnClientEvent:Connect(function(soulsleft: number, maxsouls: number)
    if not soulsleft or not maxsouls then
        warn("Should not reach me")
        return
    end
    if soulsleft <= maxsouls then
        utilMod.SetAttribute(player, "Souls", soulsleft or 0)
    end
    Adjustsouls(soulsleft, maxsouls)
end)

replicatedstorage.Events.SummonEvent.OnClientEvent:Connect(function(summonedCreature: Model, souls: number)
    if not summonedCreature then
        warn("No summoned creature received on client")
        return
    else
        table.insert(petNames, summonedCreature.Name)
        utilMod.SetAttribute(player, "Souls", souls)
    end

    -- You can add additional client-side logic here if needed

    local existingFrame: Frame? = statsGui.HudFrame:FindFirstChild(summonedCreature.Name .. "_PetFrame")
    if existingFrame then
        existingFrame:Destroy()
    end

    local petframe: Frame = replicatedstorage:WaitForChild("GUIComponents").PetFrameContainer:Clone()
    petframe.Name = summonedCreature.Name .. "_PetFrame"
    petframe.Parent = statsGui.HudFrame
    petframe.Visible = true
    local petimage: ImageLabel = petframe.PetImageLabel
    petimage.Image = statsMod.Pics[utilMod.customTrim(summonedCreature.Name)]
    local hum: Humanoid? = summonedCreature:FindFirstChild("Humanoid")
    if not hum then
        warn("should not reach me")
        return
    end
    local connection: RBXScriptConnection?

    local function updateHealth(): ()
        local inner: Frame = petframe.ZHealthMana.PetMeterBar.InnerFill
        local den: number = hum.MaxHealth
        local num: number = hum.Health
        local fraction: number
        if den == 0 then
            fraction = 0
        else
            fraction = math.clamp(num / den, 0, 1)
        end
        inner.Size = UDim2.new(fraction, 0, 1, 0)
        if hum.Health <= 1 then
            petframe:Destroy()
        end
    end
    updateHealth()

    connection = hum.HealthChanged:Connect(updateHealth)
    local ancestryConnection: RBXScriptConnection?
    ancestryConnection = summonedCreature.AncestryChanged:Connect(function(_child: Instance, parent: Instance?)
        if not parent then
            if connection then
                connection:Disconnect()
            end
            if ancestryConnection then
                ancestryConnection:Disconnect()
            end
            if petframe then
                petframe:Destroy()
            end
        end
    end)
end)

replicatedstorage.Events.PetManaEvent.OnClientEvent:Connect(function(name, mana, maxmana)
    --petframe.Name = summonedCreature.Name .. "_PetFrame"
    local hud = statsGui.HudFrame
    if not hud then
        return
    end
    local frameName = name .. "_PetFrame"
    local petFrame = hud:FindFirstChild(frameName)
    if not petFrame then
        return
    end
    petFrame.ZHealthMana.ZPetManaMeterBar.Visible = true
    local innerFill = petFrame.ZHealthMana.ZPetManaMeterBar.InnerFill

    innerFill.Visible = true
    if not innerFill then
        return
    end
    local den: number = maxmana or 1
    local num: number = mana or 0.1
    local fraction: number
    if den == 0 then
        fraction = 0
    else
        fraction = math.clamp(num / den, 0, 1)
    end
    innerFill.Size = UDim2.new(fraction, 0, 1, 0)
end)

replicatedstorage.Events.SpellCastEvent.OnClientEvent:Connect(function(spellname: string)
    -- You can add additional client-side logic here if needed
end)

--Pet commands Area
-- Variables (put these at the top, in a LocalScript)
local isPetAttacking: boolean = true
local isPetFollowing: boolean = true -- default: pet follows when passive
local isPetDefendingLith: boolean = false
local isPetTakingLith: boolean = false

local followButton: TextButton = petsGui.PetFrame.FollowButton
local defendLithButton: TextButton = petsGui.PetFrame.DefendLithButton
local attackButton: TextButton = petsGui.PetFrame.AttackButton
local takeLithButton: TextButton = petsGui.PetFrame.TakeLithButton

-- Helper: Update button visuals (example)
local function UpdateButtonVisuals(): ()
    followButton.BackgroundColor3 = isPetFollowing and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
    attackButton.BackgroundColor3 = isPetAttacking and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 80, 80)
    defendLithButton.BackgroundColor3 = isPetDefendingLith and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(80, 80, 80)
    takeLithButton.BackgroundColor3 = isPetTakingLith and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(80, 80, 80)

    -- Disable lith buttons visually if attack is off
    defendLithButton.Active = isPetAttacking
    takeLithButton.Active = isPetAttacking
    defendLithButton.AutoButtonColor = isPetAttacking
    takeLithButton.AutoButtonColor = isPetAttacking
end

local function PetEventActivation(): ()
    local commands: {
        Following: boolean,
        Attacking: boolean,
        TakingLith: boolean,
        DefendingLith: boolean,
    } =
        {
            Following = isPetFollowing,
            Attacking = isPetAttacking,
            TakingLith = isPetTakingLith,
            DefendingLith = isPetDefendingLith,
        }
    replicatedstorage.Events.PetEvent:FireServer(commands)
end

-- FOLLOW BUTTON
followButton.MouseButton1Click:Connect(function()
    isPetFollowing = not isPetFollowing

    -- When attacking, Follow is one of the 3 mutually exclusive modes
    if isPetFollowing then
        isPetDefendingLith = false
        isPetTakingLith = false
    end

    PetEventActivation()
    UpdateButtonVisuals()
end)

-- DEFEND LITH BUTTON
defendLithButton.MouseButton1Click:Connect(function()
    if not isPetAttacking then
        -- Do nothing — or show "Attack must be on" message
        return
    end

    isPetDefendingLith = true
    isPetTakingLith = false
    isPetFollowing = false

    PetEventActivation()
    UpdateButtonVisuals()
end)

-- TAKE LITH BUTTON
takeLithButton.MouseButton1Click:Connect(function()
    if not isPetAttacking then
        return
    end

    isPetTakingLith = true
    isPetDefendingLith = false
    isPetFollowing = false

    PetEventActivation()
    UpdateButtonVisuals()
end)

-- ATTACK BUTTON (Master Toggle)
attackButton.MouseButton1Click:Connect(function()
    isPetAttacking = not isPetAttacking

    if not isPetAttacking then
        -- Turn off aggressive modes, but keep Follow state intact
        isPetDefendingLith = false
        isPetTakingLith = false
    end

    PetEventActivation()
    UpdateButtonVisuals()
end)

-- Initial visual update
UpdateButtonVisuals()

local buffEvent: RemoteEvent = replicatedstorage.Events.BuffDebuffHealEvent

buffEvent.OnClientEvent:Connect(function(id: number | string, spellname: string)
    local spellInfo = statsMod.SpellInfo[spellname]
    if not spellInfo then
        warn("Received buff event for unknown spell:", spellname)
        return
    end

    local spelltype: string = spellInfo.spellType
    if not table.find({ "buff", "debuff", "heal", "damage" }, spelltype) then
        warn("Invalid spelltype:", spelltype)
        return
    end

    -- Determine duration: use BuffInfo.seconds if available, else 1 second for instant visuals
    local duration = 1 -- default for damage/heal flashes
    if statsMod.BuffInfo[spellname] and statsMod.BuffInfo[spellname].seconds then
        duration = statsMod.BuffInfo[spellname].seconds
    end

    local imageLabel: ImageLabel? = nil
    local parentFrame: Frame? = nil
    local keyPrefix: string = ""
    local model = nil
    if typeof(id) == "number" then
        -- Player buffs
        parentFrame = statsGui.HudFrame.PlayerEffectsFrame
        keyPrefix = "Player"
        local plrtarget = game.Players:GetPlayerByUserId(id)
        if plrtarget and plrtarget.Character then
            model = plrtarget.Character
        else return
        end
    else
        -- Pet buffs
        local petFrameName = tostring(id) .. "_PetFrame"
        parentFrame = statsGui.HudFrame:FindFirstChild(petFrameName)
        if not parentFrame then
            return -- Pet UI not visible yet
        end
        parentFrame = parentFrame.ZZBuffFrame
        keyPrefix = tostring(id)
        for _, mod in workspace.Pets:GetChildren() do
            if mod.Name == id then
                model = mod
            end
        end
    end

    if not parentFrame then
        return
    end

    -- Map spelltype to template label name
    local templateName = ({
        buff = "BuffLabel",
        debuff = "DebuffLabel",
        heal = "HealLabel",
        damage = "DamageLabel",
    })[spelltype]

    local template = parentFrame:FindFirstChild(templateName)
    if not template then
        warn("Missing template label:", templateName, "in", parentFrame:GetFullName())
        return
    end

    -- Clone and parent the label
    imageLabel = template:Clone()
    imageLabel.Name = templateName .. "_" .. spellname -- optional: unique name
    imageLabel.Parent = parentFrame

    -- Unique key: prevents stacking same buff visually + allows cancellation
    local key = keyPrefix .. "_" .. spellname.."_"..parentFrame.Name

    -- Start the blinking timer (handles show → blink → cleanup, including early cancel)
    buffMod.StartBuffLabelTimer(imageLabel, duration, model, key)
end)


-- admin area
if players.LocalPlayer.UserId == 2484051658 then
    local adminGui: ScreenGui = playerGui:WaitForChild("AdminGui")
    adminGui.Frame.Visible = true
    adminGui.closeButton.Visible = true
    local levelbutton: TextButton = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
    local typebutton: TextButton = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
    levelbutton.MouseButton1Click:Connect(function()
        local level: number? = ReturnLevel()
        if not level then
            return
        end
        replicatedstorage.Events.AdminEvent:FireServer("LevelUp")
        task.wait(0.1)
        levelbutton.Text = "Magic Level: " .. tostring(level + 1)
    end)
    typebutton.MouseButton1Click:Connect(function()
        replicatedstorage.Events.AdminEvent:FireServer("IncrementMagic")
        task.wait(0.1)
        typebutton.Text = "Magic Type: " .. tostring(utilMod.GetAttribute(player, "Magic"))
        local level: number? = ReturnLevel()
        if not level then
            return
        end
        levelbutton.Text = "Magic Level: " .. tostring(level)
    end)
end