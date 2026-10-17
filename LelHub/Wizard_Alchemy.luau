local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Wizard Alchemy", Style = "Native", Parameters = {{ Key = "Dupe", Title = "Dupe", Default = true },}, Action = "Start quest loop" }, [====[
getgenv().Dupe = LelHubValue("Dupe", true)
local q = "\228\187\187\229\138\16114"
local r = game:GetService("ReplicatedStorage"):WaitForChild("Msg")
local t = r:WaitForChild("Function"):WaitForChild("TalkFunc")
local e = r:WaitForChild("RemoteEvent"):WaitForChild("RemoteEvent")

task.spawn(function()
    while getgenv().Dupe do
        task.spawn(function()
            e:FireServer("\232\167\166\229\143\145\232\129\138\229\164\169", {"\229\147\136\229\136\169\229\155\160\231\137\185", "10010100"})
            task.spawn(function() t:InvokeServer("\229\174\140\230\136\144\228\187\187\229\138\161", {q}) end)
            task.spawn(function() t:InvokeServer("\229\143\145\230\148\190\228\187\187\229\138\161", {q}) end)
            e:FireServer("\229\136\183\230\150\176\229\188\149\229\175\188")
        end)
        task.wait()
    end
end)
]====])
