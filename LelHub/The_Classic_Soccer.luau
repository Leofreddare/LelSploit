local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "The Classic Soccer", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local p = game:GetService("Players").LocalPlayer
local c = p.Character or p.CharacterAdded:Wait()
local hrp = c:WaitForChild("Humanoid")
for _,x in ipairs(getconnections(hrp:GetPropertyChangedSignal("WalkSpeed"))) do x:Disconnect() end
hrp.WalkSpeed = 100
]====])
