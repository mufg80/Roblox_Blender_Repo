-- --!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local dataStoreEnabled: boolean = false

local statsMod = require(ReplicatedStorage.Shared.statsMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local recyleMod = require(ReplicatedStorage.Shared.recycleMod)
local effectMod = require(ReplicatedStorage.Shared.effectMod)
local lithMod = require(ReplicatedStorage.Shared.lithMod)

local function setStaffandPets(player: Player): ()
	local character: Model? = player.Character
	if not character then
		return
	end

	local prim: {Instance} = character:GetChildren()
	for _, item in pairs(prim) do
		if item:IsA("Tool") then
			local stype: any = item:GetAttribute("StaffType")
			if stype then
				item:Destroy()
			end
		end
	end

	local backpack: Backpack? = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local items: {Instance} = backpack:GetChildren()
		for _, item in pairs(items) do
			if item:IsA("Tool") then
				local stype: any = item:GetAttribute("StaffType")
				if stype then
					item:Destroy()
				end
			end
		end
	end

	local currentType: any = player:GetAttribute("Magic")
	local pets: {Model} = utilMod.MyPets(player)
	for _, pet: Model in pairs(pets) do
		if statsMod.creatureStats[pet.Name] and statsMod.creatureStats[pet.Name].magicType ~= currentType then
			pet:Destroy()
			local soul: number = player:GetAttribute("Souls") or 0
			player:SetAttribute("Souls", soul + 1)
		end
	end

	if currentType == statsMod.MagicType.Artificer then
		local artstaff: Tool? = ServerStorage.Staffs:FindFirstChild("StarterStaffArtificer")
		if artstaff and backpack then
			local clone: Tool = artstaff:Clone()
			clone.Parent = backpack
		end
	elseif currentType == statsMod.MagicType.Primordial then
		local primstaff: Tool? = ServerStorage.Staffs:FindFirstChild("StarterStaffPrimordial")
		if primstaff and backpack then
			local clone: Tool = primstaff:Clone()
			clone.Parent = backpack
		end
	elseif currentType == statsMod.MagicType.Nature then
		local naturestaff: Tool? = ServerStorage.Staffs:FindFirstChild("StarterStaffNature")
		if naturestaff and backpack then
			local clone: Tool = naturestaff:Clone()
			clone.Parent = backpack
		end
	end
end

local function GetMagicType(player: Player): string?
	local currentType: any = player:GetAttribute("Magic")
	if currentType == statsMod.MagicType.Artificer then
		return "ArtificerLevel"
	elseif currentType == statsMod.MagicType.Primordial then
		return "PrimordialLevel"
	elseif currentType == statsMod.MagicType.Nature then
		return "NatureLevel"
	end
	return nil
end

local function setStats(thisPlayer: Player): ()
	local baseStats: { [string]: any } = utilMod.GetStatsFromFolder(thisPlayer)
	local humanoid: Humanoid? = thisPlayer.Character and thisPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local secs: number = 0
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

local function ReduceMana(player: Player): ()
	local currentmana: number? = player:GetAttribute("Mana")
	local currentMax: number? = player:GetAttribute("MaxMana")

	if currentMax and currentmana and currentMax < currentmana then
		player:SetAttribute("Mana", currentMax)
	end
end

local function CharacterAdded(character: Model): ()
	local plr: Player? = game.Players:GetPlayerFromCharacter(character)
	if not plr then return end

	local max: number? = plr:GetAttribute("MaxSouls")
	local soul: number? = plr:GetAttribute("Souls")
	ReplicatedStorage.Events.GainedSoulEvent:FireClient(plr, soul or 0, max or 0)

	local hum: Humanoid? = character:FindFirstChild("Humanoid")
	setStats(plr)

	if hum then
		local connection: thread? = nil
		hum.HealthChanged:Connect(function(health: number)
			local damageTaken: number = hum:GetAttribute("LastHealth") and (hum:GetAttribute("LastHealth") - health) or 0

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
				hum.Health = 1
				plr:SetAttribute("HasFallen", true)
				plr:SetAttribute("Mana", 1)
				for _, part: Instance in plr.Character:GetDescendants() do
					if part:IsA("MeshPart") then
						part.Transparency = 0.75
						local AdornerClone: Highlight = ReplicatedStorage.PlayerHighLight:Clone()
						AdornerClone.Parent = part
						AdornerClone.Name = "DeathAdornment"
					end
				end
			end
		end)
	end
end

game.Players.PlayerAdded:Connect(function(player: Player)
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

	player.CharacterAppearanceLoaded:Connect(CharacterAdded)

	local AddBuffDebuffEvent: BindableEvent = Instance.new("BindableEvent")
	AddBuffDebuffEvent.Name = "BuffDebuffEvent"
	AddBuffDebuffEvent.Parent = player

	AddBuffDebuffEvent.Event:Connect(function(_player1: Player, _spellname: string)
		setStats(player)
	end)

	local RemoveBuffDebuffEvent: BindableEvent = Instance.new("BindableEvent")
	RemoveBuffDebuffEvent.Name = "RemoveBuffDebuffEvent"
	RemoveBuffDebuffEvent.Parent = player

	RemoveBuffDebuffEvent.Event:Connect(function(_player1: Player, _spellname: string)
		local character: Model? = player.Character
		if not character then return end
		local atts: { [string]: any } = character:GetAttributes()
		local isbuffstartingwithBuffTrue: boolean = true
		for attName: string, _ in pairs(atts) do
			if string.sub(attName, 1, 5) == "Buff_" then
				isbuffstartingwithBuffTrue = false
				break
			end
		end
		if isbuffstartingwithBuffTrue then
			local currentType: any = player:GetAttribute("Magic")
			local sourceStats: { [string]: any }
			if currentType == statsMod.MagicType.None then
				sourceStats = combatMod.ShallowTableCopy("PlayerNone")
			elseif currentType == statsMod.MagicType.Artificer then
				sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
			elseif currentType == statsMod.MagicType.Primordial then
				sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
			elseif currentType == statsMod.MagicType.Nature then
				sourceStats = combatMod.ShallowTableCopy("PlayerNature")
			else
				return
			end
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
		else
			setStats(player)
		end
	end)

	player:GetAttributeChangedSignal("MaxMana"):Connect(function()
		ReduceMana(player)
	end)

	player:GetAttributeChangedSignal("Magic"):Connect(function()
		local currentType: any = player:GetAttribute("Magic")
		local sourceStats: { [string]: any }?
		if currentType == statsMod.MagicType.None then
			sourceStats = combatMod.ShallowTableCopy("PlayerNone")
			player:SetAttribute("MaxMana", 20)
		elseif currentType == statsMod.MagicType.Artificer then
			sourceStats = combatMod.ShallowTableCopy("PlayerArtificer")
			player:SetAttribute("MaxMana", player:GetAttribute("ArtificerLevel") * 20)
		elseif currentType == statsMod.MagicType.Primordial then
			sourceStats = combatMod.ShallowTableCopy("PlayerPrimordial")
			player:SetAttribute("MaxMana", player:GetAttribute("PrimordialLevel") * 20)
		elseif currentType == statsMod.MagicType.Nature then
			sourceStats = combatMod.ShallowTableCopy("PlayerNature")
			player:SetAttribute("MaxMana", player:GetAttribute("NatureLevel") * 20)
		end
		if sourceStats then
			utilMod.CopyStatsToFolder(player, sourceStats)
			setStats(player)
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
		local currentmana: number? = player:GetAttribute("Mana")
		local currentMax: number? = player:GetAttribute("MaxMana")
		if currentmana and currentMax and currentmana > currentMax then
			player:SetAttribute("Mana", currentMax)
		end

		if currentmana == currentMax and player:GetAttribute("HasFallen") == true then
			player:SetAttribute("HasFallen", false)
			local character: Model? = player.Character
			if character then
				for _, part: Instance in character:GetDescendants() do
					if part:IsA("MeshPart") then
						part.Transparency = 0.0
						local AdornerClone: Highlight? = part:FindFirstChild("DeathAdornment")
						if AdornerClone then
							AdornerClone:Destroy()
						end
					end
				end
			end
		end
	end)

	if dataStoreEnabled then
		local plrData: GlobalDataStore = DataStoreService:GetDataStore("Testing_035")
		local data: any = plrData:GetAsync(player.UserId)

		if data ~= nil then
			local allAtts: { [string]: any } = player:GetAttributes()
			for dataKey: string, dataValue: any in pairs(data) do
				if allAtts[dataKey] ~= nil then
					player:SetAttribute(dataKey, dataValue)
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
			local success: boolean, err: string? = pcall(function()
				plrData:SetAsync(player.UserId, data)
			end)
			if not success then
				warn("new player failed to save.")
			end
		end

		game:BindToClose(function()
			local data: {
				Magic: any,
				ArtificerLevel: number,
				PrimordialLevel: number,
				NatureLevel: number,
				Experience: number,
			} = {
				Magic = statsMod.MagicType.None,
				ArtificerLevel = 1,
				PrimordialLevel = 1,
				NatureLevel = 1,
				Experience = 1,
			}

			local allAtts: { [string]: any } = player:GetAttributes()
			for key: string, value: any in pairs(allAtts) do
				if data[key] ~= nil then
					data[key] = value
				end
			end

			local success: boolean, err: string? = pcall(function()
				plrData:SetAsync(player.UserId, data)
			end)

			if not success then
				warn("Failed to save player data for " .. player.Name .. ": " .. tostring(err))
			end
		end)
	else
		warn("Datastores disabled")
	end

	local level: number = math.random(2, 7)
	local mtype: number = math.random(1, 3)
	mtype = 1
	level = 7
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

local summonevent: RemoteEvent = ReplicatedStorage.Events:WaitForChild("SummonEvent")
summonevent.OnServerEvent:Connect(function(player: Player, creatureName: string)
	local spawnpoint: Vector3? = utilMod.FindClearSpawnPoint(player, 10)
	if not spawnpoint then
		warn("No clear spawn point")
		return
	end

	local secs: number = statsMod.creatureStats[creatureName] and (statsMod.creatureStats[creatureName].level or 3 / 2) or 1.5
	task.delay(secs, function()
		if player:GetAttribute("HasFallen") then
			return
		end
		local summonedCreature: Model? = combatMod.ApplyAbility(player, creatureName, recyleMod, spawnpoint)
		local souls: number = player:GetAttribute("Souls") or 0
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

local spellevent: RemoteEvent = ReplicatedStorage.Events:WaitForChild("SpellCastEvent")
spellevent.OnServerEvent:Connect(function(player: Player, spellname: string)
	local secs: number = statsMod.SpellInfo[spellname] and (statsMod.SpellInfo[spellname].castTime or 3) or 3
	task.delay(secs, function()
		if player:GetAttribute("HasFallen") then
			return
		end
		combatMod.ApplySpell(player, spellname)
		spellevent:FireClient(player, spellname)
	end)
end)

local petEvents: RemoteEvent = ReplicatedStorage.Events:WaitForChild("PetEvent")
petEvents.OnServerEvent:Connect(function(plr: Player, commands: {
	Following: boolean,
	Attacking: boolean,
	TakingLith: boolean,
	DefendingLith: boolean,
})
	plr:SetAttribute("PetAttack", commands.Attacking)
	plr:SetAttribute("PetFollow", commands.Following)
	plr:SetAttribute("PetTakeLith", commands.TakingLith)
	plr:SetAttribute("PetDefendLith", commands.DefendingLith)
end)

local spawnpoints: {BasePart} = workspace:WaitForChild("FeralSpawnPoints"):GetChildren()

local function spawnferal(): ()
	if #spawnpoints == 0 then return end

	local rand: number = math.random(1, #spawnpoints)
	local point: BasePart = spawnpoints[rand]

	local creature: Model
	if recyleMod.CheckIfExistsFeral("FeralArtifactGuardian") then
		creature = recyleMod.ReturnFeral("FeralArtifactGuardian")
		creature.Parent = workspace:WaitForChild("Ferals")
	else
		local template: Model? = ServerStorage.Entities:FindFirstChild("FeralArtifactGuardian")
		if not template then return end
		creature = template:Clone()
		creature.Name = utilMod.uniqueName(creature.Name)
		creature:SetAttribute("OwnedBy", "None")
		creature:AddTag("Character")
		creature.Parent = workspace:WaitForChild("Ferals")
	end

	local height: number = statsMod.creatureStats["ArtifactGuardian"].height
	local offsetheight: number = height - point.Position.Y
	local offsetCFrame: CFrame = CFrame.new(point.Position.X, offsetheight, point.Position.Z)

	local creatureHRP: BasePart? = creature:FindFirstChild("HumanoidRootPart")
	if creatureHRP then
		creatureHRP.CFrame = offsetCFrame
	else
		warn("Summoned creature " .. creature.Name .. " has no HumanoidRootPart")
	end
end

local manaspawnpoints: {BasePart} = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()

for _, point: BasePart in pairs(manaspawnpoints) do
	if point:GetAttribute("HasBuilding") ~= true then
		point:SetAttribute("HasBuilding", true)
		local spoutModel: Model? = ServerStorage.Buildings.ManaSpout
		if spoutModel then
			local clone: Model = spoutModel:Clone()
			clone:PivotTo(point.CFrame)
			clone.Parent = workspace.ManaPoints
		end
	end
end

task.spawn(function()
	while task.wait(6) do
		for _, plr: Player in game.Players:GetPlayers() do
			local mana: number? = plr:GetAttribute("Mana")
			local maxMana: number? = plr:GetAttribute("MaxMana")
			if mana and maxMana then
				local newmana: number = math.min(mana + 12, maxMana)
				plr:SetAttribute("Mana", newmana)
			end

			if not plr:GetAttribute("HasFallen") and not plr:GetAttribute("InCombat") then
				local char: Model? = plr.Character
				if char then
					local hum: Humanoid? = char:FindFirstChild("Humanoid")
					if hum and hum.Health < hum.MaxHealth then
						local health: number = math.clamp(hum.Health + 10, 1, hum.MaxHealth)
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
		local feralsFolder: Folder? = workspace:FindFirstChild("Ferals")
		if feralsFolder and #feralsFolder:GetChildren() == 0 then
			spawnferal()
		end

		task.wait(20)
	end
end)

-- admin area
local adminEvent: RemoteEvent = ReplicatedStorage.Events.AdminEvent
adminEvent.OnServerEvent:Connect(function(player: Player, command: string)
	if player.UserId == 2484051658 then
		if command == "IncrementMagic" then
			local currentType: any = player:GetAttribute("Magic")
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
			local magictype: string? = GetMagicType(player)
			if not magictype then
				return
			end
			local currentLevel: number? = player:GetAttribute(magictype)
			if currentLevel and currentLevel < 7 then
				player:SetAttribute(magictype, currentLevel + 1)
			end
		end
	end
end)