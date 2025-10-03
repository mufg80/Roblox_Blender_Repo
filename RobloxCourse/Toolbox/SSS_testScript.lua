local repStore = game:GetService("ReplicatedStorage")
local testEvent = repStore:WaitForChild("testEvent")


local function ClientMessage(plr, msg)
	local msgforClient = plr.Name..msg
	print(msgforClient)
	testEvent:FireClient(plr, msgforClient)
	task.wait(3)
	testEvent:FireAllClients("Welcome to the game!")
end
testEvent.OnServerEvent:Connect(ClientMessage)