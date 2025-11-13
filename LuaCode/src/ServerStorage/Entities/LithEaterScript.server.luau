local model = script.Parent
local humanoid = model:FindFirstChildOfClass("Humanoid")
local height = game:GetService("ServerStorage"):FindFirstChild("Entities"):FindFirstChild("LithEater"):FindFirstChild("HumanoidRootPart").Position.Y
local utilMod = require(game:GetService("ReplicatedStorage").Shared.Util)
local hrp = model:FindFirstChild("HumanoidRootPart")
local runservice = game:GetService("RunService")
print( "LithEater height ", height )
runservice.Heartbeat:Connect(function()
	local hrploc = utilMod.DistancetoGround(hrp.Position.X, hrp.Position.Z, {model}, height)
	if hrploc then
		local movement = hrp.Position.Y - hrploc
		
		hrp.CFrame = hrp.CFrame - Vector3.new(0, movement, 0)
	end
end)


if humanoid then
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		-- Gather all Animation children of the model
		local animations = {}
		for _, child in model:GetChildren() do
			if child:IsA("Animation") then
				table.insert(animations, child)
			end
		end

		-- Loop through all animations in sequence, repeat forever
		while true do
			for _, anim in animations do
				local track = animator:LoadAnimation(anim)
				track.Looped = false
				track:Play()
				-- Wait for animation length, or 3 seconds if not available
				local length = track.Length
				if length == 0 then
					length = 5
				end
				task.wait(length)
				track:Stop()
			end
		end
	end
end


