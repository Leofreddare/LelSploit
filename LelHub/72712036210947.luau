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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Fix It Up!")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local vehiclesFolder = Workspace:WaitForChild("Vehicles")

local AlertSoundID = 9118805558
local SoundVolume = 5

local notifiedVehicles = {} 
local selectedLoc = "Junkyard"
local menuOpen = true
local running = true

local locations = {
    ["Junkyard"] = Vector3.new(-1659.89, 4.25, -343.20),
    ["Garage"]   = Vector3.new(-1914.75, 4.28, -562.92),
    ["Shop"]     = Vector3.new(-1466.5, 5.2, -536.0),
    ["Bank"]     = Vector3.new(-1455.0, 5.5, -750.5),
    ["Sell/Auc"] = Vector3.new(-1910, 3.9, -815.2),
    ["Repair"]   = Vector3.new(-1087.20, 4.53, -339.91)
}

local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name = "DeityHub"
screenGui.ResetOnSpawn = false

local function playAlertSound()
    local sound = Instance.new("Sound")
    sound.Parent = player.PlayerGui
    sound.SoundId = "rbxassetid://" .. AlertSoundID
    sound.Volume = SoundVolume
    sound:Play()
    task.delay(5, function() sound:Destroy() end)
end

local function screenAlert(chanceText)
    if not running then return end
    playAlertSound()
    Hub:Notify("Rare vehicle: " .. chanceText .. "%")
end

local infoFrame = Instance.new("Frame", screenGui)
infoFrame.Size = UDim2.new(0, 280, 0, 110)
infoFrame.Position = UDim2.new(1, -290, 0, 15)
infoFrame.BackgroundTransparency = 1

local timerLabel = Instance.new("TextLabel", infoFrame)
timerLabel.Size = UDim2.new(1, 0, 0, 50)
timerLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
timerLabel.BackgroundTransparency = 0.3
timerLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
timerLabel.TextSize = 26
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Text = "respawn -- second"
Instance.new("UICorner", timerLabel)

local goldLabel = Instance.new("TextLabel", infoFrame)
goldLabel.Size = UDim2.new(1, 0, 0, 40)
goldLabel.Position = UDim2.new(0, 0, 0, 60)
goldLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
goldLabel.BackgroundTransparency = 0.5
goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
goldLabel.TextSize = 20
goldLabel.Font = Enum.Font.GothamBold
goldLabel.RichText = true
goldLabel.Text = "Gold: 0"
Instance.new("UICorner", goldLabel)

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 210, 0, 185)
main.Position = UDim2.new(0.5, -105, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.Active = true
Instance.new("UICorner", main)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
title.Text = " ⚡️ DEITY HUB"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
Instance.new("UICorner", title)

local container = Instance.new("Frame", main)
container.Size = UDim2.new(1, 0, 1, -35)
container.Position = UDim2.new(0, 0, 0, 35)
container.BackgroundTransparency = 1

local dropBtn = Instance.new("TextButton", container)
dropBtn.Size = UDim2.new(0.9, 0, 0, 30)
dropBtn.Position = UDim2.new(0.05, 0, 0.05, 0)
dropBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
dropBtn.Text = "📍 TO: Junkyard"
dropBtn.TextColor3 = Color3.new(1, 1, 1)
dropBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", dropBtn)

local dropFrame = Instance.new("ScrollingFrame", container)
dropFrame.Size = UDim2.new(0.9, 0, 0, 100)
dropFrame.Position = UDim2.new(0.05, 0, 0.22, 0)
dropFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
dropFrame.Visible = false
dropFrame.ZIndex = 10
dropFrame.CanvasSize = UDim2.new(0, 0, 0, 200)
dropFrame.ScrollBarThickness = 4
Instance.new("UICorner", dropFrame)
Instance.new("UIListLayout", dropFrame)

local destinations = {}
for name in pairs(locations) do table.insert(destinations, name) end
table.sort(destinations)
LelUI:Control(nil, "Dropdown", "Destination", selectedLoc, function(value) selectedLoc = value end, destinations)
local tpBtn = Instance.new("TextButton", container)
tpBtn.Size = UDim2.new(0.9, 0, 0, 35)
tpBtn.Position = UDim2.new(0.05, 0, 0.45, 0)
tpBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
tpBtn.Text = "🚀 TELEPORT"
tpBtn.TextColor3 = Color3.new(1, 1, 1)
tpBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", tpBtn)

local bestCarBtn = Instance.new("TextButton", container)
bestCarBtn.Size = UDim2.new(0.9, 0, 0, 35)
bestCarBtn.Position = UDim2.new(0.05, 0, 0.70, 0)
bestCarBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
bestCarBtn.Text = "💎 TP BEST CAR"
bestCarBtn.TextColor3 = Color3.new(1, 1, 1)
bestCarBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", bestCarBtn)

local function isRealCar(v)
    local chance = tonumber(v:GetAttribute("SpawnChance")) or 100
    local owner = v:GetAttribute("Owner") or v:FindFirstChild("Owner")
    local hasOwner = (owner and tostring(owner) ~= "" and tostring(owner) ~= "0")
    if chance <= 0 or hasOwner then return false end
    return true
end

local function findMoney()
    local hud = player.PlayerGui:FindFirstChild("HUD")
    local moneyLabel = hud and hud:FindFirstChild("Money")
    if moneyLabel then
        local clean = moneyLabel.Text:gsub("[^%d]", "")
        return tonumber(clean) or 0
    end
    return 0
end

local function applyESP()
    if not running then return end
    for _, v in pairs(vehiclesFolder:GetChildren()) do
        if not isRealCar(v) then
            if v:FindFirstChild("ESPHighlight") then v.ESPHighlight:Destroy() end
            if v:FindFirstChild("ESPGui") then v.ESPGui:Destroy() end
            continue
        end

        local chance = tonumber(v:GetAttribute("SpawnChance"))
        if chance and chance > 0 and chance <= 1 and not notifiedVehicles[v] then
            screenAlert(tostring(chance))
            notifiedVehicles[v] = true
        end

        local hl = v:FindFirstChild("ESPHighlight") or Instance.new("Highlight", v)
        hl.Name = "ESPHighlight"
        hl.FillColor = (chance and chance <= 1) and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)
        hl.FillTransparency = (chance and chance <= 1) and 0.2 or 1
        hl.OutlineTransparency = (chance and chance <= 1) and 0 or 0.7

        local bill = v:FindFirstChild("ESPGui") or Instance.new("BillboardGui", v)
        bill.Name = "ESPGui"
        bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 100, 0, 40)
        bill.StudsOffset = Vector3.new(0, 6, 0)
        
        local lab = bill:FindFirstChild("TextLabel") or Instance.new("TextLabel", bill)
        lab.BackgroundTransparency = 1
        lab.Size = UDim2.new(1, 0, 1, 0)
        lab.TextColor3 = Color3.new(1, 1, 1)
        lab.Font = Enum.Font.GothamBold
        lab.RichText = true
        
        local color = (chance and chance <= 1) and "rgb(255, 0, 0)" or "rgb(0, 255, 128)"
        lab.Text = "Body\n<font color='"..color.."'>" .. (chance or "?") .. "%</font>"
    end
end

task.spawn(function()
    while task.wait(0.5) and running do
        pcall(applyESP)
        local val = findMoney()
        goldLabel.Text = "Gold: <font color='rgb(0,255,150)'>" .. math.floor(val / 20000) .. "</font> G"
        local resp = Workspace:FindFirstChild("JunkyardRespawn", true)
        local txt = resp and resp:FindFirstChildWhichIsA("TextLabel", true)
        if txt then 
            local s = txt.Text:match("%d+")
            if s then timerLabel.Text = "respawn " .. s .. " second" end
        end
    end
end)

LelUI:Bind(tpBtn, "MouseButton1Click", "tpBtn", function()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(locations[selectedLoc] + Vector3.new(0, 5, 0)) end
end)

LelUI:Bind(bestCarBtn, "MouseButton1Click", "bestCarBtn", function()
    local best, minC = nil, 1.0000001
    for _, v in pairs(vehiclesFolder:GetChildren()) do
        if isRealCar(v) then
            local c = tonumber(v:GetAttribute("SpawnChance"))
            if c and c > 0 and c <= 1 then 
                if c < minC then minC = c best = v end
            end
        end
    end
    if best then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = best:GetPivot() + Vector3.new(0, 5, 0) end
    end
end)

Hub:Connect(UserInputService.InputBegan, function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode.Delete then
        running = false
        screenGui:Destroy()
        for _, v in pairs(vehiclesFolder:GetChildren()) do
            if v:FindFirstChild("ESPHighlight") then v.ESPHighlight:Destroy() end
            if v:FindFirstChild("ESPGui") then v.ESPGui:Destroy() end
        end
    elseif i.KeyCode == Enum.KeyCode.Insert then
        menuOpen = not menuOpen
        main.Visible = menuOpen
    elseif i.KeyCode == Enum.KeyCode.LeftControl then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
    end
end)

local d, ds, sp
Hub:Connect(main.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true ds = i.Position sp = main.Position end end)
Hub:Connect(UserInputService.InputChanged, function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then
    local delta = i.Position - ds
    main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
end end)
Hub:Connect(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

end)
