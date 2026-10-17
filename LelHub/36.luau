local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Survive Homelander")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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

end)
