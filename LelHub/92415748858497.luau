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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Infinite Nights With Freddy (DOOM)")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
preferences.MAX_DISTANCE = 500
Hub:Slider(section, "Game_MAX_DISTANCE", "ESP Distance", 500, 50, 5000, function(value) preferences.MAX_DISTANCE = value end)
preferences.TEXT_SIZE = 14
Hub:Slider(section, "Game_TEXT_SIZE", "Text Size", 14, 10, 24, function(value) preferences.TEXT_SIZE = value end)
Hub:SourceController(section, "Animatronic ESP", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera


local ESP_COLOR = Color3.fromRGB(255, 0, 0)
local ESP_THICKNESS = 1
local FONT = Drawing.Fonts.UI



local espObjects = {}

local function createESP(model)
    local data = {}

    local highlight = Instance.new("BoxHandleAdornment")
    highlight.Size = model:GetExtentsSize()
    highlight.Color3 = ESP_COLOR
    highlight.AlwaysOnTop = true
    highlight.Transparency = 0.5
    highlight.ZIndex = 5
    highlight.Adornee = model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart
    highlight.Parent = game.CoreGui

    local label = Drawing.new("Text")
current:Add(function() pcall(function() label:Remove() end) end)
    label.Text = model.Name
    label.Size = preferences.TEXT_SIZE
    label.Font = FONT
    label.Color = ESP_COLOR
    label.Outline = true
    label.Center = true
    label.Visible = false

    data.highlight = highlight
    data.label = label
    data.model = model

    return data
end

local function removeESP(data)
    if data.highlight then data.highlight:Destroy() end
    if data.label then data.label:Remove() end
end

local function findAnimatronics()
    local folder = workspace:FindFirstChild("Animatronics")
    if not folder then
        quiet("No se encontró la carpeta 'Animatronics' en Workspace.")
        return
    end

    
    for _, data in pairs(espObjects) do
        removeESP(data)
    end
    espObjects = {}

    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            espObjects[model] = createESP(model)
        end
    end
end

current:Connect(RunService.RenderStepped, function()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    for model, data in pairs(espObjects) do
        if not model or not model.Parent then
            removeESP(data)
            espObjects[model] = nil
        else
            local rootOrPrimary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if rootOrPrimary then
                local position = rootOrPrimary.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(position)
                local dist = rootPart and (rootPart.Position - position).Magnitude or 0

                if onScreen and dist <= preferences.MAX_DISTANCE then
                    data.label.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                    data.label.Visible = true

                    data.label.Text = string.format("%s [%.0fm]", model.Name, dist)
                else
                    data.label.Visible = false
                end
            end
        end
    end
end)

local folder = workspace:FindFirstChild("Animatronics")
if folder then
    current:Connect(folder.ChildAdded, function(child)
        if child:IsA("Model") then
            espObjects[child] = createESP(child)
        end
    end)

    current:Connect(folder.ChildRemoved, function(child)
        if espObjects[child] then
            removeESP(espObjects[child])
            espObjects[child] = nil
        end
    end)
end

findAnimatronics()
quiet("ESP de Animatronics activado.")

current:Add(function() for _, data in pairs(espObjects) do removeESP(data) end end)

end, false)
