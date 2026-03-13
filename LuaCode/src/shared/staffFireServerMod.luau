--!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local staffFireServerMod = {}

local staffTable = statsMod.StaffStats

-- ────────────────────────────────────────────────
-- Central bullet manager (the table you wanted)
-- ────────────────────────────────────────────────
local bulletTable: { BulletData } = {}

type BulletData = {
	OwnerUserId: number,
	StaffType: string,
	StartTime: number,
	StartPos: Vector3,
	Direction: Vector3,
	Distance: number,
	Duration: number,
	BulletModel: Model?,
	LastPos: Vector3,
	PetsFilter: { Model },
}

-- ────────────────────────────────────────────────
-- Single heartbeat that processes ALL bullets
-- ────────────────────────────────────────────────
local function startBulletHeartbeat()

	RunService.Heartbeat:Connect(function(_deltaTime: number)
		for i = #bulletTable, 1, -1 do
			local b = bulletTable[i]
			local now = time()

			-- Early cleanup if model is gone
			if not b.BulletModel or not b.BulletModel.Parent or not b.BulletModel.PrimaryPart then
				if b.BulletModel then
					b.BulletModel:Destroy()
				end
				table.remove(bulletTable, i)
				continue
			end

			local elapsed = now - b.StartTime
			if elapsed - 0.5 >= b.Duration then
				b.BulletModel:Destroy()
				table.remove(bulletTable, i)
				continue
			end

			local t = elapsed / b.Duration
			local progress = t * b.Distance
			local height = staffTable[b.StaffType].arcHeight * 4 * t * (1 - t)
			local targetPos = b.StartPos + b.Direction * progress
			local newPos = targetPos + Vector3.new(0, height, 0)

			local delta = newPos - b.LastPos

			-- Very small movement → cheap update only
			if delta.Magnitude < 0.01 then
				local moveDir = (newPos - b.StartPos).Unit
				b.BulletModel:PivotTo(CFrame.lookAt(newPos, newPos + moveDir))
				b.LastPos = newPos
				continue
			end

			-- Raycast setup
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local filter = { b.BulletModel } :: { any }
			for _, pet in b.PetsFilter do
				table.insert(filter, pet)
			end
			if workspace:FindFirstChild("Effects") then
				table.insert(filter, workspace.Effects)
			end
			rayParams.FilterDescendantsInstances = filter

			local backOffsetVec = delta.Unit * -0.15
			local rayLength = delta + backOffsetVec * -2 -- note: negative direction for safety

			local rayResult = workspace:Raycast(b.LastPos + backOffsetVec, rayLength, rayParams)

			if rayResult then
				local hitPos = rayResult.Position
				utilMod.createCustomExplosion(hitPos, staffTable[b.StaffType].Explosion)

				local owner = Players:GetPlayerByUserId(b.OwnerUserId)
				if owner then
					combatMod.ApplyStaffDamage(rayResult.Instance :: BasePart, owner, b.StaffType)
				end

				b.BulletModel:Destroy()
				table.remove(bulletTable, i)
				continue
			end

			-- Normal movement
			local moveDir = delta.Unit
			b.BulletModel:PivotTo(CFrame.lookAt(newPos, newPos + moveDir))
			b.LastPos = newPos
		end
	end)
end

-- Start the loop once (you can call this when the script starts)
startBulletHeartbeat()

-- ────────────────────────────────────────────────
-- Fire function – now just creates data + model and adds to table
-- ────────────────────────────────────────────────
local function fireBullet(player: Player, targetPos: Vector3, staffType: string)
	if typeof(targetPos) ~= "Vector3" or typeof(staffType) ~= "string" then
		return
	end

	local stats = staffTable[staffType]
	if not stats then
		warn("No stats for staff:", staffType)
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool or tool:GetAttribute("StaffType") ~= staffType then
		return -- exploit attempt / wrong tool
	end

	local muzzle = tool:FindFirstChild("BulletStartPosition") :: BasePart?
	if not muzzle or not muzzle:IsA("BasePart") then
		warn("Missing BulletStartPosition in", tool.Name)
		return
	end

	local bulletTemplateName = stats.BulletTemplate or "StarterStaffBullet"
	local template = ServerStorage.Parts:FindFirstChild(bulletTemplateName) :: Model?
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Invalid/missing bullet template:", bulletTemplateName)
		return
	end

	-- Clone bullet
	local bullet = template:Clone() :: Model
	bullet:SetAttribute("Owner", player.UserId)
	if not bullet or not bullet.PrimaryPart then return end
	bullet.PrimaryPart:PivotTo(CFrame.new(muzzle.Position + Vector3.new(0, 1, 0)))
	bullet.Parent = workspace

	-- Customize trail color
	local bulletBase = bullet:FindFirstChild("BulletPart") :: BasePart?
	if bulletBase then
		local trail = bulletBase:FindFirstChild("StarterStaffTrail") :: Trail?
		if trail and trail:IsA("Trail") then
			local color = utilMod.HexToColor3(stats.bulletTrail)
			trail.Color = ColorSequence.new(color)
		end
	end

	-- Prepare bullet data
	local startPos = bullet.PrimaryPart.Position
	local direction = (targetPos - startPos).Unit
	local fullDistance = (targetPos - startPos).Magnitude
	local distance = math.min(fullDistance, stats.maxRange)
	local duration = distance / stats.bulletSpeed

	local pets = utilMod.MyPets(character) or {}

	local bulletData: BulletData = {
		OwnerUserId = player.UserId,
		StaffType = staffType,
		StartTime = time(),
		StartPos = startPos,
		Direction = direction,
		Distance = distance,
		Duration = duration,
		BulletModel = bullet,
		LastPos = startPos,
		PetsFilter = pets,
	}

	table.insert(bulletTable, bulletData)
end

-- Remote listener
local REMOTE_NAME = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage.Events:WaitForChild(REMOTE_NAME) :: RemoteEvent

fireRemote.OnServerEvent:Connect(function(player: Player, targetPos: Vector3, staffType: string)
	if utilMod.GetAttribute(player, "HasFallen") then
		return
	end
	fireBullet(player, targetPos, staffType)
end)

return staffFireServerMod
