local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Empire Clash")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Game Controls")
local preferences = {}
Hub:SourceController(section, "Client Compatibility", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
if not game.IsLoaded then
    game.Loaded:Wait()
end

local debugMod = false
local function log(x)
    if debugMod then
        quiet(x)
    end
end

local crashFns = {
    Crash = true, HardCrash = true, GPUCrash = true,
    RAMCrash = true, KillClient = true, SetFPS = true
}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function nothing() end

local function hookTableFunctions(t)
    if rawget(t, "RegisterHitbox") then
        hookfunction(t.RegisterHitbox.Fire, nothing)
        quiet("Hooked RegisterHitbox's Fire | Potential side ban")
        return
    end
    for name, elem in t do
        if typeof(elem) == "function" then
            hookfunction(elem, nothing)
            quiet(`Hooked {name}`)
        elseif typeof(elem) == "table" then
            local remote = rawget(elem, "_re")
            if remote and remote.OnClientEvent then
                for _, con in getconnections(remote.OnClientEvent) do
                    con:Disable()
                end
            end
            hookfunction(elem.Fire, nothing)
            quiet(`Hooked {name}'s Fire`)
        end
    end
end

for _, elem in getgc(true) do
    if typeof(elem) == "table" then
        if rawget(elem, "Detected") and typeof(elem.Detected) == "function" and rawget(elem, "RLocked") then
            hookfunction(elem.Detected, function(action, reason, nocrash)
                log(`Detected: Action: {action}, Reason: {reason}, Crashing: {not nocrash}`)
                return true
            end)
            log("Hooked Detected Function")
        end
        if (rawget(elem, "ILikeToMoveItMoveIt") and rawget(elem, "CasperSlidePartTwo") and rawget(elem, "NineteenDollaFortniteGiftCard"))
            or rawget(elem, "RegisterHitbox") then
            hookTableFunctions(elem)
        end
    elseif typeof(elem) == "function" then
        local name = debug.info(elem, "n")
        if crashFns[name] or name == "crashPlayer" then
            hookfunction(elem, nothing)
            log(`Hooked Lag/Crash function : {name}`)
            if name == "crashPlayer" then
                quiet("Hooked crash")
            end
        end
    end
end

local oldNCMT
local oldIMT

oldNCMT = hookmetamethod(player, "__namecall", function(self, ...)
    if not checkcaller() and rawequal(getnamecallmethod(), "Kick") then
        return
    else
        return oldNCMT(self, ...)
    end
end)

oldIMT = hookmetamethod(game, "__index", newcclosure(function(self, k)
    if not checkcaller() and rawequal(k, "Speed") and rawequal(oldIMT(self, "ClassName"), "AnimationTack") then
        return 1
    end
    return oldIMT(self, k)
end))

workspace:SetAttribute("SillyTest", true)
workspace:GetAttributeChangedSignal("SillyTest"):Connect(function()
    workspace:SetAttribute("SillyTest", true)
end)

end, true)
