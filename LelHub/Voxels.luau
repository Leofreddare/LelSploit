local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Voxels", Style = "Native", Parameters = {{ Key = "Sphere radius", Default = 20 },}, Action = "Build sphere" }, [====[
local ply = game:GetService("Players").LocalPlayer
local char = ply.Character or ply.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaceBlock = ReplicatedStorage.Remotes.PlaceBlock

local center = root.Position
local radius = math.clamp(LelHubValue("Sphere radius", 20), 3, 60) 

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
]====])
