local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Build and Crash")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Rewards")
local amount = 1000000
Hub:Input("Amount", "1000000", function(value) local number = tonumber(value) if number and number == number and number > 0 and number <= 1e18 then amount = number end end)
Hub:Button(section, "Request Cash", function()
    local remote = game:GetService("ReplicatedStorage")
    for _, name in ipairs({"Events", "GiveMoney"}) do remote = remote:FindFirstChild(name) if not remote then Hub:Notify("The reward remote is not loaded.") return end end
    remote:FireServer(amount)
end)

