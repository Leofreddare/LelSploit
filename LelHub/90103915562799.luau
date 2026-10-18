local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Free Admin Troll Tower")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local UIS = game:GetService("UserInputService")


local teleportEnabled = false
local teleportPosition = CFrame.new(197.075165, 435.925659, 100.179222, -0.0237780642, 0.00502187805, 0.999704659, -1.92310317e-11, 0.999987364, -0.00502329832, -0.999717236, 0, 0)

LelUI:Control(nil, "Toggle", "Farm wins", false, function(value) teleportEnabled = value end)
Hub:Add(function() teleportEnabled = false end)

task.spawn(function()
	while true do
		task.wait(3.01)
		if teleportEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			player.Character:MoveTo(teleportPosition.Position)
		end
	end
end)

end)
