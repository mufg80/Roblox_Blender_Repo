-- UNIFIED SERVER SCRIPT (Script inside each staff tool)
-- Place this exact script as a Script child of the Tool.
-- Handles bullet spawning, damage, & arc based on StaffType stats.
-- FIXES ORIGINAL BUG: Trail color now set on CLONED bullet (not shared template).
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local staffTable = statsMod.StaffStats
local tool = script.Parent
local muzzle = tool:WaitForChild("BulletStartPosition") -- "BulletStartPosition" part

local staffType = tool:GetAttribute("StaffType")
if not staffType or staffType == "" then
	warn("Tool", tool.Name, "missing 'StaffType' attribute!")
	return
end

local stats = staffTable[staffType]
if not stats then
	warn("No stats found for StaffType:", staffType, "in staffTable!")
	return
end

local maxRange = stats.maxRange
local bulletSpeed = stats.bulletSpeed
local arcHeight = stats.arcHeight
local bulletTemplateName = stats.BulletTemplate or tool:GetAttribute("BulletTemplate") or "StarterStaffBullet"
local trailChildName = stats.TrailChildName or tool:GetAttribute("TrailChildName") or "StarterStaffTrail" -- Flexible if differs

-- Set muzzle collision group
if muzzle:IsA("BasePart") then
	muzzle.CollisionGroup = "Weapon"
else
	warn("BulletStartPosition is not a BasePart in", tool.Name)
end

-- Single shared RemoteEvent
local REMOTE_NAME = "FireStaff"
local fireRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not fireRemote then
	fireRemote = Instance.new("RemoteEvent")
	fireRemote.Name = REMOTE_NAME
	fireRemote.Parent = ReplicatedStorage
end

local function fireBullet(player, targetPos)
	-- SECURITY: Verify tool is equipped by this player
	local character = player.Character
	if not character or character ~= tool.Parent then
		return -- Not equipped / wrong player
	end

	local bulletTemplate = ServerStorage:FindFirstChild(bulletTemplateName)
	if not bulletTemplate then
		warn(bulletTemplateName, "not found in ServerStorage")
		return
	end

	-- CLONE FIRST, then customize (fixes shared template bug!)
	local bullet = bulletTemplate:Clone()
	bullet:SetAttribute("Owner", player.Name)
	bullet.Position = muzzle.Position + Vector3.new(0, 0.5, 0)
	bullet.Parent = workspace

	-- Set Bullet collision group (handles Part or Model w/ PrimaryPart)
	local function setBulletCollision(obj)
		if obj:IsA("BasePart") then
			obj.CollisionGroup = "Bullet"
		end
	end
	if bullet:IsA("BasePart") then
		setBulletCollision(bullet)
	elseif bullet.PrimaryPart then
		setBulletCollision(bullet.PrimaryPart)
		for _, descendant in bullet:GetDescendants() do
			setBulletCollision(descendant)
		end
	end

	-- Owner immunity: Set player parts to "Player" group (run per shot)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part:IsDescendantOf(tool) then
			part.CollisionGroup = "Player"
		end
	end

	-- Trajectory calc
	local startPos = bullet.Position
	local direction = (targetPos - startPos).Unit
	local distance = math.min((targetPos - startPos).Magnitude, maxRange)
	local duration = distance / bulletSpeed + 0.05 -- slight buffer
	local startTime = tick()

	-- Custom trail color ON CLONED BULLET (bug fix!)
	local trail = bullet:FindFirstChild(trailChildName)
	if trail and trail:IsA("Trail") then
		local color = utilMod.HexToColor3(stats.bulletTrail)
		trail.Color = ColorSequence.new(color)
	else
		warn("No trail named", trailChildName, "in bullet")
	end

	-- Hit detection & damage
	local touchConn
	touchConn = bullet.Touched:Connect(function(hit)
		-- Explosion FX
		local color = utilMod.HexToColor3(stats.bulletTrail)
		utilMod.createCustomExplosion(bullet.Position, stats.visualSize, stats.visualTime, color)

		if hit == muzzle or hit:IsDescendantOf(tool) then
			return
		end

		local ownerName = bullet:GetAttribute("Owner")
		local ownerPlayer = ownerName and game.Players:FindFirstChild(ownerName)
		if not ownerPlayer then
			return
		end

		local success = combatMod.ApplyStaffDamage(hit, ownerPlayer, staffType)

		
		-- Cleanup
		bullet:Destroy()
		if touchConn then
			touchConn:Disconnect()
		end
	end)

	-- Parabolic movement
	local moveConn
	moveConn = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration or not bullet.Parent then
			if bullet.Parent then
				bullet:Destroy()
			end
			if moveConn then
				moveConn:Disconnect()
			end
			if touchConn then
				touchConn:Disconnect()
			end
			return
		end

		local t = elapsed / duration
		local progress = t * distance
		local pos = startPos + direction * progress
		local height = arcHeight * 4 * t * (1 - t) -- Smooth parabola peak

		bullet.Position = pos + Vector3.new(0, height, 0)
		bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
	end)
end

-- Handle incoming fires (with StaffType verification)
fireRemote.OnServerEvent:Connect(function(player, targetPos, receivedType)
	if typeof(targetPos) ~= "Vector3" or receivedType ~= staffType then
		return -- Invalid / spoofed
	end
	fireBullet(player, targetPos)
end)
