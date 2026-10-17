local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Steal a Kitty!")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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

end)
