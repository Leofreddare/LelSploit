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
}
local catalog = {
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
    places[entry.PlaceId], universes[entry.UniverseId] = entry, entry
end
local selected = places[game.PlaceId] or universes[game.GameId]

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
