local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("PLS DONATE")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
getgenv().autoThank = true 
local chat = game:GetService("TextChatService"):WaitForChild("TextChannels"):WaitForChild("RBXGeneral") 

msgsTable = {
   "master oogway thanks u",
   "fr fr omg ty",
   "me when the impostor donated, thanks",
   "lets goo dude thanks"
   
   
   
}
game.Players.LocalPlayer.leaderstats.Raised.Changed:Connect(function()
	if getgenv().autoThank then 
		chat:SendAsync(msgsTable[math.random(1, #msgsTable)]) 
	end 
end)
local VirtualUser = game:GetService("VirtualUser") 
game.Players.LocalPlayer.Idled:Connect(function() 
	VirtualUser:CaptureController() 
	VirtualUser:ClickButton2(Vector2.new()) 
end)

end)
