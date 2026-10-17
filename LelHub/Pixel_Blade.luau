local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Pixel Blade", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
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


local auraEnabled = true
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


RunService.Heartbeat:Connect(function()
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


local ui = Instance.new("ScreenGui")
ui.Parent = CoreGui
ui.ResetOnSpawn = false
ui.Name = "PIXEL_BLADE_UI"

local main = Instance.new("Frame", ui)
main.Size = UDim2.new(0, 300, 0, 330)
main.Position = UDim2.new(0.03, 0, 0.32, 0)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(150, 0, 0)
stroke.Thickness = 3
stroke.Transparency = 0.35


task.spawn(function()
    while true do
        TweenService:Create(stroke, TweenInfo.new(1.5), {Transparency = 0.6}):Play()
        task.wait(1.5)
        TweenService:Create(stroke, TweenInfo.new(1.5), {Transparency = 0.35}):Play()
        task.wait(1.5)
    end
end)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36)
title.Text = "PIXEL BLADE"
title.Font = Enum.Font.Fantasy
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(170, 0, 0)
title.BackgroundTransparency = 1

local tabs = {}
local pages = {}
local tabNames = {"KILL", "MISC", "SETTINGS"}

for i, n in ipairs(tabNames) do
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(0, 90, 0, 24)
    b.Position = UDim2.new(0, (i - 1) * 95 + 10, 0, 38)
    b.Text = n
    b.Font = Enum.Font.Fantasy
    b.TextSize = 14
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)

    local p = Instance.new("Frame", main)
    p.Size = UDim2.new(1, -20, 1, -74)
    p.Position = UDim2.new(0, 10, 0, 70)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Name = n
    pages[n] = p

    b.MouseButton1Click:Connect(function()
        for _, pp in pairs(pages) do pp.Visible = false end
        p.Visible = true
    end)

    tabs[n] = b
end

pages["KILL"].Visible = true


local function slider(parent, y, text, min, max, val, cb)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Position = UDim2.new(0, 0, 0, y - 14)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.Text = text .. ": " .. val
    lbl.Font = Enum.Font.Fantasy
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Name = "SliderLabel_" .. text

    local bar = Instance.new("Frame", parent)
    bar.Position = UDim2.new(0.05, 0, 0, y)
    bar.Size = UDim2.new(0.9, 0, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    bar.Name = "SliderBar_" .. text

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    fill.Name = "SliderFill_" .. text

    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then 
            drag = true 
        end
    end)
    
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then 
            drag = false 
        end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = i.Position.X - bar.AbsolutePosition.X
            local p = math.clamp(relX / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            local v = math.floor(min + (max - min) * p)
            lbl.Text = text .. ": " .. v
            cb(v)
        end
    end)
end


local kill = pages["KILL"]

local auraBtn = Instance.new("TextButton", kill)
auraBtn.Size = UDim2.new(0.9, 0, 0, 26)
auraBtn.Position = UDim2.new(0.05, 0, 0, 0)
auraBtn.Text = "Aura : ON"
auraBtn.Font = Enum.Font.Fantasy
auraBtn.TextSize = 14
auraBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
auraBtn.TextColor3 = Color3.fromRGB(170, 0, 0)
Instance.new("UICorner", auraBtn).CornerRadius = UDim.new(1, 0)

auraBtn.MouseButton1Click:Connect(function()
    auraEnabled = not auraEnabled
    auraBtn.Text = "Aura : " .. (auraEnabled and "ON" or "OFF")
    auraBtn.TextColor3 = auraEnabled and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

local modeBtn = Instance.new("TextButton", kill)
modeBtn.Size = UDim2.new(0.9, 0, 0, 26)
modeBtn.Position = UDim2.new(0.05, 0, 0, 34)
modeBtn.Text = "Mode : Nearest"
modeBtn.Font = Enum.Font.Fantasy
modeBtn.TextSize = 14
modeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
modeBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(1, 0)

modeBtn.MouseButton1Click:Connect(function()
    if AuraMode == "Nearest" then 
        AuraMode = "Cone"
    elseif AuraMode == "Cone" then 
        AuraMode = "Burst"
    else 
        AuraMode = "Nearest" 
    end
    modeBtn.Text = "Mode : " .. AuraMode
end)

slider(kill, 78, "Radius", 20, 200, auraRadius, function(v) auraRadius = v end)


local misc = pages["MISC"]

local speedBtn = Instance.new("TextButton", misc)
speedBtn.Size = UDim2.new(0.9, 0, 0, 26)
speedBtn.Position = UDim2.new(0.05, 0, 0, 0)
speedBtn.Text = "Speed : OFF"
speedBtn.Font = Enum.Font.Fantasy
speedBtn.TextSize = 14
speedBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
speedBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", speedBtn).CornerRadius = UDim.new(1, 0)

speedBtn.MouseButton1Click:Connect(function()
    speedOn = not speedOn
    speedBtn.Text = "Speed : " .. (speedOn and "ON" or "OFF")
    speedBtn.TextColor3 = speedOn and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

slider(misc, 42, "Speed", 16, 60, speedValue, function(v) speedValue = v end)

local flyBtn = Instance.new("TextButton", misc)
flyBtn.Size = UDim2.new(0.9, 0, 0, 26)
flyBtn.Position = UDim2.new(0.05, 0, 0, 80)
flyBtn.Text = "Fly : OFF"
flyBtn.Font = Enum.Font.Fantasy
flyBtn.TextSize = 14
flyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
flyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(1, 0)

flyBtn.MouseButton1Click:Connect(function()
    flyOn = not flyOn
    flyBtn.Text = "Fly : " .. (flyOn and "ON" or "OFF")
    flyBtn.TextColor3 = flyOn and Color3.fromRGB(170, 0, 0) or Color3.fromRGB(200, 200, 200)
end)

slider(misc, 122, "Fly Speed", 16, 80, flySpeed, function(v) flySpeed = v end)


local set = pages["SETTINGS"]

local cfg = Instance.new("TextButton", set)
cfg.Size = UDim2.new(0.9, 0, 0, 26)
cfg.Position = UDim2.new(0.05, 0, 0, 0)
cfg.Text = "Config : Default"
cfg.Font = Enum.Font.Fantasy
cfg.TextSize = 14
cfg.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
cfg.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", cfg).CornerRadius = UDim.new(1, 0)

cfg.MouseButton1Click:Connect(function()
    if cfg.Text:find("Default") then
        auraRadius = 180
        speedValue = 45
        flySpeed = 70
        cfg.Text = "Config : Aggressive"
    else
        auraRadius = 100
        speedValue = 20
        flySpeed = 40
        cfg.Text = "Config : Default"
    end
end)


local themeBtn = Instance.new("TextButton", set)
themeBtn.Size = UDim2.new(0.9, 0, 0, 26)
themeBtn.Position = UDim2.new(0.05, 0, 0, 35)
themeBtn.Text = "Theme: RED"
themeBtn.Font = Enum.Font.Fantasy
themeBtn.TextSize = 14
themeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
themeBtn.TextColor3 = Color3.fromRGB(170, 0, 0)
Instance.new("UICorner", themeBtn).CornerRadius = UDim.new(1, 0)

local themes = {"RED", "DARK", "BLACK"}
local currentTheme = 1

local function applyTheme(theme)
    if theme == "RED" then
        main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        stroke.Color = Color3.fromRGB(150, 0, 0)
    elseif theme == "DARK" then
        main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        stroke.Color = Color3.fromRGB(100, 100, 100)
    elseif theme == "BLACK" then
        main.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
        stroke.Color = Color3.fromRGB(255, 255, 255)
    end
end

themeBtn.MouseButton1Click:Connect(function()
    currentTheme = currentTheme + 1
    if currentTheme > #themes then currentTheme = 1 end
    themeBtn.Text = "Theme: " .. themes[currentTheme]
    applyTheme(themes[currentTheme])
end)


local credits = Instance.new("TextLabel", set)
credits.Size = UDim2.new(1, 0, 0, 20)
credits.Position = UDim2.new(0, 0, 0, 70)
credits.BackgroundTransparency = 1
credits.Text = "discord: Fog1ch"
credits.Font = Enum.Font.Fantasy
credits.TextSize = 14
credits.TextColor3 = Color3.fromRGB(170, 0, 0)


local info = Instance.new("TextLabel", set)
info.Size = UDim2.new(1, -20, 0, 90)
info.Position = UDim2.new(0, 10, 0, 95)
info.BackgroundTransparency = 1
info.TextWrapped = true
info.TextYAlignment = Enum.TextYAlignment.Top
info.Font = Enum.Font.Fantasy
info.TextSize = 12
info.TextColor3 = Color3.fromRGB(200, 200, 200)
info.Text = "Info:\nWear sword with heavy damage skill.\nAll enemies take damage.\nChange distance in aura radius slider.\nAuto attack works when Aura is ON.\nDodge enemies and stay close."


local destroyBtn = Instance.new("TextButton", set)
destroyBtn.Size = UDim2.new(0.9, 0, 0, 26)
destroyBtn.Position = UDim2.new(0.05, 0, 0, 195)
destroyBtn.Text = "DESTROY"
destroyBtn.Font = Enum.Font.Fantasy
destroyBtn.TextSize = 14
destroyBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
destroyBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(1, 0)


local confirm = Instance.new("Frame", main)
confirm.Size = UDim2.new(0, 220, 0, 120)
confirm.Position = UDim2.new(0.5, -110, 0.5, -60)
confirm.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
confirm.Visible = false
confirm.ZIndex = 10
Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 14)

local cStroke = Instance.new("UIStroke", confirm)
cStroke.Color = Color3.fromRGB(170, 0, 0)
cStroke.Thickness = 2
cStroke.ZIndex = 10

local txt = Instance.new("TextLabel", confirm)
txt.Size = UDim2.new(1, -20, 0, 40)
txt.Position = UDim2.new(0, 10, 0, 10)
txt.BackgroundTransparency = 1
txt.Text = "Destroy script?"
txt.Font = Enum.Font.Fantasy
txt.TextSize = 16
txt.TextColor3 = Color3.new(1, 1, 1)
txt.ZIndex = 10

local yes = Instance.new("TextButton", confirm)
yes.Size = UDim2.new(0.4, 0, 0, 26)
yes.Position = UDim2.new(0.08, 0, 0, 70)
yes.Text = "YES"
yes.Font = Enum.Font.Fantasy
yes.TextSize = 14
yes.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
yes.TextColor3 = Color3.new(1, 1, 1)
yes.ZIndex = 10
Instance.new("UICorner", yes).CornerRadius = UDim.new(1, 0)

local no = Instance.new("TextButton", confirm)
no.Size = UDim2.new(0.4, 0, 0, 26)
no.Position = UDim2.new(0.52, 0, 0, 70)
no.Text = "NO"
no.Font = Enum.Font.Fantasy
no.TextSize = 14
no.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
no.TextColor3 = Color3.new(1, 1, 1)
no.ZIndex = 10
Instance.new("UICorner", no).CornerRadius = UDim.new(1, 0)

destroyBtn.MouseButton1Click:Connect(function()
    confirm.Visible = true
end)

no.MouseButton1Click:Connect(function()
    confirm.Visible = false
end)

yes.MouseButton1Click:Connect(function()
    confirm.Visible = false
    
    
    clearTarget()
    
    if flyOn then
        local bv = hrp:FindFirstChild("PB_BV")
        local bg = hrp:FindFirstChild("PB_BG")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
        if hum then hum.PlatformStand = false end
    end
    
    if hum then hum.WalkSpeed = 16 end
    
    
    if ui and ui.Parent then ui:Destroy() end
    
    
    local fpsGui = CoreGui:FindFirstChild("FPS_PING_MINI")
    if fpsGui then fpsGui:Destroy() end
    
    warn("PIXEL BLADE DESTROYED")
end)


UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif i.KeyCode == Enum.KeyCode.Backspace then
        confirm.Visible = true
    end
end)


local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "FPS_PING_MINI"
fpsGui.ResetOnSpawn = false
fpsGui.Parent = CoreGui

local fpsFrame = Instance.new("Frame", fpsGui)
fpsFrame.Size = UDim2.new(0, 180, 0, 30)
fpsFrame.Position = UDim2.new(1, -190, 0, 10)
fpsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
fpsFrame.BackgroundTransparency = 0.1
fpsFrame.Active = true
fpsFrame.Draggable = true
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 12)

local fpsLabel = Instance.new("TextLabel", fpsFrame)
fpsLabel.Size = UDim2.new(0.45, 0, 1, 0)
fpsLabel.Position = UDim2.new(0.05, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 14
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.Text = "FPS: --"
fpsLabel.TextColor3 = Color3.new(1, 1, 1)

local pingLabel = Instance.new("TextLabel", fpsFrame)
pingLabel.Size = UDim2.new(0.45, 0, 1, 0)
pingLabel.Position = UDim2.new(0.5, 0, 0, 0)
pingLabel.BackgroundTransparency = 1
pingLabel.Font = Enum.Font.GothamBold
pingLabel.TextSize = 14
pingLabel.TextXAlignment = Enum.TextXAlignment.Left
pingLabel.Text = "PING: --"
pingLabel.TextColor3 = Color3.new(1, 1, 1)

local themeBtnFPS = Instance.new("TextButton", fpsFrame)
themeBtnFPS.Size = UDim2.new(0, 20, 0, 20)
themeBtnFPS.Position = UDim2.new(0.9, 0, 0.15, 0)
themeBtnFPS.Text = "T"
themeBtnFPS.Font = Enum.Font.SourceSansBold
themeBtnFPS.TextSize = 14
themeBtnFPS.TextColor3 = Color3.new(1, 1, 1)
themeBtnFPS.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", themeBtnFPS).CornerRadius = UDim.new(0, 6)

local darkTheme = true
themeBtnFPS.MouseButton1Click:Connect(function()
    darkTheme = not darkTheme
    fpsFrame.BackgroundColor3 = darkTheme and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(230, 230, 230)
    fpsLabel.TextColor3 = darkTheme and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    pingLabel.TextColor3 = darkTheme and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    themeBtnFPS.BackgroundColor3 = darkTheme and Color3.fromRGB(35, 35, 35) or Color3.fromRGB(180, 180, 180)
end)


local fps, frames, lastTime = 0, 0, tick()
RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        fps = frames
        frames = 0
        lastTime = tick()
        fpsLabel.Text = "FPS: " .. fps
        fpsLabel.TextColor3 = fps >= 60 and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    end
end)


task.spawn(function()
    while true do
        task.wait(1)
        local success, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        
        if success then
            ping = math.floor(ping)
            pingLabel.Text = "PING: " .. ping .. "ms"
            if ping <= 80 then
                pingLabel.TextColor3 = Color3.fromRGB(0, 200, 0)
            elseif ping <= 150 then
                pingLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            else
                pingLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
            end
        end
    end
end)
]====])
