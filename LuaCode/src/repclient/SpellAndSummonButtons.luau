-- --!strict
-- -- ReplicatedStorage.Client.SpellAndSummonButtons

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")

-- local utilMod = require(ReplicatedStorage.Shared.utilMod)
-- local statsMod = require(ReplicatedStorage.Shared.statsMod)
-- local combatMod = require(ReplicatedStorage.Shared.combatMod)
-- local CastFeedback = require(ReplicatedStorage.Client.CastFeedback)
-- local MagicClassUI = require(ReplicatedStorage.Client.MagicClassUI)

-- local player = Players.LocalPlayer
-- local magicGui = player:WaitForChild("PlayerGui"):WaitForChild("MagicGui")

-- local creatureButtons = magicGui.CreatureFrame:GetChildren()
-- local spellButtons = magicGui.SpellFrame:GetChildren()

-- local SpellAndSummonButtons = {}

-- local globalDebounce = false

-- local function startCastAndCooldown(duration: number, buttonName: string, cooldownExtra: number?, onCast: () -> ())
-- 	if globalDebounce then return end
-- 	globalDebounce = true

-- 	local fullCooldown = duration + 1 + (cooldownExtra or 0)
-- 	CastFeedback.StartCast(duration, function()
-- 		globalDebounce = false
-- 	end)

-- 	-- Set per-button cooldown attribute (for visual disable)
-- 	if buttonName then
-- 		utilMod.SetAttribute(player, "button_" .. buttonName, time() + fullCooldown)
-- 	end

-- 	onCast()
-- end

-- function SpellAndSummonButtons.Init()
-- 	-- Creature / Summon buttons
-- 	for _, btn in creatureButtons do
-- 		if not btn:IsA("TextButton") then continue end

-- 		btn.MouseButton1Click:Connect(function()
-- 			local creatureName = utilMod.RemoveSpaces(btn.Text)
-- 			local castTime = utilMod.CreatureCastTime(creatureName)

-- 			startCastAndCooldown(castTime, creatureName, 3, function()
-- 				ReplicatedStorage.Events.SummonEvent:FireServer(creatureName)
-- 			end)
-- 		end)
-- 	end

-- 	-- Spell buttons
-- 	for _, btn in spellButtons do
-- 		if not btn:IsA("TextButton") then continue end

-- 		btn.MouseButton1Click:Connect(function()
-- 			local spellName = utilMod.RemoveSpaces(btn.Text)
-- 			local spellInfo = statsMod.SpellInfo[spellName]
-- 			if not spellInfo then return end

-- 			local castTime = spellInfo.castTime or 2
-- 			local cooldown = spellInfo.cooldown or 0

-- 			startCastAndCooldown(castTime, spellName, cooldown, function()
-- 				ReplicatedStorage.Events.SpellCastEvent:FireServer(spellName)
-- 			end)
-- 		end)
-- 	end
-- end

-- return SpellAndSummonButtons