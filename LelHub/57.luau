local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("The Classic Soccer")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local p = game:GetService("Players").LocalPlayer
local c = p.Character or p.CharacterAdded:Wait()
local hrp = c:WaitForChild("Humanoid")
for _,x in ipairs(getconnections(hrp:GetPropertyChangedSignal("WalkSpeed"))) do x:Disconnect() end
hrp.WalkSpeed = 100

end)
