--!strict
-- ReplicatedStorage.Client.PetCommands

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local petsGui = playerGui:WaitForChild("PetGui")

local PetEvent = ReplicatedStorage.Events.PetEvent

local PetCommands = {}

-- State
local state = {
	IsPetAttacking = true,
	IsPetFollowing = true,
	IsPetDefendingLith = false,
	IsPetTakingLith = false,
}

local buttons = {
	Follow     = petsGui.PetFrame.FollowButton,
	Attack     = petsGui.PetFrame.AttackButton,
	DefendLith = petsGui.PetFrame.DefendLithButton,
	TakeLith   = petsGui.PetFrame.TakeLithButton,
}

local function updateButtonVisuals()
	buttons.Follow.BackgroundColor3     = state.IsPetFollowing     and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(80, 80, 80)
	buttons.Attack.BackgroundColor3     = state.IsPetAttacking     and Color3.fromRGB(255, 80, 80)   or Color3.fromRGB(80, 80, 80)
	buttons.DefendLith.BackgroundColor3 = state.IsPetDefendingLith and Color3.fromRGB(0, 255, 0)     or Color3.fromRGB(80, 80, 80)
	buttons.TakeLith.BackgroundColor3   = state.IsPetTakingLith    and Color3.fromRGB(255, 170, 0)   or Color3.fromRGB(80, 80, 80)
	
	-- Lith buttons only active when attacking is on
	buttons.DefendLith.Active = state.IsPetAttacking
	buttons.TakeLith.Active   = state.IsPetAttacking
	buttons.DefendLith.AutoButtonColor = state.IsPetAttacking
	buttons.TakeLith.AutoButtonColor   = state.IsPetAttacking
end

local function firePetCommands()
	local commands = {
		Following     = state.IsPetFollowing,
		Attacking     = state.IsPetAttacking,
		TakingLith    = state.IsPetTakingLith,
		DefendingLith = state.IsPetDefendingLith,
	}
	PetEvent:FireServer(commands)
end

function PetCommands.Init()
	updateButtonVisuals()
	
	buttons.Follow.MouseButton1Click:Connect(function()
		state.IsPetFollowing = not state.IsPetFollowing
		if state.IsPetFollowing then
			state.IsPetDefendingLith = false
			state.IsPetTakingLith    = false
		end
		firePetCommands()
		updateButtonVisuals()
	end)
	
	buttons.Attack.MouseButton1Click:Connect(function()
		state.IsPetAttacking = not state.IsPetAttacking
		if not state.IsPetAttacking then
			state.IsPetDefendingLith = false
			state.IsPetTakingLith    = false
		end
		firePetCommands()
		updateButtonVisuals()
	end)
	
	buttons.DefendLith.MouseButton1Click:Connect(function()
		if not state.IsPetAttacking then return end
		state.IsPetDefendingLith = true
		state.IsPetTakingLith    = false
		state.IsPetFollowing     = false
		firePetCommands()
		updateButtonVisuals()
	end)
	
	buttons.TakeLith.MouseButton1Click:Connect(function()
		if not state.IsPetAttacking then return end
		state.IsPetTakingLith    = true
		state.IsPetDefendingLith = false
		state.IsPetFollowing     = false
		firePetCommands()
		updateButtonVisuals()
	end)
end

return PetCommands