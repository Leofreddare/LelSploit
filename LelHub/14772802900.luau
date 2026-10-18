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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Jailbird")
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
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Config = {
    TargetPart = "Head",
    MaxFOV = 300,
    TeamCheck = true,
    VisibleCheck = false,
    MaxDistance = 700,
    DrawFOV = true,
}
local FOVCircle = Drawing.new("Circle")
current:Add(function() pcall(function() FOVCircle:Remove() end) end)
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Radius = Config.MaxFOV
FOVCircle.Color = Color3.fromRGB(255, 0, 100)
FOVCircle.Transparency = 0.75
FOVCircle.Visible = Config.DrawFOV
FOVCircle.Filled = false
current:Connect(RunService.RenderStepped, function()
    FOVCircle.Radius = preferences.FOV
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Visible = Config.DrawFOV
end)
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, shortest = nil, preferences.FOV
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        local char = player.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local targetPart = char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not targetPart then continue end
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < shortest then
            shortest = dist
            closest = targetPart
        end
    end
    return closest
end
local OldBulletRayCast = nil
local OldKnifeRayCast = nil
local function Redirect(origin, direction, distance, ignoreList, isKnife)
    local target = GetClosestTarget()
    if target then
        local newDirection = (target.Position - origin).Unit
        if isKnife then
            return OldKnifeRayCast(origin, newDirection, distance, ignoreList)
        else
            return OldBulletRayCast(origin, newDirection, distance, ignoreList)
        end
    end
    if isKnife then
        return OldKnifeRayCast(origin, direction, distance, ignoreList)
    else
        return OldBulletRayCast(origin, direction, distance, ignoreList)
    end
end
local function ForceHook()
    for _, v in ipairs(getgc(true)) do
        if typeof(v) == "table" and rawget(v, "BulletRayCast") and rawget(v, "KnifeRayCast") then
            if not OldBulletRayCast then
                OldBulletRayCast = v.BulletRayCast
                OldKnifeRayCast = v.KnifeRayCast
                current:Add(function() v.BulletRayCast, v.KnifeRayCast = OldBulletRayCast, OldKnifeRayCast end)
                v.BulletRayCast = function(a, b, c, d)
                    return Redirect(a, b, c, d, false)
                end
                v.KnifeRayCast = function(a, b, c, d)
                    return Redirect(a, b, c, d, true)
                end
                return true
            end
        end
    end
    return false
end
task.spawn(function()
    local tries = 0
    while tries < 25 and not OldBulletRayCast do
        if ForceHook() then
            quiet("if you see this message the silent aim will work")
            break
        end
        tries += 1
        task.wait(0.6)
    end
end)

end, false)
