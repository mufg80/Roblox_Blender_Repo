--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local statsMod = require(ReplicatedStorage.Shared.statsMod)
local castFeedback = require(ReplicatedStorage.Client.CastFeedback)
local camera = workspace.CurrentCamera
local tool: Tool = script.Parent
local player: Player = Players.LocalPlayer
local character: Model = player.Character or player.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid")
local animator: Animator = humanoid:WaitForChild("Animator")
local staffType = tool:GetAttribute("StaffType")
local stats = statsMod.StaffStats[staffType] or {}
local staffCooldown = stats.coolDown or 1.0 -- fallback 1 second

local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local crosshairGui = player.PlayerGui:WaitForChild("CrossHairGui")
local isCrosshairsVisible: boolean = false
local verticalOffset = -100
local horizontalOffset = 100

local function updateVisibility(equipped: boolean)
	local position = UDim2.new(0.5, horizontalOffset, 0.5, verticalOffset)
	local label = crosshairGui:FindFirstChild("ImageLabel")
	label.Position = position
	if isCrosshairsVisible and equipped then
		crosshairGui.Enabled = true
	else
		crosshairGui.Enabled = false
	end
end

UserInputService.GamepadConnected:Connect(function()
	isCrosshairsVisible = true
end)
UserInputService.GamepadDisconnected:Connect(function()
	isCrosshairsVisible = false
end)

isCrosshairsVisible = UserInputService.GamepadEnabled

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
	updateVisibility(true)
	holdTrack:Play()
end)

-- Unequip: Stop hold animation
tool.Unequipped:Connect(function()
	updateVisibility(false)
	holdTrack:Stop()
end)

local function GetAimPosition(maxDistance: number): Vector3
	maxDistance = maxDistance or 1000

	local rayOrigin: Vector3
	local rayDirection: Vector3

	if UserInputService.GamepadEnabled then
		-- 🎮 Center screen ray
		local viewport = camera.ViewportSize
		local screenCenter = Vector2.new(viewport.X / 2 + horizontalOffset, viewport.Y / 2 + verticalOffset)
		local unitRay = camera:ScreenPointToRay(screenCenter.X, screenCenter.Y)

		rayOrigin = unitRay.Origin
		rayDirection = unitRay.Direction
	else
		-- 🖱 Mouse ray
		local mouse: Mouse = player:GetMouse()
		local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

		rayOrigin = unitRay.Origin
		rayDirection = unitRay.Direction
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDirection * maxDistance, rayParams)

	if result then
		return result.Position
	else
		return rayOrigin + rayDirection * maxDistance
	end
end

-- Activate: Fire on click (with debounce & anim)
tool.Activated:Connect(function()
	if not debounce then
		return
	end
	debounce = false

	local targetPosition = GetAimPosition(1000)

	if not fireTrack.IsPlaying and canPlayAnim then
		player:SetAttribute("Firing", true)
		canPlayAnim = false
		holdTrack:Stop()
		fireTrack:Play()

		fireTrack.Stopped:Connect(function()
			tool:Deactivate()
		end)

		task.wait(0.3) -- Sync with fire anim

		-- local color = statsMod.Colors[stats.magicType]
		-- castFeedback.StartCast(staffCooldown, color, function()
		-- 	debounce = true
		-- end)

		fireRemote:FireServer(targetPosition, staffType)

		holdTrack:Play()
	end

	task.wait(staffCooldown) -- Cooldown
	print(staffCooldown)
	player:SetAttribute("Firing", false)
	debounce = true
end)

-- Deactivate: Allow re-interrupt
tool.Deactivated:Connect(function()
	canPlayAnim = true
end)

tool.AncestryChanged:Connect(function()
	-- Cleanup on tool removal
	holdTrack:Stop()
	fireTrack:Stop()
	updateVisibility(false)
end)
