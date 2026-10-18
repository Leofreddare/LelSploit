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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Scoped")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
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

current:Add(function() CameraController.GetAimRay = originalGetAimRay end)

end, false)
