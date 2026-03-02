local ServerStorage = game:GetService("ServerStorage")
--!strict

export type PlayerBillboardAPI = {
	-- Force re-run name / health / mana update
	Refresh: () -> (),

	-- Optional: clean up connections / remove billboard (called on player leaving or character destroy)
	Destroy: () -> (),
}

local playerbillboardMod = {}

function playerbillboardMod.Setup(player: Player): PlayerBillboardAPI?
	if not player then
		warn("Should not reach me.")
		return { Refresh = function() end, Destroy = function() end } :: PlayerBillboardAPI
	end
	local humanoidInst: Instance? = nil
	local humanoid: Humanoid? = nil
	if player.Character then
		humanoidInst = player.Character:FindFirstChild("Humanoid")
	end
	if humanoidInst and humanoidInst:IsA("Humanoid") then
		humanoid = humanoidInst
	end
	if not humanoid then
		return nil
	end

	local connections: { RBXScriptConnection } = {}
	local billboard: BillboardGui? = nil

	local function setupCharacter(character: Model)
		-- ... same billboard creation logic ...

		if not billboard then
			local temp = ServerStorage:FindFirstChild("BillboardGui", true)
			if temp and temp:IsA("BillboardGui") then
				local clone = temp:Clone()
				clone.Parent = character
				clone.ExtentsOffsetWorldSpace = Vector3.new(0,1.5,0)
				billboard = clone
			end
		end
		if not billboard or not billboard:IsA("BillboardGui") then
			warn("should not reach me")
			return
		end

		-- Helper: Update name label
		local function updateNameLabel()
			local frame = billboard:FindFirstChild("Frame")
			if not frame then
				return
			end

			local nameLabel: Instance? = frame:FindFirstChild("AANameLabel")
			if not nameLabel or not nameLabel:IsA("TextLabel") then
				return
			end

			nameLabel.Text = player.Name
		end

		-- Helper: Update health bar fill
		local function updateHealthBar()
			local frame = billboard:FindFirstChild("Frame")
			if not frame then
				return
			end

			local container = frame:FindFirstChild("PetFrameContainer")
			if not container then
				return
			end

			local bar = container:FindFirstChild("PetMeterBar")
			if not bar then
				return
			end

			local inner: Instance? = bar:FindFirstChild("InnerFill")
			if not inner or not inner:IsA("Frame") then
				return
			end

			local fraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			inner.Size = UDim2.new(fraction, 0, 1, 0)
		end

		-- Helper: Update mana bar fill
		local function updateManaBar()
			local frame = billboard:FindFirstChild("Frame")
			if not frame then
				return
			end

			local container = frame:FindFirstChild("PetFrameContainer")
			if not container then
				return
			end

			local mbar: Instance? = container:FindFirstChild("ZPetManaMeterBar")
			if not mbar or not mbar:IsA("Frame") then
				return
			end

			local minner: Instance? = mbar:FindFirstChild("MInnerFill")
			if not minner or not minner:IsA("Frame") then
				return
			end

			mbar.Visible = true
			minner.Visible = true
			local mana = player:GetAttribute("Mana") or 0
			local maxmana = player:GetAttribute("MaxMana") or 1
			if mana and maxmana and typeof(mana) == "number" and typeof(maxmana) == "number" then
				local mFraction = math.clamp(mana / maxmana, 0, 1)
				minner.Size = UDim2.new(mFraction, 0, 1, 0)
			end
		end

		updateNameLabel()
		updateHealthBar()
		updateManaBar()

		table.insert(connections, humanoid.HealthChanged:Connect(updateHealthBar))
		table.insert(connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealthBar))
		table.insert(connections, player:GetAttributeChangedSignal("Mana"):Connect(updateManaBar))
		table.insert(connections, player:GetAttributeChangedSignal("MaxMana"):Connect(updateManaBar))
	end

	-- Initial setup
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end

	-- Public API
	local api: PlayerBillboardAPI = {
		Refresh = function()
			if player.Character then
				setupCharacter(player.Character)
			end
		end,

		Destroy = function()
			for _, conn in connections do
				conn:Disconnect()
			end
			table.clear(connections)

			if billboard then
				billboard:Destroy()
				billboard = nil
			end
		end,
	}
	game.Players.PlayerRemoving:Connect(function(leaving)
		if leaving.UserId == player.UserId then
			api.Destroy()
		end
	end)

	return api
end

return playerbillboardMod
