local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Be Dino - Jurassic Dinosaur Simulation", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player.Character then player.CharacterAdded:Wait() end

local running    = false
local tweenSpeed = 100
local moverConn  = nil
local MAX_SPEED  = 3000


local function getHRP()
    local char = player.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v.Name == "RootPart" and v:IsA("BasePart") and not v.Massless then
            return v
        end
    end
    return char.PrimaryPart
end


local function getClosestFood()
    local hrp = getHRP()
    if not hrp then return nil end

    local best, bestDist = nil, math.huge

    for _, food in CollectionService:GetTagged("Food") do
        if not food or not food.Parent then continue end

        local ok, pos = pcall(function()
            if food:IsA("Model") then
                return food:GetPivot().Position
            elseif food:IsA("BasePart") then
                return food.Position
            end
        end)

        if ok and pos then
            local d = (hrp.Position - pos).Magnitude
            if d < bestDist then
                bestDist = d
                best = {instance = food, position = pos}
            end
        end
    end

    return best
end

local function stopMover()
    if moverConn then
        moverConn:Disconnect()
        moverConn = nil
    end
end

local function moveTo(targetPos)
    local reached = false
    stopMover()

    moverConn = RunService.Heartbeat:Connect(function(dt)
        local hrp = getHRP()
        if not hrp or not running then
            reached = true
            stopMover()
            return
        end

        local diff = targetPos - hrp.Position
        local dist = diff.Magnitude

        if dist < 2 then
            reached = true
            stopMover()
            return
        end

        local step = math.min(tweenSpeed * dt, dist)
        hrp.CFrame = CFrame.new(hrp.Position + diff.Unit * step)
    end)

    while not reached do
        task.wait(0.05)
    end
end


local gui = Instance.new("ScreenGui")
gui.Name = "FoodCollector"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,270,0,215)
panel.Position = UDim2.new(0.5,-135,0.5,-107)
panel.BackgroundColor3 = Color3.fromRGB(18,18,28)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.Parent = gui
Instance.new("UICorner",panel).CornerRadius = UDim.new(0,10)

local stroke = Instance.new("UIStroke",panel)
stroke.Color = Color3.fromRGB(80,80,130)
stroke.Thickness = 1.5

local titleBar = Instance.new("Frame",panel)
titleBar.Size = UDim2.new(1,0,0,38)
titleBar.BackgroundColor3 = Color3.fromRGB(35,35,58)
titleBar.BorderSizePixel = 0
Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,10)

local titleLbl = Instance.new("TextLabel",titleBar)
titleLbl.Size = UDim2.new(1,-50,1,0)
titleLbl.Position = UDim2.new(0,12,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🦖  Food Collector"
titleLbl.TextColor3 = Color3.fromRGB(230,230,255)
titleLbl.TextSize = 15
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton",titleBar)
closeBtn.Size = UDim2.new(0,26,0,26)
closeBtn.Position = UDim2.new(1,-32,0.5,-13)
closeBtn.BackgroundColor3 = Color3.fromRGB(190,50,50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)

local statusLbl = Instance.new("TextLabel",panel)
statusLbl.Size = UDim2.new(1,-20,0,22)
statusLbl.Position = UDim2.new(0,10,0,46)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Status: Idle"
statusLbl.TextColor3 = Color3.fromRGB(150,150,180)
statusLbl.TextSize = 13
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local speedLbl = Instance.new("TextLabel",panel)
speedLbl.Size = UDim2.new(1,-20,0,20)
speedLbl.Position = UDim2.new(0,10,0,94)
speedLbl.BackgroundTransparency = 1
speedLbl.Text = "Speed: 100 studs/s"
speedLbl.TextColor3 = Color3.fromRGB(150,150,180)
speedLbl.TextSize = 13
speedLbl.Font = Enum.Font.Gotham
speedLbl.TextXAlignment = Enum.TextXAlignment.Left

local track = Instance.new("Frame",panel)
track.Size = UDim2.new(1,-20,0,8)
track.Position = UDim2.new(0,10,0,122)
track.BackgroundColor3 = Color3.fromRGB(50,50,75)
track.BorderSizePixel = 0
Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

local fill = Instance.new("Frame",track)
fill.Size = UDim2.new(tweenSpeed/MAX_SPEED,0,1,0)
fill.BackgroundColor3 = Color3.fromRGB(90,160,255)
fill.BorderSizePixel = 0
Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

local knob = Instance.new("TextButton",track)
knob.Size = UDim2.new(0,20,0,20)
knob.Position = UDim2.new(tweenSpeed/MAX_SPEED,-10,0.5,-10)
knob.BackgroundColor3 = Color3.fromRGB(220,220,255)
knob.Text = ""
knob.BorderSizePixel = 0
Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

local sliderDragging = false

knob.MouseButton1Down:Connect(function()
    sliderDragging = true
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if not sliderDragging then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end

    local ratio = math.clamp(
        (inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X,
        0,
        1
    )

    tweenSpeed = math.max(1, math.floor(ratio * MAX_SPEED))

    fill.Size = UDim2.new(ratio,0,1,0)
    knob.Position = UDim2.new(ratio,-10,0.5,-10)
    speedLbl.Text = "Speed: "..tweenSpeed.." studs/s"
end)

local function makeBtn(text,color,xOffset)
    local btn = Instance.new("TextButton",panel)
    btn.Size = UDim2.new(0,112,0,36)
    btn.Position = UDim2.new(0,xOffset,0,162)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,8)
    return btn
end

local startBtn = makeBtn("▶ Start",Color3.fromRGB(40,165,70),16)
local stopBtn  = makeBtn("■ Stop",Color3.fromRGB(185,50,50),142)

local function setStatus(msg,color)
    statusLbl.Text = "Status: "..msg
    statusLbl.TextColor3 = color or Color3.fromRGB(150,150,180)
end

local function collectLoop()
    while running do

        if not player.Character then
            player.CharacterAdded:Wait()
            task.wait(1)
            continue
        end

        local food = getClosestFood()

        if not food then
            setStatus("No food nearby...",Color3.fromRGB(200,180,80))
            task.wait(0.3)
            continue
        end

        setStatus("Going to "..food.instance.Name,Color3.fromRGB(90,200,90))
        moveTo(food.position)

    end

    setStatus("Stopped")
end

startBtn.MouseButton1Click:Connect(function()
    if running then return end
    running = true
    setStatus("Running",Color3.fromRGB(90,200,90))
    task.spawn(collectLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    running = false
    stopMover()
    setStatus("Stopped")
end)

closeBtn.MouseButton1Click:Connect(function()
    running = false
    stopMover()
    gui:Destroy()
end)

setStatus("Idle")
]====])
