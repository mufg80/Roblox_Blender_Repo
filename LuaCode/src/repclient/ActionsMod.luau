local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local magicGui = playerGui:WaitForChild("MagicGui")
local spellFrame = magicGui:WaitForChild("SpellFrame")
local selectionFrame = magicGui:WaitForChild("SelectionFrame")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)

local designFolder = ReplicatedStorage:WaitForChild("Design")
local designSheet = designFolder:WaitForChild("StyleSheet")
local themes = designFolder:WaitForChild("ClassThemes")

local artificerTheme = themes:WaitForChild("ArtificerTheme")
local primordialTheme = themes:WaitForChild("PrimordialTheme")
local natureTheme = themes:WaitForChild("NatureTheme")
local noneTheme = themes:WaitForChild("NoneTheme")

local Events = ReplicatedStorage:WaitForChild("Events")
local CastFeedback = require(ReplicatedStorage.Client.CastFeedback)

local actionsMod = {}

actionsMod.buttons = {}
actionsMod.selectedButton = nil
actionsMod.lastSelectedButton = nil
actionsMod.cooldowns = {}  -- [internalName] = endTime (local tracking)

-- Dynamic item data (populated on magic/level change)
actionsMod.itemData = {
	Staffs = {},
	Creatures = {},
	Spells = {},
}

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
	actionsMod.lastSelectedButton = actionsMod.selectedButton
	actionsMod.selectedButton = nil
	if actionsMod.lastSelectedButton then
		GuiService.SelectedObject = actionsMod.lastSelectedButton
	elseif actionsMod.buttons[1] then
		GuiService.SelectedObject = actionsMod.buttons[1]
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

-- Populate itemData based on current magic type and unlocked levels
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

	-- Staffs: Starter staff always available
	if statsMod.StaffStats then
		local starterKey
		if magicType == statsMod.MagicType.Artificer then
			starterKey = "StarterStaffArtificer"
		elseif magicType == statsMod.MagicType.Primordial then
			starterKey = "StarterStaffPrimordial"
		elseif magicType == statsMod.MagicType.Nature then
			starterKey = "StarterStaffNature"
		end

		if starterKey and statsMod.StaffStats[starterKey] then
			local staffData = statsMod.StaffStats[starterKey]
			table.insert(actionsMod.itemData.Staffs, {
				Name = staffData.name or starterKey,
				Icon = "rbxassetid://0", -- TODO: real icon
				Type = "Staff",
				InternalName = starterKey,
			})
		end
	end

	-- Creatures / Abilities
	local typeLevels = statsMod.MagicLevels and statsMod.MagicLevels[magicType] or {}
	local seenCreatures = {}
	local seenSpells = {}

	for lvl = 1, level do
		local levelData = typeLevels["Level" .. lvl]
		if not levelData then continue end

		if levelData.Abilities then
			local ability = levelData.Abilities
			if not seenCreatures[ability] then
				seenCreatures[ability] = true
				local printedName = (
					statsMod.creatureStats
					and statsMod.creatureStats[ability]
					and statsMod.creatureStats[ability].printedName
				) or ability
				table.insert(actionsMod.itemData.Creatures, {
					Name = printedName,
					Icon = "rbxassetid://0",
					Type = "Creature",
					InternalName = ability,
				})
			end
		end

		if levelData.Spells then
			local spell = levelData.Spells
			if not seenSpells[spell] then
				seenSpells[spell] = true
				local printedName = (
					statsMod.SpellInfo
					and statsMod.SpellInfo[spell]
					and statsMod.SpellInfo[spell].printedName
				) or spell
				table.insert(actionsMod.itemData.Spells, {
					Name = printedName,
					Icon = "rbxassetid://0",
					Type = "Spell",
					InternalName = spell,
				})
			end
		end
	end

	-- Limit to 16 per category
	for _, cat in pairs({ "Staffs", "Creatures", "Spells" }) do
		local list = actionsMod.itemData[cat]
		if #list > 16 then
			actionsMod.itemData[cat] = { unpack(list, 1, 16) }
		end
	end
end

-- Setup default selections if all slots empty (or force = true)
local function setupDefaultSelections(force: boolean?)
    -- If force is true, clear everything first
    if force then
        for _, btn in ipairs(actionsMod.buttons) do
            btn.Text = btn.Name
            if btn:IsA("ImageButton") then
                btn.Image = "rbxassetid://0"
            end
            btn:SetAttribute("SelectedItem", nil)
            btn:SetAttribute("ItemType", nil)
            btn:SetAttribute("InternalName", nil)
        end

        -- Also unequip any staff tool (clean state)
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
        -- Normal mode: only proceed if truly all empty
        local allEmpty = true
        for _, btn in ipairs(actionsMod.buttons) do
            if btn:GetAttribute("InternalName") ~= nil then
                allEmpty = false
                break
            end
        end
        if not allEmpty then return end
    end

    local magicType = utilMod.GetAttribute(player, "Magic")
    if magicType == statsMod.MagicType.None then return end

    local level = getLevelForType(magicType)
    local character = player.Character
    local backpack = player:WaitForChild("Backpack")

    if not character or not character:FindFirstChild("Humanoid") then
        warn("Character not ready for default setup")
        return
    end

    -- Collect and sort buttons by category
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

    table.sort(creatureButtons, function(a, b) return a.Name < b.Name end)
    table.sort(spellButtons, function(a, b) return a.Name < b.Name end)

    -- Staff: Assign starter
    if staffButton and #actionsMod.itemData.Staffs > 0 then
        local item = actionsMod.itemData.Staffs[1]
        staffButton.Text = item.Name or "?"
        if staffButton:IsA("ImageButton") then
            staffButton.Image = item.Icon or "rbxassetid://0"
        end
        staffButton:SetAttribute("SelectedItem", item.Name)
        staffButton:SetAttribute("ItemType", item.Type)
        staffButton:SetAttribute("InternalName", item.InternalName or "")

        local targetToolName = item.InternalName
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:match("^StarterStaff") then
                tool.Parent = backpack
            end
        end
        local targetTool = backpack:FindFirstChild(targetToolName)
        if targetTool and targetTool:IsA("Tool") then
            targetTool.Parent = character
        else
            warn("Staff tool not found in Backpack for default: " .. targetToolName)
        end
    end

    -- Creatures: level 1 → first slot, level 2 → second slot (if available)
    local numCreatureSlots = #creatureButtons
    local unlockedCreatures = actionsMod.itemData.Creatures
    for i = 1, math.min(2, numCreatureSlots, #unlockedCreatures) do
        local item = unlockedCreatures[i]
        local btn = creatureButtons[i]
        btn.Text = item.Name or "?"
        if btn:IsA("ImageButton") then
            btn.Image = item.Icon or "rbxassetid://0"
        end
        btn:SetAttribute("SelectedItem", item.Name)
        btn:SetAttribute("ItemType", item.Type)
        btn:SetAttribute("InternalName", item.InternalName or "")
    end

    -- Spells: level 1–7 → first 7 slots (if available)
    local numSpellSlots = #spellButtons
    local unlockedSpells = actionsMod.itemData.Spells
    for i = 1, math.min(7, numSpellSlots, #unlockedSpells) do
        local item = unlockedSpells[i]
        local btn = spellButtons[i]
        btn.Text = item.Name or "?"
        if btn:IsA("ImageButton") then
            btn.Image = item.Icon or "rbxassetid://0"
        end
        btn:SetAttribute("SelectedItem", item.Name)
        btn:SetAttribute("ItemType", item.Type)
        btn:SetAttribute("InternalName", item.InternalName or "")
    end
end

-- Button state management
local function disableButton(btn: GuiButton)
	btn.Active = false
	btn.Interactable = false
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 0.5
    btn.Selectable = false
end

local function updateButtonStates()
	local shouldDisableAll = 
		utilMod.GetAttribute(player, "HasFallen") or
		utilMod.GetAttribute(player, "Firing") or
		(CastFeedback and CastFeedback.IsOnCooldown and CastFeedback.IsOnCooldown()) or
		false

	for _, btn in ipairs(actionsMod.buttons) do
		if not btn:IsA("GuiButton") then continue end

		local itemType = btn:GetAttribute("ItemType")
		local internalName = btn:GetAttribute("InternalName")

		btn.Active = true
		btn.Interactable = true
		btn.AutoButtonColor = true
		btn.BackgroundTransparency = 0
        btn.Selectable = true
        
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

			local manaCost = combatMod.LeveltoManaCost and combatMod.LeveltoManaCost(creatureName) or 0
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
		end

		if itemType == "Spell" and internalName then
			local spellName = internalName
			local spell = statsMod.SpellInfo and statsMod.SpellInfo[spellName]
			if not spell then continue end

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

			if spell.spellType and table.find({"damage", "areaDamage", "debuff"}, spell.spellType) then
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
	setupDefaultSelections(true)  -- force during development; change to false later
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

	for i, item in ipairs(items) do
		if i > 16 then break end

		local slot = Instance.new("ImageButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.Active = true
		slot.Selectable = true
		slot.Parent = selectionFrame

		slot.Image = item.Icon or "rbxassetid://0"
		slot.ScaleType = Enum.ScaleType.Fit

		if item.IsPlaceholder then
			slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			slot.ImageTransparency = 0.6
		end

		local label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = item.Name or "?"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		if item.IsPlaceholder then
			label.TextColor3 = Color3.fromRGB(180, 180, 180)
		else
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
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
					-- Clear slot
					actionsMod.selectedButton.Text = actionsMod.selectedButton.Name
					if actionsMod.selectedButton:IsA("ImageButton") then
						actionsMod.selectedButton.Image = "rbxassetid://0"
					end
					actionsMod.selectedButton:SetAttribute("SelectedItem", nil)
					actionsMod.selectedButton:SetAttribute("ItemType", nil)
					actionsMod.selectedButton:SetAttribute("InternalName", nil)

					for _, tool in ipairs(character:GetChildren()) do
						if tool:IsA("Tool") and tool.Name:match("^StarterStaff") then
							tool.Parent = backpack
							break
						end
					end
				else
					-- Equip / select
					actionsMod.selectedButton.Text = item.Name or "?"
					if actionsMod.selectedButton:IsA("ImageButton") then
						actionsMod.selectedButton.Image = item.Icon or "rbxassetid://0"
					end
					actionsMod.selectedButton:SetAttribute("SelectedItem", item.Name)
					actionsMod.selectedButton:SetAttribute("ItemType", item.Type)
					actionsMod.selectedButton:SetAttribute("InternalName", item.InternalName or "")

					if item.Type == "Staff" then
						local targetToolName = item.InternalName

						for _, tool in ipairs(character:GetChildren()) do
							if tool:IsA("Tool") and tool.Name:match("^StarterStaff") then
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
	if globalDebounce then return end
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

local function useItem(button)
	local itemType = button:GetAttribute("ItemType")
	local internalName = button:GetAttribute("InternalName")
	if not itemType or not internalName then return end

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
		startCastAndCooldown(castTime, internalName, 3, function()
			Events.SummonEvent:FireServer(creatureName)
		end)
	elseif itemType == "Spell" then
		local spellName = internalName
		local spellInfo = statsMod.SpellInfo and statsMod.SpellInfo[spellName]
		if not spellInfo then return end
		local castTime = spellInfo.castTime or 2
		local extraCooldown = spellInfo.cooldown or 0
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
		if not child:IsA("GuiButton") then continue end

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
					populateSelection(availableItems)
					selectionFrame.Visible = true
					selectionFrame.Active = true
					selectionFrame.ZIndex = spellFrame.ZIndex + 10
				end
			end
		end)
	end
end

-- Cross-platform close + gamepad secondary action
local function setupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not selectionFrame.Visible then
			if input.KeyCode == Enum.KeyCode.ButtonY and not gameProcessed then
				local focused = GuiService.SelectedObject
				if focused and table.find(actionsMod.buttons, focused) then
					actionsMod.selectedButton = focused
					local category = getCategory(focused.Name)
					local availableItems = getAvailableItems(category)
					populateSelection(availableItems)
					selectionFrame.Visible = true
					selectionFrame.Active = true
					selectionFrame.ZIndex = spellFrame.ZIndex + 10
				end
			end
			return
		end

		if input.KeyCode == Enum.KeyCode.ButtonB
			or input.KeyCode == Enum.KeyCode.Escape
			or input.UserInputType == Enum.UserInputType.BackButton then
			closeSelection()
		end
	end)
end

function actionsMod.Init()
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

	-- Periodic update for dynamic conditions (range, etc.)
	task.spawn(function()
		while true do
			updateButtonStates()
			task.wait(0.4)
		end
	end)

	-- Auto-focus Staff
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
