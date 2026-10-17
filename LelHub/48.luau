local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Anime Arise Evolution")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
getgenv().AutoRank = true
getgenv().AutoAttack = true
getgenv().GrabDrops = true
getgenv().AutoBuyZone = true
getgenv().AutoAr = true

local upvr = require(game:GetService("Players").LocalPlayer.PlayerScripts.MetaService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bridge = ReplicatedStorage:WaitForChild("Bridge")

local function parseNumbers(input)
    local part1, part2 = input:match("([^/]+)/([^/]+)")
    if not part1 or not part2 then
        return nil, nil 
    end

    local function isNumeric(str)
        local noCommas = str:gsub(",", "")
        return noCommas:match("^%d+$") ~= nil
    end

    local function safeTonumber(str)
        local noCommas = str:gsub(",", "")
        if noCommas ~= "" and isNumeric(str) then
            return tonumber(noCommas)
        else
            return upvr.Utils.Number:Unformat(str)
        end
    end

    local num1 = safeTonumber(part1)
    local num2 = safeTonumber(part2)

    return num1, num2
end
spawn(function() 
    while getgenv().AutoAr and task.wait() do
        for _, v in next, game:GetService("Players").LocalPlayer.PlayerGui.UI.Frames.Achievements.NewMain.body.items:GetChildren() do
            if not v:IsA("ImageLabel") then continue end
            if v.claimed.Visible then continue end 
            local num1, num2 = parseNumbers(v.backFill.progress.Text)
            if num1 and num2 and num1 < num2 then continue end
            print(v.Name)
            game:GetService("ReplicatedStorage"):WaitForChild("Bridge"):FireServer("Achievements", "Claim", v.Name)
        end
    end
end)


spawn(function()
    while getgenv().AutoRank and task.wait() do
        local Data = upvr.Data
        local Energy = Data.Energy
        local nextRank = Data.Rank + 1
        if upvr.SharedModules.Ranks[nextRank] then
            local required = upvr.Utils.Number:Unformat(upvr.SharedModules.Ranks[nextRank].Price)
            if Energy >= required then
                Bridge:FireServer("RankUp", "Evolve")
            end
        end
    end
end)

spawn(function() 
    while getgenv().AutoBuyZone and task.wait() do
        local Data = upvr.Data
        local last = nil;
        for i,v in pairs(Data.Inventory.Maps) do
            last = i
        end
        local index = upvr.SharedModules.Maps[last].Index
        local nextArea = nil
        for i,v in pairs(upvr.SharedModules.Maps) do
            for f,s in pairs(v) do
                if f == 'Index' and s == index + 1 then 
                    nextArea = v
                end
            end
        end
        if Data.Gems < upvr.Utils.Number:Unformat(nextArea.Price) then continue end
        game:GetService("ReplicatedStorage"):WaitForChild("Bridge"):FireServer("Teleport","Buy",nextArea.Name);
        task.wait(.5)
        game:GetService("ReplicatedStorage"):WaitForChild("Bridge"):FireServer("Teleport","Spawn",nextArea.Name);
    end
end)


spawn(function()
    while getgenv().AutoAttack and task.wait() do
        if upvr.Cache and upvr.Cache.ProximityEnemy then
            Bridge:FireServer("Attack", "Click", upvr.Cache.ProximityEnemy)
        end
    end
end)

workspace.Debris.ChildAdded:Connect(function(part)
    if not getgenv().GrabDrops then return end
    if part:IsA('Part') and part:FindFirstChild("UID") then
        local args = {
            "Drops",
            "Collect",
            part.Name
        }
        Bridge:FireServer(unpack(args))
        part:Destroy()
    end
end)

end)
