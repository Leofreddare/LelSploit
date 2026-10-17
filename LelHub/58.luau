local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Become Hungry Worm")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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
end

local EatRemote = ReplicatedStorage:FindFirstChild("EatConsumable")
if not EatRemote then
    return
end

while true do
    EatRemote:FireServer(worm, consumable)
    task.wait(0.2)
end

end)
