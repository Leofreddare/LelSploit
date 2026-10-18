local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Tsunami Game")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Coins")
local interval = 0.3
local function nearest()
    local player = game:GetService("Players").LocalPlayer
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local folder = workspace:FindFirstChild("CurrentPointCoins")
    if not root or not folder then return end
    local best, gap
    for _, part in ipairs(folder:GetDescendants()) do
        if part:IsA("BasePart") then local distance = (part.Position - root.Position).Magnitude if not gap or distance < gap then best, gap = part, distance end end
    end
    if best then root.CFrame = best.CFrame root.AssemblyLinearVelocity = Vector3.zero end
end
Hub:Loop(section, "Auto Coins", function() return interval end, nearest)
Hub:Slider(section, "CoinInterval", "Collect Interval", 0.3, 0.1, 3, function(value) interval = value end, 1)
Hub:Button(section, "Teleport to Nearest Coin", nearest)

