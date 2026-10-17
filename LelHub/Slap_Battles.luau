local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Slap Battles", Style = "Native", Parameters = {}, Action = "Unlock gloves" }, [====[
for l, j in ipairs(game.workspace.Lobby.GloveStands:GetChildren()) do
        for i, v in ipairs(game.ReplicatedStorage._NETWORK:GetChildren()) do if v.ClassName == "RemoteEvent" then
            v:FireServer(j.Name)
        end
    end
end
]====])
