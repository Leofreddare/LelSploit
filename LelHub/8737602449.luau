local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("PLS DONATE")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local preferences = {}
preferences.Message = "Thank you for the donation!"
Hub:Input("Thank You Message", preferences.Message, function(value) preferences.Message = value end)
Hub:SourceController(section, "Auto Thanks", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
getgenv().autoThank = true 
local chat = game:GetService("TextChatService"):WaitForChild("TextChannels"):WaitForChild("RBXGeneral") 

msgsTable = {
   "master oogway thanks u",
   "fr fr omg ty",
   "me when the impostor donated, thanks",
   "lets goo dude thanks"
   
   
   
}
current:Connect(game.Players.LocalPlayer.leaderstats.Raised.Changed, function()
	if getgenv().autoThank then 
		chat:SendAsync(preferences.Message) 
	end 
end)
local VirtualUser = game:GetService("VirtualUser") 
current:Connect(game.Players.LocalPlayer.Idled, function() 
	VirtualUser:CaptureController() 
	VirtualUser:ClickButton2(Vector2.new()) 
end)

end, false)
