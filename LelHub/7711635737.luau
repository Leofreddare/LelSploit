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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Emergency Hamburg")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
Hub:SourceController(section, "Client Compatibility", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

local DetectionTable = nil
local AnticheatFolder = RS:FindFirstChild("GpP")
local blocked = 0
local EventsDetection = nil
local blockedRemotes = {}

local Anticheat_IDS = {
    "9e50ff5b-cf0f-4298-8408-c3df60fc8b16",
    "4827d0ba-b8d7-4835-8638-a638c3a05add",
    "f533d2e3-6945-4c50-98cf-d24de0cdd2eb",
    "eed59c99-087b-41a6-a6e1-4eafa101c8cf"
}

for _, v in getgc(true) do
    if type(v) == "table" then
        for _, id in pairs(Anticheat_IDS) do
            if rawget(v, id) then
                EventsDetection = v; break
            end
        end
    end
end

if EventsDetection then
    for _, v in Anticheat_IDS do
        if rawget(EventsDetection, v) then
            rawset(EventsDetection, v, newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end))
        end
    end
end

if AnticheatFolder then
    for _, id in Anticheat_IDS do
        local remote = AnticheatFolder:FindFirstChild(id)

        if remote then
            blockedRemotes[remote] = true
        end
    end
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and blockedRemotes[self] then
        blocked += 1

        return
    end

    return oldNamecall(self, ...)
end))


for _, v in getgc(true) do
    if type(v) == "table" and rawget(v, "checkWalkSpeed") and rawget(v, "checkJumpHeight") then
        DetectionTable = v

        break
    end
end

if DetectionTable then
    DetectionTable.checkWalkSpeed = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.checkJumpHeight = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.checkUseJumpPower = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.handleGuiName = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
end

local function disableHumConnections(Humanoid)
    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("WalkSpeed")) do
        con:Disable()
    end

    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("JumpHeight")) do
        con:Disable()
    end

    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("UseJumpPower")) do
        con:Disable()
    end
end

if Humanoid then
    disableHumConnections(Humanoid)
end

current:Connect(LocalPlayer.CharacterAdded, function(char)
    disableHumConnections(char:WaitForChild("Humanoid"))
end)

quiet("Bypassed Client AC! ~ Credit: $Murmansk // GongYoo - https://guns.lol/mcletshacks")

end, true)
