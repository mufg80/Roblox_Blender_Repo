-- --!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local staffTable: { [string]: any } = statsMod.StaffStats

local tool: Tool = script.Parent
local muzzle: BasePart = tool:WaitForChild("BulletStartPosition") :: BasePart

local staffType: string? = tool:GetAttribute("StaffType")
if not staffType or staffType == "" then
	warn("Tool", tool.Name, "missing 'StaffType' attribute!")
	return
end

local stats: any = staffTable[staffType]
if not stats then
	warn("No stats found for StaffType:", staffType, "in staffTable!")
	return
end

local maxRange: number = stats.maxRange
local bulletSpeed: number = stats.bulletSpeed
local arcHeight: number = stats.arcHeight
local bulletTemplateName: string = stats.BulletTemplate or tool:GetAttribute("BulletTemplate") or "StarterStaffBullet"
local trailChildName: string = stats.TrailChildName or tool:GetAttribute("TrailChildName") or "StarterStaffTrail"

-- Single shared RemoteEvent
local REMOTE_NAME: string = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not fireRemote then
	fireRemote = Instance.new("RemoteEvent")
	fireRemote.Name = REMOTE_NAME
	fireRemote.Parent = ReplicatedStorage
end

local function fireBullet(player: Player, targetPos: Vector3): ()
	-- SECURITY: Verify tool is equipped by this player
	local character: Model? = player.Character
	if not character or character ~= tool.Parent then
		return -- Not equipped / wrong player
	end

	local bulletTemplate: BasePart | Model? = ServerStorage.Parts:FindFirstChild(bulletTemplateName)
	if not bulletTemplate then
		warn(bulletTemplateName, "not found in ServerStorage")
		return
	end

	-- CLONE FIRST, then customize (fixes shared template bug!)
	local bullet: Instance = bulletTemplate:Clone()
	bullet:SetAttribute("Owner", player.Name)
	bullet.Position = muzzle.Position + Vector3.new(0, 1, 0)
	bullet.Parent = workspace


	-- Trajectory calc
	local startPos: Vector3 = bullet.Position
	local direction: Vector3 = (targetPos - startPos).Unit
	local distance: number = math.min((targetPos - startPos).Magnitude, maxRange)
	local duration: number = distance / bulletSpeed + 0.05 -- slight buffer
	local startTime: number = time()

	-- Custom trail color ON CLONED BULLET (bug fix!)
	local trail: Trail? = bullet:FindFirstChild(trailChildName)
	if trail and trail:IsA("Trail") then
		local color: Color3 = utilMod.HexToColor3(stats.bulletTrail)
		trail.Color = ColorSequence.new(color)
	else
		warn("No trail named", trailChildName, "in bullet")
	end

	-- Hit detection & damage
	local touchConn: RBXScriptConnection?
	touchConn = bullet.Touched:Connect(function(hit: BasePart)
		-- Explosion FX
		local color: Color3 = utilMod.HexToColor3(stats.bulletTrail)
		utilMod.createCustomExplosion(bullet.Position, stats.visualSize, stats.visualTime, color)

		if hit == muzzle or hit:IsDescendantOf(tool) then
			return
		end

		local ownerName: string? = bullet:GetAttribute("Owner")
		local ownerPlayer: Player? = ownerName and game.Players:FindFirstChild(ownerName)
		if not ownerPlayer then
			return
		end

		local success: boolean = combatMod.ApplyStaffDamage(hit, ownerPlayer, staffType)

		-- Cleanup
		bullet:Destroy()
		if touchConn then
			touchConn:Disconnect()
		end
	end)

	-- Parabolic movement
	local moveConn: RBXScriptConnection?
	moveConn = RunService.Heartbeat:Connect(function()
		local elapsed: number = time() - startTime
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

		local t: number = elapsed / duration
		local progress: number = t * distance
		local pos: Vector3 = startPos + direction * progress
		local height: number = arcHeight * 4 * t * (1 - t) -- Smooth parabola peak

		bullet.Position = pos + Vector3.new(0, height, 0)
		bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
	end)
end

-- Handle incoming fires (with StaffType verification)
fireRemote.OnServerEvent:Connect(function(player: Player, targetPos: Vector3, receivedType: string)
	if utilMod.GetAttribute(player, "HasFallen") then
		return
	end
	if typeof(targetPos) ~= "Vector3" or receivedType ~= staffType then
		return -- Invalid / spoofed
	end
	fireBullet(player, targetPos)
end)