local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Tsunami Game")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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

end)
