local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "BORDER Military Roleplay", Style = "Native", Parameters = {}, Action = "Claim currency" }, [====[
game:GetService("ReplicatedStorage").Configuration["Core Systems"].Datastore.GiveCurrency:FireServer({Type = "Money",Amount = 9e9})
game:GetService("ReplicatedStorage").Configuration["Core Systems"].Datastore.GiveCurrency:FireServer({Type = "Diamond",Amount = 9e9})
]====])
