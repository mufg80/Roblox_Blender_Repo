local cs = game:GetService("CollectionService")
local taggedParts = cs:GetTagged("myParts")



for _, tp in pairs(taggedParts)do
	local db = true
	tp.Touched:Connect(function(hit)
		local char = hit.Parent
		local hum = char:FindFirstChild("Humanoid")
		if db and hum then
			db = false
			local plr = game.Players:GetPlayerFromCharacter(char)
			print(plr.Name.." touched part.")
			tp.BrickColor = BrickColor.random()
			task.wait(1)
			db = true
		end
	end)

end

