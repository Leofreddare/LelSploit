local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Build A Boat For Treasure")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local player = game:GetService("Players").LocalPlayer
local section = Hub.Tabs.Game:CreateSection("Treasure Farm")
local stageDelay, runDelay, stage, nextStep = 2, 5, 1, 0
local runCharacter, chestStarted, platform
local function stages()
    local folder = workspace:FindFirstChild("BoatStages")
    return folder and folder:FindFirstChild("NormalStages")
end
local function clearPlatform()
    if platform then platform:Destroy() platform = nil end
end
local function reset()
    clearPlatform()
    stage, nextStep, runCharacter, chestStarted = 1, 0, nil, nil
end
local farm
farm = Hub:Loop(section, "Auto Treasure", function() return 0.1 end, function()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not human or human.Health <= 0 then clearPlatform() return end
    if runCharacter and character ~= runCharacter then
        reset()
        nextStep = os.clock() + runDelay
    end
    if os.clock() < nextStep then return end
    runCharacter = character
    local folder = stages()
    if not folder then error("Stages not loaded") end
    if human.SeatPart then human.Sit = false return end
    if stage <= 10 then
        local cave = folder:FindFirstChild("CaveStage" .. stage)
        local part = cave and cave:FindFirstChild("DarknessPart")
        if not part then error("Stage unavailable") end
        clearPlatform()
        root.CFrame = part.CFrame
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        platform = Instance.new("Part")
        platform.Name, platform.Anchored, platform.CanCollide, platform.CanTouch = "LelHubBoatPlatform", true, true, false
        platform.Size, platform.Transparency = Vector3.new(8, 1, 8), 1
        platform.CFrame, platform.Parent = root.CFrame * CFrame.new(0, -6, 0), character
        stage, nextStep = stage + 1, os.clock() + stageDelay
    else
        clearPlatform()
        local ending = folder:FindFirstChild("TheEnd")
        local chest = ending and ending:FindFirstChild("GoldenChest")
        local trigger = chest and chest:FindFirstChild("Trigger")
        if not trigger then error("Chest unavailable") end
        chestStarted = chestStarted or os.clock()
        if os.clock() - chestStarted > 30 then farm:SetValue(false) Hub:Notify("The chest did not respond. Restart the route to try again.") return end
        root.CFrame = trigger.CFrame
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
end)
Hub:Slider(section, "TreasureDelay", "Stage Interval", 2, 1, 6, function(value) stageDelay = value end, 1)
Hub:Slider(section, "TreasureRunDelay", "Respawn Delay", 5, 1, 10, function(value) runDelay = value end, 1)
Hub:Button(section, "Restart Route", reset)
Hub:Connect(game:GetService("RunService").Heartbeat, function() if not farm.Value then clearPlatform() end end)
Hub:Connect(player.CharacterRemoving, clearPlatform)
Hub:Add(reset)

