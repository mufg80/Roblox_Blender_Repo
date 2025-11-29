local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod   = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)

local staffTable = statsMod.StaffStats
local tool       = script.Parent
local bulletStartPosition = tool:WaitForChild("BulletStartPosition")

-- Staff-specific stats
local maxRange    = staffTable.StarterStaffNature.maxRange
local bulletSpeed = staffTable.StarterStaffNature.bulletSpeed
local arcHeight   = staffTable.StarterStaffNature.arcHeight

-- Set collision group for muzzle
if bulletStartPosition:IsA("BasePart") then
    bulletStartPosition.CollisionGroup = "Weapon"
else
    warn("BulletStartPosition is not a BasePart")
end

-- RemoteEvent
local fireEvent = ReplicatedStorage:FindFirstChild("FireNatureStarterStaff")
if not fireEvent then
    fireEvent = Instance.new("RemoteEvent")
    fireEvent.Name = "FireNatureStarterStaff"
    fireEvent.Parent = ReplicatedStorage
end

local function fireBullet(player: Player, targetPosition: Vector3)
    local bulletTemplate = ServerStorage:FindFirstChild("StarterStaffBullet")
    if not bulletTemplate then
        warn("StarterStaffBullet not found in ServerStorage")
        return
    end

    -- Trail color setup
    local trail: Trail = bulletTemplate:FindFirstChild("StarterStaffTrail")
    local color = utilMod.HexToColor3(staffTable.StarterStaffNature.bulletTrail)
    trail.Color = ColorSequence.new(color)

    -- Spawn bullet
    local bullet = bulletTemplate:Clone()
    bullet:SetAttribute("Owner", player.Name)
    bullet.Position = bulletStartPosition.Position + Vector3.new(0, 0.5, 0)
    bullet.Parent = workspace

    -- Set bullet collision group (supports Part or Model)
    local function setBulletCollision(part)
        if part:IsA("BasePart") then
            part.CollisionGroup = "Bullet"
        end
    end
    if bullet:IsA("BasePart") then
        setBulletCollision(bullet)
    elseif bullet.PrimaryPart then
        setBulletCollision(bullet.PrimaryPart)
        for _, part in bullet:GetDescendants() do
            setBulletCollision(part)
        end
    end

    -- Prevent self-collision
    local character = player.Character
    if character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and not part:IsDescendantOf(tool) then
                part.CollisionGroup = "Player"
            end
        end
    end

    -- Movement math
    local startPos   = bullet.Position
    local direction  = (targetPosition - startPos).Unit
    local distance   = math.min((targetPosition - startPos).Magnitude, maxRange)
    local duration   = distance / bulletSpeed
    local startTime  = tick()

    -- Touched → Damage + Explosion
    local touchConn
    touchConn = bullet.Touched:Connect(function(hit)
        if hit == bulletStartPosition or hit:IsDescendantOf(tool) then return end

        local ownerName = bullet:GetAttribute("Owner")
        local ownerPlayer = ownerName and game.Players:FindFirstChild(ownerName)
        if not ownerPlayer then return end

        -- Use the centralized damage function!
        local hitSuccess = combatMod.ApplyStaffDamage(hit, ownerPlayer, "StarterStaffNature")

        if hitSuccess then
            -- Visual explosion
            utilMod.createCustomExplosion(
                bullet.Position,
                staffTable.StarterStaffNature.visualSize,
                staffTable.StarterStaffNature.visualTime,
                color
            )

            -- Cleanup
            bullet:Destroy()
            if touchConn then touchConn:Disconnect() end
        end
    end)

    -- Parabolic movement (smooth arc using 4t(1-t))
    local moveConn
    moveConn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= duration or not bullet.Parent then
            if bullet.Parent then bullet:Destroy() end
            if moveConn then moveConn:Disconnect() end
            if touchConn then touchConn:Disconnect() end
            return
        end

        local t = elapsed / duration
        local progress = t * distance
        local pos = startPos + direction * progress

        -- Smooth parabolic arc (peaks at t = 0.5)
        local height = arcHeight * 4 * t * (1 - t)

        bullet.Position = pos + Vector3.new(0, height, 0)
        bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
    end)
end

-- Fire on remote
fireEvent.OnServerEvent:Connect(function(player, targetPosition)
    if typeof(targetPosition) ~= "Vector3" then return end
    fireBullet(player, targetPosition)
end)