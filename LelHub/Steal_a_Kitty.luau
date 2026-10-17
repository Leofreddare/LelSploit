local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Steal a Kitty!", Style = "Native", Parameters = {}, Action = "Start slap loop" }, [====[
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
]====])
