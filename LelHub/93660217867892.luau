local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Voxels")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local player = game:GetService("Players").LocalPlayer
local radius, interval, hollow = 12, 0.1, false
local building, generation = false, 0
local tab = Hub.Tabs.Game
LelUI:Control(nil, "Slider", "Sphere Radius", radius, function(value) radius = math.floor(value) end, 3, 24)
LelUI:Control(nil, "Slider", "Build Interval", interval, function(value) interval = value end, 0.05, 1)
LelUI:Control(nil, "Toggle", "Hollow Sphere", hollow, function(value) hollow = value end)
Hub:Button(tab, "Build Sphere", function()
    if building then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local event = remotes and remotes:FindFirstChild("PlaceBlock")
    local base = workspace:FindFirstChild("1Grass")
    if not root or not base or not event or not event:IsA("RemoteEvent") then return Hub:Notify("Block placement is unavailable.") end
    generation = generation + 1
    local current, size, shell, delay, center = generation, radius, hollow, interval, root.Position
    building = true
    task.spawn(function()
        local success = pcall(function()
            for x = -size, size, 3 do
                for y = -size, size, 3 do
                    for z = -size, size, 3 do
                        if Hub.Stopped or generation ~= current then return end
                        local offset = Vector3.new(x, y, z)
                        if offset.Magnitude <= size and (not shell or offset.Magnitude >= size - 3) then
                            event:FireServer(base, Enum.NormalId.Top, center + offset, "Oak Planks")
                            task.wait(delay)
                        end
                    end
                end
            end
        end)
        if generation == current then building = false end
        if not success and not Hub.Stopped then Hub:Notify("Block placement could not complete.") end
    end)
end)
Hub:Button(tab, "Cancel Build", function() generation = generation + 1 building = false end)
Hub:Add(function() generation = generation + 1 building = false end)

end)
