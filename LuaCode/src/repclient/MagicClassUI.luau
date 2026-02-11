-- --!strict
-- -- ReplicatedStorage.Client.MagicClassUI

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")

-- local utilMod = require(ReplicatedStorage.Shared.utilMod)
-- local statsMod = require(ReplicatedStorage.Shared.statsMod)

-- local player = Players.LocalPlayer
-- local playerGui = player:WaitForChild("PlayerGui")
-- local magicGui = playerGui:WaitForChild("MagicGui")
-- local designFolder = ReplicatedStorage:WaitForChild("Design")
-- local designSheet = designFolder:WaitForChild("StyleSheet")
-- local themes = designFolder:WaitForChild("ClassThemes")

-- local artificerTheme = themes:WaitForChild("ArtificerTheme")
-- local primordialTheme = themes:WaitForChild("PrimordialTheme")
-- local natureTheme = themes:WaitForChild("NatureTheme")
-- local noneTheme = themes:WaitForChild("NoneTheme")

-- local MagicClassUI = {}
-- local currentCastColor: Color3? = nil

-- local function getCurrentLevel(): number?
-- 	local magicType = utilMod.GetAttribute(player, "Magic")
-- 	if magicType == statsMod.MagicType.None then
-- 		return 1
-- 	elseif magicType == statsMod.MagicType.Artificer then
-- 		return utilMod.GetAttribute(player, "ArtificerLevel")
-- 	elseif magicType == statsMod.MagicType.Primordial then
-- 		return utilMod.GetAttribute(player, "PrimordialLevel")
-- 	elseif magicType == statsMod.MagicType.Nature then
-- 		return utilMod.GetAttribute(player, "NatureLevel")
-- 	end
-- 	return nil
-- end

-- local function updateMagicUI()
-- 	local magicType = utilMod.GetAttribute(player, "Magic")
-- 	local level = getCurrentLevel()
-- 	local typeTable = statsMod.MagicLevels[magicType]

-- 	if magicType == statsMod.MagicType.Artificer then
-- 		designSheet:SetDerives({artificerTheme})
-- 		magicGui.Enabled = true
-- 		magicGui.SpellFrame.Visible = true
-- 		magicGui.CreatureFrame.Visible = true
-- 		currentCastColor = statsMod.Colors.Artificer

-- 	elseif magicType == statsMod.MagicType.Primordial then
-- 		designSheet:SetDerives({primordialTheme})
-- 		magicGui.Enabled = true
-- 		magicGui.SpellFrame.Visible = true
-- 		magicGui.CreatureFrame.Visible = true
-- 		currentCastColor = statsMod.Colors.Primordial

-- 	elseif magicType == statsMod.MagicType.Nature then
-- 		designSheet:SetDerives({natureTheme})
-- 		magicGui.Enabled = true
-- 		magicGui.SpellFrame.Visible = true
-- 		magicGui.CreatureFrame.Visible = true
-- 		currentCastColor = statsMod.Colors.Nature

-- 	else
-- 		designSheet:SetDerives({noneTheme})
-- 		magicGui.Enabled = false
-- 		magicGui.SpellFrame.Visible = false
-- 		magicGui.CreatureFrame.Visible = false
-- 		currentCastColor = nil
-- 		return
-- 	end

-- 	-- Hide all level buttons first
-- 	for _, item in magicGui.CreatureFrame:GetChildren() do
-- 		if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aCreaturesLabel" then
-- 			item.Visible = false
-- 		end
-- 	end
-- 	for _, item in magicGui.SpellFrame:GetChildren() do
-- 		if item:IsA("GuiObject") and item.Name ~= "UIListLayout" and item.Name ~= "aSpellsLabel" then
-- 			item.Visible = false
-- 		end
-- 	end

-- 	-- Show unlocked abilities/spells
-- 	if level then
-- 		for i = 1, level do
-- 			local levelData = typeTable["Level" .. i]
-- 			if not levelData then continue end

-- 			local abilityName = levelData.Abilities
-- 			local spellName = levelData.Spells

-- 			local creatureBtn = magicGui.CreatureFrame:FindFirstChild("Level" .. i)
-- 			if creatureBtn and abilityName then
-- 				creatureBtn.Visible = true
-- 				creatureBtn.Text = statsMod.creatureStats[abilityName].printedName
-- 			end

-- 			local spellBtn = magicGui.SpellFrame:FindFirstChild("Level" .. i)
-- 			if spellBtn and spellName then
-- 				spellBtn.Visible = true
-- 				spellBtn.Text = statsMod.SpellInfo[spellName].printedName
-- 			end
-- 		end
-- 	end
-- end

-- function MagicClassUI.Init()
-- 	updateMagicUI()

-- 	player:GetAttributeChangedSignal("Magic"):Connect(updateMagicUI)
-- 	player:GetAttributeChangedSignal("ArtificerLevel"):Connect(updateMagicUI)
-- 	player:GetAttributeChangedSignal("PrimordialLevel"):Connect(updateMagicUI)
-- 	player:GetAttributeChangedSignal("NatureLevel"):Connect(updateMagicUI)
-- end

-- -- Public access for cast color (used by CastFeedback & button handlers)
-- function MagicClassUI.GetCastColor(): Color3?
-- 	return currentCastColor
-- end

-- return MagicClassUI