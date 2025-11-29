local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local PhysicsService      = game:GetService("PhysicsService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod   = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)

local staffTable = statsMod.StaffStats
local tool       = script.Parent

local bulletStartPosition = tool:WaitForChild("BulletStartPosition")

local maxRange    = staffTable.StarterStaffArtificer.maxRange
local bulletSpeed = staffTable.StarterStaffArtificer.bulletSpeed
local arcHeight   = staffTable.StarterStaffArtificer.arcHeight

-- Collision group setup
if bulletStartPosition:IsA("BasePart") then
    bulletStartPosition.CollisionGroup = "Weapon"
else
    warn("BulletStartPosition is not a BasePart")
end

-- RemoteEvent
local fireEvent = ReplicatedStorage:FindFirstChild("FireArtificerStarterStaff")
if not fireEvent then
    fireEvent = Instance.new("RemoteEvent")
    fireEvent.Name = "FireArtificerStarterStaff"
    fireEvent.Parent = ReplicatedStorage
end

local function fireBullet(player: Player, targetPosition: Vector3)
    local bulletTemplate = ServerStorage:FindFirstChild("StarterStaffBullet")
    if not bulletTemplate then
        warn("StarterStaffBullet not found in ServerStorage")
        return
    end

    local trail: Trail = bulletTemplate:FindFirstChild("StarterStaffTrail")
    local color = utilMod.HexToColor3(staffTable.StarterStaffArtificer.bulletTrail)
    trail.Color = ColorSequence.new(color)

    -- Clone & setup bullet
    local bullet = bulletTemplate:Clone()
    bullet:SetAttribute("Owner", player.Name)
    bullet.Position = bulletStartPosition.Position + Vector3.new(0, 0.5, 0)
    bullet.Parent = workspace

    -- Set collision group for bullet (supports both Part and Model)
    local function setBulletCollisionGroup(obj)
        if obj:IsA("BasePart") then
            obj.CollisionGroup = "Bullet"
        end
    end
    if bullet:IsA("BasePart") then
        setBulletCollisionGroup(bullet)
    elseif bullet.PrimaryPart then
        setBulletCollisionGroup(bullet.PrimaryPart)
        for _, part in bullet:GetDescendants() do
            setBulletCollisionGroup(part)
        end
    end

    -- Make owner immune
    local character = player.Character
    if character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and not part:IsDescendantOf(tool) then
                part.CollisionGroup = "Player"
            end
        end
    end

    -- Direction & distance
    local startPos   = bullet.Position
    local direction  = (targetPosition - startPos).Unit
    local distance   = math.min((targetPosition - startPos).Magnitude, maxRange)
    local duration   = distance / bulletSpeed
    local startTime  = tick()

    -- Touch handling (now uses the new function!)
    local touchConn
    touchConn = bullet.Touched:Connect(function(hit)
        if hit == bulletStartPosition or hit:IsDescendantOf(tool) then return end

        local ownerName = bullet:GetAttribute("Owner")
        local ownerPlayer = ownerName and game.Players:FindFirstChild(ownerName)
        if not ownerPlayer then return end

        -- Apply damage via the new centralized function
        local success = combatMod.ApplyStaffDamage(hit, ownerPlayer, "StarterStaffArtificer")
        
        if success then
            -- Visual explosion
            utilMod.createCustomExplosion(
                bullet.Position,
                staffTable.StarterStaffArtificer.visualSize,
                staffTable.StarterStaffArtificer.visualTime,
                color
            )

            -- Cleanup
            bullet:Destroy()
            if touchConn then touchConn:Disconnect() end
        end
    end)

    -- Movement with parabolic arc
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

        -- Simple parabolic arc
        local height = arcHeight * 4 * t * (1 - t) -- peaks at t=0.5

        bullet.Position = pos + Vector3.new(0, height, 0)
        bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
    end)
end

-- RemoteEvent handler
fireEvent.OnServerEvent:Connect(function(player, targetPosition)
    if typeof(targetPosition) ~= "Vector3" then return end
    fireBullet(player, targetPosition)
end)