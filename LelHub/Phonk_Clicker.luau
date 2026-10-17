local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Phonk Clicker!", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
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
        Connect = function(_, fn) return b.Event:Connect(fn) end
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
        if c then c.Changed:Connect(fn) end
    end,
    OnSlider = function(label, fn)
        local c = Controls.sliders[label]
        if c then c.Changed:Connect(fn) end
    end,
    OnCheckbox = function(label, fn)
        local c = Controls.checkboxes[label]
        if c then c.Changed:Connect(fn) end
    end,
    OnColor = function(label, fn)
        local c = Controls.colorpickers[label]
        if c then c.Changed:Connect(fn) end
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
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input == dragInput then updateDrag(input) end end)


btnClose.MouseButton1Click:Connect(function()
    TweenService:Create(main, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
    delay(0.36, function()
        main.Visible = false
        reopenBtn.Visible = true
        reopenBtn.Size = UDim2.new(0,0,0,0)
        TweenService:Create(reopenBtn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,56,0,56)}):Play()
    end)
end)
reopenBtn.MouseButton1Click:Connect(function()
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
    initial = initial or false
    local card = mkCard(parent, 56)
    card.LayoutOrder = 0
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -120, 1, 0); lbl.Position = UDim2.new(0,16,0,0)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 16
    lbl.Text = label; lbl.TextColor3 = UI.textPrimary; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("ImageButton", card)
    btn.Size = UDim2.new(0,40,0,40); btn.Position = UDim2.new(1,-64,0.5,-20)
    btn.AutoButtonColor = false; btn.Image = ""; btn.BackgroundColor3 = initial and UI.toggleOn or Color3.fromRGB(242,242,246)
    local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,8)

    local mark = Instance.new("TextLabel", btn)
    mark.Size = UDim2.new(1,0,1,0); mark.BackgroundTransparency = 1
    mark.Font = Enum.Font.GothamBold; mark.TextSize = 18; mark.TextColor3 = Color3.fromRGB(255,255,255)
    mark.Text = initial and "✔" or ""; mark.TextTransparency = initial and 0 or 1

    local state = initial
    local event = makeEvent()

    local function set(v)
        state = v
        if state then
            TweenService:Create(btn, TweenInfo.new(0.16), {BackgroundColor3 = UI.toggleOn}):Play()
            TweenService:Create(mark, TweenInfo.new(0.16), {TextTransparency = 0}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.16), {BackgroundColor3 = Color3.fromRGB(242,242,246)}):Play()
            TweenService:Create(mark, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
        end
        event:Fire(state)
    end

    btn.MouseButton1Click:Connect(function()
        set(not state)
        btn:TweenSize(btn.Size + UDim2.new(0,4,0,4), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.06, true, function()
            btn:TweenSize(btn.Size - UDim2.new(0,4,0,4), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.06, true)
        end)
    end)

    local control = {
        Get = function() return state end,
        Set = set,
        Changed = { Connect = function(_, fn) return event:Connect(fn) end },
        Instance = card
    }
    Controls.checkboxes[label] = control
    return control
end


local function createToggle(parent, label, initial)
    initial = initial or false
    local card = mkCard(parent, 56)
    card.LayoutOrder = 0
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -120, 1, 0); lbl.Position = UDim2.new(0,16,0,0)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 16
    lbl.Text = label; lbl.TextColor3 = UI.textPrimary; lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", card)
    track.Size = UDim2.new(0,58,0,30); track.Position = UDim2.new(1,-78,0.5,-15)
    track.BackgroundColor3 = initial and UI.toggleOn or UI.toggleOff; track.BorderSizePixel = 0
    local trC = Instance.new("UICorner", track); trC.CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,26,0,26); knob.Position = initial and UDim2.new(1,-30,0.5,-13) or UDim2.new(0,4,0.5,-13)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); local knC = Instance.new("UICorner", knob); knC.CornerRadius = UDim.new(1,0)

    local state = initial
    local event = makeEvent()
    local function set(s, instant)
        state = s
        if instant then
            knob.Position = state and UDim2.new(1,-30,0.5,-13) or UDim2.new(0,4,0.5,-13)
            track.BackgroundColor3 = state and UI.toggleOn or UI.toggleOff
        else
            TweenService:Create(knob, TweenInfo.new(0.18), {Position = state and UDim2.new(1,-30,0.5,-13) or UDim2.new(0,4,0.5,-13)}):Play()
            TweenService:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = state and UI.toggleOn or UI.toggleOff}):Play()
        end
        
        knob:TweenSize(UDim2.new(0,28,0,28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.06, true, function()
            knob:TweenSize(UDim2.new(0,26,0,26), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.06, true)
        end)
        event:Fire(state)
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            set(not state)
        end
    end)

    local control = {
        Get = function() return state end,
        Set = set,
        Changed = { Connect = function(_, fn) return event:Connect(fn) end },
        Instance = card
    }
    Controls.toggles[label] = control
    return control
end


local function createSlider(parent, label, minVal, maxVal, defaultVal)
    minVal = minVal or 0; maxVal = maxVal or 100; defaultVal = defaultVal or minVal
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1, -12, 0, 72); c.BackgroundTransparency = 1
    c.LayoutOrder = 0

    local lbl = Instance.new("TextLabel", c)
    lbl.Size = UDim2.new(1, -96, 0, 20); lbl.Position = UDim2.new(0,16,0,6)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 15
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = UI.textPrimary
    lbl.Text = label .. ": " .. tostring(defaultVal)

    local valLabel = Instance.new("TextLabel", c)
    valLabel.Size = UDim2.new(0,64,0,20); valLabel.Position = UDim2.new(1, -80, 0, 6)
    valLabel.BackgroundTransparency = 1; valLabel.Font = Enum.Font.GothamBold; valLabel.TextSize = 14
    valLabel.TextColor3 = Color3.fromRGB(80,80,90); valLabel.Text = tostring(defaultVal)

    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1, -96, 0, 8); bar.Position = UDim2.new(0,16,0,36)
    bar.BackgroundColor3 = Color3.fromRGB(220,220,220); bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,4)

    local t = (defaultVal - minVal) / (maxVal - minVal)
    local fill = Instance.new("Frame", bar); fill.Size = UDim2.new(t,0,1,0); fill.BackgroundColor3 = UI.accent
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,4)

    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.new(0,18,0,18); knob.Position = UDim2.new(t, -9, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local knobShadow = Instance.new("ImageLabel", knob)
    knobShadow.Size = UDim2.new(1,6,1,6); knobShadow.Position = UDim2.new(0,-3,0,-3)
    knobShadow.BackgroundTransparency = 1; knobShadow.Image = "rbxassetid://5028857084"; knobShadow.ImageTransparency = 0.3
    knobShadow.ScaleType = Enum.ScaleType.Slice; knobShadow.SliceCenter = Rect.new(24,24,276,276)

    local dragging = false
    local value = defaultVal
    local event = makeEvent()

    local function updateFromX(x)
        local bx = bar.AbsolutePosition.X; local bw = bar.AbsoluteSize.X
        local p = math.clamp((x - bx) / bw, 0, 1)
        fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p, -9, 0.5, -9)
        value = math.floor(minVal + (maxVal - minVal) * p + 0.5)
        lbl.Text = label .. ": " .. tostring(value)
        valLabel.Text = tostring(value)
        event:Fire(value)
    end

    knob.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = true end end)
    knob.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            updateFromX(inp.Position.X); dragging = true
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(inp.Position.X)
        end
    end)

    local control = {
        Get = function() return value end,
        Set = function(v)
            local p = math.clamp((v - minVal)/(maxVal - minVal), 0, 1)
            fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p, -9, 0.5, -9)
            value = math.floor(v + 0.5); lbl.Text = label .. ": " .. tostring(value); valLabel.Text = tostring(value)
            event:Fire(value)
        end,
        Changed = { Connect = function(_, fn) return event:Connect(fn) end },
        Instance = c
    }
    Controls.sliders[label] = control
    return control
end


local function createColorPicker(parent, label, defaultColor)
    defaultColor = defaultColor or Color3.fromRGB(0,122,255)
    local card = mkCard(parent, 160)
    card.LayoutOrder = 0

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -16, 0, 20); title.Position = UDim2.new(0,8,0,6)
    title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 14
    title.Text = label; title.TextColor3 = UI.textPrimary; title.TextXAlignment = Enum.TextXAlignment.Left

    local preview = Instance.new("Frame", card)
    preview.Size = UDim2.new(0,48,0,48); preview.Position = UDim2.new(1, -64, 0, 8)
    preview.BackgroundColor3 = defaultColor; Instance.new("UICorner", preview).CornerRadius = UDim.new(0,8)

    
    local palette = Instance.new("ImageButton", card)
    palette.Size = UDim2.new(0, 160, 0, 80); palette.Position = UDim2.new(0,8,0,36)
    palette.Image = "rbxassetid://6020299385" 
    palette.AutoButtonColor = false
    Instance.new("UICorner", palette).CornerRadius = UDim.new(0,6)

    
    local brightBar = Instance.new("Frame", card)
    brightBar.Size = UDim2.new(0, 160, 0, 10); brightBar.Position = UDim2.new(0,8,0,126)
    brightBar.BackgroundColor3 = Color3.fromRGB(200,200,200); Instance.new("UICorner", brightBar).CornerRadius = UDim.new(0,5)
    local brightFill = Instance.new("Frame", brightBar); brightFill.Size = UDim2.new(1,0,1,0); brightFill.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", brightFill).CornerRadius = UDim.new(0,5)

    local hue = defaultColor
    local brightness = 1
    local draggingHue, draggingBright = false, false
    local event = makeEvent()

    local function updatePreview()
        preview.BackgroundColor3 = Color3.fromRGB(
            math.clamp(math.floor(hue.R * 255 * brightness + 0.5),0,255),
            math.clamp(math.floor(hue.G * 255 * brightness + 0.5),0,255),
            math.clamp(math.floor(hue.B * 255 * brightness + 0.5),0,255)
        )
        event:Fire(preview.BackgroundColor3)
    end

    palette.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            local relX = math.clamp((inp.Position.X - palette.AbsolutePosition.X) / palette.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((inp.Position.Y - palette.AbsolutePosition.Y) / palette.AbsoluteSize.Y, 0, 1)
            hue = Color3.fromHSV(relX, 1, 1 - relY)
            updatePreview()
        end
    end)
    palette.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then draggingHue = false end end)

    brightBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingBright = true
            local relX = math.clamp((inp.Position.X - brightBar.AbsolutePosition.X) / brightBar.AbsoluteSize.X, 0, 1)
            brightness = relX
            brightFill.Size = UDim2.new(relX,0,1,0)
            updatePreview()
        end
    end)
    brightBar.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then draggingBright = false end end)

    UserInputService.InputChanged:Connect(function(inp)
        if draggingHue and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local relX = math.clamp((inp.Position.X - palette.AbsolutePosition.X) / palette.AbsoluteSize.X, 0, 1)
            local relY = math.clamp((inp.Position.Y - palette.AbsolutePosition.Y) / palette.AbsoluteSize.Y, 0, 1)
            hue = Color3.fromHSV(relX, 1, 1 - relY)
            updatePreview()
        elseif draggingBright and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local relX = math.clamp((inp.Position.X - brightBar.AbsolutePosition.X) / brightBar.AbsoluteSize.X, 0, 1)
            brightness = relX
            brightFill.Size = UDim2.new(relX,0,1,0)
            updatePreview()
        end
    end)

    local control = {
        Get = function() return preview.BackgroundColor3 end,
        Set = function(c)
            hue = c; brightness = 1; brightFill.Size = UDim2.new(1,0,1,0); updatePreview()
        end,
        Changed = { Connect = function(_, fn) return event:Connect(fn) end },
        Instance = card
    }
    Controls.colorpickers[label] = control
    return control
end


local function makeAccordion(parent, title, expandedH)
    expandedH = expandedH or 140
    local headerCard = mkCard(parent, 52); headerCard.LayoutOrder = 0
    local hdr = Instance.new("TextButton", headerCard)
    hdr.Size = UDim2.new(1,0,1,0)
    hdr.BackgroundTransparency = 1
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 16
    hdr.TextColor3 = UI.textPrimary
    hdr.Text = title

    local arrow = Instance.new("TextLabel", headerCard)
    arrow.Size = UDim2.new(0,20,1,0)
    arrow.Position = UDim2.new(1,-36,0,0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Font = Enum.Font.Gotham
    arrow.TextColor3 = Color3.fromRGB(140,140,150)

    local content = Instance.new("ScrollingFrame", parent)
    content.Size = UDim2.new(1,0,0,0)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.LayoutOrder = 0
    content.ScrollBarThickness = 4
    content.CanvasSize = UDim2.new(0,0,0,0)

    local listLocal = Instance.new("UIListLayout", content)
    listLocal.Padding = UDim.new(0,8)
    listLocal.SortOrder = Enum.SortOrder.LayoutOrder

    local expanded = false
    hdr.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            TweenService:Create(content, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(1,0,0, expandedH)}):Play()
            arrow.Text = "▲"
        else
            TweenService:Create(content, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Size = UDim2.new(1,0,0, 0)}):Play()
            arrow.Text = "▼"
        end
    end)

    listLocal:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0,0,0,listLocal.AbsoluteContentSize.Y + 8)
        if expanded then
            local targetHeight = math.min(listLocal.AbsoluteContentSize.Y + 8, expandedH)
            content.Size = UDim2.new(1,0,0, targetHeight)
        end
    end)

    return headerCard, content
end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local gHdr, gContent = makeAccordion(scroll, "General", 160)

local function attachCallback(control, callback)
    if not control then return end

    if type(control) == "table" and control.Changed and type(control.Changed.Connect) == "function" then
        control.Changed:Connect(callback)
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
            btn.MouseButton1Click:Connect(function()
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
        fpsConn = RunService.RenderStepped:Connect(function()
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
cbAutoClick.Changed:Connect(function(state)
	if state then
		if autoClickConn then return end
		autoClickConn = RunService.Heartbeat:Connect(function()
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
cbAutoRebirth.Changed:Connect(function(state)
	if state then
		if autoRebirthConn then return end
		autoRebirthConn = RunService.Heartbeat:Connect(function()
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
    unlockLoopConn = RunService.Heartbeat:Connect(function(dt)
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

cbUnlock.Changed:Connect(function(state)
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
plr.AncestryChanged:Connect(function()
    if not plr:IsDescendantOf(game) then cleanup() end
end)

RunService.Heartbeat:Wait()
scroll.CanvasSize = UDim2.new(0,0,0, list.AbsoluteContentSize.Y + 12)


if colPick and colPick.Changed then
    colPick.Changed:Connect(function(c)
        titleTxt.TextColor3 = c
    end)
end


LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer:IsDescendantOf(game) then
        pcall(function() gui:Destroy() end)
    end
end)

return _G.MenuAPI
]====])
