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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Death Ball")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StatsService = game:GetService("Stats")

local ui = require(ReplicatedFirst.ui)
if ui and ui.Inventory and ui.Inventory.Settings then
    ui.Inventory.Settings["Deflect Keybind"] = "F1"
    keypress(70)
    keyrelease(70)
end

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.FilterDescendantsInstances = {Player.Character, workspace:FindFirstChild("FX")}

local BallShadow, BallObject = nil, nil
local PreviousPosition = nil
local LastParry = 0

local SPEED_THRESHOLD = 85 
local PARRY_KEY = 112

local function GetBallColor(target)
    if not target then return Color3.new(1, 1, 1) end
    local highlight = target:FindFirstChildOfClass("Highlight")
    if highlight then return highlight.FillColor end
    return (target:IsA("BasePart") and target.Color) or Color3.new(1, 1, 1)
end

local function GetVisualHeight(shadow)
    if not shadow then return 0 end
    return math.min(((math.max(0, shadow.Size.X - 5)) * 20) + 3, 100)
end

local function TriggerParry()
    keypress(PARRY_KEY)
    keyrelease(PARRY_KEY)
end

local function IsPathBlocked(ballPos, playerPos)
    local direction = playerPos - ballPos
    local result = workspace:Raycast(ballPos, direction, RayParams)
    
    if result and result.Instance then
        if result.Instance.CanCollide and result.Instance.Transparency < 0.8 then
            return true
        end
    end
    return false
end

Hub:Connect(RunService.RenderStepped, function(dt)
    BallShadow = (BallShadow and BallShadow.Parent) and BallShadow or workspace.FX:FindFirstChild("BallShadow")
    BallObject = (BallObject and BallObject.Parent) and BallObject or (workspace:FindFirstChild("Ball") or workspace:FindFirstChild("Part"))

    if not BallShadow or not BallObject or not Player.Character or not Player.Character.PrimaryPart then  
        PreviousPosition = nil  
        return  
    end  

    local rootPart = Player.Character.PrimaryPart  
    local charPos = rootPart.Position
    local height = GetVisualHeight(BallShadow)  
    local currentPos = Vector3.new(BallShadow.Position.X, BallShadow.Position.Y + height, BallShadow.Position.Z)  

    if PreviousPosition then  
        local velocityVector = (currentPos - PreviousPosition) / dt  
        local velocityMagnitude = velocityVector.Magnitude  
        local ping = Player:GetNetworkPing()
        local ballColor = GetBallColor(BallObject)  
        
        if ballColor ~= Color3.new(1, 1, 1) then
            if IsPathBlocked(currentPos, charPos) then
                PreviousPosition = currentPos
                return
            end

            local shouldParry = false
            local distance = (charPos - currentPos).Magnitude
            
            local dirToPlayer = (charPos - currentPos).Unit
            local velDir = velocityVector.Unit
            local accuracy = velDir:Dot(dirToPlayer)

            local curveDelay = math.clamp((1 - accuracy) * 0.1, 0, 0.15)

            if velocityMagnitude < SPEED_THRESHOLD then
                local leadTime = math.clamp(0.05 + (velocityMagnitude / 600), 0.05, 0.2)  
                local predictedPos = currentPos + velocityVector * leadTime  
                local flatDistance = (Vector3.new(charPos.X, 0, charPos.Z) - Vector3.new(predictedPos.X, 0, predictedPos.Z)).Magnitude  
                local dynamicDistance = math.clamp(12 + velocityMagnitude * ping * 0.4, 8, 55)

                if flatDistance <= (dynamicDistance - (curveDelay * 10)) then
                    shouldParry = true
                end
            else
                if accuracy > 0.15 then
                    local timeToImpact = distance / velocityMagnitude
                    local reactionWindow = 0.1 + (ping * 1.2) + (dt * 1.5) - curveDelay

                    if timeToImpact <= reactionWindow then
                        shouldParry = true
                    end
                end
            end

            if shouldParry then
                local jitter = math.random() * 0.02
                local safeDelay = math.clamp(0.02 + (velocityMagnitude / 250), 0.01, 0.1)
                
                if (tick() - LastParry) > (safeDelay + jitter) then
                    TriggerParry()
                    LastParry = tick()
                end
            end
        end  
    end  

    PreviousPosition = currentPos
end)

local active = false
LelUI:Control(nil, "Toggle", "Fast parry", false, function(value)
    active = value
    if active then
        task.spawn(function()
            while active do
                TriggerParry()
                task.wait(0.01)
            end
        end)
    end
end)
Hub:Add(function() active = false end)

end)
