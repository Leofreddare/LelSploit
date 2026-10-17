local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Build and Crash", Style = "Native", Parameters = {}, Action = "Claim cash" }, [====[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiveMoney = ReplicatedStorage.Events.GiveMoney 

GiveMoney:FireServer(
    99999999999999999999999999999999999999999
)
]====])
