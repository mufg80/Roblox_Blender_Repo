-- --!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local utilMod = require(script.Parent.utilMod)

local aggroMod = {}
-- Inside aggroMod.Setup(model)
function aggroMod.Setup(model: Model): table
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		warn("[aggroMod] Missing Humanoid or HumanoidRootPart on", model.Name)
		return {}
	end

	local hateList: { [number | string]: number } = {}

	-- Create AddThreat BindableEvent
	local addThreatEvent = Instance.new("BindableEvent")
	addThreatEvent.Name = "AddThreat"
	addThreatEvent.Parent = model

	addThreatEvent.Event:Connect(function(attackerId: number | string, amount: number?)
		if typeof(attackerId) == "number" or typeof(attackerId) == "string" then
			hateList[attackerId] = (hateList[attackerId] or 0) + (amount or 0)
		end
	end)

	-- Threat from taking damage (creator tag)
	humanoid:SetAttribute("LastHealth", humanoid.Health)
	humanoid.HealthChanged:Connect(function(health: number)
		local lastHealth = humanoid:GetAttribute("LastHealth")
		local damageTaken = lastHealth and (lastHealth - health) or 0
		humanoid:SetAttribute("LastHealth", health)

		if damageTaken > 0 then
			local creator = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")
			if creator and creator.Value then
				local attacker = creator.Value
				local attackerId = if attacker:IsA("Player") then attacker.UserId else attacker.Name
				-- Only add threat if attacker is not fallen
				local attackerModel = utilMod.GetModelByIDorName(attackerId)
				if attackerModel and not attackerModel:GetAttribute("HasFallen") then
					hateList[attackerId] = (hateList[attackerId] or 0) + damageTaken
				end
				creator:Destroy()
			end
		end
	end)

	-- === CRITICAL: Clear hate list when THIS NPC falls ===
	model:GetAttributeChangedSignal("HasFallen"):Connect(function()
		if model:GetAttribute("HasFallen") then
			table.clear(hateList)
		end
	end)

	-- If already fallen on setup (edge case), clear immediately
	if model:GetAttribute("HasFallen") then
		table.clear(hateList)
	end

	-- Unified update function
	local function updateAggro()
		local aggroRadius = model.Data.aggroRadius.Value
		local aggroSqr = aggroRadius ^ 2
		local leashSqr = (aggroRadius * 3) ^ 2

		local ownedBy = model:GetAttribute("OwnedBy")
		local isPet = ownedBy and ownedBy ~= "" and ownedBy ~= "None" and ownedBy ~= "none"

		-- Don't run aggro if self is fallen
		if model:GetAttribute("HasFallen") then
			table.clear(hateList)
			if model:GetAttribute("TargetIDorName") ~= "None" then
				model:SetAttribute("TargetIDorName", "None")
			end
			return
		end

		-- === Proximity aggro: only add non-fallen entities ===
		for _, player in Players:GetPlayers() do
			if isPet and player.UserId == ownedBy then continue end
			if player:GetAttribute("HasFallen") then
				hateList[player.UserId] = nil
				continue
			end  -- Skip fallen players

			local char = player.Character
			local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
			if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr then
				local id = player.UserId
				if not hateList[id] then
					hateList[id] = if isPet then 8 else 10
				end
			end
		end

		local petsFolder = Workspace:FindFirstChild("Pets")
		if petsFolder then
			for _, pet in petsFolder:GetChildren() do
				if pet == model then continue end
				if isPet and pet:GetAttribute("OwnedBy") == ownedBy then continue end
				if pet:GetAttribute("HasFallen") then continue end  -- Skip fallen pets

				local root = pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChild("Torso")
				if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr then
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
				if feral:GetAttribute("HasFallen") then continue end  -- Skip fallen ferals

				local root = feral:FindFirstChild("HumanoidRootPart") or feral:FindFirstChild("Torso")
				if root and (root.Position - hrp.Position).Magnitude^2 <= aggroSqr then
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

			if not root or (root.Position - hrp.Position).Magnitude^2 > leashSqr then
				hateList[id] = nil
			elseif target and target:GetAttribute("HasFallen") then
				hateList[id] = nil
			else
				hateList[id] = threat * 0.995
				if hateList[id] < 0.1 then
					hateList[id] = nil
				end
			end
		end

		-- === Select highest valid (non-fallen) target ===
		local bestId = "None"
		local bestThreat = 0

		for id, threat in pairs(hateList) do
			if threat > bestThreat then
				local target = utilMod.GetModelByIDorName(id)
				if target and not target:GetAttribute("HasFallen") then
					bestId = id
					bestThreat = threat
				else
					hateList[id] = nil
				end
			end
		end

		local current = model:GetAttribute("TargetIDorName")
		if bestThreat > 0 then
			if current ~= bestId then
				model:SetAttribute("TargetIDorName", bestId)
			end
		elseif current ~= "None" then
			model:SetAttribute("TargetIDorName", "None")
		end
	end

	-- API
	return {
		Update = updateAggro,
		AddThreat = function(id: number | string, amount: number?)
			local targetModel = utilMod.GetModelByIDorName(id)
			if targetModel and not targetModel:GetAttribute("HasFallen") then
				hateList[id] = (hateList[id] or 0) + (amount or 0)
			end
		end,
		GetHateList = function() return hateList end,
		ClearHateList = function() table.clear(hateList) end,
		GetTopThreat = function()
			local bestId, best = nil, 0
			for id, threat in hateList do
				if threat > best then
					local target = utilMod.GetModelByIDorName(id)
					if target and not target:GetAttribute("HasFallen") then
						best = threat
						bestId = id
					end
				end
			end
			return bestId, best
		end,
	}
end

return aggroMod