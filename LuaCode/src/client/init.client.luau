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
local hum = player.Character:WaitForChild("Humanoid")
local spellCastColor = nil
local db = true
local Frame = magicgui:FindFirstChild("CastFrame")
local globalCooldown = time()
local petNames = {}
-- health and mana
function ChangeMana()
	local newmana = player:GetAttribute("Mana")
	local maxmana = player:GetAttribute("MaxMana")
	if not newmana or not maxmana then
		return
	end
	local fraction = nil
	if maxmana == 0 then
		fraction = 0
	else
		fraction = math.clamp(newmana / maxmana, 0, 1)
	end

	local inner = statsGui.HudFrame.ManaMeterBar.InnerFill
	inner.Size = UDim2.new(fraction, 0, 1, 0)
end
local function EnableButton(button)
	button.Active = true
	button.Interactable = true
	button.AutoButtonColor = true
	button.BackgroundTransparency = 0
end

local function DiableButton(button)
	button.Active = false
	button.Interactable = false
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0.5
end

local function DisableButtons()
	local creaturebuttons = magicgui.CreatureFrame:GetChildren()
	local spellbuttons = magicgui.SpellFrame:GetChildren()

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
	local souls = player:GetAttribute("Souls") or 0
	if souls < 1 then
		for _, button in pairs(creaturebuttons) do
			if button:IsA("GuiButton") then
				DiableButton(button)
			end
		end
	end
	for _, button in pairs(spellbuttons) do
		if button:IsA("GuiButton") then
			local spell = statsMod.SpellInfo[button.Text]
			if spell and spell.manaCost then
				local currentMana = player:GetAttribute("Mana") or 0
				if currentMana < spell.manaCost * statsMod.MaxSpellCost then
					DiableButton(button)
				end
			end
			if player:GetAttribute("button_" .. button.Text) then
				DiableButton(button)
				if player:GetAttribute(("button_" .. button.Text)) < time() then
					player:SetAttribute("button_" .. button.Text, nil)
				end
			end
			if button.Text == "ConvertSpout" then
				if not buffMod.CheckDistanceOnSpouts(player) then
					DiableButton(button)
				end
			end
			if button.Text == "ReclaimPet" then
				local mypets = utilMod.MyPets(player)
				if not mypets or #mypets == 0 then
					DiableButton(button)
				end
			end
			local spell = statsMod.SpellInfo[button.Text]
			if spell then
				local spelltype = spell.spellType
				if spelltype and spelltype == "damage" or spelltype == "areaDamage" or spelltype == "debuff" then
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
			local creature = statsMod.creatureStats[button.Text]
			if creature then
				local currentMana = player:GetAttribute("Mana") or 0
				if currentMana < combatMod.LeveltoManaCost(button.Text) then
					DiableButton(button)
				end
				if player:GetAttribute("button_" .. button.Text) then
					DiableButton(button)
					if player:GetAttribute(("button_" .. button.Text)) < time() then
						player:SetAttribute("button_" .. button.Text, nil)
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

local function ChangeHealth()
	-- Compare old vs new health
	--local damageTaken = hum:GetAttribute("LastHealth") and (hum:GetAttribute("LastHealth") - (health or 0)) or 0

	-- Store the new health for next time
	--hum:SetAttribute("LastHealth", health)

	local inner = statsGui.HudFrame.HealthMeterBar.InnerFill
	local den = hum.MaxHealth
	local num = hum.Health
	local fraction = nil
	if den == 0 then
		fraction = 0
	else
		fraction = math.clamp(num / den, 0, 1)
	end
	inner.Size = UDim2.new(fraction, 0, 1, 0)
end

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

	local Creatureframeitems = magicgui.CreatureFrame:GetChildren()
	local Spellframeitems = magicgui.SpellFrame:GetChildren()

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

	for i = 1, magicLevel do
		local abilityName = typeTable["Level" .. tostring(i)].Abilities
		local spellName = typeTable["Level" .. tostring(i)].Spells
		local abilitybutton = magicgui.CreatureFrame:FindFirstChild("Level" .. tostring(i))
		local spellbutton = magicgui.SpellFrame:FindFirstChild("Level" .. tostring(i))
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

local creaturebuttons = magicgui.CreatureFrame:GetChildren()
local spellbuttons = magicgui.SpellFrame:GetChildren()

for _, button in pairs(creaturebuttons) do
	if button:IsA("GuiButton") then
		button.MouseButton1Click:Connect(function()
			if not db then
				return
			end
			db = false
			replicatedstorage.Events.SummonEvent:FireServer(button.Text)
			local secs = statsMod.creatureStats[button.Text] and (statsMod.creatureStats[button.Text].level or 3 / 2)
			local startTime = time()
			local connection

			Frame.Visible = true
			globalCooldown = time() + secs + 1
			player:SetAttribute("button_" .. button.Text, time() + secs + 3)
			local innerFill = Frame.InnerFill
			innerFill.BackgroundColor3 = Color3.fromHex(spellCastColor or "#FFFFFF")
			connection = runservice.RenderStepped:Connect(function(delta)
				local elapse = (time() - startTime)
				local fraction = elapse / secs
				innerFill.Size = UDim2.new(fraction, 0, 1, 0)
				if elapse >= secs or hum.Health <= 1 then
					connection:Disconnect()
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
			local secs = statsMod.SpellInfo[button.Text].castTime or 2
			local startTime = time()
			local connection
			local Frame = magicgui:FindFirstChild("CastFrame")
			Frame.Visible = true
			globalCooldown = time() + secs + 1
			player:SetAttribute("button_" .. button.Text, time() + secs + statsMod.SpellInfo[button.Text].cooldown)
			local innerFill = Frame.InnerFill
			innerFill.BackgroundColor3 = Color3.fromHex(spellCastColor or "#FFFFFF")
			connection = runservice.RenderStepped:Connect(function(delta)
				local elapse = (time() - startTime)
				local fraction = elapse / secs
				innerFill.Size = UDim2.new(fraction, 0, 1, 0)
				if elapse >= secs or hum.Health <= 2 then
					connection:Disconnect()
					Frame.Visible = false
					db = true
				end
			end)
			replicatedstorage.Events.SpellCastEvent:FireServer(button.Text)
		end)
	end
end

replicatedstorage.Events.GainedSoulEvent.OnClientEvent:Connect(function(soulsleft, maxsouls)
	if soulsleft <= maxsouls then
		player:SetAttribute("Souls", soulsleft or 0)
	end
	
end)

replicatedstorage.Events.SummonEvent.OnClientEvent:Connect(function(summonedCreature, souls)
	if not summonedCreature then
		warn("No summoned creature received on client")
		return
	else
		table.insert(petNames, summonedCreature.Name)
		player:SetAttribute("Souls", souls)
	end

	-- You can add additional client-side logic here if needed

	local existingFrame = statsGui.HudFrame:FindFirstChild(summonedCreature.Name .. "_PetFrame")
	if existingFrame then
		existingFrame:Destroy()
	end

	local petframe = replicatedstorage:WaitForChild("PetFrameContainer"):Clone()
	petframe.Name = summonedCreature.Name .. "_PetFrame"
	petframe.Parent = statsGui.HudFrame
	petframe.Visible = true
	local petimage = petframe.PetImageLabel
	petimage.Image = statsMod.Pics[utilMod.customTrim(summonedCreature.Name)]
	local hum = summonedCreature:FindFirstChild("Humanoid")
	if not hum then
		warn("should not reach me")
		return
	end
	local connection

	local function updateHealth()
		local inner = petframe.PetMeterBar.InnerFill
		local den = hum.MaxHealth
		local num = hum.Health
		local fraction = nil
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
	local ancestryConnection
	ancestryConnection = summonedCreature.AncestryChanged:Connect(function(child, parent)
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

replicatedstorage.Events.SpellCastEvent.OnClientEvent:Connect(function(spellname)
	-- You can add additional client-side logic here if needed
end)
--Pet commands Area
-- Variables (put these at the top, in a LocalScript)
local isPetAttacking = true
local isPetFollowing = true -- default: pet follows when passive
local isPetDefendingLith = false
local isPetTakingLith = false

local followButton = petsGui.PetFrame.FollowButton
local defendLithButton = petsGui.PetFrame.DefendLithButton
local attackButton = petsGui.PetFrame.AttackButton
local takeLithButton = petsGui.PetFrame.TakeLithButton

-- Helper: Update button visuals (example)
local function UpdateButtonVisuals()
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

local function PetEventActivation()
	local commands = {
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


-- Buffs
local buffEvent = replicatedstorage.Events.BuffDebuffHealEvent
buffEvent.OnClientEvent:Connect(function(id, spellname, command)
	print(tostring(id).." "..spellname.. " "..command)
end)

-- admin area
if players.LocalPlayer.UserId == 2484051658 then
	local adminGui = playerGui:WaitForChild("AdminGui")
	adminGui.Frame.Visible = true
	adminGui.closeButton.Visible = true
	local levelbutton = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
	local typebutton = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
	levelbutton.MouseButton1Click:Connect(function()
		local level = ReturnLevel()
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
		typebutton.Text = "Magic Type: " .. tostring(player:GetAttribute("Magic"))
		local level = ReturnLevel()
		if not level then
			return
		end
		levelbutton.Text = "Magic Level: " .. tostring(level)
	end)
end
