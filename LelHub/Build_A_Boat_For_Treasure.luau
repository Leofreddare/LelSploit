local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Build A Boat For Treasure", Style = "Native", Parameters = {{ Key = "Farm", Title = "Farm", Default = true },{ Key = "AntiStuck", Title = "Anti Stuck", Default = true },}, Action = "Start door farm" }, [====[
getgenv().Farm = LelHubValue("Farm", true) 
getgenv().AntiStuck = LelHubValue("AntiStuck", true) 
print("RedBlue")
while getgenv().Farm and task.wait() do
for i,v in pairs(workspace.Houses:GetChildren()) do
pcall(function()
if v:FindFirstChild("Door") and v:FindFirstChild("Door"):FindFirstChild("DoorInnerTouch") then
v:FindFirstChild("Door"):FindFirstChild("DoorInnerTouch").CanTouch = true
v:FindFirstChild("Door"):FindFirstChild("DoorInnerTouch").CanCollide = false
v:FindFirstChild("Door"):FindFirstChild("DoorInnerTouch").CFrame = game.Players.LocalPlayer.Character.PrimaryPart.CFrame * (CFrame.Angles(math.rad(math.random(1,360)), math.rad(math.random(1,360)), math.rad(math.random(1,360))) * CFrame.new(0, 0, 0))
end
end)
end
if getgenv().AntiStuck then
pcall(function()
if game.Players.LocalPlayer.Character.Humanoid.WalkSpeed == 0 then
task.wait(5.5) 
game.Players.LocalPlayer.Character.Humanoid.Health = 0
game.Players.LocalPlayer.Character:BreakJoints()
end
end)
end
end
print("RedBlue")
]====])
