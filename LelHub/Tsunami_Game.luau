local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Tsunami Game", Style = "Native", Parameters = {}, Action = "Start coin collection" }, [====[
while true do
    local player = game.Players.LocalPlayer
local coinFolder = workspace.CurrentPointCoins
local offset = Vector3.new(0, 4, 0)


if player.Character then
    local character = player.Character
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")  

    for _, descendant in pairs(coinFolder:GetDescendants()) do
        if descendant:IsA("Part") then
            
            humanoidRootPart.CFrame = descendant.CFrame + offset           
        end
    end
end
wait(0.1)
end
]====])
