local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Poop a Big Poop", Style = "Rayfield", Parameters = {}, Action = "Enable game features" }, [====[
pcall(function()
    local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request) or http_request or request
    local DiscordInvite = "UsSvP4EpDj"
    HttpService = game:GetService("HttpService")
    if requestFunc then
            requestFunc({
                Url = 'http://127.0.0.1:6463/rpc?v=1',
                Method = 'POST',
                Headers = {
                    ['Content-Type'] = 'application/json',
                    Origin = 'https://discord.com'
                },
                Body = HttpService:JSONEncode({
                    cmd = 'INVITE_BROWSER',
                    nonce = HttpService:GenerateGUID(false),
                    args = {code = DiscordInvite}
                })
            })
    end
    end)
    function checkexecutor()
        local executor = identifyexecutor()
        if executor == "Xeno" then
            game.Players.LocalPlayer:Kick("Unsupported executor | Your executor doesn't support luraph.")
        end
    end
    checkexecutor()

debugX = true

local Rayfield = LelHubUI

local Window = Rayfield:CreateWindow({
   Name = "Zynix Instant Poop",
   Icon = 0,
   LoadingTitle = "Zynix Instant Poop",
   LoadingSubtitle = "by 087f",
   Theme = "Default",

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil, 
      FileName = "Big Hub"
   },

   Discord = {
      Enabled = true,
      Invite = "https://discord.gg/kh39AFNThN",
      RememberJoins = true
   },

   KeySystem = false, 
   KeySettings = {
      Title = "We actually have no keysys",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", 
      FileName = "Key", 
      SaveKey = true, 
      GrabKeyFromSite = false, 
      Key = {"Hello"} 
   }
})

local Tab = Window:CreateTab("Main", 4483362458)

local Section = Tab:CreateSection("Instant Poop")

local Button = Tab:CreateButton({
   Name = "Instant Poop",
   Callback = function()
       local args = {buffer.fromstring("\000\000\000\000")}
       game:GetService("ReplicatedStorage"):WaitForChild("Packets"):WaitForChild("Packet"):WaitForChild("RemoteEvent"):FireServer(unpack(args))
   end,
})

Rayfield:LoadConfiguration()
]====])
