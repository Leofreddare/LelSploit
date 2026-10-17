local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Voxels")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local ply = game:GetService("Players").LocalPlayer
local char = ply.Character or ply.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaceBlock = ReplicatedStorage.Remotes.PlaceBlock

local center = root.Position
local radius = 20 

local step = 3 

for x = -radius, radius, step do
    for y = -radius, radius, step do
        for z = -radius, radius, step do
            local offset = Vector3.new(x, y, z)
            if offset.Magnitude <= radius then
                local point = center + offset
                PlaceBlock:FireServer(
                    workspace["1Grass"],
                    Enum.NormalId.Top,
                    point,
                    "Oak Planks"
                )
            end
        end
    end
end

end)
