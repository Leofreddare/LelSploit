local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Mad City", Style = "Native", Parameters = {{ Key = "fov", Title = "fov", Default = 500 },{ Key = "bodypart", Title = "bodypart", Default = "Head" },}, Action = "Enable game features" }, [====[
getgenv().fov = LelHubValue("fov", 500) 
getgenv().bodypart = LelHubValue("bodypart", "Head") 
local Target
local lp = game.Players.LocalPlayer
local Mouse = lp:GetMouse()
local Circle = Drawing.new("Circle")
local CurrentCamera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local function GetClosest(Fov)
local Target, Closest = nil, Fov or math.huge
for i,v in pairs(game.Players:GetPlayers()) do
if (v.Character and v ~= lp and v.Character:FindFirstChild(getgenv().bodypart) and v.Team ~= lp.Team and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0) then
local Position, OnScreen = CurrentCamera:WorldToScreenPoint(v.Character[getgenv().bodypart].Position)
local Distance = (Vector2.new(Position.X, Position.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
if (Distance < Closest and OnScreen) then
Closest = Distance
Target = v
end
end
end

return Target
end
RunService.RenderStepped:Connect(function()
Circle.Radius = getgenv().fov
Circle.Thickness = 2
Circle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
Circle.Transparency = 0.6
Circle.Color = Color3.fromRGB(0, 255, 155)
Circle.Visible = true
Target = GetClosest(getgenv().fov)
end)
local RaycastFunc = require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3
require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3 = function(...)
local args = {...}
if args[3] and args[3] == "Projectile" and Target and args[1] == CurrentCamera.CFrame.Position then
args[2] = Target.Character[getgenv().bodypart].Position - args[1]
end
return RaycastFunc(unpack(args))
end
]====])
