local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Survive Homelander")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Map")
Hub:Button(section, "Teleport to Random Spawn", function()
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local map = workspace:FindFirstChild("ActiveMap")
local folder = map and map:FindFirstChild("VSpawns")
local spawns = folder and folder:GetChildren() or {}
local validSpawns = {}
for _, spawn in ipairs(spawns) do
    if spawn and spawn:IsA("BasePart") then
        table.insert(validSpawns, spawn)
    end
end

if #validSpawns > 0 then
    local randomSpawn = validSpawns[math.random(1, #validSpawns)]
    humanoidRootPart.CFrame = randomSpawn.CFrame
    print("Teleported to:", randomSpawn.Name)
else
    warn("No valid spawns found!")
end

end)

