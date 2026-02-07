--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

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
