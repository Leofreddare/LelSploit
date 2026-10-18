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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Build a Brainrot")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local storage = game:GetService("ReplicatedStorage")
local section = Hub.Tabs.Game:CreateSection("Shop")
local toolName, buildName, cash = "", "", 1000000
local function names(folder)
    local values = {}
    if folder then for _, item in ipairs(folder:GetChildren()) do table.insert(values, item.Name) end end
    table.sort(values)
    return values
end
local tools = Hub:Dropdown(section, "ShopTool", "Tool", names(storage:FindFirstChild("Tools")), nil, function(value) toolName = value end)
local builds = Hub:Dropdown(section, "ShopBuild", "Build", names(storage:FindFirstChild("Builds")), nil, function(value) buildName = value end)
local function remote(name, ...)
    local folder = storage:FindFirstChild("Remotes")
    local event = folder and folder:FindFirstChild(name)
    if event then event:FireServer(...) else Hub:Notify("The shop is not loaded.") end
end
Hub:Button(section, "Buy Selected Tool", function() if toolName ~= "" then remote("buyTool", toolName) end end)
Hub:Button(section, "Buy All Tools", function() for _, name in ipairs(names(storage:FindFirstChild("Tools"))) do remote("buyTool", name) task.wait(0.1) end end)
Hub:Button(section, "Buy Selected Build", function() if buildName ~= "" then remote("buyPlaceable", buildName) end end)
Hub:Button(section, "Refresh Shop", function() tools:SetValues(names(storage:FindFirstChild("Tools"))) builds:SetValues(names(storage:FindFirstChild("Builds"))) end)
Hub:Input("Cash Amount", "1000000", function(value) local number = tonumber(value) if number and number > 0 and number < math.huge then cash = number end end)
Hub:Button(section, "Request Cash", function() remote("giveRewards", "Cash", cash) end)

