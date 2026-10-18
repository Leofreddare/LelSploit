local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Criminality")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local VirtualUser = game:GetService('VirtualUser')

if game:GetService('Players').LocalPlayer then
    game:GetService('Players').LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService") 
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = PlayerGui:FindFirstChild("VenomHubScreenGui")
if oldGui then
    oldGui:Destroy()
end

local oldCategorizedGui = PlayerGui:FindFirstChild("VenomHubScreenGui_Categorized")
if oldCategorizedGui then
    oldCategorizedGui:Destroy()
end

local oldKeyGui = PlayerGui:FindFirstChild("KeyVerificationUI")
if oldKeyGui then
    oldKeyGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VenomHubScreenGui_Categorized"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui


local mainFrame = Instance.new("Frame")
mainFrame.Name = "VenomHubMainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 350) 
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20) 
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = true
mainFrame.Active = true
mainFrame.Draggable = false 
mainFrame.Parent = screenGui


local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame


local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 75) 
stroke.Thickness = 1
stroke.Transparency = 0.5
stroke.Parent = mainFrame


local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -40, 0, 40) 
titleLabel.Position = UDim2.new(0, 20, 0, 5) 
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "EQR Hub v.1.19B"
titleLabel.Font = Enum.Font.GothamSemibold 
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLabel.TextSize = 20 
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame


local line = Instance.new("Frame")
line.Name = "Divider"
line.Size = UDim2.new(1, -40, 0, 1)
line.Position = UDim2.new(0, 20, 0, 40) 
line.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
line.BorderSizePixel = 0
line.Parent = mainFrame


local footerLabel = Instance.new("TextLabel")
footerLabel.Name = "Footer"
footerLabel.Size = UDim2.new(1, -20, 0, 20) 
footerLabel.Position = UDim2.new(0, 10, 1, -25)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "By helloitsme#4243 | Press K to Toggle" 
footerLabel.Font = Enum.Font.Gotham 
footerLabel.TextSize = 10
footerLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
footerLabel.TextXAlignment = Enum.TextXAlignment.Right
footerLabel.Parent = mainFrame


local sidebarFrame = Instance.new("Frame")
sidebarFrame.Name = "SidebarFrame"
sidebarFrame.Size = UDim2.new(0, 120, 1, -70) 
sidebarFrame.Position = UDim2.new(0, 10, 0, 50) 
sidebarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) 
sidebarFrame.BorderSizePixel = 0
sidebarFrame.Parent = mainFrame

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 8)
sidebarCorner.Parent = sidebarFrame

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 5)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.Parent = sidebarFrame


local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -150, 1, -70) 
contentFrame.Position = UDim2.new(0, 140, 0, 50) 
contentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) 
contentFrame.BorderSizePixel = 0
contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
contentFrame.ScrollBarThickness = 6
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0) 
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.Parent = contentFrame

do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        mainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end

    Hub:Connect(mainFrame.InputBegan, function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local absPos = mainFrame.AbsolutePosition
            local absSize = mainFrame.AbsoluteSize
            local headerHeight = 45 

            
            if input.Position.Y < absPos.Y + headerHeight and input.Position.Y > absPos.Y and input.Position.X > absPos.X and input.Position.X < absPos.X + absSize.X then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position

                
                Hub:Connect(input.Changed, function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end
    end)

    Hub:Connect(mainFrame.InputChanged, function(input)
        
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    Hub:Connect(UserInputService.InputChanged, function(input)
        
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

Hub:Connect(UserInputService.InputBegan, function(input, gameProcessedEvent)
    
    if not gameProcessedEvent then
        
        if input.KeyCode == Enum.KeyCode.K then
            
            mainFrame.Visible = not mainFrame.Visible
        end
    end
end)

local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer

local NoFailLockpick_Enabled = false

local lockpickAddedConnection = nil 


function NoFailLockpick_Enable()
    if NoFailLockpick_Enabled then return end
    NoFailLockpick_Enabled = true

    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    
    
    lockpickAddedConnection = Hub:Connect(PlayerGui.ChildAdded, function(Item)
        if Item.Name == "LockpickGUI" then
            local mf = Item:WaitForChild("MF", 10)
            if not mf then return end
            
            local lpFrame = mf:WaitForChild("LP_Frame", 10)
            if not lpFrame then return end
            
            local frames = lpFrame:WaitForChild("Frames", 10)
            if not frames then return end
            
            local b1 = frames:WaitForChild("B1", 10)
            local b2 = frames:WaitForChild("B2", 10)
            local b3 = frames:WaitForChild("B3", 10)

            if b1 and b1.Bar and b1.Bar:FindFirstChild("UIScale") then
                b1.Bar.UIScale.Scale = 10
            end
            if b2 and b2.Bar and b2.Bar:FindFirstChild("UIScale") then
                b2.Bar.UIScale.Scale = 10
            end
            if b3 and b3.Bar and b3.Bar:FindFirstChild("UIScale") then
                b3.Bar.UIScale.Scale = 10
            end
        end
    end)
end


function NoFailLockpick_Disable()
    if not NoFailLockpick_Enabled then return end
    NoFailLockpick_Enabled = false
    
    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    
    if lockpickAddedConnection then
        lockpickAddedConnection:Disconnect()
        lockpickAddedConnection = nil
    end

    
    local lockpickGui = PlayerGui:FindFirstChild("LockpickGUI")
    if lockpickGui then
        local frames = lockpickGui:FindFirstChild("MF")
        if frames then
            local lpFrame = frames:FindFirstChild("LP_Frame")
            if lpFrame then
                local bars = lpFrame:FindFirstChild("Frames")
                if bars then
                    if bars.B1 and bars.B1.Bar and bars.B1.Bar:FindFirstChild("UIScale") then bars.B1.Bar.UIScale.Scale = 1 end
                    if bars.B2 and bars.B2.Bar and bars.B2.Bar:FindFirstChild("UIScale") then bars.B2.Bar.UIScale.Scale = 1 end
                    if bars.B3 and bars.B3.Bar and bars.B3.Bar:FindFirstChild("UIScale") then bars.B3.Bar.UIScale.Scale = 1 end
                end
            end
        end
    end
end

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = game:GetService("Players").LocalPlayer

local BredMakurz_Enabled = false
local bredMakurzConnection = nil 


local function formatName(name)
    
    name = string.gsub(name, "([a-z])([A-Z])", "%1 %2")
    
    
    local underscoreIndex = string.find(name, "_")
    if underscoreIndex then
        name = string.sub(name, 1, underscoreIndex - 1)
    end
    
    return name
end


local function ApplyBredMakurzModification()
    local bredMakurzFolder = Workspace.Map:FindFirstChild("BredMakurz")
    if not bredMakurzFolder then return end

    local character = Player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local playerPosition = character.HumanoidRootPart.Position

    for _, v in pairs(bredMakurzFolder:GetChildren()) do
        local objectPosition
        if v.PrimaryPart and v.PrimaryPart:IsA("BasePart") then
            objectPosition = v.PrimaryPart.Position
        else
            
            local part = v:FindFirstChildOfClass("BasePart")
            if part then
                objectPosition = part.Position
            else
                
                continue 
            end
        end
        
        local distance = (objectPosition - playerPosition).magnitude
        local existingGui = v:FindFirstChild("Ahh")

        if distance <= 200 then
            
            if not existingGui then
                local x = Instance.new('BillboardGui', v)
                x.Name = "Ahh"
                x.AlwaysOnTop = true
                x.Size = UDim2.new(8,0,4,0) 
                x.MaxDistance = 200 
                
                local textLabel = Instance.new('TextLabel', x)
                textLabel.Size = UDim2.new(1,0,1,0)
                textLabel.BackgroundTransparency = 1
                textLabel.Font = Enum.Font.SourceSansBold
                textLabel.TextScaled = false 
                textLabel.TextSize = 15 
                
                textLabel.Text = formatName(v.Name) 
                x.Adornee = v
                
                local values = v:FindFirstChild("Values")
                local brokenValue = values and values:FindFirstChild("Broken")
                if brokenValue then
                    if brokenValue.Value ~= false then
                        textLabel.TextColor3 = Color3.new(255,0,0) 
                    else
                        textLabel.TextColor3 = Color3.new(0,255,0) 
                    end

                    
                    brokenValue:GetPropertyChangedSignal("Value"):Connect(function()
                        if brokenValue.Value ~= false then
                            textLabel.TextColor3 = Color3.new(255,0,0)
                        else
                            textLabel.TextColor3 = Color3.new(0,255,0)
                        end
                    end)
                else
                    textLabel.TextColor3 = Color3.new(0,255,0)
                end
            end
        elseif existingGui then
            
            existingGui:Destroy()
        end
    end
end


function BredMakurz_Enable()
    if BredMakurz_Enabled then return end 
    BredMakurz_Enabled = true

    bredMakurzConnection = Hub:Connect(RunService.Heartbeat, function()
        ApplyBredMakurzModification()
    end)
end


function BredMakurz_Disable()
    if not BredMakurz_Enabled then return end 
    BredMakurz_Enabled = false

    if bredMakurzConnection then
        bredMakurzConnection:Disconnect()
        bredMakurzConnection = nil
    end

    local bredMakurzFolder = Workspace.Map:FindFirstChild("BredMakurz")
    if bredMakurzFolder then
        for _, v in pairs(bredMakurzFolder:GetChildren()) do
            pcall(function()
                if v:FindFirstChild("Ahh") then
                    v.Ahh:Destroy()
                end
            end)
        end
    end
end

local OpenNearbyDoors_Enabled = false
local OpenNearbyDoors_Coroutine = nil 


local function OpenNearbyDoors_Loop()
    while OpenNearbyDoors_Enabled and task.wait(0.25) do 
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        
        if not hrp or not hum or hum.Health <= 0 then
            continue 
        end

        local doorsFolder = Workspace.Map:FindFirstChild("Doors")
        if not doorsFolder then
            warn("OpenNearbyDoors: Cannot find Workspace.Map.Doors folder.")
            OpenNearbyDoors_Disable() 
            break 
        end

        local playerPos = hrp.Position
        for _, doorInstance in ipairs(doorsFolder:GetChildren()) do
             
            local doorBase = doorInstance:FindFirstChild("DoorBase")
            local valuesFolder = doorInstance:FindFirstChild("Values")
            local eventsFolder = doorInstance:FindFirstChild("Events")

            if doorBase and valuesFolder and eventsFolder then
                local openValue = valuesFolder:FindFirstChild("Open")
                local toggleEvent = eventsFolder:FindFirstChild("Toggle")
                
                local knobArgument = doorInstance:FindFirstChild("Knob2") or doorInstance:FindFirstChild("Knob") 

                
                if openValue and toggleEvent and knobArgument and typeof(openValue.Value) == "boolean" then
                    
                    if (playerPos - doorBase.Position).Magnitude <= 6 then 
                        if openValue.Value == false then
                            
                            local success, err = pcall(function()
                                toggleEvent:FireServer("Open", knobArgument)
                            end)
                            if not success then
                                warn("OpenNearbyDoors: Error firing Toggle event for door", doorInstance.Name, ":", err)
                            end
                            
                        end
                    end
                end
            end
        end
    end
    OpenNearbyDoors_Coroutine = nil 
end


local function OpenNearbyDoors_Enable()
    if OpenNearbyDoors_Enabled then return end 
    OpenNearbyDoors_Enabled = true
    
    if not OpenNearbyDoors_Coroutine then
        OpenNearbyDoors_Coroutine = task.spawn(OpenNearbyDoors_Loop)
    end
end


local function OpenNearbyDoors_Disable()
    if not OpenNearbyDoors_Enabled then return end 
    OpenNearbyDoors_Enabled = false
    
    
end

local OpenNearbyDoors_Enabled = false
local UnlockNearbyDoors_Enabled = false
local NearbyDoorInteraction_Coroutine = nil 


local function NearbyDoorInteraction_Loop()
    while (OpenNearbyDoors_Enabled or UnlockNearbyDoors_Enabled) do 
        local waitTime = 0.25 
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        
        if not hrp or not hum or hum.Health <= 0 then
            task.wait(waitTime * 2) 
            continue
        end

        local doorsFolder = Workspace.Map:FindFirstChild("Doors")
        if not doorsFolder then
            warn("NearbyDoorInteraction: Cannot find Workspace.Map.Doors folder. Disabling features.")
            
            if OpenNearbyDoors_Enabled then OpenNearbyDoors_Disable() end
            if UnlockNearbyDoors_Enabled then UnlockNearbyDoors_Disable() end
            break 
        end

        local playerPos = hrp.Position
        local checkRadius = 6 

        for _, doorInstance in ipairs(doorsFolder:GetChildren()) do
            
            local doorBase = doorInstance:FindFirstChild("DoorBase")
            local valuesFolder = doorInstance:FindFirstChild("Values")
            local eventsFolder = doorInstance:FindFirstChild("Events")

            if doorBase and valuesFolder and eventsFolder then
                
                if (playerPos - doorBase.Position).Magnitude <= checkRadius then
                    local toggleEvent = eventsFolder:FindFirstChild("Toggle")
                    if not toggleEvent then continue end 

                    
                    if UnlockNearbyDoors_Enabled then
                        local lockedValue = valuesFolder:FindFirstChild("Locked")
                        local lockArgument = doorInstance:FindFirstChild("Lock") 

                        
                        if lockedValue and lockArgument and typeof(lockedValue.Value) == "boolean" and lockedValue.Value == true then
                            
                            local success, err = pcall(function() toggleEvent:FireServer("Unlock", lockArgument) end)
                            if not success then warn("UnlockNearbyDoors: Error firing event for", doorInstance.Name, ":", err) end
                            
                            
                        end
                    end

                    
                    if OpenNearbyDoors_Enabled then
                        local openValue = valuesFolder:FindFirstChild("Open")
                         
                        local knobArgument = doorInstance:FindFirstChild("Knob2") or doorInstance:FindFirstChild("Knob")

                         
                        if openValue and knobArgument and typeof(openValue.Value) == "boolean" and openValue.Value == false then
                            
                            local isLocked = valuesFolder:FindFirstChild("Locked")
                            if not isLocked or isLocked.Value == false or not UnlockNearbyDoors_Enabled then
                                 
                                local success, err = pcall(function() toggleEvent:FireServer("Open", knobArgument) end)
                                if not success then warn("OpenNearbyDoors: Error firing event for", doorInstance.Name, ":", err) end
                            end
                        end
                    end
                end 
            end 
        end 

        task.wait(waitTime) 
    end 
    NearbyDoorInteraction_Coroutine = nil 
end


local function StartStopDoorInteractionLoop()
    
    local shouldRun = OpenNearbyDoors_Enabled or UnlockNearbyDoors_Enabled

    if shouldRun and not NearbyDoorInteraction_Coroutine then
        
        NearbyDoorInteraction_Coroutine = task.spawn(NearbyDoorInteraction_Loop)
    elseif not shouldRun and NearbyDoorInteraction_Coroutine then
         
         
    end
end

function OpenNearbyDoors_Enable()
    if OpenNearbyDoors_Enabled then return end
    OpenNearbyDoors_Enabled = true
    StartStopDoorInteractionLoop()
end

function OpenNearbyDoors_Disable()
    if not OpenNearbyDoors_Enabled then return end
    OpenNearbyDoors_Enabled = false
    StartStopDoorInteractionLoop()
end


function UnlockNearbyDoors_Enable()
    if UnlockNearbyDoors_Enabled then return end
    UnlockNearbyDoors_Enabled = true
    StartStopDoorInteractionLoop()
end

function UnlockNearbyDoors_Disable()
    if not UnlockNearbyDoors_Enabled then return end
    UnlockNearbyDoors_Enabled = false
    StartStopDoorInteractionLoop()
end

local AutoPickupMoney_Enabled = false
local AutoPickupMoney_Connection = nil
local AutoPickupMoney_Coroutine = nil 

local function AutoPickupMoney_Logic()
    
    local RunService = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")

    local cashFolder = Workspace.Filter:FindFirstChild("SpawnedBread")
    local remoteEvent = ReplicatedStorage.Events:FindFirstChild("CZDPZUS")

    if not cashFolder then
        warn("AutoPickupMoney: Could not find Workspace.Filter.SpawnedBread folder.")
        AutoPickupMoney_Disable() 
        return
    end
    if not remoteEvent then
        warn("AutoPickupMoney: Could not find ReplicatedStorage.Events.CZDPZUS RemoteEvent.")
        AutoPickupMoney_Disable() 
        return
    end

    
    if not CoolDowns then CoolDowns = {} end
    if not CoolDowns.AutoPickUps then CoolDowns.AutoPickUps = {} end
    if CoolDowns.AutoPickUps.MoneyCooldown == nil then CoolDowns.AutoPickUps.MoneyCooldown = false end
     
    if not Settings then Settings = {} end
    if Settings.IsDead == nil then Settings.IsDead = false end 


    AutoPickupMoney_Connection = Hub:Connect(RunService.RenderStepped, function()
        
        if not AutoPickupMoney_Enabled then return end

        
        if Settings.IsDead then return end

        local player = Players.LocalPlayer
        local character = player and player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        
        if not hrp then return end

        
        if CoolDowns.AutoPickUps.MoneyCooldown then return end

        local rootPosition = hrp.Position
        for i, v in ipairs(cashFolder:GetChildren()) do
            
            if (rootPosition - v.Position).Magnitude < 5 then
                
                if not CoolDowns.AutoPickUps.MoneyCooldown then
                    CoolDowns.AutoPickUps.MoneyCooldown = true
                    pcall(function() 
                        remoteEvent:FireServer(v)
                    end)

                    task.wait(1) 

                    CoolDowns.AutoPickUps.MoneyCooldown = false
                    break 
                end
            end
        end
    end)
end

local function AutoPickupMoney_Enable()
    if AutoPickupMoney_Enabled then return end
    AutoPickupMoney_Enabled = true

    
    if AutoPickupMoney_Connection then
        AutoPickupMoney_Connection:Disconnect()
        AutoPickupMoney_Connection = nil
    end
     
    if AutoPickupMoney_Coroutine then
        coroutine.close(AutoPickupMoney_Coroutine)
        AutoPickupMoney_Coroutine = nil
    end

    
    AutoPickupMoney_Coroutine = coroutine.create(AutoPickupMoney_Logic)
    coroutine.resume(AutoPickupMoney_Coroutine)

    
    
end

local function AutoPickupMoney_Disable()
    if not AutoPickupMoney_Enabled then return end
    AutoPickupMoney_Enabled = false

    
    if AutoPickupMoney_Connection then
        AutoPickupMoney_Connection:Disconnect()
        AutoPickupMoney_Connection = nil
    end
    
    if AutoPickupMoney_Coroutine then
        coroutine.close(AutoPickupMoney_Coroutine)
        AutoPickupMoney_Coroutine = nil
    end

    
    if CoolDowns and CoolDowns.AutoPickUps then
        CoolDowns.AutoPickUps.MoneyCooldown = false
    end

     
    
end


local Fly_Enabled = false
local Fly_Bind = nil
local Fly_Connection
local Fly_Speed = 50

local function Fly_Enable()
    if Fly_Enabled then
        return
    end
    Fly_Enabled = true

    Fly_Connection = Hub:Connect(RunService.RenderStepped, function(dt)
        if not Fly_Enabled then
            return
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0,1,0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDir = moveDir - Vector3.new(0,1,0)
            end

            if moveDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (moveDir.Unit * Fly_Speed * dt)
            end
        end
    end)
end

local function Fly_Disable()
    if not Fly_Enabled then
        return
    end
    Fly_Enabled = false
    if Fly_Connection then
        Fly_Connection:Disconnect()
        Fly_Connection = nil
    end
end

local FullBright_Enabled = false
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")


local OriginalValues = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ColorShift_Top = Lighting.ColorShift_Top,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
}

local FullBright_Connection = nil

local function FullBright_Enable()
	if FullBright_Enabled then
		return
	end
	FullBright_Enabled = true
	
	
	Lighting.Brightness = 5
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.new(1, 1, 1)
	Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100000

	
	FullBright_Connection = Hub:Connect(RunService.RenderStepped, function()
		if not FullBright_Enabled then
			FullBright_Connection:Disconnect()
			return
		end
		
		if Lighting.Brightness ~= 5 then Lighting.Brightness = 5 end
		if Lighting.ClockTime ~= 14 then Lighting.ClockTime = 14 end
		if Lighting.Ambient ~= Color3.new(1, 1, 1) then Lighting.Ambient = Color3.new(1, 1, 1) end
		if Lighting.OutdoorAmbient ~= Color3.new(1, 1, 1) then Lighting.OutdoorAmbient = Color3.new(1, 1, 1) end
		if Lighting.ColorShift_Top ~= Color3.new(0, 0, 0) then Lighting.ColorShift_Top = Color3.new(0, 0, 0) end
		if Lighting.FogStart ~= 100000 then Lighting.FogStart = 100000 end
		if Lighting.FogEnd ~= 100000 then Lighting.FogEnd = 100000 end
	end)
end

local function FullBright_Disable()
	if not FullBright_Enabled then
		return
	end
	FullBright_Enabled = false
	
	if FullBright_Connection then
		FullBright_Connection:Disconnect()
		FullBright_Connection = nil
	end
	
	
	Lighting.Brightness = OriginalValues.Brightness
	Lighting.ClockTime = OriginalValues.ClockTime
	Lighting.Ambient = OriginalValues.Ambient
	Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient
	Lighting.ColorShift_Top = OriginalValues.ColorShift_Top
	Lighting.FogStart = OriginalValues.FogStart
	Lighting.FogEnd = OriginalValues.FogEnd
end


local Fov_Enabled = false
local Fov_Value = 80
local Camera = game.Workspace.Camera
local Original_Fov = Camera.FieldOfView

local function Fov_Enable()
    Fov_Enabled = true
end

local function Fov_Disable()
    Fov_Enabled = false
    Camera.FieldOfView = Original_Fov
end


game:GetService("RunService").RenderStepped:Connect(function()
    if Fov_Enabled then
        
        Camera.FieldOfView = Fov_Value
    end
end)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


local LocalPlayer = Players.LocalPlayer
local Noclip_Connection = nil
local Noclip_Enabled = false
local originalCollisions = {} 


local function Noclip_Enable()
    if Noclip_Enabled then
        return
    end

    Noclip_Enabled = true

    
    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                
                if part.CanCollide then
                    originalCollisions[part] = true
                    part.CanCollide = false
                end
            end
        end
    end

    
    if not Noclip_Connection then
        Noclip_Connection = Hub:Connect(RunService.RenderStepped, function()
            
            if not Noclip_Enabled then
                return
            end
            
            
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end


local function Noclip_Disable()
    if not Noclip_Enabled then
        return
    end

    Noclip_Enabled = false

    
    if Noclip_Connection then
        Noclip_Connection:Disconnect()
        Noclip_Connection = nil
    end

    
    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                
                if originalCollisions[part] then
                    part.CanCollide = true
                end
            end
        end
    end

    
    originalCollisions = {}
end


local AdminCheck_Enabled = false 
local AdminCheck_Connection = nil

local staffPlayers = {
    groups = {
        [4165692] = { 
            ["Tester"] = true, ["Contributor"] = true, ["Tester+"] = true, ["Developer"] = true,
            ["Developer+"] = true, ["Community Manager"] = true, ["Manager"] = true, ["Owner"] = true
        },
        [32406137] = { 
            ["Junior"] = true, ["Moderator"] = true, ["Senior"] = true, ["Administrator"] = true,
            ["Manager"] = true, ["Holder"] = true
        },
        [8024440] = { 
            ["zzzz"] = true, ["reshape enjoyer"] = true, ["i heart reshape"] = true, ["reshape superfan"] = true
        },
        [14927228] = { 
            ["♞"] = true
        }
        
    }, 
    users = { 
         3294804378, 93676120, 54087314, 81275825, 140837601, 1229486091, 46567801, 418086275, 29706395,
         3717066084, 1424338327, 5046662686, 5046661126, 5046659439, 418199326, 1024216621, 1810535041,
         63238912, 111250044, 63315426, 730176906, 141193516, 194512073, 193945439, 412741116, 195538733,
         102045519, 955294, 957835150, 25689921, 366613818, 281593651, 455275714, 208929505, 96783330,
         156152502, 93281166, 959606619, 142821118, 632886139, 175931803, 122209625, 278097946, 142989311,
         1517131734, 446849296, 87189764, 67180844, 9212846, 47352513, 48058122, 155413858, 10497435,
         513615792, 55893752, 55476024, 151691292, 136584758, 16983447, 3111449, 94693025, 271400893,
         5005262660, 295331237, 64489098, 244844600, 114332275, 25048901, 69262878, 50801509, 92504899,
         42066711, 50585425, 31365111, 166406495, 2457253857, 29761878, 21831137, 948293345, 439942262,
         38578487, 1163048, 7713309208, 3659305297, 15598614, 34616594, 626833004, 198610386, 153835477,
         3923114296, 3937697838, 102146039, 119861460, 371665775, 1206543842, 93428604, 1863173316, 90814576,
         374665997, 423005063, 140172831, 42662179, 9066859, 438805620, 14855669, 727189337, 1871290386,
         608073286
         
    } 
} 

local function hasTracker(player)
    if not player or not player:IsA("Player") then return false, nil end
    
    local children = player:GetChildren()
    for i = 1, #children do
        local child = children[i]
        
        if typeof(child.Name) == "string" and string.sub(child.Name, -8) == "Tracker$" then
            local trackedPlayerName = string.sub(child.Name, 1, -9) 
             if Players:FindFirstChild(trackedPlayerName) then
                return true, trackedPlayerName
            end
        end
    end
    return false, nil
end

local function isStaff(player)
    if not player or not player:IsA("Player") then return false end

    
    if staffPlayers.groups then
        for groupID, roles in pairs(staffPlayers.groups) do
            
            local successRank, rank = pcall(function() return player:GetRankInGroup(groupID) end)
            if successRank and rank and rank > 0 then
                
                local successRole, roleName = pcall(function() return player:GetRoleInGroup(groupID) end)
                if successRole and roleName and roles[roleName] then
                    return true, roleName, groupID
                end
            end
        end
    end

    
    if staffPlayers.users then
        for i = 1, #staffPlayers.users do
            if player.UserId == staffPlayers.users[i] then
                return true, "UserID", player.UserId 
            end
        end
    end

    return false
end

local function kickformat(staffInfo)
    if not staffInfo or not staffInfo.Staff then return "Staff detected." end 
    local message = "Staff detected:\n"
    for i, staff in ipairs(staffInfo.Staff) do
        local idType = "Role"
        local idValue = staff.Role or "Unknown"
        if staff.Role == "UserID" then
            idType = "UserID"
            idValue = staff.GroupId or "Unknown" 
        elseif staff.Role == "Tracker User" then
             idType = "Tracker"
             idValue = "Active"
        end

        message = message .. string.format(
            "- %s (%s: %s)%s",
            staff.Name or "Unknown",
            idType,
            idValue,
            staff.TrackedPlayer and " - Tracking: " .. staff.TrackedPlayer or ""
        )
        if i < #staffInfo.Staff then
            message = message .. "\n"
        end
    end
    return message
end

local function kickWithStaffInfo(staffInfo)
    local kickMsg = kickformat(staffInfo)
    
    if LocalPlayer then
        LocalPlayer:Kick("Staff joined\n\n" .. kickMsg)
    end
end

local function checkCurrentStaff()
    local staffFound = {}
    local currentPlayers = Players:GetPlayers()
    for i = 1, #currentPlayers do
        local player = currentPlayers[i]
        if player ~= LocalPlayer then 
            local isPlayerStaff, role, groupID = isStaff(player)
            local hasTrackers, trackedPlayer = hasTracker(player)

            if isPlayerStaff or hasTrackers then
                table.insert(staffFound, {
                    Name = player.Name,
                    Role = hasTrackers and "Tracker User" or role,
                    GroupId = groupID,
                    TrackedPlayer = trackedPlayer
                })
            end
        end
    end

    if #staffFound > 0 then
        kickWithStaffInfo({Staff = staffFound})
        return true 
    end
    return false 
end


local function onPlayerJoining(player)
     if not AdminCheck_Enabled then return end 

     local isPlayerStaff, role, groupID = isStaff(player)
     local hasTrackers, trackedPlayer = hasTracker(player)

     if isPlayerStaff or hasTrackers then
         local staffInfo = {
             Staff = {{
                 Name = player.Name,
                 Role = hasTrackers and "Tracker User" or role,
                 GroupId = groupID,
                 TrackedPlayer = trackedPlayer
             }}
         }
         kickWithStaffInfo(staffInfo)
     end
end


local function AdminCheck_Enable()
    if AdminCheck_Enabled then return end
    AdminCheck_Enabled = true 

    
    
    
    
    

    print("Admin Check v2.1 Enabling...")

    
    if AdminCheck_Connection then AdminCheck_Connection:Disconnect() end

    
    AdminCheck_Connection = Hub:Connect(Players.PlayerAdded, onPlayerJoining)
    print("Admin Check 2.1 Monitoring started.")

    
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Staff Detection", Text = "Monitoring active", Duration = 5,
            Icon = "rbxassetid://121588751997553" 
        })
    end)

    
    task.spawn(function()
        print("Admin Check: Running initial check on current players in background...")
        local foundStaff = checkCurrentStaff() 

        if foundStaff then
            
            
            
            AdminCheck_Enabled = false
            warn("Admin Check: Staff found by background check. Kicked.")
            
            if AdminCheck_Connection then 
                 AdminCheck_Connection:Disconnect()
                 AdminCheck_Connection = nil
            end
        else
             print("Admin Check: Initial background check complete, no staff found.")
        end
    end)
    
end

local function AdminCheck_Disable()
    if not AdminCheck_Enabled then return end
    AdminCheck_Enabled = false

    if AdminCheck_Connection then
        AdminCheck_Connection:Disconnect()
        AdminCheck_Connection = nil
    end
    print("Admin Check 2.1 Disabled.")
end

local AntiAFK_Enabled_Dummy = true
local AntiAFK_Bind = nil 
local function AntiAFK_Enable()
    AntiAFK_Enabled_Dummy = true
end
local function AntiAFK_Disable()
    AntiAFK_Enabled_Dummy = false
end

local MeleeAura_Enabled = false
local MeleeAura_Connection

local runAttackLoop do
    local plrs = game:GetService("Players")
    local me = plrs.LocalPlayer
    local run = game:GetService("RunService")
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local eventsFolder = replicatedStorage:WaitForChild("Events")

    
    
    
    
    local remoteFunctionPath = "XMHH.2" 
    local remoteEventPath = "XMHH2.2" 

    local remote1 = eventsFolder:WaitForChild(remoteFunctionPath) 
    local remote2 = eventsFolder:WaitForChild(remoteEventPath)    
    

    local maxdist = 5

    local function Attack(target)
        
        if not (target and target:FindFirstChild("Head")) then return end

        local char = me.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        
        if not remote1 or not remote1:IsA("RemoteFunction") then
            warn("MeleeAura Error: Cannot find required RemoteFunction at: ReplicatedStorage.Events." .. remoteFunctionPath .. " or it's not a RemoteFunction.")
            MeleeAura_Disable() 
            return
        end
        if not remote2 or not remote2:IsA("RemoteEvent") then
            warn("MeleeAura Error: Cannot find required RemoteEvent at: ReplicatedStorage.Events." .. remoteEventPath .. " or it's not a RemoteEvent.")
            MeleeAura_Disable() 
            return
        end

        
        
        local arg1 = {
            [1] = "🍞",
            [2] = tick(),
            [3] = tool,
            [4] = "43TRFWX",
            [5] = "Normal",
            [6] = tick(),
            [7] = true
        }
        local success1, result = pcall(function()
            return remote1:InvokeServer(unpack(arg1))
        end)

        if not success1 then
            warn("MeleeAura Error: InvokeServer on " .. remoteFunctionPath .. " failed:", result)
            
            return 
        end
        

        task.wait(0.1) 

        
        local Handle = tool and (tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle")) or (char and char:FindFirstChild("Right Arm"))
        local head = target:FindFirstChild("Head")

        if Handle and head and hrp then 
            
            local arg2 = {
                [1] = "🍞",
                [2] = tick(),
                [3] = tool,
                [4] = "2389ZFX34",
                [5] = result, 
                [6] = false,
                [7] = Handle,
                [8] = head,
                [9] = target,
                [10] = hrp.Position, 
                [11] = head.Position
            }
            local success2, errorMsg2 = pcall(function()
                remote2:FireServer(unpack(arg2))
            end)
            if not success2 then
                warn("MeleeAura Error: FireServer on " .. remoteEventPath .. " failed:", errorMsg2)
            end
            
        end
    end

    runAttackLoop = function()
        return Hub:Connect(run.RenderStepped, function()
            if not MeleeAura_Enabled then return end 
            local char = me.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then 
                for _, plr in ipairs(plrs:GetPlayers()) do
                    if plr ~= me then
                        local c = plr.Character
                        local hrp2 = c and c:FindFirstChild("HumanoidRootPart")
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        
                        if hrp2 and hum then
                            local dist = (hrp.Position - hrp2.Position).Magnitude
                            
                            if dist < maxdist and hum.Health > 15 and not c:FindFirstChildOfClass("ForceField") then
                                Attack(c)
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function MeleeAura_Enable()
    if MeleeAura_Enabled then return end
    MeleeAura_Enabled = true
    
    if MeleeAura_Connection and MeleeAura_Connection.Connected then
        MeleeAura_Connection:Disconnect()
    end
    MeleeAura_Connection = runAttackLoop()
end

local function MeleeAura_Disable()
    if not MeleeAura_Enabled then return end
    MeleeAura_Enabled = false
    if MeleeAura_Connection and MeleeAura_Connection.Connected then 
        MeleeAura_Connection:Disconnect()
        MeleeAura_Connection = nil
    end
    
    
    for key, bindData in pairs(activeBinds) do
        if bindData.onEnable == MeleeAura_Enable then
             if bindData.updateFn then
                 pcall(bindData.updateFn) 
             end
             break 
        end
    end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local EventsFolder = ReplicatedStorage:WaitForChild("Events", 10) 

local GNX_S_Remote = EventsFolder and EventsFolder:WaitForChild("GNX_S", 5)

local ZFKLF_H_Remote = EventsFolder and EventsFolder:WaitForChild("ZFKLF__H", 5)


local function RandomString(length)
    local res = ""
    for i = 1, length do
        res = res .. string.char(math.random(97, 122))
    end
    return res
end


local function GetClosestEnemy_Rage()
    local closestEnemy = nil
    local shortestDistance = 200 

    local myChar = LocalPlayer.Character 
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, player in ipairs(Players:GetPlayers()) do 
        if player ~= LocalPlayer then
            local enemyChar = player.Character
            local enemyHRP = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
            local enemyHum = enemyChar and enemyChar:FindFirstChildOfClass("Humanoid")

            if enemyHRP and enemyHum and enemyHum.Health > 15 and not enemyChar:FindFirstChildOfClass("ForceField") then
                local distance = (myHRP.Position - enemyHRP.Position).Magnitude
                if distance < shortestDistance then
                    
                    shortestDistance = distance
                    closestEnemy = player
                end
            end
        end
    end
    return closestEnemy
end


local function Shoot_Rage(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end

    local targetPart = targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetPart then return end

    local myChar = LocalPlayer.Character
    local tool = myChar and myChar:FindFirstChildOfClass("Tool")
    
    if not tool then
        return
    end

    local currentCam = workspace.CurrentCamera
    local hitPosition = targetPart.Position
    local hitDirection = (hitPosition - currentCam.CFrame.Position).Unit
    local randomKey = RandomString(30) .. "0"

    if not GNX_S_Remote or not ZFKLF_H_Remote then
        warn("Ragebot Error: Required remote events not found.")
        
        if typeof(Ragebot_Disable) == "function" then
            Ragebot_Disable()
        end
        return
    end

    
    local success1, err1 = pcall(function()
        GNX_S_Remote:FireServer( 
            tick(),
            randomKey,
            tool,
            "FDS9I83", 
            currentCam.CFrame.Position,
            {hitDirection},
            false
        )
    end)
    if not success1 then warn("Ragebot: FireServer GNX_S failed:", err1) end

    
    local success2, err2 = pcall(function()
        ZFKLF_H_Remote:FireServer( 
            
            "🧈",
            
            tool,
            randomKey,
            1, 
            targetPart,
            hitPosition,
            hitDirection,
            nil, 
            nil  
        )
    end)
    if not success2 then warn("Ragebot: FireServer ZFKLF__H failed:", err2) end
end


local Ragebot_Enabled = false 
local Ragebot_Coroutine = nil 
local Ragebot_Target = nil 

local function RagebotLoop()
    while Ragebot_Enabled do
        local target = GetClosestEnemy_Rage()
        Ragebot_Target = target
        if target then
            Shoot_Rage(target)
            task.wait(0.05) 
        else
            task.wait(0.1) 
        end
    end
    Ragebot_Target = nil
    Ragebot_Coroutine = nil
end

local function Ragebot_Enable()
    
    if not GNX_S_Remote or not ZFKLF_H_Remote then
         warn("Ragebot cannot enable: Required remote events not found.")
         pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Ragebot Error", Text = "Required remotes missing.", Duration = 5}) end)
         
         for k, v in pairs(activeBinds or {}) do if v.onEnable == Ragebot_Enable then if v.updateFn then task.wait(); pcall(v.updateFn) end; break; end end
         return
    end
    
    if Ragebot_Enabled then return end
    Ragebot_Enabled = true
    if not Ragebot_Coroutine then
        Ragebot_Coroutine = coroutine.create(RagebotLoop)
        coroutine.resume(Ragebot_Coroutine)
    end
end

local function Ragebot_Disable()
    
    if not Ragebot_Enabled then return end
    Ragebot_Enabled = false
end

local services = {
	ws = game:GetService("Workspace"),
	pl = game:GetService("Players"),
	rs_rep = game:GetService("ReplicatedStorage"),
	rs = game:GetService("RunService"),
	uis = game:GetService("UserInputService")
}


local localPlayer = services.pl.LocalPlayer
local task = task
local wait = task.wait

local autofarmEnabled = false
local autofarmCooldown = false
local ignoredSafes = {}


local pingThreshold = 100 
local isPingHigh = false


local CoolDowns = { AutoPickUps = { MoneyCooldown = false } }

local Settings = { IsDead = false }


local function getPing()
	local ping = localPlayer:GetNetworkPing()
	return ping * 1000 
end


task.spawn(function()
	while task.wait(5) do 
		local ping = getPing()
		if ping > pingThreshold then
			isPingHigh = true
		else
			isPingHigh = false
		end
	end
end)

local Shadow_Active = false 
local Shadow_Usable = true 

do 
	repeat task.wait() until game:IsLoaded();

	local svc_ref = cloneref or function(...) return ... end;

	local GS = setmetatable({}, {
		__index = function(_, k)
			return svc_ref(game:GetService(k));
		end
	});

	local P: Player = GS.Players.LocalPlayer;
	local Char: Model = P.Character or P.CharacterAdded:Wait();
	local HMND
	local HRP

	local function RefreshCharRefs()
		Char = P.Character
		if Char then
			HRP = Char:FindFirstChild("HumanoidRootPart")
			HMND = Char:FindFirstChildOfClass("Humanoid")
		else
			HRP = nil
			HMND = nil
		end
	end

	RefreshCharRefs() 

	local AnimTrack_Cache = nil
	local CamoAnim = Instance.new("Animation", nil);
	CamoAnim.AnimationId = "rbxassetid://215384594";

	local RS: RunService = GS.RunService;
	local UpdateFrame = RS.Heartbeat;
	local WaitRender = RS.RenderStepped;

	local CoreGS: CoreGui = GS.CoreGui;
	local StartGS: StarterGui = GS.StarterGui;

	
	local HUD = Instance.new("ScreenGui");
	HUD.Name = "ShadowWarningHUD";
	HUD.Parent = CoreGS;
	HUD.ResetOnSpawn = false;
	HUD.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

	local WarningText = Instance.new("TextLabel", HUD);
	WarningText.Text = "⚠️You are visible⚠️";
	WarningText.Visible = false;
	WarningText.Size = UDim2.new(0, 200, 0, 30);
	WarningText.Position = UDim2.new(0.5, -100, 0.85, 0);
	WarningText.BackgroundTransparency = 1;
	WarningText.Font = Enum.Font.GothamSemibold;
	WarningText.TextSize = 24;
	WarningText.TextColor3 = Color3.fromRGB(255, 255, 0);
	WarningText.TextStrokeTransparency = 0.5;
	WarningText.ZIndex = 10;

	
	if Char and not Char:FindFirstChild("Torso") then
		pcall(function()
			StartGS:SetCore("SendNotification", {
				Title = "Shadow Mode FAILED",
				Text = "Feature requires R6 Avatar.",
				Duration = 5,
			});
		end)
		Shadow_Usable = false
	end


	local function CheckGrounded()
		return HMND and HMND:IsDescendantOf(workspace) and HMND.FloorMaterial ~= Enum.Material.Air;
	end

	local function CacheAnimTrack()
		if AnimTrack_Cache then
			pcall(function() AnimTrack_Cache:Stop() end)
			AnimTrack_Cache = nil
		end
		if HMND then
			local success, result = pcall(function()
				return HMND:LoadAnimation(CamoAnim)
			end)
			if success then
				AnimTrack_Cache = result
				AnimTrack_Cache.Priority = Enum.AnimationPriority.Action4;
			else
				AnimTrack_Cache = nil
			end
		else
			AnimTrack_Cache = nil
		end
	end

	
	local function DeactivateShadow()
		if not Shadow_Active then return end
		Shadow_Active = false;

		if AnimTrack_Cache then
			pcall(function() AnimTrack_Cache:Stop() end)
		end

		if HMND then
			workspace.CurrentCamera.CameraSubject = HMND;
		end

		if Char then
			for _, v in pairs(Char:GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency == 0.5 then
					v.Transparency = 0;
				end
			end
		end
		
		WarningText.Visible = false;
	end

	
	local function ActivateShadow()
		if Shadow_Active or not Shadow_Usable then return end

		RefreshCharRefs()
		if not Char or not HMND or not HRP then
			return
		end
		if not Char:FindFirstChild("Torso") then
			pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode FAILED", Text = "Feature requires R6 Avatar.", Duration = 5}) end)
			return
		end

		Shadow_Active = true;
		workspace.CurrentCamera.CameraSubject = HRP;

		CacheAnimTrack()
	end

	
	local function ShadowStep(deltaTime)
		
		if not Char or not HMND or not HRP or not HMND:IsDescendantOf(workspace) or HMND.Health <= 0 then
			WarningText.Visible = false;
			return
		end

		WarningText.Visible = not CheckGrounded();

		
		local walk_speed = 12
		if HMND.MoveDirection.Magnitude > 0 then
			local velocity_offset = HMND.MoveDirection * walk_speed * deltaTime
			HRP.CFrame = HRP.CFrame + velocity_offset
		end

		local InitialCFrame = HRP.CFrame;
		local InitialCamOffset = HMND.CameraOffset;

		
		local _, yaw_angle = workspace.CurrentCamera.CFrame:ToOrientation();
		HRP.CFrame = CFrame.new(HRP.CFrame.Position) * CFrame.fromOrientation(0, yaw_angle, 0);
		HRP.CFrame = HRP.CFrame * CFrame.Angles(math.rad(90), 0, 0);
		HMND.CameraOffset = Vector3.new(0, 1.44, 0);

		
		if AnimTrack_Cache then
			local successPlay = pcall(function()
				if not AnimTrack_Cache.IsPlaying then
					AnimTrack_Cache:Play();
				end
				AnimTrack_Cache:AdjustSpeed(0);
				AnimTrack_Cache.TimePosition = 0.3;
			end)
			if not successPlay then
				CacheAnimTrack()
			end
		elseif HMND and HMND.Health > 0 then
			CacheAnimTrack()
		end

		
		WaitRender:Wait();

		
		if HMND and HMND:IsDescendantOf(workspace) then
			HMND.CameraOffset = InitialCamOffset;
		end
		if HRP and HRP:IsDescendantOf(workspace) then
			HRP.CFrame = InitialCFrame;
		end

		
		if AnimTrack_Cache then
			pcall(function() AnimTrack_Cache:Stop() end)
		end

		
		if HRP and HRP:IsDescendantOf(workspace) then
			local LookVec = workspace.CurrentCamera.CFrame.LookVector;
			local FlatLook = Vector3.new(LookVec.X, 0, LookVec.Z).Unit;
			if FlatLook.Magnitude > 0.1 then
				local FinalCFrame = CFrame.new(HRP.Position, HRP.Position + FlatLook);
				HRP.CFrame = FinalCFrame;
			end
		end

		
		if Char then
			for _, v in pairs(Char:GetDescendants()) do
				if (v:IsA("BasePart") and v.Transparency ~= 1) then
					v.Transparency = 0.5;
				end
			end
		end
	end

	
	Hub:Connect(UpdateFrame, function(deltaTime)
		if not Shadow_Active or not Shadow_Usable then
			
			if not Shadow_Active and Char then
				for _, v in pairs(Char:GetDescendants()) do
					if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
				end
			end
			WarningText.Visible = false
			return;
		end
		
		ShadowStep(deltaTime)
	end)


	
	Hub:Connect(P.CharacterAdded, function(NewCharacter)
		
		if Shadow_Active then DeactivateShadow() end

		if AnimTrack_Cache then
			pcall(function() AnimTrack_Cache:Stop() end)
			AnimTrack_Cache = nil
		end

		task.wait()

		RefreshCharRefs()

		if not HMND then
			task.wait(0.5)
			RefreshCharRefs()
			if not HMND then
				Shadow_Usable = false
				if Shadow_Active then DeactivateShadow() end
				pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode Error", Text = "Could not verify character type.", Duration = 5}) end)
				return
			end
		end

		if HMND.RigType ~= Enum.HumanoidRigType.R6 then
			Shadow_Usable = false
			if Shadow_Active then DeactivateShadow() end
			pcall(function() StartGS:SetCore("SendNotification", {Title = "Shadow Mode Warning", Text = "Non-R6 Avatar detected (".. tostring(HMND.RigType) .."). Disabled.", Duration = 5}) end)
			return
		else
			Shadow_Usable = true
		end
		
		
		if autofarmEnabled and Shadow_Usable then
			ActivateShadow()
		end
	end)

	Hub:Connect(P.CharacterRemoving, function(OldCharacter)
		if AnimTrack_Cache then
			pcall(function() AnimTrack_Cache:Stop() end)
			AnimTrack_Cache = nil
		end
		WarningText.Visible = false
	end)


	
	_G.ActivateShadow = ActivateShadow
	_G.DeactivateShadow = DeactivateShadow
	_G.IsShadowActive = function() return Shadow_Active end

end 

local Collector_Enabled = false
local Collector_Signal = nil
local Collector_Task = nil

local function Collector_CoreLogic()
	local RS_S = game:GetService("RunService")
	local RS_Rep = game:GetService("ReplicatedStorage")
	local WS = game:GetService("Workspace")

	local function RunCollectorLogic()
		if not Collector_Enabled or Settings.IsDead then return end

		local breadContainer = WS.Filter:FindFirstChild("SpawnedBread")
		local pickupRemote = RS_Rep.Events:FindFirstChild("CZDPZUS")

		if not breadContainer then
			warn("BreadCollector: SpawnedBread folder missing. Pausing pickup logic.")
			return
		end
		if not pickupRemote then
			warn("BreadCollector: Pickup RemoteEvent missing. Pausing pickup logic.")
			return
		end

		local p_char = localPlayer.Character
		local root_part = p_char and p_char:FindFirstChild("HumanoidRootPart")

		if not root_part or CoolDowns.AutoPickUps.MoneyCooldown then return end

		local current_pos = root_part.Position
		for _, item in ipairs(breadContainer:GetChildren()) do
			local dist_sq = (current_pos - item.Position).Magnitude^2
			if dist_sq < 25 and not CoolDowns.AutoPickUps.MoneyCooldown then
				CoolDowns.AutoPickUps.MoneyCooldown = true
				
				pcall(function()
					pickupRemote:FireServer(item)
				end)
				
				task.wait(1.1)
				
				CoolDowns.AutoPickUps.MoneyCooldown = false
				break
			end
		end
	end

	Collector_Signal = Hub:Connect(RS_S.RenderStepped, RunCollectorLogic)
end

local function Collector_Activate()
	if Collector_Enabled then return end
	Collector_Enabled = true

	if Collector_Signal then
		Collector_Signal:Disconnect()
		Collector_Signal = nil
	end
	if Collector_Task then
		coroutine.close(Collector_Task)
		Collector_Task = nil
	end

	Collector_CoreLogic()
end

local function Collector_Deactivate()
	if not Collector_Enabled then return end
	Collector_Enabled = false

	if Collector_Signal then
		Collector_Signal:Disconnect()
		Collector_Signal = nil
	end

	if CoolDowns and CoolDowns.AutoPickUps then
		CoolDowns.AutoPickUps.MoneyCooldown = false
	end
end


local function Autofarm_Enable()
	if autofarmEnabled then return end
	autofarmEnabled = true
	
	_G.ActivateShadow() 
	Collector_Activate() 
	
end


local function Autofarm_Disable()
	if not autofarmEnabled then return end
	autofarmEnabled = false
	
	_G.DeactivateShadow() 
	Collector_Deactivate() 
	
end


task.spawn(function()
	local deathRespawnEvent = services.rs_rep:WaitForChild("Events"):WaitForChild("DeathRespawn")
	while task.wait() do
		local char = localPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 and autofarmEnabled then
				deathRespawnEvent:InvokeServer("KMG4R904")
				task.wait(2) 
			end
		end
	end
end)

Hub:Connect(localPlayer.CharacterAdded, function(character)
	if not autofarmEnabled then
		return
	end

	
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait(1.5)

	
	autofarmCooldown = false
	ignoredSafes = {}
	
	
	Autofarm_Enable()
end)

local function teleportTo(targetPart)
	local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return false
	end

	if not (targetPart and targetPart:IsA("BasePart")) then
		return false
	end

	local success = false
	local attempts = 0
	while not success and attempts < 4 do 
		local targetCframe = targetPart.CFrame
		local targetPos = (targetCframe + targetCframe.LookVector * 2).Position

		hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.pi / 2, 0)
		wait(0.5) 

		
		local isStable = true
		local stabilityChecks = 10 
		local checkInterval = 0.2 

		
		for i = 1, stabilityChecks do
			wait(checkInterval)
			if not hrp or not hrp.Parent then 
				isStable = false
				break
			end
			
			local currentDistance = (hrp.Position - targetPos).Magnitude
			if currentDistance > 5 then 
				isStable = false
				break 
			end
		end

		if isStable then
			success = true
		else
			attempts = attempts + 1
			wait(1) 
		end
	end

	return success
end

local function hasTool(toolName)
	local backpackTool = localPlayer.Backpack:FindFirstChild(toolName)
	local characterTool = localPlayer.Character and localPlayer.Character:FindFirstChild(toolName)
	return backpackTool or characterTool
end


local function findNearestTarget(targetsToIgnore)
	local bredMakurzFolder = services.ws.Map:FindFirstChild("BredMakurz") or services.ws.Filter:FindFirstChild("BredMakurz")
	local char = localPlayer.Character

	if not bredMakurzFolder then
		warn("DIAGNOSTYKA: Nie znaleziono folderu 'BredMakurz' w Map ani Filter.")
		return nil
	end
	if not char then return nil end

	local nearestTarget = nil
	local shortestDistance = math.huge
	local playerPosition = char:FindFirstChild("HumanoidRootPart").Position

	for _, v in ipairs(bredMakurzFolder:GetChildren()) do
		if (string.find(v.Name, "Safe") or string.find(v.Name, "Register")) and not table.find(targetsToIgnore, v) then
			local values = v:FindFirstChild("Values")
			if values then
				local broken = values:FindFirstChild("Broken")
				if broken and broken:IsA("BoolValue") and not broken.Value then
					local targetPart = v.PrimaryPart or v:FindFirstChild("MainPart") or v:FindFirstChild("PosPart")
					if targetPart then
						local distance = (targetPart.Position - playerPosition).Magnitude
						if distance < shortestDistance then
							shortestDistance = distance
							nearestTarget = v
						end
					end
				end
			end
		end
	end
	return nearestTarget
end


local function findNearestDealer()
	local shopz = services.ws.Map:FindFirstChild("Shopz")
	local char = localPlayer.Character

	if not shopz or not char then return nil end

	local nearestDealer = nil
	local shortestDistance = math.huge
	local playerPosition = char:FindFirstChild("HumanoidRootPart").Position

	for _, dealer in ipairs(shopz:GetChildren()) do
		local crowbarStock = dealer:FindFirstChild("CurrentStocks") and dealer.CurrentStocks:FindFirstChild("Crowbar")
		if crowbarStock and crowbarStock.Value > 0 and dealer:FindFirstChild("MainPart") then
			local distance = (dealer.MainPart.Position - playerPosition).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestDealer = dealer
			end
		end
	end
	return nearestDealer
end


local function openSafe(safeModel)
	local equippedCrowbar = hasTool("Crowbar")
	if not equippedCrowbar then
		return
	end
	
	local remoteXMHH = services.rs_rep:WaitForChild("Events"):WaitForChild("XMHH.2")
	local remoteXMHH2 = services.rs_rep:WaitForChild("Events"):WaitForChild("XMHH2.2")
	local safeMainPart = safeModel:WaitForChild("MainPart", 5)

	if not safeMainPart then return end

	local startTime = tick()
	
	while safeModel and safeModel.Parent and safeModel.Values and safeModel.Values.Broken and not safeModel.Values.Broken.Value and (tick() - startTime < 15) do
		local char = localPlayer.Character
		if not char then break end

		local safeOpenValue = remoteXMHH:InvokeServer("\240\159\141\158", tick(), equippedCrowbar, "DZDRRRKI", safeModel, "Register")

		if safeOpenValue == nil then
			wait(1)
			continue
		end

		local currentTime = tick()
		remoteXMHH2:FireServer(
			"\240\159\141\158", currentTime, equippedCrowbar, "2389ZFX34", safeOpenValue, false,
			char["Right Arm"], safeMainPart, safeModel, safeMainPart.Position, safeMainPart.Position
		)
		
		wait(0.2) 
	end
	
	wait(8) 
end

local noTargetCounter = 0 

task.spawn(function()
	while true do
		wait(1) 
		local char = localPlayer.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		
		if humanoid then
			Settings.IsDead = humanoid.Health <= 0
		end
		
		if not autofarmEnabled or autofarmCooldown or not char or not humanoid or humanoid.Health <= 0 or isPingHigh then
			continue
		end
		
		local crowbar = hasTool("Crowbar")
		if not crowbar then
			local dealer = findNearestDealer()
			if dealer then
				if teleportTo(dealer:WaitForChild("MainPart")) then
					wait(1)
					services.rs_rep.Events.BYZERSPROTEC:FireServer(true, "shop", dealer.MainPart, "IllegalStore")
					wait(1)
					local args = {"IllegalStore", "Melees", "Crowbar", dealer.MainPart, nil, true}
					services.rs_rep.Events.SSHPRMTE1:InvokeServer(unpack(args))
					wait(20) 
					services.rs_rep.Events.BYZERSPROTEC:FireServer(false)
				else
					wait(5)
				end
			else
				wait(10)
			end
		else 
			local target = findNearestTarget(ignoredSafes)
			if target then
				noTargetCounter = 0 
				
				if teleportTo(target:WaitForChild("MainPart")) then
					
					if localPlayer.Character:FindFirstChild("Crowbar") == nil then
						local success, err = pcall(function()
							localPlayer.Character.Humanoid:EquipTool(crowbar)
						end)
						if not success then
							task.wait(1)
							pcall(function() localPlayer.Character.Humanoid:EquipTool(crowbar) end)
						end
					end
					
					wait(1)
					openSafe(target)
				else
					table.insert(ignoredSafes, target)
					wait(0.5)
				end
			else 
				noTargetCounter = noTargetCounter + 1
				
				
				if noTargetCounter >= 4 then
					ignoredSafes = {} 
					noTargetCounter = 0 
					wait(15)
				else
					wait(5) 
				end
			end
		end
	end
end)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


local LocalPlayer = Players.LocalPlayer
local Noclip_Connection = nil
local Noclip_Enabled = false
local originalCollisions = {} 


local function Noclip_Enable()
	if Noclip_Enabled then
		return
	end

	Noclip_Enabled = true

	
	local char = LocalPlayer.Character
	if char then
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				
				if part.CanCollide then
					originalCollisions[part] = true
					part.CanCollide = false
				end
			end
		end
	end

	
	if not Noclip_Connection then
		Noclip_Connection = Hub:Connect(RunService.RenderStepped, function()
			
			if not Noclip_Enabled then
				return
			end
			
			
			local char = LocalPlayer.Character
			if char then
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	end
end


local function Noclip_Disable()
	if not Noclip_Enabled then
		return
	end

	Noclip_Enabled = false

	
	if Noclip_Connection then
		Noclip_Connection:Disconnect()
		Noclip_Connection = nil
	end

	
	local char = LocalPlayer.Character
	if char then
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				
				if originalCollisions[part] then
					part.CanCollide = true
				end
			end
		end
	end

	
	originalCollisions = {}
end


_G.Noclip_Enable = Noclip_Enable
_G.Noclip_Disable = Noclip_Disable
_G.IsNoclipActive = function() return Noclip_Enabled end

local players_aim = Players
local localPlayer_aim = LocalPlayer
local CurrentCamera_aim = workspace.CurrentCamera
local TweenService_aim = TweenService
local UserInputService_aim = UserInputService
local mouseLocation_aim = UserInputService_aim.GetMouseLocation
local RunService_aim = RunService


local AimBotSettings = {
    Enabled = false; TeamCheck = false; WallCheck = true; StickyAim = false;
    UseMouse = true; MouseBind = "MouseButton2"; Keybind = nil; 
    ShowFov = false; Fov = 100;
    Smoothing = 0.02; AimPart = "HumanoidRootPart";
    IsAimKeyDown = false; Target = nil; CameraTween = nil;
}


local function IsAlive_aim(Player)
    
    return Player and Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") and Player.Character.Humanoid.Health > 0
end

local function GetTeam_aim(Player)
    
    if not localPlayer_aim.Neutral and Player and Player.Team and game:GetService("Teams"):FindFirstChild(Player.Team.Name) then
        return game:GetService("Teams")[Player.Team.Name];
    end
    return nil;
end


local function isVisible_aim(targetPosition, character)
    
    if not AimBotSettings.WallCheck then
        return true;
    end

    
    local ignoreList = {CurrentCamera_aim}
    if localPlayer_aim.Character then
         table.insert(ignoreList, localPlayer_aim.Character)
    end
    
    if character and character:FindFirstChild("Head") and character.Head.Parent then
        table.insert(ignoreList, character.Head.Parent)
    end

    
    local success, obscured = pcall(function()
        return CurrentCamera_aim:GetPartsObscuringTarget({targetPosition}, ignoreList)
    end)

    
    if not success or obscured == nil then
        return false
    end
    return #obscured == 0;
end


local function CameraGetClosestToMouse_aim()
    
    local AimFov = AimBotSettings.Fov;
    local targetPlayer = nil;

    for i, v in pairs(players_aim:GetPlayers()) do
        if v ~= localPlayer_aim then
            
            if AimBotSettings.TeamCheck ~= true or GetTeam_aim(v) ~= GetTeam_aim(localPlayer_aim) then
                if IsAlive_aim(v) then
                    local char = v.Character
                    
                    local aimPartInstance = char and char:FindFirstChild(AimBotSettings.AimPart)
                    if aimPartInstance then
                        local aimPartPosition = aimPartInstance.Position
                        
                        local successWTV, screen_pos, on_screen = pcall(function() return CurrentCamera_aim:WorldToViewportPoint(aimPartPosition) end)
                        if successWTV and on_screen then
                             local screen_pos_2D = Vector2.new(screen_pos.X, screen_pos.Y)
                             local successMouseLoc, mousePos = pcall(mouseLocation_aim, UserInputService_aim)
                             if not successMouseLoc then mousePos = Vector2.new() end 
                             local new_magnitude = (screen_pos_2D - mousePos).Magnitude
                             
                             if new_magnitude < AimFov and isVisible_aim(aimPartPosition, char) then
                                AimFov = new_magnitude;
                                targetPlayer = v;
                             end
                        end
                    end
                end
            end
        end
    end
    return targetPlayer;
end


Hub:Connect(UserInputService_aim.InputBegan, function(input, gameProcessedEvent)
    
    if not AimBotSettings then return end
    if gameProcessedEvent or not AimBotSettings.Enabled then return end

    if not AimBotSettings.UseMouse and AimBotSettings.Keybind and input.KeyCode == AimBotSettings.Keybind then
        AimBotSettings.Target = CameraGetClosestToMouse_aim();
        AimBotSettings.IsAimKeyDown = true;
    elseif AimBotSettings.UseMouse then
        local bind = ""
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bind = "MouseButton1"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            bind = "MouseButton2"
        end

        if bind == AimBotSettings.MouseBind then
            AimBotSettings.Target = CameraGetClosestToMouse_aim();
            AimBotSettings.IsAimKeyDown = true;
        end
    end
end)


Hub:Connect(UserInputService_aim.InputEnded, function(input, gameProcessedEvent)
     
    if not AimBotSettings then return end
    if gameProcessedEvent or not AimBotSettings.Enabled then return end

    if not AimBotSettings.UseMouse and AimBotSettings.Keybind and input.KeyCode == AimBotSettings.Keybind then
        AimBotSettings.IsAimKeyDown = false;
        AimBotSettings.Target = nil;
        if AimBotSettings.CameraTween then
            AimBotSettings.CameraTween:Cancel();
            AimBotSettings.CameraTween = nil;
        end
    elseif AimBotSettings.UseMouse then
        local bind = ""
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bind = "MouseButton1"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            bind = "MouseButton2"
        end

        if bind == AimBotSettings.MouseBind then
            AimBotSettings.IsAimKeyDown = false;
            AimBotSettings.Target = nil;
            if AimBotSettings.CameraTween then
                AimBotSettings.CameraTween:Cancel();
                AimBotSettings.CameraTween = nil;
            end
        end
    end
end)


Hub:Connect(RunService_aim.Heartbeat, function(deltaTime)
    
    
    if AimBotSettings and AimBotSettings.Enabled then
        if AimBotSettings.IsAimKeyDown then
            local currentTarget = AimBotSettings.Target

            if AimBotSettings.StickyAim then
                 if currentTarget ~= nil and IsAlive_aim(currentTarget) then
                    local targetChar = currentTarget.Character
                    local aimPart = targetChar and targetChar:FindFirstChild(AimBotSettings.AimPart)
                    if aimPart then
                        if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil; end
                        
                        local networkPing = 0
                        local successPing, resultPing = pcall(function() return localPlayer_aim:GetNetworkPing() end)
                        if successPing then networkPing = resultPing end
                        local predictionOffset = aimPart.Velocity and aimPart.Velocity * (networkPing * 0.1) or Vector3.new() 
                        local targetCFrame = CFrame.new(CurrentCamera_aim.CFrame.Position, aimPart.Position + predictionOffset)

                        
                        local successTween, tweenResult = pcall(function()
                            AimBotSettings.CameraTween = TweenService_aim:Create(CurrentCamera_aim, TweenInfo.new(AimBotSettings.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame});
                            AimBotSettings.CameraTween:Play();
                        end)
                        if not successTween then warn("Aimbot Tween creation failed:", tweenResult) end

                    else
                        AimBotSettings.Target = nil
                        if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil; end
                    end
                 else
                    local newTarget = CameraGetClosestToMouse_aim()
                    AimBotSettings.Target = newTarget
                    currentTarget = newTarget

                    if currentTarget and IsAlive_aim(currentTarget) then
                        local targetChar = currentTarget.Character
                        local aimPart = targetChar and targetChar:FindFirstChild(AimBotSettings.AimPart)
                        if aimPart then
                            if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil; end
                             local networkPing = 0; local sP, rP=pcall(function() return localPlayer_aim:GetNetworkPing() end); if sP then networkPing=rP end
                             local predictionOffset = aimPart.Velocity and aimPart.Velocity * (networkPing * 0.1) or Vector3.new()
                             local targetCFrame = CFrame.new(CurrentCamera_aim.CFrame.Position, aimPart.Position + predictionOffset)

                             local sT, tR = pcall(function()
                                AimBotSettings.CameraTween = TweenService_aim:Create(CurrentCamera_aim, TweenInfo.new(AimBotSettings.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame});
                                AimBotSettings.CameraTween:Play();
                             end)
                             if not sT then warn("Aimbot Tween creation failed (new target):", tR) end
                        end
                    elseif AimBotSettings.CameraTween then
                         AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil;
                    end
                 end

            else 
                local target = CameraGetClosestToMouse_aim();
                if target ~= nil and IsAlive_aim(target) then
                    local targetChar = target.Character
                    local aimPart = targetChar and targetChar:FindFirstChild(AimBotSettings.AimPart)
                    if aimPart then
                        if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil; end
                        local networkPing = 0; local sP, rP=pcall(function() return localPlayer_aim:GetNetworkPing() end); if sP then networkPing=rP end
                        local predictionOffset = aimPart.Velocity and aimPart.Velocity * (networkPing * 0.1) or Vector3.new()
                        local targetCFrame = CFrame.new(CurrentCamera_aim.CFrame.Position, aimPart.Position + predictionOffset)

                        local sT, tR = pcall(function()
                            AimBotSettings.CameraTween = TweenService_aim:Create(CurrentCamera_aim, TweenInfo.new(AimBotSettings.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame});
                            AimBotSettings.CameraTween:Play();
                        end)
                         if not sT then warn("Aimbot Tween creation failed (non-sticky):", tR) end

                    else
                         if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween = nil; end
                    end
                elseif AimBotSettings.CameraTween ~= nil then
                    AimBotSettings.CameraTween:Cancel();
                    AimBotSettings.CameraTween = nil;
                end
            end
        end
    
    
       
    end
end)


local function Aimbot_Enable()
    if AimBotSettings then AimBotSettings.Enabled=true else warn("Cannot enable Aimbot: AimBotSettings is nil") end
end
local function Aimbot_Disable()
    if AimBotSettings then
        AimBotSettings.Enabled=false; AimBotSettings.IsAimKeyDown=false; AimBotSettings.Target=nil;
        if AimBotSettings.CameraTween then AimBotSettings.CameraTween:Cancel(); AimBotSettings.CameraTween=nil end
    else
         warn("Cannot disable Aimbot: AimBotSettings is nil")
    end
end

local UserInputService_stam = UserInputService 
local isInfiniteStaminaEnabled = false 
local oldStaminaFunction = nil 
local targetFunction = nil 

do 
    local success_hook, result_hook = pcall(function()
        
        local env = nil
        local success_env1, env1 = pcall(getrenv)
        if success_env1 then env = env1 else local success_env2, env2 = pcall(getfenv); if success_env2 then env = env2 end end

        if env and env._G and env._G.S_Take then
             local success_upval, upval = pcall(getupvalue, env._G.S_Take, 2)
             if success_upval and type(upval) == 'function' then
                 targetFunction = upval
             else
                 warn("Inf Stamina: Nie można pobrać upvalue 2 lub nie jest to funkcja.")
             end
        else
             warn("Inf Stamina: Nie znaleziono _G.S_Take.")
        end

        
        if targetFunction then
             local hookSuccess, hookResult = pcall(function()
                 oldStaminaFunction = hookfunction(
                     targetFunction,
                     function(v1, ...) 
                         local args = {...} 
                         if isInfiniteStaminaEnabled then
                             
                             
                             return oldStaminaFunction(0, unpack(args))
                         else
                             
                             return oldStaminaFunction(v1, unpack(args))
                         end
                     end
                 )
             end)
             if not hookSuccess then
                  warn("Inf Stamina: hookfunction nie powiódł się: ", hookResult)
                  oldStaminaFunction = nil 
             end
        end
    end)
    if not success_hook then
        warn("Inf Stamina: Wystąpił błąd podczas próby hookowania: ", result_hook)
    end
end 


local function InfiniteStamina_Enable()
    if not oldStaminaFunction then
        warn("Inf Stamina: Funkcja staminy nie została zahaczona. Infinite Stamina nie działa.")
        
        return
    end
    isInfiniteStaminaEnabled = true
end

local function InfiniteStamina_Disable()
    
    isInfiniteStaminaEnabled = false
end


local Invis_Fixed = true 

do 
    repeat task.wait() until game:IsLoaded();

    local cloneref = cloneref or function(...) return ... end;

    local Service = setmetatable({}, {
        __index = function(_, k)
            return cloneref(game:GetService(k));
        end
    });

    local Player: Player = Service.Players.LocalPlayer; 
    local Character: Model = Player.Character or Player.CharacterAdded:Wait();
    local Humanoid: Humanoid
    local HumanoidRootPart: BasePart

    local function UpdateCharacterReferences()
        Character = Player.Character
        if Character then
            HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
        else
            HumanoidRootPart = nil
            Humanoid = nil
        end
    end

    UpdateCharacterReferences() 

    local InvisEnabled = false; 
    local Track = nil 
    local Animation = Instance.new("Animation"); 
    Animation.AnimationId = "rbxassetid://215384594"; 

    local RunService: RunService = Service.RunService;
    local Heartbeat = RunService.Heartbeat;
    local RenderStepped = RunService.RenderStepped;

    local UserInputService: UserInputService = Service.UserInputService;
    local CoreGui: CoreGui = Service.CoreGui; 
    local StarterGui: StarterGui = Service.StarterGui; 

    
    if Character and not Character:FindFirstChild("Torso") then
        pcall(function() 
            StarterGui:SetCore("SendNotification", {
                Title = "Invisibility FAILED",
                Text = "Feature requires R6 Avatar.",
                Duration = 5,
            });
        end)
        Invis_Fixed = false 
    end

    
    local GUI = Instance.new("ScreenGui");
    GUI.Name = "InvisWarningGUI";
    GUI.Parent = CoreGui; 
    GUI.ResetOnSpawn = false;
    GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;

    local WarnLabel = Instance.new("TextLabel", GUI);
    WarnLabel.Text = "⚠️You are visible⚠️";
    WarnLabel.Visible = false;
    WarnLabel.Size = UDim2.new(0, 200, 0, 30); 
    WarnLabel.Position = UDim2.new(0.5, -100, 0.85, 0); 
    WarnLabel.BackgroundTransparency = 1;
    WarnLabel.Font = Enum.Font.GothamSemibold;
    WarnLabel.TextSize = 24; 
    WarnLabel.TextColor3 = Color3.fromRGB(255, 255, 0); 
    WarnLabel.TextStrokeTransparency = 0.5;
    WarnLabel.ZIndex = 10; 


    local function Grounded()
        
        return Humanoid and Humanoid:IsDescendantOf(workspace) and Humanoid.FloorMaterial ~= Enum.Material.Air;
    end

    local function LoadAndPrepareTrack()
        if Track then 
             pcall(function() Track:Stop() end)
             Track = nil
        end
        if Humanoid then 
            local success, result = pcall(function()
                return Humanoid:LoadAnimation(Animation)
            end)
            if success then
                Track = result
                Track.Priority = Enum.AnimationPriority.Action4;
            else
                Track = nil 
            end
        else
             Track = nil
        end
    end

    local function Invis_Disable()
        if not InvisEnabled then return end 
        InvisEnabled = false;

        if Track then 
             pcall(function() Track:Stop() end)
        end

        
        if Humanoid then
            workspace.CurrentCamera.CameraSubject = Humanoid;
        end

        
        if Character then
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency == 0.5 then
                    v.Transparency = 0;
                end
            end
        end

        WarnLabel.Visible = false; 
    end

    local function Invis_Enable()
        if InvisEnabled or not Invis_Fixed then return end 

        
        UpdateCharacterReferences()
        if not Character or not Humanoid or not HumanoidRootPart then
             return
        end
        if not Character:FindFirstChild("Torso") then 
            pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility FAILED", Text = "Feature requires R6 Avatar.", Duration = 5}) end)
            return
        end


        InvisEnabled = true;
        workspace.CurrentCamera.CameraSubject = HumanoidRootPart; 

        LoadAndPrepareTrack() 

    end

    
    Hub:Connect(Player.CharacterAdded, function(NewCharacter)
        
        if Track then
            pcall(function() Track:Stop() end)
            Track = nil
        end

        task.wait() 

        UpdateCharacterReferences() 

        if not Humanoid then
             task.wait(0.5) 
             UpdateCharacterReferences() 
             if not Humanoid then
                  Invis_Fixed = false
                  if InvisEnabled then Invis_Disable() end
                  pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility Error", Text = "Could not verify character type.", Duration = 5}) end)
                  return
             end
        end

        if Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            Invis_Fixed = false
            if InvisEnabled then Invis_Disable() end 
            pcall(function() StarterGui:SetCore("SendNotification", {Title = "Invisibility Warning", Text = "Non-R6 Avatar detected (".. tostring(Humanoid.RigType) .."). Invisibility disabled.", Duration = 5}) end)
            return
        else
            Invis_Fixed = true 
        end

        if InvisEnabled then
            if HumanoidRootPart then
                 workspace.CurrentCamera.CameraSubject = HumanoidRootPart
            end
            LoadAndPrepareTrack()
        end
    end)

    Hub:Connect(Player.CharacterRemoving, function(OldCharacter)
         if Track then
             pcall(function() Track:Stop() end)
             Track = nil
         end
         WarnLabel.Visible = false
    end)


    
    Hub:Connect(Heartbeat, function(deltaTime)
        
        if not InvisEnabled or not Invis_Fixed then
            
            if not InvisEnabled and Character then
                 for _, v in pairs(Character:GetDescendants()) do
                      if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
                 end
            end
            WarnLabel.Visible = false 
            return;
        end

        
        if not Character or not Humanoid or not HumanoidRootPart or not Humanoid:IsDescendantOf(workspace) or Humanoid.Health <= 0 then
            WarnLabel.Visible = false; 
            return
        end

        
        WarnLabel.Visible = not Grounded();

        
        local speed = 12
        if Humanoid.MoveDirection.Magnitude > 0 then
             local offset = Humanoid.MoveDirection * speed * deltaTime
             HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + offset
        end

        
        local OldCFrame = HumanoidRootPart.CFrame;
        local OldCameraOffset = Humanoid.CameraOffset;

        
        local _, y = workspace.CurrentCamera.CFrame:ToOrientation();
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.CFrame.Position) * CFrame.fromOrientation(0, y, 0);
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0);
        Humanoid.CameraOffset = Vector3.new(0, 1.44, 0);

        
        if Track then
            local successPlay, errPlay = pcall(function()
                if not Track.IsPlaying then
                     Track:Play();
                end
                 Track:AdjustSpeed(0);
                 Track.TimePosition = 0.3;
            end)
             if not successPlay then
                 
                 LoadAndPrepareTrack()
             end
        elseif Humanoid and Humanoid.Health > 0 then 
             LoadAndPrepareTrack()
        end

        
        RenderStepped:Wait();

        
        if Humanoid and Humanoid:IsDescendantOf(workspace) then
             Humanoid.CameraOffset = OldCameraOffset;
        end
        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
             HumanoidRootPart.CFrame = OldCFrame;
        end

        
        if Track then
            local successStop, errStop = pcall(function() Track:Stop() end)
             if not successStop then
             end
        end

        
        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
             local LookVector = workspace.CurrentCamera.CFrame.LookVector;
             local Horizontal = Vector3.new(LookVector.X, 0, LookVector.Z).Unit;
             if Horizontal.Magnitude > 0.1 then 
                 local TargetCFrame = CFrame.new(HumanoidRootPart.Position, HumanoidRootPart.Position + Horizontal);
                 HumanoidRootPart.CFrame = TargetCFrame;
             end
        end

        
        if Character then
             for _, v in pairs(Character:GetDescendants()) do
                 if (v:IsA("BasePart") and v.Transparency ~= 1) then
                     v.Transparency = 0.5;
                 end
             end
        end
    end)

    
    _G.Invis_Enable = Invis_Enable 
    _G.Invis_Disable = Invis_Disable
    _G.IsInvisEnabled = function() return InvisEnabled end 

end 

local NoRecoil_Enabled=false
local NoRecoil_Connections={}
local GlobalOriginalValues={}
local WeaponCache={}
local Settings={GunMods={NoRecoil=true,Spread=true,SpreadAmount=0}}
local Player_nr=LocalPlayer

local function cacheWeapons()
    WeaponCache={};
    for _, v in pairs(getgc(true)) do
        if type(v)=='table' and rawget(v,'EquipTime') then
            table.insert(WeaponCache, v);
            if not GlobalOriginalValues[v] then
                GlobalOriginalValues[v]={
                    Recoil=v.Recoil,CameraRecoilingEnabled=v.CameraRecoilingEnabled,
                    AngleX_Min=v.AngleX_Min,AngleX_Max=v.AngleX_Max,
                    AngleY_Min=v.AngleY_Min,AngleY_Max=v.AngleY_Max,
                    AngleZ_Min=v.AngleZ_Min,AngleZ_Max=v.AngleZ_Max,
                    Spread=v.Spread
                }
            end
        end
    end
end

local function applyGunMods()
    for _, weapon in ipairs(WeaponCache) do
        if Settings.GunMods.NoRecoil then
            weapon.Recoil=0; weapon.CameraRecoilingEnabled=false;
            weapon.AngleX_Min=0; weapon.AngleX_Max=0;
            weapon.AngleY_Min=0; weapon.AngleY_Max=0;
            weapon.AngleZ_Min=0; weapon.AngleZ_Max=0;
        end;
        if Settings.GunMods.Spread then
            weapon.Spread=Settings.GunMods.SpreadAmount
        end
    end
end

local function resetGunMods()
    for weapon, values in pairs(GlobalOriginalValues) do
        weapon.Recoil=values.Recoil; weapon.CameraRecoilingEnabled=values.CameraRecoilingEnabled;
        weapon.AngleX_Min=values.AngleX_Min; weapon.AngleX_Max=values.AngleX_Max;
        weapon.AngleY_Min=values.AngleY_Min; weapon.AngleY_Max=values.AngleY_Max;
        weapon.AngleZ_Min=values.AngleZ_Min; weapon.AngleZ_Max=values.AngleZ_Max;
        weapon.Spread=values.Spread;
    end
end

local function handleWeapon(weapon)
    if NoRecoil_Enabled then
        task.wait(0.1);
        cacheWeapons();
        applyGunMods()
    end
end

local function onCharacterAdded_nr(character)
    for _, child in ipairs(character:GetChildren()) do if child:IsA("Tool") then handleWeapon(child) end end;
    table.insert(NoRecoil_Connections, Hub:Connect(character.ChildAdded, function(child) if child:IsA("Tool") then handleWeapon(child) end end));
    local humanoid=character:WaitForChild("Humanoid",2);
    if humanoid then
        table.insert(NoRecoil_Connections, Hub:Connect(humanoid.Died, function() if NoRecoil_Enabled then task.wait(1.5); cacheWeapons(); applyGunMods() end end))
    end
end

function NoRecoil_Enable()
    if NoRecoil_Enabled then return end;
    NoRecoil_Enabled=true;
    cacheWeapons();
    applyGunMods();
    table.insert(NoRecoil_Connections, Hub:Connect(Player_nr.CharacterAdded, onCharacterAdded_nr));
    if Player_nr.Character then onCharacterAdded_nr(Player_nr.Character) end
end

function NoRecoil_Disable()
    if not NoRecoil_Enabled then return end;
    NoRecoil_Enabled=false;
    resetGunMods();
    for _, conn in ipairs(NoRecoil_Connections) do conn:Disconnect() end;
    NoRecoil_Connections={};
end

local ESP_Enabled=false
local ESP_Loading=false
local LastToggleTime=0
local DEBOUNCE_TIME=0.5

function ESP_Enable()
    if os.clock()-LastToggleTime<DEBOUNCE_TIME then return end; LastToggleTime=os.clock();
    if ESP_Loading or ESP_Enabled then return end;
    ESP_Loading=true;
    local success, err=pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/kskdkdkdmsmdmdm0-dot/lolsjkskf/refs/heads/main/walhaczek", true))();
        ESP_Enabled=true;
        ESP_Loading=false
    end);
    if not success then
        warn("Błąd ładowania ESP: "..tostring(err));
        ESP_Loading=false;
        ESP_Enabled=false;
    end
end

function ESP_Disable()
    if os.clock()-LastToggleTime<DEBOUNCE_TIME then return end; LastToggleTime=os.clock();
    if not ESP_Enabled then return end;
    ESP_Enabled=false;
    local coreGui=game:GetService("CoreGui");
    for _, name in pairs({"Folder","ESP_Holder","ESP_Folder","ESP"}) do
        local folder=coreGui:FindFirstChild(name);
        if folder then folder:Destroy() end
    end
end

local buttonHoverColor = Color3.fromRGB(40, 40, 50)
local buttonColor = Color3.fromRGB(25, 25, 30)
local buttonStrokeColor = Color3.fromRGB(60, 60, 75)
local buttonTextColor = Color3.fromRGB(210, 210, 210)
local buttonOnColor = Color3.fromRGB(70, 180, 100)
local buttonOffColor = Color3.fromRGB(200, 80, 80)
local bindButtonColor = Color3.fromRGB(45, 45, 55)
local bindButtonHoverColor = Color3.fromRGB(60, 60, 75)


local activeBinds = {} 
local currentRowWaitingForKey = nil
local bindButtonReferences = {}
local keyBindGetters = {}
local keyBindSetters = {}
local toggleButtonTweens = {} 
local rowFunctionData = {} 


local function createToggleRowFrame(scriptName, canToggle, isEnabledFn, onEnable, onDisable, getKeyBindFn, setKeyBindFn)
    local frame = Instance.new("Frame")
    frame.Name = scriptName:gsub("%s+", "")
    local function change(value)
        local state = type(isEnabledFn) == "function" and isEnabledFn() or false
        if value ~= state then if value then onEnable() else onDisable() end end
    end
    if canToggle then
        local state = type(isEnabledFn) == "function" and isEnabledFn() or false
        local control = LelUI:Control(nil, "Toggle", scriptName, state, change)
        if getKeyBindFn and setKeyBindFn then
            local key = getKeyBindFn()
            Hub.Tabs.Game:CreateKeybind("Key_" .. frame.Name, { Title = scriptName .. " key", Default = key and key.Name or "None", Mode = "Toggle", Callback = function()
                control:SetValue(not (type(isEnabledFn) == "function" and isEnabledFn() or false))
            end, ChangedCallback = setKeyBindFn })
        end
        Hub:Add(function() if type(isEnabledFn) == "function" and isEnabledFn() and onDisable then pcall(onDisable) end end)
    else
        LelUI:Button(nil, scriptName, onEnable)
    end
    return frame
end


local function createActionButtonFrame(labelText, buttonText, actionFunction)
    local frame = Instance.new("Frame")
    LelUI:Button(nil, labelText, actionFunction)
    return frame
end

local EQR_UI = {}

EQR_UI.Categories = { "Combat", "Movement", "Visuals", "Farming", "Misc", "Rage" }
EQR_UI.CategoryButtons = {}
EQR_UI.CategoryFrames = {}
EQR_UI.ActiveCategoryButton = nil
EQR_UI.DefaultCategory = "Combat"


EQR_UI.KeyBinds = {
    fly = Fly_Bind,
    fov = fov_Bind,
    noclip = Noclip_Bind,
    FullBright = FullBright_Bind,
    autofarm = Autofarm_Bind,
    autoPickupMoney = nil,
    adminCheck = nil,
    melee = nil,
    infiniteStamina = nil,
    noRecoil = nil,
    esp = nil,
    aimbot = AimBotSettings.Keybind,
    invis = nil,
    antiAFK = nil,
    ragebot = nil,
    noFailLockpick = nil,
    safeESP = nil,
    openNearbyDoors = nil,
    unlockNearbyDoors = nil
}

function EQR_UI:SwitchCategory(categoryName)
    local categoryButton = self.CategoryButtons[categoryName]
    if not categoryButton or categoryButton == self.ActiveCategoryButton then
        return
    end

    
    if self.ActiveCategoryButton then
        TweenService:Create(self.ActiveCategoryButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) }):Play()
        self.ActiveCategoryButton.TextLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    end

    
    TweenService:Create(categoryButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(40, 40, 50) }):Play()
    categoryButton.TextLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    self.ActiveCategoryButton = categoryButton

    
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UICorner" then
            child.Parent = nil
        end
    end

    
    if self.CategoryFrames[categoryName] then
        for i, frame in ipairs(self.CategoryFrames[categoryName]) do
            frame.Parent = contentFrame
            frame.LayoutOrder = i
        end
        
        local numItems = #self.CategoryFrames[categoryName]
        local itemHeight = 35
        local padding = contentLayout.Padding.Offset
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, numItems * itemHeight + (numItems > 0 and (numItems - 1) * padding or 0) + 10)
    else
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    end
end


function EQR_UI:OnInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end

    local keyCode = input.KeyCode
    if keyCode == Enum.KeyCode.Unknown then return end

    
    if currentRowWaitingForKey then
        local frame = currentRowWaitingForKey
        local bindButton = bindButtonReferences[frame]
        local getKeyFn = keyBindGetters[frame]
        local setKeyFn = keyBindSetters[frame]
        local frameData = rowFunctionData[frame]

        if bindButton and getKeyFn and setKeyFn and frameData then
            local oldKey = nil
            local successGet, resultGet = pcall(getKeyFn)
            if successGet then oldKey = resultGet end

            if oldKey and activeBinds[oldKey] and activeBinds[oldKey].frame == frame then
                activeBinds[oldKey] = nil
            end

            if activeBinds[keyCode] and activeBinds[keyCode].frame ~= frame then
                local otherFrame = activeBinds[keyCode].frame
                local otherBindButton = bindButtonReferences[otherFrame]
                local otherSetKeyFn = keyBindSetters[otherFrame]
                if otherSetKeyFn then pcall(otherSetKeyFn, nil) end
                if otherBindButton then otherBindButton.Text = "Bind" end
                activeBinds[keyCode] = nil
            end

            pcall(setKeyFn, keyCode)

            local toggleButton
            for _, child in ipairs(frame:GetChildren()) do if child:IsA("TextButton") and child ~= bindButton then toggleButton = child; break end end

            if toggleButton then
                activeBinds[keyCode] = {
                    frame = frame,
                    toggleButton = toggleButton,
                    isEnabledFn = frameData.isEnabledFn,
                    onEnable = frameData.onEnable,
                    onDisable = frameData.onDisable,
                    canToggle = frameData.canToggle,
                    updateFn = frameData.updateFn
                }
            else
                warn("Nie można znaleźć przycisku przełącznika dla ramki:", frame.Name)
            end

            bindButton.Text = "[" .. input.KeyCode.Name .. "]"
            currentRowWaitingForKey = nil
        else
            if bindButton then bindButton.Text = "Bind" end
            currentRowWaitingForKey = nil
            warn("Błąd podczas przechwytywania klawisza - brakujące funkcje/referencje dla ramki:", frame and frame.Name or "Unknown")
        end

    
    elseif activeBinds[keyCode] then
        local bindInfo = activeBinds[keyCode]
        if bindInfo.frame and bindInfo.isEnabledFn and bindInfo.onEnable and bindInfo.onDisable and bindInfo.updateFn and bindInfo.canToggle ~= nil then
            if bindInfo.canToggle then
                local success, currentState = pcall(bindInfo.isEnabledFn)
                if success then
                    if currentState then
                        pcall(bindInfo.onDisable)
                    else
                        pcall(bindInfo.onEnable)
                    end
                    task.wait()
                    pcall(bindInfo.updateFn)
                end
            end
        end
    end
end


function EQR_UI:Initialize()
    
    for i, categoryName in ipairs(self.Categories) do
        self.CategoryFrames[categoryName] = {}

        local catButton = Instance.new("TextButton")
        catButton.Name = categoryName .. "Button"
        catButton.Size = UDim2.new(1, -10, 0, 30)
        catButton.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        catButton.BorderSizePixel = 0
        catButton.AutoButtonColor = false
        catButton.LayoutOrder = i
        catButton.Parent = sidebarFrame

        local catCorner = Instance.new("UICorner")
        catCorner.CornerRadius = UDim.new(0, 6)
        catCorner.Parent = catButton

        local catLabel = Instance.new("TextLabel")
        catLabel.Name = "TextLabel"
        catLabel.Size = UDim2.new(1, 0, 1, 0)
        catLabel.BackgroundTransparency = 1
        catLabel.Text = categoryName
        catLabel.Font = Enum.Font.GothamSemibold
        catLabel.TextSize = 14
        catLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        catLabel.Parent = catButton

        Hub:Connect(catButton.MouseEnter, function()
            if catButton ~= self.ActiveCategoryButton then
                TweenService:Create(catButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
            end
        end)
        Hub:Connect(catButton.MouseLeave, function()
            if catButton ~= self.ActiveCategoryButton then
                TweenService:Create(catButton, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 20, 25) }):Play()
            end
        end)
        LelUI:Bind(catButton, "MouseButton1Click", "catButton", function()
            self:SwitchCategory(categoryName)
        end)

        self.CategoryButtons[categoryName] = catButton
    end

    
    local k = self.KeyBinds 

    
    table.insert(self.CategoryFrames.Combat, createToggleRowFrame("Melee Aura", true, function() return MeleeAura_Enabled end, MeleeAura_Enable, MeleeAura_Disable, function() return k.melee end, function(val) k.melee=val end))
    table.insert(self.CategoryFrames.Combat, createToggleRowFrame("Aimbot", true, function() return AimBotSettings.Enabled end, Aimbot_Enable, Aimbot_Disable, function() return k.aimbot end, function(val) k.aimbot=val; AimBotSettings.Keybind=val end))
    table.insert(self.CategoryFrames.Combat, createToggleRowFrame("No Recoil", true, function() return NoRecoil_Enabled end, NoRecoil_Enable, NoRecoil_Disable, function() return k.noRecoil end, function(val) k.noRecoil=val end))

    
    table.insert(self.CategoryFrames.Movement, createToggleRowFrame("Fly", true, function() return Fly_Enabled end, Fly_Enable, Fly_Disable, function() return k.fly end, function(val) k.fly=val; Fly_Bind=val end))
    table.insert(self.CategoryFrames.Movement, createToggleRowFrame("Noclip", true, function() return Noclip_Enabled end, Noclip_Enable, Noclip_Disable, function() return k.noclip end, function(val) k.noclip=val; Noclip_Bind=val end))
    table.insert(self.CategoryFrames.Movement, createToggleRowFrame("Infinite Stamina", true, function() return isInfiniteStaminaEnabled end, InfiniteStamina_Enable, InfiniteStamina_Disable, function() return k.infiniteStamina end, function(val) k.infiniteStamina=val end))

    
    table.insert(self.CategoryFrames.Visuals, createToggleRowFrame("ESP (55 STUDS)", true, function() return ESP_Enabled end, ESP_Enable, ESP_Disable, function() return k.esp end, function(val) k.esp=val end))
    table.insert(self.CategoryFrames.Visuals, createToggleRowFrame("Invisibility", true, _G.IsInvisEnabled, _G.Invis_Enable, _G.Invis_Disable, function() return k.invis end, function(val) k.invis=val end))
    table.insert(self.CategoryFrames.Visuals, createToggleRowFrame("Safe ESP", true, function() return BredMakurz_Enabled end, BredMakurz_Enable, BredMakurz_Disable, function() return k.safeESP end, function(val) k.safeESP=val end))
    table.insert(self.CategoryFrames.Visuals, createToggleRowFrame("FullBright", true, function() return FullBright_Enabled end, FullBright_Enable, FullBright_Disable, function() return k.FullBright end, function(val) k.FullBright=val; FulLBright_Bind=val end))
    table.insert(self.CategoryFrames.Visuals, createToggleRowFrame("FOV", true, function() return Fov_Enabled end, Fov_Enable, Fov_Disable, function() return k.fov end, function(val) k.fov=val; fov=val end))

    
    table.insert(self.CategoryFrames.Farming, createToggleRowFrame("Autofarm", true, function() return autofarmEnabled end, Autofarm_Enable, Autofarm_Disable, function() return k.autofarm end, function(val) k.autofarm=val; Autofarm_Bind=val end))
    
    
    
    table.insert(self.CategoryFrames.Misc, createToggleRowFrame("Staff Detector", true, function() return AdminCheck_Enabled end, AdminCheck_Enable, AdminCheck_Disable, function() return k.adminCheck end, function(val) k.adminCheck=val end))
    table.insert(self.CategoryFrames.Misc, createToggleRowFrame("Auto Pickup Money", true, function() return AutoPickupMoney_Enabled end, AutoPickupMoney_Enable, AutoPickupMoney_Disable, function() return k.autoPickupMoney end, function(val) k.autoPickupMoney=val end))
    table.insert(self.CategoryFrames.Misc, createToggleRowFrame("No Fail Lockpick", true, function() return NoFailLockpick_Enabled end, NoFailLockpick_Enable, NoFailLockpick_Disable, function() return k.noFailLockpick end, function(val) k.noFailLockpick=val end))
    table.insert(self.CategoryFrames.Misc, createToggleRowFrame("Auto Unlock Doors", true, function() return UnlockNearbyDoors_Enabled end, UnlockNearbyDoors_Enable, UnlockNearbyDoors_Disable, function() return k.unlockNearbyDoors end, function(val) k.unlockNearbyDoors=val end))
    table.insert(self.CategoryFrames.Misc, createToggleRowFrame("Auto Open Doors", true, function() return OpenNearbyDoors_Enabled end, OpenNearbyDoors_Enable, OpenNearbyDoors_Disable, function() return k.openNearbyDoors end, function(val) k.openNearbyDoors=val end))

    
    table.insert(self.CategoryFrames.Rage, createToggleRowFrame("Ragebot", true, function() return Ragebot_Enabled end, Ragebot_Enable, Ragebot_Disable, function() return k.ragebot end, function(val) k.ragebot=val end))
    
    
    Hub:Connect(UserInputService.InputBegan, function(...) self:OnInputBegan(...) end)
    Hub:Connect(PlayerGui.ChildAdded, function(Item)
        if Item.Name == "LockpickGUI" then
            ApplyLockpickModification()
        end
    end)
    
    
    self:SwitchCategory(self.DefaultCategory)
    
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    local openTween = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 450, 0, 350) })
    task.wait(0.1)
    openTween:Play()
    
    print("EQR Hub (Refactored UI - Final) Loaded.")
end

EQR_UI:Initialize()

end)
