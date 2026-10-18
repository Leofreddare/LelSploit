local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Anime Arise Evolution")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local player = game:GetService("Players").LocalPlayer
local interval, meta = 0.3, nil
local function service()
    if meta then return meta end
    local scripts = player:FindFirstChild("PlayerScripts")
    local module = scripts and scripts:FindFirstChild("MetaService")
    if not module then error("MetaService not loaded") end
    meta = require(module)
    return meta
end
local function bridge(...)
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Bridge")
    if not remote then error("Bridge not loaded") end
    remote:FireServer(...)
end
Hub:Loop(section, "Auto Attack", function() return interval end, function()
    local data = service()
    if data.Cache and data.Cache.ProximityEnemy then bridge("Attack", "Click", data.Cache.ProximityEnemy) end
end)
Hub:Loop(section, "Auto Rank", function() return 1 end, function()
    local data = service()
    local rank = data.SharedModules.Ranks[data.Data.Rank + 1]
    if rank and data.Data.Energy >= data.Utils.Number:Unformat(rank.Price) then bridge("RankUp", "Evolve") end
end)
Hub:Loop(section, "Auto Buy Zone", function() return 1 end, function()
    local data, current = service(), -1
    for name in pairs(data.Data.Inventory.Maps) do local map = data.SharedModules.Maps[name] if map and map.Index > current then current = map.Index end end
    for _, map in pairs(data.SharedModules.Maps) do
        if map.Index == current + 1 and data.Data.Gems >= data.Utils.Number:Unformat(map.Price) then bridge("Teleport", "Buy", map.Name) task.wait(0.5) if not Hub.Stopped then bridge("Teleport", "Spawn", map.Name) end return end
    end
end)
Hub:Loop(section, "Auto Achievements", function() return 2 end, function()
    local data = service()
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local ui = gui and gui:FindFirstChild("UI")
    local frames = ui and ui:FindFirstChild("Frames")
    local achievements = frames and frames:FindFirstChild("Achievements")
    local main = achievements and achievements:FindFirstChild("NewMain")
    local body = main and main:FindFirstChild("body")
    local items = body and body:FindFirstChild("items")
    if not items then return end
    for _, item in ipairs(items:GetChildren()) do
        local claimed = item:FindFirstChild("claimed")
        local fill = item:FindFirstChild("backFill")
        local progress = fill and fill:FindFirstChild("progress")
        if item:IsA("ImageLabel") and claimed and not claimed.Visible and progress then
            local left, right = progress.Text:match("([^/]+)/([^/]+)")
            if left and right then
                local value = tonumber(left:gsub(",", "")) or data.Utils.Number:Unformat(left)
                local goal = tonumber(right:gsub(",", "")) or data.Utils.Number:Unformat(right)
                if value and goal and value >= goal then bridge("Achievements", "Claim", item.Name) end
            end
        end
    end
end)
local drops = false
Hub:Toggle(section, "AutoDrops", "Auto Drops", function(value) drops = value end, false)
Hub:Slider(section, "AttackInterval", "Attack Interval", 0.3, 0.1, 2, function(value) interval = value end, 1)
Hub:Connect(workspace.DescendantAdded, function(part)
    if drops and part:IsA("Part") and part.Parent and part.Parent.Name == "Debris" and part:FindFirstChild("UID") then pcall(function() bridge("Drops", "Collect", part.Name) end) end
end)

