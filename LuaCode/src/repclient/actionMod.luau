local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local magicGui = playerGui:WaitForChild("MagicGui")
local petGui = playerGui:WaitForChild("PetGui")
local spellFrame = magicGui:WaitForChild("SpellFrame")
local selectionFrame = magicGui:WaitForChild("SelectionFrame")
local petFrame = petGui:WaitForChild("PetFrame")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)
local PetCommands = require(ReplicatedStorage.Client.PetCommands)
local recycleMod = require(ReplicatedStorage.Shared.recycleMod)
local animMod = require(ReplicatedStorage.Shared.animMod)

local designFolder = ReplicatedStorage:WaitForChild("Design")
local designSheet = designFolder:WaitForChild("StyleSheet")
local themes = designFolder:WaitForChild("ClassThemes")

local artificerTheme = themes:WaitForChild("ArtificerTheme")
local primordialTheme = themes:WaitForChild("PrimordialTheme")
local natureTheme = themes:WaitForChild("NatureTheme")
local noneTheme = themes:WaitForChild("NoneTheme")

local Events = ReplicatedStorage:WaitForChild("Events")
local CastFeedback = require(ReplicatedStorage.Client.CastFeedback)

-- Attack Button
-- DPad Up
local attackButton = petFrame:WaitForChild("AttackButton")
-- DPad Left
local DefendLithButton = petFrame:WaitForChild("DefendLithButton")
-- DPad Right
local FollowMeButton = petFrame:WaitForChild("FollowButton")
-- DPad Down
local TakeLithButton = petFrame:WaitForChild("TakeLithButton")

local actionsMod = {}

actionsMod.buttons = {}
actionsMod.selectedButton = nil
actionsMod.lastSelectedButton = nil
actionsMod.cooldowns = {} -- [internalName] = endTime (local tracking)

-- Dynamic item data (populated on magic/level change)
actionsMod.itemData = {
	Staffs = {},
	Creatures = {},
	Spells = {},
}

-- Returns a table shaped like statsMod.MagicLevels, but only containing bonus/earned items
-- Structure: { Artificer = { staffs = {...}, abilities = {...}, spells = {...} }, ... }
function actionsMod.GetEarnedBonusItems()
	local player = game.Players.LocalPlayer
	local bonus = {
		Artificer = { staffs = {}, abilities = {}, spells = {} },
		Primordial = { staffs = {}, abilities = {}, spells = {} },
		Nature = { staffs = {}, abilities = {}, spells = {} },
		Any = { staffs = {}, abilities = {}, spells = {} },
	}

	-- Helper to add item to the correct path/category
	local function addToPath(magicType, category, itemName)
		if not bonus[magicType] then
			return
		end
		if not bonus[magicType][category] then
			return
		end
		table.insert(bonus[magicType][category], itemName)
	end

	-- Get all current attributes (this is fast and local)
	local attributes = player:GetAttributes() -- returns a dictionary { [key] = value, ... }

	for attrName, value in pairs(attributes) do
		if value ~= true then
			continue
		end -- only care about true flags

		-- Pattern: "Earned_Staff_Nature_LegendaryStaff" "Earned_Spell_Nature_RootII" "Earned_Abilities_Nature_BigGriffin → categoryRaw = "Staff", magicType = "Artificer", itemName = "LegendaryHammer"
		local categoryRaw, magicType, itemName = attrName:match("^Earned_(%w+)_(%w+)_(.+)$")

		if categoryRaw and magicType and itemName then
			local categoryLower = categoryRaw:lower()

			if categoryLower == "staff" or categoryLower == "staffs" then
				addToPath(magicType, "staffs", itemName)
			elseif
				categoryLower == "ability"
				or categoryLower == "abilities"
				or categoryLower == "creature"
				or categoryLower == "creatures"
			then
				addToPath(magicType, "abilities", itemName)
			elseif categoryLower == "spell" or categoryLower == "spells" then
				addToPath(magicType, "spells", itemName)
			end
		end
	end

	return bonus
end

actionsMod.CastColor = nil

-- Helper: Get current level for the active magic type
local function getLevelForType(magicType)
	if magicType == statsMod.MagicType.Artificer then
		return utilMod.GetAttribute(player, "ArtificerLevel") or 0
	elseif magicType == statsMod.MagicType.Primordial then
		return utilMod.GetAttribute(player, "PrimordialLevel") or 0
	elseif magicType == statsMod.MagicType.Nature then
		return utilMod.GetAttribute(player, "NatureLevel") or 0
	else
		return 0
	end
end

-- Determine category from button name
local function getCategory(buttonName)
	if buttonName == "Staff" then
		return "Staffs"
	end
	if buttonName:match("Creature") then
		return "Creatures"
	end
	return "Spells"
end

-- Theme-friendly focus/highlight
local function applyFocusHighlight(guiObj, isFocused)
	local stroke = guiObj:FindFirstChild("UIStroke")
	if stroke then
		if isFocused then
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Thickness = 4
			stroke.Transparency = 0
		else
			stroke.Thickness = 1
			stroke.Transparency = 0.3
		end
	end
end

local function closeSelection()
	selectionFrame.Visible = false
	selectionFrame.Active = false

	-- Re-enable selectable on hotbar buttons when selection closes
	for _, btn in ipairs(actionsMod.buttons) do
		btn.Selectable = true
	end

	actionsMod.lastSelectedButton = actionsMod.selectedButton
	actionsMod.selectedButton = nil
	if actionsMod.lastSelectedButton then
		GuiService.SelectedObject = actionsMod.lastSelectedButton
	elseif actionsMod.buttons[1] then
		GuiService.SelectedObject = actionsMod.buttons[1]
	end
end

-- NEW: Disable selectable on all hotbar buttons
local function disableHotbarSelectable()
	for _, btn in ipairs(actionsMod.buttons) do
		btn.Selectable = false
	end
end

-- Filter out already equipped items in other slots
local function getAvailableItems(category)
	local allItems = actionsMod.itemData[category] or {}
	local available = {}

	local used = {}
	for _, btn in ipairs(actionsMod.buttons) do
		if btn ~= actionsMod.selectedButton then
			local itemType = btn:GetAttribute("ItemType")
			local internalName = btn:GetAttribute("InternalName")
			if itemType and internalName then
				used[internalName] = true
			end
		end
	end

	table.insert(available, {
		Name = "Empty (" .. (actionsMod.selectedButton and actionsMod.selectedButton.Name or category) .. ")",
		Icon = "rbxassetid://0",
		Type = category == "Staffs" and "Staff" or (category == "Creatures" and "Creature" or "Spell"),
		InternalName = nil,
		IsPlaceholder = true,
	})

	for _, item in ipairs(allItems) do
		if not used[item.InternalName] then
			table.insert(available, item)
		end
	end

	return available
end

--        Example attributes for pickup now
--Earned_Staff_Artificer_LegendaryHammer     = true
--Earned_Ability_Nature_EternalBloom         = true
--Earned_Spell_Primordial_VoidNova           = true
--Earned_Staff_Primordial_CrystalWand        = true

-- Populate itemData based on current magic type and unlocked levels + earned bonuses
local function updateItemData()
	local magicType = utilMod.GetAttribute(player, "Magic")
	local level = getLevelForType(magicType)

	actionsMod.itemData = {
		Staffs = {},
		Creatures = {},
		Spells = {},
	}

	if magicType == statsMod.MagicType.None then
		return
	end

	local pathName
	if magicType == statsMod.MagicType.Artificer then
		pathName = "Artificer"
	elseif magicType == statsMod.MagicType.Primordial then
		pathName = "Primordial"
	elseif magicType == statsMod.MagicType.Nature then
		pathName = "Nature"
	else
		return
	end

	local typeLevels = statsMod.MagicLevels and statsMod.MagicLevels[pathName] or {}

	local seenStaffs = {}
	local seenCreatures = {}
	local seenSpells = {}

	-- ────────────────────────────────────────────────
	-- 1. Normal progression (levels 1 to current level)
	-- ────────────────────────────────────────────────
	for lvl = 1, level do
		local levelKey = "Level" .. lvl
		local levelData = typeLevels[levelKey]
		if not levelData then
			continue
		end

		-- Staffs
		if levelData.staffs then
			for _, staffName in ipairs(levelData.staffs) do
				if staffName and staffName ~= "" and not seenStaffs[staffName] then
					seenStaffs[staffName] = true
					local staffData = statsMod.StaffStats and statsMod.StaffStats[staffName]
					local printedName = staffData and (staffData.printedName or staffData.name) or staffName
					table.insert(actionsMod.itemData.Staffs, {
						Name = printedName,
						Icon = statsMod.Pics[staffName] or "rbxassetid://0",
						Type = "Staff",
						InternalName = staffName,
					})
				end
			end
		end

		-- Abilities / Creatures
		if levelData.abilities then
			for _, creatureName in ipairs(levelData.abilities) do
				if creatureName and creatureName ~= "" and not seenCreatures[creatureName] then
					seenCreatures[creatureName] = true
					local printedName = (
						statsMod.creatureStats
						and statsMod.creatureStats[creatureName]
						and statsMod.creatureStats[creatureName].printedName
					) or creatureName
					table.insert(actionsMod.itemData.Creatures, {
						Name = printedName,
						Icon = statsMod.Pics[creatureName] or "rbxassetid://0",
						Type = "Creature",
						InternalName = creatureName,
					})
				end
			end
		end

		-- Spells
		if levelData.spells then
			for _, spell in ipairs(levelData.spells) do
				if spell and spell ~= "" and not seenSpells[spell] then
					seenSpells[spell] = true
					local printedName = (
						statsMod.SpellInfo
						and statsMod.SpellInfo[spell]
						and statsMod.SpellInfo[spell].printedName
					) or spell
					table.insert(actionsMod.itemData.Spells, {
						Name = printedName,
						Icon = (
							statsMod.SpellInfo
							and statsMod.SpellInfo[spell]
							and statsMod.Pics[statsMod.SpellInfo[spell].spellType]
						) or "rbxassetid://0",
						Type = "Spell",
						InternalName = spell,
					})
				end
			end
		end
	end

	-- ────────────────────────────────────────────────
	-- 3. Bonus items from attributes (Earned_...)
	-- ────────────────────────────────────────────────
	local bonusItems = actionsMod.GetEarnedBonusItems()
	local bonusForPath = bonusItems[pathName] or { staffs = {}, abilities = {}, spells = {} }

	for _,spell in bonusItems.Any.spells do
		table.insert(bonusForPath.spells, spell)
	end

	-- Bonus Staffs
	for _, staffName in ipairs(bonusForPath.staffs) do
		if staffName and staffName ~= "" and not seenStaffs[staffName] then
			seenStaffs[staffName] = true
			local staffData = statsMod.StaffStats and statsMod.StaffStats[staffName]
			local printedName = staffData and (staffData.printedName or staffData.name) or staffName
			table.insert(actionsMod.itemData.Staffs, {
				Name = printedName,
				Icon = statsMod.Pics[staffName] or "rbxassetid://0",
				Type = "Staff",
				InternalName = staffName,
			})
		end
	end

	-- Bonus Abilities/Creatures
	for _, creatureName in ipairs(bonusForPath.abilities) do
		if creatureName and creatureName ~= "" and not seenCreatures[creatureName] then
			seenCreatures[creatureName] = true
			local printedName = (
				statsMod.creatureStats
				and statsMod.creatureStats[creatureName]
				and statsMod.creatureStats[creatureName].printedName
			) or creatureName
			table.insert(actionsMod.itemData.Creatures, {
				Name = printedName,
				Icon = statsMod.Pics[creatureName] or "rbxassetid://0",
				Type = "Creature",
				InternalName = creatureName,
			})
		end
	end


	-- Bonus Spells
	for _, spell in ipairs(bonusForPath.spells) do
		if spell and spell ~= "" and not seenSpells[spell] then
			seenSpells[spell] = true

			local printedName = (
				statsMod.SpellInfo
				and statsMod.SpellInfo[spell]
				and statsMod.SpellInfo[spell].printedName
			) or spell

			local newList = {}
			local spellLine = statsMod.SpellInfo[spell].spellline

			-- copy only spells that are NOT in the same spellline
			for _, entry in ipairs(actionsMod.itemData.Spells) do
				local internal = entry.InternalName
				local entryLine = internal and statsMod.SpellInfo[internal] and statsMod.SpellInfo[internal].spellline
				if entryLine ~= spellLine then
					table.insert(newList, entry)
				end
			end

			-- add the new spell
			table.insert(newList, {
				Name = printedName,
				Icon = (
					statsMod.SpellInfo
					and statsMod.SpellInfo[spell]
					and statsMod.Pics[statsMod.SpellInfo[spell].spellType]
				) or "rbxassetid://0",
				Type = "Spell",
				InternalName = spell,
			})

			-- replace the old list
			actionsMod.itemData.Spells = newList
		end
	end

	-- ────────────────────────────────────────────────
	-- 4. Optional safety cap (prevent UI overflow)
	-- ────────────────────────────────────────────────
	for _, cat in pairs({ "Staffs", "Creatures", "Spells" }) do
		local list = actionsMod.itemData[cat]
		if #list > 16 then
			actionsMod.itemData[cat] = { table.unpack(list, 1, 16) }
		end
	end
end

player:GetAttributeChangedSignal("HasFallen"):Connect(function()
	updateItemData()
end)

-- Setup default selections if all slots empty (or force = true)
local function setupDefaultSelections(force: boolean?)
	if force then
		for _, btn in ipairs(actionsMod.buttons) do
			btn.NameLabel.Text = btn.Name
			if btn:IsA("ImageButton") then
				btn.Image = "rbxassetid://0"
			end
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			btn.BackgroundTransparency = 0
			btn.ImageTransparency = 0.6
			btn.NameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
			btn:SetAttribute("SelectedItem", nil)
			btn:SetAttribute("ItemType", nil)
			btn:SetAttribute("InternalName", nil)
		end

		local character = player.Character
		local backpack = player:WaitForChild("Backpack")
		if character then
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") and tool.Name:match("^StarterStaff") then
					tool.Parent = backpack
				end
			end
		end
	else
		local allEmpty = true
		for _, btn in ipairs(actionsMod.buttons) do
			if btn:GetAttribute("InternalName") ~= nil then
				allEmpty = false
				break
			end
		end
		if not allEmpty then
			return
		end
	end

	local magicType = utilMod.GetAttribute(player, "Magic")
	if magicType == statsMod.MagicType.None then
		return
	end

	local level = getLevelForType(magicType)
	local character = player.Character
	local backpack = player:WaitForChild("Backpack")

	if not character or not character:FindFirstChild("Humanoid") then
		warn("Character not ready for default setup")
		return
	end

	local staffButton = spellFrame:FindFirstChild("Staff")
	local creatureButtons = {}
	local spellButtons = {}

	for _, btn in ipairs(actionsMod.buttons) do
		local cat = getCategory(btn.Name)
		if cat == "Creatures" then
			table.insert(creatureButtons, btn)
		elseif cat == "Spells" then
			table.insert(spellButtons, btn)
		end
	end

	table.sort(creatureButtons, function(a, b)
		return a.Name < b.Name
	end)
	table.sort(spellButtons, function(a, b)
		return a.Name < b.Name
	end)

	local numCreatureSlots = #creatureButtons
	local unlockedCreatures = actionsMod.itemData.Creatures
	for i = 1, math.min(2, numCreatureSlots, #unlockedCreatures) do
		local item = unlockedCreatures[i]
		local btn = creatureButtons[i]
		btn.NameLabel.Text = item.Name or "?"
		if btn:IsA("ImageButton") then
			btn.Image = item.Icon or "rbxassetid://0"
		end
		btn.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
		btn.BackgroundTransparency = 0
		btn.ImageTransparency = 0
		local tempcolor = btn.BackgroundColor3
		local brightness = (tempcolor.R * 0.299 + tempcolor.G * 0.587 + tempcolor.B * 0.114)
		btn.NameLabel.TextColor3 = (brightness > 0.5) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		btn:SetAttribute("SelectedItem", item.Name)
		btn:SetAttribute("ItemType", item.Type)
		btn:SetAttribute("InternalName", item.InternalName or "")
	end

	local numSpellSlots = #spellButtons
	local unlockedSpells = actionsMod.itemData.Spells
	for i = 1, math.min(7, numSpellSlots, #unlockedSpells) do
		local item = unlockedSpells[i]
		local btn = spellButtons[i]
		btn.NameLabel.Text = item.Name or "?"
		if btn:IsA("ImageButton") then
			btn.Image = item.Icon or "rbxassetid://0"
		end
		btn.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
		btn.BackgroundTransparency = 0
		btn.ImageTransparency = 0
		local tempcolor = btn.BackgroundColor3
		local brightness = (tempcolor.R * 0.299 + tempcolor.G * 0.587 + tempcolor.B * 0.114)
		btn.NameLabel.TextColor3 = (brightness > 0.5) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		btn:SetAttribute("SelectedItem", item.Name)
		btn:SetAttribute("ItemType", item.Type)
		btn:SetAttribute("InternalName", item.InternalName or "")
	end
end

-- Button state management
local function disableButton(btn: GuiButton)
	btn.BackgroundTransparency = 0.5
end

local function updateButtonStates()
	local shouldDisableAll = utilMod.GetAttribute(player, "HasFallen")
		or utilMod.GetAttribute(player, "Firing")
		or (CastFeedback and CastFeedback.IsOnCooldown and CastFeedback.IsOnCooldown())
		or false

	for _, btn in ipairs(actionsMod.buttons) do
		if not btn:IsA("GuiButton") then
			continue
		end

		-- Only force Selectable = true when selection is NOT visible
		if selectionFrame.Visible then
			btn.Selectable = false
			attackButton.Selectable = false
			DefendLithButton.Selectable = false
			TakeLithButton.Selectable = false
			FollowMeButton.Selectable = false
		else
			btn.Selectable = true
			attackButton.Selectable = true
			DefendLithButton.Selectable = true
			TakeLithButton.Selectable = true
			FollowMeButton.Selectable = true
		end

		local itemType = btn:GetAttribute("ItemType")
		local internalName = btn:GetAttribute("InternalName")

		btn.Active = true
		btn.Interactable = true
		btn.AutoButtonColor = true
		btn.BackgroundTransparency = 0

		if shouldDisableAll then
			disableButton(btn)
			continue
		end

		if itemType == "Creature" and internalName then
			local creatureName = internalName
			local souls = utilMod.GetAttribute(player, "Souls") or 0
			if souls < 1 then
				disableButton(btn)
			end

			local manaCost = utilMod.LeveltoManaCost and utilMod.LeveltoManaCost(creatureName) or 0
			local currentMana = utilMod.GetAttribute(player, "Mana") or 0
			if currentMana < manaCost then
				disableButton(btn)
			end

			local cdAttr = "button_" .. creatureName
			local cdEnd = utilMod.GetAttribute(player, cdAttr)
			if cdEnd and cdEnd > time() then
				disableButton(btn)
			elseif cdEnd then
				utilMod.SetAttribute(player, cdAttr, nil)
			end

			if utilMod.IsMaxSummoned(player.Character, creatureName) then
				disableButton(btn)
			end
		end

		if itemType == "Spell" and internalName then
			local spellName = internalName
			local spell = statsMod.SpellInfo and statsMod.SpellInfo[spellName]
			if not spell then
				continue
			end

			local currentMana = utilMod.GetAttribute(player, "Mana") or 0
			local manaCost = spell.manaCost or 0
			if manaCost > 0 and currentMana < manaCost * (statsMod.MaxSpellCost or 1) then
				disableButton(btn)
			end

			local cdAttr = "button_" .. spellName
			local cdEnd = utilMod.GetAttribute(player, cdAttr)
			if cdEnd and cdEnd > time() then
				disableButton(btn)
			elseif cdEnd then
				utilMod.SetAttribute(player, cdAttr, nil)
			end

			if spellName == "ConvertSpout" and player.Character then
				if not buffMod.CheckDistanceOnSpouts(player.Character) then
					disableButton(btn)
				end
			end

			if spellName == "ReclaimPet" and player.Character then
				local myPets = utilMod.MyPets and utilMod.MyPets(player.Character) or {}
				if #myPets == 0 then
					disableButton(btn)
				end
			end

			if spellName == "TheftOfSoul" and player.Character then
				local eligiblesoul = recycleMod.GetEligibleSoul(player.Character)
				if not eligiblesoul then
					disableButton(btn)
				end
			end

			if spell.spellType and table.find({ "damage", "areaDamage", "debuff" }, spell.spellType) then
				local range = spell.range or 30
				if player.Character and not utilMod.IsEnemyInRange(player.Character, range) then
					disableButton(btn)
				end
			end
		end
	end
end

-- Theme application + item data refresh + defaults + states
local function updateMagicUI()
	local magicType = utilMod.GetAttribute(player, "Magic")

	if magicType == statsMod.MagicType.Artificer then
		designSheet:SetDerives({ artificerTheme })
		magicGui.Enabled = true
		actionsMod.CastColor = statsMod.Colors.Artificer
	elseif magicType == statsMod.MagicType.Primordial then
		designSheet:SetDerives({ primordialTheme })
		magicGui.Enabled = true
		actionsMod.CastColor = statsMod.Colors.Primordial
	elseif magicType == statsMod.MagicType.Nature then
		designSheet:SetDerives({ natureTheme })
		magicGui.Enabled = true
		actionsMod.CastColor = statsMod.Colors.Nature
	else
		designSheet:SetDerives({ noneTheme })
		magicGui.Enabled = false
		actionsMod.CastColor = statsMod.Colors.None
	end

	updateItemData()
	setupDefaultSelections(false) -- force during development; change to false later

	-- Reapply styles to all buttons based on new theme
	for _, btn in ipairs(actionsMod.buttons) do
		if btn:GetAttribute("InternalName") then
			btn.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
			btn.BackgroundTransparency = 0
			btn.ImageTransparency = 0
			local tempcolor = btn.BackgroundColor3
			local brightness = (tempcolor.R * 0.299 + tempcolor.G * 0.587 + tempcolor.B * 0.114)
			btn.NameLabel.TextColor3 = (brightness > 0.5) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			btn.BackgroundTransparency = 0
			btn.ImageTransparency = 0.6
			btn.NameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		end
	end

	updateButtonStates()
end

-- Populate selection UI
local function populateSelection(items)
	for _, child in ipairs(selectionFrame:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local gridLayout = selectionFrame:FindFirstChild("UIGridLayout") or error("Add UIGridLayout to SelectionFrame")

	-- Apply theme color to the selection frame background (semi-transparent)
	if actionsMod.CastColor then
		selectionFrame.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
		selectionFrame.BackgroundTransparency = 0.5
	else
		selectionFrame.BackgroundTransparency = 1 -- fallback if no color
	end

	for i, item in ipairs(items) do
		if i > 16 then
			break
		end

		local slot = Instance.new("ImageButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.Active = true
		slot.Selectable = true
		slot.Parent = selectionFrame

		slot.Image = item.Icon or "rbxassetid://0"
		slot.ScaleType = Enum.ScaleType.Fit

		if item.IsPlaceholder then
			-- Empty slot stays black/dark
			slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			slot.BackgroundTransparency = 0
			slot.ImageTransparency = 0.6
		else
			-- Themed buttons: full opacity cast color background
			if actionsMod.CastColor then
				slot.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
				slot.BackgroundTransparency = 0
			else
				slot.BackgroundTransparency = 1 -- fallback
			end
			slot.ImageTransparency = 0
		end

		local label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = item.Name or "?"
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold

		-- Make text readable on colored background
		if item.IsPlaceholder then
			label.TextColor3 = Color3.fromRGB(180, 180, 180)
		else
			-- White or black depending on cast color brightness (simple heuristic)
			local tempcolor = Color3.fromHex(actionsMod.CastColor)
			local brightness = (tempcolor.R * 0.299 + tempcolor.G * 0.587 + tempcolor.B * 0.114)
			label.TextColor3 = (brightness > 0.5) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		end
		label.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Transparency = 0.3
		stroke.Thickness = 1
		stroke.Parent = slot

		slot.SelectionGained:Connect(function()
			applyFocusHighlight(slot, true)
		end)

		slot.SelectionLost:Connect(function()
			applyFocusHighlight(slot, false)
		end)

		slot.Activated:Connect(function()
			if actionsMod.selectedButton then
				local character = player.Character
				local backpack = player:WaitForChild("Backpack")

				if not character or not character:FindFirstChild("Humanoid") then
					warn("Character or Humanoid not ready")
					closeSelection()
					return
				end

				if item.IsPlaceholder then
					actionsMod.selectedButton.NameLabel.Text = actionsMod.selectedButton.Name
					if actionsMod.selectedButton:IsA("ImageButton") then
						actionsMod.selectedButton.Image = "rbxassetid://0"
					end
					actionsMod.selectedButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					actionsMod.selectedButton.BackgroundTransparency = 0
					actionsMod.selectedButton.ImageTransparency = 0.6
					actionsMod.selectedButton.NameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
					actionsMod.selectedButton:SetAttribute("SelectedItem", nil)
					actionsMod.selectedButton:SetAttribute("ItemType", nil)
					actionsMod.selectedButton:SetAttribute("InternalName", nil)

					for _, tool in ipairs(character:GetChildren()) do
						if tool:IsA("Tool") then
							tool.Parent = backpack
							break
						end
					end
				else
					actionsMod.selectedButton.NameLabel.Text = item.Name or "?"
					if actionsMod.selectedButton:IsA("ImageButton") then
						actionsMod.selectedButton.Image = item.Icon or "rbxassetid://0"
					end
					actionsMod.selectedButton.BackgroundColor3 = Color3.fromHex(actionsMod.CastColor)
					actionsMod.selectedButton.BackgroundTransparency = 0
					actionsMod.selectedButton.ImageTransparency = 0
					local tempcolor = actionsMod.selectedButton.BackgroundColor3
					local brightness = (tempcolor.R * 0.299 + tempcolor.G * 0.587 + tempcolor.B * 0.114)
					actionsMod.selectedButton.NameLabel.TextColor3 = (brightness > 0.5) and Color3.fromRGB(0, 0, 0)
						or Color3.fromRGB(255, 255, 255)
					actionsMod.selectedButton:SetAttribute("SelectedItem", item.Name)
					actionsMod.selectedButton:SetAttribute("ItemType", item.Type)
					actionsMod.selectedButton:SetAttribute("InternalName", item.InternalName or "")

					if item.Type == "Staff" then
						local targetToolName = item.InternalName

						for _, tool in ipairs(character:GetChildren()) do
							if tool:IsA("Tool") and utilMod.GetAttribute(tool, "StaffType") ~= nil then
								tool.Parent = backpack
							end
						end

						local targetTool = backpack:FindFirstChild(targetToolName)
						if targetTool and targetTool:IsA("Tool") then
							targetTool.Parent = character
						else
							warn("Staff tool not found in Backpack: " .. targetToolName)
						end
					end
				end

				closeSelection()
			end
		end)
	end

	-- Auto-select first slot
	task.delay(0.1, function()
		local first
		for _, child in ipairs(selectionFrame:GetChildren()) do
			if child:IsA("GuiButton") and child.Selectable then
				first = child
				break
			end
		end
		if first then
			GuiService.SelectedObject = first
		end
	end)
end

-- Perform action (summon / cast / activate)
local globalDebounce = false

local function startCastAndCooldown(duration: number, itemName: string, cooldownExtra: number?, onCast: () -> ())
	if globalDebounce then
		return
	end
	globalDebounce = true

	local fullCooldown = duration + 1 + (cooldownExtra or 0)

	if CastFeedback and CastFeedback.StartCast then
		CastFeedback.StartCast(duration, actionsMod.CastColor, function()
			globalDebounce = false
		end)
	else
		task.delay(duration, function()
			globalDebounce = false
		end)
	end

	utilMod.SetAttribute(player, "button_" .. itemName, time() + fullCooldown)
	actionsMod.cooldowns[itemName] = time() + fullCooldown
	onCast()

	task.delay(0.05, updateButtonStates)
end

local function CastAnimation(castTime: number)
	local hum = player.Character:FindFirstChild("Humanoid")
	animMod.ActivateCast(hum)
	task.delay(castTime, function()
		animMod.DeactivateCast(hum)
	end)
end

local function useItem(button)
	if button.BackgroundTransparency > 0.25 then
		-- Button is visually disabled (no mana/cooldown/souls etc), do not perform action
		return
	end
	local itemType = button:GetAttribute("ItemType")
	local internalName = button:GetAttribute("InternalName")
	if not itemType or not internalName then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then
		return
	end

	local cooldownAttr = "button_" .. internalName
	local cooldownEnd = utilMod.GetAttribute(player, cooldownAttr) or 0
	if time() < cooldownEnd then
		return
	end

	if itemType == "Staff" then
		local tool = character:FindFirstChild(internalName) or character:FindFirstChildWhichIsA("Tool")
		if tool and tool:IsA("Tool") then
			tool:Activate()
		end
	elseif itemType == "Creature" then
		local creatureName = internalName
		local castTime = utilMod.CreatureCastTime and utilMod.CreatureCastTime(creatureName) or 1.5
		CastAnimation(castTime)
		startCastAndCooldown(castTime, internalName, 3, function()
			Events.SummonEvent:FireServer(creatureName)
		end)
	elseif itemType == "Spell" then
		local spellName = internalName
		local spellInfo = statsMod.SpellInfo and statsMod.SpellInfo[spellName]
		if not spellInfo then
			return
		end
		local castTime = spellInfo.castTime or 2

		local extraCooldown = spellInfo.cooldown or 0
		CastAnimation(castTime)
		startCastAndCooldown(castTime, internalName, extraCooldown, function()
			Events.SpellCastEvent:FireServer(spellName)
		end)
	end

	updateButtonStates()
end

-- Initialize buttons with dual input handling
local function initializeButtons()
	actionsMod.buttons = {}

	for _, child in ipairs(spellFrame:GetChildren()) do
		if not child:IsA("GuiButton") then
			continue
		end

		table.insert(actionsMod.buttons, child)

		child.Active = true
		child.Selectable = true

		if not child:FindFirstChild("UIStroke") then
			local stroke = Instance.new("UIStroke")
			stroke.Transparency = 0.3
			stroke.Thickness = 1
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Parent = child
		end

		if not child:FindFirstChild("NameLabel") then
			local label = Instance.new("TextLabel")
			label.Name = "NameLabel"
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = child.Name
			label.TextScaled = true
			label.TextWrapped = true
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromRGB(180, 180, 180)
			label.Parent = child
		end

		if child:IsA("ImageButton") then
			child.ScaleType = Enum.ScaleType.Fit
		end

		child.MouseEnter:Connect(function()
			local stroke = child:FindFirstChild("UIStroke")
			if stroke then
				stroke.Thickness = 4
				stroke.Transparency = 0
			end
			GuiService.SelectedObject = child
		end)

		child.MouseLeave:Connect(function()
			local stroke = child:FindFirstChild("UIStroke")
			if stroke then
				if GuiService.SelectedObject == child then
					stroke.Thickness = 4
					stroke.Transparency = 0
				else
					stroke.Thickness = 1
					stroke.Transparency = 0.3
				end
			end
		end)

		child.SelectionGained:Connect(function()
			applyFocusHighlight(child, true)
		end)

		child.SelectionLost:Connect(function()
			applyFocusHighlight(child, false)
		end)

		child.Activated:Connect(function()
			if child:GetAttribute("InternalName") ~= nil then
				useItem(child)
			else
				actionsMod.selectedButton = child
				local category = getCategory(child.Name)
				local availableItems = getAvailableItems(category)
				disableHotbarSelectable() -- Prevent going back to hotbar
				populateSelection(availableItems)
				selectionFrame.Visible = true
				selectionFrame.Active = true
				selectionFrame.ZIndex = spellFrame.ZIndex + 10
			end
		end)

		child.MouseButton2Click:Connect(function()
			actionsMod.selectedButton = child
			local category = getCategory(child.Name)
			local availableItems = getAvailableItems(category)
			disableHotbarSelectable() -- Prevent going back to hotbar
			populateSelection(availableItems)
			selectionFrame.Visible = true
			selectionFrame.Active = true
			selectionFrame.ZIndex = spellFrame.ZIndex + 10
		end)

		local pressStart = 0
		child.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				pressStart = tick()
			end
		end)

		child.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				local duration = tick() - pressStart
				if duration >= 0.5 then
					actionsMod.selectedButton = child
					local category = getCategory(child.Name)
					local availableItems = getAvailableItems(category)
					disableHotbarSelectable() -- Prevent going back to hotbar
					populateSelection(availableItems)
					selectionFrame.Visible = true
					selectionFrame.Active = true
					selectionFrame.ZIndex = spellFrame.ZIndex + 10
				end
			end
		end)
	end

	-- SORT buttons by LayoutOrder
	table.sort(actionsMod.buttons, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
end

-- Cross-platform controller handling (FIXED)
local function setupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- =========================
		-- 🎮 D-PAD PET COMMANDS
		-- =========================
		if not selectionFrame.Visible then
			if input.KeyCode == Enum.KeyCode.DPadUp then
				PetCommands.ToggleAttack()
				return
			elseif input.KeyCode == Enum.KeyCode.DPadLeft then
				PetCommands.DefendLith()
				return
			elseif input.KeyCode == Enum.KeyCode.DPadRight then
				PetCommands.ToggleFollow()
				return
			elseif input.KeyCode == Enum.KeyCode.DPadDown then
				PetCommands.TakeLith()
				return
			end
		end

		-- =========================
		-- 🎮 BUMPER CYCLING (L1 / R1)
		-- =========================
		if input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonR1 then
			local targetList = {}

			if selectionFrame.Visible then
				-- Only cycle selection frame buttons
				for _, child in ipairs(selectionFrame:GetChildren()) do
					if child:IsA("GuiButton") and child.Selectable then
						table.insert(targetList, child)
					end
				end
			else
				-- Cycle hotbar buttons
				targetList = actionsMod.buttons
			end

			if #targetList == 0 then
				return
			end

			local current = GuiService.SelectedObject
			local index = table.find(targetList, current) or 1

			if input.KeyCode == Enum.KeyCode.ButtonL1 then
				index -= 1
				if index < 1 then
					index = #targetList
				end
			else
				index += 1
				if index > #targetList then
					index = 1
				end
			end

			GuiService.SelectedObject = targetList[index]
			return
		end

		-- =========================
		-- 🎮 OPEN SELECTION (Y)
		-- =========================
		if not selectionFrame.Visible then
			if input.KeyCode == Enum.KeyCode.ButtonY then
				local focused = GuiService.SelectedObject
				if focused and table.find(actionsMod.buttons, focused) then
					actionsMod.selectedButton = focused
					local category = getCategory(focused.Name)
					local availableItems = getAvailableItems(category)

					disableHotbarSelectable()
					populateSelection(availableItems)

					selectionFrame.Visible = true
					selectionFrame.Active = true
					selectionFrame.ZIndex = spellFrame.ZIndex + 10
				end
			end
			return
		end

		-- =========================
		-- 🎮 CLOSE SELECTION (B)
		-- =========================
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			closeSelection()
		end
	end)
end

function actionsMod.Init()
	task.wait(0.3)
	-- 🔥 Disable Roblox automatic gamepad GUI navigation
	GuiService.GuiNavigationEnabled = false
	GuiService.AutoSelectGuiEnabled = false

	spellFrame.Active = true
	selectionFrame.Visible = false

	initializeButtons()
	setupInputHandling()

	updateMagicUI()
	setupDefaultSelections(true)
	updateButtonStates()

	player:GetAttributeChangedSignal("Magic"):Connect(updateMagicUI)
	player:GetAttributeChangedSignal("ArtificerLevel"):Connect(updateMagicUI)
	player:GetAttributeChangedSignal("PrimordialLevel"):Connect(updateMagicUI)
	player:GetAttributeChangedSignal("NatureLevel"):Connect(updateMagicUI)

	player:GetAttributeChangedSignal("Mana"):Connect(updateButtonStates)
	player:GetAttributeChangedSignal("Souls"):Connect(updateButtonStates)
	player:GetAttributeChangedSignal("HasFallen"):Connect(updateButtonStates)
	player:GetAttributeChangedSignal("Firing"):Connect(updateButtonStates)
	player:GetAttributeChangedSignal("ChangedSpells"):Connect(function()
		local changed = utilMod.GetAttribute(player, "ChangedSpells") or false
		if changed then
			updateButtonStates()
		end
	end)
	task.spawn(function()
		while true do
			updateButtonStates()
			task.wait(0.4)
		end
	end)

	task.spawn(function()
		task.wait(0.5)
		local staffButton = spellFrame:FindFirstChild("Staff")
		if staffButton and staffButton:IsA("GuiButton") then
			GuiService.SelectedObject = staffButton
		elseif actionsMod.buttons[1] then
			GuiService.SelectedObject = actionsMod.buttons[1]
		end
	end)
end

return actionsMod
