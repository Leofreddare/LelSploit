local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Survive Homelander", Style = "Native", Parameters = {}, Action = "Teleport to spawn" }, [====[
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local spawns = {
    workspace.ActiveMap.VSpawns:GetChildren()[7],
    workspace.ActiveMap.VSpawns.TempVSpawn,
    workspace.ActiveMap.VSpawns:GetChildren()[4],
    workspace.ActiveMap.VSpawns:GetChildren()[2],
    workspace.ActiveMap.VSpawns:GetChildren()[5],
    workspace.ActiveMap.VSpawns:GetChildren()[3],
    workspace.ActiveMap.VSpawns:GetChildren()[6]
}


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
]====])
