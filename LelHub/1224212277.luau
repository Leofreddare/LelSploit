local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Mad City")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.fov = 300
preferences.bodypart = "Head"
Hub:Slider(section, "AimFOV", "FOV", 300, 30, 1000, function(value) preferences.fov = value end)
Hub:Dropdown(section, "AimPart", "Target Part", { "Head", "HumanoidRootPart" }, "Head", function(value) preferences.bodypart = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
 
 
local Target
local lp = game.Players.LocalPlayer
local Mouse = lp:GetMouse()
local Circle = Drawing.new("Circle")
current:Add(function() pcall(function() Circle:Remove() end) end)
local CurrentCamera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local function GetClosest(Fov)
local Target, Closest = nil, Fov or math.huge
for i,v in pairs(game.Players:GetPlayers()) do
if (v.Character and v ~= lp and v.Character:FindFirstChild(preferences.bodypart) and v.Team ~= lp.Team and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0) then
local Position, OnScreen = CurrentCamera:WorldToScreenPoint(v.Character[preferences.bodypart].Position)
local Distance = (Vector2.new(Position.X, Position.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
if (Distance < Closest and OnScreen) then
Closest = Distance
Target = v
end
end
end

return Target
end
current:Connect(RunService.RenderStepped, function()
Circle.Radius = preferences.fov
Circle.Thickness = 2
Circle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
Circle.Transparency = 0.6
Circle.Color = Color3.fromRGB(0, 255, 155)
Circle.Visible = current.Active
Target = GetClosest(preferences.fov)
end)
local RaycastFunc = require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3
require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3 = function(...)
local args = {...}
if args[3] and args[3] == "Projectile" and Target and args[1] == CurrentCamera.CFrame.Position then
args[2] = Target.Character[preferences.bodypart].Position - args[1]
end
return RaycastFunc(unpack(args))
end

current:Add(function() require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3 = RaycastFunc end)

end, false)
