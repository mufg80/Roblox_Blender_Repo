-- --!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(game.ReplicatedStorage.Shared.statsMod)
-- other shared mods as needed...

local ResourceBars = require(ReplicatedStorage.Client.ResourceBars)
local PetHUD = require(ReplicatedStorage.Client.PetHUD)
local PetCommands = require(ReplicatedStorage.Client.PetCommands)
--local MagicClassUI = require(ReplicatedStorage.Client.MagicClassUI)
local CastFeedback = require(ReplicatedStorage.Client.CastFeedback)
--local ActionButtonManager = require(ReplicatedStorage.Client.ActionButtonManager)
--local SpellAndSummonButtons = require(ReplicatedStorage.Client.SpellAndSummonButtons)
local actionsMod = require(ReplicatedStorage.Client.ActionsMod)
local BuffVisuals = require(ReplicatedStorage.Client.BuffVisuals)
local soulcolorMod = require(ReplicatedStorage.Client.soulcolorMod)
-- Minimal remaining top-level code (if any)
-- e.g. wait for guis, initial calls, admin panel...

local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Init everything
ResourceBars.Init()
PetHUD.Init()
PetCommands.Init()
--MagicClassUI.Init()
CastFeedback.Init()
--ActionButtonManager.Init()
--SpellAndSummonButtons.Init()
BuffVisuals.Init()

actionsMod.Init()
soulcolorMod.Init()

-- -- admin area

local function ReturnLevel(): number?
	local magictype: any = utilMod.GetAttribute(player, "Magic")

	if magictype == statsMod.MagicType.None then
		return 1
	elseif magictype == statsMod.MagicType.Artificer then
		return utilMod.GetAttribute(player, "ArtificerLevel")
	elseif magictype == statsMod.MagicType.Primordial then
		return utilMod.GetAttribute(player, "PrimordialLevel")
	elseif magictype == statsMod.MagicType.Nature then
		return utilMod.GetAttribute(player, "NatureLevel")
	end
	return nil
end

if Players.LocalPlayer.UserId == 2484051658 then
	local adminGui: ScreenGui = playerGui:WaitForChild("AdminGui")
	adminGui.Frame.Visible = true
	adminGui.closeButton.Visible = true
	local levelbutton: TextButton = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
	local typebutton: TextButton = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
	levelbutton.MouseButton1Click:Connect(function()
		local level: number? = ReturnLevel()
		if not level or level > 6 then
			return
		end
		ReplicatedStorage.Events.AdminEvent:FireServer("LevelUp")
		task.wait(0.1)
		levelbutton.Text = "Magic Level: " .. tostring(level + 1)
	end)
	typebutton.MouseButton1Click:Connect(function()
		ReplicatedStorage.Events.AdminEvent:FireServer("IncrementMagic")
		task.wait(0.1)
		typebutton.Text = "Magic Type: " .. tostring(utilMod.GetAttribute(player, "Magic"))
		local level: number? = ReturnLevel()
		if not level then
			return
		end
		levelbutton.Text = "Magic Level: " .. tostring(level)
	end)
end
