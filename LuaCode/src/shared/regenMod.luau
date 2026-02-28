--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local utilMod = require(ReplicatedStorage.Shared.utilMod)

-- ────────────────────────────────────────────────
-- Debug toggle - set to true to see detailed output
-- ────────────────────────────────────────────────
local isDebugging = false

local playerHealthRegen = 5
local playerManaRegen = 25
local ManaPerTickByOwnedBuildingBonus = 10
local ManaPerTickIfPetCloseBonus = 2
local OwnedBuildingMaxProximity = 30
local OwnedPetMaxProximity = 20
local ManaRegenForPetsPerTick = 20
local PetMultiplyerIfBuildingExist = 3
local PetHealthRegen = 10
local PlayerIsGhostManaRegen = 20
local DeadPlayerBuildingProximity = 15

local SPECIAL_PETS = {
	UnkemptDruid = true,
	StoneManaPriest = true,
	MudPriest = true,
}

-- Remote events
local petManaEvent = ReplicatedStorage.Events.PetManaEvent

local regenMod = {}

function regenMod.RegenTick()
	if isDebugging then
		print("=== Regen Tick started ===")
	end

	for _, plr: Player in Players:GetPlayers() do
		local party = utilMod.GetPartyMembers(plr)
		if not party.Player or not party.Character then
			if isDebugging then
				print(string.format("[Regen] %s - No character, skipping", plr.Name))
			end
			continue
		end

		local char = party.Character
		local hrp = utilMod.GetRootPart(char)
		if not hrp or not hrp:IsA("BasePart") then
			if isDebugging then
				print(string.format("[Regen] %s - No root part, skipping", plr.Name))
			end
			continue
		end

		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			if isDebugging then
				print(string.format("[Regen] %s - No humanoid, skipping", plr.Name))
			end
			continue
		end

		if isDebugging then
			print(string.format("[Regen] Processing player: %s", plr.Name))
		end

		-- ────────────────────────────────────────────────
		-- Player Health Regen
		-- ────────────────────────────────────────────────
		local isSafeToRegen = not utilMod.GetAttribute(plr, "HasFallen") and not utilMod.GetAttribute(plr, "InCombat")

		if isSafeToRegen and humanoid.Health < humanoid.MaxHealth then
			local oldHealth = humanoid.Health
			local newHealth = math.clamp(humanoid.Health + playerHealthRegen, 0, humanoid.MaxHealth)
			humanoid.Health = newHealth

			if isDebugging then
				print(
					string.format(
						"[Health] %s: %d → %d (+%d)  [not fallen, not in combat]",
						plr.Name,
						math.floor(oldHealth),
						math.floor(newHealth),
						playerHealthRegen
					)
				)
			end
		end

		-- ────────────────────────────────────────────────
		-- Player Mana Regen
		-- ────────────────────────────────────────────────
		local currentMana = utilMod.GetAttribute(plr, "Mana") or 0
		local maxMana = utilMod.GetAttribute(plr, "MaxMana") or 1

		if isDebugging then
			print(string.format("[Mana] %s - Current: %.1f / %.1f", plr.Name, currentMana, maxMana))
		end

		if currentMana < maxMana then
			if isDebugging then
				print(string.format("[Mana] %s - Already full, skipping", plr.Name))
			end

			local manaBonus = playerManaRegen

			-- Building detection
			local hasCloseBuilding = false
			local hasAnyBuilding = #party.buildings > 0

			for _, building in party.buildings do
				local buildingPos = utilMod.GetPosition(building)
				if buildingPos then
					local dist = utilMod.GetDistance(hrp.Position, buildingPos)
					if dist and dist <= OwnedBuildingMaxProximity then
						hasCloseBuilding = true
						if isDebugging then
							print(string.format("[Mana] %s - Building in range (%.1f studs)", plr.Name, dist))
						end
						break
					end
				end
			end

			if hasCloseBuilding then
				manaBonus += ManaPerTickByOwnedBuildingBonus
			end

			-- Pet bonus (with conditional multiplier)
			local closeSpecialPetCount = 0

			for _, pet in party.pets do
				local petName = utilMod.customTrim(pet.Name)
				if not SPECIAL_PETS[petName] then
					continue
				end

				local petHrp = utilMod.GetRootPart(pet)
				if not petHrp or not petHrp:IsA("BasePart") then
					continue
				end

				local dist = utilMod.GetDistance(hrp.Position, petHrp.Position)
				local notFallen = not utilMod.GetAttribute(pet, "HasFallen")
				local notInCombat = not utilMod.GetAttribute(pet, "InCombat")

				if dist and dist <= OwnedPetMaxProximity and notFallen and notInCombat then
					closeSpecialPetCount += 1
					if isDebugging then
						print(
							string.format("[Mana] %s - Special pet '%s' in range (%.1f studs)", plr.Name, petName, dist)
						)
					end
				end
			end

			-- Apply pet bonus (doubled if player owns any building at all — not just close one)
			local petBonusPerPet = ManaPerTickIfPetCloseBonus
			if hasAnyBuilding then
				petBonusPerPet *= PetMultiplyerIfBuildingExist
			end

			manaBonus += closeSpecialPetCount * petBonusPerPet

			local totalManaAdded = manaBonus
			local newMana = math.min(currentMana + totalManaAdded, maxMana)

			utilMod.SetAttribute(plr, "Mana", newMana)
			currentMana = utilMod.GetAttribute(plr, "Mana")
			if isDebugging then
				print(
					string.format(
						"[Mana] %s: %.1f → %.1f  (+%.1f total)  [base:%d | bld:%d | pets:%d×%d (x%d if owned bld)] Doubling=%s",
						plr.Name,
						currentMana,
						newMana,
						totalManaAdded,
						playerManaRegen,
						hasCloseBuilding and ManaPerTickByOwnedBuildingBonus or 0,
						closeSpecialPetCount,
						ManaPerTickIfPetCloseBonus,
						PetMultiplyerIfBuildingExist,
						hasAnyBuilding and "Yes" or "No"
					)
				)
			end

			-- ────────────────────────────────────────────────
			-- Ghost (HasFallen) player mana regen near any building (owned or neutral)
			-- ────────────────────────────────────────────────
			if utilMod.GetAttribute(plr, "HasFallen") then
				local hasCloseBuildingForGhost = false
				local manaPointsFolder = workspace:FindFirstChild("ManaPoints")

				if manaPointsFolder and manaPointsFolder:IsA("Folder") then
					for _, building in manaPointsFolder:GetChildren() do
						local ownedBy = utilMod.GetAttribute(building, "OwnedBy")
						local isOwnedByPlayer = typeof(ownedBy) == "number" and ownedBy == plr.UserId
						local isNeutral = typeof(ownedBy) ~= "number" -- nil or non-number = unowned/neutral

						if isOwnedByPlayer or isNeutral then
							local buildingPos = utilMod.GetPosition(building)
							if buildingPos then
								local dist = utilMod.GetDistance(hrp.Position, buildingPos)
								if dist and dist <= DeadPlayerBuildingProximity then
									hasCloseBuildingForGhost = true
									if isDebugging then
										print(
											string.format(
												"[Ghost Mana] %s - %s building in range (%.1f studs)",
												plr.Name,
												isOwnedByPlayer and "owned" or "neutral",
												dist
											)
										)
									end
									break
								end
							end
						end
					end
				end

				if hasCloseBuildingForGhost and currentMana < maxMana then
					local ghostManaAdded = PlayerIsGhostManaRegen
					local newGhostMana = math.min(currentMana + ghostManaAdded, maxMana)
					utilMod.SetAttribute(plr, "Mana", newGhostMana)

					if isDebugging then
						print(
							string.format(
								"[Ghost Mana] %s: %.1f → %.1f (+%d)  [near building while fallen]",
								plr.Name,
								currentMana,
								newGhostMana,
								PlayerIsGhostManaRegen
							)
						)
					end
				end
			end
		end

		-- ────────────────────────────────────────────────
		-- Special Pet Mana Regen + client update
		-- ────────────────────────────────────────────────
		for _, pet in party.pets do
			local petName = utilMod.customTrim(pet.Name)
			if not SPECIAL_PETS[petName] then
				continue
			end

			local notFallen = not utilMod.GetAttribute(pet, "HasFallen")
			local notInCombat = not utilMod.GetAttribute(pet, "InCombat")

			if notFallen and notInCombat then
				local petMana = utilMod.GetAttribute(pet, "Mana") or 0
				local petMaxMana = utilMod.GetAttribute(pet, "MaxMana") or 1

				if petMana < petMaxMana then
					local newPetMana = math.min(petMana + ManaRegenForPetsPerTick, petMaxMana)
					utilMod.SetAttribute(pet, "Mana", newPetMana)

					if isDebugging then
						print(
							string.format(
								"[Pet Mana] %s's %s: %.1f → %.1f (+%d)",
								plr.Name,
								petName,
								petMana,
								newPetMana,
								ManaRegenForPetsPerTick
							)
						)
					end

					petManaEvent:FireClient(plr, pet.Name, newPetMana, petMaxMana)
				end
			else
				if isDebugging then
					print(
						string.format(
							"[Pet Mana] %s's %s: Skipped (fallen=%s, combat=%s)",
							plr.Name,
							petName,
							tostring(not notFallen),
							tostring(not notInCombat)
						)
					)
				end
			end
		end
		-- ────────────────────────────────────────────────
		-- Pet Health Regen (all pets, not just special ones)
		-- ────────────────────────────────────────────────
		for _, pet in party.pets do
			local petHumanoid = pet:FindFirstChildOfClass("Humanoid")
			if not petHumanoid then
				continue
			end

			local petNotFallen = not utilMod.GetAttribute(pet, "HasFallen")
			local petNotInCombat = not utilMod.GetAttribute(pet, "InCombat")

			if petNotFallen and petNotInCombat and petHumanoid.Health < petHumanoid.MaxHealth then
				local oldPetHealth = petHumanoid.Health
				local newPetHealth = math.clamp(petHumanoid.Health + PetHealthRegen, 0, petHumanoid.MaxHealth)
				petHumanoid.Health = newPetHealth

				if isDebugging then
					print(
						string.format(
							"[Pet Health] %s's %s: %d → %d (+%d)  [not fallen, not in combat]",
							plr.Name,
							utilMod.customTrim(pet.Name),
							math.floor(oldPetHealth),
							math.floor(newPetHealth),
							PetHealthRegen
						)
					)
				end
			end
		end
	end

	if isDebugging then
		print("=== Regen Tick finished ===\n")
	end
end

task.spawn(function()
	while task.wait(10) do
		regenMod.RegenTick()
	end
end)

return regenMod
