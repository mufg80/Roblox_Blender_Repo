-- hi testing
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local db = true

local hum = char:FindFirstChild("Humanoid")
local animator = hum:WaitForChild("Animator")
local fireAnim = Instance.new("Animation")
fireAnim.AnimationId = tool.StarterStaffAnimation.AnimationId

local holdStaffAnim = Instance.new("Animation")
holdStaffAnim.AnimationId = tool.StarterStaffHoldAnimation.AnimationId

local animTrack = animator:LoadAnimation(fireAnim)
animTrack.Looped = false
local canPlay = true

local holdAnimTrack = animator:LoadAnimation(holdStaffAnim)
holdAnimTrack.Looped = true

-- Create RemoteEvent if it doesn't exist
local fireEvent = ReplicatedStorage:FindFirstChild("FireStarterStaff")
if not fireEvent then
	fireEvent = Instance.new("RemoteEvent")
	fireEvent.Name = "FireStarterStaff"
	fireEvent.Parent = ReplicatedStorage
end



-- Equip tool
tool.Equipped:Connect(function()
	holdAnimTrack:Play()
end)

-- Unequip tool
tool.Unequipped:Connect(function()
	holdAnimTrack:Stop()
end)

-- Activate tool (on mouse click)
tool.Activated:Connect(function()
	if db then
		db = false
		local mouse = player:GetMouse()
		local mouseHit = mouse.Hit
		

		if not animTrack.IsPlaying and canPlay then
			canPlay = false
			holdAnimTrack:Stop()	

			animTrack:Play()
			task.wait(.3)
			fireEvent:FireServer(mouseHit.Position)
			holdAnimTrack:Play()
		end
		task.wait(1)
		db = true
	end
	
	
end)

-- Deactivate tool (optional, for when the tool is no longer held)
tool.Deactivated:Connect(function()
	canPlay = true
end)