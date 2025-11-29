
local ds = game:GetService("DataStoreService")
local dataStoreEnabled = false
local collectionService = game:GetService("CollectionService")
local repstore = game:GetService("ReplicatedStorage")
local serverstorage = game:GetService("ServerStorage")
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local recyleMod = require(game.ReplicatedStorage.Shared.recycleMod)


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


local function CharacterAdded(character)
	local plr = game.Players:GetPlayerFromCharacter(character)
	local hum = character:FindFirstChild("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	collectionService:AddTag(character, "Character")

end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(CharacterAdded)

	

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

	player:GetAttributeChangedSignal("MaxMana"):Connect(function()
		local currentmana = player:GetAttribute("Mana")
		local currentMax = player:GetAttribute("MaxMana")

		if currentMax < currentmana then
			player:SetAttribute("Mana", currentMax)
		end
	end)
	
	player:GetAttributeChangedSignal("Magic"):Connect(function()
		local currentType = player:GetAttribute("Magic")
		if currentType == statsMod.MagicType.None then
			player:SetAttribute("MaxMana", 1)
		elseif currentType == statsMod.MagicType.Artificer then
			player:SetAttribute("MaxMana", player:GetAttribute("ArtificerLevel") * 20)
		elseif currentType == statsMod.MagicType.Primordial then
			player:SetAttribute("MaxMana", player:GetAttribute("PrimordialLevel") * 20)
		elseif currentType == statsMod.MagicType.Nature then
			player:SetAttribute("MaxMana", player:GetAttribute("NatureLevel") * 20)
		end
	end)

	player:GetAttributeChangedSignal("Mana"):Connect(function()
		local currentmana = player:GetAttribute("Mana")
		local currentMax = player:GetAttribute("MaxMana")
		if currentmana > currentMax then
			player:SetAttribute("Mana", currentMax)
		end
	end)




	if dataStoreEnabled then
		
		local plrData = ds:GetDataStore("Testing_035")
		local data = plrData:GetAsync(player.UserId)
		
		if data ~= nil then
			local allAtts = player:GetAttributes()
			for dataKey, dataValue in pairs(data)do
				for key,value in pairs(allAtts)do
					if key == dataKey then
						player:SetAttribute(key, dataValue)
					end
				end
			end
			print("PlayerData Loaded.")
		else
			data = {
				["Magic"] = statsMod.MagicType.None,
				["ArtificerLevel"] = 1,
				["PrimordialLevel"] = 1,
				["NatureLevel"] = 1,
				["Experience"] = 1
			}
			local success,err = pcall(function()
				plrData:SetAsync(player.UserId,data)
			end)
			if success then
				print("New player saved")
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
				["Experience"] = 1
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
				print("Player data saved successfully for " .. player.Name)
			else
				warn("Failed to save player data for " .. player.Name .. ": " .. tostring(err))
			end
		end)
	else
		warn("Datastores disabled")
	end
end)


local summonevent = repstore.Events:waitForChild("SummonEvent")
summonevent.OnServerEvent:Connect(function(player, creatureName)
 	print("SummonEvent received from "..player.Name.." for creature "..creatureName)
	combatMod.ApplyAbility(player, creatureName, recyleMod)
end)

local spellevent = repstore.Events:WaitForChild("SpellCastEvent")
spellevent.OnServerEvent:Connect(function(player, spellname)
	print("SpellEvent received from "..player.Name.." for spell "..spellname)
	combatMod.ApplySpell(player, spellname)
	
end)


local spawnpoints = workspace:WaitForChild("FeralSpawnPoints"):GetChildren()


function spawnferal()
	if spawnpoints then
		local rand = math.random(1, #spawnpoints)
		local point = spawnpoints[rand]
		local creature = nil
		if recyleMod.CheckIfExistsFeral("FeralArtifactGuardian")then
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
			warn("Summoned creature "..creature.." has no HumanoidRootPart")
		end
	end
end

local manaspawnpoints = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()

for _,point in pairs(manaspawnpoints) do
	if point:GetAttribute("HasBuilding") ~= "Empty" then
		point:SetAttribute("HasBuilding", "Spout")
		local spoutModel = serverstorage.Buildings.ManaSpout:Clone()  -- now a Model
		spoutModel:PivotTo(point.CFrame)  -- or point.CFrame * CFrame.new(0, offset, 0) if needed
		spoutModel.Parent = workspace.ManaPoints
	end
end

task.spawn(function()
	while task.wait(6) do
		for _,plr in game.Players:GetPlayers() do
			local mana = plr:GetAttribute("Mana")
			local newmana = math.min(mana + 2, plr:GetAttribute("MaxMana"))
			plr:SetAttribute("Mana", newmana)
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
			if not magictype or magictype == statsMod.MagicType.None then return end
            local currentLevel = player:GetAttribute(magictype)
            if currentLevel < 7 then
                player:SetAttribute(magictype, currentLevel + 1)
            end
        end
    end
end)

-- local testMod = require(game.ReplicatedStorage.Shared.testMod)
