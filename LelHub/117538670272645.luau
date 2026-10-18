local function lelHubFetchSource(url)
    local function text(value)
        if type(value) ~= "string" or not value:find("%S") then return end
        local start = value:sub(1, 160):gsub("^%s+", "")
        start = start:lower()
        if start:find("<!doctype", 1, true) or start:find("<html", 1, true) or start:find("404: not found", 1, true) then return end
        return value
    end
    local methods = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
    }
    local send = request or http_request or (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    if type(send) == "function" then
        table.insert(methods, function()
            local response = send({ Url = url, Method = "GET", Timeout = 15 })
            if type(response) == "string" then return response end
            if type(response) ~= "table" or response.Success == false then return end
            local status = tonumber(response.StatusCode or response.Status)
            if status and (status < 200 or status >= 300) then return end
            return response.Body or response.body
        end)
    end
    for attempt = 1, 2 do
        for _, fetch in ipairs(methods) do
            local ok, response = pcall(fetch)
            local source = ok and text(response)
            if source then return source end
        end
        if attempt < 2 then task.wait(0.25) end
    end
    error("[LelHub] Download returned no script text: " .. url, 0)
end

local function lelHubCompileRemote(url, name)
    if type(loadstring) ~= "function" then error("[LelHub] This executor does not provide loadstring.", 0) end
    local source = lelHubFetchSource(url)
    local ok, chunk, message = pcall(loadstring, source, name or "LelHub/Remote")
    if not ok or type(chunk) ~= "function" then error("[LelHub] Downloaded script could not compile: " .. tostring(message or chunk), 0) end
    return chunk
end

local function lelHubLoadInterface()
    local urls = {
        "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/f.luau",
        "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau",
    }
    local lastError
    for _, url in ipairs(urls) do
        local ok, library = pcall(function() return lelHubCompileRemote(url, "LelHub/Fluent")() end)
        if ok and type(library) == "table" and type(library.CreateWindow) == "function" then return library end
        lastError = ok and "The interface did not return a valid library." or tostring(library)
    end
    error("[LelHub] Could not load the interface. " .. tostring(lastError), 0)
end

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Missile Wars")
local LelUI = Hub.Native
local LelAPI = Hub:Interface("WindUI")
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local WindUI = LelAPI


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer


local Remotes = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
local LaunchAllMissiles = Remotes:WaitForChild("LaunchAllMissiles")
local PlaceItem = Remotes:WaitForChild("PlaceItem")
local PurchaseItem = Remotes:WaitForChild("PurchaseItem")
local HireWorker = Remotes:WaitForChild("HireWorker")


local BUILD_TYPES = {
    "Small House","Farm","Medium House","Large House","Greenhouse","Apartment",
    "Bank","Trade Port","Oil Rig","Factory","Industrial Factory",
    "Skyscraper","Power Plant","Anti Air","Basic AA Turret","Bubble Shield",
    "EMP Defense Tower","Flare Launcher","Laser Defense System"
}

local ROCKET_NAMES = { "Basic Missile","Vanta","Bazooka","Super Missile","Titan Missile",
    "Sparrow","Viper Missile","Hydra","AMG","Nuke","VX-9","VIP Launcher"
}

local WORKER_NAMES = { "Farmer","LavaBuilder","MissileEngineer","ProBuilder","RepairMan" }

local BUILD_SET = {}
for _, name in ipairs(BUILD_TYPES) do
    BUILD_SET[name] = true
end

local ROCKET_SET = {}
for _, name in ipairs(ROCKET_NAMES) do
    ROCKET_SET[name] = true
end

local WORKER_SET = {}
for _, name in ipairs(WORKER_NAMES) do
    WORKER_SET[name] = true
end


local ASSET_SIZES = {}

local function buildSizeLookup()
    local assets = ReplicatedStorage:FindFirstChild("Game")
    if not assets then return end
    assets = assets:FindFirstChild("Assets")
    if not assets then return end

    
    local missilesFolder = assets:FindFirstChild("Missiles")
    if missilesFolder then
        for _, missile in ipairs(missilesFolder:GetChildren()) do
            local size = missile:IsA("BasePart") and missile.Size or
                        (missile.PrimaryPart and missile.PrimaryPart.Size)
            if size then
                ASSET_SIZES[missile.Name] = size
            end
        end
    end

    
    local housesFolder = assets:FindFirstChild("Houses")
    if housesFolder then
        for _, house in ipairs(housesFolder:GetChildren()) do
            local size = house:IsA("BasePart") and house.Size or
                        (house.PrimaryPart and house.PrimaryPart.Size)
            if size then
                ASSET_SIZES[house.Name] = size
            end
        end
    end

    
    local defensesFolder = assets:FindFirstChild("Defenses")
    if defensesFolder then
        for _, defense in ipairs(defensesFolder:GetChildren()) do
            local size = defense:IsA("BasePart") and defense.Size or
                        (defense.PrimaryPart and defense.PrimaryPart.Size)
            if size then
                ASSET_SIZES[defense.Name] = size
            end
        end
    end

    
    local workersFolder = assets:FindFirstChild("Workers")
    if workersFolder then
        for _, worker in ipairs(workersFolder:GetChildren()) do
            local size = worker:IsA("BasePart") and worker.Size or
                        (worker.PrimaryPart and worker.PrimaryPart.Size)
            if size then
                ASSET_SIZES[worker.Name] = size
            end
        end
    end
end

buildSizeLookup()


local Settings = {
    LauncherEnabled = false,
    AutoplaceEnabled = false,
    AutoplaceBuildings = false,
    TargetPlayers = false,
    PrioritizeBigMeteor = false,
    AutobuyRockets = false,
    AutobuyBuildings = false,
    AutobuyBuilding = "Small House",
    AutobuyWorkers = false,
    AutobuyWorkersList = {},
    FireDelay = 0.08,
    FireBatch = 1,
    PlaceDelay = 0.15,
    BuildingPlaceDelay = 0.3,
    BuyDelay = 0.5,
    TargetBuildings = {},
    AutoplaceRockets = {},
    AutoplaceRocketsList = {},
    AutoplaceBuildingsList = {},
    AutobuyRocketsList = {},
    AutobuyBuildingsList = {},
    CollisionRadius = 2,
    PlacementRetries = 50,
    EdgeAvoidance = 3,
    MinimumSpacing = 2,
}

local PlacementStats = {
    successCount = 0,
    failCount = 0,
    lastUpdate = 0,
}


for _, name in ipairs(BUILD_TYPES) do
    Settings.TargetBuildings[name] = true
    Settings.AutoplaceBuildingsList[name] = true
    Settings.AutobuyBuildingsList[name] = true
end

for _, name in ipairs(ROCKET_NAMES) do
    Settings.AutobuyRocketsList[name] = true
    Settings.AutoplaceRockets[name] = true
end

for _, name in ipairs(WORKER_NAMES) do
    Settings.AutobuyWorkersList[name] = true
end

local lastFire = 0
local lastPlace = 0
local lastPlaceBuilding = 0
local lastRocketBuy = 0
local lastBuildingBuy = 0
local lastWorkerBuy = 0
local lastTargetScan = 0
local targetQueue = {}
local cachedPlayerPlot = nil
local cachedPlotRefreshTime = 0
local cachedPlacedItems = {}
local cachedPlacedItemsRefresh = 0
local gridPosition = { row = 0, col = 0 }
local gridPositionBuildings = { row = 0, col = 0 }
local heartbeatCounter = 0


local function getPlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local activePlots = plots:FindFirstChild("ActivePlots")
    if not activePlots then return nil end

    local playerName = LocalPlayer.Name
    local playerDisplayName = LocalPlayer.DisplayName

    for _, plot in ipairs(activePlots:GetChildren()) do
        local placementPart = plot:FindFirstChild("PlacementPart")
        if placementPart then
            local userInfoAttachment = placementPart:FindFirstChild("UserInfoAttachment")
            if userInfoAttachment then
                local userInfo = userInfoAttachment:FindFirstChild("UserInfo")
                if userInfo then
                    local card = userInfo:FindFirstChild("Card")
                    if card then
                        local info = card:FindFirstChild("Info")
                        if info then
                            local username = info:FindFirstChild("Username")
                            if username and (username.Text == playerName or username.Text == playerDisplayName) then
                                return plot
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function getPlacementBounds(plot)
    local placementPart = plot:FindFirstChild("PlacementPart")
    if not placementPart or not placementPart:IsA("BasePart") then return nil end

    local pos = placementPart.Position
    local size = placementPart.Size

    return {
        minX = pos.X - (size.X / 2),
        maxX = pos.X + (size.X / 2),
        minZ = pos.Z - (size.Z / 2),
        maxZ = pos.Z + (size.Z / 2),
        topY = pos.Y + (size.Y / 2),
    }
end

local function getPlacedItems(plot)
    local placedItems = plot:FindFirstChild("PlacedItems")
    if not placedItems then return {} end

    local items = {}
    for _, item in ipairs(placedItems:GetChildren()) do
        if item:IsA("BasePart") then
            table.insert(items, {position = item.Position, size = item.Size})
        elseif item:IsA("Model") and item.PrimaryPart then
            table.insert(items, {position = item.PrimaryPart.Position, size = item.PrimaryPart.Size})
        end
    end
    return items
end

local function checkCollision(x, z, placedItems)
    local minDist = Settings.CollisionRadius + Settings.MinimumSpacing
    local minDistSq = minDist * minDist

    for _, item in ipairs(placedItems) do
        local dx = x - item.position.X
        local dz = z - item.position.Z
        local distSq = dx * dx + dz * dz
        local itemRadius = item.radius or math.sqrt((item.size.X / 2) ^ 2 + (item.size.Z / 2) ^ 2)
        if not item.radius then item.radius = itemRadius end
        local thresholdSq = (minDist + itemRadius) ^ 2

        if distSq < thresholdSq then return true end
    end
    return false
end

local function getGridPosition(bounds, placedItems, gridPos, itemName)
    if not bounds then return nil end
    gridPos = gridPos or gridPosition

    local padding = Settings.EdgeAvoidance
    local sizeX = bounds.maxX - bounds.minX
    local sizeZ = bounds.maxZ - bounds.minZ

    local minRelX = -(sizeX / 2) + padding
    local maxRelX = (sizeX / 2) - padding
    local minRelZ = -(sizeZ / 2) + padding
    local maxRelZ = (sizeZ / 2) - padding

    if minRelX >= maxRelX or minRelZ >= maxRelZ then return nil end

    local itemHalfWidth = 0.5
    local itemHalfDepth = 0.5
    if itemName and ASSET_SIZES[itemName] then
        local itemSize = ASSET_SIZES[itemName]
        itemHalfWidth = itemSize.X / 2
        itemHalfDepth = itemSize.Z / 2
    end

    local spacing = 2.5
    if itemName and ASSET_SIZES[itemName] then
        local itemSize = ASSET_SIZES[itemName]
        local maxDim = math.max(itemSize.X, itemSize.Z)
        spacing = maxDim + 2.5
    end

    local idx = gridPos.idx or 0
    local relX, relZ = 0, 0

    if idx == 0 then
        relX, relZ = 0, 0
    else
        local layer = 0
        local remaining = idx

        while remaining > layer * 8 do
            remaining = remaining - layer * 8
            layer = layer + 1
        end

        local s = layer * spacing
        local pos = remaining

        if pos <= layer then
            relX = (pos - 1) * spacing - (layer - 1) * spacing
            relZ = -s
        elseif pos <= 2 * layer then
            relX = s
            relZ = -s + (pos - layer) * spacing
        elseif pos <= 3 * layer then
            relX = s - (pos - 2 * layer) * spacing
            relZ = s
        else
            relX = -s
            relZ = s - (pos - 3 * layer) * spacing
        end
    end

    if relX - itemHalfWidth < minRelX or relX + itemHalfWidth > maxRelX or relZ - itemHalfDepth < minRelZ or relZ + itemHalfDepth > maxRelZ then
        gridPos.idx = idx + 1
        return nil
    end

    local worldX = (bounds.minX + bounds.maxX) / 2 + relX
    local worldZ = (bounds.minZ + bounds.maxZ) / 2 + relZ

    if not checkCollision(worldX, worldZ, placedItems) then
        gridPos.idx = idx + 1
        return relX, relZ
    end

    gridPos.idx = idx + 1
    return nil
end

local function canPlace()
    return tick() - lastPlace >= Settings.PlaceDelay
end

local function getSelectedRocket()
    local selected = {}
    for name, enabled in pairs(Settings.AutoplaceRockets) do
        if enabled then table.insert(selected, name) end
    end
    return #selected > 0 and selected[math.random(#selected)] or nil
end

local function getSelectedBuilding()
    local selected = {}
    for name, enabled in pairs(Settings.AutoplaceBuildingsList) do
        if enabled then table.insert(selected, name) end
    end
    return #selected > 0 and selected[math.random(#selected)] or nil
end

local function placeAtSpot()
    if not canPlace() then return end

    local rocketType = getSelectedRocket()
    if not rocketType then return end

    if not cachedPlayerPlot or tick() - cachedPlotRefreshTime > 5 then
        cachedPlayerPlot = getPlayerPlot()
        cachedPlotRefreshTime = tick()
        cachedPlacedItemsRefresh = 0
        gridPosition = { row = 0, col = 0 }
    end
    if not cachedPlayerPlot then return end

    local bounds = getPlacementBounds(cachedPlayerPlot)
    if not bounds then return end

    if tick() - cachedPlacedItemsRefresh > 1 then
        cachedPlacedItems = getPlacedItems(cachedPlayerPlot)
        cachedPlacedItemsRefresh = tick()
    end

    for _ = 1, 5 do
        local relX, relZ = getGridPosition(bounds, cachedPlacedItems, gridPosition, rocketType)
        if relX then
            lastPlace = tick()
            pcall(function()
                PlaceItem:FireServer(rocketType, relX, relZ, 0)
                table.insert(cachedPlacedItems, {position = Vector3.new((bounds.minX + bounds.maxX) / 2 + relX, bounds.topY, (bounds.minZ + bounds.maxZ) / 2 + relZ), size = ASSET_SIZES[rocketType] or Vector3.new(1,1,1)})
            end)
            PlacementStats.successCount = PlacementStats.successCount + 1
            PlacementStats.lastUpdate = tick()
            return
        end
    end

    PlacementStats.failCount = PlacementStats.failCount + 1
    PlacementStats.lastUpdate = tick()
end

local function canPlaceBuilding()
    return tick() - lastPlaceBuilding >= Settings.BuildingPlaceDelay
end

local function placeBuildingAtSpot()
    if not canPlaceBuilding() then return end

    local buildingType = getSelectedBuilding()
    if not buildingType then return end

    if not cachedPlayerPlot or tick() - cachedPlotRefreshTime > 5 then
        cachedPlayerPlot = getPlayerPlot()
        cachedPlotRefreshTime = tick()
        cachedPlacedItemsRefresh = 0
        gridPositionBuildings = { row = 0, col = 0 }
    end
    if not cachedPlayerPlot then return end

    local bounds = getPlacementBounds(cachedPlayerPlot)
    if not bounds then return end

    if tick() - cachedPlacedItemsRefresh > 1 then
        cachedPlacedItems = getPlacedItems(cachedPlayerPlot)
        cachedPlacedItemsRefresh = tick()
    end

    for _ = 1, 5 do
        local relX, relZ = getGridPosition(bounds, cachedPlacedItems, gridPositionBuildings, buildingType)
        if relX then
            lastPlaceBuilding = tick()
            pcall(function()
                PlaceItem:FireServer(buildingType, relX, relZ, 0)
                table.insert(cachedPlacedItems, {position = Vector3.new((bounds.minX + bounds.maxX) / 2 + relX, bounds.topY, (bounds.minZ + bounds.maxZ) / 2 + relZ), size = ASSET_SIZES[buildingType] or Vector3.new(1,1,1)})
            end)
            return
        end
    end
end


local autobuyRocketIndex = 1
local autobuyWorkerIndex = 1

local function getNextRocket()
    local selected = {}
    for name, enabled in pairs(Settings.AutobuyRocketsList) do
        if enabled then table.insert(selected, name) end
    end
    if #selected == 0 then return nil end
    local rocket = selected[autobuyRocketIndex]
    autobuyRocketIndex = autobuyRocketIndex % #selected + 1
    return rocket
end

local function getNextWorker()
    local selected = {}
    for name, enabled in pairs(Settings.AutobuyWorkersList) do
        if enabled then table.insert(selected, name) end
    end
    if #selected == 0 then return nil end
    local worker = selected[autobuyWorkerIndex]
    autobuyWorkerIndex = autobuyWorkerIndex % #selected + 1
    return worker
end

local function autoBuy()
    if Settings.AutobuyRockets and tick() - lastRocketBuy >= Settings.BuyDelay then
        if Settings.AutobuyRocketsList and type(Settings.AutobuyRocketsList) == "table" then
            local rocket = getNextRocket()
            if rocket then
                pcall(function()
                    PurchaseItem:FireServer(rocket)
                end)
                lastRocketBuy = tick()
            end
        end
    end

    if Settings.AutobuyBuildings and Settings.AutobuyBuilding ~= "" and tick() - lastBuildingBuy >= Settings.BuyDelay then
        pcall(function()
            PurchaseItem:FireServer(Settings.AutobuyBuilding)
        end)
        lastBuildingBuy = tick()
    end

    if Settings.AutobuyWorkers and tick() - lastWorkerBuy >= Settings.BuyDelay then
        if Settings.AutobuyWorkersList and type(Settings.AutobuyWorkersList) == "table" then
            local worker = getNextWorker()
            if worker then
                pcall(function()
                    HireWorker:FireServer(worker)
                end)
                lastWorkerBuy = tick()
            end
        end
    end
end


local function queueTargets(positions)
    if not positions or #positions == 0 then return end

    for _, pos in ipairs(positions) do
        table.insert(targetQueue, pos)
    end
end

local function fireNextTarget()
    if #targetQueue == 0 then return end
    if tick() - lastFire < Settings.FireDelay then return end

    for _ = 1, math.max(1, math.floor(Settings.FireBatch or 1)) do
        if #targetQueue == 0 then break end
        local pos = table.remove(targetQueue, 1)
        lastFire = tick()

        pcall(function()
            LaunchAllMissiles:FireServer(pos)
        end)
    end
end

local function rejoinServer()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local function newServer()
    local success, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)

    if success and servers and servers.data then
        for _, server in pairs(servers.data) do
            if server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                return
            end
        end
    end

    
    TeleportService:Teleport(game.PlaceId)
end

local function joinServerWith56Players()
    local success, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)

    if success and servers and servers.data then
        for _, server in pairs(servers.data) do
            if (server.playing == 5 or server.playing == 6) and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                return
            end
        end
    end

    
    newServer()
end


local function disableAllToggles()
    Settings.LauncherEnabled = false
    Settings.AutoplaceEnabled = false
    Settings.AutoplaceBuildings = false
    Settings.AutobuyRockets = false
    Settings.AutobuyBuildings = false
    Settings.TargetPlayers = false
    targetQueue = {}
    PlacementStats.successCount = 0
    PlacementStats.failCount = 0
end


local function hasForcefield(plot)
    local forcefieldMesh = plot:FindFirstChild("forcefieldmesh", true)
    if forcefieldMesh and forcefieldMesh:IsA("BasePart") then
        return forcefieldMesh.Transparency == 0 or forcefieldMesh.CanQuery == true
    end
    return false
end

local function isOwnPlot(plot)
    local placementPart = plot:FindFirstChild("PlacementPart")
    if not placementPart then return false end

    local userInfoAttachment = placementPart:FindFirstChild("UserInfoAttachment")
    if not userInfoAttachment then return false end

    local userInfo = userInfoAttachment:FindFirstChild("UserInfo")
    if not userInfo then return false end

    local card = userInfo:FindFirstChild("Card")
    if not card then return false end

    local info = card:FindFirstChild("Info")
    if not info then return false end

    local username = info:FindFirstChild("Username")
    if not username or username.Text == "" then return false end

    return username.Text == LocalPlayer.Name or username.Text == LocalPlayer.DisplayName
end


local function getPlayerTargets()
    local targets = {}
    local currentTime = tick()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent then continue end

        local character = player.Character
        if not character or not character.Parent then continue end

        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart or not humanoidRootPart.Parent then continue end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local shieldAttack = player:GetAttribute("BaseShieldAttackCancelableExpiresAt") or 0
        local forcefield = player:GetAttribute("ForcefieldExpiresAt") or 0
        local protection = player:GetAttribute("ProtectionExpiresAt") or 0
        local newPlayer = player:GetAttribute("NewPlayerForcefieldEndsAt") or 0

        if shieldAttack > currentTime or forcefield > currentTime or protection > currentTime or newPlayer > currentTime then
            continue
        end

        table.insert(targets, humanoidRootPart.Position)
    end

    return targets
end

local cachedTargets = {}
local cachedTargetsRefresh = 0

local function scanAllTargets()
    local allTargets = {}

    local meteorVisuals = workspace:FindFirstChild("_MeteorShowerVisuals")
    local bigMeteorFound = false
    if meteorVisuals then
        local bigMeteor = meteorVisuals:FindFirstChild("BigMeteor")
        if bigMeteor and bigMeteor.Parent then
            local meteorPos = bigMeteor:IsA("BasePart") and bigMeteor.Position
                or (bigMeteor.PrimaryPart and bigMeteor.PrimaryPart.Position)
            if meteorPos then
                table.insert(allTargets, meteorPos)
                bigMeteorFound = true
            end
        end
    end

    if Settings.PrioritizeBigMeteor and bigMeteorFound then
        return allTargets
    end

    local plots = workspace:FindFirstChild("Plots")
    if plots then
        local activePlots = plots:FindFirstChild("ActivePlots")
        if activePlots then
            for _, plot in ipairs(activePlots:GetChildren()) do
                if not plot.Parent then continue end
                if hasForcefield(plot) or isOwnPlot(plot) then continue end

                local placedItems = plot:FindFirstChild("PlacedItems")
                if placedItems and #placedItems:GetChildren() > 0 then
                    for _, obj in ipairs(placedItems:GetChildren()) do
                        if not obj.Parent then continue end
                        if BUILD_SET[obj.Name] and Settings.TargetBuildings[obj.Name] then
                            local pos = nil
                            if obj:IsA("BasePart") then
                                pos = obj.Position
                            elseif obj:IsA("Model") and obj.PrimaryPart then
                                pos = obj.PrimaryPart.Position
                            end
                            if pos then
                                table.insert(allTargets, pos)
                            end
                        end
                    end
                end
            end
        end
    end

    if Settings.TargetPlayers then
        local playerTargets = getPlayerTargets()
        for _, pos in ipairs(playerTargets) do
            table.insert(allTargets, pos)
        end
    end

    return allTargets
end


Hub:Connect(RunService.Heartbeat, function()
    heartbeatCounter = heartbeatCounter + 1

    autoBuy()

    if Settings.AutoplaceEnabled then
        placeAtSpot()
    end

    if Settings.AutoplaceBuildings then
        placeBuildingAtSpot()
    end

    if Settings.LauncherEnabled then
        if #targetQueue == 0 and tick() - lastTargetScan >= 0.5 then
            lastTargetScan = tick()
            local targets = scanAllTargets()
            queueTargets(targets)
        end
        fireNextTarget()
    end
end)


local Window = WindUI:CreateWindow({
    Title = "Missile Wars",
    Icon = "bomb",
    Author = "Advanced Launcher",
    Folder = "MissileWars",
    Theme = "Dark",
    KeySystem = false,
    Size = UDim2.fromOffset(580, 460),
})

local LauncherTab = Window:Tab({ Title = "Launcher", Icon = "crosshair" })
local AutoplaceTab = Window:Tab({ Title = "Autoplace", Icon = "map-pin" })
local AutobuyTab = Window:Tab({ Title = "Autobuy", Icon = "shopping-cart" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "sliders" })
local ServerTab = Window:Tab({ Title = "Server", Icon = "globe" })


LauncherTab:Section({ Title = "Launch Control" })
LauncherTab:Toggle({ Title = "Enable Launcher", Value = false,
    Callback = function(v) Settings.LauncherEnabled = v end })
LauncherTab:Toggle({ Title = "Prioritize Big Meteor", Value = false,
    Callback = function(v) Settings.PrioritizeBigMeteor = v end })
LauncherTab:Toggle({ Title = "Target Players", Value = false,
    Callback = function(v) Settings.TargetPlayers = v end })

LauncherTab:Section({ Title = "Building Targets" })
LauncherTab:Dropdown({ Title = "Select Buildings", Multi = true, AllowNone = true,
    Values = BUILD_TYPES,
    Callback = function(sel)
        for _, name in ipairs(BUILD_TYPES) do Settings.TargetBuildings[name] = false end
        if sel and type(sel) == "table" and #sel > 0 then
            for _, name in ipairs(sel) do Settings.TargetBuildings[name] = true end
        else
            for _, name in ipairs(BUILD_TYPES) do Settings.TargetBuildings[name] = true end
        end
    end })

LauncherTab:Button({ Title = "Reset Target Cache", Icon = "refresh-cw",
    Callback = function()
        cachedPlacedItems = {}
        cachedPlacedItemsRefresh = 0
        WindUI:Notify({ Title = "Cache Reset", Content = "Cleared placement cache", Duration = 2 })
    end })


AutoplaceTab:Section({ Title = "Missiles" })
AutoplaceTab:Toggle({ Title = "Enable Missile Autoplace", Value = false,
    Callback = function(v) Settings.AutoplaceEnabled = v end })

AutoplaceTab:Dropdown({ Title = "Select Rockets", Multi = true, AllowNone = true,
    Values = ROCKET_NAMES,
    Callback = function(sel)
        for _, name in ipairs(ROCKET_NAMES) do Settings.AutoplaceRockets[name] = false end
        if sel and type(sel) == "table" and #sel > 0 then
            for _, name in ipairs(sel) do Settings.AutoplaceRockets[name] = true end
        else
            for _, name in ipairs(ROCKET_NAMES) do Settings.AutoplaceRockets[name] = true end
        end
    end })

AutoplaceTab:Section({ Title = "Buildings" })
AutoplaceTab:Toggle({ Title = "Enable Building Autoplace", Value = false,
    Callback = function(v) Settings.AutoplaceBuildings = v end })

AutoplaceTab:Dropdown({ Title = "Select Buildings", Multi = true, AllowNone = true,
    Values = BUILD_TYPES,
    Callback = function(sel)
        for _, name in ipairs(BUILD_TYPES) do Settings.AutoplaceBuildingsList[name] = false end
        if sel and type(sel) == "table" and #sel > 0 then
            for _, name in ipairs(sel) do Settings.AutoplaceBuildingsList[name] = true end
        else
            for _, name in ipairs(BUILD_TYPES) do Settings.AutoplaceBuildingsList[name] = true end
        end
    end })

AutoplaceTab:Section({ Title = "Placement Settings" })
AutoplaceTab:Slider({ Title = "Missile Place Delay", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.15 },
    Callback = function(v) Settings.PlaceDelay = v end })
AutoplaceTab:Slider({ Title = "Building Place Delay", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = 0.3 },
    Callback = function(v) Settings.BuildingPlaceDelay = v end })
AutoplaceTab:Slider({ Title = "Edge Avoidance", Step = 0.5, Value = { Min = 0, Max = 10, Default = 3 },
    Callback = function(v) Settings.EdgeAvoidance = v end })


AutobuyTab:Section({ Title = "Rockets" })
AutobuyTab:Toggle({ Title = "Autobuy Rockets", Value = false,
    Callback = function(v)
        Settings.AutobuyRockets = v
        if v then lastRocketBuy = 0 end
    end })
AutobuyTab:Dropdown({ Title = "Select Rockets", Multi = true, AllowNone = true,
    Values = ROCKET_NAMES,
    Callback = function(sel)
        for _, name in ipairs(ROCKET_NAMES) do Settings.AutobuyRocketsList[name] = false end
        if sel and type(sel) == "table" and #sel > 0 then
            for _, name in ipairs(sel) do Settings.AutobuyRocketsList[name] = true end
        else
            for _, name in ipairs(ROCKET_NAMES) do Settings.AutobuyRocketsList[name] = true end
        end
    end })

AutobuyTab:Section({ Title = "Buildings" })
AutobuyTab:Toggle({ Title = "Autobuy Buildings", Value = false,
    Callback = function(v)
        Settings.AutobuyBuildings = v
        if v then lastBuildingBuy = 0 end
    end })
AutobuyTab:Dropdown({ Title = "Building Type", Values = BUILD_TYPES,
    Callback = function(v) Settings.AutobuyBuilding = v end })

AutobuyTab:Section({ Title = "Workers" })
AutobuyTab:Toggle({ Title = "Autobuy Workers", Value = false,
    Callback = function(v)
        Settings.AutobuyWorkers = v
        if v then lastWorkerBuy = 0 end
    end })
AutobuyTab:Dropdown({ Title = "Select Workers", Multi = true, AllowNone = true,
    Values = WORKER_NAMES,
    Callback = function(sel)
        for _, name in ipairs(WORKER_NAMES) do Settings.AutobuyWorkersList[name] = false end
        if sel and type(sel) == "table" and #sel > 0 then
            for _, name in ipairs(sel) do Settings.AutobuyWorkersList[name] = true end
        else
            for _, name in ipairs(WORKER_NAMES) do Settings.AutobuyWorkersList[name] = true end
        end
    end })

AutobuyTab:Section({ Title = "Delay Settings" })
AutobuyTab:Slider({ Title = "Buy Delay", Step = 0.1, Value = { Min = 0.1, Max = 5, Default = 0.5 },
    Callback = function(v) Settings.BuyDelay = v end })


SettingsTab:Section({ Title = "Launch Settings" })
SettingsTab:Slider({ Title = "Fire Delay", Step = 0.01, Value = { Min = 0.01, Max = 0.5, Default = 0.08 },
    Callback = function(v) Settings.FireDelay = v end })
SettingsTab:Slider({ Title = "Fire Batch Size", Step = 1, Value = { Min = 1, Max = 10, Default = 1 },
    Callback = function(v) Settings.FireBatch = v end })


ServerTab:Section({ Title = "Server Control" })
ServerTab:Button({ Title = "Rejoin Current Server", Icon = "refresh-cw",
    Callback = function()
        local success, err = pcall(rejoinServer)
        if success then
            WindUI:Notify({ Title = "Rejoining...", Content = "Teleporting to same server", Duration = 2 })
        else
            WindUI:Notify({ Title = "Error", Content = "Failed to rejoin", Duration = 2 })
        end
    end })

ServerTab:Button({ Title = "Find New Server", Icon = "globe",
    Callback = function()
        local success, err = pcall(newServer)
        if success then
            WindUI:Notify({ Title = "Switching...", Content = "Finding new server", Duration = 2 })
        else
            WindUI:Notify({ Title = "Error", Content = "Failed to find server", Duration = 2 })
        end
    end })

ServerTab:Button({ Title = "Join Server (5-6 Players)", Icon = "users",
    Callback = function()
        local success, err = pcall(joinServerWith56Players)
        if success then
            WindUI:Notify({ Title = "Switching...", Content = "Finding 5-6 player server", Duration = 2 })
        else
            WindUI:Notify({ Title = "Error", Content = "Failed to find server", Duration = 2 })
        end
    end })

ServerTab:Section({ Title = "UI Control" })
ServerTab:Button({ Title = "Close UI & Disable All", Icon = "x",
    Callback = function()
        disableAllToggles()
        Window:Close()
    end })

WindUI:Notify({ Title = "Missile Wars", Content = "Advanced Combat System Ready", Duration = 3 })

end)
