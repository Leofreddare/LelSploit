local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "PLS DONATE", Style = "Native", Parameters = {{ Key = "autoThank", Title = "auto Thank", Default = true },}, Action = "Enable game features" }, [====[
getgenv().autoThank = LelHubValue("autoThank", true) 
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
]====])
