--!strict

local playerbillboardMod = {}

function playerbillboardMod.Setup(player: Player): table
	if not player then
		warn("Should not reach me.")
		return {}
	end

	local function setupCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid")
		if not humanoid then
			warn("[playerbillboardMod] Missing Humanoid on", character.Name)
			return
		end


		-- Billboard
		local billboard: BillboardGui? = character:FindFirstChild("BillBoardGUI")
		if not billboard then
			-- Clone from ServerStorage if missing
			local template = game.ServerStorage:FindFirstChild("BillBoards")
				and game.ServerStorage.BillBoards:FindFirstChild("BillBoardGUI")
			if template then
				billboard = template:Clone()
				billboard.Parent = character

				-- For players, use a default offset (e.g., above head)
				billboard.ExtentsOffset = Vector3.new(0, 1.5, 0) -- default fallback
			end
		end

		if not billboard then
			return
		end

		-- Helper: Update name label
		local function updateNameLabel()
			local frame = billboard:FindFirstChild("Frame")
			if not frame then
				return
			end

			local nameLabel: TextLabel = frame:FindFirstChild("AANameLabel")
			if not nameLabel then
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

			local inner: Frame = bar:FindFirstChild("InnerFill")
			if not inner then
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

			local mbar = container:FindFirstChild("ZPetManaMeterBar")
			if not mbar then
				return
			end

			local minner: Frame = mbar:FindFirstChild("MInnerFill")
			if not minner then
				return
			end

			mbar.Visible = true
			minner.Visible = true
			local mana = player:GetAttribute("Mana") or 0
			local maxmana = player:GetAttribute("MaxMana") or 1
			local mFraction = math.clamp(mana / maxmana, 0, 1)
			minner.Size = UDim2.new(mFraction, 0, 1, 0)
		end

		-- Initial setup
		updateNameLabel()
		updateHealthBar()
		updateManaBar()

		-- Health updates
		humanoid.HealthChanged:Connect(updateHealthBar)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealthBar)

		-- Mana updates (attributes on player)
		player:GetAttributeChangedSignal("Mana"):Connect(updateManaBar)
		player:GetAttributeChangedSignal("MaxMana"):Connect(updateManaBar)
	end

	-- Setup current character if exists
	if player.Character then
		setupCharacter(player.Character)
	end

	-- Handle respawns
	--player.CharacterAdded:Connect(setupCharacter)

	return {}
end

return playerbillboardMod
