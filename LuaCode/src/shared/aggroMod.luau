--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local utilMod = require(script.Parent.utilMod)

export type AggroAPI = {
	-- Call this periodically (e.g. every 0.4–1 s) to refresh proximity, decay, leash & target selection
	Update: () -> (),

	-- Manually add threat to a specific entity (player UserId, pet/feral Name, etc.)
	-- amount defaults to 0 if nil (which is a no-op)
	AddThreat: (id: number | string, amount: number?) -> (),

	-- Returns the internal hate/threat table (for debugging, UI, or advanced logic)
	-- Keys = attacker ID (UserId number or string name), values = current threat level
	GetHateList: () -> { [number | string]: number },

	-- Immediately reset all threat data
	ClearHateList: () -> (),

	-- Returns the current top threat target (if any) + its threat value
	-- Returns nil, 0 if no valid (non-fallen) targets exist
	GetTopThreat: () -> Model?,
}

local aggroMod = {}

-- Inside aggroMod.Setup(model)
function aggroMod.Setup(model: Model): AggroAPI?
	if not model then
		warn("Should not reach me.")
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or not hrp:IsA("BasePart") then
		warn("[aggroMod] Missing Humanoid or HumanoidRootPart on", model.Name)
		return nil
	end

	local hateList: { [number | string]: number } = {}

	-- Create AddThreat BindableEvent
	local addThreatEvent = Instance.new("BindableEvent")
	addThreatEvent.Name = "AddThreat"
	addThreatEvent.Parent = model

	addThreatEvent.Event:Connect(function(attackerId: number | string, amount: number?)
		--print("attacker added threat from bindableevent: "..attackerId)
		if typeof(attackerId) == "number" or typeof(attackerId) == "string" then
			hateList[attackerId] = (hateList[attackerId] or 0) + (amount or 0)
		end
	end)

	-- Threat from taking damage (creator tag)
	humanoid:SetAttribute("LastHealth", humanoid.Health)
	humanoid.HealthChanged:Connect(function(health: number)
		local lastHealth = humanoid:GetAttribute("LastHealth")
		if typeof(lastHealth) ~= "number" then
			warn("Should not reach me")
			return
		end
		local damageTaken = lastHealth and (lastHealth - health) or 0
		humanoid:SetAttribute("LastHealth", health)

		if damageTaken > 0 then
			if humanoid.Health <= 1 then
				task.wait()
				if utilMod.GetAttribute(model, "HasFallen") then
					local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")
					if creator and creator:IsA("ObjectValue") and creator.Value then
						local attacker = creator.Value
						local attackerID = nil
						if attacker:IsA("Player") then
							attackerID = attacker.UserId
						elseif game.Players:GetPlayerFromCharacter(attacker) ~= nil then
                            attackerID = game.Players:GetPlayerFromCharacter(attacker).UserId
                        else
							if attacker:IsA("Player") then
								attackerID = utilMod.GetAttribute(attacker, "OwnedBy")
							end							
						end
						if attackerID and attackerID ~= 0 then
                            local plr = Players:GetPlayerByUserId(attackerID)
                            if plr then
                                local event = plr:FindFirstChild("ExpEvent")
                                if event and event:IsA("BindableEvent") then
                                    event:Fire(model.Name) -- Award 10 EXP for a kill, can be adjusted as needed
                                end
                            end
						end
						creator:Destroy()
					end
				end
			end
		end
	end)

	-- === CRITICAL: Clear hate list when THIS NPC falls ===
	model:GetAttributeChangedSignal("HasFallen"):Connect(function()
		if utilMod.GetAttribute(model, "HasFallen") then
			table.clear(hateList)
		end
	end)

	-- If already fallen on setup (edge case), clear immediately
	if utilMod.GetAttribute(model, "HasFallen") then
		table.clear(hateList)
	end

	-- Unified update function
	local function updateAggro()
		local data = model:FindFirstChild("Data")
		local radius = data and data:FindFirstChild("aggroRadius")
		local aggroRadius = nil
		if radius and radius:IsA("NumberValue") then
			aggroRadius = radius.Value
		end
		
		local aggroSqr = aggroRadius ^ 2
		local leashSqr = (aggroRadius * 3) ^ 2

		local ownedBy = utilMod.GetAttribute(model, "OwnedBy")
		local isPet = ownedBy and ownedBy ~= "" and ownedBy ~= "None" and ownedBy ~= "none"

		-- Don't run aggro if self is fallen
		if utilMod.GetAttribute(model, "HasFallen") then
			table.clear(hateList)
			if utilMod.GetAttribute(model, "TargetIDorName") ~= "None" then
				utilMod.SetAttribute(model, "TargetIDorName", "None")
			end
			return
		end

		-- === Proximity aggro: only add non-fallen entities ===
		for _, player in Players:GetPlayers() do
			if isPet and player.UserId == ownedBy then
				continue
			end
			if utilMod.GetAttribute(player, "HasFallen") then
				hateList[player.UserId] = nil
				continue
			end -- Skip fallen players

			local char = player.Character
			local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
			if root and (root.Position - hrp.Position).Magnitude ^ 2 <= aggroSqr then
				local id = player.UserId
				if not hateList[id] then
					hateList[id] = if isPet then 8 else 10
				end
			end
		end

		local petsFolder = Workspace:FindFirstChild("Pets")
		if petsFolder then
			for _, pet in petsFolder:GetChildren() do
				if pet == model then
					continue
				end
				if isPet and utilMod.GetAttribute(pet, "OwnedBy") == ownedBy then
					continue
				end
				if utilMod.GetAttribute(pet, "HasFallen") then
					continue
				end -- Skip fallen pets

				local root = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChild("Torso")
				if root and (root.Position - hrp.Position).Magnitude ^ 2 <= aggroSqr then
					local id = pet.Name
					if not hateList[id] then
						hateList[id] = 4
					end
				end
			end
		end

		local feralsFolder = Workspace:FindFirstChild("Ferals")
		if feralsFolder and isPet then
			for _, feral in feralsFolder:GetChildren() do
				if utilMod.GetAttribute(feral, "HasFallen") then
					continue
				end -- Skip fallen ferals

				local root = feral:FindFirstChild("HumanoidRootPart") or feral:FindFirstChild("Torso")
				if root and (root.Position - hrp.Position).Magnitude ^ 2 <= aggroSqr then
					local id = feral.Name
					if not hateList[id] then
						hateList[id] = 6
					end
				end
			end
		end

		-- === Remove allies (pets only) ===
		if isPet then
			for id, _ in pairs(hateList) do
				local targetModel = utilMod.GetModelByIDorName(id)
				if targetModel and utilMod.IsAlly(model, targetModel) then
					hateList[id] = nil
				end
			end
		end

		-- === Leash, decay, and cleanup: use HasFallen only ===
		for id, threat in pairs(hateList) do
			local target = utilMod.GetModelByIDorName(id)
			local root = target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso"))
			if not root or not root:IsA("BasePart") then
				continue
			end
			if not root or (root.Position - hrp.Position).Magnitude ^ 2 > leashSqr then
				hateList[id] = nil
			elseif target and utilMod.GetAttribute(target, "HasFallen") then
				hateList[id] = nil
			else
				hateList[id] = threat * 0.995
				if hateList[id] < 0.1 then
					hateList[id] = nil
				end
			end
		end

		-- === Select highest valid (non-fallen) target ===
		local bestId: string | number = "None"
		local bestThreat = 0

		for id, threat in pairs(hateList) do
			if threat > bestThreat then
				local target = utilMod.GetModelByIDorName(id)
				if target and not utilMod.GetAttribute(target, "HasFallen") then
					bestId = id
					bestThreat = threat
				else
					hateList[id] = nil
				end
			end
		end

		local current = utilMod.GetAttribute(model, "TargetIDorName")
		if bestThreat > 0 then
			if current ~= bestId then
				utilMod.SetAttribute(model, "TargetIDorName", bestId)
			end
		elseif current ~= "None" then
			utilMod.SetAttribute(model, "TargetIDorName", "None")
		end
	end

	-- API
	return {
		Update = updateAggro,
		AddThreat = function(id: number | string, amount: number?)
			local targetModel = utilMod.GetModelByIDorName(id)
			if targetModel and not utilMod.GetAttribute(targetModel, "HasFallen") then
				hateList[id] = (hateList[id] or 0) + (amount or 0)
			end
		end,
		GetHateList = function()
			return hateList
		end,
		ClearHateList = function()
			table.clear(hateList)
		end,
		GetTopThreat = function()
			local bestmodel:Model? = nil
			local best = 0
			for id, threat in hateList do
				if threat > best then
					local target = utilMod.GetModelByIDorName(id)
					if target and not utilMod.GetAttribute(target, "HasFallen") then
						best = threat
						bestmodel = target
					end
				end
			end
			return bestmodel
		end,
	}
end

return aggroMod
