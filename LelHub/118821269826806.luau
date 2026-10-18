local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Wizard Alchemy")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Automation")
local preferences = {}
Hub:SourceController(section, "Auto Quest Rewards", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
getgenv().Dupe = true
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
        task.wait(0.5)
    end
end)

end, false)
