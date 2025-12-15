local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ds = game:GetService("DataStoreService")
local dataStoreEnabled = false
local repstore = game:GetService("ReplicatedStorage")
local serverstorage = game:GetService("ServerStorage")
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local recyleMod = require(game.ReplicatedStorage.Shared.recycleMod)
local effectMod = require(game.ReplicatedStorage.Shared.effectMod)
local lithMod = require(ReplicatedStorage.Shared.lithMod)

local function setStaffandPets(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local prim = character:GetChildren()
	for _, item in pairs(prim) do
		if item:IsA("Tool") then
			local stype = item:GetAttribute("StaffType")
			if stype then
				item:Destroy()
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local items = backpack:GetChildren()
		for _, item in pairs(items) do
			if item:IsA("Tool") then
				local stype = item:GetAttribute("StaffType")
				if stype then
					item:Destroy()
				end
			end
		end
	end

	local currentType = player:GetAttribute("Magic")
	local pets = utilMod.MyPets(player)
	for _, pet in pairs(pets) do
		if statsMod.creatureStats[pet.Name] and statsMod.creatureStats[pet.Name].magicType ~= currentType then
			pet:Destroy()
			local soul = player:GetAttribute("Souls")
			player:SetAttribute("Souls", soul + 1)
		end
	end
	if currentType == statsMod.MagicType.Artificer then
		local artstaff = serverstorage.Staffs:FindFirstChild("StarterStaffArtificer"):Clone()
		artstaff.Parent = backpack
	elseif currentType == statsMod.MagicType.Primordial then
		local primstaff = serverstorage.Staffs:FindFirstChild("StarterStaffPrimordial"):Clone()
		primstaff.Parent = backpack
	elseif currentType == statsMod.MagicType.Nature then
		local naturestaff = serverstorage.Staffs:FindFirstChild("StarterStaffNature"):Clone()
		naturestaff.Parent = backpack
	else
		return
	end
end

local function GetMagicType(player: Player): string
	local currentType = player:GetAttribute("Magic")
	if currentType == statsMod.MagicType.Artificer then
		return "ArtificerLevel"
	elseif currentType == statsMod.MagicType.Primordial then
		return "PrimordialLevel"
	elseif currentType == statsMod.MagicType.Nature then
		return "NatureLevel"
	else
		warn("Should not reach me.")
		return nil
	end
end

local function setStats(thisPlayer: Player)
	local baseStats = utilMod.GetStatsFromFolder(thisPlayer)
	local humanoid = thisPlayer.Character and thisPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local secs = 0
		while not humanoid and secs <= 5 do
			task.wait(1)
			secs += 1
			humanoid = thisPlayer.Character and thisPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
		if not humanoid then
			warn("should not reach me")
			return
		end
	end
	humanoid.MaxHealth = baseStats.hitPoints
	if humanoid.Health > humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
	humanoid.WalkSpeed = 16 * baseStats.speed
	humanoid:SetAttribute("LastHealth", humanoid.Health)
end

local function ReduceMana(player: Player)
	local currentmana = player:GetAttribute("Mana")
	local currentMax = player:GetAttribute("MaxMana")

	if currentMax < currentmana then
		player:SetAttribute("Mana", currentMax)
	end
end

local function CharacterAdded(character)
	local plr = game.Players:GetPlayerFromCharacter(character)
	local hum = character:FindFirstChild("Humanoid")
	setStats(plr)
	local connection = nil
	if hum then
		hum.HealthChanged:Connect(function(health)
			local damageTaken = hum:GetAttribute("LastHealth") and (hum:GetAttribute("LastHealth") - health) or 0

			hum:SetAttribute("LastHealth", health)
			if damageTaken > 0 then
				plr:SetAttribute("InCombat", true)
				if connection then
					task.cancel(connection)
				end
				connection = task.delay(5, function()
					plr:SetAttribute("InCombat", false)
				end)
			end
			if hum.Health < 2 then
				local repstore = game:GetService("ReplicatedStorage")
				hum.Health = 1
				plr:SetAttribute("HasFallen", true)
				plr:SetAttribute("Mana", 1)
				for _, part in plr.Character:GetDescendants() do
					if part:IsA("MeshPart") then
						part.Transparency = 0.75
						local AdornerClone = repstore.PlayerHighLight:Clone()
						AdornerClone.Parent = part
						AdornerClone.Name = "DeathAdornment"
					end
				end
			end
		end)
	end
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(CharacterAdded)

	local AddBuffDebuffEvent = Instance.new("BindableEvent")
	AddBuffDebuffEvent.Name = "BuffDebuffEvent"
	AddBuffDebuffEvent.Parent = player

	AddBuffDebuffEvent.Event:Connect(function(player1: Player, spellname: string)
		setStats(player)
	end)

	local RemoveBuffDebuffEvent = Instance.new("BindableEvent")
	RemoveBuffDebuffEvent.Name = "RemoveBuffDebuffEvent"
	RemoveBuffDebuffEvent.Parent = player

	RemoveBuffDebuffEvent.Event:Connect(function(player1: Player, spellname: string)
		local atts = player.Character:GetAttributes()
		if not atts then
			return
		end
		local isbuffstartingwithBuffTrue = true
		for attName, attValue in pairs(atts) do
			if string.sub(attName, 1, 5) == "Buff_" then
				isbuffstartingwithBuffTrue = false
				break
			end
		end
		if isbuffstartingwithBuffTrue then
			local currentType = player:GetAttribute("Magic")
			if currentType == statsMod.MagicType.None then
				local sourceStats = combatMod.ShallowTableCopy("PlayerNone")
				utilMod.CopyStatsToFolder(player, sourceStats)
				setStats(player)
			elseif currentType == statsMod.MagicType.Artificer then
				local sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
				utilMod.CopyStatsToFolder(player, sourceStats)
				setStats(player)
			elseif currentType == statsMod.MagicType.Primordial then
				local sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
				utilMod.CopyStatsToFolder(player, sourceStats)
				setStats(player)
			elseif currentType == statsMod.MagicType.Nature then
				local sourceStats = combatMod.ShallowTableCopy("PlayerNature")
				utilMod.CopyStatsToFolder(player, sourceStats)
				setStats(player)
			end
		else
			setStats(player)
		end
	end)

	-- set magic to enum of none
	-- Persistence Attributes
	player:SetAttribute("Magic", statsMod.MagicType.None)
	player:SetAttribute("ArtificerLevel", 1)
	player:SetAttribute("PrimordialLevel", 1)
	player:SetAttribute("NatureLevel", 1)
	player:SetAttribute("ArtificerExperience", 1)
	player:SetAttribute("PrimordialExperience", 1)
	player:SetAttribute("NatureExperience", 1)

	-- No persistence for these attributes
	player:SetAttribute("MaxMana", 20)
	player:SetAttribute("Mana", 20)
	player:SetAttribute("HasFallen", false)
	player:SetAttribute("AllyId", 0)
	player:SetAttribute("Souls", 4)
	player:SetAttribute("MaxSouls", 4)
	player:SetAttribute("PetAttack", true)
	player:SetAttribute("PetFollow", true)
	player:SetAttribute("PetTakeLith", false)
	player:SetAttribute("PetDefendLith", false)

	player:GetAttributeChangedSignal("MaxMana"):Connect(function()
		ReduceMana(player)
	end)

	player:GetAttributeChangedSignal("Magic"):Connect(function()
		local currentType = player:GetAttribute("Magic")
		if currentType == statsMod.MagicType.None then
			local sourceStats = combatMod.ShallowTableCopy("PlayerNone")
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
			player:SetAttribute("MaxMana", 20)
			setStaffandPets(player)
		elseif currentType == statsMod.MagicType.Artificer then
			local sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
			player:SetAttribute("MaxMana", player:GetAttribute("ArtificerLevel") * 20)
			setStaffandPets(player)
		elseif currentType == statsMod.MagicType.Primordial then
			local sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
			player:SetAttribute("MaxMana", player:GetAttribute("PrimordialLevel") * 20)
			setStaffandPets(player)
		elseif currentType == statsMod.MagicType.Nature then
			local sourceStats = combatMod.ShallowTableCopy("PlayerNature")
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
			player:SetAttribute("MaxMana", player:GetAttribute("NatureLevel") * 20)
			setStaffandPets(player)
		end
	end)

	player:GetAttributeChangedSignal("ArtificerLevel"):Connect(function()
		if player:GetAttribute("Magic") == statsMod.MagicType.Artificer then
			player:SetAttribute("MaxMana", player:GetAttribute("ArtificerLevel") * 20)
		end
	end)
	player:GetAttributeChangedSignal("PrimordialLevel"):Connect(function()
		if player:GetAttribute("Magic") == statsMod.MagicType.Primordial then
			player:SetAttribute("MaxMana", player:GetAttribute("PrimordialLevel") * 20)
		end
	end)
	player:GetAttributeChangedSignal("NatureLevel"):Connect(function()
		if player:GetAttribute("Magic") == statsMod.MagicType.Nature then
			player:SetAttribute("MaxMana", player:GetAttribute("NatureLevel") * 20)
		end
	end)

	player:SetAttribute("Magic", statsMod.MagicType.Artificer)
	player:SetAttribute("Magic", statsMod.MagicType.None)

	player:GetAttributeChangedSignal("Mana"):Connect(function()
		local currentmana = player:GetAttribute("Mana")
		local currentMax = player:GetAttribute("MaxMana")
		if currentmana > currentMax then
			player:SetAttribute("Mana", currentMax)
		end

		if currentmana == currentMax and player:GetAttribute("HasFallen") == true then
			player:SetAttribute("HasFallen", false)
			for _, part in player.Character:GetDescendants() do
				if part:IsA("MeshPart") then
					part.Transparency = 0.0
					local AdornerClone = part:FindFirstChild("DeathAdornment")
					AdornerClone.Parent = nil
				end
			end
		end
	end)

	if dataStoreEnabled then
		local plrData = ds:GetDataStore("Testing_035")
		local data = plrData:GetAsync(player.UserId)

		if data ~= nil then
			local allAtts = player:GetAttributes()
			for dataKey, dataValue in pairs(data) do
				for key, value in pairs(allAtts) do
					if key == dataKey then
						player:SetAttribute(key, dataValue)
					end
				end
			end
		else
			data = {
				["Magic"] = statsMod.MagicType.None,
				["ArtificerLevel"] = 1,
				["PrimordialLevel"] = 1,
				["NatureLevel"] = 1,
				["Experience"] = 1,
			}
			local success, err = pcall(function()
				plrData:SetAsync(player.UserId, data)
			end)
			if success then
			else
				warn("new player failed to save.")
			end
		end

		game:BindToClose(function()
			-- Initialize the default data table
			local data = {
				["Magic"] = statsMod.MagicType.None,
				["ArtificerLevel"] = 1,
				["PrimordialLevel"] = 1,
				["NatureLevel"] = 1,
				["Experience"] = 1,
			}

			-- Get all player attributes
			local allAtts = player:GetAttributes()

			-- Update data table with matching attributes
			for key, value in pairs(allAtts) do
				if data[key] ~= nil then -- Check if the key exists in the data table
					data[key] = value
				end
			end

			-- Save the data once
			local success, err = pcall(function()
				plrData:SetAsync(player.UserId, data)
			end)

			if success then
			else
				warn("Failed to save player data for " .. player.Name .. ": " .. tostring(err))
			end
		end)
	else
		warn("Datastores disabled")
	end

	-- task.spawn(function()
	-- 	while task.wait(3) do
	-- 		local liths = workspace:FindFirstChild("ManaPoints"):GetChildren()
	-- 		for _, lith in pairs(liths) do
	-- 			local unique = lith:GetAttribute("Unique")
	-- 			if unique then
	-- 				print("Lith " .. tostring(unique) .. " at " .. lithMod.GetLithControl(unique))
	-- 			end
	-- 		end
	-- 	end
	-- end)

	local level = math.random(2, 7)
	local mtype = math.random(1, 3)
	if mtype == 1 then
		player:SetAttribute("Magic", statsMod.MagicType.Artificer)
		player:SetAttribute("ArtificerLevel", level)
	elseif mtype == 2 then
		player:SetAttribute("Magic", statsMod.MagicType.Primordial)
		player:SetAttribute("PrimordialLevel", level)
	elseif mtype == 3 then
		player:SetAttribute("Magic", statsMod.MagicType.Nature)
		player:SetAttribute("NatureLevel", level)
	end
end)

local summonevent = repstore.Events:waitForChild("SummonEvent")
summonevent.OnServerEvent:Connect(function(player, creatureName)
	local spawnpoint = utilMod.FindClearSpawnPoint(player, 10)
	if not spawnpoint then
		warn("No clear spawn point")
		return
	end

	local secs = statsMod.creatureStats[creatureName] and (statsMod.creatureStats[creatureName].level or 3 / 2)
	task.delay(secs, function()
		if player:GetAttribute("HasFallen") then
			return
		end
		local summonedCreature = combatMod.ApplyAbility(player, creatureName, recyleMod, spawnpoint)
		local souls = player:GetAttribute("Souls")
		if souls > 0 then
			player:SetAttribute("Souls", souls - 1)
		else
			return
		end
		ReplicatedStorage.Events.GainedSoulEvent:FireClient(
			player,
			player:GetAttribute("Souls"),
			player:GetAttribute("MaxSouls")
		)
		summonevent:FireClient(player, summonedCreature, player:GetAttribute("Souls"))
	end)

	effectMod.SummonCreatureEffect(spawnpoint, creatureName, secs)
end)

local spellevent = repstore.Events:WaitForChild("SpellCastEvent")
spellevent.OnServerEvent:Connect(function(player, spellname)
	local secs = statsMod.SpellInfo[spellname] and (statsMod.SpellInfo[spellname].castTime or 3)
	task.delay(secs, function()
		if player:GetAttribute("HasFallen") then
			return
		end
		combatMod.ApplySpell(player, spellname)
		spellevent:FireClient(player, spellname)
	end)
end)

local petEvents = repstore.Events:WaitForChild("PetEvent")
petEvents.OnServerEvent:Connect(function(plr, commands)
	--local commands = {isPetFollowing, isPetAttacking, isPetTakingLith, isPetDefendingLith}
	local following = commands.Following -- always correct
	local attacking = commands.Attacking
	local takingLith = commands.TakingLith
	local defendingLith = commands.DefendingLith
	plr:SetAttribute("PetAttack", attacking)
	plr:SetAttribute("PetFollow", following)
	plr:SetAttribute("PetTakeLith", takingLith)
	plr:SetAttribute("PetDefendLith", defendingLith)
end)

local spawnpoints = workspace:WaitForChild("FeralSpawnPoints"):GetChildren()

function spawnferal()
	if spawnpoints then
		local rand = math.random(1, #spawnpoints)
		local point = spawnpoints[rand]
		local creature = nil
		if recyleMod.CheckIfExistsFeral("FeralArtifactGuardian") then
			creature = recyleMod.ReturnFeral("FeralArtifactGuardian")
			creature.Parent = workspace:WaitForChild("Ferals")
		else
			creature = serverstorage.Entities:FindFirstChild("FeralArtifactGuardian"):Clone()
			creature.Name = utilMod.uniqueName(creature.Name)
			creature:SetAttribute("OwnedBy", "None")
			creature:AddTag("Character")
			creature.Parent = workspace:WaitForChild("Ferals")
		end

		local height = statsMod.creatureStats["ArtifactGuardian"].height

		local offsetheight = height - point.Position.Y
		local offsetCFrame = CFrame.new(point.Position.X, offsetheight, point.Position.Z)
		local creatureHRP = creature:FindFirstChild("HumanoidRootPart")
		if creatureHRP then
			creatureHRP.CFrame = offsetCFrame
		else
			warn("Summoned creature " .. creature .. " has no HumanoidRootPart")
		end
	end
end

local manaspawnpoints = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()

for _, point in pairs(manaspawnpoints) do
	if point:GetAttribute("HasBuilding") ~= true then
		point:SetAttribute("HasBuilding", true)
		local spoutModel = serverstorage.Buildings.ManaSpout:Clone() -- now a Model
		spoutModel:PivotTo(point.CFrame)
		spoutModel.Parent = workspace.ManaPoints
	end
end

task.spawn(function()
	while task.wait(6) do
		for _, plr in game.Players:GetPlayers() do
			local mana = plr:GetAttribute("Mana")
			local newmana = math.min(mana + 12, plr:GetAttribute("MaxMana"))
			plr:SetAttribute("Mana", newmana)

			if not plr:GetAttribute("HasFallen") and not plr:GetAttribute("InCombat") then
				local char = plr.Character
				if char then
					local hum = char:FindFirstChild("Humanoid")
					if hum and hum.Health < hum.MaxHealth then
						local health = math.clamp(hum.Health + 10, 1, hum.MaxHealth)
						hum.Health = health
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if #workspace:FindFirstChild("Ferals"):GetChildren() == 0 then
			spawnferal()
		end

		task.wait(20)
	end
end)

-- admin area

local adminEvent = repstore.Events.AdminEvent
adminEvent.OnServerEvent:Connect(function(player, command)
	if player.UserId == 2484051658 then
		if command == "IncrementMagic" then
			local currentType = player:GetAttribute("Magic")
			if currentType == statsMod.MagicType.None then
				player:SetAttribute("Magic", statsMod.MagicType.Artificer)
			elseif currentType == statsMod.MagicType.Artificer then
				player:SetAttribute("Magic", statsMod.MagicType.Primordial)
			elseif currentType == statsMod.MagicType.Primordial then
				player:SetAttribute("Magic", statsMod.MagicType.Nature)
			elseif currentType == statsMod.MagicType.Nature then
				player:SetAttribute("Magic", statsMod.MagicType.None)
			end
		end
		if command == "LevelUp" then
			local magictype = GetMagicType(player)
			if not magictype or magictype == statsMod.MagicType.None then
				return
			end
			local currentLevel = player:GetAttribute(magictype)
			if currentLevel < 7 then
				player:SetAttribute(magictype, currentLevel + 1)
			end
		end
	end
end)

-- local testMod = require(game.ReplicatedStorage.Shared.testMod)
