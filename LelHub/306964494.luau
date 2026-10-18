local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Loomian Legacy")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Encounters")
local interval = 5
local function encounter()
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

end
Hub:Loop(section, "Auto Wild Encounter", function() return interval end, encounter)
Hub:Slider(section, "EncounterInterval", "Encounter Interval", 5, 3, 30, function(value) interval = value end)
Hub:Button(section, "Start Wild Encounter", encounter)

