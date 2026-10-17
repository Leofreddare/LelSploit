local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Femboy Simulator", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local player = Players.LocalPlayer


local tele = game:GetService('ReplicatedStorage'):WaitForChild('Teleporter')
tele:Clone().Parent = player.Backpack


local Events = ReplicatedStorage:WaitForChild('Events')
local RebirthEvent = Events:WaitForChild('Rebirth')
assert(RebirthEvent:IsA('RemoteEvent'), 'Events.Rebirth must be a RemoteEvent')

local RollEnchant = Events:WaitForChild('RollEnchant') 

local HireWorker = Events:WaitForChild('HireWorker') 

local GetQuest = Events:WaitForChild('GetQuest') 
local ClaimQuest = Events:WaitForChild('ClaimQuest') 


local pg = player:WaitForChild('PlayerGui')
local screen = pg:WaitForChild('Screen')

local workersGui = screen:WaitForChild('Workers')
local workersContainer = workersGui:WaitForChild('Container')
local workersSubtitle = workersContainer:WaitForChild('Subtitle') 

local enchants = screen:WaitForChild('Enchants')
local container = enchants:WaitForChild('Container')
local enchantLabel = container:WaitForChild('Enchant') 


local gui = Instance.new('ScreenGui')
gui.Name = 'TogglePanel'
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild('PlayerGui')

local panel = Instance.new('Frame')
panel.Size = UDim2.fromOffset(280, 240)
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -30)
panel.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
panel.Parent = gui

local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local padding = Instance.new('UIPadding')
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local list = Instance.new('UIListLayout')
list.Padding = UDim.new(0, 8)
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = panel


local header = Instance.new('Frame')
header.Size = UDim2.new(1, -4, 0, 28)
header.BackgroundTransparency = 1
header.Parent = panel

local title = Instance.new('TextLabel')
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -36, 1, 0)
title.Text = 'Pootilities'
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamSemibold
title.TextSize = 16
title.Parent = header

local closeBtn = Instance.new('TextButton')
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -28, 0, 0)
closeBtn.Text = 'X'
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header

local closeCorner = Instance.new('UICorner')
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
    script:Destroy()
end)


local UIS = game:GetService('UserInputService')

local dragging = false
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    panel.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end


header.InputBegan:Connect(function(input)
    if
        input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position

        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)


header.InputChanged:Connect(function(input)
    if
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    then
        dragInput = input
    end
end)


UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)


local function makeToggle(labelText, onToggle)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, -4, 0, 40)
    btn.Text = labelText .. ' (OFF)'
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(240, 240, 255)
    btn.BackgroundColor3 = Color3.fromRGB(60, 110, 220)
    btn.AutoButtonColor = true
    btn.Parent = panel

    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = labelText .. (state and ' (ON)' or ' (OFF)')
        onToggle(state, btn)
    end)

    return btn
end


local rebirthToken = 0 
local enchantToken = 0 
local workerToken = 0
local questToken = 0

local function setAutoRebirth(on)
    rebirthToken += 1
    local myToken = rebirthToken
    if on then
        task.spawn(function()
            while myToken == rebirthToken do
                
                pcall(function()
                    RebirthEvent:FireServer()
                end)
                task.wait(1)
            end
        end)
    end
end


local function isEnchantGoal(text)
    text = tostring(text or ''):gsub('%s+', ''):upper()
    return text == 'X'
end

local function setAutoEnchant(on)
    enchantToken += 1
    local myToken = enchantToken
    if on then
        task.spawn(function()
            while myToken == enchantToken do
                if not isEnchantGoal(enchantLabel.Text) then
                    
                    pcall(function()
                        if RollEnchant:IsA('RemoteEvent') then
                            RollEnchant:FireServer()
                        elseif RollEnchant:IsA('RemoteFunction') then
                            RollEnchant:InvokeServer()
                        else
                            warn(
                                'RollEnchant must be RemoteEvent or RemoteFunction'
                            )
                        end
                    end)
                    task.wait(0.1)
                else
                    
                    task.wait(0.2)
                end
            end
        end)
    end
end


local function isWorkerGoal(text)
    text = tostring(text or '') 
    text = text
        :gsub('^%s+', '') 
        :gsub('%s+$', '') 
        :gsub('%s+', ' ') 
        :upper() 
    return text == 'BUY A WORKER (X30)'
end

local function setAutoWorker(on)
    workerToken += 1
    local myToken = workerToken
    if on then
        task.spawn(function()
            while myToken == workerToken do
                if not isWorkerGoal(workersSubtitle.Text) then
                    
                    pcall(function()
                        if HireWorker:IsA('RemoteEvent') then
                            HireWorker:FireServer()
                        elseif HireWorker:IsA('RemoteFunction') then
                            HireWorker:InvokeServer()
                        else
                            warn(
                                'HireWorker must be RemoteEvent or RemoteFunction'
                            )
                        end
                    end)
                    task.wait(0.1)
                else
                    
                    task.wait(0.2)
                end
            end
        end)
    end
end

local function setAutoQuest(on)
    questToken += 1
    local myToken = questToken
    if on then
        task.spawn(function()
            while myToken == questToken do
                pcall(function()
                    if GetQuest:IsA('RemoteEvent') then
                        GetQuest:FireServer()
                    elseif GetQuest:IsA('RemoteFunction') then
                        GetQuest:InvokeServer()
                    else
                        warn('GetQuest must be RemoteEvent or RemoteFunction')
                    end

                    if ClaimQuest:IsA('RemoteEvent') then
                        ClaimQuest:FireServer()
                    elseif ClaimQuest:IsA('RemoteFunction') then
                        ClaimQuest:InvokeServer()
                    else
                        warn('ClaimQuest must be RemoteEvent or RemoteFunction')
                    end
                end)
                task.wait(0.5)
            end
        end)
    end
end

makeToggle('Auto Rebirth', function(on)
    setAutoRebirth(on)
end)


makeToggle('Auto Enchant', function(on)
    setAutoEnchant(on)
end)

makeToggle('Auto Workers', function(on)
    setAutoWorker(on)
end)

makeToggle('Questing Blud', function(on)
    setAutoQuest(on)
end)
]====])
