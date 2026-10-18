local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Clicking Simulator Ultimate")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Clicking")
local interval, burst = 0.1, 1
local function click()
    local storage = game:GetService("ReplicatedStorage")
    local remote = storage:FindFirstChild("Taps", true)
    if not remote or not remote:IsA("RemoteEvent") then error("Click remote unavailable") end
    for index = 1, burst do remote:FireServer() end
end
Hub:Loop(section, "Auto Tap", function() return interval end, click)
Hub:Slider(section, "ClickInterval", "Click Interval", 0.1, 0.05, 3, function(value) interval = value end, 2)
Hub:Slider(section, "ClickBurst", "Clicks per Tick", 1, 1, 5, function(value) burst = math.floor(value) end)
Hub:Button(section, "Click Once", function() local ok = pcall(click) if not ok then Hub:Notify("The click remote is unavailable.") end end)

