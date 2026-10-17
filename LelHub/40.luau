local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Build and Crash")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiveMoney = ReplicatedStorage.Events.GiveMoney 

GiveMoney:FireServer(
    99999999999999999999999999999999999999999
)

end)
