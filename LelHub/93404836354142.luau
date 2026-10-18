local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Phonk Clicker!")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer


local gui = Instance.new("ScreenGui")
gui.Name = "iOS_CustomMenu"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")


local function makeEvent()
    local b = Instance.new("BindableEvent")
    return {
        Fire = function(_, ...) b:Fire(...)
        end,
        Connect = function(_, fn) return Hub:Connect(b.Event, fn) end
    }
end


local Controls = {
    toggles = {},
    sliders = {},
    checkboxes = {},
    colorpickers = {}
}


_G.MenuAPI = {
    OnToggle = function(label, fn)
        local c = Controls.toggles[label]
        if c then Hub:Connect(c.Changed, fn) end
    end,
    OnSlider = function(label, fn)
        local c = Controls.sliders[label]
        if c then Hub:Connect(c.Changed, fn) end
    end,
    OnCheckbox = function(label, fn)
        local c = Controls.checkboxes[label]
        if c then Hub:Connect(c.Changed, fn) end
    end,
    OnColor = function(label, fn)
        local c = Controls.colorpickers[label]
        if c then Hub:Connect(c.Changed, fn) end
    end,
    
    GetControl = function(typeName, label)
        if typeName == "toggle" then return Controls.toggles[label] end
        if typeName == "slider" then return Controls.sliders[label] end
        if typeName == "checkbox" then return Controls.checkboxes[label] end
        if typeName == "color" then return Controls.colorpickers[label] end
        return nil
    end
}


local UI = {
    windowW = 380, windowH = 520,
    bg = Color3.fromRGB(245,245,247),
    card = Color3.fromRGB(255,255,255),
    textPrimary = Color3.fromRGB(20,20,20),
    accent = Color3.fromRGB(0,122,255),
    toggleOn = Color3.fromRGB(48,209,88),
    toggleOff = Color3.fromRGB(229,229,234)
}


local reopenBtn = Instance.new("ImageButton")
reopenBtn.Name = "Reopen"
reopenBtn.Size = UDim2.new(0, 56, 0, 56)
reopenBtn.AnchorPoint = Vector2.new(1,1)
reopenBtn.Position = UDim2.new(1, -28, 1, -28)
reopenBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
reopenBtn.BackgroundTransparency = 0.06
reopenBtn.Image = "rbxassetid://3926305904" 
reopenBtn.ScaleType = Enum.ScaleType.Fit
reopenBtn.AutoButtonColor = true
reopenBtn.Visible = false
reopenBtn.Parent = gui
Instance.new("UICorner", reopenBtn).CornerRadius = UDim.new(1,0)
local reopenShadow = Instance.new("ImageLabel", reopenBtn)
reopenShadow.Size = UDim2.new(1,20,1,20); reopenShadow.Position = UDim2.new(0,-10,0,-10)
reopenShadow.BackgroundTransparency = 1; reopenShadow.Image = "rbxassetid://5028857084"
reopenShadow.ImageTransparency = 0.5; reopenShadow.ScaleType = Enum.ScaleType.Slice
reopenShadow.SliceCenter = Rect.new(24,24,276,276)


local main = Instance.new("Frame")
main.Name = "Window"
main.Size = UDim2.new(0, UI.windowW, 0, UI.windowH)
main.Position = UDim2.new(0.5, -UI.windowW/2, 0.5, -UI.windowH/2)
main.BackgroundColor3 = UI.bg
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainShadow = Instance.new("ImageLabel", main)
mainShadow.Size = UDim2.new(1,48,1,48); mainShadow.Position = UDim2.new(0,-24,0,-24)
mainShadow.BackgroundTransparency = 1; mainShadow.Image = "rbxassetid://5028857084"
mainShadow.ImageTransparency = 0.45; mainShadow.ScaleType = Enum.ScaleType.Slice
mainShadow.SliceCenter = Rect.new(24,24,276,276)


local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1,0,0,56); titleBar.BackgroundTransparency = 1
local titleTxt = Instance.new("TextLabel", titleBar)
titleTxt.Size = UDim2.new(1,-120,1,0); titleTxt.Position = UDim2.new(0,16,0,0)
titleTxt.BackgroundTransparency = 1; titleTxt.Font = Enum.Font.GothamBold; titleTxt.TextSize = 20
titleTxt.TextXAlignment = Enum.TextXAlignment.Left; titleTxt.TextColor3 = UI.textPrimary; titleTxt.Text = "DinasHub"

local btnClose = Instance.new("ImageButton", titleBar)
btnClose.Size = UDim2.new(0,44,0,44); btnClose.Position = UDim2.new(1,-72,0.5,-22)
btnClose.BackgroundColor3 = Color3.fromRGB(255,59,48); btnClose.Image = ""
btnClose.AutoButtonColor = false
local btnCloseLbl = Instance.new("TextLabel", btnClose); btnCloseLbl.Size = UDim2.new(1,0,1,0); btnCloseLbl.BackgroundTransparency = 1
btnCloseLbl.Text = "✕"; btnCloseLbl.Font = Enum.Font.GothamBold; btnCloseLbl.TextSize = 20; btnCloseLbl.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(1,0)


local scroll = Instance.new("ScrollingFrame", main)
scroll.Name = "Scroll"; scroll.Size = UDim2.new(1, -32, 1, -96); scroll.Position = UDim2.new(0,16,0,72)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0,0,0,0)
local list = Instance.new("UIListLayout", scroll); list.Padding = UDim.new(0,12)
list.SortOrder = Enum.SortOrder.LayoutOrder
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0,0,0, list.AbsoluteContentSize.Y + 12)
end)


local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
local function updateDrag(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
Hub:Connect(titleBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        Hub:Connect(input.Changed, function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Hub:Connect(titleBar.InputChanged, function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
Hub:Connect(UserInputService.InputChanged, function(input) if dragging and input == dragInput then updateDrag(input) end end)


LelUI:Bind(btnClose, "MouseButton1Click", "btnClose", function()
    TweenService:Create(main, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    delay(0.36, function()
        main.Visible = false
        reopenBtn.Visible = true
        reopenBtn.Size = UDim2.new(0,0,0,0)
        TweenService:Create(reopenBtn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,56,0,56)}):Play()
    end)
end)
LelUI:Bind(reopenBtn, "MouseButton1Click", "reopenBtn", function()
    reopenBtn.Visible = false
    main.Size = UDim2.new(0,0,0,0); main.Visible = true
    TweenService:Create(main, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, UI.windowW, 0, UI.windowH)}):Play()
end)

main.Size = UDim2.new(0,0,0,0)
TweenService:Create(main, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, UI.windowW, 0, UI.windowH)}):Play()


local function mkCard(parent, h)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -12, 0, h or 56)
    f.BackgroundColor3 = UI.card
    f.BorderSizePixel = 0
    local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0,10)
    return f
end


local function mkDivider(parent)
    local l = Instance.new("Frame", parent)
    l.Size = UDim2.new(1, -32, 0, 1); l.Position = UDim2.new(0,16,1,-1)
    l.AnchorPoint = Vector2.new(0,1); l.BackgroundColor3 = Color3.fromRGB(230,230,235); l.BorderSizePixel = 0
    return l
end

local function createCheckbox(parent, label, initial)
    local event = makeEvent()
    local value = initial or false
    local instance = Instance.new("Frame", parent)
    local raw = LelUI:Control(parent, "Toggle", label, value, function(nextValue) value = nextValue event:Fire(nextValue) end)
    local control = { Get = function() return value end, Set = function(nextValue)
        raw:SetValue(nextValue)
    end, Changed = { Connect = function(_, callback) return Hub:Connect(event, callback) end }, Instance = instance }
    Controls.checkboxes[label] = control
    return control
end


local function createToggle(parent, label, initial)
    local event = makeEvent()
    local value = initial or false
    local instance = Instance.new("Frame", parent)
    local raw = LelUI:Control(parent, "Toggle", label, value, function(nextValue) value = nextValue event:Fire(nextValue) end)
    local control = { Get = function() return value end, Set = function(nextValue)
        raw:SetValue(nextValue)
    end, Changed = { Connect = function(_, callback) return Hub:Connect(event, callback) end }, Instance = instance }
    Controls.toggles[label] = control
    return control
end


local function createSlider(parent, label, minVal, maxVal, defaultVal)
    local event = makeEvent()
    local value = defaultVal or minVal or 0
    local instance = Instance.new("Frame", parent)
    local raw = LelUI:Control(parent, "Slider", label, value, function(nextValue) value = nextValue event:Fire(nextValue) end, minVal or 0, maxVal or 100)
    local control = { Get = function() return value end, Set = function(nextValue)
        raw:SetValue(nextValue)
    end, Changed = { Connect = function(_, callback) return Hub:Connect(event, callback) end }, Instance = instance }
    Controls.sliders[label] = control
    return control
end


local function createColorPicker(parent, label, initial)
    local event = makeEvent()
    local value = initial or Color3.fromRGB(0,122,255)
    local instance = Instance.new("Frame", parent)
    local raw = LelUI:Control(parent, "Colorpicker", label, value, function(nextValue) value = nextValue event:Fire(nextValue) end)
    local control = { Get = function() return value end, Set = function(nextValue)
        raw:SetValueRGB(nextValue)
    end, Changed = { Connect = function(_, callback) return Hub:Connect(event, callback) end }, Instance = instance }
    Controls.colorpickers[label] = control
    return control
end


local function makeAccordion(parent, title)
    local frame = LelUI:Section(parent, title)
    return frame, frame
end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local gHdr, gContent = makeAccordion(scroll, "General", 160)

local function attachCallback(control, callback)
    if not control then return end

    if type(control) == "table" and control.Changed and type(control.Changed.Connect) == "function" then
        Hub:Connect(control.Changed, callback)
        return true
    end

    if type(control) == "table" and type(control.Get) == "function" then
        local prev = control.Get()
        task.spawn(function()
            while true do
                task.wait(0.12)
                local ok, cur = pcall(control.Get)
                if ok and cur ~= prev then
                    prev = cur
                    callback(cur)
                end
            end
        end)
        return true
    end

    local inst = nil
    if typeof(control) == "Instance" then inst = control end
    if type(control) == "table" and control.Instance and typeof(control.Instance) == "Instance" then inst = control.Instance end

    if inst then
        local function findButton(root)
            for _,d in ipairs(root:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    return d
                end
            end
            return nil
        end
        local btn = findButton(inst)
        if btn then
            LelUI:Bind(btn, "MouseButton1Click", "btn", function()
                task.defer(function()
                    if type(control) == "table" and type(control.Get) == "function" then
                        local ok, v = pcall(control.Get)
                        if ok then callback(v); return end
                    end
                    for _,d in ipairs(inst:GetDescendants()) do
                        if d:IsA("TextLabel") and (d.Text == "✔" or d.Text == "✓") then
                            callback(d.Text ~= "")
                            return
                        end
                    end
                    callback(nil)
                end)
            end)
            return true
        end
    end
    return false
end


local cbSh = createCheckbox(gContent, "Enable Shadows", true)
local function onSh(state)
    local ok, err = pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = state and true or false
    end)
    if not ok then warn("Enable Shadows handler error:", err) end
end
attachCallback(cbSh, onSh)


local cbFPS = createCheckbox(gContent, "Show FPS", false)
local fpsGui, fpsLabel, fpsConn
local function createFPSGui()
    if fpsGui and fpsGui.Parent then return end
    fpsGui = Instance.new("ScreenGui")
    fpsGui.Name = "FPSGui"
    fpsGui.ResetOnSpawn = false
    fpsGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    fpsLabel = Instance.new("TextLabel", fpsGui)
    fpsLabel.Name = "FPSLabel"
    fpsLabel.Size = UDim2.new(0, 100, 0, 28)
    fpsLabel.Position = UDim2.new(0, 12, 0, 12)
    fpsLabel.BackgroundTransparency = 0.4
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.TextSize = 14
    fpsLabel.Text = "FPS: 0"
end
local function destroyFPSGui()
    if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
    if fpsGui then fpsGui:Destroy(); fpsGui = nil end
end

local function onFPS(state)
    if state then
        createFPSGui()
        if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
        local frames = 0
        local last = tick()
        fpsConn = Hub:Connect(RunService.RenderStepped, function()
            frames = frames + 1
            local now = tick()
            if now - last >= 1 then
                if fpsLabel and fpsLabel.Parent then
                    fpsLabel.Text = "FPS: " .. tostring(frames)
                end
                frames = 0
                last = now
            end
        end)
    else
        destroyFPSGui()
    end
end
attachCallback(cbFPS, onFPS)


local tCompact = createToggle(gContent, "Compact UI", true)
local function ensureUIScale(rootGui)
    local us = rootGui:FindFirstChildWhichIsA("UIScale")
    if not us then
        us = Instance.new("UIScale")
        us.Name = "MenuUIScale"
        us.Parent = rootGui
    end
    return us
end

local rootGui = gui
local us = ensureUIScale(rootGui)

local function onCompact(state)
    local target = state and 0.88 or 1
    local ok, err = pcall(function()
        local tween = TweenService:Create(us, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = target})
        tween:Play()
    end)
    if not ok then warn("Compact UI tween error:", err) end
end
attachCallback(tCompact, onCompact)

pcall(function()
    if type(cbSh) == "table" and cbSh.Get and type(cbSh.Get) == "function" then onSh(cbSh.Get()) end
    if type(cbFPS) == "table" and cbFPS.Get and type(cbFPS.Get) == "function" then onFPS(cbFPS.Get()) end
    if type(tCompact) == "table" and tCompact.Get and type(tCompact.Get) == "function" then onCompact(tCompact.Get()) end
end)


local pHdr, pContent = makeAccordion(scroll, "Gameplay", 140)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clicker = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Clicker")
local Rebirth = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")
local Area = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Area")

local autoClickConn, autoRebirthConn


local cbAutoClick = createCheckbox(pContent, "AutoClick", false)
Hub:Connect(cbAutoClick.Changed, function(state)
	if state then
		if autoClickConn then return end
		autoClickConn = Hub:Connect(RunService.Heartbeat, function()
			pcall(function()
				Clicker:FireServer()
			end)
		end)
	else
		if autoClickConn then
			autoClickConn:Disconnect()
			autoClickConn = nil
		end
	end
end)


local cbAutoRebirth = createCheckbox(pContent, "AutoRebirth", false)
Hub:Connect(cbAutoRebirth.Changed, function(state)
	if state then
		if autoRebirthConn then return end
		autoRebirthConn = Hub:Connect(RunService.Heartbeat, function()
			pcall(function()
				Rebirth:FireServer(1)
			end)
		end)
	else
		if autoRebirthConn then
			autoRebirthConn:Disconnect()
			autoRebirthConn = nil
		end
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function findRemoteByName(name, timeout)
    timeout = timeout or 5
    local start = tick()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    while tick() - start < timeout do
        if remotesFolder then
            local r = remotesFolder:FindFirstChild(name)
            if r then return r end
        end
        local r2 = ReplicatedStorage:FindFirstChild(name)
        if r2 then return r2 end
        task.wait(0.1)
    end
    return nil
end

local AreaRemote = findRemoteByName("Area", 5)
if not AreaRemote then
    warn("Unlock Arena: remote 'Area' not found in ReplicatedStorage.Remotes or ReplicatedStorage.")
    local cbUnlock = createCheckbox(pContent, "Unlock Arena (Remote not found)", false)
    cbUnlock.Set(false)
    return
end

local cbUnlock = createCheckbox(pContent, "Unlock Arena", false)

local unlockLoopConn = nil
local unlocking = false

local function doUnlockOnce()
    local success, err = pcall(function()
        AreaRemote:FireServer()
    end)
    if not success then
    end
end

local function startUnlockLoop(interval)
    if unlockLoopConn then return end
    local last = 0
    unlockLoopConn = Hub:Connect(RunService.Heartbeat, function(dt)
        local now = tick()
        if now - last < (interval or 0.5) then return end
        last = now
        pcall(function() AreaRemote:FireServer() end)
    end)
end
local function stopUnlockLoop()
    if unlockLoopConn then
        unlockLoopConn:Disconnect()
        unlockLoopConn = nil
    end
end

Hub:Connect(cbUnlock.Changed, function(state)
    if state then
        doUnlockOnce()
    else
        stopUnlockLoop()
    end
end)

local function cleanup()
    if autoClickConnection then
        autoClickConnection:Disconnect()
        autoClickConnection = nil
    end
end

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
Hub:Connect(plr.AncestryChanged, function()
    if not plr:IsDescendantOf(game) then cleanup() end
end)

RunService.Heartbeat:Wait()
scroll.CanvasSize = UDim2.new(0,0,0, list.AbsoluteContentSize.Y + 12)


if colPick and colPick.Changed then
    Hub:Connect(colPick.Changed, function(c)
        titleTxt.TextColor3 = c
    end)
end


Hub:Connect(LocalPlayer.AncestryChanged, function()
    if not LocalPlayer:IsDescendantOf(game) then
        pcall(function() gui:Destroy() end)
    end
end)

return _G.MenuAPI

end)
