--!strict
-- ReplicatedStorage.Client.ResourceBars

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local utilMod = require(ReplicatedStorage.Shared.utilMod)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statsGui = playerGui:WaitForChild("StatsGui")

local function ChangeHealth()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local inner = statsGui.HudFrame.HealthMeterBar.InnerFill
	local fraction = if humanoid.MaxHealth == 0 then 0 else math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	inner.Size = UDim2.new(fraction, 0, 1, 0)
end

local function ChangeMana()
	local current = utilMod.GetAttribute(player, "Mana") or 0
	local maxMana = utilMod.GetAttribute(player, "MaxMana") or 1
	local fraction = if maxMana == 0 then 0 else math.clamp(current / maxMana, 0, 1)
	
	local inner = statsGui.HudFrame.ManaMeterBar.InnerFill
	inner.Size = UDim2.new(fraction, 0, 1, 0)
end

local function AdjustSouls(soulsLeft: number, maxSouls: number)
	local label = statsGui.SoulFrame.SoulsLabel
	if label then
		label.Text = soulsLeft .. "/" .. maxSouls
	end
end

-- Public API
local ResourceBars = {}

function ResourceBars.Init()
	-- Initial updates
	ChangeHealth()
	ChangeMana()
	
	-- Connections
	if player.Character then
		local humanoid = player.Character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.HealthChanged:Connect(ChangeHealth)
		end
	end
	
	player.CharacterAdded:Connect(function(char)
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.HealthChanged:Connect(ChangeHealth)
			ChangeHealth()
		end
	end)
	
	player:GetAttributeChangedSignal("Mana"):Connect(ChangeMana)
	
	ReplicatedStorage.Events.GainedSoulEvent.OnClientEvent:Connect(function(soulsLeft: number, maxSouls: number)
		if soulsLeft and maxSouls then
			utilMod.SetAttribute(player, "Souls", soulsLeft)
			AdjustSouls(soulsLeft, maxSouls)
		end
	end)
end

return ResourceBars