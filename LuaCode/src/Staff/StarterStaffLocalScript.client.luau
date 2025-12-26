-- --!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool: Tool = script.Parent
local player: Player = Players.LocalPlayer
local character: Model = player.Character or player.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid")
local animator: Animator = humanoid:WaitForChild("Animator")
player:SetAttribute("Firing", false)
-- Load animations from tool's child Animation objects (different IDs per staff)
local fireAnimObj: Animation = tool:WaitForChild("StarterStaffAnimation")
local holdAnimObj: Animation = tool:WaitForChild("StarterStaffHoldAnimation")

local fireAnim: Animation = Instance.new("Animation")
fireAnim.AnimationId = fireAnimObj.AnimationId

local holdAnim: Animation = Instance.new("Animation")
holdAnim.AnimationId = holdAnimObj.AnimationId

local fireTrack: AnimationTrack = animator:LoadAnimation(fireAnim)
fireTrack.Looped = false

local holdTrack: AnimationTrack = animator:LoadAnimation(holdAnim)
holdTrack.Looped = true

local canPlayAnim: boolean = true
local debounce: boolean = true

-- Single shared RemoteEvent for ALL staffs
local REMOTE_NAME: string = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not fireRemote then
	fireRemote = Instance.new("RemoteEvent")
	fireRemote.Name = REMOTE_NAME
	fireRemote.Parent = ReplicatedStorage
end

local staffType: string? = tool:GetAttribute("StaffType")
if not staffType or staffType == "" then
	warn("Tool", tool.Name, "missing 'StaffType' attribute! Set it to e.g. 'StarterStaffArtificer'")
end

-- Equip: Play hold animation
tool.Equipped:Connect(function()
	holdTrack:Play()
end)

-- Unequip: Stop hold animation
tool.Unequipped:Connect(function()
	holdTrack:Stop()
end)

-- Activate: Fire on click (with debounce & anim)
tool.Activated:Connect(function()
	if not debounce then
		return
	end
	debounce = false

	local mouse: Mouse = player:GetMouse()
	local mouseHit: CFrame = mouse.Hit

	if not fireTrack.IsPlaying and canPlayAnim then
		player:SetAttribute("Firing", true)
		canPlayAnim = false
		holdTrack:Stop()
		fireTrack:Play()
		task.wait(0.3)  -- Sync with fire anim (adjust if needed per staff)
		fireRemote:FireServer(mouseHit.Position, staffType)
		holdTrack:Play()
	end

	task.wait(1)  -- Cooldown
	player:SetAttribute("Firing", false)
	debounce = true
end)

-- Deactivate: Allow re-interrupt
tool.Deactivated:Connect(function()
	canPlayAnim = true
end)