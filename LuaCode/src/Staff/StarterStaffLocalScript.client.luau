--!strict

-- UNIFIED CLIENT SCRIPT (LocalScript inside each staff tool)
-- Place this exact script as a LocalScript child of the Tool.
-- Differences are driven by tool children (animations) + StaffType attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local debounce = true

local humanoid = character:FindFirstChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

-- Load animations from tool's child Animation objects (different IDs per staff)
local fireAnimObj = tool:WaitForChild("StarterStaffAnimation")
local holdAnimObj = tool:WaitForChild("StarterStaffHoldAnimation")

local fireAnim = Instance.new("Animation")
fireAnim.AnimationId = fireAnimObj.AnimationId
local holdAnim = Instance.new("Animation")
holdAnim.AnimationId = holdAnimObj.AnimationId

local fireTrack = animator:LoadAnimation(fireAnim)
fireTrack.Looped = false
local canPlayAnim = true

local holdTrack = animator:LoadAnimation(holdAnim)
holdTrack.Looped = true

-- Single shared RemoteEvent for ALL staffs
local REMOTE_NAME = "FireStaff"
local fireRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not fireRemote then
    fireRemote = Instance.new("RemoteEvent")
    fireRemote.Name = REMOTE_NAME
    fireRemote.Parent = ReplicatedStorage
end

local staffType = tool:GetAttribute("StaffType")
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
    if debounce then
        debounce = false
        local mouse = player:GetMouse()
        local mouseHit = mouse.Hit

        if not fireTrack.IsPlaying and canPlayAnim then
            canPlayAnim = false
            holdTrack:Stop()
            fireTrack:Play()
            task.wait(0.3)  -- Sync with fire anim (adjust if needed per staff)
            fireRemote:FireServer(mouseHit.Position, staffType)
            holdTrack:Play()
        end
        task.wait(1)  -- Cooldown
        debounce = true
    end
end)

-- Deactivate: Allow re-interrupt
tool.Deactivated:Connect(function()
    canPlayAnim = true
end)