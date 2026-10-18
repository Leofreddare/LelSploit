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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Become Hungry Worm")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local preferences = {}
preferences.Interval = 0.2
Hub:Slider(section, "EatInterval", "Eat Interval", 0.2, 0.1, 3, function(value) preferences.Interval = value end, 1)
Hub:SourceController(section, "Auto Eat", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local wormName = "Worm-" .. LocalPlayer.Name
local worm = Workspace.Worms:FindFirstChild(wormName)

if not worm then
    return
end

local function findNilConsumable()
    for _, obj in pairs(getnilinstances()) do
        if obj:IsA("BasePart") and (obj.Name == "FirstApple" or obj.Name == "Meat" or obj.Name == "Burger") then
            return obj
        end
    end
    return nil
end

local consumable = findNilConsumable()

if not consumable then
    consumable = Instance.new("Part")
    consumable.Name = "FirstApple"
    consumable.Size = Vector3.new(1, 1, 1)
    consumable.Anchored = true
    consumable.CanCollide = false
    consumable.Transparency = 0
    consumable.Parent = nil
    current:Add(function() consumable:Destroy() end)
end

local EatRemote = ReplicatedStorage:FindFirstChild("EatConsumable")
if not EatRemote then
    return
end

while true do
    EatRemote:FireServer(worm, consumable)
    task.wait(preferences.Interval)
end

end, false)
