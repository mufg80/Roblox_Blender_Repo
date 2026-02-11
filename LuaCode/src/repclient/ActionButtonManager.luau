-- --!strict
-- -- ReplicatedStorage.Client.ActionButtonManager

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")

-- local utilMod = require(ReplicatedStorage.Shared.utilMod)
-- local statsMod = require(ReplicatedStorage.Shared.statsMod)
-- local combatMod = require(ReplicatedStorage.Shared.combatMod)
-- local buffMod = require(ReplicatedStorage.Shared.buffMod)
-- local CastFeedback = require(ReplicatedStorage.Client.CastFeedback)  -- ← ADDED THIS LINE
-- local player = Players.LocalPlayer
-- local magicGui = player:WaitForChild("PlayerGui"):WaitForChild("MagicGui")

-- local creatureButtons = magicGui.CreatureFrame:GetChildren()
-- local spellButtons = magicGui.SpellFrame:GetChildren()

-- local ActionButtonManager = {}

-- local function enableButton(btn: GuiButton)
-- 	btn.Active = true
-- 	btn.Interactable = true
-- 	btn.AutoButtonColor = true
-- 	btn.BackgroundTransparency = 0
-- end

-- local function disableButton(btn: GuiButton)
-- 	btn.Active = false
-- 	btn.Interactable = false
-- 	btn.AutoButtonColor = false
-- 	btn.BackgroundTransparency = 0.5
-- end

-- local function shouldDisableAll(): boolean
-- 	return utilMod.GetAttribute(player, "HasFallen") or
-- 	       utilMod.GetAttribute(player, "Firing") or
-- 	       CastFeedback.IsOnCooldown()  -- from CastFeedback module
-- end

-- local function updateButtonStates()
-- 	-- First enable everything
-- 	for _, btn in creatureButtons do
-- 		if btn:IsA("GuiButton") then enableButton(btn) end
-- 	end
-- 	for _, btn in spellButtons do
-- 		if btn:IsA("GuiButton") then enableButton(btn) end
-- 	end

-- 	if shouldDisableAll() then
-- 		for _, btn in creatureButtons do if btn:IsA("GuiButton") then disableButton(btn) end end
-- 		for _, btn in spellButtons do if btn:IsA("GuiButton") then disableButton(btn) end end
-- 		return
-- 	end

-- 	-- Souls check for creatures
-- 	local souls = utilMod.GetAttribute(player, "Souls") or 0
-- 	if souls < 1 then
-- 		for _, btn in creatureButtons do
-- 			if btn:IsA("GuiButton") then disableButton(btn) end
-- 		end
-- 	end

-- 	-- Per-button logic
-- 	for _, btn in spellButtons do
-- 		if not btn:IsA("GuiButton") then continue end

-- 		local spellName = utilMod.RemoveSpaces(btn.Text)
-- 		local spell = statsMod.SpellInfo[spellName]
-- 		if not spell then continue end

-- 		local currentMana = utilMod.GetAttribute(player, "Mana") or 0

-- 		-- Mana cost (with max scaling)
-- 		if spell.manaCost and currentMana < spell.manaCost * statsMod.MaxSpellCost then
-- 			disableButton(btn)
-- 		end

-- 		-- Personal cooldown
-- 		local cdAttr = "button_" .. spellName
-- 		local cdTime = utilMod.GetAttribute(player, cdAttr)
-- 		if cdTime then
-- 			disableButton(btn)
-- 			if cdTime < time() then
-- 				utilMod.SetAttribute(player, cdAttr, nil)
-- 			end
-- 		end

-- 		-- Special cases
-- 		if btn.Text == "Convert Spout" and player.Character then
-- 			if not buffMod.CheckDistanceOnSpouts(player.Character) then
-- 				disableButton(btn)
-- 			end
-- 		end

-- 		if btn.Text == "Reclaim Pet" and player.Character then
-- 			local myPets = utilMod.MyPets(player.Character)
-- 			if not myPets or #myPets == 0 then
-- 				disableButton(btn)
-- 			end
-- 		end

-- 		-- Target required for damage/debuff
-- 		if spell.spellType and table.find({"damage", "areaDamage", "debuff"}, spell.spellType) then
-- 			if not utilMod.IsEnemyInRange(player.Character, spell.range) then
-- 				disableButton(btn)
-- 			end
-- 		end
-- 	end

-- 	-- Creature buttons (mana + cooldown)
-- 	for _, btn in creatureButtons do
-- 		if not btn:IsA("GuiButton") then continue end

-- 		local creatureName = utilMod.RemoveSpaces(btn.Text)
-- 		local currentMana = utilMod.GetAttribute(player, "Mana") or 0

-- 		if currentMana < combatMod.LeveltoManaCost(creatureName) then
-- 			disableButton(btn)
-- 		end

-- 		local cdAttr = "button_" .. creatureName
-- 		local cdTime = utilMod.GetAttribute(player, cdAttr)
-- 		if cdTime then
-- 			disableButton(btn)
-- 			if cdTime < time() then
-- 				utilMod.SetAttribute(player, cdAttr, nil)
-- 			end
-- 		end
-- 	end
-- end

-- function ActionButtonManager.Init()
-- 	task.spawn(function()
-- 		while true do
-- 			updateButtonStates()
-- 			task.wait(0.1)
-- 		end
-- 	end)
-- end

-- return ActionButtonManager