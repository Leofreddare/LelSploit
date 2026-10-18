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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Voxels")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local player = game:GetService("Players").LocalPlayer
local radius, interval, hollow = 12, 0.1, false
local building, generation = false, 0
local tab = Hub.Tabs.Game
LelUI:Control(nil, "Slider", "Sphere Radius", radius, function(value) radius = math.floor(value) end, 3, 24)
LelUI:Control(nil, "Slider", "Build Interval", interval, function(value) interval = value end, 0.05, 1)
LelUI:Control(nil, "Toggle", "Hollow Sphere", hollow, function(value) hollow = value end)
Hub:Button(tab, "Build Sphere", function()
    if building then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local event = remotes and remotes:FindFirstChild("PlaceBlock")
    local base = workspace:FindFirstChild("1Grass")
    if not root or not base or not event or not event:IsA("RemoteEvent") then return Hub:Notify("Block placement is unavailable.") end
    generation = generation + 1
    local current, size, shell, delay, center = generation, radius, hollow, interval, root.Position
    building = true
    task.spawn(function()
        local success = pcall(function()
            for x = -size, size, 3 do
                for y = -size, size, 3 do
                    for z = -size, size, 3 do
                        if Hub.Stopped or generation ~= current then return end
                        local offset = Vector3.new(x, y, z)
                        if offset.Magnitude <= size and (not shell or offset.Magnitude >= size - 3) then
                            event:FireServer(base, Enum.NormalId.Top, center + offset, "Oak Planks")
                            task.wait(delay)
                        end
                    end
                end
            end
        end)
        if generation == current then building = false end
        if not success and not Hub.Stopped then Hub:Notify("Block placement could not complete.") end
    end)
end)
Hub:Button(tab, "Cancel Build", function() generation = generation + 1 building = false end)
Hub:Add(function() generation = generation + 1 building = false end)

end)
