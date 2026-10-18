local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Build A Boat For Treasure")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local player = game:GetService("Players").LocalPlayer
local section = Hub.Tabs.Game:CreateSection("Treasure Farm")
local stageDelay, finishing, characterBefore, stage = 2, false, nil, 1
local function stages()
    local folder = workspace:FindFirstChild("BoatStages")
    return folder and folder:FindFirstChild("NormalStages")
end
local function move(part, offset)
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not human or human.Health <= 0 then return false end
    if human.SeatPart then human.Sit = false task.wait() end
    character:PivotTo(part.CFrame * CFrame.new(0, offset or 3, 0))
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    return true
end
local farm
farm = Hub:Loop(section, "Auto Treasure", function() return stageDelay end, function()
    local folder = stages()
    if not folder then error("Stages not loaded") end
    if finishing then
        if player.Character == characterBefore then return end
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 then return end
        finishing, stage = false, 1
    end
    local cave = folder:FindFirstChild("CaveStage" .. stage)
    local part = cave and cave:FindFirstChild("DarknessPart")
    if stage <= 10 then
        if not part then error("Stage unavailable") end
        if move(part, 3) then stage = stage + 1 end
    else
        local ending = folder:FindFirstChild("TheEnd")
        local chest = ending and ending:FindFirstChild("GoldenChest")
        local trigger = chest and chest:FindFirstChild("Trigger")
        if not trigger then error("Chest unavailable") end
        if move(trigger, 0) then characterBefore, finishing = player.Character, true end
    end
end)
Hub:Slider(section, "TreasureDelay", "Stage Interval", 2, 1, 6, function(value) stageDelay = value end, 1)
Hub:Button(section, "Restart Route", function() stage, finishing = 1, false end)
local destination = 1
local choices = {}
for index = 1, 10 do table.insert(choices, tostring(index)) end
Hub:Dropdown(section, "TreasureStage", "Stage", choices, "1", function(value) destination = tonumber(value) end)
Hub:Button(section, "Teleport to Stage", function()
    local folder = stages()
    local cave = folder and folder:FindFirstChild("CaveStage" .. destination)
    local part = cave and cave:FindFirstChild("DarknessPart")
    if part then move(part) else Hub:Notify("That stage is not loaded.") end
end)
Hub:Button(section, "Return to Team Spawn", function()
    farm:SetValue(false)
    local team = player.TeamColor and workspace:FindFirstChild(player.TeamColor.Name .. "Team")
    local spawns = team and team:FindFirstChild("Spawns")
    local spawn = spawns and (spawns:IsA("BasePart") and spawns or spawns:FindFirstChildWhichIsA("BasePart", true))
    if spawn then move(spawn) else Hub:Notify("Your team spawn is not loaded.") end
end)

local platform
Hub:Connect(game:GetService("RunService").Heartbeat, function()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if farm.Value and not finishing and stage <= 10 and root then
        if not platform then
            platform = Instance.new("Part")
            platform.Name, platform.Anchored, platform.CanCollide, platform.CanTouch = "LelHubBoatPlatform", true, true, false
            platform.Size, platform.Transparency, platform.Parent = Vector3.new(8, 1, 8), 1, workspace
        end
        platform.CFrame = CFrame.new(root.Position - Vector3.new(0, 3.5, 0))
    elseif platform then platform:Destroy() platform = nil end
end)
Hub:Add(function() if platform then platform:Destroy() platform = nil end end)

