--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)

local recycleMod = {}

-- Internal state (typed for clarity)
recycleMod.thedead = {}
recycleMod.theferaldead = {}
recycleMod.waittime = 2

----------------------------------------------------------------
-- Helper: reset an NPC back to its default state
----------------------------------------------------------------
function recycleMod.resetNPC(npc: Model): ()
	if not npc then
		return
	end

	-- Reset attributes
	npc:SetAttribute("TargetIDorName", "None")
	npc:SetAttribute("HasFallen", false)
	npc:SetAttribute("InCombat", false)
	npc:SetAttribute("IsIdle", true)
	npc:SetAttribute("IsMoving", false)
	npc:SetAttribute("OwnedBy", "None")
	npc:SetAttribute("RecycleMe", false)

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
			event:Destroy() -- better than setting Parent = nil
		end
	end

	destroyEvent("BuffDebuffEvent")
	destroyEvent("RemoveBuffDebuffEvent")
	destroyEvent("AddThreat")

	-- Restart scripts
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
-- RETURN FUNCTIONS
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

function recycleMod.SpawnSoul(npc: Model): ()
	-- npc passed in is player pet; when dies, spawns a soul
	-- player that picks up soul can now summon pet (if under MaxSouls)

	-- Validate input
	if not npc or not npc.Parent then
		warn("SpawnSoul: Invalid NPC model")
		return
	end

	local ownedBy = npc:GetAttribute("OwnedBy")
	if typeof(ownedBy) ~= "number" then
		-- Feral NPCs do not spawn souls
		warn("SpawnSoul: NPC has no owner (OwnedBy not a number)")
		return
	end

	local rootPart = utilMod.GetRootPart(npc)
	if not rootPart then
		warn("SpawnSoul: NPC missing HumanoidRootPart")
		return
	end

	local loc = rootPart.Position
	local yAxis = utilMod.DistancetoGround(loc)
	local newLoc = Vector3.new(loc.X, yAxis + 1, loc.Z) -- Slightly above ground for visibility/pickup

	local soulClone = ServerStorage.Parts.SoulObject:Clone()
	if not soulClone then
		warn("SpawnSoul: Failed to clone SoulObject")
		return
	end

	-- Set owner as UserId (number) for reliable storage/comparison
	soulClone:SetAttribute("OwnedBy", ownedBy)
    soulClone:SetAttribute("DB", true)
	-- Reference the touchable MeshPart (from model structure: SoulObject > SoulObject (MeshPart))
	local soulPart = soulClone:FindFirstChild("SoulObject")
	if not soulPart or not soulPart:IsA("MeshPart") then
		warn("SpawnSoul: SoulObject missing MeshPart")
		soulClone:Destroy()
		return
	end
    local con = nil
	-- Setup one-time Touched handler with auto-disconnect for debounce
	con = soulPart.Touched:Connect(function(hitpart)
        local db = soulClone:GetAttribute("DB")
        if not db then return end
        soulClone:SetAttribute("DB",false)
		local character = hitpart.Parent
		local player = game.Players:GetPlayerFromCharacter(character)
		if player then
			local ownerId = soulClone:GetAttribute("OwnedBy")
			if player.UserId == ownerId then
				-- Owner pickup: award soul if under limit
				local souls = player:GetAttribute("Souls") or 0
				if souls < player:GetAttribute("MaxSouls") then
					player:SetAttribute("Souls", souls + 1)
					-- Optional: Fire client remote for UI feedback/sound/particles
					ReplicatedStorage.Events.GainedSoulEvent:FireClient(
						player,
						player:GetAttribute("Souls"),
						player:GetAttribute("MaxSouls")
					)
                    con:Disconnect()
                    soulClone.Parent = nil
				end
            else
                print("Other players cannot harvest this way.")
			end
		end
        task.wait(2)
        soulClone:SetAttribute("DB",true)
	end)

	-- Position and parent
	soulClone:PivotTo(CFrame.new(newLoc))
	soulClone.Parent = workspace.Souls -- Assumes folder exists

end
----------------------------------------------------------------
-- FLAG DEAD LOOP
----------------------------------------------------------------
function recycleMod.flagAsDead(): ()
	while true do
		local petsFolder = workspace:WaitForChild("Pets")
		local feralsFolder = workspace:WaitForChild("Ferals")

		-- Track new dead pets
		for _, pet in petsFolder:GetChildren() do
			if pet:GetAttribute("RecycleMe") and not recycleMod.thedead[pet.Name] then
				recycleMod.thedead[pet.Name] = tick()
			end
		end

		-- Track new dead ferals
		for _, feral in feralsFolder:GetChildren() do
			if feral:GetAttribute("RecycleMe") and not recycleMod.theferaldead[feral.Name] then
				recycleMod.theferaldead[feral.Name] = tick()
			end
		end

		-- Recycle pets
		for name, t in recycleMod.thedead do
			if tick() - t > recycleMod.waittime then
				local npc = petsFolder:FindFirstChild(name)
				if npc then
					local storagePets = ServerStorage:FindFirstChild("Pets")
					if storagePets then
						recycleMod.SpawnSoul(npc)
						npc.Parent = storagePets
					end
				end
				recycleMod.thedead[name] = nil
			end
		end

		-- Recycle ferals
		for name, t in recycleMod.theferaldead do
			if tick() - t > recycleMod.waittime then
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
