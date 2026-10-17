if not game:IsLoaded() then
    game.Loaded:Wait()
end

local environment = getgenv()
local previous = environment.LelHubLoader

if previous and previous.Loading then
    return
end

local session = { Loading = true }
environment.LelHubLoader = session

local baseUrl = "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/"
local supportedGames = {
    {
        Name = "99 Nights in the Forest",
        PlaceId = 79546208627805,
        UniverseId = 7326934954,
        File = "99_Nights_in_the_Forest.luau",
    },
    {
        Name = "Islands",
        PlaceId = 4872321990,
        UniverseId = 1659645941,
        File = "Islands.luau",
    },
    {
        Name = "Drive A Kukirin",
        PlaceId = 71704434889758,
        UniverseId = 10634461028,
        File = "Drive_A_Kukirin.luau",
    },
    {
        Name = "Wheelie District",
        PlaceId = 89490838554710,
        UniverseId = 9765324104,
        File = "Wheelie_District.luau",
    },
}

local function notify(message)
    task.spawn(function()
        local starterGui = game:GetService("StarterGui")

        for _ = 1, 6 do
            local success = pcall(function()
                starterGui:SetCore("SendNotification", {
                    Title = "LelHub",
                    Text = message,
                    Duration = 7,
                })
            end)

            if success then
                return
            end

            task.wait(0.5)
        end

        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

        if not playerGui then
            warn("[LelHub] " .. message)
            return
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "LelHubNotification"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 10000
        gui.Parent = playerGui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.84, 0, 0, 76)
        label.Position = UDim2.new(0.08, 0, 0, 30)
        label.BackgroundColor3 = Color3.fromRGB(23, 24, 34)
        label.TextColor3 = Color3.fromRGB(244, 245, 255)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 16
        label.TextWrapped = true
        label.Text = "LelHub\n" .. message
        label.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = label

        task.delay(7, function()
            gui:Destroy()
        end)
    end)
end

local function executeRemote(file)
    local url = baseUrl .. file
    local source
    local lastError

    for attempt = 1, 3 do
        local success, result = pcall(function()
            return game:HttpGetAsync(url)
        end)

        if success and type(result) == "string" and #result > 0 then
            source = result
            break
        end

        lastError = result

        if attempt < 3 then
            task.wait(0.35 * attempt)
        end
    end

    if not source then
        return false, "Download failed for " .. file .. ": " .. tostring(lastError)
    end

    local chunk, compileError = loadstring(source, "LelHub/" .. file)

    if not chunk then
        return false, "Invalid script in " .. file .. ": " .. tostring(compileError)
    end

    return pcall(chunk)
end

local selected

for _, entry in ipairs(supportedGames) do
    if game.PlaceId == entry.PlaceId then
        selected = entry
        break
    end
end

if not selected then
    for _, entry in ipairs(supportedGames) do
        if game.GameId == entry.UniverseId then
            selected = entry
            break
        end
    end
end

if not selected then
    notify("LelHub doesn't support this game yet. Opening LelHub Global.")
end

task.spawn(function()
    local loadedGame = selected and selected.Name or "Global"
    local success, result = executeRemote(selected and selected.File or "global.luau")

    if not success and selected then
        warn("[LelHub] " .. tostring(result))
        notify(selected.Name .. " could not load. Opening LelHub Global instead.")
        loadedGame = "Global"
        success, result = executeRemote("global.luau")
    end

    session.Loading = false
    session.Game = loadedGame
    session.Success = success

    if not success then
        warn("[LelHub] " .. tostring(result))
        notify("The script could not load. Check that its GitHub file is available, then try again.")
    end
end)
