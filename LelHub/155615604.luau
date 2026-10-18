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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Prison Life")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV_Size = 100
Hub:Slider(section, "Game_FOV_Size", "FOV", 100, 30, 1000, function(value) preferences.FOV_Size = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn

local HIT_PART = "Head"

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")

local local_player = players.LocalPlayer

local fov_circle = Drawing.new("Circle")
current:Add(function() pcall(function() fov_circle:Remove() end) end)
fov_circle.Position = user_input_service:GetMouseLocation()
fov_circle.Visible = true
fov_circle.Color = Color3.fromRGB(255, 255, 255)
fov_circle.Radius = preferences.FOV_Size
current:Connect(run_service.Heartbeat, function() fov_circle.Radius = preferences.FOV_Size end)
fov_circle.Transparency = 1
fov_circle.Filled = false
fov_circle.NumSides = 64

current:Connect(run_service.PreRender, function()
    fov_circle.Position = user_input_service:GetMouseLocation()
end)

local function get_closest_player(part_name, fov)
    fov = fov or math.huge
    local closest_player = nil
    local closest_position = nil
    local closest_distance = fov

    for _, player in players:GetPlayers() do
        if player == local_player or player.Team == local_player.Team then
            continue
        end
        
        local character = player.Character
        if not character then
            continue
        end
        
        local part = character:FindFirstChild(part_name)
        if not part then
            continue
        end
        
        local screen_position = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
        if screen_position.Z <= 0 then
            continue
        end
        
        local screen_center = user_input_service:GetMouseLocation()
        local screen_distance = (Vector2.new(screen_position.X, screen_position.Y) - screen_center).Magnitude
        
        if screen_distance < closest_distance then
            closest_player = player
            closest_position = part.Position
            closest_distance = screen_distance
        end
    end

    return closest_player, closest_position
end

LPH_NO_UPVALUES = function(Function)
    return function(...)
        return Function(...)
    end
end

local castRay = filtergc("function", {Name = "castRay"}, true)
local old; old = hookfunction(castRay, LPH_NO_UPVALUES(function(...)
    local closest_player, closest_position = get_closest_player(HIT_PART, preferences.FOV_Size)
    if closest_player and closest_position then
        return closest_player.Character[HIT_PART], closest_position
    end
    return old(...)
end))

end, false)
