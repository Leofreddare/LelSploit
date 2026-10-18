local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Pool Incremental")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local valuehere = 0
Hub:Input("Amount", "0", function(value) valuehere = tonumber(value) or 0 end)
Hub:Button(Hub.Tabs.Game, "Send amount", function()
local args = {
    [1] = valuehere
}

game:GetService("ReplicatedStorage"):WaitForChild("UpdateValues"):FireServer(unpack(args))

end)
