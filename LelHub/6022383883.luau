local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("BORDER Military Roleplay")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Currency")
local amount = 1000000
Hub:Input("Amount", "1000000", function(value) local number = tonumber(value) if number and number > 0 and number <= 1e18 then amount = number end end)
local function request(kind)
    local storage = game:GetService("ReplicatedStorage")
    local configuration = storage:FindFirstChild("Configuration")
    local core = configuration and configuration:FindFirstChild("Core Systems")
    local data = core and core:FindFirstChild("Datastore")
    local remote = data and data:FindFirstChild("GiveCurrency")
    if remote then remote:FireServer({ Type = kind, Amount = amount }) else Hub:Notify("The currency remote is unavailable.") end
end
Hub:Button(section, "Request Money", function() request("Money") end)
Hub:Button(section, "Request Diamonds", function() request("Diamond") end)

