local function lelHubFetchSource(url)
    local function text(value)
        if type(value) ~= "string" or not value:find("%S") then return end
        local start = value:sub(1, 160):gsub("^%s+", "")
        start = start:lower()
        if start:find("<!doctype", 1, true) or start:find("<html", 1, true) or start:find("404: not found", 1, true) then return end
        return value
    end
    local methods = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
    }
    local send = request or http_request or (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    if type(send) == "function" then
        table.insert(methods, function()
            local response = send({ Url = url, Method = "GET", Timeout = 15 })
            if type(response) == "string" then return response end
            if type(response) ~= "table" or response.Success == false then return end
            local status = tonumber(response.StatusCode or response.Status)
            if status and (status < 200 or status >= 300) then return end
            return response.Body or response.body
        end)
    end
    for attempt = 1, 2 do
        for _, fetch in ipairs(methods) do
            local ok, response = pcall(fetch)
            local source = ok and text(response)
            if source then return source end
        end
        if attempt < 2 then task.wait(0.25) end
    end
    error("[LelHub] Download returned no script text: " .. url, 0)
end

local function lelHubCompileRemote(url, name)
    if type(loadstring) ~= "function" then error("[LelHub] This executor does not provide loadstring.", 0) end
    local source = lelHubFetchSource(url)
    local ok, chunk, message = pcall(loadstring, source, name or "LelHub/Remote")
    if not ok or type(chunk) ~= "function" then error("[LelHub] Downloaded script could not compile: " .. tostring(message or chunk), 0) end
    return chunk
end

local function lelHubLoadInterface()
    local urls = {
        "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/f.luau",
        "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau",
    }
    local lastError
    for _, url in ipairs(urls) do
        local ok, library = pcall(function() return lelHubCompileRemote(url, "LelHub/Fluent")() end)
        if ok and type(library) == "table" and type(library.CreateWindow) == "function" then return library end
        lastError = ok and "The interface did not return a valid library." or tostring(library)
    end
    error("[LelHub] Could not load the interface. " .. tostring(lastError), 0)
end

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("THA BRONX 3")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.fovRadius = 230
Hub:Slider(section, "Game_fovRadius", "FOV", 230, 30, 1000, function(value) preferences.fovRadius = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer
local silentaimHOOK = true

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
                        if dist < closestDist and dist <= preferences.fovRadius then
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
current:Add(function() scriptEnv.Fire = originalFire end)
        scriptEnv.Fire = function(handle, hitPoint)
            if silentaimHOOK then
                local target = findClosestTarget()
                if target then
                    hitPoint = target.Position + Vector3.new(0, 0.1, 0)
                end
            end
            return originalFire(handle, hitPoint)
        end
        quiet("Successfully Hooked via getsenv")
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
current:Connect(localPlayer.CharacterAdded, tryHook)
if localPlayer.Character then tryHook() end
current:Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        silentaimHOOK = not silentaimHOOK
        quiet("getsenv", silentaimHOOK and "Hooked" or "Unhooked")
    end
end)
if showFovCircle then
    local fovCircle = Drawing.new("Circle")
current:Add(function() pcall(function() fovCircle:Remove() end) end)
    fovCircle.Thickness = 2
    fovCircle.NumSides = 64
    fovCircle.Radius = preferences.fovRadius
    fovCircle.Color = Color3.fromRGB(255, 50, 50)
    fovCircle.Transparency = 0.65
    fovCircle.Filled = false
    fovCircle.Visible = true
    game:GetService("RunService").RenderStepped:Connect(function()
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Visible = silentaimHOOK
    end)
end

end, false)
