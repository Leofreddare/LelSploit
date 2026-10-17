local FLY_SPEED      = 60
local DRIVE_SPEED    = 250
local WHEELIE_ANGLE  = 30
local FLY_MIN,   FLY_MAX   = 10, 400
local DRIVE_MIN, DRIVE_MAX = 50, 1400
local DRIVE_HOVER    = 2.5

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local mode        = "off"
local wheelieOn   = false
local aimOn       = false

local currentVehicle, vehicleRoot = nil, nil
local bodyVelocity, bodyGyro      = nil, nil
local alignAttach, alignOrient    = nil, nil

local connections = {}
local function track(c) table.insert(connections, c); return c end

local C = {
    bg     = Color3.fromRGB(22, 22, 28),
    top    = Color3.fromRGB(30, 30, 40),
    stroke = Color3.fromRGB(56, 56, 70),
    text   = Color3.fromRGB(234, 234, 244),
    muted  = Color3.fromRGB(132, 132, 150),
    accent = Color3.fromRGB(108, 152, 255),
    btn    = Color3.fromRGB(40, 40, 50),
    btnH   = Color3.fromRGB(54, 54, 68),
    on     = Color3.fromRGB(96, 190, 140),
    aimOn  = Color3.fromRGB(160, 110, 240),
    wheelOn= Color3.fromRGB(230, 110, 110),
}

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local existing  = playerGui:FindFirstChild("LunarVehicle")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LunarVehicle"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function createSlider(parent, y, labelText, minV, maxV, initialV, accentColor, onChange)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -24, 0, 42)
    holder.Position = UDim2.new(0, 12, 0, y)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = C.text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0, 16)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(initialV)
    valueLabel.TextColor3 = accentColor or C.accent
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = holder

    local trackFrame = Instance.new("Frame")
    trackFrame.Size = UDim2.new(1, 0, 0, 6)
    trackFrame.Position = UDim2.new(0, 0, 0, 26)
    trackFrame.BackgroundColor3 = Color3.fromRGB(46, 46, 58)
    trackFrame.BorderSizePixel = 0
    trackFrame.Parent = holder
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = trackFrame

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = accentColor or C.accent
    fill.BorderSizePixel = 0
    fill.Parent = trackFrame
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(236, 236, 246)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = trackFrame
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.new(1, 0, 0, 20)
    hitbox.Position = UDim2.new(0, 0, 0.5, 0)
    hitbox.AnchorPoint = Vector2.new(0, 0.5)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.AutoButtonColor = false
    hitbox.Parent = trackFrame

    local function setValue(v, fire)
        v = math.clamp(v, minV, maxV)
        local p = (v - minV) / (maxV - minV)
        fill.Size  = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        valueLabel.Text = tostring(math.floor(v + 0.5))
        if fire then onChange(v) end
    end

    local sliderDragging = false
    local function updateFromX(x)
        local abs, size = trackFrame.AbsolutePosition.X, trackFrame.AbsoluteSize.X
        if size <= 0 then return end
        local p = math.clamp((x - abs) / size, 0, 1)
        setValue(minV + p * (maxV - minV), true)
    end

    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
            updateFromX(input.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end))

    setValue(initialV, false)
    return holder
end

local W, TOP    = 240, 34
local BODY_H    = 286
local H         = TOP + BODY_H

local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(0, W, 0, H)
shadow.Position = UDim2.new(0.5, -W/2 + 4, 0.5, -H/2 + 4)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
shadow.Parent = screenGui
local shc = Instance.new("UICorner"); shc.CornerRadius = UDim.new(0, 10); shc.Parent = shadow

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, W, 0, H)
mainFrame.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ZIndex = 1
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 10); mainCorner.Parent = mainFrame
local mainStroke = Instance.new("UIStroke");  mainStroke.Color = C.stroke; mainStroke.Thickness = 1; mainStroke.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, TOP)
topBar.BackgroundColor3 = C.top
topBar.BorderSizePixel = 0
topBar.ZIndex = 2
topBar.Parent = mainFrame
local topCorner = Instance.new("UICorner"); topCorner.CornerRadius = UDim.new(0, 10); topCorner.Parent = topBar

local topPatch = Instance.new("Frame")
topPatch.Size = UDim2.new(1, 0, 0, 12)
topPatch.Position = UDim2.new(0, 0, 1, -12)
topPatch.BackgroundColor3 = C.top
topPatch.BorderSizePixel = 0
topPatch.ZIndex = 2
topPatch.Parent = topBar

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(0, 3, 0, 14)
accentBar.Position = UDim2.new(0, 12, 0.5, -7)
accentBar.BackgroundColor3 = C.accent
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 4
accentBar.Parent = topBar
local abc = Instance.new("UICorner"); abc.CornerRadius = UDim.new(0, 2); abc.Parent = accentBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 24, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Lunar Vehicle"
title.TextColor3 = C.text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = topBar

local dragHandle = Instance.new("TextButton")
dragHandle.Size = UDim2.new(1, -70, 1, 0)
dragHandle.BackgroundTransparency = 1
dragHandle.Text = ""
dragHandle.AutoButtonColor = false
dragHandle.ZIndex = 4
dragHandle.Parent = topBar

local function chromeBtn(text, xOff)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 22, 0, 22)
    b.Position = UDim2.new(1, xOff, 0.5, -11)
    b.BackgroundColor3 = C.btn
    b.TextColor3 = C.muted
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = false
    b.ZIndex = 5
    b.Parent = topBar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
    b.MouseEnter:Connect(function() b.BackgroundColor3 = C.btnH; b.TextColor3 = C.text end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = C.btn;  b.TextColor3 = C.muted end)
    return b
end

local minBtn   = chromeBtn("–", -52)
local closeBtn = chromeBtn("×", -28)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -TOP)
body.Position = UDim2.new(0, 0, 0, TOP)
body.BackgroundTransparency = 1
body.ZIndex = 2
body.Parent = mainFrame

local HALF_W  = UDim2.new(0.5, -16, 0, 34)
local FULL_W  = UDim2.new(1, -24, 0, 34)
local LEFT_X  = 12
local RIGHT_X = W/2 + 4

local function modeBtn(text, xOff, size, yPos)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = UDim2.new(0, xOff, 0, yPos)
    b.BackgroundColor3 = C.btn
    b.TextColor3 = C.text
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.AutoButtonColor = false
    b.ZIndex = 10
    b.Parent = body
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
    b.MouseEnter:Connect(function()
        if b.BackgroundColor3 == C.btn then b.BackgroundColor3 = C.btnH end
    end)
    b.MouseLeave:Connect(function()
        if b.BackgroundColor3 == C.btnH then b.BackgroundColor3 = C.btn end
    end)
    return b
end

local flyBtn     = modeBtn("Fly",           LEFT_X,  HALF_W, 12)
local driveBtn   = modeBtn("Drive",         RIGHT_X, HALF_W, 12)
local aimBtn     = modeBtn("Mouse Aim",     LEFT_X,  FULL_W, 96)
local wheelieBtn = modeBtn("Auto Wheelie",  LEFT_X,  FULL_W, 138)

createSlider(body, 184, "Fly Speed",    FLY_MIN,   FLY_MAX,   FLY_SPEED,   C.accent, function(v) FLY_SPEED   = v end)
createSlider(body, 232, "Drive Speed",  DRIVE_MIN, DRIVE_MAX, DRIVE_SPEED, C.accent, function(v) DRIVE_SPEED = v end)

local function refreshButtons()
    flyBtn.BackgroundColor3     = (mode == "fly")   and C.on     or C.btn
    driveBtn.BackgroundColor3   = (mode == "drive") and C.on     or C.btn
    aimBtn.BackgroundColor3     = aimOn             and C.aimOn  or C.btn
    wheelieBtn.BackgroundColor3 = wheelieOn         and C.wheelOn or C.btn
end
refreshButtons()

local panelDragging, dragStart, startPos = false, nil, nil
dragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = true
        dragStart = input.Position
        startPos  = mainFrame.Position
    end
end)
track(UserInputService.InputChanged:Connect(function(input)
    if panelDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        shadow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X + 4, startPos.Y.Scale, startPos.Y.Offset + delta.Y + 4)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = false
    end
end))

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    topPatch.Visible = not minimized
    minBtn.Text = minimized and "+" or "–"
    mainFrame.Size = minimized and UDim2.new(0, W, 0, TOP) or UDim2.new(0, W, 0, H)
    shadow.Visible = not minimized
end)

local function getVehicle()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if not seat then return nil end
    local vehicle = seat.Parent
    if not vehicle or not vehicle:IsA("Model") then vehicle = seat end
    return vehicle, seat
end

local function releaseAlign()
    if alignOrient then alignOrient:Destroy(); alignOrient = nil end
    if alignAttach then alignAttach:Destroy(); alignAttach = nil end
end

local function cleanupForces()
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro     then bodyGyro:Destroy();     bodyGyro     = nil end
    releaseAlign()
end

local function updateVehicle()
    local vehicle, seat = getVehicle()
    if vehicle then
        if currentVehicle ~= vehicle then
            cleanupForces()
            currentVehicle = vehicle
            vehicleRoot = (vehicle:IsA("Model") and (vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart"))) or seat
            if vehicleRoot and vehicle:IsA("Model") then
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") then part.Anchored = false end
                end
            end
        end
    else
        if currentVehicle then
            cleanupForces()
            currentVehicle, vehicleRoot = nil, nil
        end
    end
end

local function ensureVelocity3D()
    if not vehicleRoot then return end
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.P = 1000
        bodyVelocity.Parent = vehicleRoot
    end
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
end

local function ensureVelocityGround()
    if not vehicleRoot then return end
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.P = 2000
        bodyVelocity.Parent = vehicleRoot
    end
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
end

local function ensureBodyGyro()
    if not vehicleRoot then return end
    if not bodyGyro then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.P = 1000
        bodyGyro.D = 50
        bodyGyro.Parent = vehicleRoot
    end
end

local function disableBodyGyro()
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
end

local function ensureAlign()
    if not vehicleRoot then return end
    if not alignAttach or not alignAttach.Parent then
        alignAttach = Instance.new("Attachment")
        alignAttach.Parent = vehicleRoot
    end
    if not alignOrient or not alignOrient.Parent then
        alignOrient = Instance.new("AlignOrientation")
        alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOrient.Attachment0 = alignAttach
        alignOrient.RigidityEnabled = true
        alignOrient.Enabled = false
        alignOrient.Parent = vehicleRoot
    end
end

local function setAlign(cf)
    if cf then
        ensureAlign()
        alignOrient.CFrame = cf
        alignOrient.Enabled = true
    elseif alignOrient then
        alignOrient.Enabled = false
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundY()
    if not vehicleRoot then return nil end
    rayParams.FilterDescendantsInstances = { currentVehicle, LocalPlayer.Character }
    local origin = Vector3.new(vehicleRoot.Position.X, vehicleRoot.Position.Y + 500, vehicleRoot.Position.Z)
    local hit = Workspace:Raycast(origin, Vector3.new(0, -1200, 0), rayParams)
    return hit and hit.Position.Y or nil
end

local function groundInfo()
    if not vehicleRoot then return nil end
    rayParams.FilterDescendantsInstances = { currentVehicle, LocalPlayer.Character }
    local origin = Vector3.new(vehicleRoot.Position.X, vehicleRoot.Position.Y + 500, vehicleRoot.Position.Z)
    local hit = Workspace:Raycast(origin, Vector3.new(0, -1200, 0), rayParams)
    return hit
end

local function setMode(newMode)
    mode = newMode
    if mode == "off" and not (wheelieOn or aimOn) then cleanupForces() end
    refreshButtons()
end

flyBtn.MouseButton1Click:Connect(function()   setMode(mode == "fly" and "off" or "fly") end)
driveBtn.MouseButton1Click:Connect(function() setMode(mode == "drive" and "off" or "drive") end)

aimBtn.MouseButton1Click:Connect(function()
    aimOn = not aimOn
    if not aimOn and not wheelieOn and mode == "off" then cleanupForces() end
    refreshButtons()
end)

wheelieBtn.MouseButton1Click:Connect(function()
    wheelieOn = not wheelieOn
    if not wheelieOn and not aimOn and mode == "off" then cleanupForces() end
    refreshButtons()
end)

local mainLoop = RunService.RenderStepped:Connect(function(dt)
    updateVehicle()
    if not vehicleRoot then return end

    local camCF    = Camera.CFrame
    local camLook  = camCF.LookVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
    if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit else flatLook = Vector3.new(0, 0, -1) end
    local worldUp  = Vector3.new(0, 1, 0)

    local function pitched(base, deg)
        local r = math.rad(deg)
        return base * math.cos(r) + worldUp * math.sin(r)
    end

    local carLook = vehicleRoot.CFrame.LookVector
    local carFlat = Vector3.new(carLook.X, 0, carLook.Z)
    if carFlat.Magnitude > 0.001 then carFlat = carFlat.Unit else carFlat = flatLook end

    local function alignmentCF(baseDir)
        local dir = baseDir
        if wheelieOn then dir = pitched(dir, WHEELIE_ANGLE) end
        return CFrame.lookAt(vehicleRoot.Position, vehicleRoot.Position + dir, worldUp)
    end

    if mode == "off" then
        if wheelieOn or aimOn then
            if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
            disableBodyGyro()
            local base = aimOn and flatLook or carFlat
            setAlign(alignmentCF(base))
        else
            setAlign(nil)
        end

    elseif mode == "fly" then
        setAlign(nil)
        ensureVelocity3D(); ensureBodyGyro()

        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += worldUp end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= worldUp end
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end

        bodyVelocity.Velocity = moveDir * FLY_SPEED
        bodyGyro.CFrame = camCF

    elseif mode == "drive" then
        disableBodyGyro()

        local axis = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then axis += 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then axis -= 1 end

        local hit = groundInfo()
        local groundYVal = hit and hit.Position.Y or nil
        local targetY = groundYVal and (groundYVal + vehicleRoot.Size.Y / 2 + DRIVE_HOVER) or nil

        ensureVelocityGround()

        local v = carFlat * (axis * DRIVE_SPEED)

        if targetY then
            local diff = targetY - vehicleRoot.Position.Y
            local yVel = math.clamp(diff * 8, -80, 80)

            if vehicleRoot.Position.Y < targetY - 1 then
                local rot = vehicleRoot.CFrame - vehicleRoot.Position
                vehicleRoot.CFrame = CFrame.new(vehicleRoot.Position.X, targetY, vehicleRoot.Position.Z) * rot
                yVel = 0
            end

            bodyVelocity.Velocity = Vector3.new(v.X, yVel, v.Z)
        else
            bodyVelocity.Velocity = Vector3.new(v.X, -20, v.Z)
        end

        if aimOn or wheelieOn then
            local base = aimOn and flatLook or carFlat
            setAlign(alignmentCF(base))
        else
            setAlign(nil)
        end
    end
end)
table.insert(connections, mainLoop)

track(LocalPlayer.CharacterAdded:Connect(function()
    wait(0.1)
    setMode("off")
    wheelieOn = false
    aimOn = false
    refreshButtons()
    updateVehicle()
end))

closeBtn.MouseButton1Click:Connect(function()
    cleanupForces()
    currentVehicle, vehicleRoot = nil, nil
    mode = "off"
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
    screenGui:Destroy()
end)