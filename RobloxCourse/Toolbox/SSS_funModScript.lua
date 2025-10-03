local funMod = {}

funMod.MessageDictionary = {
	["m1"] = "Hello ",
	["m2"] = "Welcome ",
	["m3"] = "Welcome to the game "
}

function funMod.GreetPlayer(plr)
	local ranNum = math.random(1,3)
	local thisMsg = funMod.MessageDictionary["m"..ranNum]
	print(thisMsg..plr.Name)
end

return funMod
