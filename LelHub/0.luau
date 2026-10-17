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
        local method = parent["Create" .. kind] or parent["Add" .. kind] or parent[kind]
        return method(parent, ...)
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

local tracebackFunction = type(debug) == "table" and type(debug.traceback) == "function" and debug.traceback or nil

local function describeError(message)
    local text = tostring(message)

    if tracebackFunction then
        local success, traceback = pcall(tracebackFunction, text, 2)

        if success and type(traceback) == "string" then
            return traceback
        end
    end

    return text
end

local function finiteNumber(value, fallback)
    local number = tonumber(value)

    if not number or number ~= number or math.abs(number) == math.huge then
        return fallback
    end

    return number
end

local function createScope()
    local scope = { Resources = {} }

    function scope:Add(resource)
        if resource then
            table.insert(self.Resources, resource)
        end

        return resource
    end

    function scope:Connect(signal, callback)
        return self:Add(signal:Connect(callback))
    end

    function scope:Spawn(callback)
        return self:Add(task.spawn(callback))
    end

    function scope:Clean()
        local resources = self.Resources
        self.Resources = {}

        for index = #resources, 1, -1 do
            local resource = resources[index]

            pcall(function()
                local kind = typeof(resource)

                if kind == "RBXScriptConnection" then
                    resource:Disconnect()
                elseif kind == "Instance" then
                    resource:Destroy()
                elseif type(resource) == "function" then
                    resource()
                elseif type(resource) == "thread" then
                    if resource ~= coroutine.running() then
                        task.cancel(resource)
                    end
                elseif type(resource) == "table" and resource.Disconnect then
                    resource:Disconnect()
                end
            end)
        end
    end

    return scope
end

local function currentCharacter(context)
    local character = context.Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local function parseKeyCode(value)
    local name = typeof(value) == "EnumItem" and value.Name or tostring(value):match("([^%.]+)$")
    local success, key = pcall(function()
        return Enum.KeyCode[name]
    end)

    if success and key and name ~= "Unknown" then
        return key, name
    end

    return nil
end

local function keyDown(context, name)
    return context.Input:IsKeyDown(Enum.KeyCode[name])
end

local function movementDirection(context, cameraFrame, humanoid)
    if context.Input:GetFocusedTextBox() then
        return Vector3.zero
    end

    local direction = Vector3.zero

    if keyDown(context, "W") then
        direction = direction + cameraFrame.LookVector
    end

    if keyDown(context, "S") then
        direction = direction - cameraFrame.LookVector
    end

    if keyDown(context, "D") then
        direction = direction + cameraFrame.RightVector
    end

    if keyDown(context, "A") then
        direction = direction - cameraFrame.RightVector
    end

    if context.Input.TouchEnabled and humanoid and direction.Magnitude == 0 then
        direction = humanoid.MoveDirection
    end

    if keyDown(context, "E") or keyDown(context, "Space") or context.TouchUp then
        direction = direction + Vector3.yAxis
    end

    if keyDown(context, "Q") or keyDown(context, "LeftShift") or keyDown(context, "LeftControl") or context.TouchDown then
        direction = direction - Vector3.yAxis
    end

    return direction.Magnitude > 1 and direction.Unit or direction
end

local function modifierFactor(rate, braking, deltaTime)
    local base = braking and math.max(0, 1 - rate / 1000) or 1 + rate / 1000
    return base ^ (math.clamp(deltaTime, 0, 0.1) * 60)
end

local function findVehicle(context)
    local character, humanoid = currentCharacter(context)
    local seat = humanoid and humanoid.SeatPart

    if not seat or not seat:IsA("BasePart") or not seat:IsDescendantOf(context.Workspace) then
        return nil
    end

    local nearestModel
    local preferredModel
    local ancestor = seat.Parent

    while ancestor and ancestor ~= context.Workspace do
        if ancestor == character then
            return nil
        end

        if ancestor:IsA("Model") then
            nearestModel = nearestModel or ancestor

            if ancestor.Name == context.Player.Name .. "'s Car" then
                preferredModel = ancestor
                break
            end

            if ancestor:FindFirstChild("Wheels") or ancestor:FindFirstChild("Chassis") or ancestor:FindFirstChild("Body") then
                preferredModel = preferredModel or ancestor
            end
        end

        if (ancestor.Name == "Body" or ancestor.Name == "Misc") and ancestor.Parent and ancestor.Parent:IsA("Model") then
            preferredModel = preferredModel or ancestor.Parent
        end

        ancestor = ancestor.Parent
    end

    local model = preferredModel or nearestModel
    local root = seat.AssemblyRootPart or seat
    return model, seat, root
end

local function createPlayerControls(context)
    local player = context.Player
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = context.Workspace.CurrentCamera
    local scope = createScope()
    local originalMovement = setmetatable({}, { __mode = "k" })
    local originalCollisions = {}
    local flightObjects = {}
    local flightState
    local teleportTool
    local originalFovs = setmetatable({}, { __mode = "k" })
    local elapsed = 0
    local destroyed = false

    local controller = {
        Values = {
            WalkSpeed = humanoid and humanoid.WalkSpeed or 16,
            JumpPower = humanoid and humanoid.JumpPower or 50,
            HipHeight = humanoid and humanoid.HipHeight or 2,
            FOV = camera and camera.FieldOfView or 70,
            FlySpeed = 100,
        },
        Overrides = {},
        InfiniteJump = false,
        Noclip = false,
        Fly = false,
        Frozen = false,
    }

    local function currentHumanoid()
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function currentRoot()
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    function controller:ApplyMovement()
        local activeHumanoid = currentHumanoid()

        if not activeHumanoid then
            return
        end

        local overrides = {}

        for property, value in pairs(self.Overrides) do
            if property ~= "FOV" then
                overrides[property] = value
            end
        end

        if self.Frozen then
            overrides.WalkSpeed = 0
            overrides.JumpPower = 0
        end

        for property, value in pairs(overrides) do
            local saved = originalMovement[activeHumanoid]

            if not saved then
                saved = {}
                originalMovement[activeHumanoid] = saved
            end

            if saved[property] == nil then
                saved[property] = activeHumanoid[property]
            end

            if property == "JumpPower" then
                if saved.UseJumpPower == nil then
                    saved.UseJumpPower = activeHumanoid.UseJumpPower
                end

                activeHumanoid.UseJumpPower = true
            end

            activeHumanoid[property] = value
        end
    end

    function controller:SetMovement(property, value)
        self.Values[property] = value

        if property == "FOV" then
            local activeCamera = context.Workspace.CurrentCamera

            if activeCamera then
                if originalFovs[activeCamera] == nil then
                    originalFovs[activeCamera] = activeCamera.FieldOfView
                end

                self.Overrides.FOV = value
                activeCamera.FieldOfView = value
            end
        else
            self.Overrides[property] = value
            self:ApplyMovement()
        end
    end

    function controller:RestoreCollisions()
        for part, canCollide in pairs(originalCollisions) do
            if part.Parent then
                part.CanCollide = canCollide
            end

            originalCollisions[part] = nil
        end
    end

    function controller:StopFlight()
        for name, object in pairs(flightObjects) do
            object:Destroy()
            flightObjects[name] = nil
        end

        if flightState and flightState.Humanoid.Parent then
            flightState.Humanoid.PlatformStand = flightState.PlatformStand
            flightState.Humanoid.AutoRotate = flightState.AutoRotate
        end

        flightState = nil
    end

    function controller:SetNoclip(enabled)
        self.Noclip = enabled

        if not enabled then
            self:RestoreCollisions()
        end
    end

    function controller:SetFly(enabled)
        self.Fly = enabled

        if not enabled then
            self:StopFlight()
        end
    end

    function controller:GiveTeleportTool()
        local backpack = player:FindFirstChildOfClass("Backpack")

        if not backpack then
            return
        end

        local previousTool = backpack:FindFirstChild("Teleport Tool")
            or (character and character:FindFirstChild("Teleport Tool"))

        if previousTool then
            previousTool:Destroy()
        end

        if teleportTool then
            teleportTool:Destroy()
        end

        local tool = Instance.new("Tool")
        tool.Name = "Teleport Tool"
        tool.RequiresHandle = false
        tool.CanBeDropped = false

        scope:Connect(tool.Activated, function()
            local target = player:GetMouse().Hit
            local root = currentRoot()

            if target and root then
                root.CFrame = target + Vector3.new(0, 3, 0)
            end
        end)

        tool.Parent = backpack
        teleportTool = tool
    end

    local function flightDirection(cameraFrame)
        return movementDirection(context, cameraFrame, currentHumanoid())
    end

    scope:Connect(context.Input.JumpRequest, function()
        local activeHumanoid = currentHumanoid()

        if controller.InfiniteJump and activeHumanoid and not context.Input:GetFocusedTextBox() then
            activeHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    scope:Connect(context.RunService.Stepped, function()
        if not controller.Noclip or not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if originalCollisions[part] == nil then
                    originalCollisions[part] = part.CanCollide
                end

                part.CanCollide = false
            end
        end
    end)

    scope:Connect(context.RunService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime

        if elapsed >= 0.2 then
            elapsed = 0
            controller:ApplyMovement()
            local activeCamera = context.Workspace.CurrentCamera

            if activeCamera and controller.Overrides.FOV then
                if originalFovs[activeCamera] == nil then
                    originalFovs[activeCamera] = activeCamera.FieldOfView
                end

                activeCamera.FieldOfView = controller.Overrides.FOV
            end
        end
    end)

    scope:Connect(context.RunService.RenderStepped, function()
        if not controller.Fly then
            return
        end

        local activeCamera = context.Workspace.CurrentCamera
        local activeHumanoid = currentHumanoid()
        local root = currentRoot()

        if not activeCamera or not activeHumanoid or not root or activeHumanoid.SeatPart or controller.Frozen or activeHumanoid.Health <= 0 then
            controller:StopFlight()
            return
        end

        if not flightObjects.Velocity or flightObjects.Velocity.Parent ~= root then
            controller:StopFlight()
            flightState = {
                Humanoid = activeHumanoid,
                PlatformStand = activeHumanoid.PlatformStand,
                AutoRotate = activeHumanoid.AutoRotate,
            }

            activeHumanoid.PlatformStand = true
            activeHumanoid.AutoRotate = false

            local velocity = Instance.new("BodyVelocity")
            velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            velocity.P = 1000
            velocity.Parent = root

            local gyro = Instance.new("BodyGyro")
            gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            gyro.P = 1000
            gyro.D = 50
            gyro.Parent = root

            flightObjects.Velocity = velocity
            flightObjects.Gyro = gyro
        end

        flightObjects.Velocity.Velocity = flightDirection(activeCamera.CFrame) * controller.Values.FlySpeed
        flightObjects.Gyro.CFrame = activeCamera.CFrame
    end)

    scope:Connect(player.CharacterRemoving, function()
        controller:RestoreCollisions()
        controller:StopFlight()
        character = nil
    end)

    scope:Connect(player.CharacterAdded, function(newCharacter)
        character = newCharacter

        scope:Spawn(function()
            newCharacter:WaitForChild("Humanoid", 10)

            if not destroyed and character == newCharacter then
                controller:ApplyMovement()
            end
        end)
    end)

    function controller:SetFrozen(enabled)
        self.Frozen = enabled

        if enabled then
            self:StopFlight()
        else
            local activeHumanoid = currentHumanoid()
            local saved = activeHumanoid and originalMovement[activeHumanoid]

            if saved then
                for property, value in pairs(saved) do
                    activeHumanoid[property] = value
                end
            end
        end

        self:ApplyMovement()
    end

    function controller:ResetMovement()
        self.Overrides = {}
        self.Frozen = false

        for activeHumanoid, saved in pairs(originalMovement) do
            if activeHumanoid.Parent then
                for property, value in pairs(saved) do
                    activeHumanoid[property] = value
                end
            end
        end

        for activeCamera, value in pairs(originalFovs) do
            if activeCamera.Parent then
                activeCamera.FieldOfView = value
            end
        end

        originalMovement = setmetatable({}, { __mode = "k" })
        originalFovs = setmetatable({}, { __mode = "k" })
    end

    function controller:Destroy()
        if destroyed then
            return
        end

        destroyed = true
        self.Fly = false
        self.Noclip = false
        self:ResetMovement()
        scope:Clean()
        self:RestoreCollisions()
        self:StopFlight()

        for activeHumanoid, saved in pairs(originalMovement) do
            if activeHumanoid.Parent then
                for property, value in pairs(saved) do
                    activeHumanoid[property] = value
                end
            end
        end

        if teleportTool then
            teleportTool:Destroy()
        end
    end

    return controller
end

local function createCameraControls(context)
    local scope = createScope()
    local saved
    local yaw = 0
    local pitch = 0
    local position
    local controller = { Mode = "None", Speed = 50, Distance = 14, Target = nil }

    local function saveCamera(camera)
        saved = {
            Camera = camera,
            Type = camera.CameraType,
            Subject = camera.CameraSubject,
            CFrame = camera.CFrame,
            Focus = camera.Focus,
            MouseBehavior = context.Input.MouseBehavior,
            MouseIconEnabled = context.Input.MouseIconEnabled,
        }
        position = camera.CFrame.Position
        pitch, yaw = camera.CFrame:ToOrientation()
    end

    function controller:Stop()
        self.Mode = "None"
        self.Target = nil

        if saved then
            local camera = saved.Camera

            pcall(function()
                camera.CameraType = saved.Type
                local _, humanoid = currentCharacter(context)
                camera.CameraSubject = saved.Subject and saved.Subject.Parent and saved.Subject or humanoid
                camera.CFrame = saved.CFrame
                camera.Focus = saved.Focus
            end)

            context.Input.MouseBehavior = saved.MouseBehavior
            context.Input.MouseIconEnabled = saved.MouseIconEnabled
            saved = nil
        end

        context.PlayerControls:SetFrozen(false)

        if self.OnChanged then
            self.OnChanged("None")
        end
    end

    function controller:Start(mode, target)
        self:Stop()
        local camera = context.Workspace.CurrentCamera

        if not camera then
            return false, "Camera is not ready yet."
        end

        if mode == "Spectate" and (not target or target == context.Player) then
            return false, "Select another player first."
        end

        saveCamera(camera)
        self.Mode = mode
        self.Target = target
        camera.CameraType = Enum.CameraType.Scriptable
        context.Input.MouseBehavior = Enum.MouseBehavior.LockCenter
        context.Input.MouseIconEnabled = false

        if mode == "Freecam" then
            context.PlayerControls:SetFrozen(true)
        end

        if self.OnChanged then
            self.OnChanged(mode)
        end

        return true, mode .. " enabled. Use the Stop camera button to exit."
    end

    local bindingName = "LelHubGlobalCamera_" .. tostring(context.Player.UserId)
    context.RunService:BindToRenderStep(bindingName, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        if controller.Mode == "None" then
            return
        end

        local camera = context.Workspace.CurrentCamera

        if not camera then
            return
        end

        if saved and camera ~= saved.Camera then
            controller:Stop()
            return
        end

        local focused = context.Input:GetFocusedTextBox()

        if not focused then
            local delta = context.Input:GetMouseDelta()
            yaw = yaw - delta.X * 0.003
            pitch = math.clamp(pitch - delta.Y * 0.003, math.rad(-80), math.rad(80))
        end

        local rotation = CFrame.fromOrientation(pitch, yaw, 0)
        camera.CameraType = Enum.CameraType.Scriptable

        if controller.Mode == "Freecam" then
            local direction = movementDirection(context, rotation)
            position = position + direction * controller.Speed * math.min(deltaTime, 0.1)
            camera.CFrame = CFrame.new(position) * rotation
            camera.Focus = camera.CFrame * CFrame.new(0, 0, -12)
        else
            local target = controller.Target

            if not target or target.Parent ~= context.Players then
                controller:Stop()
                return
            end

            local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

            if root then
                local focus = root.Position + Vector3.new(0, 3, 0)
                local orbit = focus - rotation.LookVector * controller.Distance
                camera.CFrame = CFrame.lookAt(orbit, focus)
                camera.Focus = CFrame.new(focus)
            end
        end
    end)

    scope:Add(function()
        context.RunService:UnbindFromRenderStep(bindingName)
    end)
    scope:Connect(context.Input.InputChanged, function(input, processed)
        if not processed and controller.Mode == "Spectate" and input.UserInputType == Enum.UserInputType.MouseWheel then
            controller.Distance = math.clamp(controller.Distance - input.Position.Z * 2, 3, 150)
        end
    end)
    scope:Connect(context.Player.CharacterRemoving, function()
        controller:Stop()
    end)

    function controller:Destroy()
        self:Stop()
        scope:Clean()
    end

    return controller
end

local function createWorldControls(context)
    local scope = createScope()
    local originalLighting
    local controller = { Fullbright = false, AntiIdle = false }
    local brightLighting = {
        Brightness = 3,
        ClockTime = 12,
        Ambient = Color3.fromRGB(200, 200, 200),
        OutdoorAmbient = Color3.fromRGB(200, 200, 200),
        GlobalShadows = false,
        FogEnd = 100000,
    }

    function controller:SetFullbright(enabled)
        self.Fullbright = enabled

        if enabled then
            originalLighting = originalLighting or {}

            for property, value in pairs(brightLighting) do
                if originalLighting[property] == nil then
                    originalLighting[property] = context.Lighting[property]
                end

                context.Lighting[property] = value
            end
        elseif originalLighting then
            for property, value in pairs(originalLighting) do
                context.Lighting[property] = value
            end

            originalLighting = nil
        end
    end

    local elapsed = 0
    scope:Connect(context.RunService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime

        if elapsed >= 0.5 then
            elapsed = 0

            if controller.Fullbright then
                for property, value in pairs(brightLighting) do
                    context.Lighting[property] = value
                end
            end
        end
    end)
    scope:Connect(context.Player.Idled, function()
        if controller.AntiIdle then
            local success, message = pcall(function()
                context.VirtualUser:CaptureController()
                context.VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)

            if not success then
            end
        end
    end)

    function controller:Destroy()
        self.AntiIdle = false
        self:SetFullbright(false)
        scope:Clean()
    end

    return controller
end

local function createVehicleControls(context)
    local scope = createScope()
    local springScope = createScope()
    local springs = {}
    local activeModel
    local flightRoot
    local velocity
    local gyro
    local savedPosition
    local lastError = 0
    local controller = {
        Fly = false,
        FlightMode = "Physics",
        FlySpeed = 100,
        KeybindsActive = true,
        Acceleration = 25,
        BrakeForce = 150,
        AccelerationKey = "W",
        BrakeKey = "S",
        StopKey = "P",
        SpringsVisible = nil,
        Model = nil,
        Speed = 0,
    }

    local function stopFlight()
        if velocity then
            velocity:Destroy()
        end

        if gyro then
            gyro:Destroy()
        end

        velocity = nil
        gyro = nil
        flightRoot = nil
    end

    local function restoreSprings()
        springScope:Clean()

        for spring, visible in pairs(springs) do
            if spring.Parent then
                spring.Visible = visible
            end
        end

        springs = {}
    end

    local function applySpring(spring)
        if controller.SpringsVisible == nil or not spring:IsA("SpringConstraint") then
            return
        end

        if springs[spring] == nil then
            springs[spring] = spring.Visible
        end

        spring.Visible = controller.SpringsVisible
    end

    local function watchSprings(model)
        restoreSprings()

        if model and controller.SpringsVisible ~= nil then
            for _, descendant in ipairs(model:GetDescendants()) do
                applySpring(descendant)
            end

            springScope:Connect(model.DescendantAdded, applySpring)
        end
    end

    function controller:SetSprings(value)
        self.SpringsVisible = value
        watchSprings(activeModel)
    end

    function controller:SetFly(enabled)
        self.Fly = enabled

        if not enabled then
            stopFlight()
        end
    end

    function controller:SetFlightMode(mode)
        self.FlightMode = mode
        stopFlight()
    end

    function controller:Stop()
        local _, _, root = findVehicle(context)

        if not root then
            return false, "Sit in a vehicle first."
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        if velocity then
            velocity.Velocity = Vector3.zero
        end

        return true, "Vehicle stopped."
    end

    local function positionVehicle(model, seat, target)
        model:PivotTo(target * seat.CFrame:Inverse() * model:GetPivot())
    end

    function controller:Flip()
        local model, seat = findVehicle(context)

        if not model then
            return false, "Sit in a vehicle first."
        end

        local look = seat.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)

        if forward.Magnitude < 0.01 then
            forward = Vector3.new(0, 0, -1)
        end

        local position = seat.Position + Vector3.new(0, 3, 0)
        positionVehicle(model, seat, CFrame.lookAt(position, position + forward))
        self:Stop()
        return true, "Vehicle placed upright."
    end

    function controller:SavePosition()
        local model, seat = findVehicle(context)

        if not model then
            return false, "Sit in a vehicle first."
        end

        savedPosition = seat.CFrame
        return true, "Vehicle position saved for this session."
    end

    function controller:ReturnPosition()
        local model, seat = findVehicle(context)

        if not model or not savedPosition then
            return false, "Sit in a vehicle and save a position first."
        end

        positionVehicle(model, seat, savedPosition)
        self:Stop()
        return true, "Returned to the saved position."
    end

    function controller:TeleportTo(target)
        local model, seat = findVehicle(context)
        local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

        if not model or not root then
            return false, "Sit in a vehicle and select an available player first."
        end

        positionVehicle(model, seat, root.CFrame * CFrame.new(0, 3, 12))
        self:Stop()
        return true, "Vehicle moved near " .. target.Name .. "."
    end

    scope:Connect(context.Input.InputBegan, function(input, processed)
        if not processed and controller.KeybindsActive and not context.Input:GetFocusedTextBox()
            and input.KeyCode == Enum.KeyCode[controller.StopKey] then
            controller:Stop()
        end
    end)

    local function update(deltaTime)
        local model, seat, root = findVehicle(context)

        if model ~= activeModel then
            stopFlight()
            activeModel = model
            controller.Model = model
            watchSprings(model)
        end

        controller.Speed = root and root.AssemblyLinearVelocity.Magnitude or 0

        if not root or root.Anchored then
            stopFlight()
            return
        end

        local _, humanoid = currentCharacter(context)
        local camera = context.Workspace.CurrentCamera

        if controller.Fly and camera and not context.PlayerControls.Frozen then
            local direction = movementDirection(context, camera.CFrame, humanoid)

            if controller.FlightMode == "Pivot" and model then
                stopFlight()
                local position = seat.Position + direction * controller.FlySpeed * math.min(deltaTime, 0.1)
                local target = CFrame.lookAt(position, position + camera.CFrame.LookVector)
                positionVehicle(model, seat, target)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            else
                if flightRoot ~= root or not velocity or not velocity.Parent or not gyro or not gyro.Parent then
                    stopFlight()
                    flightRoot = root
                    velocity = Instance.new("BodyVelocity")
                    velocity.Name = "LelHubVehicleVelocity"
                    velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    velocity.P = 10000
                    velocity.Velocity = Vector3.zero
                    velocity.Parent = root
                    gyro = Instance.new("BodyGyro")
                    gyro.Name = "LelHubVehicleGyro"
                    gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    gyro.P = 90000
                    gyro.D = 1000
                    gyro.CFrame = camera.CFrame
                    gyro.Parent = root
                end

                velocity.Velocity = direction * controller.FlySpeed
                gyro.CFrame = camera.CFrame
            end

            return
        end

        stopFlight()

        if not controller.KeybindsActive or context.Input:GetFocusedTextBox() then
            return
        end

        local braking = keyDown(context, controller.BrakeKey)
        local accelerating = keyDown(context, controller.AccelerationKey)

        if braking or accelerating then
            local factor = modifierFactor(braking and controller.BrakeForce or controller.Acceleration, braking, deltaTime)
            local current = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(current.X * factor, current.Y, current.Z * factor)
        end
    end

    scope:Connect(context.RunService.PreSimulation, function(deltaTime)
        local success, message = xpcall(function()
            update(deltaTime)
        end, describeError)

        if not success and os.clock() - lastError > 5 then
            lastError = os.clock()
            stopFlight()
        end
    end)

    function controller:Destroy()
        self.Fly = false
        scope:Clean()
        stopFlight()
        restoreSprings()
    end

    return controller
end

local function createOtherPlayerControls(context)
    local scope = createScope()
    local entries = {}
    local elapsed = 0
    local controller = { SelectedUserId = nil, ESP = false, Names = true, TeamColors = true }

    local function clearVisuals(entry)
        if entry.Highlight then
            entry.Highlight:Destroy()
            entry.Highlight = nil
        end

        if entry.Label then
            entry.Label:Destroy()
            entry.Label = nil
        end
    end

    local function updateVisuals(target, entry)
        local character = target.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not controller.ESP or not root then
            clearVisuals(entry)
            return
        end

        if entry.Character ~= character or not entry.Highlight or not entry.Highlight.Parent then
            clearVisuals(entry)
            entry.Character = character
            local highlight = Instance.new("Highlight")
            highlight.Name = "LelHubPlayerHighlight"
            highlight.Adornee = character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.65
            highlight.OutlineTransparency = 0
            highlight.Parent = character
            entry.Highlight = highlight

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "LelHubPlayerLabel"
            billboard.Adornee = root
            billboard.AlwaysOnTop = true
            billboard.Size = UDim2.fromOffset(240, 44)
            billboard.StudsOffset = Vector3.new(0, 3.5, 0)
            billboard.Parent = root
            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.TextSize = 14
            label.Font = Enum.Font.GothamMedium
            label.TextStrokeTransparency = 0.3
            label.Parent = billboard
            entry.Label = billboard
            entry.Text = label
        end

        local color = controller.TeamColors and not target.Neutral and target.TeamColor.Color or Color3.fromRGB(129, 237, 181)
        entry.Highlight.FillColor = color
        entry.Highlight.OutlineColor = color
        entry.Label.Enabled = controller.Names
        entry.Text.TextColor3 = color
        local _, _, localRoot = currentCharacter(context)
        local distance = localRoot and math.floor((localRoot.Position - root.Position).Magnitude) or 0
        entry.Text.Text = target.DisplayName .. " (@" .. target.Name .. ")\n" .. distance .. " studs"
    end

    local function addPlayer(target)
        if target == context.Player or entries[target] then
            return
        end

        local entry = { Scope = createScope() }
        entries[target] = entry
        entry.Scope:Connect(target.CharacterRemoving, function()
            clearVisuals(entry)
        end)
        entry.Scope:Connect(target.CharacterAdded, function()
            clearVisuals(entry)
        end)
        updateVisuals(target, entry)
    end

    function controller:GetSelected()
        return self.SelectedUserId and context.Players:GetPlayerByUserId(self.SelectedUserId) or nil
    end

    function controller:RefreshESP()
        for target, entry in pairs(entries) do
            updateVisuals(target, entry)
        end
    end

    function controller:Teleport()
        local target = self:GetSelected()
        local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local _, humanoid, root = currentCharacter(context)

        if not targetRoot or not root then
            return false, "Select an available player first."
        end

        if humanoid and humanoid.SeatPart then
            return false, "Leave your seat or use Teleport vehicle in Vehicles."
        end

        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
        root.AssemblyLinearVelocity = Vector3.zero
        return true, "Moved near " .. target.Name .. "."
    end

    for _, target in ipairs(context.Players:GetPlayers()) do
        addPlayer(target)
    end

    scope:Connect(context.Players.PlayerAdded, function(target)
        addPlayer(target)

        if controller.OnListChanged then
            controller.OnListChanged()
        end
    end)
    scope:Connect(context.Players.PlayerRemoving, function(target)
        local entry = entries[target]

        if entry then
            clearVisuals(entry)
            entry.Scope:Clean()
            entries[target] = nil
        end

        if controller.SelectedUserId == target.UserId then
            controller.SelectedUserId = nil
        end

        if context.CameraControls.Target == target then
            context.CameraControls:Stop()
        end

        if controller.OnListChanged then
            controller.OnListChanged(target)
        end
    end)
    scope:Connect(context.RunService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime

        if elapsed >= 0.2 then
            elapsed = 0
            controller:RefreshESP()
        end
    end)

    function controller:Destroy()
        scope:Clean()

        for target, entry in pairs(entries) do
            clearVisuals(entry)
            entry.Scope:Clean()
            entries[target] = nil
        end
    end

    return controller
end

local function createInterface(context, library, window, lifetime, hub)
    local playerControls = context.PlayerControls
    local cameraControls = context.CameraControls
    local otherPlayers = context.OtherPlayers
    local vehicles = context.VehicleControls
    local world = context.WorldControls
    local building = true
    local controls = {}
    local callbacks = {}
    local settings = {}
    local defaults = {}
    local tabs = {}

    local function invoke(container, kind, ...)
        local method = container["Create" .. kind] or container[kind]
        assert(type(method) == "function", "UI does not support " .. kind)
        return method(container, ...)
    end

    local function tab(title, icon)
        local result = invoke(window, "Tab", { Title = title, Icon = icon })
        tabs[title] = result
        return result
    end

    local function section(parent, title)
        return invoke(parent, "Section", title)
    end

    local function apply(id, value)
        if not building and not context.Destroying then
            local success, message = xpcall(function()
                callbacks[id](value)
            end, describeError)

            if not success then
                context.Notify("Could not apply that control.")
            end
        end
    end

    local function register(control, id, value, callback)
        controls[id] = control
        defaults[id] = value
        settings[id] = value
        callbacks[id] = callback
        control:OnChanged(function(nextValue)
            settings[id] = nextValue
            apply(id, nextValue)
        end)
        return control
    end

    local function toggle(parent, id, title, default, callback, description)
        return register(invoke(parent, "Toggle", id, {
            Title = title,
            Default = default,
        }), id, default, callback)
    end

    local function slider(parent, id, title, default, minimum, maximum, callback, rounding)
        return register(invoke(parent, "Slider", id, {
            Title = title,
            Default = default,
            Min = minimum,
            Max = maximum,
            Rounding = rounding or 0,
        }), id, default, function(value)
            callback(math.clamp(finiteNumber(value, default), minimum, maximum))
        end)
    end

    local function dropdown(parent, id, title, values, default, callback)
        return register(invoke(parent, "Dropdown", id, {
            Title = title,
            Values = values,
            Default = default,
            Multi = false,
        }), id, default, callback)
    end

    local function button(parent, title, callback, description)
        return invoke(parent, "Button", {
            Title = title,
            Callback = function()
                local success, result, message = xpcall(callback, describeError)

                if not success then
                    context.Notify("Could not complete that action.")
                elseif message then
                    context.Notify(message)
                end
            end,
        })
    end

    local function keybind(parent, id, title, default, callback)
        local control = invoke(parent, "Keybind", id, {
            Title = title,
            Default = default,
            Mode = "Hold",
            ChangedCallback = function(key)
                local keyCode, name = parseKeyCode(key)

                if keyCode then
                    settings[id] = name

                    if not building then
                        callback(name)
                    end
                end
            end,
        })
        controls[id] = control
        defaults[id] = default
        settings[id] = default
        callbacks[id] = callback
        return control
    end

    local playerTab = tab("Player", "user")
    local playersTab = tab("Players", "users")
    local cameraTab = tab("Camera", "camera")
    local worldTab = tab("World", "sun")
    local vehicleTab = tab("Vehicles", "car")
    local settingsTab = tab("Settings", "settings")

    local movement = section(playerTab, "Movement")

    for _, configuration in ipairs({
        { "WalkSpeed", "Walk speed", 16, 500 },
        { "JumpPower", "Jump power", 0, 500 },
        { "HipHeight", "Hip height", 0, 50 },
    }) do
        local property, title, minimum, maximum = table.unpack(configuration)
        slider(movement, property, title, playerControls.Values[property], minimum, maximum, function(value)
            playerControls:SetMovement(property, value)
        end)
    end

    toggle(movement, "Noclip", "Noclip", false, function(value)
        playerControls:SetNoclip(value)
    end)
    toggle(movement, "InfiniteJump", "Infinite jump", false, function(value)
        playerControls.InfiniteJump = value
    end)
    local flySection = section(playerTab, "Flight")
    local playerFly = toggle(flySection, "PlayerFly", "Fly", false, function(value)
        playerControls:SetFly(value)
    end, "WASD moves; E / Space rises; Q / Shift descends. Leave your seat to fly your character.")
    slider(flySection, "PlayerFlySpeed", "Fly speed", 100, 0, 500, function(value)
        playerControls.Values.FlySpeed = value
    end)
    local playerFlyKey = "F"
    keybind(flySection, "PlayerFlyKey", "Toggle fly key", playerFlyKey, function(value)
        playerFlyKey = value
    end)
    local utility = section(playerTab, "Tools")
    button(utility, "Give teleport tool", function()
        playerControls:GiveTeleportTool()
        return true, "Equip Teleport Tool and click a destination."
    end)
    button(utility, "Restore original movement", function()
        cameraControls:Stop()
        playerControls:ResetMovement()
        return true, "Original movement and field of view restored."
    end)

    local targetMap = {}
    local targetDropdown
    local function refreshTargets(leaving)
        local values = { "Select a player" }
        targetMap = {}

        for _, target in ipairs(context.Players:GetPlayers()) do
            if target ~= context.Player and target ~= leaving then
                local label = target.DisplayName .. " (@" .. target.Name .. ")"
                targetMap[label] = target.UserId
                table.insert(values, label)
            end
        end

        table.sort(values, function(a, b)
            if a == "Select a player" then
                return b ~= a
            elseif b == "Select a player" then
                return false
            end

            return a:lower() < b:lower()
        end)

        if targetDropdown then
            targetDropdown:SetValues(values)
            local selectedLabel = "Select a player"

            for label, userId in pairs(targetMap) do
                if userId == otherPlayers.SelectedUserId then
                    selectedLabel = label
                    break
                end
            end

            targetDropdown:SetValue(selectedLabel)
        end

        return values
    end

    local selection = section(playersTab, "Selected player")
    targetDropdown = dropdown(selection, "SelectedPlayer", "Player", refreshTargets(), "Select a player", function(value)
        otherPlayers.SelectedUserId = targetMap[value]

        if cameraControls.Mode == "Spectate" then
            local target = otherPlayers:GetSelected()

            if target then
                cameraControls.Target = target
            else
                cameraControls:Stop()
            end
        end
    end)
    otherPlayers.OnListChanged = refreshTargets
    button(selection, "Refresh players", function()
        refreshTargets()
    end)
    button(selection, "Teleport near player", function()
        return otherPlayers:Teleport()
    end)
    button(selection, "Spectate player", function()
        return cameraControls:Start("Spectate", otherPlayers:GetSelected())
    end, "Free-look orbit camera. Scroll to zoom. X stops spectating.")
    button(selection, "Stop spectating", function()
        cameraControls:Stop()
    end)
    local espSection = section(playersTab, "Player ESP")
    toggle(espSection, "PlayerESP", "Highlight other players", false, function(value)
        otherPlayers.ESP = value
        otherPlayers:RefreshESP()
    end)
    toggle(espSection, "PlayerNames", "Names and distance", true, function(value)
        otherPlayers.Names = value
        otherPlayers:RefreshESP()
    end)
    toggle(espSection, "TeamColors", "Use team colors", true, function(value)
        otherPlayers.TeamColors = value
        otherPlayers:RefreshESP()
    end)

    local cameraSection = section(cameraTab, "Camera")
    slider(cameraSection, "FOV", "Field of view", playerControls.Values.FOV, 30, 120, function(value)
        playerControls:SetMovement("FOV", value)
    end)
    button(cameraSection, "Start freecam", function()
        return cameraControls:Start("Freecam")
    end, "WASD and E / Q to move; mouse to look. Your character stays still. X exits.")
    slider(cameraSection, "FreecamSpeed", "Freecam speed", 50, 1, 500, function(value)
        cameraControls.Speed = value
    end)
    slider(cameraSection, "SpectateDistance", "Spectate distance", 14, 3, 150, function(value)
        cameraControls.Distance = value
    end)
    button(cameraSection, "Stop camera / return to character", function()
        cameraControls:Stop()
    end)

    local environmentSection = section(worldTab, "Environment")
    toggle(environmentSection, "Fullbright", "Fullbright", false, function(value)
        world:SetFullbright(value)
    end)
    toggle(environmentSection, "AntiIdle", "Anti-idle", false, function(value)
        world.AntiIdle = value
    end)

    local vehicleFlight = section(vehicleTab, "Flight")
    local vehicleFly = toggle(vehicleFlight, "VehicleFly", "Vehicle fly", false, function(value)
        vehicles:SetFly(value)
    end, "WASD moves; E / Space rises; Q / Shift descends. Remains ready when you change vehicles.")
    dropdown(vehicleFlight, "VehicleFlyMode", "Flight mode", { "Physics", "Pivot" }, "Physics", function(value)
        vehicles:SetFlightMode(value)
    end)
    slider(vehicleFlight, "VehicleFlySpeed", "Vehicle fly speed", 100, 0, 800, function(value)
        vehicles.FlySpeed = value
    end)
    local vehicleFlyKey = "V"
    keybind(vehicleFlight, "VehicleFlyKey", "Toggle vehicle fly key", vehicleFlyKey, function(value)
        vehicleFlyKey = value
    end)
    local driving = section(vehicleTab, "Speed and brakes")
    toggle(driving, "VehicleKeybinds", "Enable driving keybinds", true, function(value)
        vehicles.KeybindsActive = value
    end)
    slider(driving, "Acceleration", "Acceleration modifier", 25, 0, 50, function(value)
        vehicles.Acceleration = value
    end)
    keybind(driving, "AccelerationKey", "Acceleration key", "W", function(value)
        vehicles.AccelerationKey = value
    end)
    slider(driving, "BrakeForce", "Brake modifier", 150, 0, 300, function(value)
        vehicles.BrakeForce = value
    end)
    keybind(driving, "BrakeKey", "Quick brake key", "S", function(value)
        vehicles.BrakeKey = value
    end)
    keybind(driving, "StopKey", "Instant stop key", "P", function(value)
        vehicles.StopKey = value
    end)
    button(driving, "Stop vehicle now", function()
        return vehicles:Stop()
    end)
    local recovery = section(vehicleTab, "Appearance and recovery")
    dropdown(recovery, "Springs", "Spring visibility", { "Original", "Visible", "Hidden" }, "Original", function(value)
        if value == "Original" then
            vehicles:SetSprings(nil)
        else
            vehicles:SetSprings(value == "Visible")
        end
    end)
    button(recovery, "Flip upright", function()
        return vehicles:Flip()
    end)
    button(recovery, "Save vehicle position", function()
        return vehicles:SavePosition()
    end)
    button(recovery, "Return vehicle to saved position", function()
        return vehicles:ReturnPosition()
    end)
    button(recovery, "Teleport vehicle near selected player", function()
        return vehicles:TeleportTo(otherPlayers:GetSelected())
    end)

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "LelHubGlobalControls"
    overlay.ResetOnSpawn = false
    overlay.DisplayOrder = 10001
    overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlay.Parent = context.Player:WaitForChild("PlayerGui")
    lifetime:Add(overlay)

    local function overlayButton(text, position, size)
        local control = Instance.new("TextButton")
        control.Size = UDim2.fromOffset(size or 100, 38)
        control.Position = position
        control.AnchorPoint = Vector2.new(1, 1)
        control.BackgroundColor3 = Color3.fromRGB(31, 33, 48)
        control.TextColor3 = Color3.fromRGB(242, 244, 255)
        control.Text = text
        control.Font = Enum.Font.GothamMedium
        control.TextSize = 14
        control.AutoButtonColor = true
        control.Parent = overlay
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = control
        return control
    end

    local stopButton = overlayButton("Stop camera", UDim2.new(1, -112, 1, -18), 120)
    stopButton.Visible = false
    cameraControls.OnChanged = function(mode)
        stopButton.Visible = mode ~= "None"
    end
    lifetime:Connect(stopButton.Activated, function()
        cameraControls:Stop()
    end)

    if context.Input.TouchEnabled then
        local upButton = overlayButton("Rise", UDim2.new(1, -18, 1, -112), 70)
        local downButton = overlayButton("Descend", UDim2.new(1, -18, 1, -160), 70)
        local activeTouches = {}

        local function bindDirection(control, property)
            lifetime:Connect(control.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    activeTouches[input] = property
                    context[property] = true
                end
            end)
        end

        bindDirection(upButton, "TouchUp")
        bindDirection(downButton, "TouchDown")
        lifetime:Connect(context.Input.InputEnded, function(input)
            local property = activeTouches[input]

            if property then
                activeTouches[input] = nil
                context[property] = false

                for _, heldProperty in pairs(activeTouches) do
                    if heldProperty == property then
                        context[property] = true
                    end
                end
            end
        end)
    end

    lifetime:Connect(context.Input.InputBegan, function(input, processed)
        if processed or context.Input:GetFocusedTextBox() then
            return
        end

        if input.KeyCode == Enum.KeyCode.X then
            cameraControls:Stop()
        elseif input.KeyCode == Enum.KeyCode[playerFlyKey] then
            playerFly:SetValue(not playerControls.Fly)
        elseif input.KeyCode == Enum.KeyCode[vehicleFlyKey] then
            vehicleFly:SetValue(not vehicles.Fly)
        end
    end)
    lifetime:Connect(context.Input.WindowFocusReleased, function()
        context.TouchUp = false
        context.TouchDown = false
    end)

    building = false
    local shared = installLelHubControls(library, window, {
        Name = "global",
        SettingsTab = settingsTab,
        Cleanup = hub.Cleanup,
        StopCamera = function() cameraControls:Stop() end,
    })
    lifetime:Add(shared.Cleanup)
    hub.SharedControls = shared
    hub.Controls = controls
    hub.Tabs = tabs
    window:SelectTab(1)
end

local function launch()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local environment = type(getgenv) == "function" and getgenv() or _G
    local previous = environment.LelHubGlobal

    if previous and type(previous.Cleanup) == "function" then
        previous.Cleanup()
    end

    local libraryUrl = "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"
    local success, library = pcall(function()
        local source = game:HttpGetAsync(libraryUrl)
        local chunk, message = loadstring(source, "LelHub/Fluent")
        assert(chunk, message)
        return chunk()
    end)

    if not success or type(library) ~= "table" then
        error("[LelHub] Could not load the interface: " .. tostring(library))
    end

    local lifetime = createScope()
    local controllers = {}
    local players = game:GetService("Players")
    local context = {
        Players = players,
        Player = players.LocalPlayer,
        Workspace = game:GetService("Workspace"),
        RunService = game:GetService("RunService"),
        Input = game:GetService("UserInputService"),
        Lighting = game:GetService("Lighting"),
        VirtualUser = game:GetService("VirtualUser"),
        HttpService = game:GetService("HttpService"),
        Destroying = false,
    }
    local hub = { Library = library, Context = context }

    function hub.Cleanup()
        if context.Destroying then
            return
        end

        context.Destroying = true
        lifetime:Clean()

        for index = #controllers, 1, -1 do
            local ok, message = pcall(function()
                controllers[index]:Destroy()
            end)

            if not ok then
            end
        end

        if not library.Unloaded then
            pcall(function()
                library:Destroy()
            end)
        end

        if environment.LelHubGlobal == hub then
            environment.LelHubGlobal = nil
        end
    end

    hub.Destroy = hub.Cleanup
    environment.LelHubGlobal = hub
    context.Notify = function(message)
        if not context.Destroying then
            library:Notify({ Title = "LelHub Global", Content = message, Duration = 5 })
        end
    end

    local initialized, message = xpcall(function()
        local window = library:CreateWindow({
            Title = "LelHub Global",
            SubTitle = "by LelSploit",
            TabWidth = 150,
            Size = UDim2.fromOffset(670, 460),
            Resize = true,
            MinSize = Vector2.new(470, 360),
            Acrylic = false,
            Theme = "Dark",
            MinimizeKey = Enum.KeyCode.RightShift,
        })
        hub.Window = window

        local function controller(name, factory)
            local result = factory(context)
            context[name] = result
            hub[name] = result
            table.insert(controllers, result)
        end

        controller("PlayerControls", createPlayerControls)
        controller("CameraControls", createCameraControls)
        controller("WorldControls", createWorldControls)
        controller("VehicleControls", createVehicleControls)
        controller("OtherPlayers", createOtherPlayerControls)
        createInterface(context, library, window, lifetime, hub)

        if library.OnUnload then
            lifetime:Connect(library.OnUnload, hub.Cleanup)
        end

        lifetime:Connect(context.RunService.Heartbeat, function()
            if library.Unloaded then
                hub.Cleanup()
            end
        end)
        context.Notify("Ready. Player, camera and vehicle controls are available. Right Shift opens or hides LelHub.")
    end, describeError)

    if not initialized then
        hub.Cleanup()
        error("[LelHub] Initialization failed: " .. message)
    end

    return hub
end

return launch()
