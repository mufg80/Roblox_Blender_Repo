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

local lithMod = {}
local liths = {} -- [uniqueId] = currentControl (0 to 5000)

-- Returns: [UserId] = {playerModel: Model?, pets: {Model}}
local function GetNearbyCombatants(lithPosition: Vector3): { [number]: { playerModel: Model?, pets: { Model } } }
	local nearby = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
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
				local hrp = petModel.HumanoidRootPart
				if utilMod.GetDistance(lithPosition, hrp.Position) <= CONTROL_RANGE then
					local ownerUserId = petModel:GetAttribute("OwnedBy")
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
			local hrp = feral.HumanoidRootPart
			if utilMod.GetDistance(lithPosition, hrp.Position) <= FERALDISTANCE then
				return true
			end
		end
	end

	return false
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

			local uniqueId = building:GetAttribute("Unique")
			if not uniqueId then
				uniqueId = lithMod.CreateUnique(building)
				liths[uniqueId] = LITHHEALTHCAP
				continue
			end

			local currentControl = liths[uniqueId] or LITHHEALTHCAP
			local currentOwnerId = building:GetAttribute("OwnedBy") or 0

			local lithPos = mesh.Position
			local nearbyCombatants = GetNearbyCombatants(lithPos)

			-- === No one nearby → decay logic ===
			if not next(nearbyCombatants) then
				if currentOwnerId ~= 0 and currentControl > LITHHEALTHCAP / 3 then
					local decayAmount = BASE_DECAY

					-- Ferals double the decay if nearby
					if HasNearbyFerals(lithPos) then
						decayAmount = decayAmount * 2
					end

					currentControl = math.max(currentControl - decayAmount, LITHHEALTHCAP / 3)
					liths[uniqueId] = currentControl
				end
				continue
			end

			-- === Combat active: normal strength-based shift ===
			local defenderStrength = 0
			local attackerStrength = 0

			for userId, data in pairs(nearbyCombatants) do
				local isDefending = (userId == currentOwnerId)
				if not isDefending and data.playerModel then
					local allyId = data.playerModel:GetAttribute("IsAlly")
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
					local petKey = utilMod.customTrim(pet)
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
			--print("Change is: "..tostring(change))
			currentControl = math.clamp(currentControl + change, 0, LITHHEALTHCAP)
			liths[uniqueId] = currentControl

			-- === Building destroyed when control hits 0 ===
			if currentControl <= 0 then
				local manaspawnpoints = workspace:WaitForChild("ManaSpawnPoints"):GetChildren()

                for _, point in pairs(manaspawnpoints) do
					local pointPos = point.CFrame.Position
                    if utilMod.GetDistance(pointPos, mesh.Position) < 10 then
                        point:SetAttribute("HasBuilding", "Spout")
                        local spoutModel = ServerStorage.Buildings.ManaSpout:Clone() -- now a Model
						spoutModel:PivotTo(point.CFrame) -- or point.CFrame * CFrame.new(0, offset, 0) if needed
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

-- Public: Get current lith control/health
function lithMod.GetLithControl(uniqueId: number): number?
	return liths[uniqueId]
end

return lithMod
