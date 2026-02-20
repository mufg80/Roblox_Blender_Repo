local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)

local effectMod = require(ReplicatedStorage.Shared.effectMod)
local recyleMod = require(ReplicatedStorage.Shared.recycleMod)
local DataStoreService = game:GetService("DataStoreService")
local dataStoreEnabled: boolean = false
local ServerStorage = game:GetService("ServerStorage")

local setupMod = {}

-- DEV Testing Quick Setup
local function setupDevTesting(player: Player)
	utilMod.SetAttribute(player, "Magic", statsMod.MagicType.Nature)
	utilMod.SetAttribute(player, "NatureLevel", 2)
	utilMod.SetAttribute(player, "PrimordialLevel", 2)
	utilMod.SetAttribute(player, "ArtificerLevel", 1)
end

local function setCollisionGroup(plrId: number, model: Model)
	if model.Name == "Dervish" or model.Name == "FeralDervish" then
		return
	end
	if not plrId or not model then
		warn("should not reach me")
		return
	end
	if typeof(plrId) ~= "number" or not model:IsA("Model") then
		warn("Should not reach me")
		return
	end
	if not game.Players:GetPlayerByUserId(plrId) then
		warn("Should not reach me")
		return
	end
	local groupName = tostring(plrId)
	local exists = false
	for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		if group.name == groupName then
			exists = true
			break
		end
	end

	if not exists then
		PhysicsService:RegisterCollisionGroup(groupName)
		PhysicsService:CollisionGroupSetCollidable(groupName, groupName, false)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") or part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end
local function fireManaUsedEvent(player)
	local manaevent = ReplicatedStorage.Events.ManaUsedEvent
	if manaevent then
		manaevent:FireClient(player, utilMod.GetAttribute(player,"Mana"), utilMod.GetAttribute(player, "MaxMana"))
	end

end
local function setStaffandPets(player: Player, char: Model): ()
	if not player or not char then
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	-- ────────────────────────────────────────────────
	-- 1. Move mismatched staffs back to backpack (do NOT destroy)
	-- ────────────────────────────────────────────────
	local currentMagic = utilMod.GetAttribute(player, "Magic") or "None"

	for _, item in char:GetChildren() do
		if item:IsA("Tool") then
			local staffType = utilMod.GetAttribute(item, "StaffType")
			if staffType then
				local staffData = statsMod.StaffStats[staffType]
				local staffMagic = staffData and staffData.magicType or "Unknown"

				if staffMagic ~= currentMagic then
					-- Wrong magic type → move back to backpack
					item.Parent = backpack
					-- Optional: print("Moved mismatched staff back to backpack:", item.Name, player.Name)
				end
				-- If staffMagic == currentMagic → leave it equipped
			end
		end
	end

	-- ────────────────────────────────────────────────
	-- 2. Handle mismatched pets (unchanged)
	-- ────────────────────────────────────────────────
	local pets = utilMod.MyPets(char) or {}

	for _, pet in pets do
		local trimmed = utilMod.customTrim(pet.Name)
		local petType = statsMod.creatureStats[trimmed] and statsMod.creatureStats[trimmed].magicType

		if petType and petType ~= currentMagic then
			utilMod.SetAttribute(pet, "Reclaimed", true)
			utilMod.SetAttribute(pet, "RecycleMe", true)

			local souls = utilMod.GetAttribute(player, "Souls") or 0
			local maxSouls = utilMod.GetAttribute(player, "MaxSouls") or 0
			if souls < maxSouls then
				utilMod.SetAttribute(player, "Souls", souls + 1)
				ReplicatedStorage.Events.GainedSoulEvent:FireClient(player, souls + 1, maxSouls)
			end
		end
	end

	-- ────────────────────────────────────────────────
	-- 3. STAFF MANAGEMENT (backpack + ensure all desired are present)
	-- ────────────────────────────────────────────────
	local serverStaffs = ServerStorage:FindFirstChild("Staffs")
	if not serverStaffs then
		warn("ServerStorage.Staffs folder missing!")
		return
	end

	-- A. Collect all desired staff names
	local desiredStaffs = {} -- [staffName] = true

	-- Progression staffs (all levels up to current)
	local levelAttrName = setupMod.GetMagicType(player) -- e.g. "ArtificerLevel"
	local magiclevel = utilMod.GetAttribute(player, levelAttrName) or 1

	local progression = statsMod.MagicLevels[currentMagic]
	if progression then
		for lv = 1, magiclevel do
			local levelData = progression["Level" .. lv]
			if levelData and levelData.staffs then
				for _, name in levelData.staffs do
					if name and name ~= "" then
						desiredStaffs[name] = true
					end
				end
			end
		end
	end

	-- B. Bonus / purchasable / special unlocked staffs
	for attrName, value in player:GetAttributes() do
		local category, magicType, itemName = attrName:match("^Earned_(%w+)_(%w+)_(.+)$")
		if category == "Staff" and itemName and magicType == currentMagic then
			desiredStaffs[itemName] = true
		end
	end

	-- C. Give missing desired staffs to backpack
	for staffName in pairs(desiredStaffs) do
		if not backpack:FindFirstChild(staffName) then
			local original = serverStaffs:FindFirstChild(staffName)
			if original and original:IsA("Tool") then
				local clone = original:Clone()
				clone.Parent = backpack
				-- Optional: print("Gave staff to backpack:", staffName, player.Name)
			else
				warn("Missing staff in ServerStorage.Staffs:", staffName)
			end
		end
	end
end

function setupMod.GetMagicType(player: Player): string?
	local magic = utilMod.GetAttribute(player, "Magic")
	if magic == statsMod.MagicType.Artificer then
		return "ArtificerLevel"
	end
	if magic == statsMod.MagicType.Primordial then
		return "PrimordialLevel"
	end
	if magic == statsMod.MagicType.Nature then
		return "NatureLevel"
	end
	return nil
end

local function setStats(Char: Model, spellname: string?)
	local baseStats = utilMod.GetStatsFromFolder(Char)
	local character = Char
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local plr = Players:GetPlayerFromCharacter(Char)
	local level = plr and utilMod.GetAttribute(plr, setupMod.GetMagicType(plr)) or 1
	local numberlevel = tonumber(level) * 20
	humanoid.MaxHealth = (baseStats.hitPoints + numberlevel) or humanoid.MaxHealth
	if humanoid.Health > humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end

	if spellname and statsMod.BuffInfo[spellname] and statsMod.BuffInfo[spellname].hitPoints then
		humanoid.Health = math.min(humanoid.Health + statsMod.BuffInfo[spellname].hitPoints, humanoid.MaxHealth)
	end

	humanoid.WalkSpeed = 16 * (baseStats.speed or 1)
	utilMod.SetAttribute(humanoid, "LastHealth", humanoid.Health)
	setStaffandPets(plr, Char)
end

local function ReduceMana(player: Player)
	local current = utilMod.GetAttribute(player, "Mana")
	local max = utilMod.GetAttribute(player, "MaxMana")
	if current and max and current > max then
		utilMod.SetAttribute(player, "Mana", max)
	end
end

local function CharacterAdded(character: Model)
	local player = game.Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	setCollisionGroup(player.UserId, character)
	local souls = utilMod.GetAttribute(player, "Souls") or 0
	local maxSouls = utilMod.GetAttribute(player, "MaxSouls") or 0
	ReplicatedStorage.Events.GainedSoulEvent:FireClient(player, souls, maxSouls)

	setStats(player)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local inCombatTimeout
	humanoid.HealthChanged:Connect(function(health)
		local lastHealth = utilMod.GetAttribute(humanoid, "LastHealth")
		local damage = lastHealth and (lastHealth - health) or 0
		utilMod.SetAttribute(humanoid, "LastHealth", health)

		if damage > 0 then
			utilMod.SetAttribute(player, "InCombat", true)
			if inCombatTimeout then
				task.cancel(inCombatTimeout)
			end
			inCombatTimeout = task.delay(5, function()
				utilMod.SetAttribute(player, "InCombat", false)
			end)
		end

		if health < 2 then
			humanoid.Health = 1
			utilMod.SetAttribute(player, "HasFallen", true)
			utilMod.SetAttribute(player, "Mana", 1)
			setStaffandPets(player, character)
			for _, part in character:GetDescendants() do
				if part:IsA("MeshPart") then
					part.Transparency = 0.75
					local adorn = ReplicatedStorage.PlayerHighLight:Clone()
					adorn.Name = "DeathAdornment"
					adorn.Parent = part
				end
			end
		end
	end)
	-- Buff/Debuff events
	local addEvent = Instance.new("BindableEvent")
	addEvent.Name = "BuffDebuffEvent"
	addEvent.Parent = character
	addEvent.Event:Connect(function(_, spellname)
		setStats(character, spellname)
	end)

	local removeEvent = Instance.new("BindableEvent")
	removeEvent.Name = "RemoveBuffDebuffEvent"
	removeEvent.Parent = character
	removeEvent.Event:Connect(function(_, spellname)
		if not character then
			return
		end

		local hasBuff = false
		for name in character:GetAttributes() do
			if typeof(name) == "string" and name:sub(1, 5) == "Buff_" then
				hasBuff = true
				break
			end
		end

		if not hasBuff then
			local magic = utilMod.GetAttribute(player, "Magic")
			local sourceStats
			if magic == statsMod.MagicType.None then
				sourceStats = combatMod.ShallowTableCopy("PlayerNone")
			elseif magic == statsMod.MagicType.Artificer then
				sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
			elseif magic == statsMod.MagicType.Primordial then
				sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
			elseif magic == statsMod.MagicType.Nature then
				sourceStats = combatMod.ShallowTableCopy("PlayerNature")
			end

			if sourceStats then
				utilMod.CopyStatsToFolder(character, sourceStats)
				setStats(character)
			end
		else
			setStats(character)
		end
	end)

	-- Mana cap enforcement
	player:GetAttributeChangedSignal("MaxMana"):Connect(function()
		ReduceMana(player)
	end)

	-- Magic type change → stats/staff/pets
	player:GetAttributeChangedSignal("Magic"):Connect(function()
		local magic = utilMod.GetAttribute(player, "Magic")
		local sourceStats
		if magic == statsMod.MagicType.None then
			sourceStats = combatMod.ShallowTableCopy("PlayerNone")
			utilMod.SetAttribute(player, "MaxMana", 20)
		elseif magic == statsMod.MagicType.Artificer then
			sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "ArtificerLevel") * 20)
		elseif magic == statsMod.MagicType.Primordial then
			sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "PrimordialLevel") * 20)
		elseif magic == statsMod.MagicType.Nature then
			sourceStats = combatMod.ShallowTableCopy("PlayerNature")
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "NatureLevel") * 20)
		end

		if sourceStats then
			utilMod.CopyStatsToFolder(player.Character, sourceStats)
			setStats(player.Character)
			setStaffandPets(player, player.Character)
		end
	end)

	-- Level changes → mana cap
	player:GetAttributeChangedSignal("ArtificerLevel"):Connect(function()
		if utilMod.GetAttribute(player, "Magic") == statsMod.MagicType.Artificer then
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "ArtificerLevel") * 20)
			setStats(player.Character, nil)
		end
	end)

	player:GetAttributeChangedSignal("PrimordialLevel"):Connect(function()
		if utilMod.GetAttribute(player, "Magic") == statsMod.MagicType.Primordial then
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "PrimordialLevel") * 20)
			setStats(player.Character, nil)
		end
	end)

	player:GetAttributeChangedSignal("NatureLevel"):Connect(function()
		if utilMod.GetAttribute(player, "Magic") == statsMod.MagicType.Nature then
			utilMod.SetAttribute(player, "MaxMana", utilMod.GetAttribute(player, "NatureLevel") * 20)
			setStats(player.Character, nil)
		end
	end)

	-- Mana overflow → cap + wake from fallen if full
	player:GetAttributeChangedSignal("Mana"):Connect(function()
		local mana = utilMod.GetAttribute(player, "Mana")
		local maxMana = utilMod.GetAttribute(player, "MaxMana")
		if mana and maxMana and mana > maxMana then
			utilMod.SetAttribute(player, "Mana", maxMana)
		end

		if mana == maxMana and utilMod.GetAttribute(player, "HasFallen") then
			utilMod.SetAttribute(player, "HasFallen", false)
			local char = player.Character
			if char then
				setStaffandPets(player, char)
				for _, part in char:GetDescendants() do
					if part:IsA("MeshPart") then
						part.Transparency = 0
						local adorn = part:FindFirstChild("DeathAdornment")
						if adorn then
							adorn:Destroy()
						end
					end
				end
			end
		end
	end)

	-- DataStore (disabled by default)
	if dataStoreEnabled then
		local store = DataStoreService:GetDataStore("Testing_035")
		local success, data = pcall(function()
			return store:GetAsync(player.UserId)
		end)

		if success and data then
			for key, value in data do
				utilMod.SetAttribute(player, key, value)
			end
		else
			-- Default values already set above
		end

		game:BindToClose(function()
			local saveData = {}
			for key in { "Magic", "ArtificerLevel", "PrimordialLevel", "NatureLevel", "Experience" } do
				saveData[key] = utilMod.GetAttribute(player, key)
			end

			pcall(function()
				store:SetAsync(player.UserId, saveData)
			end)
		end)
	else
		warn("DataStores disabled")
	end

	-- Dev/test: force Artificer + level 7

	setupDevTesting(player)
end

game.Players.PlayerAdded:Connect(function(player)
	-- Default attributes
	utilMod.SetAttribute(player, "Magic", statsMod.MagicType.None)
	utilMod.SetAttribute(player, "ArtificerLevel", 1)
	utilMod.SetAttribute(player, "PrimordialLevel", 1)
	utilMod.SetAttribute(player, "NatureLevel", 1)
	utilMod.SetAttribute(player, "ArtificerExperience", 1)
	utilMod.SetAttribute(player, "PrimordialExperience", 1)
	utilMod.SetAttribute(player, "NatureExperience", 1)

	utilMod.SetAttribute(player, "MaxMana", 20)
	utilMod.SetAttribute(player, "Mana", 20)
	utilMod.SetAttribute(player, "HasFallen", false)
	utilMod.SetAttribute(player, "AllyId", 0)
	utilMod.SetAttribute(player, "Souls", 4)
	utilMod.SetAttribute(player, "MaxSouls", 4)
	utilMod.SetAttribute(player, "PetAttack", true)
	utilMod.SetAttribute(player, "PetFollow", true)
	utilMod.SetAttribute(player, "PetTakeLith", false)
	utilMod.SetAttribute(player, "PetDefendLith", false)
	--utilMod.SetAttribute(player, "Earned_Staff_Nature_LegendaryStaff", true)

	player.CharacterAppearanceLoaded:Connect(CharacterAdded)
end)

-- Remote events
local petManaEvent = ReplicatedStorage.Events.PetManaEvent
local summonEvent = ReplicatedStorage.Events.SummonEvent

summonEvent.OnServerEvent:Connect(function(player: Player, creatureName: string)
	local spawnpoint = utilMod.FindClearSpawnPoint(player, 10)
	if not spawnpoint then
		return
	end

	-- Check if max is reached
	local maxAmount = statsMod.MaxCreatures[creatureName]
	if maxAmount and maxAmount > 0 then
		local mypets = utilMod.MyPets(player.Character) or {}
		local existing = 0
		for _, pet in mypets do
			if pet and pet.Parent and utilMod.customTrim(pet.Name) == creatureName then
				existing += 1
			end
		end
		if existing >= maxAmount then
			return
		end
	end

	local castTime = utilMod.CreatureCastTime(creatureName)
	combatMod.AdjustSpeedOfHumanoid(player, castTime)
	task.delay(castTime, function()
		if utilMod.GetAttribute(player, "HasFallen") then
			return
		end

		local summoned = combatMod.ApplyAbility(player, creatureName, recyleMod, spawnpoint)
		if not summoned then
			return
		end

		local souls = utilMod.GetAttribute(player, "Souls") or 0
		if souls > 0 then
			utilMod.SetAttribute(player, "Souls", souls - 1)
		else
			return
		end

		ReplicatedStorage.Events.GainedSoulEvent:FireClient(
			player,
			utilMod.GetAttribute(player, "Souls"),
			utilMod.GetAttribute(player, "MaxSouls")
		)
		setCollisionGroup(player.UserId, summoned)

		summonEvent:FireClient(player, summoned, utilMod.GetAttribute(player, "Souls"))

		if utilMod.IsMobHealer(summoned) then
			petManaEvent:FireClient(
				player,
				summoned.Name,
				utilMod.GetAttribute(summoned, "Mana"),
				utilMod.GetAttribute(summoned, "MaxMana")
			)
		end
		fireManaUsedEvent(player)
	end)

	effectMod.SummonCreatureEffect(spawnpoint, creatureName, castTime)
	
end)

local spellCastEvent = ReplicatedStorage.Events.SpellCastEvent
spellCastEvent.OnServerEvent:Connect(function(player: Player, spellname: string)
	local spell = statsMod.SpellInfo[spellname]
	if not spell then
		return
	end

	local castTime = spell.castTime or 3
	combatMod.AdjustSpeedOfHumanoid(player, castTime)
	task.delay(castTime, function()
		if utilMod.GetAttribute(player, "HasFallen") then
			return
		end
		combatMod.ApplySpell(player, spellname)
		spellCastEvent:FireClient(player, spellname)
		fireManaUsedEvent(player, utilMod.GetAttribute(player, "Mana"), utilMod.GetAttribute(player, "MaxMana"))
	end)
	
end)

local petEvent = ReplicatedStorage.Events.PetEvent
petEvent.OnServerEvent:Connect(
	function(
		player: Player,
		commands: { Following: boolean, Attacking: boolean, TakingLith: boolean, DefendingLith: boolean }
	)
		utilMod.SetAttribute(player, "PetFollow", commands.Following)
		utilMod.SetAttribute(player, "PetAttack", commands.Attacking)
		utilMod.SetAttribute(player, "PetTakeLith", commands.TakingLith)
		utilMod.SetAttribute(player, "PetDefendLith", commands.DefendingLith)
	end
)

return setupMod
