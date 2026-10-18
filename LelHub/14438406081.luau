local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Wanted")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV = 300
Hub:Slider(section, "AimFOV", "FOV", 300, 30, 1500, function(value) preferences.FOV = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Devv = require(ReplicatedStorage:WaitForChild("Devv"))
local load = Devv.load
local ClientGuns = load("ClientTools").ToolModules.ClientGuns
local ClientTools = load("ClientTools")
local function getEnemies()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            table.insert(enemies, player)
        end
    end
    return enemies
end
local function getAimedDirection(originalCFrame, toolId, ownerId)
    if ownerId ~= LocalPlayer.UserId then return originalCFrame end
    local muzzlePos = originalCFrame.Position
    local bestTarget = nil
    local bestDist = preferences.FOV
    for _, enemy in ipairs(getEnemies()) do
        local head = enemy.Character and enemy.Character:FindFirstChild("Head")
        if head then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = head.Position
                end
            end
        end
    end
    return bestTarget and CFrame.lookAt(muzzlePos, bestTarget) or originalCFrame
end
local originalMakeGunProjectiles = ClientGuns.MakeGunProjectiles
ClientGuns.MakeGunProjectiles = function(ownerId, toolId, muzzleCFrame, projectilesData)
    local newProjectilesData = {}
    for _, proj in ipairs(projectilesData) do
        local projId = proj[1]
        local aimCFrame = proj[2]
        local newAimCFrame = getAimedDirection(aimCFrame, toolId, ownerId)
        table.insert(newProjectilesData, {projId, newAimCFrame})
    end
    return originalMakeGunProjectiles(ownerId, toolId, muzzleCFrame, newProjectilesData)
end

current:Add(function() ClientGuns.MakeGunProjectiles = originalMakeGunProjectiles end)

end, false)
