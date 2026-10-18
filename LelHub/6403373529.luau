local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Slap Battles")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Gloves")
Hub:Button(section, "Run Glove Requests", function()
for l, j in ipairs(game.workspace.Lobby.GloveStands:GetChildren()) do
        for i, v in ipairs(game.ReplicatedStorage._NETWORK:GetChildren()) do if v.ClassName == "RemoteEvent" then
            v:FireServer(j.Name)
        end
    end
end

end)

