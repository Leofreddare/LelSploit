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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Anime Arise Evolution")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local player = game:GetService("Players").LocalPlayer
local interval, meta = 0.3, nil
local function service()
    if meta then return meta end
    local scripts = player:FindFirstChild("PlayerScripts")
    local module = scripts and scripts:FindFirstChild("MetaService")
    if not module then error("MetaService not loaded") end
    meta = require(module)
    return meta
end
local function bridge(...)
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Bridge")
    if not remote then error("Bridge not loaded") end
    remote:FireServer(...)
end
Hub:Loop(section, "Auto Attack", function() return interval end, function()
    local data = service()
    if data.Cache and data.Cache.ProximityEnemy then bridge("Attack", "Click", data.Cache.ProximityEnemy) end
end)
Hub:Loop(section, "Auto Rank", function() return 1 end, function()
    local data = service()
    local rank = data.SharedModules.Ranks[data.Data.Rank + 1]
    if rank and data.Data.Energy >= data.Utils.Number:Unformat(rank.Price) then bridge("RankUp", "Evolve") end
end)
Hub:Loop(section, "Auto Buy Zone", function() return 1 end, function()
    local data, current = service(), -1
    for name in pairs(data.Data.Inventory.Maps) do local map = data.SharedModules.Maps[name] if map and map.Index > current then current = map.Index end end
    for _, map in pairs(data.SharedModules.Maps) do
        if map.Index == current + 1 and data.Data.Gems >= data.Utils.Number:Unformat(map.Price) then bridge("Teleport", "Buy", map.Name) task.wait(0.5) if not Hub.Stopped then bridge("Teleport", "Spawn", map.Name) end return end
    end
end)
Hub:Loop(section, "Auto Achievements", function() return 2 end, function()
    local data = service()
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local ui = gui and gui:FindFirstChild("UI")
    local frames = ui and ui:FindFirstChild("Frames")
    local achievements = frames and frames:FindFirstChild("Achievements")
    local main = achievements and achievements:FindFirstChild("NewMain")
    local body = main and main:FindFirstChild("body")
    local items = body and body:FindFirstChild("items")
    if not items then return end
    for _, item in ipairs(items:GetChildren()) do
        local claimed = item:FindFirstChild("claimed")
        local fill = item:FindFirstChild("backFill")
        local progress = fill and fill:FindFirstChild("progress")
        if item:IsA("ImageLabel") and claimed and not claimed.Visible and progress then
            local left, right = progress.Text:match("([^/]+)/([^/]+)")
            if left and right then
                local value = tonumber(left:gsub(",", "")) or data.Utils.Number:Unformat(left)
                local goal = tonumber(right:gsub(",", "")) or data.Utils.Number:Unformat(right)
                if value and goal and value >= goal then bridge("Achievements", "Claim", item.Name) end
            end
        end
    end
end)
local drops = false
Hub:Toggle(section, "AutoDrops", "Auto Drops", function(value) drops = value end, false)
Hub:Slider(section, "AttackInterval", "Attack Interval", 0.3, 0.1, 2, function(value) interval = value end, 1)
Hub:Connect(workspace.DescendantAdded, function(part)
    if drops and part:IsA("Part") and part.Parent and part.Parent.Name == "Debris" and part:FindFirstChild("UID") then pcall(function() bridge("Drops", "Collect", part.Name) end) end
end)

