--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local statsMod = require(ReplicatedStorage.Shared.statsMod)
local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local recyleMod = require(ReplicatedStorage.Shared.recycleMod)
local effectMod = require(ReplicatedStorage.Shared.effectMod)
local lithMod = require(ReplicatedStorage.Shared.lithMod)
local testMod = require(ReplicatedStorage.Shared.testMod)
local regenMod = require(ReplicatedStorage.Shared.regenMod)
local setupMod = require(ReplicatedStorage.Shared.setupMod)
local spawnMod = require(ReplicatedStorage.Shared.spawnMod)

-- Admin commands
local adminEvent = ReplicatedStorage.Events.AdminEvent
adminEvent.OnServerEvent:Connect(function(player: Player, command: string)
	if player.UserId ~= 2484051658 then
		return
	end

	if command == "IncrementMagic" then
		local current = utilMod.GetAttribute(player, "Magic")
		local nextType
		if current == statsMod.MagicType.None then
			nextType = statsMod.MagicType.Artificer
		elseif current == statsMod.MagicType.Artificer then
			nextType = statsMod.MagicType.Primordial
		elseif current == statsMod.MagicType.Primordial then
			nextType = statsMod.MagicType.Nature
		elseif current == statsMod.MagicType.Nature then
			nextType = statsMod.MagicType.None
		end
		if nextType then
			utilMod.SetAttribute(player, "Magic", nextType)
		end
	end

	if command == "LevelUp" then
		local levelKey = setupMod.GetMagicType(player)
		if not levelKey then
			return
		end
		local current = utilMod.GetAttribute(player, levelKey)
		if current and current < 7 then
			utilMod.SetAttribute(player, levelKey, current + 1)
		end
	end
end)

-- local function PrintModelData(model: Model)
-- 	local dataFolder = model:FindFirstChild("Data")

-- 	if not dataFolder or not dataFolder:IsA("Folder") then
-- 		warn(model.Name .. " has no Data folder")
-- 		return
-- 	end

-- 	local parts = {}

-- 	for _, child in ipairs(dataFolder:GetChildren()) do
-- 		--local returnval = utilMod.getValue(child)
-- 		if child:IsA("ValueBase") then
-- 			local returnval = utilMod.getValue(child)
-- 			local name = child.Name

-- 			-- Convert value to a readable string
-- 			local valueStr = if returnval then tostring(returnval) else "nil"

-- 			table.insert(parts,  valueStr.."  ")
-- 		end
-- 	end

-- 	print(table.concat(parts, ", "))
-- end

-- task.spawn(function()
-- 	while task.wait(2) do
-- 		local plrs = game.Players:GetPlayers()
-- 		for _,plr in plrs do
-- 			local char = plr.Character

-- 			if char then
-- 				local mypets = utilMod.MyPets(char)
-- 				if mypets and next(mypets) ~= nil then
-- 					PrintModelData(mypets[1])
-- 				end
				
-- 			end
-- 		end
-- 	end
-- end)
