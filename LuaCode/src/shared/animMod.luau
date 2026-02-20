-- animMod (ModuleScript)
-- Place this ModuleScript anywhere accessible (e.g. ReplicatedStorage)
-- Retrieves the 3 animations from ReplicatedStorage.Anims
-- Provides 6 public functions for activating/deactivating the hold, fire, and cast animations
-- Hold animation is automatically resumed when DeactivateFire or DeactivateCast is called
-- (if the staff hold state was active). Fire and cast cannot run simultaneously (handled by caller).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anims = ReplicatedStorage:WaitForChild("Anims")
local SpellCastAnim = Anims:WaitForChild("SpellCastAnim")
local StarterStaffAnimation = Anims:WaitForChild("StarterStaffAnimation") -- fire staff
local StarterStaffHoldAnimation = Anims:WaitForChild("StarterStaffHoldAnimation") -- hold staff

local animMod = {}

-- Internal state (per humanoid)
local tracks = {}       -- [humanoid] = {hold = AnimationTrack, fire = AnimationTrack, cast = AnimationTrack}
local isHolding = {}    -- [humanoid] = boolean

local function getTracks(humanoid)
	if not tracks[humanoid] then
		local animator = humanoid:WaitForChild("Animator")

		local t = {
			hold = animator:LoadAnimation(StarterStaffHoldAnimation),
			fire = animator:LoadAnimation(StarterStaffAnimation),
			cast = animator:LoadAnimation(SpellCastAnim),
		}

		t.hold.Looped = true
		t.hold.Priority = Enum.AnimationPriority.Action
		t.fire.Priority = Enum.AnimationPriority.Action
        t.fire.Looped = false
		t.cast.Priority = Enum.AnimationPriority.Action
        t.cast.Looped = true
		tracks[humanoid] = t
	end
	return tracks[humanoid]
end

-- ====================== PUBLIC FUNCTIONS ======================

function animMod.ActivateHold(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local t = getTracks(humanoid)
	isHolding[humanoid] = true

	-- Stop any active actions
	if t.fire.IsPlaying then t.fire:Stop(0.3) end
	if t.cast.IsPlaying then t.cast:Stop(0.3) end
	t.hold:Play(0.3)
end

function animMod.DeactivateHold(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local t = getTracks(humanoid)
	isHolding[humanoid] = false

	if t.hold.IsPlaying then t.hold:Stop(0) end
	if t.fire.IsPlaying then t.fire:Stop(0) end
	if t.cast.IsPlaying then t.cast:Stop(0) end
end

function animMod.ActivateFire(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local t = getTracks(humanoid)

	-- If we were holding staff, stop the hold animation so fire takes over
	if isHolding[humanoid] and t.hold.IsPlaying then
		t.hold:Stop(0.3)
	end

	-- Safety: stop cast in case it was somehow active
	if t.cast.IsPlaying then t.cast:Stop(0.3) end
	t.fire:Play(0)
    t.fire.Stopped:Connect(function()
        if isHolding[humanoid] then
            animMod.ActivateHold(humanoid)
        end
    end)
end

function animMod.ActivateCast(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local t = getTracks(humanoid)

	-- If we were holding staff, stop the hold animation so cast takes over
	if isHolding[humanoid] and t.hold.IsPlaying then
		t.hold:Stop(0.3)
	end

	-- Safety: stop fire in case it was somehow active
	if t.fire.IsPlaying then t.fire:Stop(0) end

	t.cast:Play(0.3)
end

function animMod.DeactivateCast(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local t = getTracks(humanoid)

	if t.cast.IsPlaying then
		t.cast:Stop(0.3)
	end

	-- Resume hold animation if the staff is still supposed to be held
	if isHolding[humanoid] then
		t.hold:Play(0.3)
	end
end

return animMod