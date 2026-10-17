if not game:IsLoaded() then game.Loaded:Wait() end

local environment = getgenv()
if environment.LelHubLoader and environment.LelHubLoader.Loading then return end

local session = { Loading = true }
environment.LelHubLoader = session

local baseUrl = "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/"
local games = {
    { Name = "99 Nights in the Forest", PlaceId = 79546208627805, UniverseId = 7326934954, File = "99_Nights_in_the_Forest.luau" },
    { Name = "Islands", PlaceId = 4872321990, UniverseId = 1659645941, File = "Islands.luau" },
    { Name = "Drive A Kukirin", PlaceId = 71704434889758, UniverseId = 10634461028, File = "Drive_A_Kukirin.luau" },
    { Name = "Wheelie District", PlaceId = 89490838554710, UniverseId = 9765324104, File = "Wheelie_District.luau" },
    { Name = "Violence District", PlaceId = 93978595733734, UniverseId = 6739698191, File = "Violence_District.luau" },
    { Name = "Loot To Forge", PlaceId = 118805555015549, UniverseId = 10684750879, File = "Loot_To_Forge.luau" },
    { Name = "Fluxo PVP", PlaceId = 99001115434148, UniverseId = 8856451375, File = "Fluxo_PVP.luau" },
    { Name = "Blade Ball", PlaceId = 13772394625, UniverseId = 4777817887, File = "Blade_Ball.luau" },
    { Name = "Murder Mystery 2", PlaceId = 142823291, UniverseId = 66654135, File = "Murder_Mystery_2.luau" },
    { Name = "Natural Disaster Survival", PlaceId = 189707, File = "Natural_Disaster_Survival.luau" },
    { Name = "Rising of Aliens", PlaceId = 99365835174711, File = "Rising_of_Aliens.luau" },
}
local catalog = {
    { Name = "Empire Clash", File = "Empire_Clash.luau", Game = true },
    { Name = "Crop Incremental", File = "Crop_Incremental.luau", Game = true },
    { Name = "Fix It Up!", File = "Fix_It_Up.luau", Game = true },
    { Name = "Forsaken", File = "Forsaken.luau", Game = true },
    { Name = "BORDER Military Roleplay", File = "BORDER_Military_Roleplay.luau", Game = true },
    { Name = "Slap Battles", File = "Slap_Battles.luau", Game = true },
    { Name = "Phonk Clicker!", File = "Phonk_Clicker.luau", Game = true },
    { Name = "THA BRONX 3", File = "THA_BRONX_3.luau", Game = true },
    { Name = "Wanted", File = "Wanted.luau", Game = true },
    { Name = "Loomian Legacy", File = "Loomian_Legacy.luau", Game = true },
    { Name = "Tsunami Game", File = "Tsunami_Game.luau", Game = true },
    { Name = "Voxels", File = "Voxels.luau", Game = true },
    { Name = "Build a Brainrot", File = "Build_a_Brainrot.luau", Game = true },
    { Name = "Survive Zombie Arena", File = "Survive_Zombie_Arena.luau", Game = true },
    { Name = "Emergency Hamburg", File = "Emergency_Hamburg.luau", Game = true },
    { Name = "Counter Blox", File = "Counter_Blox.luau", Game = true },
    { Name = "Combat Warriors", File = "Combat_Warriors.luau", Game = true },
    { Name = "Pixel Blade", File = "Pixel_Blade.luau", Game = true },
    { Name = "PLS DONATE", File = "PLS_DONATE.luau", Game = true },
    { Name = "Build A Boat For Treasure", File = "Build_A_Boat_For_Treasure.luau", Game = true },
    { Name = "Poop a Big Poop", File = "Poop_a_Big_Poop.luau", Game = true },
    { Name = "Anime Vanguards", File = "Anime_Vanguards.luau", Game = true },
    { Name = "Apocalypse Rising 2", File = "Apocalypse_Rising_2.luau", Game = true },
    { Name = "Survive Homelander", File = "Survive_Homelander.luau", Game = true },
    { Name = "My Knife Farm", File = "My_Knife_Farm.luau", Game = true },
    { Name = "Split The Sea", File = "Split_The_Sea.luau", Game = true },
    { Name = "Reign Fall", File = "Reign_Fall.luau", Game = true },
    { Name = "Build and Crash", File = "Build_and_Crash.luau", Game = true },
    { Name = "Be Dino - Jurassic Dinosaur Simulation", File = "Be_Dino_Jurassic_Dinosaur_Simulation.luau", Game = true },
    { Name = "Prison Life", File = "Prison_Life.luau", Game = true },
    { Name = "Jujutsu Shenanigans", File = "Jujutsu_Shenanigans.luau", Game = true },
    { Name = "Infinite Pizza Clicker", File = "Infinite_Pizza_Clicker.luau", Game = true },
    { Name = "Wizard Alchemy", File = "Wizard_Alchemy.luau", Game = true },
    { Name = "Death Ball", File = "Death_Ball.luau", Game = true },
    { Name = "Anime Arise Evolution", File = "Anime_Arise_Evolution.luau", Game = true },
    { Name = "DOORS", File = "DOORS.luau", Game = true },
    { Name = "Criminality", File = "Criminality.luau", Game = true },
    { Name = "Jailbird", File = "Jailbird.luau", Game = true },
    { Name = "Pool Incremental", File = "Pool_Incremental.luau", Game = true },
    { Name = "Scoped", File = "Scoped.luau", Game = true },
    { Name = "Giant Simulator", File = "Giant_Simulator.luau", Game = true },
    { Name = "Supermarket Together", File = "Supermarket_Together.luau", Game = true },
    { Name = "Infinite Nights With Freddy (DOOM)", File = "Infinite_Nights_With_Freddy_DOOM.luau", Game = true },
    { Name = "The Classic Soccer", File = "The_Classic_Soccer.luau", Game = true },
    { Name = "Become Hungry Worm", File = "Become_Hungry_Worm.luau", Game = true },
    { Name = "Clicking Simulator Ultimate", File = "Clicking_Simulator_Ultimate.luau", Game = true },
    { Name = "RIVALS", File = "RIVALS.luau", Game = true },
    { Name = "Missile Wars", File = "Missile_Wars.luau", Game = true },
    { Name = "Schedule", File = "Schedule.luau", Game = true },
    { Name = "Jailbreak", File = "Jailbreak.luau", Game = true },
    { Name = "Femboy Simulator", File = "Femboy_Simulator.luau", Game = true },
    { Name = "Fallen Survival", File = "Fallen_Survival.luau", Game = true },
    { Name = "Mad City", File = "Mad_City.luau", Game = true },
    { Name = "Steal a Kitty!", File = "Steal_a_Kitty.luau", Game = true },
    { Name = "Anime Waifu Card Collection", File = "Anime_Waifu_Card_Collection.luau", Game = true },
    { Name = "Project Delta", File = "Project_Delta.luau", Game = true },
    { Name = "+$1,000 Every Correct Glass", File = "1000_Every_Correct_Glass.luau", Game = true },
    { Name = "Soccer Zero", File = "Soccer_Zero.luau", Game = true },
    { Name = "Free Admin Troll Tower", File = "Free_Admin_Troll_Tower.luau", Game = true },
    { Name = "Sniper Arena", File = "Sniper_Arena.luau", Game = true },
    { Name = "Global", File = "global.luau" },
    { Name = "Universal Enhancements", File = "Universal_Enhancements.luau" },
    { Name = "Client Tools", File = "Client_Tools.luau" },
}
local allowedFiles = {}
for _, entry in ipairs(games) do table.insert(catalog, entry) end
for _, entry in ipairs(catalog) do allowedFiles[entry.File] = entry.Name end
environment.LelHubCatalog = catalog
local places, universes = {}, {}
for _, entry in ipairs(games) do
    if entry.PlaceId then places[entry.PlaceId] = entry end
    if entry.UniverseId then universes[entry.UniverseId] = entry end
end
local selected = places[game.PlaceId] or universes[game.GameId]
if not selected then
    local function normalize(name)
        return tostring(name):lower():gsub("%b[]", ""):gsub("%b()", ""):gsub("[^%w]", "")
    end
    local success, information = pcall(function()
        local marketplace = game:GetService("MarketplaceService")
        return marketplace:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
    end)
    if success and type(information) == "table" and type(information.Name) == "string" then
        local placeName = normalize(information.Name)
        for _, entry in ipairs(catalog) do
            if (entry.Game or entry.PlaceId) and normalize(entry.Name) == placeName then
                selected = entry
                break
            end
        end
    end
end

local function notify(message)
    task.spawn(function()
        for _ = 1, 6 do
            if pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", { Title = "LelHub", Text = message, Duration = 7 })
            end) then return end
            task.wait(0.5)
        end
        local player = game:GetService("Players").LocalPlayer
        local parent = player and player:FindFirstChildOfClass("PlayerGui")
        if not parent then return end
        local gui = Instance.new("ScreenGui")
        gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "LelHubNotification", false, 10000, parent
        local label = Instance.new("TextLabel")
        label.Size, label.Position = UDim2.new(0.84, 0, 0, 76), UDim2.new(0.08, 0, 0, 30)
        label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(23, 24, 34), Color3.fromRGB(244, 245, 255)
        label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamMedium, 16, true
        label.Text, label.Parent = "LelHub\n" .. message, gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius, corner.Parent = UDim.new(0, 12), label
        task.delay(7, function() gui:Destroy() end)
    end)
end

local function loadHub(file, beforeRun)
    local source, lastError
    for attempt = 1, 3 do
        local success, result = pcall(function() return game:HttpGetAsync(baseUrl .. file) end)
        if success and type(result) == "string" and #result > 0 then source = result break end
        lastError = result
        if attempt < 3 then task.wait(0.35 * attempt) end
    end
    if not source then return false, "Download failed for " .. file .. ": " .. tostring(lastError) end
    return pcall(function()
        local chunk, message = loadstring(source, "LelHub/" .. file)
        assert(chunk, message)
        if beforeRun then beforeRun() end
        return chunk()
    end)
end

print(("\n%s\n  LelHub  /  by LelSploit\n  %s\n  Place %s\n%s"):format(
    string.rep("─", 42), selected and selected.Name or "Global", tostring(game.PlaceId), string.rep("─", 42)
))

if not selected then notify("LelHub doesn't support this game yet. Opening LelHub Global.") end

function session.LoadModule(file, beforeRun)
    if session.Loading or not allowedFiles[file] then return false end
    session.Loading = true
    task.spawn(function()
        local name = allowedFiles[file]
        print("[LelHub] Loading " .. name .. "…")
        local success, message = loadHub(file, beforeRun)
        if not success and file ~= "global.luau" then
            warn("[LelHub] " .. tostring(message))
            notify(name .. " could not load. Opening LelHub Global instead.")
            name = "Global"
            success, message = loadHub("global.luau", beforeRun)
        end
        session.Loading, session.Game, session.Success = false, name, success
        if success then
            print("[LelHub] ✓ " .. name .. " ready. Enjoy!")
        else
            warn("[LelHub] " .. tostring(message))
            notify("The script could not load. Check that its GitHub file is available, then try again.")
        end
    end)
    return true
end

session.Loading = false
session.LoadModule(selected and selected.File or "global.luau")
