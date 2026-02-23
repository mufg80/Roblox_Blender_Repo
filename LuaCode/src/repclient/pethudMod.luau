--!strict
-- ReplicatedStorage.Client.PetHUD

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statsGui = playerGui:WaitForChild("StatsGui")
local guiComponents = ReplicatedStorage:WaitForChild("GUIComponents")

local PetHUD = {}
local activePetConnections = {}  -- [petName] = {healthConn, ancestryConn}

local function createOrUpdatePetFrame(petModel: Model, souls: number?)
	local petName = petModel.Name
	local trimmedName = utilMod.customTrim(petName)
	
	-- Clean up old frame if exists
	local oldFrame = statsGui.HudFrame:FindFirstChild(petName .. "_PetFrame")
	if oldFrame then oldFrame:Destroy() end
	
	local petFrame = guiComponents.PetFrameContainer:Clone()
	petFrame.Name = petName .. "_PetFrame"
	petFrame.Parent = statsGui.HudFrame
	petFrame.Visible = true
	
	local petImage = petFrame.PetImageLabel
	petImage.Image = statsMod.Pics[trimmedName]
	
	local humanoid = petModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	-- Health bar update
	local function updatePetHealth()
		if not petFrame or not petFrame.Parent then return end
		
		local container = petFrame:FindFirstChild("ZHealthMana")
		if not container then return end
		
		local bar = container:FindFirstChild("PetMeterBar")
		if not bar then return end
		
		local inner = bar:FindFirstChild("InnerFill")
		if not inner then return end
		
		local fraction = if humanoid.MaxHealth == 0 then 0 else math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		inner.Size = UDim2.new(fraction, 0, 1, 0)
		
		if humanoid.Health <= 1 then
			petFrame:Destroy()
		end
	end
	
	updatePetHealth()
	
	-- Store connections for cleanup
	local healthConn = humanoid.HealthChanged:Connect(updatePetHealth)
	
	local ancestryConn = nil
   ancestryConn = petModel.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if healthConn then healthConn:Disconnect() end
			if ancestryConn then ancestryConn:Disconnect() end
			if petFrame then petFrame:Destroy() end
			activePetConnections[petName] = nil
		end
	end)
	
	activePetConnections[petName] = {healthConn, ancestryConn}
end

local function updatePetMana(petName: string, mana: number, maxMana: number)
	local frame = statsGui.HudFrame:FindFirstChild(petName .. "_PetFrame")
	if not frame then return end
	
	local container = frame.ZHealthMana
	local manaBar = container.ZPetManaMeterBar
	manaBar.Visible = true
	
	local inner = manaBar.InnerFill
	inner.Visible = true
	
	local fraction = if maxMana == 0 then 0 else math.clamp(mana / maxMana, 0, 1)
	inner.Size = UDim2.new(fraction, 0, 1, 0)
end

function PetHUD.Init()
	ReplicatedStorage.Events.SummonEvent.OnClientEvent:Connect(function(petModel: Model?, souls: number?)
		if not petModel or not petModel:IsA("Model") then
			warn("Invalid summoned creature received on client")
			return
		end
		
		createOrUpdatePetFrame(petModel, souls)
	end)
	
	ReplicatedStorage.Events.PetManaEvent.OnClientEvent:Connect(updatePetMana)
end

return PetHUD