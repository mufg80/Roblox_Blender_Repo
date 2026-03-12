--!strict


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local statsMod = require(ReplicatedStorage.Shared.statsMod)
local animMod = require(ReplicatedStorage.Shared.animMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)

local player = Players.LocalPlayer

local staffFireMod = {}

-- Shared RemoteEvent for every staff
local REMOTE_NAME = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	or (function()
		local ev = Instance.new("RemoteEvent")
		ev.Name = REMOTE_NAME
		ev.Parent = ReplicatedStorage
		return ev
	end)()

-- GUI references (shared)
local playerGui = player:WaitForChild("PlayerGui")
local magicGui = playerGui:WaitForChild("MagicGui")
local castFrame = magicGui:WaitForChild("CastFrame")
local crosshairGui = playerGui:WaitForChild("CrossHairGui")

local verticalOffset = -100
local horizontalOffset = 100
local isCrosshairsVisible: boolean = UserInputService.GamepadEnabled
local currentEquippedTool: Tool? = nil   -- used for gamepad crosshair updates

local function updateCrosshairVisibility(equipped: boolean)
	local label = crosshairGui:FindFirstChild("ImageLabel")
	if label and label:IsA("ImageLabel") then
		label.Position = UDim2.new(0.5, horizontalOffset, 0.5, verticalOffset)
		crosshairGui.Enabled = (isCrosshairsVisible and equipped)
	end
end

-- Gamepad crosshair handling
UserInputService.GamepadConnected:Connect(function()
	isCrosshairsVisible = true
	if currentEquippedTool then
		updateCrosshairVisibility(true)
	end
end)

UserInputService.GamepadDisconnected:Connect(function()
	isCrosshairsVisible = false
	updateCrosshairVisibility(false)
end)

-- Exact same aim function you already had
local function GetAimPosition(maxDistance: number): Vector3
	maxDistance = maxDistance or 1000

	local camera = workspace.CurrentCamera
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
	rayParams.FilterDescendantsInstances = { player.Character or {} }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDirection * maxDistance, rayParams)
	return if result then result.Position else rayOrigin + rayDirection * maxDistance
end

-- ──────────────────────────────────────────────────────────────
-- PER-TOOL SETUP (this is the "module" part — called for every staff)
-- ──────────────────────────────────────────────────────────────
local function setupTool(tool: Tool)
	local staffType = tool:GetAttribute("StaffType")
	if not staffType or typeof(staffType) ~= "string" then
		warn("Tool", tool.Name, "missing 'StaffType' attribute!")
		return
	end

	local stats = statsMod.StaffStats[staffType]
	local staffCooldown = stats and stats.coolDown or 1

	local debounce = true

	-- Equip / Unequip
	tool.Equipped:Connect(function()
		currentEquippedTool = tool
		updateCrosshairVisibility(true)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			animMod.ActivateHold(humanoid)
		end
	end)

	tool.Unequipped:Connect(function()
		currentEquippedTool = nil
		updateCrosshairVisibility(false)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			animMod.DeactivateHold(humanoid)
		end
	end)

	-- Fire logic (exactly your original Activated code)
	tool.Activated:Connect(function()
		if utilMod.GetAttribute(player, "HasFallen") then return end
		if not debounce then return end
		if castFrame and castFrame:IsA("Frame") and castFrame.Visible then return end

		debounce = false
		player:SetAttribute("Firing", true)

		local targetPosition = GetAimPosition(1000)

		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			animMod.ActivateFire(humanoid)
		end

		task.wait(0.3)

		fireRemote:FireServer(targetPosition, staffType)

		task.wait(staffCooldown)

		player:SetAttribute("Firing", false)
		debounce = true
	end)

	-- Optional interrupt support
	tool.Deactivated:Connect(function()
		-- Uncomment if you want early interrupt:
		-- local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		-- if humanoid then animMod.DeactivateFire(humanoid) end
	end)

	-- Cleanup when tool is removed from game
	tool.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			updateCrosshairVisibility(false)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				animMod.DeactivateHold(humanoid)
			end
		end
	end)
end

-- ──────────────────────────────────────────────────────────────
-- AUTO-ATTACH TO ANY TOOL THAT HAS StaffType ATTRIBUTE
-- ──────────────────────────────────────────────────────────────
local function setupExistingTools(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			setupTool(child)
		end
	end
end

-- Backpack
player.Backpack.ChildAdded:Connect(setupTool)
setupExistingTools(player.Backpack)

-- Character (and respawns)
player.CharacterAdded:Connect(function(character: Model)
	setupExistingTools(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			setupTool(child)
		end
	end)
end)

if player.Character then
	setupExistingTools(player.Character)
end

-- Final init
player:SetAttribute("Firing", false)

return staffFireMod