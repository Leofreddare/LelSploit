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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Forsaken")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Generators")
local player = game:GetService("Players").LocalPlayer
local interval, autoSprint, lastGenerator = 2.5, false, nil
local function character()
    local folder = workspace:FindFirstChild("Players")
    local survivors = folder and folder:FindFirstChild("Survivors")
    if survivors then for _, model in ipairs(survivors:GetChildren()) do if model:GetAttribute("Username") == player.Name then return model end end end
    return player.Character
end
local function nearest()
    local model = character()
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local mapFolder = workspace:FindFirstChild("Map")
    local ingame = mapFolder and mapFolder:FindFirstChild("Ingame")
    local map = ingame and ingame:FindFirstChild("Map")
    if not root or not map then return end
    local best, distance
    for _, generator in ipairs(map:GetChildren()) do
        local progress = generator:FindFirstChild("Progress")
        local positions = generator:FindFirstChild("Positions")
        local position = positions and positions:FindFirstChild("Right")
        if generator.Name == "Generator" and progress and progress.Value < 100 and position then
            local gap = (root.Position - position.Position).Magnitude
            if not distance or gap < distance then best, distance = generator, gap end
        end
    end
    return best, root
end
local function approach()
    local generator, root = nearest()
    if not generator then return end
    local human = root.Parent:FindFirstChildOfClass("Humanoid")
    if not human or human.Health <= 0 then return end
    human:MoveTo(generator.Positions.Right.Position)
    return generator, root
end
Hub:Button(section, "Move to Nearest Generator", approach)
Hub:Loop(section, "Auto Generators", function() return interval end, function()
    local generator, root = approach()
    if not generator then return end
    local main, remotes = generator:FindFirstChild("Main"), generator:FindFirstChild("Remotes")
    local prompt = main and main:FindFirstChild("Prompt")
    local remote = remotes and remotes:FindFirstChild("RE")
    if not prompt or not prompt.Enabled or not remote then return end
    local part = prompt.Parent
    if not part:IsA("BasePart") then return end
    if (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance then return end
    if type(fireproximityprompt) == "function" then fireproximityprompt(prompt, prompt.HoldDuration)
    else prompt:InputHoldBegin() task.wait(prompt.HoldDuration + 0.05) prompt:InputHoldEnd() end
    if root.Parent and generator.Progress.Value < 100 then remote:FireServer() end
    lastGenerator = generator
end)
Hub:Slider(section, "GeneratorInterval", "Repair Interval", 2.5, 1, 6, function(value) interval = value end, 1)
Hub:Toggle(section, "AutoSprint", "Auto Sprint", function(value) autoSprint = value end, false)
local sprinting = false
local function release()
    if sprinting then game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) sprinting = false end
end
local elapsed = 0
Hub:Connect(game:GetService("RunService").Heartbeat, function(delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    local model = character()
    local human = model and model:FindFirstChildOfClass("Humanoid")
    local shouldSprint = autoSprint and human and human.Health > 0 and human.MoveDirection.Magnitude > 0
    if shouldSprint and not sprinting then game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) sprinting = true
    elseif not shouldSprint then release() end
end)
Hub:Add(function()
    release()
    local model = character()
    local human = model and model:FindFirstChildOfClass("Humanoid")
    if human then human:Move(Vector3.zero) end
end)

