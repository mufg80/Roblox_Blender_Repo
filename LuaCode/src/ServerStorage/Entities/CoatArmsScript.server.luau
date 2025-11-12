local model = script.Parent
local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
local height = hrp.Position.Y
local runservice = game:GetService("RunService")
print(height)
-- create local function named spawn
local function localspawn()
	if hrp then
		hrp.Anchored = false
		local currentY = hrp.CFrame.Y
		if currentY ~= height then
			hrp.CFrame = hrp.CFrame + Vector3.new(0, height - currentY, 0)
		end
		
		runservice.Heartbeat:Wait()
		task.wait(0.05)
		hrp.Anchored = true
	end
end
localspawn()
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
			-- call localspawn function
			localspawn()
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


