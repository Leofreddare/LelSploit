local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Build a Brainrot")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local storage = game:GetService("ReplicatedStorage")
local section = Hub.Tabs.Game:CreateSection("Shop")
local toolName, buildName, cash = "", "", 1000000
local function names(folder)
    local values = {}
    if folder then for _, item in ipairs(folder:GetChildren()) do table.insert(values, item.Name) end end
    table.sort(values)
    return values
end
local tools = Hub:Dropdown(section, "ShopTool", "Tool", names(storage:FindFirstChild("Tools")), nil, function(value) toolName = value end)
local builds = Hub:Dropdown(section, "ShopBuild", "Build", names(storage:FindFirstChild("Builds")), nil, function(value) buildName = value end)
local function remote(name, ...)
    local folder = storage:FindFirstChild("Remotes")
    local event = folder and folder:FindFirstChild(name)
    if event then event:FireServer(...) else Hub:Notify("The shop is not loaded.") end
end
Hub:Button(section, "Buy Selected Tool", function() if toolName ~= "" then remote("buyTool", toolName) end end)
Hub:Button(section, "Buy All Tools", function() for _, name in ipairs(names(storage:FindFirstChild("Tools"))) do remote("buyTool", name) task.wait(0.1) end end)
Hub:Button(section, "Buy Selected Build", function() if buildName ~= "" then remote("buyPlaceable", buildName) end end)
Hub:Button(section, "Refresh Shop", function() tools:SetValues(names(storage:FindFirstChild("Tools"))) builds:SetValues(names(storage:FindFirstChild("Builds"))) end)
Hub:Input("Cash Amount", "1000000", function(value) local number = tonumber(value) if number and number > 0 and number < math.huge then cash = number end end)
Hub:Button(section, "Request Cash", function() remote("giveRewards", "Cash", cash) end)

