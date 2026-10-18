local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Giant Simulator")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Automation")
local preferences = {}
preferences.OrbFarm = true
Hub:Toggle(section, "Farm_OrbFarm", "Farm Orbs", function(value) preferences.OrbFarm = value end, true)
preferences.PenguinFarm = true
Hub:Toggle(section, "Farm_PenguinFarm", "Farm Penguins", function(value) preferences.PenguinFarm = value end, true)
preferences.SnowmanFarm = true
Hub:Toggle(section, "Farm_SnowmanFarm", "Farm Snowmen", function(value) preferences.SnowmanFarm = value end, true)
preferences.GnomeFarm = true
Hub:Toggle(section, "Farm_GnomeFarm", "Farm Gnomes", function(value) preferences.GnomeFarm = value end, true)
preferences.MeteorFarm = false
Hub:Toggle(section, "Farm_MeteorFarm", "Farm Meteors", function(value) preferences.MeteorFarm = value end, false)
preferences.FasterRebirths = true
Hub:Toggle(section, "Farm_FasterRebirths", "Fast Rebirth", function(value) preferences.FasterRebirths = value end, true)
preferences.AutoRebirth = true
Hub:Toggle(section, "Farm_AutoRebirth", "Auto Rebirth", function(value) preferences.AutoRebirth = value end, true)
preferences.AllocateSoulGems = true
Hub:Toggle(section, "Farm_AllocateSoulGems", "Auto Soul Gems", function(value) preferences.AllocateSoulGems = value end, true)
preferences.AutoClick = true
Hub:Toggle(section, "Farm_AutoClick", "Auto Attack", function(value) preferences.AutoClick = value end, true)
preferences.AntiAFK = true
Hub:Toggle(section, "Farm_AntiAFK", "Anti Idle", function(value) preferences.AntiAFK = value end, true)
preferences.RebirthAt = 500
Hub:Slider(section, "RebirthLevel", "Rebirth Level", 500, 100, 10000, function(value) preferences.RebirthAt = value end)
Hub:SourceController(section, "Auto Farm", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn





preferences.SmartFarm = true








preferences.connections = preferences.connections or {}

local plr = game.Players.LocalPlayer
local hrp = plr.Character and plr.Character:WaitForChild("HumanoidRootPart")

local alive = true
local function oncharadded(character)
    hrp = character:WaitForChild("HumanoidRootPart")
    local human = character:WaitForChild("Humanoid")
    alive = true
    current:Connect(human.Died, function()
        alive = false
    end)
end

if plr.Character then
    oncharadded(plr.Character)
end

current:Connect(plr.CharacterAdded, oncharadded)

local vim = game:GetService("VirtualInputManager")
local vu = game:GetService("VirtualUser")
local rs = game:GetService("ReplicatedStorage")

local RemoteEvent = rs.Crosstalk.RemoteEvent 
local GameService = rs.Aero.AeroRemoteServices.GameService 

local function click()
    if not alive then return end
    if rs.Aero.AeroRemoteServices.GameService.WeaponAnimComplete and rs.Aero.AeroRemoteServices.GameService.WeaponAttackStart then
        rs.Aero.AeroRemoteServices.GameService.WeaponAnimComplete:FireServer()
        rs.Aero.AeroRemoteServices.GameService.WeaponAttackStart:FireServer()
    else
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

local function rebirth()
    local RemoteEvent = rs.Crosstalk.RemoteEvent
    RemoteEvent:FireServer("GameService:RebirthRequest", 403569)
end

local function findorbfolder()
    for _, child in ipairs(workspace.Scene:GetChildren()) do
        if child:IsA("Folder") and child.Name:match("^%d+$") then
            return child
        end
    end
    return nil
end

local function get_skin_count()
    local skins = plr.PlayerGui.Inventory.Main.InventoryBG.InventoryClipFrame.InventoryMainFrame
        .SkinInventoryFrame.SkinInvDataFrame.SkinSelectionPanel.SkinSelectionFrame:GetChildren()
    local count = 0
    for _, v in ipairs(skins) do
        if v:IsA("ImageLabel") then
            count = count + 1
        end
    end
    return count
end

local function get_weapon_count()
    local weapons = plr.PlayerGui.Inventory.Main.InventoryBG.InventoryClipFrame.InventoryMainFrame
        .WpnInventoryFrame.WpnInvDataFrame.WpnSelectionPanel.WpnSelectionFrame:GetChildren()
    local count = 0
    for _, v in ipairs(weapons) do
        if v:IsA("ImageLabel") then
            count = count + 1
        end
    end
    return count
end

local function buy_item(item_type)
    if item_type == "skin" then
        RemoteEvent:FireServer("GameService:OpenLegendaryCrate", 484129, "skin", 1)
    else
        RemoteEvent:FireServer("GameService:OpenLegendaryCrate", 487620, "weapon", 1)
    end
end

local function equip_best_items()
    local bestskin = get_skin_count()
    if get_skin_count() > 0 then
        GameService.EquipSkin:FireServer(tostring(bestskin))
    end

    local bestweapon = get_weapon_count()
    local secondbest = get_weapon_count() - 1
    if get_weapon_count() >= 2 then
        GameService.EquipWeapon:FireServer(tostring(bestweapon))
        GameService.EquipOffhand:FireServer(tostring(secondbest))
    end
end

local orbFolder = findorbfolder()
quiet("Orb folder found")

local afkConnection = nil
local function antiafk(enabled)
    if enabled then
        if not afkConnection then
            afkConnection = current:Connect(plr.Idled, function()
                quiet("[ANTI-AFK] Prevented being kicked from game.")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
            table.insert(preferences.connections, afkConnection)
            quiet("[ANTI-AFK] Loaded")
        end
    else
        if afkConnection then
            afkConnection:Disconnect()
            table.remove(preferences.connections, table.find(preferences.connections, afkConnection) or 0)
            afkConnection = nil
            quiet("[ANTI-AFK] Disabled")
        end
    end
end

antiafk(preferences.AntiAFK)

local function cleanupconnects()
    for _, conn in ipairs(preferences.connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(preferences.connections)
end

local function validOrbs()
    local count = 0
    for _, orb in ipairs(workspace.Scene[tostring(orbFolder)]:GetChildren()) do
        if orb:FindFirstChild("Prefab") then
            count = count + 1
        end
    end
    return count >= 20
end

local function validPenguins()
    return #workspace.NPC.Penguins:GetChildren() >= 2
end

local function validGnomes()
    return #workspace.NPC.Gnomes:GetChildren() >= 2
end

local function doOrbFarm()
    local orbs = workspace.Scene[tostring(orbFolder)]:GetChildren()
    local validOrbs = {}
    for _, orb in ipairs(orbs) do
        if orb:FindFirstChild("Prefab") then
            table.insert(validOrbs, orb)
        end
    end
    for i, orb in ipairs(validOrbs) do
        if not (preferences.SmartFarm and preferences.OrbFarm and alive) then break end
        if orb.CFrame then
            quiet(string.format("Collecting orbs [%d/%d]", i, #validOrbs))
            hrp.CFrame = orb.CFrame
            task.wait(0.7)
        end
    end
end

local function doPenguinFarm()
    local penguins = workspace.NPC.Penguins:GetChildren()
    local canCollect = validPenguins()
    quiet("Number of penguins:", #penguins, "canCollect:", tostring(canCollect))
    if not canCollect then
        quiet("Not enough penguins..")
        return false
    end
    
    for i, penguin in ipairs(penguins) do
        if not (preferences.SmartFarm and preferences.PenguinFarm and alive) then break end
        if penguin:IsA("Model") and penguin:FindFirstChild("HumanoidRootPart") then
            quiet("Collecting penguin:", penguin.Name, string.format("[%d/%d]", i, #penguins))
            local conn
            conn = current:Connect(penguin.AncestryChanged, function(_, parent)
                if not parent and conn then
                    conn:Disconnect()
                    conn = nil
                end
            end)
            table.insert(preferences.connections, conn)
            while preferences.SmartFarm and preferences.PenguinFarm and penguin.Parent and penguin:FindFirstChild("HumanoidRootPart") and alive do
                hrp.CFrame = penguin.HumanoidRootPart.CFrame
                click()
                task.wait()
            end
            cleanupconnects()
        end
    end
    return true
end

local function doSnowmanFarm()
    local snowmen = workspace.Ephemeral.AdvCrate:GetChildren()
    quiet("Number of snowmen: ", #snowmen)
    local validSnowmen = {}
    for _, snowman in ipairs(snowmen) do
        if snowman:IsA("Model") and snowman:FindFirstChild("TechBox") and snowman.TechBox:FindFirstChild("SnowMan") then
            table.insert(validSnowmen, snowman)
        end
    end
    for i, snowman in ipairs(validSnowmen) do
        quiet(string.format("Collecting snowman [%d/%d]", i, #validSnowmen))
        local conn
        conn = current:Connect(snowman.AncestryChanged, function(_, parent)
            if not parent and conn then
                conn:Disconnect()
                conn = nil
            end
        end)
        table.insert(preferences.connections, conn)
        while preferences.SmartFarm and preferences.SnowmanFarm and alive and snowman.Parent and snowman.TechBox and snowman.TechBox:FindFirstChild("SnowMan") and snowman.TechBox.SnowMan.Transparency < 1 do
            hrp.CFrame = snowman.TechBox.CFrame
            click()
            task.wait(0.2)
        end
        cleanupconnects()
    end
end

local function doGnomeFarm()
    local gnomes = workspace.NPC.Gnomes:GetChildren()
    local canCollect = validGnomes()
    quiet("Number of gnomes:", #gnomes, "canCollect:", tostring(canCollect))
    if not canCollect then
        quiet("Not enough gnomes..")
        return false
    end
    
    for i, gnome in ipairs(gnomes) do
        if not (preferences.SmartFarm and preferences.GnomeFarm and alive) then break end
        if gnome:IsA("Model") and gnome:FindFirstChild("HumanoidRootPart") then
            quiet("Collecting gnome:", gnome.Name, string.format("[%d/%d]", i, #gnomes))
            local conn
            conn = current:Connect(gnome.AncestryChanged, function(_, parent)
                if not parent and conn then
                    conn:Disconnect()
                    conn = nil
                end
            end)
            table.insert(preferences.connections, conn)
            while preferences.SmartFarm and preferences.GnomeFarm and gnome.Parent and gnome:FindFirstChild("HumanoidRootPart") do
                hrp.CFrame = gnome.HumanoidRootPart.CFrame
                click()
                task.wait()
            end
            cleanupconnects()
        end
    end
    return true
end

local function doMeteorFarm()
    quiet("Starting METEOR farm")
    local meteor = workspace.Meteors:FindFirstChild("Meteor")
    if meteor and meteor:FindFirstChild("Health") then
        local conn
        conn = current:Connect(meteor.Health.Changed, function(v)
            if v <= 0 and conn then
                conn:Disconnect()
                conn = nil
            end
        end)
        table.insert(preferences.connections, conn)
        while preferences.SmartFarm and preferences.MeteorFarm and alive and meteor.Parent and meteor.Health.Value > 0 do
            hrp.CFrame = CFrame.new(meteor.Position + Vector3.new(0, 5, 0))
            click()
            task.wait(0.2)
        end
        cleanupconnects()
    end
end

local function smartfarm()
    quiet("[AX] started")
    while preferences.SmartFarm do
        if not alive then
            quiet("player died awaiting respawn")
            repeat task.wait(1) until alive
            quiet("player spawned resuming")
        end
        
        quiet("Checking ORBS")
        if preferences.OrbFarm and validOrbs() then
            doOrbFarm()
        end
        
        if preferences.PenguinFarm then
            local collected = doPenguinFarm()
            if not collected then
                quiet("Moving onto GNOMES instead of penguins")
            end
        end
        
        if preferences.GnomeFarm then
            local collected = doGnomeFarm()
            if not collected then
                quiet("Moving onto SNOWMEN instead of gnomes")
            end
        end
        
        if preferences.SnowmanFarm then
            doSnowmanFarm()
        end
        
        if preferences.MeteorFarm then
            if not validOrbs() then
                quiet("ORBS < 20")
                doMeteorFarm()
                doOrbFarm()
            else
                quiet("ORBS > 20")
            end
        end
        task.wait(1)
    end
    quiet("[AX] ended")
end

local acCorou
local function startautoclicking()
    if acCorou then return end
    acCorou = task.spawn(function()
        while preferences.AutoClick and alive do
            click()
            task.wait(0.1)
        end
        acCorou = nil
    end)
end

local function stopautoclicking()
    preferences.AutoClick = false
    acCorou = nil
end

local abCorou
local function startautorebirth()
    if abCorou then return end
    abCorou = task.spawn(function()
        while preferences.AutoRebirth and alive do
            local level = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("⚡Level") and plr.leaderstats:FindFirstChild("⚡Level").Value or 0
            local rebirthAt = preferences.RebirthAt or 0
            if rebirthAt >= 100 and level >= rebirthAt then
                rebirth()
                task.wait(3)
            else
                task.wait(1)
            end
        end
        abCorou = nil
    end)
end

local function stopautorebirth()
    preferences.AutoRebirth = false
    abCorou = nil
end

local agCorou
local function startallocatinggems()
    if agCorou then return end
    local RemoteEvent = rs.Crosstalk.RemoteEvent
    agCorou = task.spawn(function()
        while preferences.AllocateSoulGems and alive do
            RemoteEvent:FireServer("GameService:MassUpgradeSkills", 416964)
            task.wait(1)
        end
        agCorou = nil
    end)
end

local function stopallocatinggems()
    preferences.AllocateSoulGems = false
    agCorou = nil
end

task.spawn(function()
    while true do
        if preferences.AutoClick then
            startautoclicking()
        else
            acCorou = nil
            stopautoclicking()
        end

        if preferences.AutoRebirth then
            startautorebirth()
        else
            abCorou = nil
            stopautorebirth()
        end

        if preferences.AllocateSoulGems then
            startallocatinggems()
        else
            agCorou = nil
            stopallocatinggems()
        end

        if preferences.FasterRebirths and preferences.AutoRebirth then
            if get_weapon_count() < 4 or get_skin_count() < 4 then
                if get_weapon_count() < 4 then
                    buy_item("wpn")
                end
                if get_skin_count() < 4 then
                    buy_item("skin")
                end
            else
                equip_best_items()
            end
        end

        antiafk(preferences.AntiAFK)
        task.wait(1)
    end
end)

if preferences.SmartFarm then
    task.spawn(smartfarm)
else
    if preferences.OrbFarm then task.spawn(doOrbFarm) end
    if preferences.PenguinFarm then task.spawn(doPenguinFarm) end
    if preferences.SnowmanFarm then task.spawn(doSnowmanFarm) end
    if preferences.GnomeFarm then task.spawn(doGnomeFarm) end
    if preferences.MeteorFarm then task.spawn(doMeteorFarm) end
end

end, false)
