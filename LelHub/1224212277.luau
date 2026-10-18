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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Mad City")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.fov = 300
preferences.bodypart = "Head"
Hub:Slider(section, "AimFOV", "FOV", 300, 30, 1000, function(value) preferences.fov = value end)
Hub:Dropdown(section, "AimPart", "Target Part", { "Head", "HumanoidRootPart" }, "Head", function(value) preferences.bodypart = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
 
 
local Target
local lp = game.Players.LocalPlayer
local Mouse = lp:GetMouse()
local Circle = Drawing.new("Circle")
current:Add(function() pcall(function() Circle:Remove() end) end)
local CurrentCamera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local function GetClosest(Fov)
local Target, Closest = nil, Fov or math.huge
for i,v in pairs(game.Players:GetPlayers()) do
if (v.Character and v ~= lp and v.Character:FindFirstChild(preferences.bodypart) and v.Team ~= lp.Team and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0) then
local Position, OnScreen = CurrentCamera:WorldToScreenPoint(v.Character[preferences.bodypart].Position)
local Distance = (Vector2.new(Position.X, Position.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
if (Distance < Closest and OnScreen) then
Closest = Distance
Target = v
end
end
end

return Target
end
current:Connect(RunService.RenderStepped, function()
Circle.Radius = preferences.fov
Circle.Thickness = 2
Circle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
Circle.Transparency = 0.6
Circle.Color = Color3.fromRGB(0, 255, 155)
Circle.Visible = current.Active
Target = GetClosest(preferences.fov)
end)
local RaycastFunc = require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3
require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3 = function(...)
local args = {...}
if args[3] and args[3] == "Projectile" and Target and args[1] == CurrentCamera.CFrame.Position then
args[2] = Target.Character[preferences.bodypart].Position - args[1]
end
return RaycastFunc(unpack(args))
end

current:Add(function() require(game.ReplicatedStorage.Aero.Shared.Utilities.Numerical.VectorUtil).Raycast3 = RaycastFunc end)

end, false)
