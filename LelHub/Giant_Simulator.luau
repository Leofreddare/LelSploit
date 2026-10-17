local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Giant Simulator", Style = "Native", Parameters = {{ Key = "PenguinFarm", Title = "Penguin Farm", Default = false },{ Key = "SnowmanFarm", Title = "Snowman Farm", Default = false },{ Key = "OrbFarm", Title = "Orb Farm", Default = false },{ Key = "GnomeFarm", Title = "Gnome Farm", Default = false },{ Key = "MeteorFarm", Title = "Meteor Farm", Default = false },{ Key = "SmartFarm", Title = "Smart Farm", Default = true },{ Key = "FasterRebirths", Title = "Faster Rebirths", Default = true },{ Key = "AutoRebirth", Title = "Auto Rebirth", Default = true },{ Key = "AllocateSoulGems", Title = "Allocate Soul Gems", Default = true },{ Key = "AutoClick", Title = "Auto Click", Default = true },{ Key = "RebirthAt", Title = "Rebirth At", Default = 500 },{ Key = "AntiAFK", Title = "Anti AFK", Default = true },}, Action = "Enable game features" }, [====[
getgenv().PenguinFarm = LelHubValue("PenguinFarm", false)
getgenv().SnowmanFarm = LelHubValue("SnowmanFarm", false)
getgenv().OrbFarm = LelHubValue("OrbFarm", false)
getgenv().GnomeFarm = LelHubValue("GnomeFarm", false)
getgenv().MeteorFarm = LelHubValue("MeteorFarm", false)
getgenv().SmartFarm = LelHubValue("SmartFarm", true)

getgenv().FasterRebirths = LelHubValue("FasterRebirths", true)
getgenv().AutoRebirth = LelHubValue("AutoRebirth", true)
getgenv().AllocateSoulGems = LelHubValue("AllocateSoulGems", true)
getgenv().AutoClick = LelHubValue("AutoClick", true)
getgenv().RebirthAt = LelHubValue("RebirthAt", 500)
getgenv().AntiAFK = LelHubValue("AntiAFK", true)

getgenv().connections = getgenv().connections or {}

local plr = game.Players.LocalPlayer
local hrp = plr.Character and plr.Character:WaitForChild("HumanoidRootPart")

local alive = true
local function oncharadded(character)
    hrp = character:WaitForChild("HumanoidRootPart")
    local human = character:WaitForChild("Humanoid")
    alive = true
    human.Died:Connect(function()
        alive = false
    end)
end

if plr.Character then
    oncharadded(plr.Character)
end

plr.CharacterAdded:Connect(oncharadded)

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
print("Orb folder found")

local afkConnection = nil
local function antiafk(enabled)
    if enabled then
        if not afkConnection then
            afkConnection = plr.Idled:Connect(function()
                print("[ANTI-AFK] Prevented being kicked from game.")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
            table.insert(getgenv().connections, afkConnection)
            print("[ANTI-AFK] Loaded")
        end
    else
        if afkConnection then
            afkConnection:Disconnect()
            table.remove(getgenv().connections, table.find(getgenv().connections, afkConnection) or 0)
            afkConnection = nil
            print("[ANTI-AFK] Disabled")
        end
    end
end

antiafk(getgenv().AntiAFK)

local function cleanupconnects()
    for _, conn in ipairs(getgenv().connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(getgenv().connections)
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
        if not (getgenv().SmartFarm and getgenv().OrbFarm and alive) then break end
        if orb.CFrame then
            print(string.format("Collecting orbs [%d/%d]", i, #validOrbs))
            hrp.CFrame = orb.CFrame
            task.wait(0.7)
        end
    end
end

local function doPenguinFarm()
    local penguins = workspace.NPC.Penguins:GetChildren()
    local canCollect = validPenguins()
    print("Number of penguins:", #penguins, "canCollect:", tostring(canCollect))
    if not canCollect then
        print("Not enough penguins..")
        return false
    end
    
    for i, penguin in ipairs(penguins) do
        if not (getgenv().SmartFarm and getgenv().PenguinFarm and alive) then break end
        if penguin:IsA("Model") and penguin:FindFirstChild("HumanoidRootPart") then
            print("Collecting penguin:", penguin.Name, string.format("[%d/%d]", i, #penguins))
            local conn
            conn = penguin.AncestryChanged:Connect(function(_, parent)
                if not parent and conn then
                    conn:Disconnect()
                    conn = nil
                end
            end)
            table.insert(getgenv().connections, conn)
            while getgenv().SmartFarm and getgenv().PenguinFarm and penguin.Parent and penguin:FindFirstChild("HumanoidRootPart") and alive do
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
    print("Number of snowmen: ", #snowmen)
    local validSnowmen = {}
    for _, snowman in ipairs(snowmen) do
        if snowman:IsA("Model") and snowman:FindFirstChild("TechBox") and snowman.TechBox:FindFirstChild("SnowMan") then
            table.insert(validSnowmen, snowman)
        end
    end
    for i, snowman in ipairs(validSnowmen) do
        print(string.format("Collecting snowman [%d/%d]", i, #validSnowmen))
        local conn
        conn = snowman.AncestryChanged:Connect(function(_, parent)
            if not parent and conn then
                conn:Disconnect()
                conn = nil
            end
        end)
        table.insert(getgenv().connections, conn)
        while getgenv().SmartFarm and getgenv().SnowmanFarm and alive and snowman.Parent and snowman.TechBox and snowman.TechBox:FindFirstChild("SnowMan") and snowman.TechBox.SnowMan.Transparency < 1 do
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
    print("Number of gnomes:", #gnomes, "canCollect:", tostring(canCollect))
    if not canCollect then
        print("Not enough gnomes..")
        return false
    end
    
    for i, gnome in ipairs(gnomes) do
        if not (getgenv().SmartFarm and getgenv().GnomeFarm and alive) then break end
        if gnome:IsA("Model") and gnome:FindFirstChild("HumanoidRootPart") then
            print("Collecting gnome:", gnome.Name, string.format("[%d/%d]", i, #gnomes))
            local conn
            conn = gnome.AncestryChanged:Connect(function(_, parent)
                if not parent and conn then
                    conn:Disconnect()
                    conn = nil
                end
            end)
            table.insert(getgenv().connections, conn)
            while getgenv().SmartFarm and getgenv().GnomeFarm and gnome.Parent and gnome:FindFirstChild("HumanoidRootPart") do
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
    print("Starting METEOR farm")
    local meteor = workspace.Meteors:FindFirstChild("Meteor")
    if meteor and meteor:FindFirstChild("Health") then
        local conn
        conn = meteor.Health.Changed:Connect(function(v)
            if v <= 0 and conn then
                conn:Disconnect()
                conn = nil
            end
        end)
        table.insert(getgenv().connections, conn)
        while getgenv().SmartFarm and getgenv().MeteorFarm and alive and meteor.Parent and meteor.Health.Value > 0 do
            hrp.CFrame = CFrame.new(meteor.Position + Vector3.new(0, 5, 0))
            click()
            task.wait(0.2)
        end
        cleanupconnects()
    end
end

local function smartfarm()
    print("[AX] started")
    while getgenv().SmartFarm do
        if not alive then
            print("player died awaiting respawn")
            repeat task.wait(1) until alive
            print("player spawned resuming")
        end
        
        print("Checking ORBS")
        if getgenv().OrbFarm and validOrbs() then
            doOrbFarm()
        end
        
        if getgenv().PenguinFarm then
            local collected = doPenguinFarm()
            if not collected then
                print("Moving onto GNOMES instead of penguins")
            end
        end
        
        if getgenv().GnomeFarm then
            local collected = doGnomeFarm()
            if not collected then
                print("Moving onto SNOWMEN instead of gnomes")
            end
        end
        
        if getgenv().SnowmanFarm then
            doSnowmanFarm()
        end
        
        if getgenv().MeteorFarm then
            if not validOrbs() then
                print("ORBS < 20")
                doMeteorFarm()
                doOrbFarm()
            else
                print("ORBS > 20")
            end
        end
        task.wait(1)
    end
    print("[AX] ended")
end

local acCorou
local function startautoclicking()
    if acCorou then return end
    acCorou = task.spawn(function()
        while getgenv().AutoClick and alive do
            click()
            task.wait(0.1)
        end
        acCorou = nil
    end)
end

local function stopautoclicking()
    getgenv().AutoClick = false
    acCorou = nil
end

local abCorou
local function startautorebirth()
    if abCorou then return end
    abCorou = task.spawn(function()
        while getgenv().AutoRebirth and alive do
            local level = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("⚡Level") and plr.leaderstats:FindFirstChild("⚡Level").Value or 0
            local rebirthAt = getgenv().RebirthAt or 0
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
    getgenv().AutoRebirth = false
    abCorou = nil
end

local agCorou
local function startallocatinggems()
    if agCorou then return end
    local RemoteEvent = rs.Crosstalk.RemoteEvent
    agCorou = task.spawn(function()
        while getgenv().AllocateSoulGems and alive do
            RemoteEvent:FireServer("GameService:MassUpgradeSkills", 416964)
            task.wait(1)
        end
        agCorou = nil
    end)
end

local function stopallocatinggems()
    getgenv().AllocateSoulGems = false
    agCorou = nil
end

task.spawn(function()
    while true do
        if getgenv().AutoClick then
            startautoclicking()
        else
            acCorou = nil
            stopautoclicking()
        end

        if getgenv().AutoRebirth then
            startautorebirth()
        else
            abCorou = nil
            stopautorebirth()
        end

        if getgenv().AllocateSoulGems then
            startallocatinggems()
        else
            agCorou = nil
            stopallocatinggems()
        end

        if getgenv().FasterRebirths and getgenv().AutoRebirth then
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

        antiafk(getgenv().AntiAFK)
        task.wait(1)
    end
end)

if getgenv().SmartFarm then
    getgenv().OrbFarm = true
    getgenv().PenguinFarm = true
    getgenv().GnomeFarm = true
    getgenv().SnowmanFarm = true
    task.spawn(smartfarm)
else
    if getgenv().OrbFarm then task.spawn(doOrbFarm) end
    if getgenv().PenguinFarm then task.spawn(doPenguinFarm) end
    if getgenv().SnowmanFarm then task.spawn(doSnowmanFarm) end
    if getgenv().GnomeFarm then task.spawn(doGnomeFarm) end
    if getgenv().MeteorFarm then task.spawn(doMeteorFarm) end
end
]====])
