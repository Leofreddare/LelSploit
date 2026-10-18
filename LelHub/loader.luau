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

if not game:IsLoaded() then game.Loaded:Wait() end
local base = "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/"
local function read(file) return lelHubCompileRemote(base .. file, "LelHub/" .. file) end
local routes = read("g.luau")()
local environment = getgenv()
environment.LelHubCatalog = routes.C
local selected = routes.U[game.GameId] or routes.P[game.PlaceId]
local allowed = {}
for _, entry in ipairs(routes.C) do allowed[entry.File] = true end
local session = {Loading = false}
environment.LelHubLoader = session
function session.LoadModule(file, cleanup)
    if session.Loading or not allowed[file] then return false end
    session.Loading = true
    task.spawn(function()
        local ok = pcall(function()
            local chunk = read(file)
            if cleanup then cleanup() end
            chunk()
        end)
        session.Loading = false
        if not ok and file ~= "global.luau" then read("global.luau")() end
    end)
    return true
end
if not selected then pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title="LelHub",Text="LelHub doesn't support this game yet. Opening Global.",Duration=5}) end) end
session.LoadModule((selected or "global") .. ".luau")
