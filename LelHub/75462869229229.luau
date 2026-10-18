local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Soccer Zero")
local LelUI = Hub.Native
local LelAPI = Hub:Interface("Rayfield")
task.spawn(function()
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local VirtualWorkspace = Workspace:WaitForChild("VirtualWorkspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Rayfield = LelAPI

local Window = Rayfield:CreateWindow({
   Name = "SkidZero Script",
   LoadingTitle = "Loading Script",
   LoadingSubtitle = "by PotatoIsCool",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "PotatoScripts", 
      FileName = "PotatosSoccerZeroScript"
   },
   KeySystem = false,
})

local CFrameJumpEnabled = false
local CFrameJumpHeight = 2 

local BallESPEnabled = false
local GoalAssistEnabled = false

local SpeedEnabled = false
local SpeedValue = 1
local HoldingBall = false
local AutoDribbleEnabled = false

local FlyEnabled = false
local FlySpeed = 1
local Camera = workspace.CurrentCamera
local RingESPEnabled = false

local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Main")

MainTab:CreateToggle({
   Name = "Auto Dribble",
   CurrentValue = false,
   Flag = "AutoDribble",
   Callback = function(Value)
      AutoDribbleEnabled = Value
   end,
})

MainTab:CreateSection("Visuals")

MainTab:CreateToggle({
   Name = "Ball ESP (Highlight)",
   CurrentValue = false,
   Flag = "BallESP",
   Callback = function(Value)
      BallESPEnabled = Value
   end,
})

MainTab:CreateToggle({
   Name = "Ring ESP",
   CurrentValue = false,
   Flag = "RingESP",
   Callback = function(Value)
      RingESPEnabled = Value
   end,
})

local Paragraph = MainTab:CreateParagraph({Title = "Note From Developer:", Content = "Auto Dribble is still in Beta. I am new to Roblox Exploiting so sorry if it is not the best. Also setting your speed to high will set off Anti Cheat. Please keep it below 2.5 to not get detected."})

MainTab:CreateSection("RPCs Detections")
local BallStatusLabel = MainTab:CreateLabel("Holding Ball: No")
local StealStatusLabel = MainTab:CreateLabel("Steal Alert: Safe")


local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateSection("Movement")

MovementTab:CreateToggle({
   Name = "CFrame Speed Boost",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(Value)
      SpeedEnabled = Value
   end,
})

MovementTab:CreateToggle({
   Name = "Fly Mode",
   CurrentValue = false,
   Flag = "FlyToggle",
   Callback = function(Value)
      FlyEnabled = Value
      if Player.Character and Player.Character:FindFirstChild("Humanoid") then
          Player.Character.Humanoid.PlatformStand = Value 
      end
   end,
})

MovementTab:CreateToggle({
   Name = "CFrame Jump Boost",
   CurrentValue = false,
   Flag = "CFrameJumpToggle",
   Callback = function(Value)
      CFrameJumpEnabled = Value
   end,
})

MovementTab:CreateSlider({
   Name = "Speed Multiplier",
   Range = {0, 3},
   Increment = 0.1,
   Suffix = "Power",
   CurrentValue = 1,
   Flag = "SpeedSlider",
   Callback = function(Value)
      SpeedValue = Value
   end,
})

MovementTab:CreateSlider({
   Name = "Fly Speed",
   Range = {0.1, 5},
   Increment = 0.1,
   Suffix = "Mult",
   CurrentValue = 1,
   Flag = "FlySlider",
   Callback = function(Value)
      FlySpeed = Value
   end,
})

MovementTab:CreateSlider({
   Name = "Jump Boost Height",
   Range = {1, 10},
   Increment = 0.5,
   Suffix = "Studs",
   CurrentValue = 2,
   Flag = "CFrameJumpSlider",
   Callback = function(Value)
      CFrameJumpHeight = Value
   end,
})


local function PerformDribble()
    local DribbleKey = Enum.KeyCode.Q
    VirtualInputManager:SendKeyEvent(true, DribbleKey, false, game)
    VirtualInputManager:SendKeyEvent(false, DribbleKey, false, game)
    print("Pressing Q to dribble!!")
    
end

local function CheckForStealers()
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return false end
    
    local VFXFolder = Workspace:FindFirstChild("VFX")
    if not VFXFolder then return false end

    for _, effect in pairs(VFXFolder:GetChildren()) do
        if effect.Name == "Dirt" and effect:IsA("BasePart") then
            local weld = effect:FindFirstChildWhichIsA("WeldConstraint")
            
            if weld and weld.Part1 ~= Character.HumanoidRootPart then
                local distance = (effect.Position - Character.HumanoidRootPart.Position).Magnitude
                
                if distance < 15 then
                    return true
                end
            end
        end
    end
    return false
end

local function getBall()
    local myBallName = Player.Name .. "'s SoccerBall"
    local myBall = workspace:FindFirstChild(myBallName)
    if myBall then return myBall end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:find("SoccerBall") then
            return obj
        end
    end
    return nil
end

local function UpdateBallESP()
    local targetBall = getBall()
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")

    if not targetBall or not RootPart or HoldingBall or not BallESPEnabled then
        if targetBall then
            if targetBall:FindFirstChild("ESPHighlight") then targetBall.ESPHighlight.Enabled = false end
            if targetBall:FindFirstChild("BallTracer") then targetBall.BallTracer.Enabled = false end
            if targetBall:FindFirstChild("BallDistance") then targetBall.BallDistance.Enabled = false end
        end
        return 
    end

    local Highlight = targetBall:FindFirstChild("ESPHighlight")
    if not Highlight then
        Highlight = Instance.new("Highlight")
        Highlight.Name = "ESPHighlight"
        Highlight.Parent = targetBall
        Highlight.FillColor = Color3.fromRGB(0, 255, 127)
        Highlight.FillTransparency = 0.4
    end
    Highlight.Enabled = true

    local Beam = targetBall:FindFirstChild("BallTracer")
    local Attachment0 = RootPart:FindFirstChild("TracerAttachment")
    local Attachment1 = targetBall:FindFirstChild("BallAttachment")

    if not Attachment0 then
        Attachment0 = Instance.new("Attachment", RootPart)
        Attachment0.Name = "TracerAttachment"
    end
    if not Attachment1 then
        Attachment1 = Instance.new("Attachment", targetBall)
        Attachment1.Name = "BallAttachment"
    end
    if not Beam then
        Beam = Instance.new("Beam")
        Beam.Name = "BallTracer"
        Beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 127))
        Beam.Width0 = 0.1
        Beam.Width1 = 0.1
        Beam.FaceCamera = true
        Beam.Attachment0 = Attachment0
        Beam.Attachment1 = Attachment1
        Beam.Parent = targetBall
    end
    Beam.Enabled = true

    local Billboard = targetBall:FindFirstChild("BallDistance")
    if not Billboard then
        Billboard = Instance.new("BillboardGui")
        Billboard.Name = "BallDistance"
        Billboard.Size = UDim2.new(0, 100, 0, 50)
        Billboard.StudsOffset = Vector3.new(0, 2, 0)
        Billboard.AlwaysOnTop = true
        
        local TextLabel = Instance.new("TextLabel")
        TextLabel.Parent = Billboard
        TextLabel.BackgroundTransparency = 1
        TextLabel.Size = UDim2.new(1, 0, 1, 0)
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextStrokeTransparency = 0
        TextLabel.Font = Enum.Font.GothamBold
        TextLabel.TextSize = 14
        Billboard.Parent = targetBall
    end
    
    local dist = math.floor((RootPart.Position - targetBall.Position).Magnitude)
    Billboard.TextLabel.Text = dist .. " studs"
    Billboard.Enabled = true
end


local function ApplyGoalAssist()
    if not GoalAssistEnabled then return end
    
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Ball = getBall()
    
    local Goal = workspace:FindFirstChild("Goal") 

    if RootPart and Ball and Goal then
        local distanceToBall = (RootPart.Position - Ball.Position).Magnitude
        
        if distanceToBall < 5 then
            local targetPos = Vector3.new(Goal.Position.X, RootPart.Position.Y, Goal.Position.Z)
            RootPart.CFrame = RootPart.CFrame:Lerp(CFrame.lookAt(RootPart.Position, targetPos), 0.2)
        end
    end
end

RunService.RenderStepped:Connect(function()
    local Character = Player.Character
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    local Humanoid = Character and Character:FindFirstChild("Humanoid")

    if SpeedEnabled and RootPart and Humanoid then
        if Humanoid.MoveDirection.Magnitude > 0 then
            RootPart.CFrame = RootPart.CFrame + (Humanoid.MoveDirection * (SpeedValue / 5))
        end
    end

    local VirtualWorkspace = Workspace:FindFirstChild("VirtualWorkspace")
    local Server1 = VirtualWorkspace and VirtualWorkspace:FindFirstChild("Server1")
    local Ring = Server1 and Server1:FindFirstChild("Ring")
    
    if FlyEnabled and RootPart then
        local FlyDirection = Vector3.new(0, 0, 0)
        
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
            FlyDirection = FlyDirection + Camera.CFrame.LookVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
            FlyDirection = FlyDirection - Camera.CFrame.LookVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
            FlyDirection = FlyDirection - Camera.CFrame.RightVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
            FlyDirection = FlyDirection + Camera.CFrame.RightVector
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
            FlyDirection = FlyDirection + Vector3.new(0, 1, 0)
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftControl) then
            FlyDirection = FlyDirection - Vector3.new(0, 1, 0)
        end

        if FlyDirection.Magnitude > 0 then
            RootPart.Velocity = Vector3.new(0, 0, 0) 
            RootPart.CFrame = RootPart.CFrame + (FlyDirection * FlySpeed)
        else
            RootPart.Velocity = Vector3.new(0, 0, 0)
        end
    end

    if Ring and RingESPEnabled then
        local RingHighlight = Ring:FindFirstChild("RingHighlight")
        if not RingHighlight then
            RingHighlight = Instance.new("Highlight")
            RingHighlight.Name = "RingHighlight"
            RingHighlight.Parent = Ring
            RingHighlight.FillColor = Color3.fromRGB(255, 0, 0)
            RingHighlight.FillTransparency = 0.5
            RingHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        end
        RingHighlight.Enabled = true
    elseif Ring and Ring:FindFirstChild("RingHighlight") then
        Ring.RingHighlight.Enabled = false
    end

    if Ring and RootPart then
        local ringPos = Vector3.new(Ring.CFrame.Position.X, 0, Ring.CFrame.Position.Z)
        local playerPos = Vector3.new(RootPart.Position.X, 0, RootPart.Position.Z)
        local distance = (ringPos - playerPos).Magnitude
        
        if distance < 3 and Ring.Transparency < 1 then
            if not HoldingBall then
                HoldingBall = true
                BallStatusLabel:Set("Holding Ball: YES")
            end
            
            if CheckForStealers() then
                StealStatusLabel:Set("Someone trying to steal!")
                print("Someone tried to steal the ball!!")

                if AutoDribbleEnabled then
                    PerformDribble()
                end
            else
                StealStatusLabel:Set("Steal Alert: Safe")
            end
        else
            if HoldingBall then
                HoldingBall = false
                BallStatusLabel:Set("Holding Ball: No")
                StealStatusLabel:Set("Steal Alert: Safe")
            end
        end
    else
        if HoldingBall then
            HoldingBall = false
            BallStatusLabel:Set("Holding Ball: No")
            StealStatusLabel:Set("Steal Alert: Safe")
        end
    end
    UpdateBallESP()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end 
    
    if input.KeyCode == Enum.KeyCode.Space and CFrameJumpEnabled then
        local Character = Player.Character
        local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChild("Humanoid")
        
        if RootPart and Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait() 
            RootPart.CFrame = RootPart.CFrame * CFrame.new(0, CFrameJumpHeight, 0)
            RootPart.AssemblyLinearVelocity = Vector3.new(RootPart.AssemblyLinearVelocity.X, 30, RootPart.AssemblyLinearVelocity.Z)
        end
    end
end)

Rayfield:LoadConfiguration()

end)
