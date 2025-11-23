local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local staffTable = combatMod.StaffStats
local tool = script.Parent
local bulletStartPosition = tool:WaitForChild("BulletStartPosition")
local maxRange = staffTable.StarterStaffArtificer.maxRange
local bulletSpeed = staffTable.StarterStaffArtificer.bulletSpeed
local arcHeight = staffTable.StarterStaffArtificer.arcHeight

-- Set collision group for BulletStartPosition
if bulletStartPosition:IsA("BasePart") then
	bulletStartPosition.CollisionGroup = "Weapon"
else
	warn("BulletStartPosition is not a BasePart")
end

-- Create RemoteEvent if it doesn't exist
local fireEvent = ReplicatedStorage:FindFirstChild("FireArtificerStarterStaff")
if not fireEvent then
	fireEvent = Instance.new("RemoteEvent")
	fireEvent.Name = "FireArtificerStarterStaff"
	fireEvent.Parent = ReplicatedStorage
end

-- Function to spawn and move bullet
local function fireBullet(player, targetPosition)
	-- Get bullet from ServerStorage
	local bulletTemplate = ServerStorage:FindFirstChild("StarterStaffBullet")
	local trail: Trail = bulletTemplate:FindFirstChild("StarterStaffTrail")
	
	local color = utilMod.HexToColor3(staffTable.StarterStaffArtificer.bulletTrail)
	local seq = ColorSequence.new({ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color)})

	trail.Color = seq
	
	if not bulletTemplate then
		warn("StarterStaffBullet not found in ServerStorage")
		return
	end

	-- Clone bullet
	local bullet = bulletTemplate:Clone()
	bullet:SetAttribute("Owner", player.Name)
	bullet.Position = bulletStartPosition.Position + Vector3.new(0, 0.5, 0) -- Slight offset to avoid initial collision
	bullet.Parent = workspace

	-- Set collision group for bullet
	if bullet:IsA("BasePart") then
		bullet.CollisionGroup = "Bullet"
	elseif bullet:IsA("Model") and bullet.PrimaryPart then
		bullet.PrimaryPart.CollisionGroup = "Bullet"
		for _, part in ipairs(bullet:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Bullet"
			end
		end
	end

	-- Set collision group for player's character parts, excluding tool parts
	local character = player.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and not part:IsDescendantOf(tool) then
				part.CollisionGroup = "Player"
			end
		end
	end

	-- Calculate direction and distance
	local startPosition = bullet.Position
	local direction = (targetPosition - startPosition).Unit
	local distance = math.min((targetPosition - startPosition).Magnitude, maxRange)

	-- Handle collision detection
	local connection
	connection = bullet.Touched:Connect(function(hit)
		-- Ignore BulletStartPosition, parts in the same tool, and owner's character
		if hit == bulletStartPosition or hit:IsDescendantOf(tool) then
			return
		end
		local ownerName = bullet:GetAttribute("Owner")
		local hitCharacter = hit:FindFirstAncestorOfClass("Model")
		if hitCharacter and ownerName then
			local hitPlayer = game.Players:FindFirstChild(ownerName)
			if hitPlayer and hitPlayer.Character == hitCharacter then
				return -- Ignore collision with the owner's character

			else
				local targetchar = combatMod.customTrim(hitCharacter.Name)
				local damage = combatMod.SpellAttackResult("PlayerArtificer", targetchar, "StarterStaffArtificer")
				if damage then
					local targetHum = hitCharacter:FindFirstChildOfClass("Humanoid")
                            if targetHum then
                                -- Creator tag
                                local creator = Instance.new("ObjectValue")
                                creator.Name = "creator"
                                creator.Value = hitPlayer
                                creator.Parent = targetHum
                                task.delay(0.5, function()
                                    if creator.Parent then creator:Destroy() end
                                end)

                                targetHum.Health = math.max(targetHum.Health - damage, 0)
								if damage == 0 then
									local event = hitCharacter:FindFirstChild("AddThreat")
									if event then
										event:fire(hitPlayer.UserId, 25)
									end
								end
                            end
				end
			end
		end
		-- Trigger the explosion
		utilMod.createCustomExplosion(bullet.Position, staffTable.StarterStaffArtificer.visualSize, staffTable.StarterStaffArtificer.visualTime, color)

		-- Clean up
		bullet:Destroy()
		if connection then
			connection:Disconnect()
		end
	end)

	-- Move bullet with arc
	local startTime = tick()
	local duration = distance / bulletSpeed
	local halfDuration = duration / 2

	local heartbeatConnection
	heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		if elapsed > duration or not bullet.Parent then
			bullet:Destroy()
			if heartbeatConnection then
				heartbeatConnection:Disconnect()
			end
			if connection then
				connection:Disconnect()
			end
			return
		end

		local t = elapsed / duration -- Normalized time (0 to 1)
		local progress = t * distance
		local currentPos = startPosition + direction * progress

		-- Calculate arc height
		local height
		if t < 0.5 then
			height = arcHeight * (t / 0.5)
		else
			height = arcHeight * (1 - (t - 0.5) / 0.5)
		end

		bullet.Position = currentPos + Vector3.new(0, height, 0)
		bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
	end)
end

-- Handle fire event
fireEvent.OnServerEvent:Connect(function(player, targetPosition)
	fireBullet(player, targetPosition)
end)