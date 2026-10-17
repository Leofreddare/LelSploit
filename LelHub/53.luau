local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Scoped")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local function getValidEnemies()
    local enemies = {}
    local charactersFolder = workspace:FindFirstChild("PlayersCharacters")
    if not charactersFolder then return enemies end
    for _, model in ipairs(charactersFolder:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local humanoid = model:FindFirstChild("Humanoid")
            local head = model:FindFirstChild("Head")
            if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
                if not model:FindFirstChild("ForceField") then
                    table.insert(enemies, {model = model, head = head})
                end
            end
        end
    end
    return enemies
end
local function getClosestEnemyToCrosshair()
    local enemies = getValidEnemies()
    if #enemies == 0 then return nil end
    local viewportSize = Camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local bestEnemy = nil
    local bestDistance = math.huge
    for _, enemy in ipairs(enemies) do
        local headPos = enemy.head.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(headPos)
        if onScreen then
            local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                bestEnemy = enemy
            end
        end
    end
    if not bestEnemy then
        local cameraPos = Camera.CFrame.Position
        local minDist = math.huge
        for _, enemy in ipairs(enemies) do
            local dist = (enemy.head.Position - cameraPos).Magnitude
            if dist < minDist then
                minDist = dist
                bestEnemy = enemy
            end
        end
    end
    return bestEnemy
end
local CameraController = require(game:GetService("ReplicatedStorage").Utils.CameraController)
local originalGetAimRay = CameraController.GetAimRay
CameraController.GetAimRay = function(self, ...)
    local origin, _ = originalGetAimRay(self, ...)
    local targetEnemy = getClosestEnemyToCrosshair()
    if targetEnemy then
        local headPos = targetEnemy.head.Position
        local direction = (headPos - origin).Unit
        return origin, direction
    else
        return originalGetAimRay(self, ...)
    end
end

end)
