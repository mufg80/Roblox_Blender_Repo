--!strict

local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local magicGui = playerGui:WaitForChild("MagicGui")
local castFrame = magicGui:WaitForChild("CastFrame")
local innerFill = castFrame:WaitForChild("InnerFill")

export type CastFeedbackMod = {
	StartCast:(duration: number, castColorhex:string, onComplete: () -> ()) -> (),
	IsOnCooldown:() -> boolean,
	Init:() -> (),
}

local CastFeedback = {}
local isCasting = false

-- Start cast bar animation
function CastFeedback.StartCast(duration: number, castColorhex:string, onComplete: () -> ()) : ()
	if isCasting then return end
	isCasting = true

	castFrame.Visible = true
	-- FIXED: Convert hex string to Color3
	innerFill.BackgroundColor3 = Color3.fromHex(castColorhex or "#FFFFFF")

	local startTime = time()

	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = time() - startTime
		local fraction = math.clamp(elapsed / duration, 0, 1)
		innerFill.Size = UDim2.new(fraction, 0, 1, 0)

		if elapsed >= duration or (player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health <= 1) then
			if connection then
				connection:Disconnect()
			end
			castFrame.Visible = false
			isCasting = false
			onComplete()
		end
	end)
end

function CastFeedback.IsOnCooldown(): boolean
	return isCasting
end

function CastFeedback.Init():()
	--print("Castfeedbackstarting")
end


return CastFeedback :: CastFeedbackMod