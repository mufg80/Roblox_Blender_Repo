local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")

local combatMod = require(ReplicatedStorage.Shared.combatMod)
local utilMod   = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)

local staffTable = statsMod.StaffStats
local tool       = script.Parent
local bulletStartPosition = tool:WaitForChild("BulletStartPosition")

-- Primordial Staff Stats
local maxRange    = staffTable.StarterStaffPrimordial.maxRange
local bulletSpeed = staffTable.StarterStaffPrimordial.bulletSpeed
local arcHeight   = staffTable.StarterStaffPrimordial.arcHeight

-- Muzzle collision group
if bulletStartPosition:IsA("BasePart") then
    bulletStartPosition.CollisionGroup = "Weapon"
else
    warn("BulletStartPosition is not a BasePart")
end

-- RemoteEvent (generic name "FireStarterStaff" – matches your original)
local fireEvent = ReplicatedStorage:FindFirstChild("FireStarterStaff")
if not fireEvent then
    fireEvent = Instance.new("RemoteEvent")
    fireEvent.Name = "FireStarterStaff"
    fireEvent.Parent = ReplicatedStorage
end

local function fireBullet(player: Player, targetPosition: Vector3)
    local bulletTemplate = ServerStorage:FindFirstChild("StarterStaffBullet")
    if not bulletTemplate then
        warn("StarterStaffBullet not found in ServerStorage")
        return
    end

    -- Set trail color
    local trail: Trail = bulletTemplate:FindFirstChild("StarterStaffTrail")
    local color = utilMod.HexToColor3(staffTable.StarterStaffPrimordial.bulletTrail)
    trail.Color = ColorSequence.new(color)

    -- Spawn bullet
    local bullet = bulletTemplate:Clone()
    bullet:SetAttribute("Owner", player.Name)
    bullet.Position = bulletStartPosition.Position + Vector3.new(0, 0.5, 0)
    bullet.Parent = workspace

    -- Apply Bullet collision group (works for Part or Model)
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

    -- Prevent self-hit
    local character = player.Character
    if character then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and not part:IsDescendantOf(tool) then
                part.CollisionGroup = "Player"
            end
        end
    end

    -- Movement setup
    local startPos   = bullet.Position
    local direction  = (targetPosition - startPos).Unit
    local distance   = math.min((targetPosition - startPos).Magnitude, maxRange)
    local duration   = distance / bulletSpeed
    local startTime  = tick()

    -- Touched → Damage via shared function
    local touchConn
    touchConn = bullet.Touched:Connect(function(hit)
        if hit == bulletStartPosition or hit:IsDescendantOf(tool) then return end

        local ownerName = bullet:GetAttribute("Owner")
        local ownerPlayer = ownerName and game.Players:FindFirstChild(ownerName)
        if not ownerPlayer then return end

        -- Reusable damage application
        local hitSuccess = combatMod.ApplyStaffDamage(hit, ownerPlayer, "StarterStaffPrimordial")

        if hitSuccess then
            -- Visual explosion
            utilMod.createCustomExplosion(
                bullet.Position,
                staffTable.StarterStaffPrimordial.visualSize,
                staffTable.StarterStaffPrimordial.visualTime,
                color
            )

            -- Cleanup
            bullet:Destroy()
            if touchConn then touchConn:Disconnect() end
        end
    end)

    -- Smooth parabolic flight
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

        -- Beautiful smooth arc: peaks perfectly at t = 0.5
        local height = arcHeight * 4 * t * (1 - t)

        bullet.Position = pos + Vector3.new(0, height, 0)
        bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + direction)
    end)
end

-- Fire when client sends target position
fireEvent.OnServerEvent:Connect(function(player, targetPosition)
    if typeof(targetPosition) ~= "Vector3" then return end
    fireBullet(player, targetPosition)
end)