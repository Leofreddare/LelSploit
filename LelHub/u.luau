local function lelHubTitle(value)
    local title = tostring(value or "")
    title = title:gsub("<[^>]*>", ""):gsub("_", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local names = {
        ["WalkSpeed"] = "Walk speed", ["Walk Speed"] = "Walk speed",
        ["JumpPower"] = "Jump power", ["NoClip"] = "Walk through walls", ["Noclip"] = "Walk through walls",
        ["Fly"] = "Player flight", ["Fly Mode"] = "Player flight", ["Fly Speed"] = "Flight speed", ["Fly speed"] = "Flight speed",
        ["Spin"] = "Spin character", ["Auto walk"] = "Walk forward automatically",
        ["Fullbright"] = "Full brightness", ["Fullbright Intensity"] = "Brightness level",
        ["Door ESP"] = "Highlight doors", ["Objective ESP"] = "Highlight objectives",
        ["Entity Highlight"] = "Highlight entities", ["Gold Highlight"] = "Highlight gold",
        ["Item Highlight"] = "Highlight items", ["Hiding ESP"] = "Highlight hiding spots",
        ["ToolShed ESP"] = "Highlight tool sheds", ["Player ESP"] = "Highlight players",
        ["Rainbow ESP"] = "Rainbow highlight colors", ["Enable Text"] = "Show highlight labels",
        ["Text Size"] = "Label text size", ["Text Offset Y"] = "Label vertical offset",
        ["Max ESP Distance"] = "Highlight distance limit", ["Anti CamShake"] = "Disable camera shake",
        ["Aura"] = "Attack nearby enemies", ["Aura mode"] = "Attack targeting mode",
        ["Aura radius"] = "Attack radius", ["Speed"] = "Enable speed override",
        ["Collect speed"] = "Food collection travel speed", ["Auto guitar"] = "Play guitar automatically",
        ["Farm wins"] = "Farm wins automatically", ["Fast parry"] = "Parry continuously",
        ["Destroy UI"] = "Unload LelHub", ["Unload"] = "Unload LelHub",
        ["Names and roles"] = "Show player labels", ["Ball ESP (Highlight)"] = "Highlight ball",
        ["Ring ESP"] = "Highlight rings", ["Master Sell Loop"] = "Sell selected items automatically",
        ["Auto Spam Spins"] = "Spin automatically", ["Remove All Knives"] = "Remove knives from plot",
        ["Include Inventory in Loop"] = "Include inventory when selling",
        ["Auto Collect GradeTokens"] = "Collect grade tokens automatically",
        ["Auto Collect Cash"] = "Collect cash automatically", ["Auto Open Ready Packs"] = "Open ready packs automatically",
    }
    return names[title] or title
end

local function installLelHubControls(library, window, configuration)
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local input = game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local tweenService = game:GetService("TweenService")
    local http = game:GetService("HttpService")
    local connections = {}
    local controls = {}
    local state = { Sprint = false, SprintSpeed = 32, AutoWalk = false, NoSit = false, Spin = false, SpinSpeed = 90, HideAccessories = false }
    local originals = setmetatable({}, { __mode = "k" })
    local accessoryParts = {}
    local sprintHumanoid
    local sprintOriginal
    local spinHumanoid
    local spinOriginal
    local spinner
    local basicFlight = {}
    local basicCollisions = {}
    local waypoints = {}
    local selectedWaypoint
    local waypointName = "Home"
    local coordinateText = ""
    local destroyed = false
    local loading = false
    local originalZoom = player.CameraMaxZoomDistance
    local originalFov
    local originalCamera
    local basicValues = {}
    local basicFlags = { Noclip = false, InfiniteJump = false, Fly = false, FlySpeed = 100 }

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
    end

    local function notify(message)
        if not destroyed then
            library:Notify({ Title = "LelHub", Content = message, Duration = 3 })
        end
    end

    local function ui(parent, kind, ...)
        local arguments = table.pack(...)
        for index = 1, arguments.n do
            local argument = arguments[index]
            if type(argument) == "table" and argument.Title then argument.Title = lelHubTitle(argument.Title) end
        end
        local method = parent["Create" .. kind] or parent["Add" .. kind] or parent[kind]
        return method(parent, table.unpack(arguments, 1, arguments.n))
    end

    local function parts()
        local character = player.Character
        return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
    end

    local function remember(humanoid, property)
        originals[humanoid] = originals[humanoid] or {}

        if originals[humanoid][property] == nil then
            originals[humanoid][property] = humanoid[property]
        end
    end

    local function register(parent, kind, id, options, callback)
        local control = ui(parent, kind, "LelShared_" .. id, options)
        controls[id] = control
        control:OnChanged(function(value)
            if not loading and not destroyed then
                callback(value)
            end
        end)
        return control
    end

    local function toggle(parent, id, title, callback)
        return register(parent, "Toggle", id, { Title = title, Default = false }, callback)
    end

    local function slider(parent, id, title, default, minimum, maximum, callback, rounding)
        return register(parent, "Slider", id, { Title = title, Default = default, Min = minimum, Max = maximum, Rounding = rounding or 0 }, function(value)
            local number = tonumber(value)

            if number and number == number and math.abs(number) ~= math.huge then
                callback(math.clamp(number, minimum, maximum))
            end
        end)
    end

    local function button(parent, title, callback)
        return ui(parent, "Button", { Title = title, Callback = function()
            local success, message = pcall(callback)

            if not success then
                notify("Could not complete that action.")
            elseif type(message) == "string" then
                notify(message)
            end
        end })
    end

    local function releaseSprint()
        if sprintHumanoid and sprintHumanoid.Parent then
            sprintHumanoid.WalkSpeed = sprintOriginal
        end

        sprintHumanoid = nil
        sprintOriginal = nil
    end

    local function releaseSpin()
        if spinner then
            spinner:Destroy()
            spinner = nil
        end

        if spinHumanoid and spinHumanoid.Parent then
            spinHumanoid.AutoRotate = spinOriginal
        end

        spinHumanoid = nil
        spinOriginal = nil
    end

    local function restoreAccessories()
        for part, transparency in pairs(accessoryParts) do
            if part.Parent then
                part.LocalTransparencyModifier = transparency
            end
        end

        accessoryParts = {}
    end

    local function stopBasicFlight()
        for _, object in pairs(basicFlight) do
            object:Destroy()
        end

        basicFlight = {}
    end

    local function restoreBasicCollisions()
        for part, value in pairs(basicCollisions) do
            if part.Parent then
                part.CanCollide = value
            end
        end

        basicCollisions = {}
    end

    local function restoreBasicMovement()
        basicValues = {}

        for humanoid, saved in pairs(originals) do
            if humanoid.Parent then
                for property, value in pairs(saved) do
                    humanoid[property] = value
                end
            end
        end

        originals = setmetatable({}, { __mode = "k" })

        if originalCamera and originalCamera.Parent and originalFov then
            originalCamera.FieldOfView = originalFov
        end
    end

    local utilityTab = configuration.PlayerTab or ui(window, "Tab", { Title = configuration.BasicMovement and "Player" or "Utilities", Icon = "user" })
    local movement = ui(utilityTab, "Section", "Movement")

    if configuration.BasicMovement then
        for _, entry in ipairs({ { "WalkSpeed", "Walk speed", 16, 16, 500 }, { "JumpPower", "Jump power", 50, 0, 500 }, { "HipHeight", "Hip height", 2, 0, 50 } }) do
            local property = entry[1]
            if not configuration.Skip or not configuration.Skip[property] then
                slider(movement, property, entry[2], entry[3], entry[4], entry[5], function(value)
                    basicValues[property] = value
                end)
            end
        end

        if not configuration.Skip or not configuration.Skip.Noclip then
        toggle(movement, "Noclip", "Noclip", function(value)
            basicFlags.Noclip = value

            if not value then
                restoreBasicCollisions()
            end
        end)
        end
        if not configuration.Skip or not configuration.Skip.InfiniteJump then
        toggle(movement, "InfiniteJump", "Infinite jump", function(value)
            basicFlags.InfiniteJump = value
        end)
        end
        toggle(movement, "Fly", "Fly", function(value)
            basicFlags.Fly = value

            if not value then
                stopBasicFlight()
            end
        end)
        slider(movement, "FlySpeed", "Fly speed", 100, 1, 500, function(value)
            basicFlags.FlySpeed = value
        end)
        slider(movement, "FOV", "Field of view", 70, 30, 120, function(value)
            local camera = workspace.CurrentCamera

            if camera then
                if not originalCamera then
                    originalCamera = camera
                    originalFov = camera.FieldOfView
                end

                camera.FieldOfView = value
            end
        end)
        button(movement, "Restore movement", restoreBasicMovement)
    end

    toggle(movement, "Sprint", "Hold Shift to sprint", function(value)
        state.Sprint = value

        if not value then
            releaseSprint()
        end
    end)
    slider(movement, "SprintSpeed", "Sprint speed", 32, 16, 500, function(value)
        state.SprintSpeed = value
    end)
    toggle(movement, "AutoWalk", "Auto walk", function(value)
        state.AutoWalk = value

        if not value then
            local _, humanoid = parts()

            if humanoid then
                humanoid:Move(Vector3.zero, false)
            end
        end
    end)
    toggle(movement, "NoSit", "Prevent sitting", function(value)
        state.NoSit = value
    end)
    toggle(movement, "Spin", "Spin", function(value)
        state.Spin = value

        if not value then
            releaseSpin()
        end
    end)
    slider(movement, "SpinSpeed", "Spin speed", 90, 0, 720, function(value)
        state.SpinSpeed = value
    end)
    button(movement, "Sit", function()
        local _, humanoid = parts()

        if humanoid then
            humanoid.Sit = true
        end
    end)
    button(movement, "Stand up", function()
        local _, humanoid = parts()

        if humanoid then
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
    button(movement, "Stop movement", function()
        local _, humanoid, root = parts()

        if humanoid then
            humanoid:Move(Vector3.zero, false)
        end

        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    local cameraSection = ui(utilityTab, "Section", "Camera and character")
    toggle(cameraSection, "HideAccessories", "Hide accessories locally", function(value)
        state.HideAccessories = value

        if not value then
            restoreAccessories()
        end
    end)
    slider(cameraSection, "Zoom", "Camera zoom distance", math.clamp(originalZoom, 1, 2000), 1, 2000, function(value)
        player.CameraMaxZoomDistance = math.max(player.CameraMinZoomDistance, value)
    end)
    button(cameraSection, "Restore camera zoom", function()
        player.CameraMaxZoomDistance = math.max(player.CameraMinZoomDistance, originalZoom)
    end)
    button(cameraSection, "Return camera to character", function()
        if configuration.StopCamera then
            configuration.StopCamera()
        end

        local camera = workspace.CurrentCamera
        local _, humanoid = parts()

        if camera and humanoid then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end

        input.MouseBehavior = Enum.MouseBehavior.Default
        input.MouseIconEnabled = true
    end)

    local places = ui(utilityTab, "Section", "Saved positions")
    register(places, "Input", "WaypointName", { Title = "Position name", Default = "Home", Finished = true }, function(value)
        waypointName = tostring(value):sub(1, 40)
    end)
    local waypointDropdown = register(places, "Dropdown", "Waypoint", { Title = "Saved position", Values = {}, Multi = false }, function(value)
        selectedWaypoint = value
    end)

    local function refreshWaypoints()
        local names = {}

        for name in pairs(waypoints) do
            table.insert(names, name)
        end

        table.sort(names)
        waypointDropdown:SetValues(names)
        waypointDropdown:SetValue(selectedWaypoint)
    end

    local function teleport(frame)
        local _, humanoid, root = parts()

        if not root then
            return "Character is not ready."
        end

        if humanoid.SeatPart then
            return "Leave your vehicle first."
        end

        root.CFrame = frame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    button(places, "Save current position", function()
        local _, _, root = parts()

        if root and waypointName:match("%S") then
            waypoints[waypointName] = root.CFrame
            selectedWaypoint = waypointName
            refreshWaypoints()
        end
    end)
    button(places, "Go to saved position", function()
        local frame = selectedWaypoint and waypoints[selectedWaypoint]

        if not frame then
            return "Select a saved position."
        end

        return teleport(frame)
    end)
    button(places, "Delete saved position", function()
        if selectedWaypoint then
            waypoints[selectedWaypoint] = nil
            selectedWaypoint = nil
            refreshWaypoints()
        end
    end)
    register(places, "Input", "Coordinates", { Title = "Coordinates", Default = "", Placeholder = "X, Y, Z", Finished = true }, function(value)
        coordinateText = tostring(value)
    end)
    button(places, "Teleport to coordinates", function()
        local values = {}

        for token in coordinateText:gmatch("[^,%s]+") do
            local number = tonumber(token)

            if not number or number ~= number or math.abs(number) == math.huge then
                return "Enter three valid coordinates."
            end

            table.insert(values, number)
        end

        if #values ~= 3 then
            return "Enter X, Y and Z."
        end

        return teleport(CFrame.new(values[1], values[2], values[3]))
    end)
    button(places, "Copy coordinates", function()
        local _, _, root = parts()

        if root and type(setclipboard) == "function" then
            setclipboard(string.format("%.2f, %.2f, %.2f", root.Position.X, root.Position.Y, root.Position.Z))
        end
    end)

    local savedLight
    local fullbright = false
    local antiIdle = false
    local selectedPlayer
    local spectating = false
    local savedSubject
    local savedCameraType
    local outlines = {}
    local outlinesEnabled = false
    local function restoreSpectate()
        if spectating then
            local camera = workspace.CurrentCamera
            local _, humanoid = parts()
            if camera then
                camera.CameraType = savedCameraType or Enum.CameraType.Custom
                camera.CameraSubject = savedSubject and savedSubject.Parent and savedSubject or humanoid
            end
        end
        spectating = false
    end
    local function restoreLight()
        if savedLight then
            local lighting = game:GetService("Lighting")
            for property, value in pairs(savedLight) do lighting[property] = value end
            savedLight = nil
        end
    end
    if configuration.BasicMovement then
        local worldControls = ui(utilityTab, "Section", "World")
        if not configuration.Skip or not configuration.Skip.Fullbright then
            toggle(worldControls, "Fullbright", "Fullbright", function(value)
                fullbright = value
                if value then
                    local lighting = game:GetService("Lighting")
                    savedLight = savedLight or { Brightness = lighting.Brightness, ClockTime = lighting.ClockTime, GlobalShadows = lighting.GlobalShadows, Ambient = lighting.Ambient }
                else restoreLight() end
            end)
        end
        if not configuration.Skip or not configuration.Skip.AntiIdle then
            toggle(worldControls, "AntiIdle", "Anti-idle", function(value) antiIdle = value end)
        end
        button(worldControls, "Give teleport tool", function()
            local backpack = player:FindFirstChildOfClass("Backpack")
            if not backpack then return "Backpack is not ready." end
            local old = backpack:FindFirstChild("LelHub Teleport") or (player.Character and player.Character:FindFirstChild("LelHub Teleport"))
            if old then old:Destroy() end
            local tool = Instance.new("Tool")
            tool.Name, tool.RequiresHandle, tool.CanBeDropped = "LelHub Teleport", false, false
            connect(tool.Activated, function()
                local _, humanoid, root = parts()
                if root and humanoid and not humanoid.SeatPart then root.CFrame = player:GetMouse().Hit + Vector3.new(0, 3, 0) end
            end)
            tool.Parent = backpack
        end)
        local playersTab = ui(window, "Tab", { Title = "Players", Icon = "users" })
        local names = { "Select a player" }
        local playerDropdown
        local function refreshPlayers(leaving)
            names = { "Select a player" }
            for _, target in ipairs(players:GetPlayers()) do
                if target ~= player and target ~= leaving then table.insert(names, target.Name) end
            end
            table.sort(names)
            if playerDropdown then playerDropdown:SetValues(names) end
        end
        refreshPlayers()
        playerDropdown = register(playersTab, "Dropdown", "TargetPlayer", { Title = "Player", Values = names, Default = "Select a player", Multi = false }, function(value)
            selectedPlayer = value ~= "Select a player" and players:FindFirstChild(value) or nil
        end)
        button(playersTab, "Teleport near player", function()
            local root = selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then return "Select an available player." end
            return teleport(root.CFrame * CFrame.new(0, 0, 4))
        end)
        button(playersTab, "Spectate player", function()
            local humanoid = selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            local camera = workspace.CurrentCamera
            if not humanoid or not camera then return "Select an available player." end
            if not spectating then savedSubject, savedCameraType = camera.CameraSubject, camera.CameraType end
            spectating = true
            camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, humanoid
        end)
        button(playersTab, "Stop spectating", restoreSpectate)
        toggle(playersTab, "PlayerOutlines", "Player outlines", function(value) outlinesEnabled = value end)
        connect(players.PlayerAdded, function() refreshPlayers() end)
        connect(players.PlayerRemoving, function(target)
            refreshPlayers(target)
            if selectedPlayer == target then restoreSpectate() selectedPlayer = nil end
            local entry = outlines[target]
            if entry then entry:Destroy() outlines[target] = nil end
        end)
        connect(player.Idled, function()
            if antiIdle then
                pcall(function()
                    local virtual = game:GetService("VirtualUser")
                    virtual:CaptureController()
                    virtual:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end)
    end
    local extrasElapsed = 0
    connect(runService.Heartbeat, function(deltaTime)
        extrasElapsed = extrasElapsed + deltaTime
        if extrasElapsed < 0.2 then return end
        extrasElapsed = 0
        if fullbright then
            local lighting = game:GetService("Lighting")
            lighting.Brightness, lighting.ClockTime, lighting.GlobalShadows, lighting.Ambient = 3, 12, false, Color3.fromRGB(210, 210, 210)
        end
        if spectating then
            local humanoid = selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            local camera = workspace.CurrentCamera
            if humanoid and camera then camera.CameraSubject = humanoid end
        end
        for _, target in ipairs(players:GetPlayers()) do
            if target ~= player then
                local character = target.Character
                local entry = outlines[target]
                if entry and (not outlinesEnabled or entry.Parent ~= character) then entry:Destroy() outlines[target] = nil entry = nil end
                if outlinesEnabled and character and not entry then
                    entry = Instance.new("Highlight")
                    entry.Name, entry.Adornee, entry.Parent = "LelHubSharedOutline", character, character
                    entry.FillTransparency = 1
                    entry.OutlineColor = Color3.fromRGB(120, 160, 255)
                    entry.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    outlines[target] = entry
                end
            end
        end
    end)

    local settingsTab = configuration.SettingsTab or ui(window, "Tab", { Title = "Settings", Icon = "settings" })
    local appearance = ui(settingsTab, "Section", "Appearance")
    register(appearance, "Dropdown", "Theme", { Title = "Theme", Values = library.Themes or { "Dark", "Light" }, Default = library.Theme or "Dark", Multi = false }, function(value)
        library:SetTheme(value)
    end)
    local menuBind = ui(appearance, "Keybind", "LelShared_MenuKey", {
        Title = "Menu key",
        Default = "RightShift",
        Mode = "Toggle",
        ChangedCallback = function(value)
            local name = typeof(value) == "EnumItem" and value.Name or tostring(value):match("([^%.]+)$")
            local success, key = pcall(function()
                return Enum.KeyCode[name]
            end)

            if success and key and name ~= "Unknown" then
                library.MinimizeKey = key
            end
        end,
    })
    library.MinimizeKey = Enum.KeyCode.RightShift
    library.MinimizeKeybind = menuBind

    local gui = Instance.new("ScreenGui")
    gui.Name = "LelHubLauncher_" .. configuration.Name
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10002
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player:WaitForChild("PlayerGui")
    local launcher = Instance.new("ImageButton")
    launcher.Name = "MenuButton"
    launcher.AnchorPoint = Vector2.new(1, 1)
    launcher.Position = UDim2.new(1, -18, 1, -18)
    launcher.Size = UDim2.fromOffset(52, 52)
    launcher.BackgroundColor3 = Color3.fromRGB(24, 27, 39)
    launcher.BackgroundTransparency = 0.08
    launcher.BorderSizePixel = 0
    launcher.Image = "rbxassetid://123368435411946"
    launcher.ScaleType = Enum.ScaleType.Fit
    launcher.AutoButtonColor = false
    launcher.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = launcher
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(112, 153, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.25
    stroke.Parent = launcher
    local launcherSize = 52
    local function hover(entered)
        tweenService:Create(launcher, TweenInfo.new(0.16), { Size = UDim2.fromOffset(launcherSize + (entered and 4 or 0), launcherSize + (entered and 4 or 0)) }):Play()
        tweenService:Create(stroke, TweenInfo.new(0.16), { Transparency = entered and 0 or 0.25 }):Play()
    end
    connect(launcher.MouseEnter, function()
        hover(true)
    end)
    connect(launcher.MouseLeave, function()
        hover(false)
    end)
    connect(launcher.Activated, function()
        window:Minimize()
    end)
    local showButton = register(appearance, "Toggle", "ShowButton", { Title = "Show menu button", Default = true }, function(value)
        launcher.Visible = value
    end)
    slider(appearance, "ButtonSize", "Menu button size", 52, 40, 72, function(value)
        launcherSize = value
        launcher.Size = UDim2.fromOffset(value, value)
    end)
    slider(appearance, "ButtonOpacity", "Menu button opacity", 0.92, 0.2, 1, function(value)
        launcher.BackgroundTransparency = 1 - value
    end, 2)
    button(appearance, "Restore menu button", function()
        launcher.Position = UDim2.new(1, -18, 1, -18)
        controls.ButtonSize:SetValue(52)
        controls.ButtonOpacity:SetValue(0.92)
        showButton:SetValue(true)
    end)

    local profiles = ui(settingsTab, "Section", "Profile")
    local profilePath = "LelHub/" .. configuration.Name .. "-profile.json"
    button(profiles, "Save settings", function()
        if not writefile or not isfolder or not makefolder then
            return "Settings files are unavailable."
        end

        if not isfolder("LelHub") then
            makefolder("LelHub")
        end

        local values = {}

        for id, control in pairs(library.Options or {}) do
            local value = control.Value

            if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
                values[id] = value
            end
        end

        writefile(profilePath, http:JSONEncode(values))
        return "Settings saved."
    end)
    button(profiles, "Load settings", function()
        if not readfile or not isfile or not isfile(profilePath) then
            return "No saved settings found."
        end

        local values = http:JSONDecode(readfile(profilePath))

        for id, value in pairs(values) do
            local control = library.Options and library.Options[id]

            if control and type(control.Value) == type(value) then
                pcall(function()
                    control:SetValue(value, control.Mode)
                end)
            end
        end

        return "Settings loaded."
    end)

    local moduleSection = ui(settingsTab, "Section", "Hubs")
    local moduleEnvironment = type(getgenv) == "function" and getgenv() or _G
    local catalog = moduleEnvironment.LelHubCatalog or {
        { Name = "Global", File = "0.luau" },
        { Name = "Universal Enhancements", File = "10.luau" },
        { Name = "Client Tools", File = "11.luau" },
    }
    local moduleNames, moduleFiles = {}, {}
    for _, entry in ipairs(catalog) do
        if not entry.PlaceId or entry.PlaceId == game.PlaceId or entry.UniverseId == game.GameId then
            table.insert(moduleNames, entry.Name)
            moduleFiles[entry.Name] = entry.File
        end
    end
    local moduleChoice = moduleNames[1]
    register(moduleSection, "Dropdown", "HubChoice", { Title = "Choose hub", Values = moduleNames, Default = moduleChoice, Multi = false }, function(value)
        moduleChoice = value
    end)
    button(moduleSection, "Open selected hub", function()
        local file = moduleFiles[moduleChoice]
        if not file then return "Select a hub first." end
        local function closeCurrent()
            if configuration.Cleanup then configuration.Cleanup()
            elseif not library.Unloaded then library:Destroy() end
        end
        local loader = moduleEnvironment.LelHubLoader
        if loader and type(loader.LoadModule) == "function" then
            loader.LoadModule(file, closeCurrent)
            return
        end
        local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/" .. file)
        local chunk, message = loadstring(source, "LelHub/" .. file)
        if not chunk then return "The selected hub could not compile." end
        closeCurrent()
        chunk()
    end)

    local function cleanup()
        if destroyed then
            return
        end

        destroyed = true

        if configuration.ShutdownLegacy then
            for id, control in pairs(library.Options or {}) do
                if not tostring(id):match("^LelShared_") and control.Type == "Toggle" and control.Value == true then
                    pcall(function()
                        control:SetValue(false)
                    end)
                end
            end
        end

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end

        releaseSprint()
        releaseSpin()
        restoreSpectate()
        restoreLight()
        for target, highlight in pairs(outlines) do highlight:Destroy() outlines[target] = nil end
        local character = player.Character
        local backpack = player:FindFirstChildOfClass("Backpack")
        local teleportTool = (character and character:FindFirstChild("LelHub Teleport")) or (backpack and backpack:FindFirstChild("LelHub Teleport"))
        if teleportTool then teleportTool:Destroy() end
        if state.AutoWalk then
            local _, humanoid = parts()

            if humanoid then
                humanoid:Move(Vector3.zero, false)
            end
        end

        restoreAccessories()
        stopBasicFlight()
        restoreBasicCollisions()
        restoreBasicMovement()
        player.CameraMaxZoomDistance = math.max(player.CameraMinZoomDistance, originalZoom)
        gui:Destroy()
    end

    button(settingsTab, "Unload LelHub", function()
        for _, control in pairs(library.Options or {}) do
            if control.Type == "Toggle" and control.Value == true then
                pcall(function()
                    control:SetValue(false)
                end)
            end
        end

        cleanup()

        if configuration.Cleanup then
            configuration.Cleanup()
        elseif not library.Unloaded then
            library:Destroy()
        end
    end)

    connect(input.JumpRequest, function()
        local _, humanoid = parts()

        if basicFlags.InfiniteJump and humanoid and not input:GetFocusedTextBox() then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    connect(player.CharacterRemoving, function()
        releaseSprint()
        releaseSpin()
        stopBasicFlight()
        restoreBasicCollisions()
        restoreAccessories()
    end)
    local accessoryElapsed = 0
    connect(runService.PreSimulation, function(deltaTime)
        if library.Unloaded then
            cleanup()
            return
        end

        local character, humanoid, root = parts()

        if not humanoid or humanoid.Health <= 0 or not root then
            releaseSprint()
            releaseSpin()
            stopBasicFlight()
            return
        end

        for property, value in pairs(basicValues) do
            remember(humanoid, property)

            if property == "JumpPower" then
                remember(humanoid, "UseJumpPower")
                humanoid.UseJumpPower = true
            end

            humanoid[property] = value
        end

        local focused = input:GetFocusedTextBox()
        local sprinting = state.Sprint and not focused and input:IsKeyDown(Enum.KeyCode.LeftShift) and not humanoid.SeatPart and not humanoid.PlatformStand

        if sprinting then
            if sprintHumanoid ~= humanoid then
                releaseSprint()
                sprintHumanoid = humanoid
                sprintOriginal = humanoid.WalkSpeed
            end

            humanoid.WalkSpeed = state.SprintSpeed
        elseif sprintHumanoid then
            releaseSprint()
        end

        if state.NoSit then
            humanoid.Sit = false
        end

        local camera = workspace.CurrentCamera

        if state.AutoWalk and camera and not focused and not humanoid.SeatPart then
            local look = camera.CFrame.LookVector
            local direction = Vector3.new(look.X, 0, look.Z)
            humanoid:Move(direction.Magnitude > 0.01 and direction.Unit or Vector3.zero, false)
        end

        if state.Spin and not humanoid.SeatPart then
            if spinHumanoid ~= humanoid then
                releaseSpin()
                spinHumanoid = humanoid
                spinOriginal = humanoid.AutoRotate
            end

            if not spinner or spinner.Parent ~= root then
                releaseSpin()
                spinHumanoid = humanoid
                spinOriginal = humanoid.AutoRotate
                spinner = Instance.new("BodyAngularVelocity")
                spinner.Name = "LelHubSpin"
                spinner.MaxTorque = Vector3.new(0, 9e9, 0)
                spinner.Parent = root
            end

            humanoid.AutoRotate = false
            spinner.AngularVelocity = Vector3.new(0, math.rad(state.SpinSpeed), 0)
        elseif spinner then
            releaseSpin()
        end

        if basicFlags.Noclip then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if basicCollisions[part] == nil then
                        basicCollisions[part] = part.CanCollide
                    end

                    part.CanCollide = false
                end
            end
        end

        if basicFlags.Fly and camera and not humanoid.SeatPart then
            if not basicFlight.Velocity or basicFlight.Velocity.Parent ~= root then
                stopBasicFlight()
                local velocity = Instance.new("BodyVelocity")
                velocity.Name = "LelHubPlayerFlight"
                velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                velocity.Parent = root
                basicFlight.Velocity = velocity
            end

            local direction = Vector3.zero

            if not focused then
                if input:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
                if input:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
                if input:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
                if input:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
                if input:IsKeyDown(Enum.KeyCode.E) or input:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.yAxis end
                if input:IsKeyDown(Enum.KeyCode.Q) or input:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.yAxis end

                if input.TouchEnabled and direction.Magnitude == 0 then
                    direction = humanoid.MoveDirection
                end
            end

            basicFlight.Velocity.Velocity = (direction.Magnitude > 1 and direction.Unit or direction) * basicFlags.FlySpeed
        elseif next(basicFlight) then
            stopBasicFlight()
        end

        accessoryElapsed = accessoryElapsed + deltaTime

        if state.HideAccessories and accessoryElapsed >= 0.25 then
            accessoryElapsed = 0

            for _, accessory in ipairs(character:GetChildren()) do
                if accessory:IsA("Accessory") then
                    for _, part in ipairs(accessory:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if accessoryParts[part] == nil then
                                accessoryParts[part] = part.LocalTransparencyModifier
                            end

                            part.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end
    end)

    if library.OnUnload then
        connect(library.OnUnload, cleanup)
    end

    return { Cleanup = cleanup, Controls = controls, Launcher = launcher, Settings = settingsTab, State = state }
end

local function createLelHub(name)
    local environment = type(getgenv) == "function" and getgenv() or _G
    environment.LelHubModules = environment.LelHubModules or {}
    local previous = environment.LelHubModules[name]
    if previous then previous.Cleanup() end
    local library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
    local window = library:CreateWindow({ Title = "LelHub " .. name, SubTitle = "by LelSploit", Size = UDim2.fromOffset(680, 470), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift })
    local hub = { Library = library, Window = window, Connections = {}, Resources = {}, Tabs = {}, Controls = {}, Stopped = false }
    local serial = 0
    function hub:Connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self.Connections, connection)
        return connection
    end
    function hub:Add(resource)
        table.insert(self.Resources, resource)
        return resource
    end
    function hub:Notify(message)
        if not self.Stopped then library:Notify({ Title = "LelHub", Content = tostring(message), Duration = 4 }) end
    end
    function hub:Tab(title, icon)
        local tab = window:CreateTab({ Title = lelHubTitle(title), Icon = icon or "grid" })
        self.Tabs[title] = tab
        return tab
    end
    function hub:Toggle(tab, id, title, callback, default)
        local raw = tab:CreateToggle(id, { Title = lelHubTitle(title), Default = default == true })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Slider(tab, id, title, default, minimum, maximum, callback, decimals)
        local raw = tab:CreateSlider(id, { Title = lelHubTitle(title), Default = default, Min = minimum, Max = maximum, Rounding = decimals or 0 })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Dropdown(tab, id, title, values, default, callback)
        local raw = tab:CreateDropdown(id, { Title = lelHubTitle(title), Values = values, Default = default, Multi = false })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Button(tab, title, callback)
        return tab:CreateButton({ Title = lelHubTitle(title), Callback = function()
            if self.Stopped then return end
            local success, message = pcall(callback)
            if not success then self:Notify("That action could not complete.") end
        end })
    end
    function hub.Cleanup()
        if hub.Stopped then return end
        hub.Stopped = true
        for _, connection in ipairs(hub.Connections) do pcall(function() connection:Disconnect() end) end
        for index = #hub.Resources, 1, -1 do
            pcall(function()
                local resource = hub.Resources[index]
                if type(resource) == "function" then resource() else resource:Destroy() end
            end)
        end
        if not library.Unloaded then library:Destroy() end
        if environment.LelHubModules[name] == hub then environment.LelHubModules[name] = nil end
    end
    function hub:Finish(configuration)
        configuration = configuration or {}
        configuration.Name = name
        configuration.BasicMovement = configuration.BasicMovement ~= false
        configuration.SettingsTab = self.Tabs.Settings
        configuration.PlayerTab = self.Tabs.Player
        configuration.Cleanup = self.Cleanup
        self.Shared = installLelHubControls(library, window, configuration)
        self:Add(self.Shared.Cleanup)
        self.Tabs.Settings = self.Shared.Settings
        if library.OnUnload then self:Connect(library.OnUnload, self.Cleanup) end
        window:SelectTab(1)
        return self
    end
    environment.LelHubModules[name] = hub
    return hub
end

local function createGameInterface(hub, style)
    local api = { Options = {}, Toggles = {}, Unloaded = false }
    api.Flags = api.Options
    local sequence = 0
    local function nextId()
        sequence = sequence + 1
        return "GameControl_" .. sequence
    end
    local function status()
        local result = {}
        for _, method in ipairs({ "Set", "SetText", "SetTitle", "SetContent", "Destroy", "Remove" }) do result[method] = function() end end
        return result
    end
    local wrap
    local function element(raw, kind, key, config)
        config = config or {}
        key = key or config.Flag or nextId()
        local title = lelHubTitle(config.Title or config.Name or config.Text or "Option")
        local default = config.Default
        if default == nil then default = config.CurrentValue end
        if default == nil then default = config.CurrentText end
        if default == nil then default = config.Value end
        local spec = { Title = title, Default = default }
        if kind == "Toggle" then spec.Default = default == true end
        if kind == "Slider" then
            local range = type(config.Value) == "table" and config.Value or {}
            spec.Min = config.Min or (config.Range and config.Range[1]) or range.Min or 0
            spec.Max = config.Max or (config.Range and config.Range[2]) or range.Max or 100
            spec.Default = tonumber(default) or range.Default or spec.Min
            if title:lower():find("walk", 1, true) then spec.Min, spec.Max = 16, 500 end
            spec.Default = math.clamp(spec.Default, spec.Min, spec.Max)
            spec.Rounding = config.Rounding or ((config.Step or config.Increment or 1) < 1 and 2 or 0)
        elseif kind == "Dropdown" then
            spec.Values = config.Values or config.Options or {}
            spec.Multi = config.Multi == true or config.MultipleOptions == true
            local current = default or config.CurrentOption
            if spec.Multi then
                spec.Default = {}
                for key, value in pairs(type(current) == "table" and current or {}) do
                    if type(key) == "number" then spec.Default[value] = true elseif value then spec.Default[key] = true end
                end
            else
                spec.Default = type(current) == "table" and current[1] or current
                if type(spec.Default) == "number" then spec.Default = spec.Values[spec.Default] end
            end
        elseif kind == "Input" then
            spec.Default = tostring(default or "")
            spec.Placeholder = config.Placeholder or config.PlaceholderText or ""
            spec.Finished = true
        elseif kind == "Colorpicker" then spec.Default = default or config.Color or Color3.new(1, 1, 1) end
        local native = raw["Create" .. kind](raw, key, spec)
        local control = { Value = spec.Default, Native = native, Callbacks = {} }
        local function valueForCallback(value)
            if kind ~= "Dropdown" then return value end
            if style == "Rayfield" then
                local selected = {}
                if spec.Multi then
                    for _, item in ipairs(spec.Values) do if value and value[item] then table.insert(selected, item) end end
                elseif value ~= nil then selected[1] = value end
                return selected
            elseif style == "WindUI" and spec.Multi then
                local selected = {}
                for _, item in ipairs(spec.Values) do if value and value[item] then table.insert(selected, item) end end
                return selected
            end
            return value
        end
        local initializing = true
        native:OnChanged(function(value)
            if hub.Stopped or api.Unloaded or (api.Controller and not api.Controller.Active) then return end
            control.Value = value
            if initializing then return end
            if config.Callback then config.Callback(valueForCallback(value)) end
            for _, callback in ipairs(control.Callbacks) do callback(value) end
        end)
        initializing = false
        function control:SetValue(value)
            if kind == "Dropdown" and type(value) == "table" and not spec.Multi then value = value[1] end
            if kind == "Colorpicker" and native.SetValueRGB then native:SetValueRGB(value) else native:SetValue(value) end
        end
        control.Set = control.SetValue
        function control:GetValue() return self.Value end
        control.Get = control.GetValue
        function control:OnChanged(callback) table.insert(self.Callbacks, callback) return self end
        function control:Refresh(values) spec.Values = values native:SetValues(values) end
        control.SetValues = control.Refresh
        function control:SetTitle(value) if native.SetTitle then native:SetTitle(value) end end
        control.SetText = control.SetTitle
        function control:AddColorPicker(id, settings) return element(raw, "Colorpicker", id, settings) end
        function control:AddKeyPicker(id, settings)
            local keybind = raw:CreateKeybind(id, { Title = settings.Text or title .. " key", Default = settings.Default or "None", Mode = settings.Mode or "Toggle", Callback = function(held)
                if settings.Mode == "Hold" then control:SetValue(held) else control:SetValue(not control.Value) end
            end })
            api.Options[id] = keybind
            return control
        end
        api.Options[key] = control
        if kind == "Toggle" then api.Toggles[key] = control end
        return control
    end
    wrap = function(raw)
        local group = { Raw = raw }
        function group:CreateSection(value) return wrap(raw:CreateSection(type(value) == "table" and (value.Title or value.Name) or value)) end
        group.Section, group.AddLeftGroupbox, group.AddRightGroupbox = group.CreateSection, group.CreateSection, group.CreateSection
        function group:AddLeftTabbox() return self end
        group.AddRightTabbox = group.AddLeftTabbox
        function group:AddTab(title) return self:CreateSection(title) end
        for _, pair in ipairs({ { "Toggle", "Toggle" }, { "Slider", "Slider" }, { "Dropdown", "Dropdown" }, { "Input", "Input" }, { "ColorPicker", "Colorpicker" } }) do
            local method, kind = pair[1], pair[2]
            group["Create" .. method] = function(_, config) return element(raw, kind, nil, config) end
            group["Add" .. method] = function(_, key, config) return element(raw, kind, key, config) end
            group[method] = group["Create" .. method]
        end
        group.AddCheckbox = group.AddToggle
        function group:CreateButton(config)
            return hub:Button(raw, config.Title or config.Name or config.Text or "Action", function()
                if api.Controller and not api.Controller.Active then return end
                local callback = config.Callback or config.Func
                if callback then callback() end
            end)
        end
        group.Button = group.CreateButton
        function group:AddButton(config, callback)
            if type(config) == "string" then config = { Text = config, Func = callback } end
            self:CreateButton(config)
            return self
        end
        function group:CreateKeybind(config)
            local key = config.CurrentKeybind or config.Default or "None"
            if typeof(key) == "EnumItem" then key = key.Name end
            local settings = { Title = config.Name or config.Title, Default = key, Mode = config.HoldToInteract and "Hold" or "Toggle" }
            if style == "Vapor" then settings.ChangedCallback = config.Callback else settings.Callback = config.Callback end
            return raw:CreateKeybind(nextId(), settings)
        end
        function group:CreateLabel(value)
            local text = type(value) == "table" and (value.Text or value.Title or value.Content) or value
            text = tostring(text or "")
            if text:lower():find("developer:", 1, true) then return status() end
            local native = raw:CreateParagraph(nextId(), { Title = "", Content = text })
            local label = { Native = native, Value = text }
            function label:Set(value)
                self.Value = tostring(type(value) == "table" and (value.Content or value.Text or value.Title or "") or value)
                native:SetValue(self.Value)
            end
            label.SetText, label.SetTitle, label.SetContent = label.Set, label.Set, label.Set
            function label:Destroy() if native.Destroy then native:Destroy() end end
            label.Remove = label.Destroy
            return label
        end
        group.AddLabel = group.CreateLabel
        for _, method in ipairs({ "CreateParagraph", "AddParagraph", "CreateDivider", "AddDivider" }) do group[method] = status end
        return group
    end
    local window = {}
    function window:CreateTab(title, icon)
        if type(title) == "table" then icon, title = title.Icon, title.Title or title.Name end
        local raw = hub.Tabs[title] or hub:Tab(title, type(icon) == "string" and icon or "grid")
        return wrap(raw)
    end
    window.Tab, window.AddTab = window.CreateTab, window.CreateTab
    function window:Destroy() hub.Cleanup() end
    window.Close = window.Destroy
    function window:CreateToggleKeybind(tab, config) return tab:CreateKeybind(config) end
    function window:CreateFloatingButton(config)
        local result = hub:Button(hub.Tabs.Game or hub:Tab("Game"), config.Text or config.Title or "Action", config.Callback or config.OnClick or config.ClickCallback)
        local instance = result and (result.Frame or result.Instance)
        if type(instance) == "table" then instance = instance.Frame end
        return { Instance = typeof(instance) == "Instance" and instance or nil, SetPosition = function() end, Destroy = function()
            if result and result.Destroy then result:Destroy() elseif typeof(instance) == "Instance" then instance:Destroy() end
        end }
    end
    function api:CreateWindow() return window end
    function api:Notify(config) hub:Notify(config.Content or config.Text or config.Title or "") end
    function api:Unload() api.Unloaded = true hub.Cleanup() end
    api.Destroy = api.Unload
    for _, method in ipairs({ "SetTheme", "LoadConfiguration", "SetLibrary", "BuildConfigSection", "ApplyToTab", "LoadAutoloadConfig", "IgnoreThemeSettings", "SetIgnoreIndexes", "SetFolder", "SetSaveFile" }) do api[method] = function() end end
    return api
end

local function installNativeUI(hub)
    local native = { Objects = {}, Roots = {}, Groups = {}, Controls = {}, Bindings = {}, Sequence = 0 }
    local gameTab = hub.Tabs.Game or hub:Tab("Game", "gamepad-2")
    local function id()
        native.Sequence = native.Sequence + 1
        return "Game_" .. native.Sequence
    end
    function native:Group(parent)
        local current = parent
        while current do
            if self.Groups[current] then return self.Groups[current] end
            current = current.Parent
        end
        return gameTab
    end
    function native:Page(parent, title)
        local frame = Instance.new("Frame")
        frame.Name, frame.Parent = title, parent
        self.Groups[frame] = hub.Tabs[title] or hub:Tab(title)
        table.insert(self.Objects, frame)
        return frame
    end
    function native:Section(parent, title)
        local frame = Instance.new("Frame")
        frame.Parent = parent
        self.Groups[frame] = self:Group(parent):CreateSection(title)
        table.insert(self.Objects, frame)
        return frame
    end
    function native:Control(parent, kind, title, default, callback, minimum, maximum)
        local group = self:Group(parent)
        local settings = { Title = lelHubTitle(title), Default = default }
        if kind == "Slider" then
            settings.Min, settings.Max, settings.Rounding = minimum, maximum, 2
            if title:lower():find("walk", 1, true) then settings.Min, settings.Max = 16, 500 end
        elseif kind == "Dropdown" then settings.Values, settings.Multi = minimum, false
        elseif kind == "Input" then settings.Finished = true end
        local control = group["Create" .. kind](group, id(), settings)
        local initializing = true
        control:OnChanged(function(value)
            if not initializing and not hub.Stopped then callback(value) end
        end)
        initializing = false
        return control
    end
    function native:Button(parent, title, callback)
        return hub:Button(self:Group(parent), title, callback)
    end
    function native:Label(parent, title, value)
        local label = Instance.new("TextLabel")
        label.Parent, label.Text = parent, value or ""
        table.insert(self.Objects, label)
        local paragraph = self:Group(parent):CreateParagraph(id(), { Title = title, Content = label.Text })
        hub:Connect(label:GetPropertyChangedSignal("Text"), function() paragraph:SetValue(label.Text) end)
        return label
    end
    local function title(object)
        local text = object:IsA("TextButton") and object.Text or object:IsA("TextBox") and object.PlaceholderText or ""
        if text == "" then
            local parent = object.Parent
            for _ = 1, 2 do
                if not parent then break end
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text ~= "" and #child.Text < 100 then text = child.Text break end
                end
                if text ~= "" then break end
                parent = parent.Parent
            end
        end
        return lelHubTitle(text ~= "" and text or object.Name)
    end
    local ignored = { X=true, ["×"]=true, ["✕"]=true, ["−"]=true, Close=true, Menu=true, Main=true, Settings=true, Credits=true, Combat=true, Movement=true, Visuals=true, Farming=true, Misc=true, Rage=true, Tracker=true, Teleports=true }
    local ignoredNames = {closebtn=true,closebutton=true,btnclose=true,hidebtn=true,openbutton=true,reopenbtn=true,mainbtn=true,trackbtn=true,telebtn=true,tabbtn=true,catbutton=true}
    function native:Bind(object, event, alias, callback)
        if type(alias) == "function" then callback, alias = alias, nil end
        local connection = hub:Connect(object[event], callback)
        local root = object:FindFirstAncestorWhichIsA("ScreenGui")
        if not root or not self.Roots[root] then return connection end
        self.Roots[root].Menu = true
        root.Enabled = false
        local bindings = self.Bindings[object] or {}
        self.Bindings[object] = bindings
        bindings[event] = bindings[event] or {}
        table.insert(bindings[event], callback)
        task.defer(function()
            if hub.Stopped or self.Controls[object] or not object.Parent then return end
            if alias and ignoredNames[alias:lower()] then return end
            local label = title(object)
            if ignored[label] then return end
            if event == "FocusLost" and object:IsA("TextBox") then
                self.Controls[object] = self:Control(object.Parent, "Input", label, object.Text, function(value)
                    object.Text = tostring(value)
                    for _, handler in ipairs(bindings.FocusLost) do handler(true) end
                end)
            elseif object:IsA("GuiButton") then
                self.Controls[object] = self:Button(object.Parent, label, function()
                    local handlers = bindings.Activated or bindings.MouseButton1Click or bindings.MouseButton1Down or {}
                    for _, handler in ipairs(handlers) do handler() end
                end)
                if object:IsA("TextButton") then hub:Connect(object:GetPropertyChangedSignal("Text"), function()
                    local control = self.Controls[object]
                    if control and control.SetTitle then control:SetTitle(title(object)) end
                end) end
            end
        end)
        return connection
    end
    native.Instance = { new = function(class, parent)
        local object = Instance.new(class, parent)
        table.insert(native.Objects, object)
        if object:IsA("ScreenGui") then
            native.Roots[object] = { Menu = false }
            hub:Connect(object:GetPropertyChangedSignal("Enabled"), function()
                if native.Roots[object].Menu and object.Enabled then object.Enabled = false end
            end)
        end
        return object
    end }
    hub:Add(function()
        for index = #native.Objects, 1, -1 do pcall(function() native.Objects[index]:Destroy() end) end
    end)
    return native
end

return function(name)
    local hub = createLelHub(name)
    hub.Native = installNativeUI(hub)
    function hub:Interface(style) return createGameInterface(self, style) end
    function hub:Input(title, default, callback)
        return self.Native:Control(nil, "Input", title, default, callback)
    end
    hub:Finish()
    return hub
end
