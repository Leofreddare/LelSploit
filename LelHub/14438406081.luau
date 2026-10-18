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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Wanted")
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
