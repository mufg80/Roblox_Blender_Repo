local model = script.Parent
local random = Random.new()

local utilMod = require(game.ReplicatedStorage.Shared.utilMod)
local combatMod = require(game.ReplicatedStorage.Shared.combatMod)
local pathMod = require(game.ReplicatedStorage.Shared.pathMod)
local aggroMod = require(game.ReplicatedStorage.Shared.aggroMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
local buffMod = require(game.ReplicatedStorage.Shared.buffMod)
local thisMob = utilMod.customTrim(model.Name)
random = Random.new(utilMod.GetSeedFromName(thisMob))
local humanoid = model:FindFirstChildOfClass("Humanoid")
local hrp = model:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then
	return
end

local sourceStats = combatMod.ShallowTableCopy(thisMob)

utilMod.CopyStatsToFolder(script.Parent, sourceStats)

local IsStationary = model:GetAttribute("IsStationary") ~= false
local IdleReset = model:GetAttribute("IdleReset") or 5
local rangeLimit = model:GetAttribute("RangeLimit") or 50
local spawnPosition = hrp.Position
local lithTakePosition = nil
local lithDefendPosition = nil

local function SetTakeLithPosition()
	local id = model:GetAttribute("OwnedBy")
	if id == "None" or id == "none" or id == "" then
		return
	end
	local plr = game.Players:GetPlayerByUserId(id)
	if not plr then
		return
	end
	local points = workspace:WaitForChild("ManaPoints"):GetChildren()
	if not points then
		return
	end

	local closestPointDist = math.huge()
	local closestPoint = nil
	for _,point in pairs(points) do
		local dist = utilMod.GetDistance(point:FindFirstChildOfClass("MeshPart").Position, hrp.Position)
		if dist < closestPointDist then
			closestPointDist = dist
			closestPoint = point
		end
	end
	if closestPoint then
		lithTakePosition = closestPoint:FindFirstChildOfClass("MeshPart").Position
	else 
		lithTakePosition = nil
	end

end

local function SetLithDefendPosition()
	local id = model:GetAttribute("OwnedBy")
	if id == "None" or id == "none" or id == "" then
		return
	end
	local plr = game.Players:GetPlayerByUserId(id)
	if not plr then
		return
	end

	local points = workspace:WaitForChild("ManaPoints"):GetChildren()
	if not points then
		return
	end

	local thoseUnderAttack = {}
	local allliths
	for _, point in pairs(points) do
		local ownedby = point:GetAttribute("OwnedBy")
		local underAttack = point:GetAttribute("IsUnderAttack")
		if ownedby == plr.UserId and underAttack then
			table.insert(thoseUnderAttack, point)
			table.insert(allliths, point)
		elseif ownedby == plr.UserId then
			table.insert(allliths, point)
		end
	end

	if #thoseUnderAttack == 0 then
		-- go to nearest lith
		if #allliths < 1 then
			lithDefendPosition = nil
			return
		elseif #allliths == 1 then
			lithDefendPosition = allliths[1]:FindFirstChildOfClass("MeshPart").Position
			return
		else
			local closestLithdist = math.huge()
			local closestLith = nil
			for _, lith in pairs(allliths) do
				local lithpos = lith:FindFirstChildOfClass("MeshPart").Position
				if lithpos and utilMod.GetDistance(hrp.Position, lithpos) < closestLithdist then
					closestLith = lith
				end
			end
			if closestLith then
				lithDefendPosition = closestLith:FindFirstChildOfClass("MeshPart").Position
			else
				lithDefendPosition = nil
			end
			return
		end
	elseif #thoseUnderAttack == 1 then
		-- go to lith that is being attacked
		lithDefendPosition = thoseUnderAttack[1]:FindFirstChildOfClass("MeshPart").Position
		return
	elseif #thoseUnderAttack > 1 then
		-- go to closest
		local closestLithdist = math.huge()
		local closestLith = nil
		for _, lith in pairs(thoseUnderAttack) do
			local lithpos = lith:FindFirstChildOfClass("MeshPart").Position
			if lithpos and utilMod.GetDistance(hrp.Position, lithpos) < closestLithdist then
				closestLith = lith
			end
		end
		if closestLith then
			lithDefendPosition = closestLith:FindFirstChildOfClass("MeshPart").Position
		else
			lithDefendPosition = nil
		end
	else
		-- none go to is nil
		lithDefendPosition = nil
	end
end

function setStats()
	local baseStats = utilMod.GetStatsFromFolder(model)
	humanoid.MaxHealth = baseStats.hitPoints
	if humanoid.Health > humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
	humanoid.WalkSpeed = 16 * baseStats.speed
	IsStationary = model:GetAttribute("IsStationary") ~= false
	IdleReset = model:GetAttribute("IdleReset") or 15
	--print(thisMob, baseStats)
end

setStats()

local AddBuffDebuffEvent = Instance.new("BindableEvent")
AddBuffDebuffEvent.Name = "BuffDebuffEvent"
AddBuffDebuffEvent.Parent = model

AddBuffDebuffEvent.Event:Connect(function(player: Player, spellname: string)
	print("Called buff debuff event ", player.UserId, " spell: ", spellname)
	setStats()
end)

local RemoveBuffDebuffEvent = Instance.new("BindableEvent")
RemoveBuffDebuffEvent.Name = "RemoveBuffDebuffEvent"
RemoveBuffDebuffEvent.Parent = model

RemoveBuffDebuffEvent.Event:Connect(function(player: Player, spellname: string)
	print("Called Remove buff debuff event ", player.UserId, " spell: ", spellname)
	local atts = model:GetAttributes()
	local isbuffstartingwithBuffTrue = true
	for attName, attValue in pairs(atts) do
		if string.sub(attName, 1, 5) == "Buff_" then
			isbuffstartingwithBuffTrue = false
			break
		end
	end
	if isbuffstartingwithBuffTrue then
		utilMod.CopyStatsToFolder(script.Parent, sourceStats)
		setStats()
	else
		setStats()
	end
end)

-- === Threat API ===
local AddThreatEvent = Instance.new("BindableEvent")
AddThreatEvent.Name = "AddThreat"
AddThreatEvent.Parent = model

local hateList = {}

AddThreatEvent.Event:Connect(function(attackerId, amount)
	if typeof(attackerId) == "number" or typeof(attackerId) == "string" then
		hateList[attackerId] = (hateList[attackerId] or 0) + (amount or 0)
	end
end)

-- === THREAT FROM TAKING DAMAGE (NOW WORKING) ===
humanoid.HealthChanged:Connect(function(health)
	-- Compare old vs new health
	local damageTaken = humanoid:GetAttribute("LastHealth") and (humanoid:GetAttribute("LastHealth") - health) or 0

	-- Store the new health for next time
	humanoid:SetAttribute("LastHealth", health)
	local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")

	if creator and creator.Value then
		local attacker = creator.Value
		local attackerId = attacker:IsA("Player") and attacker.UserId or attacker.Name
		--AddThreatEvent:Fire(attackerId, combatMod.CalculateAggro(damageTaken))
		if creator.Parent then
			creator:Destroy()
		end
	end
end)
humanoid.Health = humanoid.MaxHealth - 1

local playerConnection
local petattackConnection
local petfollowConnection
local pettakeLithConnection
local petdefendLithConnection

local petAttack = true
local petFollow = true
local petTakeLith = false
local petDefendlith = false

local function setupOwnerConnection(ownerId)
	-- Disconnect old
	if playerConnection then
		playerConnection:Disconnect()
		playerConnection = nil
	end
	if petattackConnection then
		petattackConnection:Disconnect()
		petattackConnection = nil
	end
	if petfollowConnection then
		petfollowConnection:Disconnect()
		petfollowConnection = nil
	end
	if pettakeLithConnection then
		pettakeLithConnection:Disconnect()
		pettakeLithConnection = nil
	end
	if petdefendLithConnection then
		petdefendLithConnection:Disconnect()
		petdefendLithConnection = nil
	end

	-- Validate & setup new
	local ownerUserId = tonumber(ownerId)
	if not ownerUserId then
		return
	end -- Invalid ID → no connection

	local plrowner = game.Players:GetPlayerByUserId(ownerUserId)
	if plrowner then
		petattackConnection = plrowner:GetAttributeChangedSignal("PetAttack"):Connect(function()
			petAttack = plrowner:GetAttribute("PetAttack")
		end)
		petfollowConnection = plrowner:GetAttributeChangedSignal("PetFollow"):Connect(function()
			petFollow = plrowner:GetAttribute("PetFollow")
		end)
		petattackConnection = plrowner:GetAttributeChangedSignal("PetTakeLith"):Connect(function()
			petTakeLith = plrowner:GetAttribute("PetTakeLith")
			if petTakeLith then
				SetTakeLithPosition()
			end
		end)
		petattackConnection = plrowner:GetAttributeChangedSignal("PetDefendLith"):Connect(function()
			petDefendlith = plrowner:GetAttribute("PetDefendLith")
			if petDefendlith then
				SetLithDefendPosition()
			end
		end)
	end

	playerConnection = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer.UserId == ownerUserId then
			petattackConnection:Disconnect()
			petfollowConnection:Disconnect()
			pettakeLithConnection:Disconnect()
			petdefendLithConnection:Disconnect()
			model:SetAttribute("RecycleMe", true)
		end
	end)
end

local function onOwnerChanged()
	local ownerId = model:GetAttribute("OwnedBy")
	setStats()
	if ownerId and ownerId ~= "" and ownerId ~= "None" and ownerId ~= "none" then
		setupOwnerConnection(ownerId)
	else
		setupOwnerConnection(nil) -- Clear connection
	end
end

-- Initial setup & listen for changes
onOwnerChanged()
model:GetAttributeChangedSignal("OwnedBy"):Connect(onOwnerChanged)

-- === Animations ===
local animator = humanoid:FindFirstChildOfClass("Animator")
local animTracks = {}
if animator then
	local function load(name, looped)
		local anim = model:FindFirstChild(name)
		if anim then
			local track = animator:LoadAnimation(anim)
			if looped ~= nil then
				track.Looped = looped
			end
			return track
		end
	end
	animTracks.idle = load("ArtGuardIdle", true)
	animTracks.blink = load("ArtGuardBlink", false)
	animTracks.death = load("ArtGuardFall", false)
	animTracks.attack1 = load("ArtGuardAtt1", false)
	animTracks.attack2 = load("ArtGuardAtt2", false)
	animTracks.attack3 = load("ArtGuardAtt3", false)
end

-- task.spawn(function()
--     while true do
--         if thisMob =="FeralArtifactGuardian" then
--             print(hateList)
--         end

--         task.wait(2)
--     end

-- end)

-- === MAIN LOOP ===
task.spawn(function()
	-- Blink loop
	task.spawn(function()
		while task.wait(random:NextInteger(6, 14)) do
			if animTracks.blink and not model:GetAttribute("HasFallen") then
				animTracks.blink:Play()
			end
		end
	end)
	model:SetAttribute("IdleStartTime", tick())
	local lastAttackTime = 0

	local homewardBound = false
	local ownedby = model:GetAttribute("OwnedBy")
	local spincooldown = true

	-- Main loop for npc state
	while task.wait(0.03) do
		local ATTACK_COOLDOWN = statsMod.DELAY * model.Data.attackDelay.Value
		if humanoid.Health <= 1 then
			if not model:GetAttribute("HasFallen") then
				utilMod.SetFlagsForDeath(model)
			end
		end
		local isPet = true
		local ownerInstance = nil
		local combatTargetModel = nil
		local acceptableDistance = nil
		local movingDirection = "NotMoving"
		if not model:GetAttribute("HasFallen") then
			----------------------------------------------------------------
			-- Aggro
			----------------------------------------------------------------

			if ownedby == "" or ownedby == "None" or ownedby == "none" then
				isPet = false
			end

			if isPet then
				ownerInstance = utilMod.GetModelByIDorName(model:GetAttribute("OwnedBy"))
			end

			if isPet then
				aggroMod.hateListPet(model.Data.aggroRadius.Value, hateList, model, hrp)
			else
				aggroMod.hateListFeral(model.Data.aggroRadius.Value, hateList, model, hrp)
			end

			local hasEnemies = next(hateList) ~= nil -- true if table has at least one entry

			if hasEnemies then
				if model:GetAttribute("TargetIDorName") == "None" then
					warn("Should not reach me.")
				end
			end

			----------------------------------------------------------------
			-- SetStates
			----------------------------------------------------------------

			-- local petattack = true
			-- local petfollow = true
			-- local pettakelith = false
			-- local petdefendlith = false

			local targetid = model:GetAttribute("TargetIDorName")

			if targetid and targetid ~= "" and targetid ~= "None" and targetid ~= "none" then
				combatTargetModel = utilMod.GetModelByIDorName(targetid)
			end

			if combatTargetModel then
				acceptableDistance = combatMod.AcceptableDistanceToOpponent(model, combatTargetModel)
			end

			if isPet then

				if hasEnemies and acceptableDistance and petattack then -- next() returns nil if table is empty
					if not model:GetAttribute("InCombat") then
						utilMod.SetFlagsForCombat(model)
					end
				end
				if hasEnemies and not acceptableDistance and petattack then -- next() returns nil if table is empty
					if not model:GetAttribute("IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							if not model:GetAttribute("IsIdle") then
								utilMod.SetFlagsForIdle(model)
							end
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			else
				if hasEnemies and acceptableDistance then -- next() returns nil if table is empty
					if not model:GetAttribute("InCombat") then
						utilMod.SetFlagsForCombat(model)
					end
				end
				if hasEnemies and not acceptableDistance then -- next() returns nil if table is empty
					if not model:GetAttribute("IsMoving") then
						utilMod.SetFlagsForMoving(model)
						movingDirection = "MovingToCombatTarget"
					else
						local targ = pathMod.GetCurrentTarget(model)
						if targ ~= combatTargetModel then
							if not model:GetAttribute("IsIdle") then
								utilMod.SetFlagsForIdle(model)
							end
						else
							movingDirection = "MovingToCombatTarget"
						end
					end
				end
			end

			if not hasEnemies then
				if isPet then
					local check = ownerInstance
						and pathMod.GetTargetPet(model, game.Players:GetPlayerFromCharacter(ownerInstance).UserId)
					if check then
						if not model:GetAttribute("IsMoving") then
							utilMod.SetFlagsForMoving(model)
						end
						movingDirection = "MovingToOwner"
					else
						if not model:GetAttribute("IsIdle") then
							utilMod.SetFlagsForIdle(model)
						end
					end
				else
					if IsStationary then
						if
							utilMod.GetDistance(spawnPosition, hrp.Position) > 3
							and tick() - (model:GetAttribute("IdleStartTime")) > IdleReset
						then
							if not model:GetAttribute("IsMoving") then
								utilMod.SetFlagsForMoving(model)
							end
							movingDirection = "MovingToSpawnPosition"
						else
							if not model:GetAttribute("IsIdle") then
								utilMod.SetFlagsForIdle(model)
							end
						end
					else
						local tooFar = utilMod.GetDistance(hrp.Position, spawnPosition) > rangeLimit

						if tooFar and not homewardBound then
							homewardBound = true
							if pathMod.IsPathActive(model) then
								pathMod.ShortCircuitTravel(model)
							end
							if not model:GetAttribute("IsIdle") then
								utilMod.SetFlagsForIdle(model)
							end
						elseif homewardBound then
							if not model:GetAttribute("IsMoving") then
								utilMod.SetFlagsForMoving(model)
							end
							movingDirection = "HomewardBound"
						elseif (tick() - model:GetAttribute("IdleStartTime")) > IdleReset then
							if not model:GetAttribute("IsMoving") then
								utilMod.SetFlagsForMoving(model)
							elseif model:GetAttribute("IsMoving") and not pathMod.IsPathActive(model) then
								if not model:GetAttribute("IsIdle") then
									utilMod.SetFlagsForIdle(model)
								end
							end
							movingDirection = "MovingToRandom"
						else
							if not model:GetAttribute("IsIdle") then
								utilMod.SetFlagsForIdle(model)
							end
						end
					end
				end
			end

			----------------------------------------------------------------
			-- Actions
			----------------------------------------------------------------

			if model:GetAttribute("InCombat") then
				----------------------------------------------------------------
				-- FACE TARGET / OWNER
				----------------------------------------------------------------

				if combatTargetModel and pathMod.IsPathActive(model) then
					if combatMod.AcceptableDistanceToOpponent(model, combatTargetModel) then
						pathMod.ShortCircuitTravel(model)
					end
				end
				if combatTargetModel and not pathMod.IsPathActive(model) then
					-- Face target smoothly during combat
					utilMod.SpinToTargetInCombat(model, combatTargetModel, 0.3)

					if animTracks.idle and animTracks.idle.IsPlaying then
						animTracks.idle:Stop()
					end

					if tick() - lastAttackTime >= ATTACK_COOLDOWN then
						local track = animTracks["attack" .. random:NextInteger(1, 3)]
						if track and not track.IsPlaying then
							track:Play()
							lastAttackTime = tick()
							-- NEW: All damage + threat + creator tag is now handled centrally
							task.delay(0.5, function()
								combatMod.ApplyMeleeDamage(model, combatTargetModel)
							end)
						end
					end
				end
			end
			----------------------------------------------------------------
			-- Moving
			----------------------------------------------------------------
			if model:GetAttribute("IsMoving") then
				if not animTracks.idle.IsPlaying then
					animTracks.idle:Play()
					animTracks.idle:AdjustSpeed(1.5)
				else
					animTracks.idle:AdjustSpeed(1.5)
				end

				if movingDirection == "MovingToCombatTarget" then
					local target = pathMod.GetTargetPet(model, model:GetAttribute("TargetIDorName"))
					if target and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
					elseif pathMod.GetCurrentTarget(model) ~= combatTargetModel then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, target, model:GetAttribute("TargetIDorName"))
					end
				elseif movingDirection == "MovingToOwner" then
					local owner = model:GetAttribute("OwnedBy")
					local target = pathMod.GetTargetPet(model, owner)
					if target and not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, target, owner)
					elseif pathMod.GetCurrentTarget(model) ~= utilMod.GetModelByIDorName(owner) then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, target, owner)
					end
				elseif movingDirection == "MovingToSpawnPosition" then
					if not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					end
				elseif movingDirection == "MovingToRandom" then
					local vec = Vector3.new(spawnPosition.X, hrp.Position.Y, spawnPosition.Z)
					if random:NextInteger(1, 10) < 5 then
						local xpos = random:NextInteger(-10, 10)
						local zpos = random:NextInteger(-10, 10)
						vec = vec + Vector3.new(xpos, 0, zpos)
					end

					if not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, vec, "SpawnPoint")
					elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, vec, "SpawnPoint")
					end
				elseif movingDirection == "HomewardBound" then
					if not pathMod.IsPathActive(model) then
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					elseif pathMod.GetCurrentTarget(model) ~= "SpawnPoint" then
						pathMod.ShortCircuitTravel(model)
						pathMod.PathfindToPosition(model, spawnPosition, "SpawnPoint")
					elseif utilMod.GetDistance(hrp.Position, spawnPosition) < 5 then
						pathMod.ShortCircuitTravel(model)
						homewardBound = false
					end
				elseif movingDirection == "NotMoving" then
					warn("flag is moving but not target.")
				else
					warn("Should not reach me.")
				end
			end
			----------------------------------------------------------------
			-- Idle
			----------------------------------------------------------------
			if model:GetAttribute("IsIdle") then
				if not animTracks.idle.IsPlaying then
					animTracks.idle:Play()
					animTracks.idle:AdjustSpeed(1.0)
				else
					animTracks.idle:AdjustSpeed(1.0)
				end
				if pathMod.IsPathActive(model) then
					pathMod.ShortCircuitTravel(model)
				end

				if
					ownerInstance
					and (tick() - model:GetAttribute("IdleStartTime")) > random:NextInteger(10, 20)
					and spincooldown
				then
					spincooldown = false

					utilMod.SpinToOwner(model, hrp, ownerInstance, random, spincooldown)

					-- Allow next turn after a random delay
					task.delay(random:NextInteger(8, 15), function()
						spincooldown = true
					end)
				end
			end
		else
			----------------------------------------------------------------
			-- Death
			----------------------------------------------------------------
			if animTracks.death and not animTracks.death.IsPlaying then
				if animTracks.blink then
					animTracks.blink:Stop()
				end
				if animTracks.idle then
					animTracks.idle:Stop()
				end
				animTracks.death:Play()
				task.wait(3)
				model:SetAttribute("RecycleMe", true)
			else
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				humanoid.PlatformStand = true
				model:SetAttribute("RecycleMe", true)
			end
		end
	end
end)
