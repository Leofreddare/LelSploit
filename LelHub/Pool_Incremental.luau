local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Pool Incremental", Style = "Native", Parameters = {{ Key = "Amount", Default = 0 },}, Action = "Send amount" }, [====[
local args = {
    [1] = LelHubValue("Amount", 0)
}

game:GetService("ReplicatedStorage"):WaitForChild("UpdateValues"):FireServer(unpack(args))
]====])
