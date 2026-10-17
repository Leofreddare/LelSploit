local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Infinite Pizza Clicker")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
while true do game:GetService("ReplicatedStorage").Remotes.Click:FireServer()task.wait()end

end)
