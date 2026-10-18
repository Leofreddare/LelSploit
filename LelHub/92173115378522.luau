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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Split The Sea")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")


local CURRENT_PLOT = "Plot1"
local CURRENT_ISLAND = "Basic"
local TELEPORT_DELAY = 0.08

local ISLANDS = {"Basic", "VoidReef", "CyberTech", "RainbowReef", "RadioactiveReef"}
local PLOTS = {"Plot1", "Plot2", "Plot3", "Plot4", "Plot5"}

local lootFolder = workspace:WaitForChild("ActiveLoot")
local busy = false

LelUI:Control(nil, "Dropdown", "Island", CURRENT_ISLAND, function(value) CURRENT_ISLAND = value end, ISLANDS)
LelUI:Control(nil, "Dropdown", "Plot", CURRENT_PLOT, function(value) CURRENT_PLOT = value end, PLOTS)
Hub:Input("Teleport delay (seconds)", tostring(TELEPORT_DELAY), function(value) local number = tonumber(value) if number then TELEPORT_DELAY = number end end)


local function getSafeZone()
    local island = workspace:WaitForChild("Islands"):FindFirstChild(CURRENT_ISLAND)
    if not island then return nil end

    local plot = island:WaitForChild("Plots"):FindFirstChild(CURRENT_PLOT)
    if not plot then return nil end

    return plot:WaitForChild("Important"):FindFirstChild("SafeZone")
end

local function getMatchingLoot()
    local matches = {}

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    for _, model in ipairs(lootFolder:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("PlotName") == CURRENT_PLOT then
            local pivot = model:GetPivot()
            local distance = (pivot.Position - hrp.Position).Magnitude

            if distance <= 800 then
                table.insert(matches, model)
            end
        end
    end

    return matches
end

local function teleportOnce()
    if busy then return end
    busy = true

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    for _, model in ipairs(getMatchingLoot()) do
        if model and model.Parent then
            hrp.CFrame = model:GetPivot() + Vector3.new(0,2,0)
        end
        task.wait(TELEPORT_DELAY)
    end

    busy = false
end

local function teleportHome()
    local safeZone = getSafeZone()
    if not safeZone then return end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    hrp.CFrame = safeZone.CFrame + Vector3.new(0,3,0)
end


Hub:Button(Hub.Tabs.Game, "Collect from selected island", teleportOnce)
Hub:Button(Hub.Tabs.Game, "Return to your plot", teleportHome)


Hub:Connect(UserInputService.InputBegan, function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.G then
        teleportOnce()
    elseif input.KeyCode == Enum.KeyCode.F then
        teleportHome()
    end
end)

end)
