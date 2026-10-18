local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Become Hungry Worm")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local preferences = {}
preferences.Interval = 0.2
Hub:Slider(section, "EatInterval", "Eat Interval", 0.2, 0.1, 3, function(value) preferences.Interval = value end, 1)
Hub:SourceController(section, "Auto Eat", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local wormName = "Worm-" .. LocalPlayer.Name
local worm = Workspace.Worms:FindFirstChild(wormName)

if not worm then
    return
end

local function findNilConsumable()
    for _, obj in pairs(getnilinstances()) do
        if obj:IsA("BasePart") and (obj.Name == "FirstApple" or obj.Name == "Meat" or obj.Name == "Burger") then
            return obj
        end
    end
    return nil
end

local consumable = findNilConsumable()

if not consumable then
    consumable = Instance.new("Part")
    consumable.Name = "FirstApple"
    consumable.Size = Vector3.new(1, 1, 1)
    consumable.Anchored = true
    consumable.CanCollide = false
    consumable.Transparency = 0
    consumable.Parent = nil
    current:Add(function() consumable:Destroy() end)
end

local EatRemote = ReplicatedStorage:FindFirstChild("EatConsumable")
if not EatRemote then
    return
end

while true do
    EatRemote:FireServer(worm, consumable)
    task.wait(preferences.Interval)
end

end, false)
