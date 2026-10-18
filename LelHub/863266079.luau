local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Apocalypse Rising 2")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local targetName = ""
Hub:Input("Target username", "", function(value) targetName = value end)
Hub:Button(Hub.Tabs.Game, "Follow target", function()
local target = targetName 
local behindOffset = 10 

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local stableTime = 0
local lastTeleportPos = nil

while true do
    local targetPlayer = Players:FindFirstChild(target)
    if not targetPlayer or not player.Character or not targetPlayer.Character then break end

    local myRoot = player.Character.HumanoidRootPart
    local targetRoot = targetPlayer.Character.HumanoidRootPart
    if not myRoot or not targetRoot then break end

    if lastTeleportPos then
        local myRootPos = myRoot.Position
        local teleportCheck = math.abs(myRootPos.X - lastTeleportPos.X) >= 100 or math.abs(myRootPos.Y - lastTeleportPos.Y) >= 100 or math.abs(myRootPos.Z - lastTeleportPos.Z) >= 100

        if teleportCheck then
            stableTime = 0
        else
            stableTime = stableTime + 0.09
            if stableTime >= 1.0 then
                break
            end
        end
    end

    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, behindOffset)
    lastTeleportPos = myRoot.Position
    task.wait(0.09)
end

end)
