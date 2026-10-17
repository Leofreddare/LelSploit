local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "THA BRONX 3", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer
local silentaimHOOK = true
local fovRadius = 230
local aimAtHead = true
local showFovCircle = true
local function findClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closestPart, closestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local targetPart = aimAtHead and character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < closestDist and dist <= fovRadius then
                            closestDist = dist
                            closestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    return closestPart
end
local function hookGunScript()
    local tool = localPlayer.Character and localPlayer.Character:FindFirstChildWhichIsA("Tool")
              or localPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if not tool then return false end
    local gunScript = nil
    for _, child in ipairs(tool:GetDescendants()) do
        if child.Name == "GunScript_Local" and child.ClassName == "LocalScript" then
            gunScript = child
            break
        end
    end
    if not gunScript then return false end
    local scriptEnv = getsenv(gunScript)
    if scriptEnv and scriptEnv.Fire then
        local originalFire = scriptEnv.Fire
        scriptEnv.Fire = function(handle, hitPoint)
            if silentaimHOOK then
                local target = findClosestTarget()
                if target then
                    hitPoint = target.Position + Vector3.new(0, 0.1, 0)
                end
            end
            return originalFire(handle, hitPoint)
        end
        print("Successfully Hooked via getsenv")
        return true
    end
    return false
end
local function tryHook()
    task.wait(0.5)
    if not hookGunScript() then
        task.delay(1, tryHook)
    end
end
localPlayer.CharacterAdded:Connect(tryHook)
if localPlayer.Character then tryHook() end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.k then
        silentaimHOOK = not silentaimHOOK
        print("getsenv", silentaimHOOK and "Hooked" or "Unhooked")
    end
end)
if showFovCircle then
    local fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.NumSides = 64
    fovCircle.Radius = fovRadius
    fovCircle.Color = Color3.fromRGB(255, 50, 50)
    fovCircle.Transparency = 0.65
    fovCircle.Filled = false
    fovCircle.Visible = true
    game:GetService("RunService").RenderStepped:Connect(function()
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Visible = silentaimHOOK
    end)
end
]====])
