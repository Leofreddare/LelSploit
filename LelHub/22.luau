local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Loomian Legacy")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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

end)
