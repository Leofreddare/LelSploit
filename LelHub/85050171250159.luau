local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Poop a Big Poop")
local LelUI = Hub.Native
local LelAPI = Hub:Interface("Rayfield")
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Rayfield = LelAPI

local Window = Rayfield:CreateWindow({
   Name = "Zynix Instant Poop",
   Icon = 0,
   LoadingTitle = "Zynix Instant Poop",
   LoadingSubtitle = "by 087f",
   Theme = "Default",

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil, 
      FileName = "Big Hub"
   },

   Discord = {
      Enabled = true,
      Invite = "https://discord.gg/kh39AFNThN",
      RememberJoins = true
   },

   KeySystem = false, 
   KeySettings = {
      Title = "We actually have no keysys",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", 
      FileName = "Key", 
      SaveKey = true, 
      GrabKeyFromSite = false, 
      Key = {"Hello"} 
   }
})

local Tab = Window:CreateTab("Main", 4483362458)

local Section = Tab:CreateSection("Instant Poop")

local Button = Tab:CreateButton({
   Name = "Instant Poop",
   Callback = function()
       local args = {buffer.fromstring("\000\000\000\000")}
       game:GetService("ReplicatedStorage"):WaitForChild("Packets"):WaitForChild("Packet"):WaitForChild("RemoteEvent"):FireServer(unpack(args))
   end,
})

Rayfield:LoadConfiguration()

end)
