--!strict
-- Centralized server handler for ALL staffs — no scripts inside tools anymore

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local staffFireServerMod = {}

local staffTable = statsMod.StaffStats -- { [staffType] = stats }

-- Shared RemoteEvent
local REMOTE_NAME = "FireStaff"
local fireRemote: RemoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_NAME) :: RemoteEvent
	or (function()
		local ev = Instance.new("RemoteEvent")
		ev.Name = REMOTE_NAME
		ev.Parent = ReplicatedStorage
		return ev
	end)()

local TRAIL_NAME = "StarterStaffTrail" -- consistent naming

local function fireBullet(player: Player, targetPos: Vector3, staffType: string)
	-- Basic early validation
	if typeof(targetPos) ~= "Vector3" or typeof(staffType) ~= "string" then
		return
	end

	local stats = staffTable[staffType]
	if not stats then
		warn("No stats found for StaffType:", staffType)
		return
	end

	-- SECURITY: Make sure the player is actually holding a tool with this StaffType
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool or tool:GetAttribute("StaffType") ~= staffType then
		-- Player is not holding the correct staff → possible exploit attempt
		return
	end

	local muzzle: BasePart? = tool:FindFirstChild("BulletStartPosition") :: BasePart?
	if not muzzle or not muzzle:IsA("BasePart") then
		warn("Missing BulletStartPosition in tool:", tool.Name)
		return
	end

	local bulletTemplateName = stats.BulletTemplate or "StarterStaffBullet"
	local bulletTemplate: Model? = ServerStorage.Parts:FindFirstChild(bulletTemplateName) :: Model?

	if not bulletTemplate or not bulletTemplate:IsA("Model") or not bulletTemplate.PrimaryPart then
		warn(bulletTemplateName, "not found or invalid in ServerStorage.Parts")
		return
	end

	-- Clone & setup
	local bullet = bulletTemplate:Clone() :: Model
	if not bullet or not bullet.PrimaryPart then
		return
	end
	bullet:SetAttribute("Owner", player.UserId)
	bullet.PrimaryPart:PivotTo(CFrame.new(muzzle.Position + Vector3.new(0, 1, 0)))
	bullet.Parent = workspace

	-- Customize trail color (on the clone!)
	local bulletBasePart = bullet:FindFirstChild("BulletPart") :: BasePart?
	if bulletBasePart then
		local trail = bulletBasePart:FindFirstChild(TRAIL_NAME) :: Trail?
		if trail and trail:IsA("Trail") then
			local color = utilMod.HexToColor3(stats.bulletTrail)
			trail.Color = ColorSequence.new(color)
		else
			warn("No trail named", TRAIL_NAME, "found in bullet template")
		end
	end

	-- Trajectory setup
	local startPos = bullet.PrimaryPart.Position
	local direction = (targetPos - startPos).Unit
	local distance = math.min((targetPos - startPos).Magnitude, stats.maxRange)
	local duration = distance / stats.bulletSpeed
	local startTime = time()

	local lastPos = startPos
	local petsGroup = utilMod.MyPets(character)
	local effectsFolder = workspace:FindFirstChild("Effects")

	local moveConn: RBXScriptConnection?
	moveConn = RunService.Heartbeat:Connect(function()
		if not bullet.Parent or not bullet.PrimaryPart then
			if moveConn then
				moveConn:Disconnect()
				return
			end
		end

		local elapsed = time() - startTime
		if (elapsed - 1) >= duration then
			bullet:Destroy()
			if moveConn then
				moveConn:Disconnect()
				return
			end
		end

		local t = elapsed / duration
		local progress = t * distance
		local pos = startPos + direction * progress
		local height = stats.arcHeight * 4 * t * (1 - t) -- parabola
		local newPos = pos + Vector3.new(0, height, 0)

		local delta = newPos - lastPos

		if delta.Magnitude > 0.01 then
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			

				local filter = { bullet, character } :: { Instance }
				for _, pet in petsGroup do
					if pet then
						table.insert(filter, pet)
					end
				end
				if effectsFolder then
					table.insert(filter, effectsFolder)
				end

				rayParams.FilterDescendantsInstances = filter
			local backOffset = delta.Unit * -0.1 -- 0.1–0.5 studs usually enough; adjust if needed
			local rayOrigin = lastPos + backOffset

			local result = workspace:Raycast(rayOrigin, delta - backOffset, rayParams) -- adjust length too if you want

			if result then
				utilMod.createCustomExplosion(result.Position, stats.Explosion)

				local ownerPlayer = Players:GetPlayerByUserId(bullet:GetAttribute("Owner") :: number)
				if ownerPlayer then
					combatMod.ApplyStaffDamage(result.Instance :: BasePart, ownerPlayer, staffType)
				end

				bullet:Destroy()
				if moveConn then
					moveConn:Disconnect()
					return
				end
			end
		end

		-- No hit → continue moving & orient
		local moveDir = delta.Unit
		bullet:PivotTo(CFrame.lookAt(newPos, newPos + moveDir))
		lastPos = newPos
	end)
end

-- Listen for all fire requests
fireRemote.OnServerEvent:Connect(function(player: Player, targetPos: Vector3, staffType: string)
	if utilMod.GetAttribute(player, "HasFallen") then
		return
	end

	fireBullet(player, targetPos, staffType)
end)

return staffFireServerMod
