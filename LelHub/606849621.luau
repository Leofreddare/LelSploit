local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Jailbreak")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
Hub:SourceController(section, "Client Compatibility", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local fireFunc
local acTable
local blocked = 0

for _, v in getgc(true) do
    if type(v) == "table" and rawget(v, "FireServer") and type(rawget(v, "FireServer")) == "function" then
        local upv = debug.getupvalues(v.FireServer)

        if #upv == 1 and type(upv[1]) == "function" then
            fireFunc = upv[1]
            acTable = v

            break
        end
    end
end

if not acTable or not fireFunc then Hub:Notify("The client module is unavailable.") return end
local oldFire = fireFunc
local newFire = newcclosure(function(event, ...)
    if type(event) == "string" and event == "jly4rdsw" then
        blocked = blocked + 1

        return
    end

    return oldFire(event, ...)
end)

debug.setupvalue(acTable.FireServer, 1, newFire)

quiet("Bypass Loaded! ~ https://guns.lol/mcletshacks")

current:Add(function() debug.setupvalue(acTable.FireServer, 1, oldFire) end)

end, true)
