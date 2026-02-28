--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local messageGui = playerGui:WaitForChild("MessageGui")
local messageEvent = ReplicatedStorage.Events:WaitForChild("MessageEvent")

local FADE_IN_SPEED = 0.5 -- seconds to fully fade in (adjust as needed)
local FADE_OUT_SPEED = 0.5 -- seconds to fully fade out
local DEFAULT_DURATION = 3 -- fallback hold duration

local frame = messageGui:WaitForChild("Frame")
local messageLabel = frame:WaitForChild("MessageLabel")

-- Queue: FIFO array of {message: string, duration: number?}
type QueuedMessage = { message: string, duration: number? }
local queue: { QueuedMessage } = {}
local isPlaying = false

local currentTween: Tween?

local function playNext()
	if #queue == 0 then
		isPlaying = false
		return
	end

	isPlaying = true
	local queued: QueuedMessage? = table.remove(queue, 1) -- Dequeue first
	if not queued then
		return
	end
	local duration = queued.duration or DEFAULT_DURATION

	-- Cancel any existing tween
	if currentTween then
		currentTween:Cancel()
	end

	-- Reset & setup
	messageLabel.Text = queued.message
	messageLabel.TextTransparency = 1
	frame.Visible = true
	messageLabel.Visible = true

	-- Fade in
	local tweenIn = TweenService:Create(
		messageLabel,
		TweenInfo.new(FADE_IN_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)
	tweenIn:Play()

	-- Schedule fade out after fade-in + duration
	task.delay(FADE_IN_SPEED + duration, function()
		local tweenOut = TweenService:Create(
			messageLabel,
			TweenInfo.new(FADE_OUT_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)
		currentTween = tweenOut

		tweenOut.Completed:Connect(function()
			frame.Visible = false
			messageLabel.Visible = false
			currentTween = nil
			-- Chain to next
			task.wait()
			playNext()
		end)

		tweenOut:Play()
	end)
end

local function showMessage(message: string, duration: number?)
	table.insert(queue, { message = message, duration = duration })
	if not isPlaying then
		playNext()
	end
end

-- Remote event listener
messageEvent.OnClientEvent:Connect(function(message: string, duration: number?)
	showMessage(message, duration)
end)

export type MessageMod = {
	ShowMessage: (message: string, duration: number?) -> (),
	ClearQueue: () -> (),
	GetQueueSize: () -> number,
	Init: () -> (),
}

-- Module export
local messageMod = {
	ShowMessage = showMessage,
	-- Optional: Clear queue
	ClearQueue = function()
		queue = {}
		isPlaying = false
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
		frame.Visible = false
		messageLabel.Visible = false
		messageLabel.TextTransparency = 1
	end,
	-- Optional: Get queue size for debugging
	GetQueueSize = function(): number
		return #queue
	end,
}
function messageMod.Init(): ()
	--print("MessageModInitialized")
end

return messageMod :: MessageMod
