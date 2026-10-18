local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Forsaken")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Generators")
local player = game:GetService("Players").LocalPlayer
local interval, autoSprint, lastGenerator = 2.5, false, nil
local function character()
    local folder = workspace:FindFirstChild("Players")
    local survivors = folder and folder:FindFirstChild("Survivors")
    if survivors then for _, model in ipairs(survivors:GetChildren()) do if model:GetAttribute("Username") == player.Name then return model end end end
    return player.Character
end
local function nearest()
    local model = character()
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local mapFolder = workspace:FindFirstChild("Map")
    local ingame = mapFolder and mapFolder:FindFirstChild("Ingame")
    local map = ingame and ingame:FindFirstChild("Map")
    if not root or not map then return end
    local best, distance
    for _, generator in ipairs(map:GetChildren()) do
        local progress = generator:FindFirstChild("Progress")
        local positions = generator:FindFirstChild("Positions")
        local position = positions and positions:FindFirstChild("Right")
        if generator.Name == "Generator" and progress and progress.Value < 100 and position then
            local gap = (root.Position - position.Position).Magnitude
            if not distance or gap < distance then best, distance = generator, gap end
        end
    end
    return best, root
end
local function approach()
    local generator, root = nearest()
    if not generator then return end
    local human = root.Parent:FindFirstChildOfClass("Humanoid")
    if not human or human.Health <= 0 then return end
    human:MoveTo(generator.Positions.Right.Position)
    return generator, root
end
Hub:Button(section, "Move to Nearest Generator", approach)
Hub:Loop(section, "Auto Generators", function() return interval end, function()
    local generator, root = approach()
    if not generator then return end
    local main, remotes = generator:FindFirstChild("Main"), generator:FindFirstChild("Remotes")
    local prompt = main and main:FindFirstChild("Prompt")
    local remote = remotes and remotes:FindFirstChild("RE")
    if not prompt or not prompt.Enabled or not remote then return end
    local part = prompt.Parent
    if not part:IsA("BasePart") then return end
    if (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance then return end
    if type(fireproximityprompt) == "function" then fireproximityprompt(prompt, prompt.HoldDuration)
    else prompt:InputHoldBegin() task.wait(prompt.HoldDuration + 0.05) prompt:InputHoldEnd() end
    if root.Parent and generator.Progress.Value < 100 then remote:FireServer() end
    lastGenerator = generator
end)
Hub:Slider(section, "GeneratorInterval", "Repair Interval", 2.5, 1, 6, function(value) interval = value end, 1)
Hub:Toggle(section, "AutoSprint", "Auto Sprint", function(value) autoSprint = value end, false)
local sprinting = false
local function release()
    if sprinting then game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) sprinting = false end
end
local elapsed = 0
Hub:Connect(game:GetService("RunService").Heartbeat, function(delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    local model = character()
    local human = model and model:FindFirstChildOfClass("Humanoid")
    local shouldSprint = autoSprint and human and human.Health > 0 and human.MoveDirection.Magnitude > 0
    if shouldSprint and not sprinting then game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) sprinting = true
    elseif not shouldSprint then release() end
end)
Hub:Add(function()
    release()
    local model = character()
    local human = model and model:FindFirstChildOfClass("Humanoid")
    if human then human:Move(Vector3.zero) end
end)

