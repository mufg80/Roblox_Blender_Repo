--!strict
-- ReplicatedStorage.Shared.soulcolorMod
-- Client-side visual feedback for soul ownership via particle color

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Configurable colors
local MY_SOUL_PARTICLE_COLOR = Color3.fromRGB(98, 234, 255) -- your current blue
local OTHER_SOUL_PARTICLE_COLOR = Color3.fromRGB(255, 70, 70) -- vivid red (adjust as needed)

-- You can make red more subtle if preferred:
-- local OTHER_SOUL_PARTICLE_COLOR = Color3.fromRGB(220, 80, 80)

local SOULS_FOLDER_NAME = "Souls"
local SOUL_PART_NAME = "SoulObject" -- adjust if the model/part has a different name
local ANCHOR_NAME = "Anchor"
local PARTICLE_NAME = "ParticleEmitter"
local MYSOUL = "OwnedSurfaceAppearance"
local OTHERSOUL = "OtherSurfaceAppearance"

local soulcolorMod = {}

-- Main function to update visual for one soul
local function updateSoulVisual(soul: Instance)
	if not soul:IsDescendantOf(workspace) then
		return
	end

	-- Find the Anchor part
	local anchor = soul:FindFirstChild(ANCHOR_NAME, true)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end

	-- soulobject
	local object = soul:FindFirstChild(SOUL_PART_NAME)

	-- Find the ParticleEmitter
	local particle = anchor:FindFirstChildWhichIsA("ParticleEmitter")
	if not particle or particle.Name ~= PARTICLE_NAME then
		-- warn("No matching ParticleEmitter found in " .. soul.Name)
		return
	end

	-- Get ownership
	local ownedBy = soul:GetAttribute("OwnedBy") -- should be number (UserId)
	local isMine = ownedBy == player.UserId

	if isMine then
		local myappearanceclone = soul:FindFirstChild(MYSOUL) and soul:FindFirstChild(MYSOUL):Clone()
		if not myappearanceclone then
			return
		end

		local hasrightappearance = object:FindFirstChild(MYSOUL)
		local haswrongappearance = object:FindFirstChild(OTHERSOUL)

		if haswrongappearance then
			haswrongappearance.Parent = nil
		end
		if not hasrightappearance then
			myappearanceclone.Parent = object
		end
	else
		local myappearanceclone = soul:FindFirstChild(OTHERSOUL) and soul:FindFirstChild(OTHERSOUL):Clone()
		if not myappearanceclone then
			return
		end

		local hasrightappearance = object:FindFirstChild(OTHERSOUL)
		local haswrongappearance = object:FindFirstChild(MYSOUL)

		if haswrongappearance then
			haswrongappearance.Parent = nil
		end
		if not hasrightappearance then
			myappearanceclone.Parent = object
		end
	end

	-- Apply color
	local targetColor = isMine and MY_SOUL_PARTICLE_COLOR or OTHER_SOUL_PARTICLE_COLOR

	-- Only change if different (performance + avoids unnecessary replication)
	if particle.Color ~= targetColor then
		particle.Color = ColorSequence.new(targetColor)
	end
end

-- Initialize all existing souls
local function initializeSouls()
	local soulsFolder = workspace:FindFirstChild(SOULS_FOLDER_NAME)
	if not soulsFolder then
		warn("Souls folder not found in workspace")
		return
	end

	for _, soul in ipairs(soulsFolder:GetChildren()) do
		updateSoulVisual(soul)
	end
end

-- Watch for new souls
local function setupListeners()
	local soulsFolder = workspace:FindFirstChild(SOULS_FOLDER_NAME)
	if not soulsFolder then
		return
	end

	-- New souls added
	soulsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") or child:IsA("BasePart") then
			task.delay(0.1, function() -- small delay for attributes to replicate
				updateSoulVisual(child)
			end)
		end
	end)

	-- Watch for ownership changes (theft/recycling/etc.)
	-- Heartbeat is used instead of AttributeChanged for performance
	task.spawn(function()
		while true do
			if soulsFolder.Parent then
				for _, soul in ipairs(soulsFolder:GetChildren()) do
					updateSoulVisual(soul)
				end
			end
			task.wait(1.5) -- adjust interval; 1-2 seconds is usually enough
		end
	end)
end

function soulcolorMod.Init()
	initializeSouls()
	setupListeners()

	-- Optional: re-check if player respawns (in case souls are recreated)
	player.CharacterAdded:Connect(function()
		task.delay(1, initializeSouls)
	end)
end

return soulcolorMod
