--!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local staffTable: { [string]: any } = statsMod.StaffStats

local tool: Tool = script.Parent
local muzzle: BasePart = tool:WaitForChild("BulletStartPosition") :: BasePart

local staffType = tool:GetAttribute("StaffType")
if not staffType or typeof(staffType) ~= "string" then
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
local bulletTemplateName: string = stats.BulletTemplate or "StarterStaffBullet"
local trailChildName: string = "StarterStaffTrail"

-- Single shared RemoteEvent
local REMOTE_NAME: string = "FireStaff"
local fireRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
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

	local bulletTemplate: Model? = ServerStorage.Parts:FindFirstChild(bulletTemplateName)
	if not bulletTemplate then
		warn(bulletTemplateName, "not found in ServerStorage")
		return
	end

	-- CLONE FIRST, then customize (fixes shared template bug!)
	local bullet: Instance = bulletTemplate:Clone()
	if bullet and bullet:IsA("Model") and bullet.PrimaryPart then
		bullet:SetAttribute("Owner", player.UserId)
		bullet.PrimaryPart:PivotTo(CFrame.new(muzzle.Position + Vector3.new(0, 1, 0)))
		bullet.Parent = workspace

		-- Trajectory calc
		local startPos: Vector3 = bullet.PrimaryPart.CFrame.Position
		local direction: Vector3 = (targetPos - startPos).Unit
		local distance: number = math.min((targetPos - startPos).Magnitude, maxRange)
		local duration: number = distance / bulletSpeed
		local startTime: number = time()

		-- Custom trail color ON CLONED BULLET (bug fix!)
		local bulletbasepart = bullet:FindFirstChild("BulletPart")
		if not bulletbasepart or not bulletbasepart:IsA("BasePart") then return end
		local trail: Instance? = bulletbasepart:FindFirstChild(trailChildName)
		if trail and trail:IsA("Trail") then
			local color: Color3 = utilMod.HexToColor3(stats.bulletTrail)
			trail.Color = ColorSequence.new(color)
		else
			warn("No trail named", trailChildName, "in bullet")
		end

		local group = utilMod.MyPets(character)
		local foldereffects = workspace:FindFirstChild("Effects")

		-- Raycast-based hit detection & damage (replaces Touched)
		local lastPos: Vector3 = bullet.PrimaryPart.Position
		local moveConn: RBXScriptConnection?
		moveConn = RunService.Heartbeat:Connect(function()
			if not bullet.Parent or not bullet.PrimaryPart then
				if moveConn then
					moveConn:Disconnect()
				end
				return
			end

			local elapsed: number = time() - startTime
			if (elapsed - 1) >= duration then
				--print("duration destroy")
				bullet:Destroy()
				if moveConn then
					moveConn:Disconnect()
				end
				return
			end

			local t: number = elapsed / duration
			local progress: number = t * distance
			local pos: Vector3 = startPos + direction * progress
			local height: number = arcHeight * 4 * t * (1 - t) -- Smooth parabola peak
			local newpos: Vector3 = pos + Vector3.new(0, height, 0)
			
			local delta: Vector3 = newpos - lastPos
			if delta.Magnitude > 0.01 then
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local groupInst: {Instance} = {bullet :: Instance, character :: Instance} :: {Instance }

				for _, pet in pairs(group) do
					if pet and pet:IsA("Instance") then
						table.insert(groupInst, pet :: Instance)
					end
				end
				if foldereffects then
					table.insert(groupInst, foldereffects)
				end
				rayParams.FilterDescendantsInstances = groupInst
				
				local result = workspace:Raycast(lastPos, delta, rayParams)
				if result then
					local hitPart: BasePart = result.Instance :: BasePart
					--print("hit the "..hitPart.Name)
					
					-- Explosion FX (now only on valid hits)
					utilMod.createCustomExplosion(result.Position, stats.Explosion)

					-- Damage
					local ownerName = bullet:GetAttribute("Owner")
					if ownerName and typeof(ownerName) == "number" then
						local ownerPlayer: Player? = game.Players:GetPlayerByUserId(ownerName)
						if ownerPlayer then
							local _success: boolean = combatMod.ApplyStaffDamage(hitPart, ownerPlayer, staffType)
						end
					end
					
					-- Destroy on hit
					bullet:Destroy()
					if moveConn then
						moveConn:Disconnect()
					end
					return
				end
			end
			
			-- No hit: move and orient along path
			local moveDir: Vector3 = delta.Unit
			bullet:PivotTo(CFrame.lookAt(newpos, newpos + moveDir))
			lastPos = newpos
		end)
	end
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