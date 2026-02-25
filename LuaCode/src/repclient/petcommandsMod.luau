--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local petsGui = playerGui:WaitForChild("PetGui")

local PetEvent = ReplicatedStorage.Events.PetEvent

-- ────────────────────────────────────────────────────────────────────────────────
--   Exported public API type
-- ────────────────────────────────────────────────────────────────────────────────

export type PetCommandsAPI = {
	-- Initialize button connections & set initial visual state
	-- Should be called once when the PetGui screen loads
	Init: () -> (),

	-- Toggle "Follow" mode on/off
	-- When enabling Follow → automatically disables DefendLith & TakeLith
	ToggleFollow: () -> (),

	-- Toggle "Attack" mode on/off
	-- When disabling Attack → automatically disables DefendLith & TakeLith
	ToggleAttack: () -> (),

	-- Set pet to Defend Lith mode
	-- Only works if Attack is currently enabled
	-- Automatically disables Follow & TakeLith
	DefendLith: () -> (),

	-- Set pet to Take Lith mode
	-- Only works if Attack is currently enabled
	-- Automatically disables Follow & DefendLith
	TakeLith: () -> (),
}

local petecommandsMod = {}
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

-- =========================
-- INTERNAL HELPERS
-- =========================

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
	PetEvent:FireServer({
		Following     = state.IsPetFollowing,
		Attacking     = state.IsPetAttacking,
		TakingLith    = state.IsPetTakingLith,
		DefendingLith = state.IsPetDefendingLith,
	})
end

-- =========================
-- ✅ PUBLIC FUNCTIONS
-- =========================

function petecommandsMod.ToggleFollow()
	state.IsPetFollowing = not state.IsPetFollowing

	if state.IsPetFollowing then
		state.IsPetDefendingLith = false
		state.IsPetTakingLith    = false
	end

	firePetCommands()
	updateButtonVisuals()
end

function petecommandsMod.ToggleAttack()
	state.IsPetAttacking = not state.IsPetAttacking

	if not state.IsPetAttacking then
		state.IsPetDefendingLith = false
		state.IsPetTakingLith    = false
	end

	firePetCommands()
	updateButtonVisuals()
end

function petecommandsMod.DefendLith()
	if not state.IsPetAttacking then return end

	state.IsPetDefendingLith = true
	state.IsPetTakingLith    = false
	state.IsPetFollowing     = false

	firePetCommands()
	updateButtonVisuals()
end

function petecommandsMod.TakeLith()
	if not state.IsPetAttacking then return end

	state.IsPetTakingLith    = true
	state.IsPetDefendingLith = false
	state.IsPetFollowing     = false

	firePetCommands()
	updateButtonVisuals()
end

-- =========================
-- INIT (GUI binding only)
-- =========================

function petecommandsMod.Init()
	updateButtonVisuals()

	buttons.Follow.MouseButton1Click:Connect(petecommandsMod.ToggleFollow)
	buttons.Attack.MouseButton1Click:Connect(petecommandsMod.ToggleAttack)
	buttons.DefendLith.MouseButton1Click:Connect(petecommandsMod.DefendLith)
	buttons.TakeLith.MouseButton1Click:Connect(petecommandsMod.TakeLith)
end

return petecommandsMod :: PetCommandsAPI
