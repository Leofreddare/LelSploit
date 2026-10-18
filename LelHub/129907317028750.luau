local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Be Dino - Jurassic Dinosaur Simulation")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
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

    moverConn = Hub:Connect(RunService.Heartbeat, function(dt)
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

LelUI:Control(nil, "Slider", "Collect speed", tweenSpeed, function(value) tweenSpeed = value end, 1, MAX_SPEED)
local function setStatus() end

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

Hub:Button(Hub.Tabs.Game, "Start collecting", function()
    if running then return end
    running = true
    task.spawn(collectLoop)
end)
Hub:Button(Hub.Tabs.Game, "Stop collecting", function() running = false stopMover() end)
Hub:Add(function() running = false stopMover() end)

end)
