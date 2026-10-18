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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Empire Clash")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
Hub:SourceController(section, "Client Compatibility", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
if not game.IsLoaded then
    game.Loaded:Wait()
end

local debugMod = false
local function log(x)
    if debugMod then
        quiet(x)
    end
end

local crashFns = {
    Crash = true, HardCrash = true, GPUCrash = true,
    RAMCrash = true, KillClient = true, SetFPS = true
}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function nothing() end

local function hookTableFunctions(t)
    if rawget(t, "RegisterHitbox") then
        hookfunction(t.RegisterHitbox.Fire, nothing)
        quiet("Hooked RegisterHitbox's Fire | Potential side ban")
        return
    end
    for name, elem in t do
        if typeof(elem) == "function" then
            hookfunction(elem, nothing)
            quiet(`Hooked {name}`)
        elseif typeof(elem) == "table" then
            local remote = rawget(elem, "_re")
            if remote and remote.OnClientEvent then
                for _, con in getconnections(remote.OnClientEvent) do
                    con:Disable()
                end
            end
            hookfunction(elem.Fire, nothing)
            quiet(`Hooked {name}'s Fire`)
        end
    end
end

for _, elem in getgc(true) do
    if typeof(elem) == "table" then
        if rawget(elem, "Detected") and typeof(elem.Detected) == "function" and rawget(elem, "RLocked") then
            hookfunction(elem.Detected, function(action, reason, nocrash)
                log(`Detected: Action: {action}, Reason: {reason}, Crashing: {not nocrash}`)
                return true
            end)
            log("Hooked Detected Function")
        end
        if (rawget(elem, "ILikeToMoveItMoveIt") and rawget(elem, "CasperSlidePartTwo") and rawget(elem, "NineteenDollaFortniteGiftCard"))
            or rawget(elem, "RegisterHitbox") then
            hookTableFunctions(elem)
        end
    elseif typeof(elem) == "function" then
        local name = debug.info(elem, "n")
        if crashFns[name] or name == "crashPlayer" then
            hookfunction(elem, nothing)
            log(`Hooked Lag/Crash function : {name}`)
            if name == "crashPlayer" then
                quiet("Hooked crash")
            end
        end
    end
end

local oldNCMT
local oldIMT

oldNCMT = hookmetamethod(player, "__namecall", function(self, ...)
    if not checkcaller() and rawequal(getnamecallmethod(), "Kick") then
        return
    else
        return oldNCMT(self, ...)
    end
end)

oldIMT = hookmetamethod(game, "__index", newcclosure(function(self, k)
    if not checkcaller() and rawequal(k, "Speed") and rawequal(oldIMT(self, "ClassName"), "AnimationTack") then
        return 1
    end
    return oldIMT(self, k)
end))

workspace:SetAttribute("SillyTest", true)
workspace:GetAttributeChangedSignal("SillyTest"):Connect(function()
    workspace:SetAttribute("SillyTest", true)
end)

end, true)
