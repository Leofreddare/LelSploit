local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Steal a Kitty!")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.Interval = 0.6
Hub:Slider(section, "SlapInterval", "Slap Interval", 0.6, 0.3, 3, function(value) preferences.Interval = value end, 1)
Hub:SourceController(section, "Slap Aura", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local players = game:GetService("Players")
local ply = players.LocalPlayer
local Event

if ply.Character:FindFirstChild("Slap") then 
  Event = ply.Character.Slap.Event 
else
  Event = ply.Backpack.Slap.Event 
end

while true do 
  task.wait(.555) 
  for i,v in players:GetPlayers() do 
    if v == ply then continue end 
    if not v.Character then continue end 
    Event:FireServer( 
    "slash",
    workspace[v.Name],
    Vector3.new(2^31, -0, 6)  
)
  end
end

end, false)
