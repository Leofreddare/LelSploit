local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Death Ball")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StatsService = game:GetService("Stats")

local ui = require(ReplicatedFirst.ui)
if ui and ui.Inventory and ui.Inventory.Settings then
    ui.Inventory.Settings["Deflect Keybind"] = "F1"
    keypress(70)
    keyrelease(70)
end

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.FilterDescendantsInstances = {Player.Character, workspace:FindFirstChild("FX")}

local BallShadow, BallObject = nil, nil
local PreviousPosition = nil
local LastParry = 0

local SPEED_THRESHOLD = 85 
local PARRY_KEY = 112

local function GetBallColor(target)
    if not target then return Color3.new(1, 1, 1) end
    local highlight = target:FindFirstChildOfClass("Highlight")
    if highlight then return highlight.FillColor end
    return (target:IsA("BasePart") and target.Color) or Color3.new(1, 1, 1)
end

local function GetVisualHeight(shadow)
    if not shadow then return 0 end
    return math.min(((math.max(0, shadow.Size.X - 5)) * 20) + 3, 100)
end

local function TriggerParry()
    keypress(PARRY_KEY)
    keyrelease(PARRY_KEY)
end

local function IsPathBlocked(ballPos, playerPos)
    local direction = playerPos - ballPos
    local result = workspace:Raycast(ballPos, direction, RayParams)
    
    if result and result.Instance then
        if result.Instance.CanCollide and result.Instance.Transparency < 0.8 then
            return true
        end
    end
    return false
end

RunService.RenderStepped:Connect(function(dt)
    BallShadow = (BallShadow and BallShadow.Parent) and BallShadow or workspace.FX:FindFirstChild("BallShadow")
    BallObject = (BallObject and BallObject.Parent) and BallObject or (workspace:FindFirstChild("Ball") or workspace:FindFirstChild("Part"))

    if not BallShadow or not BallObject or not Player.Character or not Player.Character.PrimaryPart then  
        PreviousPosition = nil  
        return  
    end  

    local rootPart = Player.Character.PrimaryPart  
    local charPos = rootPart.Position
    local height = GetVisualHeight(BallShadow)  
    local currentPos = Vector3.new(BallShadow.Position.X, BallShadow.Position.Y + height, BallShadow.Position.Z)  

    if PreviousPosition then  
        local velocityVector = (currentPos - PreviousPosition) / dt  
        local velocityMagnitude = velocityVector.Magnitude  
        local ping = Player:GetNetworkPing()
        local ballColor = GetBallColor(BallObject)  
        
        if ballColor ~= Color3.new(1, 1, 1) then
            if IsPathBlocked(currentPos, charPos) then
                PreviousPosition = currentPos
                return
            end

            local shouldParry = false
            local distance = (charPos - currentPos).Magnitude
            
            local dirToPlayer = (charPos - currentPos).Unit
            local velDir = velocityVector.Unit
            local accuracy = velDir:Dot(dirToPlayer)

            local curveDelay = math.clamp((1 - accuracy) * 0.1, 0, 0.15)

            if velocityMagnitude < SPEED_THRESHOLD then
                local leadTime = math.clamp(0.05 + (velocityMagnitude / 600), 0.05, 0.2)  
                local predictedPos = currentPos + velocityVector * leadTime  
                local flatDistance = (Vector3.new(charPos.X, 0, charPos.Z) - Vector3.new(predictedPos.X, 0, predictedPos.Z)).Magnitude  
                local dynamicDistance = math.clamp(12 + velocityMagnitude * ping * 0.4, 8, 55)

                if flatDistance <= (dynamicDistance - (curveDelay * 10)) then
                    shouldParry = true
                end
            else
                if accuracy > 0.15 then
                    local timeToImpact = distance / velocityMagnitude
                    local reactionWindow = 0.1 + (ping * 1.2) + (dt * 1.5) - curveDelay

                    if timeToImpact <= reactionWindow then
                        shouldParry = true
                    end
                end
            end

            if shouldParry then
                local jitter = math.random() * 0.02
                local safeDelay = math.clamp(0.02 + (velocityMagnitude / 250), 0.01, 0.1)
                
                if (tick() - LastParry) > (safeDelay + jitter) then
                    TriggerParry()
                    LastParry = tick()
                end
            end
        end  
    end  

    PreviousPosition = currentPos
end)

local active = false
LelUI:Control(nil, "Toggle", "Fast parry", false, function(value)
    active = value
    if active then
        task.spawn(function()
            while active do
                TriggerParry()
                task.wait(0.01)
            end
        end)
    end
end)
Hub:Add(function() active = false end)

end)
