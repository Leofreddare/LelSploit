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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Reign Fall")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV = 300
Hub:Slider(section, "AimFOV", "FOV", 300, 30, 1500, function(value) preferences.FOV = value end)
Hub:SourceController(section, "NPC Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local target = {
    enabled = true,
    position = nil,
    enemyContainer = nil
}
local function getEnemyContainer()
    local container = workspace.Game and workspace.Game.Current and workspace.Game.Current.Spawned and workspace.Game.Current.Spawned.NPCs
    if container then
        return container:FindFirstChild("enemies")
    end
    return nil
end
local function getClosestHead()
    local container = getEnemyContainer()
    if not container then return nil end
    local referencePos
    if isMobile then
        local vp = camera.ViewportSize
        referencePos = Vector2.new(vp.X / 2, vp.Y / 2)
    else
        referencePos = UserInputService:GetMouseLocation()
    end
    local bestHeadPos = nil
    local bestDist = preferences.FOV
    for _, enemy in ipairs(container:GetChildren()) do
        local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
        if head then
            local screenPoint, onScreen = camera:WorldToScreenPoint(head.Position)
            if onScreen then
                local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - referencePos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestHeadPos = head.Position
                end
            end
        end
    end
    return bestHeadPos
end
current:Connect(RunService.Heartbeat, function()
    if target.enabled then
        target.position = getClosestHead()
    end
end)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if target.enabled and method:lower() == "raycast" and self == workspace then
        local args = {...}
        if #args >= 2 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
            local raycastParams = args[3]
            if raycastParams and raycastParams.CollisionGroup == "raycast_npc_neutral" then
                if target.position then
                    local origin = args[1]
                    local dir = target.position - origin
                    if dir.Magnitude > 0.001 then
                        args[2] = dir.Unit * args[2].Magnitude
                    end
                end
            end
        end
        return oldNamecall(self, unpack(args))
    end
    return oldNamecall(self, ...)
end))

end, false)
