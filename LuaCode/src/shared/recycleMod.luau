--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local effectMod = require(ReplicatedStorage.Shared.effectMod)
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local recycleMod = {}

-- Internal state (typed for clarity)
recycleMod.thedead = {}          -- [petName] = timestamp when flagged dead
recycleMod.theferaldead = {}     -- [feralName] = timestamp when flagged dead
recycleMod.waittime = 2          -- seconds to wait before recycling

----------------------------------------------------------------
-- Helper: reset an NPC back to its default state
----------------------------------------------------------------
function recycleMod.resetNPC(npc: Model): ()
    if not npc then
        return
    end

    utilMod.InitNPC(npc)

    -- Reset humanoid
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.PlatformStand = false

        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in animator:GetPlayingAnimationTracks() do
                track:Stop()
            end
        end

        hum:ChangeState(Enum.HumanoidStateType.Physics)
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    end

    -- Clean up bindable events
    local function destroyEvent(name: string)
        local event = npc:FindFirstChild(name)
        if event and event:IsA("BindableEvent") then
            event:Destroy()
        end
    end

    destroyEvent("BuffDebuffEvent")
    destroyEvent("RemoveBuffDebuffEvent")
    destroyEvent("AddThreat")

    -- Reset collision group
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CollisionGroup = "default"
    end

    -- Restart scripts (if any were disabled)
    for _, s in npc:GetDescendants() do
        if s:IsA("Script") then
            s.Disabled = true
            s.Disabled = false
        end
    end
end

----------------------------------------------------------------
-- EXISTENCE CHECKS
----------------------------------------------------------------
function recycleMod.CheckIfExistsPet(baseName: string): boolean
    local storagePets = ServerStorage:FindFirstChild("Pets")
    if not storagePets then
        return false
    end

    for _, npc in storagePets:GetChildren() do
        if utilMod.customTrim(npc.Name) == baseName then
            return true
        end
    end
    return false
end

function recycleMod.CheckIfExistsFeral(baseName: string): boolean
    local storageFerals = ServerStorage:FindFirstChild("Ferals")
    if not storageFerals then
        return false
    end

    for _, npc in storageFerals:GetChildren() do
        if utilMod.customTrim(npc.Name) == baseName then
            return true
        end
    end
    return false
end

----------------------------------------------------------------
-- RETURN FUNCTIONS (reuse/reset from storage)
----------------------------------------------------------------
function recycleMod.ReturnPet(baseName: string): Model?
    local storagePets = ServerStorage:FindFirstChild("Pets")
    if not storagePets then
        return nil
    end

    for _, npc in storagePets:GetChildren() do
        if utilMod.customTrim(npc.Name) == baseName then
            recycleMod.resetNPC(npc)
            return npc
        end
    end
    return nil
end

function recycleMod.ReturnFeral(baseName: string): Model?
    local storageFerals = ServerStorage:FindFirstChild("Ferals")
    if not storageFerals then
        return nil
    end

    for _, npc in storageFerals:GetChildren() do
        if utilMod.customTrim(npc.Name) == baseName then
            recycleMod.resetNPC(npc)
            return npc
        end
    end
    return nil
end

----------------------------------------------------------------
-- Soul spawn on pet death (only for player-owned pets)
----------------------------------------------------------------
function recycleMod.SpawnSoul(npc: Model): ()
    if not npc or not npc.Parent then
        warn("SpawnSoul: Invalid NPC model")
        return
    end

    -- Dont spawn soul if model is reclaimed

    local reclaimed = utilMod.GetAttribute(npc,"Reclaimed")
    if reclaimed then return end

    local ownedBy = utilMod.GetAttribute(npc, "OwnedBy")
    if typeof(ownedBy) ~= "number" then
        -- Feral NPCs do not spawn souls
        return
    end



    local rootPart = utilMod.GetRootPart(npc)
    if not rootPart then
        warn("SpawnSoul: NPC missing HumanoidRootPart")
        return
    end

    local loc = rootPart.Position
    local yAxis = utilMod.DistancetoGround(loc) or loc.Y
    local newLoc = Vector3.new(loc.X, yAxis + 1, loc.Z)

    local soulClone = ServerStorage.Parts.SoulObject:Clone()
    if not soulClone then
        warn("SpawnSoul: Failed to clone SoulObject")
        return
    end

    utilMod.SetAttribute(soulClone, "OwnedBy", ownedBy)
    utilMod.SetAttribute(soulClone, "DB", true)

    local soulPart = soulClone:FindFirstChild("SoulObject")
    if not soulPart or not soulPart:IsA("MeshPart") then
        warn("SpawnSoul: SoulObject missing MeshPart")
        soulClone:Destroy()
        return
    end

    local con
    con = soulPart.Touched:Connect(function(hitpart)
        local db = utilMod.GetAttribute(soulClone, "DB")
        if not db then return end
        utilMod.SetAttribute(soulClone, "DB", false)

        local character = hitpart.Parent
        local player = game.Players:GetPlayerFromCharacter(character)
        if player then
            local ownerId = utilMod.GetAttribute(soulClone, "OwnedBy")
            if player.UserId == ownerId then
                local souls = utilMod.GetAttribute(player, "Souls") or 0
                local maxSouls = utilMod.GetAttribute(player, "MaxSouls")
                if souls < maxSouls then
                    utilMod.SetAttribute(player, "Souls", souls + 1)
                    ReplicatedStorage.Events.GainedSoulEvent:FireClient(
                        player,
                        utilMod.GetAttribute(player, "Souls"),
                        maxSouls
                    )
                    if con then con:Disconnect() end
                    
                    effectMod.SoulGrabbedEffect(newLoc)
                    soulClone.Parent = nil
                end
            else
                print("Other players cannot harvest this soul.")
            end
        end

        task.delay(2, function()
            utilMod.SetAttribute(soulClone, "DB", true)
        end)
    end)

    soulClone:PivotTo(CFrame.new(newLoc))
    soulClone.Parent = workspace:WaitForChild("Souls")
end

-- Returns the first eligible soul within range that belongs to another player,
-- or nil if none found or requirements not met.
function recycleMod.GetEligibleSoul(char: Model): Model?
	if not char then
		warn("GetEligibleSoul: character is nil")
		return nil
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		warn("GetEligibleSoul: no valid HumanoidRootPart")
		return nil
	end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		warn("GetEligibleSoul: no player associated with character")
		return nil
	end
	local plrId = player.UserId

    local souls = utilMod.GetAttribute(player, "Souls")
    local maxsouls = utilMod.GetAttribute(player, "MaxSouls")
    if souls >= maxsouls then
        return nil
    end

	-- Get spell config once
	local spellInfo = statsMod.SpellInfo and statsMod.SpellInfo.TheftOfSoul
	if not spellInfo then
		warn("GetEligibleSoul: TheftOfSoul spell info missing in statsMod")
		return nil
	end

	local range = spellInfo.range or 0
	local manaCost = spellInfo.manaCost or 0

	if range <= 0 then
		warn("GetEligibleSoul: invalid range for TheftOfSoul (" .. tostring(range) .. ")")
		return nil
	end

	-- Check mana early (cheaper than looping through souls)
	local currentMana = utilMod.GetAttribute(player, "Mana") or 0
    
	if manaCost > currentMana then
		return nil  -- no warning needed — player just doesn't have mana
	end

	local soulsFolder = workspace:FindFirstChild("Souls")
	if not soulsFolder then
		return nil
	end

	for _, soul in ipairs(soulsFolder:GetChildren()) do
		if not soul:IsA("Model") then
			continue  -- skip invalid souls
		end
        local anch = soul:FindFirstChild("Anchor")
        if not anch then continue end
        local positionofanchor = anch.CFrame.Position

		local distance = (positionofanchor - hrp.Position).Magnitude
		if distance <= range then
			local ownedBy = utilMod.GetAttribute(soul, "OwnedBy")
			if ownedBy and ownedBy ~= plrId then
				return soul  -- found one → return immediately
			end
		end
	end

	return nil
end

----------------------------------------------------------------
-- FLAG DEAD LOOP (recycles dead pets/ferals after waittime)
----------------------------------------------------------------
function recycleMod.flagAsDead(): ()
    while true do
        local petsFolder = workspace:WaitForChild("Pets")
        local feralsFolder = workspace:WaitForChild("Ferals")

        -- Track new dead pets
        for _, pet in petsFolder:GetChildren() do
            if utilMod.GetAttribute(pet, "RecycleMe") and not recycleMod.thedead[pet.Name] then
                recycleMod.thedead[pet.Name] = time()
            end
        end

        -- Track new dead ferals
        for _, feral in feralsFolder:GetChildren() do
            if utilMod.GetAttribute(feral, "RecycleMe") and not recycleMod.theferaldead[feral.Name] then
                recycleMod.theferaldead[feral.Name] = time()
            end
        end

        -- Recycle pets
        for name, t in pairs(recycleMod.thedead) do
            if time() - t > recycleMod.waittime then
                local npc = petsFolder:FindFirstChild(name)
                if npc then
                    local storagePets = ServerStorage:FindFirstChild("Pets")
                    if storagePets then
                        recycleMod.SpawnSoul(npc)  -- only for player pets
                        npc.Parent = storagePets
                    end
                end
                recycleMod.thedead[name] = nil
            end
        end

        -- Recycle ferals (no soul spawn)
        for name, t in pairs(recycleMod.theferaldead) do
            if time() - t > recycleMod.waittime then
                local npc = feralsFolder:FindFirstChild(name)
                if npc then
                    local storageFerals = ServerStorage:FindFirstChild("Ferals")
                    if storageFerals then
                        npc.Parent = storageFerals
                    end
                end
                recycleMod.theferaldead[name] = nil
            end
        end

        task.wait(0.5)
    end
end

-- Start the recycling loop
task.spawn(recycleMod.flagAsDead)

-- Exported type
export type RecycleMod = {
    waittime: number,

    resetNPC: (npc: Model) -> (),

    CheckIfExistsPet: (baseName: string) -> boolean,
    CheckIfExistsFeral: (baseName: string) -> boolean,

    ReturnPet: (baseName: string) -> Model?,
    ReturnFeral: (baseName: string) -> Model?,

    SpawnSoul: (npc: Model) -> (),
    flagAsDead: () -> (),
}

return recycleMod :: RecycleMod