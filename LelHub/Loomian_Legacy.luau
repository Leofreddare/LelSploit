local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Loomian Legacy", Style = "Native", Parameters = {}, Action = "Start wild battle" }, [====[
local Main
for _,v in pairs(getgc(true)) do
    if typeof(v) == "table" and rawget(v, "DataManager") then
        Main = v
        break
    end
end

if Main.DataManager.currentChunk.regionData.Grass then
    

    Main.Battle.doWildBattle(Main.Battle, Main.DataManager.currentChunk.regionData.Grass, {})
 
    

    


end
]====])
