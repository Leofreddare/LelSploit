local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Jailbreak", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
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

local oldFire = fireFunc
local newFire = newcclosure(function(event, ...)
    if type(event) == "string" and event == "jly4rdsw" then
        blocked = blocked + 1

        return
    end

    return oldFire(event, ...)
end)

debug.setupvalue(acTable.FireServer, 1, newFire)

warn("Bypass Loaded! ~ https://guns.lol/mcletshacks")
]====])
