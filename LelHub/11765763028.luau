local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Reign Fall")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV = 300
Hub:Slider(section, "AimFOV", "FOV", 300, 30, 1500, function(value) preferences.FOV = value end)
Hub:SourceController(section, "NPC Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local target = {
    enabled = true,
    position = nil,
    enemyContainer = nil
}
local function getEnemyContainer()
    local container = workspace.Game and workspace.Game.Current and workspace.Game.Current.Spawned and workspace.Game.Current.Spawned.NPCs
    if container then
        return container:FindFirstChild("enemies")
    end
    return nil
end
local function getClosestHead()
    local container = getEnemyContainer()
    if not container then return nil end
    local referencePos
    if isMobile then
        local vp = camera.ViewportSize
        referencePos = Vector2.new(vp.X / 2, vp.Y / 2)
    else
        referencePos = UserInputService:GetMouseLocation()
    end
    local bestHeadPos = nil
    local bestDist = preferences.FOV
    for _, enemy in ipairs(container:GetChildren()) do
        local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
        if head then
            local screenPoint, onScreen = camera:WorldToScreenPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - referencePos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestHeadPos = head.Position
                end
            end
        end
    end
    return bestHeadPos
end
current:Connect(RunService.Heartbeat, function()
    if target.enabled then
        target.position = getClosestHead()
    end
end)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if target.enabled and method:lower() == "raycast" and self == workspace then
        local args = {...}
        if #args >= 2 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
            local raycastParams = args[3]
            if raycastParams and raycastParams.CollisionGroup == "raycast_npc_neutral" then
                if target.position then
                    local origin = args[1]
                    local dir = target.position - origin
                    if dir.Magnitude > 0.001 then
                        args[2] = dir.Unit * args[2].Magnitude
                    end
                end
            end
        end
        return oldNamecall(self, unpack(args))
    end
    return oldNamecall(self, ...)
end))

end, false)
