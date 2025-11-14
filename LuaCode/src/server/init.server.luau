
--local funMod = require(game.ServerScriptService.FunModScript)----
--local ds = game:GetService("DataStoreService")
--local plrData = ds:GetDataStore("Testing_035")
--local dataStoreEnabled = false
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local collectionService = game:GetService("CollectionService")
local repstore = game:GetService("ReplicatedStorage")
local serverstorage = game:GetService("ServerStorage")
local magicMod = require(game.ReplicatedStorage.Shared.combatMod)

local function CharacterAdded(character)
	local plr = game.Players:GetPlayerFromCharacter(character)
	local hum = character:FindFirstChild("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	collectionService:AddTag(character, "Character")

	-- local currPos = hrp.CFrame.Position
	-- local rot = CFrame.Angles(0,math.rad(90),0)
	-- hrp.CFrame = CFrame.new(currPos)*rot
	
	-- hum.BreakJointsOnDeath = false
	-- hum.HealthChanged:Connect(function()
		
	-- end)
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(CharacterAdded)
	
    -- set magic to enum of none

	player:SetAttribute("Magic", magicMod.MagicType.Artificer)
	player:SetAttribute("MagicLevel", 1)
	
	
	
	-- if dataStoreEnabled then
		
	-- 	local data = plrData:GetAsync(player.UserId)
		
	-- 	if data ~= nil then
			
	-- 		for key,value in pairs(data)do
				
	-- 		end
			
	-- 		local allAtts = player:GetAttributes()
	-- 		for dataKey, dataValue in pairs(data)do
	-- 			for key,value in pairs(allAtts)do
	-- 				if key == dataKey then
	-- 					player:SetAttribute(key, dataValue)
	-- 				end
	-- 			end
	-- 		end
	-- 		print("PlayerData Loaded.")
	-- 	else
	-- 		data = {
	-- 			["TotalApples"] = 0,
	-- 			["TotalLogs"] = 0,
	-- 			["HighScore"] = 0,
	-- 			["TotalTrees"] = 0
	-- 		}
	-- 		local success,err = pcall(function()
	-- 			plrData:SetAsync(player.UserId,data)
	-- 		end)
	-- 		if success then
	-- 			print("New player saved")
	-- 		else
	-- 			warn("new player failed to save.")
	-- 		end
	-- 	end
		
	-- 	game:BindToClose(function()
	-- 		-- Initialize the default data table
	-- 		local data = {
	-- 			["TotalApples"] = 0,
	-- 			["TotalLogs"] = 0,
	-- 			["HighScore"] = 0,
	-- 			["TotalTrees"] = 0
	-- 		}

	-- 		-- Get all player attributes
	-- 		local allAtts = player:GetAttributes()

	-- 		-- Update data table with matching attributes
	-- 		for key, value in pairs(allAtts) do
	-- 			if data[key] ~= nil then -- Check if the key exists in the data table
	-- 				data[key] = value
	-- 			end
	-- 		end

	-- 		-- Save the data once
	-- 		local success, err = pcall(function()
	-- 			plrData:SetAsync(player.UserId, data)
	-- 		end)

	-- 		if success then
	-- 			print("Player data saved successfully for " .. player.Name)
	-- 		else
	-- 			warn("Failed to save player data for " .. player.Name .. ": " .. tostring(err))
	-- 		end
	-- 	end)
		
		
	-- else
	-- 	warn("Datastores disabled")
	-- end
	
		
end)


local summonevent = repstore.Events:waitForChild("SummonEvent")
summonevent.OnServerEvent:Connect(function(player, creatureName)
    print("SummonEvent received from "..player.Name.." for creature "..creatureName)
    local creature = serverstorage.Entities:FindFirstChild(creatureName)
    if creature then
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local summonedCreature = creature:Clone()
				summonedCreature:SetAttribute("OwnedBy", player.UserId)
                summonedCreature.Parent = workspace:WaitForChild("Pets")
                -- get creature humanoidrootpart cframe and offset by 5 studs in front of player
                local offsetCFrame = hrp.CFrame * CFrame.new(0, 0, -5)
                local creatureHRP = summonedCreature:FindFirstChild("HumanoidRootPart")
                if creatureHRP then
                    creatureHRP.CFrame = offsetCFrame
                    
                    print("Summoned "..creatureName.." for "..player.Name)
                else
                    warn("Summoned creature "..creatureName.." has no HumanoidRootPart")
                end
            end
        end
    else
        warn("Creature "..creatureName.." not found in Serverstorate.Entities")
    end
end)


-- admin area

local adminEvent = repstore.Events.AdminEvent
adminEvent.OnServerEvent:Connect(function(player, command)
    if player.UserId == 2484051658 then
        if command == "IncrementMagic" then
            local currentType = player:GetAttribute("Magic")
            if currentType == magicMod.MagicType.None then
                player:SetAttribute("Magic", magicMod.MagicType.Artificer)
            elseif currentType == magicMod.MagicType.Artificer then
                player:SetAttribute("Magic", magicMod.MagicType.Primordial)
            elseif currentType == magicMod.MagicType.Primordial then
                player:SetAttribute("Magic", magicMod.MagicType.None)
            end
        end
        if command == "LevelUp" then
            local currentLevel = player:GetAttribute("MagicLevel")
            if currentLevel < 7 then
                player:SetAttribute("MagicLevel", currentLevel + 1)
            end
        end
    end
end)

