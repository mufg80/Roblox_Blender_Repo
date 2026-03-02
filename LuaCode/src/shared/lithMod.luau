--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local LITHHEALTHCAP = 5000
local MAXCHANGEPERTICK = 0.001 -- Base max 10% change per second
local MAXPLAYERCHANGEPERTICK = 0.05
local CONTROL_RANGE = 50 -- Player/pet combat range
local FERALDISTANCE = 60 -- Distance within which ferals annoy and double decay
local BASE_DECAY = LITHHEALTHCAP * MAXCHANGEPERTICK -- Normal decay amount
local FERALMULTIPLIER = 3

export type LithModule = {
	-- Creates or ensures a unique numeric ID for a lith building/instance
	-- Sets the "Unique" attribute on the building if missing
	-- Returns the ID (or nil if building is invalid)
	CreateUnique: (building: Instance) -> number?,

	-- Returns the current control percentage (0–1) for a given lith uniqueId
	-- Returns 1 if the lith doesn't exist in the internal table (full control default)
	GetLithControl: (uniqueId: number) -> number?,

	-- (Internal helper exposed — used by adorners/UI)
	-- Updates the BillboardGUI progress bar + +/− indicator on the building
	AdjustAdorner: (
		uniqueId: number,
		currentControl: number,
		building: Instance,
		isPositive: boolean
	) -> (),
	LithBaneDamage: (player: Player, building: Model, spellName: string) -> (),
}

local lithMod = {}
local liths = {} -- [uniqueId] = currentControl (0 to 5000)

-- Returns: [UserId] = {playerModel: Model?, pets: {Model}}
local function GetNearbyCombatants(lithPosition: Vector3): { [number]: { playerModel: Model?, pets: { Model } } }
	local nearby = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if utilMod.GetAttribute(player, "HasFallen") then
				continue
			end
			local hrp = player.Character.HumanoidRootPart
			if utilMod.GetDistance(lithPosition, hrp.Position) <= CONTROL_RANGE then
				nearby[player.UserId] = {
					playerModel = player.Character,
					pets = {},
				}
			end
		end
	end

	local petsFolder = workspace:FindFirstChild("Pets")
	if petsFolder then
		for _, petModel in ipairs(petsFolder:GetChildren()) do
			if petModel:IsA("Model") and petModel:FindFirstChild("HumanoidRootPart") then
				if utilMod.GetAttribute(petModel, "HasFallen") then
					continue
				end
				local hrp = petModel.HumanoidRootPart
				if utilMod.GetDistance(lithPosition, hrp.Position) <= CONTROL_RANGE then
					local ownerUserId = utilMod.GetAttribute(petModel, "OwnedBy")
					if typeof(ownerUserId) == "number" then
						if not nearby[ownerUserId] then
							nearby[ownerUserId] = { playerModel = nil, pets = {} }
						end
						table.insert(nearby[ownerUserId].pets, petModel)
					end
				end
			end
		end
	end

	return nearby
end

-- Helper: Check if any feral is within annoyance range
local function HasNearbyFerals(lithPosition: Vector3): boolean
	local feralsFolder = workspace:FindFirstChild("Ferals")
	if not feralsFolder then
		return false
	end

	for _, feral in ipairs(feralsFolder:GetChildren()) do
		if feral:IsA("Model") and feral:FindFirstChild("HumanoidRootPart") then
			if utilMod.GetAttribute(feral, "HasFallen") then
				continue
			end
			local hrp = feral.HumanoidRootPart
			if utilMod.GetDistance(lithPosition, hrp.Position) <= FERALDISTANCE then
				return true
			end
		end
	end

	return false
end

function lithMod.AdjustAdorner(uniqueId: number, currentControl: number, building: Instance, isPositive: boolean): ()
	local percentage = lithMod.GetLithControl(uniqueId)
	local billboard = building:FindFirstChild("BillboardGui")
	if not billboard then
		local billy = ServerStorage and ServerStorage:FindFirstChild("BillboardGui", true)
		if billy and billy:IsA("BillboardGui") then
			local clone = billy:Clone()
			if clone then
				billboard = clone
				clone.Parent = building
				clone.ExtentsOffset = Vector3.new(0, 1, 0)
			end
		end
	end
	if not billboard or not billboard:IsA("BillboardGui") then
		return
	end
	local plrID = building:GetAttribute("OwnedBy")
	if typeof(plrID) == "number" then
		local plr = game.Players:GetPlayerByUserId(plrID)
		local frame = billboard:FindFirstChild("Frame")
		if plr and frame then
			local label = frame:FindFirstChild("AANameLabel")
			if label and label:IsA("TextLabel") then
				label.Text = plr.Name .. "'s Lith"
			end
		end
	end

	local innerFrame = billboard:FindFirstChild("InnerFill", true)
	if innerFrame and innerFrame:IsA("Frame") then
		innerFrame.Size = UDim2.new(percentage, 0, 1, 0)
	end
	local plus = billboard:FindFirstChild("PlusLabel", true)
	local minus = billboard:FindFirstChild("MinusLabel", true)
	if plus and plus:IsA("ImageLabel") and minus and minus:IsA("ImageLabel") then
		if isPositive then
			plus.Visible = true
			minus.Visible = false
		else
			plus.Visible = false
			minus.Visible = true
		end
	end
end

-- Unique ID generator
local nextUniqueId = 1

function lithMod.CreateUnique(building: Instance): number?
	if not building then
		return nil
	end

	building:SetAttribute("Unique", nextUniqueId)
	nextUniqueId += 1
	return nextUniqueId - 1
end

-- Mana points (spouts)
local manaSpawnPoints = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()
for _, point in manaSpawnPoints do
	if utilMod.GetAttribute(point, "HasBuilding") ~= true then
		utilMod.SetAttribute(point, "HasBuilding", true)
		local spoutTemplate = ServerStorage.Buildings.ManaSpout
		if spoutTemplate then
			local clone = spoutTemplate:Clone()
			clone:PivotTo(point.CFrame)
			clone.Parent = workspace.ManaPoints
		end
	end
end

-- Public: Get current lith control/health
function lithMod.GetLithControl(uniqueId: number): number?
	return (liths[uniqueId] or LITHHEALTHCAP) / LITHHEALTHCAP
end

-- Main control tick loop
task.spawn(function()
	while task.wait(1) do
		local manaPoints = workspace:WaitForChild("ManaPoints"):GetChildren()
		if next(manaPoints) == nil then
			return
		end

		for _, building in manaPoints do
			if building.Name == "ManaSpout" then
				continue
			end

			local mesh = building:FindFirstChildOfClass("MeshPart")
			if not mesh then
				continue
			end

			local uniqueId = utilMod.GetAttribute(building, "Unique")
			if not uniqueId then
				uniqueId = lithMod.CreateUnique(building)
				liths[uniqueId] = LITHHEALTHCAP
				continue
			end

			local currentControl = liths[uniqueId] or LITHHEALTHCAP
			local currentOwnerId = utilMod.GetAttribute(building, "OwnedBy") or 0

			local lithPos = mesh.Position
			local nearbyCombatants = GetNearbyCombatants(lithPos)

			-- === No one nearby → decay logic ===
			if not next(nearbyCombatants) then
				if currentOwnerId ~= 0 and currentControl > LITHHEALTHCAP / 3 then
					local decayAmount = BASE_DECAY

					-- Ferals double the decay if nearby
					if HasNearbyFerals(lithPos) then
						decayAmount = decayAmount * FERALMULTIPLIER
					end

					currentControl = math.max(currentControl - decayAmount, LITHHEALTHCAP / 3)
					liths[uniqueId] = currentControl
					lithMod.AdjustAdorner(uniqueId, currentControl, building, decayAmount <= 0)
				end

				continue
			end

			-- === Combat active: normal strength-based shift ===
			local defenderStrength = 0
			local attackerStrength = 0

			for userId, data in pairs(nearbyCombatants) do
				local isDefending = (userId == currentOwnerId)
				if not isDefending and data.playerModel then
					local allyId = utilMod.GetAttribute(data.playerModel, "IsAlly")
					if typeof(allyId) == "number" and allyId == currentOwnerId then
						isDefending = true
					end
				end

				local targetStrength = isDefending and defenderStrength or attackerStrength

				if data.playerModel then
					local player = Players:GetPlayerByUserId(userId)
					local level = player and utilMod.GetPlayerLevel(player) or 1
					targetStrength += level * 6
				end

				for _, pet in ipairs(data.pets) do
					local petKey = utilMod.customTrim(pet.Name)
					local petLevel = statsMod.creatureStats[petKey] and statsMod.creatureStats[petKey].level or 1
					targetStrength += (petLevel * 4)
				end

				if isDefending then
					defenderStrength = targetStrength
				else
					attackerStrength = targetStrength
				end
			end
			defenderStrength = defenderStrength * 5
			attackerStrength = attackerStrength * 4.8

			local netAdvantage = defenderStrength - attackerStrength
			local maxDelta = LITHHEALTHCAP * MAXPLAYERCHANGEPERTICK
			local change = math.clamp(netAdvantage, -maxDelta, maxDelta)
			currentControl = math.clamp(currentControl + change, 0, LITHHEALTHCAP)
			liths[uniqueId] = currentControl
			lithMod.AdjustAdorner(uniqueId, currentControl, building, change >= 0)

			-- === Building destroyed when control hits 0 ===
			if currentControl <= 0 then
				local manaspawnpoints = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()

				for _, point in pairs(manaspawnpoints) do
					local pointPos = point.CFrame.Position
					if utilMod.GetDistance(pointPos, mesh.Position) < 10 then
						utilMod.SetAttribute(point, "HasBuilding", "Spout")
						local spoutModel = ServerStorage.Buildings.ManaSpout:Clone() -- now a Model
						spoutModel:PivotTo(point.CFrame)
						spoutModel.Parent = workspace.ManaPoints
					end
				end

				liths[uniqueId] = nil
				building:Destroy()
				continue
			end
		end
	end
end)

-- Applies LithBane damage to a building and updates global/player tracking
-- Does **not** return anything (void), fails silently with warnings where appropriate
function lithMod.LithBaneDamage(player: Player, building: Model, spellName: string): ()
	if not player or not player:IsDescendantOf(game) then
		warn("LithBaneDamage → Invalid or destroyed player")
		return
	end

	if not building or not building:IsDescendantOf(workspace) then
		warn("LithBaneDamage → Invalid or destroyed building")
		return
	end

	local spellinfo = statsMod.SpellInfo[spellName]
	if not spellinfo then
		warn("LithBaneDamage → No spell info for", spellName)
		return
	end

	local multiplier = spellinfo.effectMultiplier
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		warn("LithBaneDamage → Invalid effectMultiplier for", spellName)
		return
	end

	local damage = multiplier * statsMod.MaxSpellDamage
	if damage <= 0 then
		warn("LithBaneDamage → Calculated damage ≤ 0 for", spellName)
		return
	end

	local uniqueId = building:GetAttribute("Unique")
	if typeof(uniqueId) ~= "number" then
		warn("LithBaneDamage → Building missing valid Unique attribute", building:GetFullName())
		return
	end

	if not liths or typeof(liths) ~= "table" then
		warn("LithBaneDamage → Global 'liths' table is missing or invalid")
		return
	end

	local currentHealth = liths[uniqueId]
	if typeof(currentHealth) ~= "number" then
		warn("LithBaneDamage → No valid health entry for building Unique =", uniqueId)
		return
	end

	local newHealth = math.max(0, currentHealth - damage)
	liths[uniqueId] = newHealth

	local damageapplied = currentHealth - newHealth 
	

	-- Apply damage
	liths[uniqueId] = currentHealth - damage

	-- Update player's total damage dealt (LithDamage stat)
	local currentPlayerDamage = utilMod.GetAttribute(player, "LithDamage") or 0
	if typeof(currentPlayerDamage) ~= "number" then
		currentPlayerDamage = 0
	end

	utilMod.SetAttribute(player, "LithDamage", currentPlayerDamage + damageapplied)

end


return lithMod :: LithModule
