-- --!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local utilMod = require(ReplicatedStorage.Shared.utilMod)
local statsMod = require(ReplicatedStorage.Shared.statsMod)
-- other shared mods as needed...

local ResourceBars = require(ReplicatedStorage.Client.resourcebarsMod)
local pethudMod = require(ReplicatedStorage.Client.pethudMod)
local petcommandsMod = require(ReplicatedStorage.Client.petcommandsMod)
local castfeedbackMod = require(ReplicatedStorage.Client.castfeedbackMod)
local actionMod = require(ReplicatedStorage.Client.actionMod)
local buffvisualsMod = require(ReplicatedStorage.Client.buffvisualsMod)
local soulcolorMod = require(ReplicatedStorage.Client.soulcolorMod)
local messageMod = require(ReplicatedStorage.Client.messageMod)
-- Minimal remaining top-level code (if any)
-- e.g. wait for guis, initial calls, admin panel...

local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Init everything
messageMod.Init()
ResourceBars.Init()
pethudMod.Init()
petcommandsMod.Init()
--MagicClassUI.Init()
castfeedbackMod.Init()
--ActionButtonManager.Init()
--SpellAndSummonButtons.Init()
buffvisualsMod.Init()

actionMod.Init()
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
	if adminGui and adminGui:IsA("ScreenGui") then
		local frame = adminGui:WaitForChild("Frame")
		if frame and frame:IsA("Frame") then
			frame.Visible = true
		end
		local closebut = adminGui:WaitForChild("closeButton")
		if closebut and closebut:IsA("TextButton") then
			closebut.Visible = true
		end
	end
	local levelbutton: Instance? = adminGui:WaitForChild("Frame"):WaitForChild("LevelButton")
	local typebutton: Instance? = adminGui:WaitForChild("Frame"):WaitForChild("TypeButton")
	if levelbutton and levelbutton:IsA("TextButton") then
		levelbutton.MouseButton1Click:Connect(function()
			local level: number? = ReturnLevel()
			if not level or level > 6 then
				return
			end
			ReplicatedStorage.Events.AdminEvent:FireServer("LevelUp")
			task.wait(0.1)
			levelbutton.Text = "Magic Level: " .. tostring(level + 1)
		end)
		if typebutton and typebutton:IsA("TextButton") then
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
	end
end
