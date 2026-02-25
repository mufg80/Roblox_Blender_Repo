--!strict
-- LocalScript inside the Staff Tool
-- Calls animMod functions instead of managing AnimationTracks directly

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local statsMod = require(ReplicatedStorage.Shared.statsMod)
local animMod = require(ReplicatedStorage.Shared.animMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)

local tool: Tool = script.Parent
local player: Player = Players.LocalPlayer
local character: Model = player.Character or player.CharacterAdded:Wait()
local humanoidInst: Instance? = character:WaitForChild("Humanoid")
local humanoid = nil
if humanoidInst and humanoidInst:IsA("Humanoid") then
	humanoid = humanoidInst
end
local camera = workspace.CurrentCamera
local staffType = tool:GetAttribute("StaffType")

local stats = nil
local staffCooldown = nil
if staffType and typeof(staffType) == "string" and statsMod.StaffStats[staffType] then
	stats = statsMod.StaffStats[staffType]
	staffCooldown = stats.CoolDown
end

local playerGui = player:WaitForChild("PlayerGui")
local magicGui = playerGui:WaitForChild("MagicGui")
local castFrame = magicGui:WaitForChild("CastFrame")

local crosshairGui = playerGui:WaitForChild("CrossHairGui")
local isCrosshairsVisible: boolean = UserInputService.GamepadEnabled

local verticalOffset = -100
local horizontalOffset = 100

-- Single shared RemoteEvent for all staffs
local REMOTE_NAME = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	or (function()
		local ev = Instance.new("RemoteEvent")
		ev.Name = REMOTE_NAME
		ev.Parent = ReplicatedStorage
		return ev
	end)()

if not staffType or staffType == "" then
	warn("Tool", tool.Name, "missing 'StaffType' attribute!")
end

local function updateCrosshairVisibility(equipped: boolean)
	local label = crosshairGui:FindFirstChild("ImageLabel")
	if label and label:IsA("ImageLabel") and crosshairGui:IsA("ScreenGui") then
		label.Position = UDim2.new(0.5, horizontalOffset, 0.5, verticalOffset)
		crosshairGui.Enabled = (isCrosshairsVisible and equipped)
	end
end

-- Gamepad crosshair visibility
UserInputService.GamepadConnected:Connect(function()
	isCrosshairsVisible = true
	updateCrosshairVisibility(tool.Parent == character)
end)

UserInputService.GamepadDisconnected:Connect(function()
	isCrosshairsVisible = false
	updateCrosshairVisibility(false)
end)

-- Initial state
player:SetAttribute("Firing", false)

local debounce = true

local function GetAimPosition(maxDistance: number): Vector3
	maxDistance = maxDistance or 1000

	local rayOrigin: Vector3
	local rayDirection: Vector3

	if UserInputService.GamepadEnabled then
		local viewport = camera.ViewportSize
		local screenCenter = Vector2.new(viewport.X / 2 + horizontalOffset, viewport.Y / 2 + verticalOffset)
		local unitRay = camera:ScreenPointToRay(screenCenter.X, screenCenter.Y)
		rayOrigin = unitRay.Origin
		rayDirection = unitRay.Direction
	else
		local mouse = player:GetMouse()
		local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
		rayOrigin = unitRay.Origin
		rayDirection = unitRay.Direction
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDirection * maxDistance, rayParams)

	return if result then result.Position else rayOrigin + rayDirection * maxDistance
end

-- ──────────────────────────────────────────────────────────────
-- Equip / Unequip
-- ──────────────────────────────────────────────────────────────

tool.Equipped:Connect(function()
	updateCrosshairVisibility(true)
	animMod.ActivateHold(humanoid)
end)

tool.Unequipped:Connect(function()
	updateCrosshairVisibility(false)
	animMod.DeactivateHold(humanoid)
end)

-- ──────────────────────────────────────────────────────────────
-- Fire (Activated)
-- ──────────────────────────────────────────────────────────────

tool.Activated:Connect(function()
	if utilMod.GetAttribute(player, "HasFallen") then
		return
	end
	if not debounce then
		return
	end
	if castFrame and castFrame:IsA("Frame")then
		if castFrame.Visible == true then
			return
		end
		
	end

	debounce = false
	player:SetAttribute("Firing", true)

	local targetPosition = GetAimPosition(1000)

	-- Play fire animation (will stop hold automatically inside animMod)
	animMod.ActivateFire(humanoid)

	-- Wait a bit to sync with animation wind-up
	task.wait(0.3)

	-- Fire the actual projectile / effect via server
	fireRemote:FireServer(targetPosition, staffType)

	-- After fire animation finishes → automatically resumes hold via animMod
	-- But we still wait the full cooldown before allowing next fire
	task.wait(staffCooldown)

	player:SetAttribute("Firing", false)
	debounce = true
end)

-- Optional: if you want to allow interrupting the fire animation early
tool.Deactivated:Connect(function()
	-- You can choose whether to allow early stop or not.
	-- Most staff games let the animation finish once started.
	-- If you want to support interrupt:
	-- animMod.DeactivateFire(humanoid)
	-- player:SetAttribute("Firing", false)
	-- debounce = true
end)

-- Cleanup
tool.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		animMod.DeactivateHold(humanoid)
		updateCrosshairVisibility(false)
	end
end)
