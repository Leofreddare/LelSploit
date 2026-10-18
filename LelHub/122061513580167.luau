local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Schedule")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
preferences.Amount = 1
Hub:Slider(section, "SeedAmount", "Seed Quantity", 1, 1, 100, function(value) preferences.Amount = math.floor(value) end)
Hub:SourceController(section, "Order Seeds", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local args = {
	"DeadDrop/Order",
	{
		{
			["OG Seed"] = preferences.Amount
		}
	}
}
game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/UICommunication"):FireServer(unpack(args))

end, true)
