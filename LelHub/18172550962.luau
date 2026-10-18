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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Pixel Blade")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local cam = Workspace.CurrentCamera


local remotes = ReplicatedStorage:FindFirstChild("remotes")
if not remotes then
    warn("remotes folder not found!")
    return
end

local swingRemote = remotes:FindFirstChild("swing")
local onHitRemote = remotes:FindFirstChild("onHit")
local blockRemote = remotes:FindFirstChild("block")

if not swingRemote or not onHitRemote or not blockRemote then
    warn("Some remotes not found!")
    return
end


local auraEnabled = false
local auraRadius = 100
local AuraMode = "Nearest"
local BurstCooldown = 5
local lastBurst = 0

local speedOn = false
local speedValue = 20

local flyOn = false
local flySpeed = 40

local currentTarget
local currentHighlight
local IgnoredEnemies = {
    ["teeth trap"] = true, ["Teeth Trap"] = true,
    ["teeth_trap"] = true, ["Teeth_Trap"] = true
}


local function clearTarget()
    if currentHighlight and currentHighlight.Parent then 
        currentHighlight:Destroy() 
    end
    currentTarget = nil
    currentHighlight = nil
end

local function setTarget(m)
    if currentTarget == m then return end
    clearTarget()
    currentTarget = m
    local h = Instance.new("Highlight")
    h.FillTransparency = 1
    h.OutlineColor = Color3.fromRGB(170, 0, 0)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = m
    currentHighlight = h
end

local function getNearbyEnemies(r)
    local t = {}
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and o ~= char and not IgnoredEnemies[o.Name] then
            local h = o:FindFirstChild("Humanoid")
            local rp = o:FindFirstChild("HumanoidRootPart")
            if h and rp and h.Health > 0 then
                local d = (hrp.Position - rp.Position).Magnitude
                if d <= r then
                    table.insert(t, {obj = o, dist = d})
                end
            end
        end
    end
    table.sort(t, function(a, b) return a.dist < b.dist end)
    return t
end

local function filterByMode(list)
    if AuraMode == "Nearest" then return list end
    if AuraMode == "Cone" then
        local out = {}
        for _, e in ipairs(list) do
            local r = e.obj:FindFirstChild("HumanoidRootPart")
            if r then
                local dir = (r.Position - cam.CFrame.Position).Unit
                if cam.CFrame.LookVector:Dot(dir) >= math.cos(math.rad(45)) then
                    table.insert(out, e)
                end
            end
        end
        return out
    end
    if AuraMode == "Burst" then
        if tick() - lastBurst < BurstCooldown then return {} end
        lastBurst = tick()
        return list
    end
    return list
end


task.spawn(function()
    while task.wait(0.3) do
        if auraEnabled then
            local enemies = filterByMode(getNearbyEnemies(auraRadius))
            if #enemies > 0 then
                pcall(function()
                    swingRemote:FireServer()
                end)
                setTarget(enemies[1].obj)
                for _, e in ipairs(enemies) do
                    local h = e.obj:FindFirstChild("Humanoid")
                    if h then
                        pcall(function()
                            onHitRemote:FireServer(h, 9999999999, {}, 0)
                        end)
                    end
                end
            else
                clearTarget()
            end
        else
            clearTarget()
        end
    end
end)


task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            blockRemote:FireServer(true)
        end)
    end
end)


Hub:Connect(RunService.Heartbeat, function()
    if speedOn and hum and hum.Parent then 
        hum.WalkSpeed = speedValue 
    end
end)


local function ensureFly()
    local bv = hrp:FindFirstChild("PB_BV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "PB_BV"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent = hrp
    end
    
    local bg = hrp:FindFirstChild("PB_BG")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "PB_BG"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.Parent = hrp
    end
    return bv, bg
end

local function flyDir()
    local d = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then d = d - Vector3.new(0, 1, 0) end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end


task.spawn(function()
    while task.wait(0.02) do
        if flyOn and hrp and hrp.Parent then
            local bv, bg = ensureFly()
            bv.Velocity = flyDir() * flySpeed
            bg.CFrame = cam.CFrame
            hum.PlatformStand = true
        else
            if hum then hum.PlatformStand = false end
            local bv = hrp:FindFirstChild("PB_BV")
            local bg = hrp:FindFirstChild("PB_BG")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
    end
end)


LelUI:Control(nil, "Toggle", "Aura", auraEnabled, function(value) auraEnabled = value end)
LelUI:Control(nil, "Dropdown", "Aura mode", AuraMode, function(value) AuraMode = value end, {"Nearest", "Cone", "Burst"})
local radiusControl = LelUI:Control(nil, "Slider", "Aura radius", auraRadius, function(value) auraRadius = value end, 20, 200)
LelUI:Control(nil, "Toggle", "Speed", speedOn, function(value) speedOn = value end)
local speedControl = LelUI:Control(nil, "Slider", "WalkSpeed", speedValue, function(value) speedValue = value end, 16, 500)
LelUI:Control(nil, "Toggle", "Fly", flyOn, function(value) flyOn = value end)
local flyControl = LelUI:Control(nil, "Slider", "Fly speed", flySpeed, function(value) flySpeed = value end, 16, 80)
LelUI:Control(nil, "Dropdown", "Preset", "Default", function(value)
    if value == "Aggressive" then auraRadius = 180 speedValue = 45 flySpeed = 70 else auraRadius = 100 speedValue = 20 flySpeed = 40 end
    radiusControl:SetValue(auraRadius) speedControl:SetValue(speedValue) flyControl:SetValue(flySpeed)
end, {"Default", "Aggressive"})
Hub:Add(function()
    auraEnabled = false speedOn = false flyOn = false clearTarget()
    if hum then hum.PlatformStand = false end
    for _, name in ipairs({"PB_BV", "PB_BG"}) do local item = hrp and hrp:FindFirstChild(name) if item then item:Destroy() end end
end)

end)
