local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Free Admin Troll Tower", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local UIS = game:GetService("UserInputService")


local teleportEnabled = false
local teleportPosition = CFrame.new(197.075165, 435.925659, 100.179222, -0.0237780642, 0.00502187805, 0.999704659, -1.92310317e-11, 0.999987364, -0.00502329832, -0.999717236, 0, 0)


local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
screenGui.Name = "ViewHubGUI"


local openButton = Instance.new("TextButton", screenGui)
openButton.Size = UDim2.new(0, 100, 0, 40)
openButton.Position = UDim2.new(0, 10, 0, 10)
openButton.Text = "Menu"
openButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 20
openButton.ZIndex = 2


local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 250, 0, 150)
mainFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.Visible = false
mainFrame.BorderSizePixel = 0


local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "SView hub"
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 22


local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 20


local farmButton = Instance.new("TextButton", mainFrame)
farmButton.Size = UDim2.new(0, 200, 0, 50)
farmButton.Position = UDim2.new(0.5, -100, 0.5, -25)
farmButton.Text = "Farm Wins"
farmButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
farmButton.TextColor3 = Color3.new(1, 1, 1)
farmButton.Font = Enum.Font.GothamBold
farmButton.TextSize = 22


farmButton.MouseEnter:Connect(function()
	farmButton:TweenSize(UDim2.new(0, 205, 0, 55), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
end)
farmButton.MouseLeave:Connect(function()
	farmButton:TweenSize(UDim2.new(0, 200, 0, 50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
end)


openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
end)


closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)


farmButton.MouseButton1Click:Connect(function()
	teleportEnabled = not teleportEnabled
	if teleportEnabled then
		farmButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	else
		farmButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	end
end)


task.spawn(function()
	while true do
		task.wait(3.01)
		if teleportEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			player.Character:MoveTo(teleportPosition.Position)
		end
	end
end)
]====])
