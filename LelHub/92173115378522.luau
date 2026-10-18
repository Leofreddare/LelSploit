local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Split The Sea")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")


local CURRENT_PLOT = "Plot1"
local CURRENT_ISLAND = "Basic"
local TELEPORT_DELAY = 0.08

local ISLANDS = {"Basic", "VoidReef", "CyberTech", "RainbowReef", "RadioactiveReef"}
local PLOTS = {"Plot1", "Plot2", "Plot3", "Plot4", "Plot5"}

local lootFolder = workspace:WaitForChild("ActiveLoot")
local busy = false

LelUI:Control(nil, "Dropdown", "Island", CURRENT_ISLAND, function(value) CURRENT_ISLAND = value end, ISLANDS)
LelUI:Control(nil, "Dropdown", "Plot", CURRENT_PLOT, function(value) CURRENT_PLOT = value end, PLOTS)
Hub:Input("Teleport delay (seconds)", tostring(TELEPORT_DELAY), function(value) local number = tonumber(value) if number then TELEPORT_DELAY = number end end)


local function getSafeZone()
    local island = workspace:WaitForChild("Islands"):FindFirstChild(CURRENT_ISLAND)
    if not island then return nil end

    local plot = island:WaitForChild("Plots"):FindFirstChild(CURRENT_PLOT)
    if not plot then return nil end

    return plot:WaitForChild("Important"):FindFirstChild("SafeZone")
end

local function getMatchingLoot()
    local matches = {}

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    for _, model in ipairs(lootFolder:GetChildren()) do
        if model:IsA("Model") and model:GetAttribute("PlotName") == CURRENT_PLOT then
            local pivot = model:GetPivot()
            local distance = (pivot.Position - hrp.Position).Magnitude

            if distance <= 800 then
                table.insert(matches, model)
            end
        end
    end

    return matches
end

local function teleportOnce()
    if busy then return end
    busy = true

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    for _, model in ipairs(getMatchingLoot()) do
        if model and model.Parent then
            hrp.CFrame = model:GetPivot() + Vector3.new(0,2,0)
        end
        task.wait(TELEPORT_DELAY)
    end

    busy = false
end

local function teleportHome()
    local safeZone = getSafeZone()
    if not safeZone then return end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    hrp.CFrame = safeZone.CFrame + Vector3.new(0,3,0)
end


Hub:Button(Hub.Tabs.Game, "Collect from selected island", teleportOnce)
Hub:Button(Hub.Tabs.Game, "Return to your plot", teleportHome)


UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.G then
        teleportOnce()
    elseif input.KeyCode == Enum.KeyCode.F then
        teleportHome()
    end
end)

end)
