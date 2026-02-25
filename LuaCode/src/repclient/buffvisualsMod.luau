--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local statsMod = require(ReplicatedStorage.Shared.statsMod)
local buffMod = require(ReplicatedStorage.Shared.buffMod)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statsGui = playerGui:WaitForChild("StatsGui")

export type BuffVisualsMod = {
	Init:() -> (),
}

local BuffVisuals = {}

local function getBuffParentFrame(id: number | string): Frame?
	if typeof(id) == "number" then
		-- Player buff
		return statsGui.HudFrame:FindFirstChild("PlayerEffectsFrame")
	else
		-- Pet buff
		local frameName = tostring(id) .. "_PetFrame"
		local petFrame = statsGui.HudFrame:FindFirstChild(frameName)
		if petFrame then
			return petFrame:FindFirstChild("ZZBuffFrame")
		end
	end
	return nil
end

local function getModelForId(id: number | string): Model?
	if typeof(id) == "number" then
		local targetPlayer = Players:GetPlayerByUserId(id)
		return targetPlayer and targetPlayer.Character
	else
		-- Pet by name
		for _, pet in workspace.Pets:GetChildren() do
			if pet.Name == tostring(id) then
				return pet
			end
		end
	end
	return nil
end

local function onBuffReceived(id: number | string, spellName: string)
	local spellInfo = statsMod.SpellInfo[spellName]
	if not spellInfo then
		warn("Unknown spell in buff event:", spellName)
		return
	end

	local spellType = spellInfo.spellType
	if not table.find({"buff", "debuff", "heal", "damage"}, spellType) then
		return
	end

	local parentFrame = getBuffParentFrame(id)
	if not parentFrame then return end

	local duration = 1
	if statsMod.BuffInfo[spellName] and statsMod.BuffInfo[spellName].seconds then
		duration = statsMod.BuffInfo[spellName].seconds
	end

	local templateName = ({
		buff   = "BuffLabel",
		debuff = "DebuffLabel",
		heal   = "HealLabel",
		damage = "DamageLabel",
	})[spellType]

	local template = parentFrame:FindFirstChild(templateName)
	if not template then
		warn("Missing buff template:", templateName, "in", parentFrame:GetFullName())
		return
	end

	local label = template:Clone()
	label.Name = templateName .. "_" .. spellName
	label.Parent = parentFrame

	local keyPrefix = if typeof(id) == "number" then "Player" else tostring(id)
	local uniqueKey = keyPrefix .. "_" .. spellName .. "_" .. parentFrame.Name

	local model = getModelForId(id)
	if model and label:IsA("ImageLabel") then
		buffMod.StartBuffLabelTimer(label, duration, model, uniqueKey)
	end
end

function BuffVisuals.Init()
	ReplicatedStorage.Events.BuffDebuffHealEvent.OnClientEvent:Connect(onBuffReceived)
end

return BuffVisuals :: BuffVisualsMod