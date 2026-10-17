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

local function createLelHub(name)
    local environment = type(getgenv) == "function" and getgenv() or _G
    environment.LelHubModules = environment.LelHubModules or {}
    local previous = environment.LelHubModules[name]
    if previous then previous.Cleanup() end
    local library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
    local window = library:CreateWindow({ Title = "LelHub Loot To Forge", SubTitle = "by LelSploit", Size = UDim2.fromOffset(680, 470), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift })
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
        local tab = window:CreateTab({ Title = title, Icon = icon or "grid" })
        self.Tabs[title] = tab
        return tab
    end
    function hub:Toggle(tab, id, title, callback, default)
        local raw = tab:CreateToggle(id, { Title = title, Default = default == true })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Slider(tab, id, title, default, minimum, maximum, callback, decimals)
        local raw = tab:CreateSlider(id, { Title = title, Default = default, Min = minimum, Max = maximum, Rounding = decimals or 0 })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Dropdown(tab, id, title, values, default, callback)
        local raw = tab:CreateDropdown(id, { Title = title, Values = values, Default = default, Multi = false })
        self.Controls[id] = raw
        raw:OnChanged(function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Button(tab, title, callback)
        return tab:CreateButton({ Title = title, Callback = function()
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

local function createCompatibilityLibrary(name)
    local hub = createLelHub(name)
    local api = { Options = {}, Toggles = {}, Unloaded = false, UnloadCallbacks = {}, Hub = hub }
    local sequence = 0
    local wrap
    local function id(value)
        sequence = sequence + 1
        return value or ("LelOption_" .. sequence)
    end
    local function label(content)
        local result = { Text = tostring(content or "") }
        function result:SetText(value) self.Text = tostring(value) end
        result.SetContent = result.SetText
        result.SetValue = result.SetText
        function result:SetTitle() end
        function result:Remove() end
        return result
    end
    local function widget(group, kind, key, settings)
        settings = settings or {}
        key = id(key)
        local title = settings.Text or settings.Title or key
        local options = { Title = title, Default = settings.Default }
        if kind == "Toggle" then options.Default = settings.Default == true end
        if kind == "Slider" then
            options.Min, options.Max = settings.Min or 0, settings.Max or 100
            if title:lower():find("walk", 1, true) then options.Min, options.Max = 16, 500 end
            options.Default = math.clamp(tonumber(settings.Default) or options.Min, options.Min, options.Max)
            options.Rounding = settings.Rounding or 0
        elseif kind == "Dropdown" then
            options.Values = settings.Values or {}
            options.Multi = settings.Multi == true
            if not options.Multi and type(options.Default) == "number" then options.Default = options.Values[options.Default] end
            if options.Multi then
                local selected = {}
                for k, v in pairs(type(options.Default) == "table" and options.Default or {}) do
                    if type(k) == "number" then selected[v] = true elseif v then selected[k] = true end
                end
                options.Default = selected
            end
        elseif kind == "Input" then
            options.Default = tostring(settings.Default or "")
            options.Finished = settings.Finished ~= false
            options.Placeholder = settings.Placeholder or ""
        end
        local raw = group.Raw["Create" .. kind](group.Raw, key, options)
        local control = { Raw = raw, Value = options.Default, Values = options.Values, Type = kind, Info = settings, Guards = {}, Callbacks = {}, Parent = group }
        api.Options[key] = control
        if kind == "Toggle" then api.Toggles[key] = control end
        local resetting = false
        raw:OnChanged(function(value)
            if resetting or api.Unloaded then return end
            if control.Disabled and value ~= control.Value then
                resetting = true
                raw:SetValue(control.Value)
                resetting = false
                return
            end
            for _, guard in ipairs(control.Guards) do
                if guard(value) == false then
                    resetting = true
                    raw:SetValue(control.Value)
                    resetting = false
                    return
                end
            end
            control.Value = value
            if settings.Callback then settings.Callback(value) end
            for _, callback in ipairs(control.Callbacks) do callback(value) end
        end)
        function control:SetValue(value) raw:SetValue(value) end
        function control:SetValues(values) self.Values = values raw:SetValues(values) end
        function control:OnChanged(callback) table.insert(self.Callbacks, callback) return self end
        function control:AddGuard(callback) table.insert(self.Guards, callback) return self end
        function control:SetText(text) if raw.SetTitle then raw:SetTitle(text) end end
        function control:SetImages() end
        function control:Disable() self.Disabled = true end
        function control:Enable() self.Disabled = false end
        function control:AddKeyPicker(keyId, configuration)
            local mode = configuration.Mode or "Toggle"
            local picker = group.Raw:CreateKeybind(keyId, {
                Title = configuration.Text or title .. " key",
                Default = configuration.Default == "None" and "None" or configuration.Default or "None",
                Mode = mode,
                Callback = function(held)
                    if api.Unloaded or self.Disabled then return end
                    if mode == "Hold" then self:SetValue(held == true) else self:SetValue(not self.Value) end
                end,
            })
            return self
        end
        return control
    end
    wrap = function(raw, isWindow)
        local group = { Raw = raw }
        function group:AddTab(title, icon)
            local native = hub:Tab(title, icon)
            local result = wrap(native)
            if title == "Player" then api.PlayerTab = native end
            if title == "Settings" then api.SettingsTab = native end
            return result
        end
        function group:AddTabSection() end
        function group:AddLeftGroupbox(title) return wrap(raw:CreateSection(title)) end
        group.AddRightGroupbox = group.AddLeftGroupbox
        function group:AddToggle(key, options) return widget(self, "Toggle", key, options) end
        group.AddCheckbox = group.AddToggle
        function group:AddSlider(key, options) return widget(self, "Slider", key, options) end
        function group:AddDropdown(key, options) return widget(self, "Dropdown", key, options) end
        function group:AddInput(key, options) return widget(self, "Input", key, options) end
        function group:AddDivider() return self end
        function group:AddLabel(text) return label(text) end
        function group:AddParagraph(options) return label(options.Content) end
        function group:AddButton(options)
            if type(options) == "string" then options = { Text = options } end
            raw:CreateButton({ Title = options.Text or options.Title or "Action", Callback = function()
                if not api.Unloaded then
                    local success = pcall(options.Func or options.Callback or function() end)
                    if not success then hub:Notify("That action could not complete.") end
                end
            end })
            return self
        end
        function group:AddSettingsTab()
            if not api.SettingsTab then api.SettingsTab = hub:Tab("Settings", "settings") end
            return wrap(api.SettingsTab)
        end
        function group:AddVisualsTab(configuration)
            local tab = self:AddTab("Visuals", "eye")
            local enabled = false
            local names = true
            local visuals = {}
            local elapsed = 0
            api.Visuals = { Get = function(_, key) return key == "Enabled" and enabled end }
            tab:AddToggle("LelVisualsEnabled", { Text = "Player ESP", Callback = function(value) enabled = value end })
            tab:AddToggle("LelVisualsNames", { Text = "Names and health", Default = true, Callback = function(value) names = value end })
            local function clear(model)
                local entry = visuals[model]
                if entry then entry.Highlight:Destroy() entry.Label:Destroy() visuals[model] = nil end
            end
            hub:Connect(game:GetService("RunService").Heartbeat, function(deltaTime)
                elapsed = elapsed + deltaTime
                if elapsed < 0.2 then return end
                elapsed = 0
                local seen = {}
                local success, targets = pcall(configuration.Provider)
                if enabled and success then
                    for _, target in ipairs(targets or {}) do
                        local model, root = target.Model, target.Root
                        if model and root then
                            seen[model] = true
                            local entry = visuals[model]
                            if not entry then
                                local highlight = Instance.new("Highlight")
                                highlight.Adornee, highlight.Parent = model, model
                                highlight.FillTransparency = 0.6
                                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                local billboard = Instance.new("BillboardGui")
                                billboard.Adornee, billboard.Parent = root, root
                                billboard.Size = UDim2.fromOffset(220, 30)
                                billboard.StudsOffset = Vector3.new(0, 3, 0)
                                billboard.AlwaysOnTop = true
                                local text = Instance.new("TextLabel")
                                text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
                                text.Font, text.TextSize, text.TextStrokeTransparency = Enum.Font.GothamMedium, 14, 0.4
                                text.Parent = billboard
                                entry = { Highlight = highlight, Label = billboard, Text = text }
                                visuals[model] = entry
                            end
                            local color = target.Friendly and Color3.fromRGB(100, 230, 160) or Color3.fromRGB(255, 110, 125)
                            entry.Highlight.FillColor, entry.Highlight.OutlineColor = color, color
                            entry.Label.Enabled = names
                            entry.Text.TextColor3 = color
                            entry.Text.Text = tostring(target.Name or model.Name) .. "  " .. math.floor(target.Health or 0) .. " HP"
                        end
                    end
                end
                for model in pairs(visuals) do if not seen[model] then clear(model) end end
            end)
            hub:Add(function() for model in pairs(visuals) do clear(model) end end)
            return tab
        end
        return group
    end
    function api:T(english) return english end
    function api:Notify(title, content, duration)
        hub.Library:Notify({ Title = title or "LelHub", Content = tostring(content or ""), Duration = duration or 4 })
    end
    function api:OnUnload(callback) table.insert(self.UnloadCallbacks, callback) end
    function api:Unload() hub.Cleanup() end
    function api:Every(interval, callback)
        local elapsed = 0
        return hub:Connect(game:GetService("RunService").Heartbeat, function(deltaTime)
            elapsed = elapsed + deltaTime
            if not api.Unloaded and elapsed >= interval then elapsed = 0 pcall(callback) end
        end)
    end
    function api:LoadAutoloadConfig() end
    function api:CreateWindow(options)
        self.Window = wrap(hub.Window, true)
        if options.OnUnlocked then options.OnUnlocked() end
        hub.Tabs.Settings = self.SettingsTab
        hub.Tabs.Player = self.PlayerTab
        hub:Finish({ Skip = name == "Violence_District" and { WalkSpeed = true, Noclip = true, InfiniteJump = true, Fullbright = true, AntiIdle = true } or { WalkSpeed = true } })
        return self.Window
    end
    local capabilities = {
        Connections = type(getconnections) == "function",
        Signals = type(firesignal) == "function",
        Gc = type(getgc) == "function",
        Namecall = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function",
        Hook = type(hookfunction) == "function",
        Touch = type(firetouchinterest) == "function",
        Prompt = type(fireproximityprompt) == "function",
        VirtualInput = pcall(function() return game:GetService("VirtualInputManager") end),
    }
    api.Compat = { Caps = capabilities }
    function api.Compat.Has(capability)
        for _, key in ipairs(type(capability) == "table" and capability or { capability }) do
            if not capabilities[key] then return false end
        end
        return true
    end
    function api.Compat.Block(key, reason)
        local control = type(key) == "table" and key or api.Options[key]
        if control then
            control:AddGuard(function(value)
                if value == true then hub:Notify(reason or "Unavailable on this executor.") return false end
                return true
            end)
            if control.Value == true then control:SetValue(false) end
        end
    end
    function api.Compat.NeedCap(key, capability)
        if not api.Compat.Has(capability) then api.Compat.Block(key, "Unavailable on this executor.") end
    end
    hub:Add(function()
        api.Unloaded = true
        for _, callback in ipairs(api.UnloadCallbacks) do pcall(callback) end
    end)
    return api
end


if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.GameId ~= 10684750879 then
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = "LelHub", Text = "LelHub: this script is for Loot To Forge only", Duration = 4 })
    return
end

if not LPH_OBFUSCATED then
    local function Passthrough(fn) return fn end
    LPH_JIT, LPH_JIT_MAX, LPH_NO_VIRTUALIZE = Passthrough, Passthrough, Passthrough
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local xDTaraZ = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, type(value) == "function" and LPH_JIT(value) or value)
    end,
})

xDTaraZ.Config = {
    SaveFolder = "Loot To Forge",
    UpdateLog = {
        { "2026-10-14", "Autonomous Egg2 Hatching & Auto-Incubate Watchdog\nAccurate Server Timer Sync & Zero-Crash Status UI\nTargeted Legendary Honor Hunt & Auto Egg Trimming\nFull Combat Aura, God Ore Spawning & Rebirth Farm" },
        { "2026-10-13", "Map-Wide Insane Kill Aura (SuperLoot + All Mobs + World Boss)\nInstant God Ore Spawner & Stage 27 Tier 48 farm\nFast Tower Season Coins and shop automation\nDeadlock-free cached profile & enhanced scheduler" },
    },
    UiSource = "https://raw.githubusercontent.com/xDTaraZz/Roblox-Scripts/refs/heads/main/ui.lua",
    ReloadSource = [[loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/loader.luau"))()]],
    LoadTimeout = 30,
    RemoteTimeout = 10,
    RequireTimeout = 3,
    MaxFailures = 5,
    FailWindow = 10,
    AlertTries = 20,
    AlertDelay = 0.5,
    TickDelay = 0.15,
    StatusInterval = 1.5,
    PumpInterval = 0.2,
    OwnedOresLabel = "Owned ores",
    AcquireRounds = 5,
    StoneWorkers = 16,
    StoneCallsPerWorker = 25,
    EggFarmWorkers = 16,
    EggFarmCalls = 25,
    TurboFarmWorkers = 24,
    TurboFarmCalls = 35,
    TurboBurstCount = 10000,
    PetInterval = 0.5,
    PetDeployInterval = 15,
    TowerWorkers = 16,
    CoinFarmTimeout = 600,
    TowerCallsPerWorker = 15,
    GearForgeTries = 15,
    GearEnhanceTries = 2,
    GearEnhanceWorkers = 8,
    SlotEnhanceRounds = 200,
    ClickInterval = 0.12,
    ForgeTargets = {
        { name = "Great Weapon", forgeType = "Weapon", ores = 13 },
        { name = "Katana", forgeType = "Weapon", ores = 4 },
        { name = "Armor", forgeType = "Armor", ores = 11 },
        { name = "Hat", forgeType = "Armor", ores = 4 },
    },
    GearSlots = {
        { slot = "Weapon", forgeType = "Weapon", ores = 13 },
        { slot = "Armor", forgeType = "Armor", ores = 11 },
        { slot = "Hat", forgeType = "Armor", ores = 4 },
    },
    GearTypes = { "Weapon", "Armor", "Hat" },
    EnchantPriority = { "Poison_3", "Thunder_3", "Ice_3", "Fire_3", "Poison_2", "Thunder_2", "Ice_2", "Fire_2" },
    RuneMinTier = 2,
    EnchantRefill = 50,
    ForgeCountMax = 30,
    PlanSlice = 0.004,
    HuntBatch = 40,
    HuntWorkers = 4,
    HuntMaxForges = 4000,
    HuntTargetHits = 3,
    IndexInterval = 60,
    IndexLevelClaims = 50,
    ClaimIdScan = 20,
    LookKinds = { "Ore", "EnchStone", "Weapon", "Armor", "Material", "Class", "Pet", "Egg", "Food" },
    TokenShopInterval = 60,
    ClaimInterval = 30,
    SeasonInterval = 60,
    BossCards = 8,
    BossAttackIds = { Katana = "K_ATK_1", Great = "G_ATK_1" },
    BossHitsPerTick = 30,
    BossHitGap = 0.02,
    BossJoinSettle = 1,
    BossClaimDelay = 3.5,
    BossStandHeight = 3,
    BossStandBack = 8,
    BossReach = 25,
    UpgradeInterval = 5,
    EquipInterval = 3,
    SellInterval = 1,
    RebirthInterval = 2,
    BossInterval = 1,
    BossHopInterval = 5,
    BossHopAfter = 8,
    BossLootTimeout = 30,
    BossHopFlag = "bosshop.txt",
    BossHopResume = 180,
    BossHopServers = "bossservers.json",
    HopListTtl = 120,
    HopBackoffStart = 5,
    HopBackoffMax = 60,
    HopGiveUp = 8,
    HopStall = 30,
    HopGap = 15,
    TrainRejoinDelay = 0.3,
    TrainWatchdog = 3,
    TrainAcceptWait = 1.5,
    TrainExitTries = 3,
    TrainSettle = 0.5,
    WarnCooldown = 30,
    WarnMemory = 64,
    KillAuraInterval = 0.12,
    KillDamage = 1e30,
    RaceRollDelay = 0.15,
    RaceResultWait = 2,
    RaceProtectRarity = "Mythic",
    RaceSlots = { "Equipped", "Slot 1", "Slot 2", "Slot 3" },
    RejoinDelay = 5,
    CodeReplyWait = 1.5,
    Codes = { "100000CCU", "50000CCU", "30000CCU", "20000CCU" },
    Needs = {
        AutoBattle = { "Utils.CommunicationUtils", "CTRL.EnemyCTRL", "Config.Stage.Helper" },
        AutoCheckIn = { "LocalData.PlanKData", "Remote.PlanKing_Server.TryClaimRE", "Config.PlanK.Config" },
        AutoTokenShop = { "Config.TokenShop.Config", "Remote.TokenShop_Server.OpenGoodsRE", "Remote.TokenShop_Server.ExchangeGoodsRF" },
        KillAura = { "Utils.CommunicationUtils" },
        CollectOre = { "Remote.Stage_Server.StageFinishedRF", "Remote.Stage_Server.GetOreRF", "Remote.Stage_Server.ClaimedAllOreRE", "Config.Stage.Helper", "Config.Ore.Config" },
        SuperLootAura = { "Remote.SuperLoot_Server.KillSuperLootRE", "Remote.SuperLoot_Server.RefreshSuperLootRE", "Remote.Stage_Server.GetOreRF" },
        AutoWorldBoss = { "Remote.WorldBoss_Server.IntoWorldBossFightRE", "Remote.WorldBoss_Server.ExitWorldBossFightRE", "Remote.WorldBoss_Server.BossDeadRE", "Remote.Attack_Server.UseAnyATKRE", "Remote.Attack_Server.AttackEnemyServiceRE" },
        AutoIndex = { "Remote.Forge_Server.ForgeRF", "Remote.Index_Server.TryClaimIndexExpRF", "Utils.ForgeUtils", "Config.Weapon.Config", "Config.Armor.Config" },
        MaxGear = { "Utils.BalanceUtils", "Remote.Forge_Server.ForgeRF", "Remote.Backpack_Server.EnhantEquipmentRF", "Remote.Backpack_Server.EnchantRE", "Config.Enhant.Config", "Config.EnchStone.Show" },
        AutoEquip = { "Utils.BalanceUtils", "Remote.Backpack_Server.TryEquipItemRE", "Config.Weapon.Helper", "Config.Armor.Helper" },
        AutoForge = { "Remote.Forge_Server.ForgeRF", "Remote.Backpack_Server.TrySellItemRE", "Config.Ore.Config" },
        AutoSell = { "Remote.Backpack_Server.TrySellItemRE", "Config.Weapon.Config", "Config.Armor.Config" },
        AutoTrain = { "Remote.Train_Server.IntoAutoTrainRE", "Remote.Train_Server.ExitAutoTrainRE", "Config.TrainArea.Config" },
        AutoRebirth = { "Remote.Rebirth_Server.TryRebirthRE", "Config.Rebirth.Helper" },
        AutoUpgrade = { "Remote.Upgrade_Server.UpgradeOnceRE", "Config.Upgrade.Config" },
        AutoTower = { "Remote.Dungeon_Server.TryIntoDungeonRF", "Remote.Dungeon_Server.StartRoundRE", "Remote.Dungeon_Server.CompleteRoundRF", "Config.Dungeon.Config.LootTab" },
        RaceBuyRolls = { "Config.Season.GoodsConfig", "Remote.Season_Server.ExchangeGoodsRE", "LocalData.ClassData" },
        AutoSeason = { "Remote.Season_Server.TryClaimDailyTicRE", "Remote.Season_Server.ExchangeGoodsRE", "Remote.Season_Server.LuckRE", "Config.Season.GoodsConfig" },
        AutoClaim = { "Remote.Offline_Server.TryClaimOfflineRewardRE", "Remote.Online_Server.TryClaimRE" },
        AutoRace = { "Remote.Class_Server.LuckOnceRE", "Config.Class.Config" },
        AutoBestRace = { "Remote.Class_Server.ChangeEquipedIndexRE", "Config.Class.Config" },
        AutoHatchEgg = { "Remote.Pet_Server.TryHatchEggRE", "Remote.Pet_Server.TryOpenEggRE", "Config.Egg.Config" },
        AutoEquipPet = { "Remote.Pet_Server.IsEquipPetRE", "Utils.BalanceUtils", "Config.Pet.Config" },
        AutoFeedPet = { "Remote.Pet_Server.FeedPetRE", "Config.Pet.Helper", "Config.Food.Config" },
        AutoDeployPet = { "Remote.Pet_Server.IsDeployPetRE", "Remote.Pet_Server.ClaimAllDeployRewardRE", "Config.Pet.Config" },
        AutoSellPet = { "Remote.Pet_Server.DeleteRE", "Config.Pet.Config", "Config.Egg.Config" },
        KeepOre = { "Remote.Stage_Server.LostAllOreRF" },
    },
    KaitunToggles = { "MaxGear", "AutoEquip", "AutoForge", "AutoSell", "AutoTrain", "AutoRebirth", "AutoUpgrade", "AutoClaim", "AutoCheckIn", "AutoSeason", "KillAura", "SuperLootAura", "AutoWorldBoss", "AutoTower", "GodMode", "AutoBestRace", "AutoHatchEgg", "AutoEquipPet", "AutoFeedPet", "AutoDeployPet" },
}

local Config = xDTaraZ.Config
local Remote = ReplicatedStorage:WaitForChild("Remote", Config.LoadTimeout)
local GameConfig = ReplicatedStorage:WaitForChild("Config", Config.LoadTimeout)

xDTaraZ.State = {
    Alive = true,
    Busy = false,
    Rolling = false,
    SavedSpot = nil,
    Rejoining = false,
    Lock = nil,
    LockOwner = nil,
    LockTime = 0,
    Profile = nil,
    ProfileTime = 0,
    ProfileCacheTtl = 0.35,
    Failures = {},
    Halted = {},
    InTower = false,
    Entering = false,
    GearForged = false,
    TrainArea = nil,
    TrainPending = nil,
    TrainEntering = false,
    TrainGen = 0,
    TrainFiredAt = 0,
    TrainRebirth = nil,
    BossReturn = nil,
    TrainLevel = nil,
    TrainNilSince = nil,
    Warned = {},
    WarnedCount = 0,
    LastRun = {},
    RemoteCache = {},
    JobRunning = {},
    WorkerBatches = {},
    ChildThreads = {},
    JobGroups = {},
    JobStats = {},
    ScheduleCursor = 0,
    LootPending = {},
    LootQueue = {},
    LootSeen = {},
    GearNote = nil,
    IndexNote = nil,
    TowerLoot = 0,
    OreLabels = {},
    GearLabels = {},
    SpawnLabels = {},
    BossHopping = false,
    HopFails = 0,
    HopBackoff = nil,
    HopBlockedUntil = 0,
    HopQueued = false,
    BossDone = nil,
    MissingLabels = {},
    OreStage = {},
    Plans = {},
    Runes = nil,
    Conns = {},
    AuraCursor = 0,
    Opt = {
        MaxGear = false,
        AutoEquip = false,
        EnhanceTarget = 20,
        GearForge = true,
        GearEnchant = true,
        GearEnhance = true,
        EnchantPriority = {},
        EnhanceSlot = "Weapon",
        ForgeSellJunk = false,
        ForgePerTick = 10,
        BossCards = true,
        SeasonSpin = true,
        SeasonSpinBatch = 10,
        SeasonGoods = { ["4"] = true, ["5"] = true, ["7"] = true },
        AutoBestRace = false,
        GodMode = false,
        KeepOre = false,
        CollectOre = false,
        Stage = "Stage_27",
        CollectRarities = {},
        KillAura = false,
        AutoBattle = false,
        AutoCheckIn = false,
        TokenReveal = true,
        TokenTargets = {},
        TokenSkipOwned = true,
        AuraMapWide = true,
        AuraRange = 0,
        AuraBatch = 60,
        AuraBurst = 10,
        AuraInterval = 0.12,
        AuraDamage = 1e30,
        AuraCritical = true,
        AuraSuper = true,
        AuraTarget = "All",
        AutoCollectDrops = true,
        JobTimeout = 60,
        WorkerLimit = 16,
        ParallelJobs = 4,
        SuperLootAura = true,
        AutoWorldBoss = false,
        BossHop = false,
        BossWaitMinutes = 2.5,
        AutoForge = false,
        ForgeTarget = "Great Weapon",
        ForgeOre = nil,
        ForgeRarities = {},
        KeepPerOre = 0,
        BestOreFirst = false,
        AutoSell = false,
        SellTypes = { Weapon = true, Armor = true, Hat = true },
        SellRarities = {},
        KeepPerItem = 1,
        AutoIndex = false,
        IndexTypes = { Weapon = true, Armor = true, Hat = true },
        MissingItem = nil,
        AutoTrain = false,
        AutoClick = false,
        AutoRebirth = false,
        AutoUpgrade = false,
        Upgrades = {},
        AutoClaim = false,
        AutoSeason = false,
        AutoTokenShop = false,
        AutoTower = false,
        AutoRace = false,
        RaceTargets = {},
        RaceMinLevel = nil,
        RaceStar = 0,
        RaceSlot = "Equipped",
        RaceLock = false,
        RaceProtect = false,
        RaceBuyRolls = true,
        RaceAnim = false,
        AutoHatchEgg = false,
        TargetPet = nil,
        TargetPetCopies = 1,
        AutoChaseTargetPet = false,
        AutoLockTargetPet = true,
        HatchBestFirst = true,
        SkipEggAnim = true,
        AutoEquipPet = false,
        AutoFeedPet = false,
        AutoDeployPet = false,
        AutoSellPet = false,
        DeletePetRarities = { Common = true, UnCommon = true, Rare = true },
        KeepBestPets = 6,
        AutoDeleteEggs = false,
        KeepPerEgg = 10,
        EggFarmRounds = 10,
        CoinTarget = 50000,
        SpawnItem = nil,
        SpawnAmount = 1000,
        TurboSpawn = false,
        TurboBurst = 10000,
        PotionAmount = 1000,
        SpawnGear = nil,
        GearCopies = 1,
        SpeedOn = false,
        WalkSpeed = 60,
        InfJump = false,
        AutoRejoin = false,
        LowGraphics = false,
    },
}

local State = xDTaraZ.State

xDTaraZ.GameLib = { Loaded = {}, Failed = {}, Apis = {}, Deferred = {} }


function xDTaraZ.GameLib.RequireAsGame(module)
    local done, ok, loaded = false, false, nil
    local thread = xDTaraZ.Util.Child(function()
        pcall(setthreadidentity, 2)
        local read, identity = pcall(getthreadidentity)
        if read and identity == 2 then
            ok, loaded = pcall(require, module)
        end
        done = true
    end)
    local deadline = os.clock() + Config.RequireTimeout
    while not done and os.clock() < deadline do
        task.wait()
    end
    if not done then pcall(task.cancel, thread) return false, "module require timed out" end
    return ok, loaded
end


function xDTaraZ.GameLib.Require(module)
    local cached = xDTaraZ.GameLib.Loaded[module]
    if cached ~= nil or xDTaraZ.GameLib.Failed[module] then return cached end

    local result
    local thread = xDTaraZ.Util.Child(function() result = table.pack(pcall(require, module)) end)
    local deadline = os.clock() + Config.RequireTimeout
    while not result and os.clock() < deadline do task.wait() end
    if not result then
        pcall(task.cancel, thread)
        result = { false, "module require timed out" }
    end
    local ok, loaded = result[1], result[2]
    if not ok then
        local firstErr = loaded
        ok, loaded = xDTaraZ.GameLib.RequireAsGame(module)
        if not ok then
            xDTaraZ.GameLib.Failed[module] = tostring(firstErr)
            warn("[LootToForge] require", module:GetFullName(), firstErr)
            return nil
        end
    end
    xDTaraZ.GameLib.Loaded[module] = loaded
    return loaded
end


function xDTaraZ.GameLib.CallAsGame(fn, ...)
    local args = table.pack(...)
    local box
    local thread = xDTaraZ.Util.Child(function()
        pcall(setthreadidentity, 2)
        box = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
    end)
    local deadline = os.clock() + Config.RequireTimeout
    while not box and os.clock() < deadline do
        task.wait()
    end
    if not box then pcall(task.cancel, thread) return false, "game call timed out" end
    return table.unpack(box, 1, box.n)
end


function xDTaraZ.GameLib.Call(fn, ...)
    if not xDTaraZ.GameLib.Deferred[fn] then
        local result = table.pack(pcall(fn, ...))
        if result[1] or not tostring(result[2]):find("non-RobloxScript", 1, true) then
            if not result[1] then error(result[2], 0) end
            return table.unpack(result, 2, result.n)
        end
        xDTaraZ.GameLib.Deferred[fn] = true
    end
    local result = table.pack(xDTaraZ.GameLib.CallAsGame(fn, ...))
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end


function xDTaraZ.GameLib.Api(module)
    local api = xDTaraZ.GameLib.Apis[module]
    if api then return api end
    local loaded = xDTaraZ.GameLib.Need(module)
    api = setmetatable({}, {
        __index = function(self, key)
            local value = loaded[key]
            if type(value) ~= "function" then return value end
            local wrapped = function(...)
                return xDTaraZ.GameLib.Call(value, ...)
            end
            rawset(self, key, wrapped)
            return wrapped
        end,
    })
    xDTaraZ.GameLib.Apis[module] = api
    return api
end


function xDTaraZ.GameLib.Need(module)
    local loaded = xDTaraZ.GameLib.Require(module)
    if loaded == nil then
        error(("game data %s.%s can't be read on this executor"):format(module.Parent.Name, module.Name), 0)
    end
    return loaded
end


function xDTaraZ.GameLib.Find(path)
    local node = ReplicatedStorage
    for part in path:gmatch("[^%.]+") do
        node = node and node:FindFirstChild(part)
    end
    if node then return node end
    local folder, name = path:match("^Remote%.([^%.]+)%.([^%.]+)$")
    return folder and xDTaraZ.Util.FindRemote(folder, name)
end


function xDTaraZ.GameLib.Missing()
    local missing = {}
    for idx, paths in pairs(Config.Needs) do
        for _, path in ipairs(paths) do
            if not xDTaraZ.GameLib.Find(path) then
                missing[idx] = missing[idx] or {}
                table.insert(missing[idx], path)
            end
        end
    end
    return missing
end

for _, name in ipairs({ "Util", "Data", "Stage", "Ore", "Spawn", "Potion", "Forge", "Sell", "Gear", "Index", "Level", "Upgrade", "Tower", "Boss", "Season", "Claim", "TokenShop", "Look", "SuperLoot", "Combat", "Guard", "Race", "Pet", "Movement", "Session", "Scheduler" }) do
    xDTaraZ[name] = {}
end


function xDTaraZ.Util.FindRemote(folder, name)
    if not Remote then return nil end
    local key = folder .. "." .. name
    local cached = State.RemoteCache[key]
    if cached and cached:IsDescendantOf(Remote) then return cached end
    State.RemoteCache[key] = nil

    local directFolder = Remote:FindFirstChild(folder .. "_Server") or Remote:FindFirstChild(folder)
    if directFolder then
        local remote = directFolder:FindFirstChild(name)
        if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
            State.RemoteCache[key] = remote
            return remote
        end
    end

    for _, descendant in ipairs(Remote:GetDescendants()) do
        if descendant.Name == name and (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) then
            local parentName = descendant.Parent and descendant.Parent.Name or ""
            if parentName:find("^" .. folder) then
                State.RemoteCache[key] = descendant
                return descendant
            end
        end
    end

    for _, descendant in ipairs(Remote:GetDescendants()) do
        if descendant.Name == name and (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) then
            State.RemoteCache[key] = descendant
            return descendant
        end
    end

    return nil
end


function xDTaraZ.Util.Remote(folder, name)
    local remote = xDTaraZ.Util.FindRemote(folder, name)
    if remote then return remote end

    local holder = Remote and (Remote:FindFirstChild(folder .. "_Server") or Remote:WaitForChild(folder, Config.RemoteTimeout))
    remote = holder and holder:WaitForChild(name, Config.RemoteTimeout) or xDTaraZ.Util.FindRemote(folder, name)
    if not remote then error(("remote %s.%s not found"):format(folder, name), 0) end
    return remote
end


function xDTaraZ.Util.HttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end

    local send = request or http_request or (syn and syn.request) or (http and http.request)
    if not send then return nil, tostring(body) end
    local sent, response = pcall(send, { Url = url, Method = "GET" })
    if not sent then return nil, tostring(response) end
    if type(response) ~= "table" or response.StatusCode ~= 200 or type(response.Body) ~= "string" then
        return nil, "HTTP " .. tostring(type(response) == "table" and response.StatusCode)
    end
    return response.Body
end


function xDTaraZ.Util.Alert(text, detail)
    warn("[LootToForge] menu:", text, detail or "")
    task.spawn(function()
        for _ = 1, Config.AlertTries do
            local shown = pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "LelHub", Text = text, Duration = 10 })
            if shown then return end
            task.wait(Config.AlertDelay)
        end
    end)
end


function xDTaraZ.Util.LoadLibrary()
    return createCompatibilityLibrary("Loot_To_Forge")
end

function xDTaraZ.Util.WarnJob(key, err)
    local stamp = key .. tostring(err):match("[^\n]*")
    local now = os.clock()
    if now - (State.Warned[stamp] or -Config.WarnCooldown) < Config.WarnCooldown then return end

    if not State.Warned[stamp] then
        State.WarnedCount += 1
        if State.WarnedCount > Config.WarnMemory then
            table.clear(State.Warned)
            State.WarnedCount = 1
        end
    end
    State.Warned[stamp] = now
    warn("[LootToForge]", key, err)
end


function xDTaraZ.Util.Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[LootToForge]", err)
    end
    return ok, err
end


function xDTaraZ.Util.Tier(id)
    return tonumber(tostring(id):match("%d+")) or 0
end


function xDTaraZ.Util.Abbreviate(number)
    local units = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" }
    local index = 1
    while number >= 1000 and index < #units do
        number /= 1000
        index += 1
    end
    return (index == 1 and "%d%s" or "%.2f%s"):format(number, units[index])
end


function xDTaraZ.Util.HighestKey(configTable)
    local bestKey, bestTier = nil, -1
    for key in pairs(configTable) do
        local tier = xDTaraZ.Util.Tier(key)
        if tier > bestTier then
            bestKey, bestTier = key, tier
        end
    end
    return bestKey
end


function xDTaraZ.Util.Child(fn)
    local owner = coroutine.running()
    local children = State.ChildThreads[owner]
    if not children then children = {} State.ChildThreads[owner] = children end
    local thread
    thread = task.defer(function()
        fn()
        children[thread] = nil
        if next(children) == nil then State.ChildThreads[owner] = nil end
    end)
    children[thread] = true
    return thread
end


function xDTaraZ.Util.CancelTree(thread)
    if not thread then return end
    for child in pairs(State.ChildThreads[thread] or {}) do xDTaraZ.Util.CancelTree(child) end
    State.ChildThreads[thread] = nil
    for _, worker in ipairs(State.WorkerBatches[thread] or {}) do xDTaraZ.Util.CancelTree(worker) end
    State.WorkerBatches[thread] = nil
    if State.LockOwner == thread then State.Lock = nil State.LockOwner = nil State.LockTime = 0 end
    for uuid, owner in pairs(State.LootPending) do
        if owner == thread then State.LootPending[uuid] = nil State.LootSeen[uuid] = nil end
    end
    if coroutine.status(thread) ~= "dead" then pcall(task.cancel, thread) end
end


function xDTaraZ.Util.WaitAll(workers, job)
    workers = math.max(0, math.floor(workers))
    local nextJob, pending, firstError = 0, workers, nil
    local threads = {}
    local owner = coroutine.running()
    State.WorkerBatches[owner] = threads
    for _ = 1, math.min(workers, math.clamp(State.Opt.WorkerLimit, 1, 32)) do
        table.insert(threads, task.defer(function()
            while State.Alive and nextJob < workers do
                nextJob += 1
                local ok, err = pcall(job)
                if not ok then firstError = firstError or err end
                pending -= 1
            end
        end))
    end
    local deadline = os.clock() + Config.RemoteTimeout * 2
    while State.Alive and pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end
    for _, thread in ipairs(threads) do
        if coroutine.status(thread) ~= "dead" then pcall(task.cancel, thread) end
    end
    State.WorkerBatches[owner] = nil
    if State.Alive and pending > 0 then error("worker batch timed out", 0) end
    if firstError then error(firstError, 0) end
    return pending == 0
end


function xDTaraZ.Util.RarityNames()
    local helper = xDTaraZ.GameLib.Api(GameConfig.Rarity.Helper)
    local names = {}
    for level = 1, 20 do
        local name = helper.GetRarityByLevel(level)
        if not name then break end
        table.insert(names, name)
    end
    return names
end


function xDTaraZ.Util.AllSet(list)
    local set = {}
    for _, name in ipairs(list) do
        set[name] = true
    end
    return set
end


function xDTaraZ.Util.Exclusive(name, fn, ...)
    local now = os.clock()
    if State.Lock and State.LockTime and (now - State.LockTime > 12) then
        State.Lock = nil
        State.LockOwner = nil
    end
    if State.Lock then return false end
    local owner = coroutine.running()
    for key, thread in pairs(State.JobRunning) do
        if thread ~= owner and not xDTaraZ.Scheduler.Groups[key] then return false end
    end
    State.Lock = name
    State.LockOwner = owner
    State.LockTime = now
    local result = table.pack(pcall(fn, ...))
    if State.LockOwner == owner then
        State.Lock = nil
        State.LockOwner = nil
        State.LockTime = 0
    end
    if not result[1] then error(result[2], 0) end
    return true, table.unpack(result, 2, result.n)
end


function xDTaraZ.Data.Get(force)
    local now = os.clock()
    if not force and State.Profile and (now - State.ProfileTime < State.ProfileCacheTtl) then
        return State.Profile
    end
    local remote = xDTaraZ.Util.Remote("Profile", "GetTotalDataRF")
    local ok, profile = pcall(remote.InvokeServer, remote)
    if not ok or type(profile) ~= "table" then
        if State.Profile then return State.Profile end
        error("profile unavailable; retry after loading", 0)
    end
    State.Profile = profile
    State.ProfileTime = now
    return State.Profile
end


function xDTaraZ.Data.Count(profile, itemId)
    local total = 0
    for _, entry in pairs(profile.Backpack.have) do
        if entry.ID == itemId then
            total += entry.Number or 1
        end
    end
    return total
end


function xDTaraZ.Data.Uuid(profile, itemId)
    for uuid, entry in pairs(profile.Backpack.have) do
        if entry.ID == itemId and (entry.Number or 0) >= 1 then
            return uuid
        end
    end
    return nil
end


function xDTaraZ.Data.Snapshot()
    local seen = {}
    for uuid in pairs(xDTaraZ.Data.Get().Backpack.have) do
        seen[uuid] = true
    end
    return seen
end


function xDTaraZ.Data.NewGear(before)
    local fresh = {}
    for uuid, entry in pairs(xDTaraZ.Data.Get(true).Backpack.have) do
        if not before[uuid] and (entry.Type == "Weapon" or entry.Type == "Armor" or entry.Type == "Hat") then
            fresh[uuid] = entry
        end
    end
    return fresh
end


function xDTaraZ.Ore.Rarity(oreId)
    local oreConfig = xDTaraZ.GameLib.Need(GameConfig.Ore.Config)[oreId]
    return oreConfig and xDTaraZ.GameLib.Api(GameConfig.Rarity.Helper).GetRarityByLevel(oreConfig.Rarity)
end


function xDTaraZ.Ore.Owned(profile)
    local ores = {}
    for uuid, entry in pairs(profile.Backpack.have) do
        if entry.Type == "Ore" and (entry.Number or 0) >= 1 then
            table.insert(ores, {
                uuid = uuid,
                id = entry.ID,
                tier = xDTaraZ.Util.Tier(entry.ID),
                number = math.floor(entry.Number),
                rarity = xDTaraZ.Ore.Rarity(entry.ID),
            })
        end
    end
    table.sort(ores, function(a, b) return a.tier > b.tier end)
    return ores
end


function xDTaraZ.Ore.Ids()
    local ids = {}
    for oreId in pairs(xDTaraZ.GameLib.Need(GameConfig.Ore.Config)) do
        table.insert(ids, oreId)
    end
    table.sort(ids, function(a, b) return xDTaraZ.Util.Tier(a) > xDTaraZ.Util.Tier(b) end)
    return ids
end


function xDTaraZ.Look.Item(itemId)
    for _, kind in ipairs(Config.LookKinds) do
        local folder = GameConfig:FindFirstChild(kind)
        local show = folder and folder:FindFirstChild("Show") and xDTaraZ.GameLib.Require(folder.Show)
        local entry = show and show[itemId]
        if not entry then continue end
        local config = folder:FindFirstChild("Config") and xDTaraZ.GameLib.Require(folder.Config)
        local info = config and config[itemId]
        return entry.Image, info and info.Rarity
    end
    return nil, nil
end


function xDTaraZ.Look.Color(rarity)
    if rarity == nil then return nil end
    State.RarityColors = State.RarityColors or {}
    local cached = State.RarityColors[rarity]
    if cached ~= nil then return cached or nil end

    local helper = xDTaraZ.GameLib.Api(GameConfig.Rarity.Helper)
    local name = rarity
    if type(rarity) == "number" then
        local ok, byLevel = pcall(helper.GetRarityByLevel, rarity)
        name = ok and byLevel or rarity
    end
    local probe = Instance.new("TextLabel")
    pcall(helper.SetUIQiu, probe, name)
    local gradient = probe:FindFirstChildWhichIsA("UIGradient")
    local color = gradient and gradient.Color.Keypoints[1].Value
    probe:Destroy()
    State.RarityColors[rarity] = color or false
    return color
end


function xDTaraZ.Look.Maps(labels, idOf)
    local images, colors = {}, {}
    for _, label in ipairs(labels) do
        local itemId = idOf(label)
        if not itemId then continue end
        local image, rarity = xDTaraZ.Look.Item(itemId)
        images[label] = image
        colors[label] = xDTaraZ.Look.Color(rarity)
    end
    return images, colors
end


function xDTaraZ.Ore.Choices()
    local oreShow = xDTaraZ.GameLib.Need(GameConfig.Ore.Show)
    local labels, idByLabel = {}, {}
    for _, oreId in ipairs(xDTaraZ.Ore.Ids()) do
        local label = ("%s (%s)"):format(oreShow[oreId] and oreShow[oreId].DisplayName or oreId, xDTaraZ.Ore.Rarity(oreId) or "?")
        if idByLabel[label] then
            label = ("%s #%d"):format(label, xDTaraZ.Util.Tier(oreId))
        end
        idByLabel[label] = oreId
        table.insert(labels, label)
    end
    State.OreLabels = idByLabel
    return labels
end


function xDTaraZ.Ore.ForgeChoices()
    local labels = xDTaraZ.Ore.Choices()
    table.insert(labels, 1, Config.OwnedOresLabel)
    return labels
end


function xDTaraZ.Spawn.Amount(value)
    value = tonumber(value)
    if not value or value ~= value or value <= 0 or value == math.huge then error("Enter a finite positive amount", 0) end
    return math.clamp(math.floor(value), 1, 1000000000)
end


function xDTaraZ.Ore.Add(uuid, amount)
    xDTaraZ.Util.Remote("Backpack", "TrySellItemRE"):FireServer(uuid, -xDTaraZ.Spawn.Amount(amount))
end


function xDTaraZ.Spawn.Choices()
    local labels, ids = {}, {}
    local oreShow = xDTaraZ.GameLib.Need(GameConfig.Ore.Show)
    for _, id in ipairs(xDTaraZ.Ore.Ids()) do
        local label = "Ore • " .. (oreShow[id] and oreShow[id].DisplayName or id) .. " [" .. id .. "]"
        labels[#labels + 1] = label
        ids[label] = { id = id, kind = "Ore" }
    end

    local eggFolder = GameConfig:FindFirstChild("Egg")
    local eggShow = eggFolder and eggFolder:FindFirstChild("Show") and xDTaraZ.GameLib.Require(eggFolder.Show)
    local eggCfg = eggFolder and eggFolder:FindFirstChild("Config") and xDTaraZ.GameLib.Require(eggFolder.Config)
    if eggShow or eggCfg then
        local eggIds = {}
        local allEggKeys = {}
        if eggShow then for id in pairs(eggShow) do allEggKeys[id] = true end end
        if eggCfg then for id in pairs(eggCfg) do allEggKeys[id] = true end end
        for id in pairs(allEggKeys) do eggIds[#eggIds + 1] = id end
        table.sort(eggIds, function(a, b) return xDTaraZ.Util.Tier(a) > xDTaraZ.Util.Tier(b) end)
        for _, id in ipairs(eggIds) do
            local name = eggShow and eggShow[id] and (eggShow[id].DisplayName or eggShow[id].Name) or id
            local label = "Egg • " .. name .. " [" .. id .. "]"
            labels[#labels + 1] = label
            ids[label] = { id = id, kind = "Egg" }
        end
    end

    local foodFolder = GameConfig:FindFirstChild("Food")
    local foodShow = foodFolder and foodFolder:FindFirstChild("Show") and xDTaraZ.GameLib.Require(foodFolder.Show)
    local foodCfg = foodFolder and foodFolder:FindFirstChild("Config") and xDTaraZ.GameLib.Require(foodFolder.Config)
    if foodShow or foodCfg then
        local foodIds = {}
        local allFoodKeys = {}
        if foodShow then for id in pairs(foodShow) do allFoodKeys[id] = true end end
        if foodCfg then for id in pairs(foodCfg) do allFoodKeys[id] = true end end
        for id in pairs(allFoodKeys) do foodIds[#foodIds + 1] = id end
        table.sort(foodIds, function(a, b) return xDTaraZ.Util.Tier(a) > xDTaraZ.Util.Tier(b) end)
        for _, id in ipairs(foodIds) do
            local name = foodShow and foodShow[id] and (foodShow[id].DisplayName or foodShow[id].Name) or id
            local label = "Fruit • " .. name .. " [" .. id .. "]"
            labels[#labels + 1] = label
            ids[label] = { id = id, kind = "Food" }
        end
    end

    local seen = {}
    local runeShow = xDTaraZ.GameLib.Need(GameConfig.EnchStone.Show)
    for _, entry in pairs(xDTaraZ.Data.Get().Backpack.have) do
        if entry.Type == "EnchStone" and not seen[entry.ID] then
            local id = entry.ID
            local label = "Rune • " .. (runeShow[id] and runeShow[id].DisplayName or id) .. " [" .. id .. "]"
            labels[#labels + 1] = label
            ids[label] = { id = id, kind = "EnchStone" }
            seen[id] = true
        end
    end
    State.SpawnLabels = ids
    return labels
end


function xDTaraZ.Spawn.Give(id, kind, amount)
    amount = xDTaraZ.Spawn.Amount(amount)
    if kind == "Egg" or kind == "Food" then
        local farmed = xDTaraZ.Stage.FarmTurbo(id, kind, amount)
        return farmed > 0, farmed, farmed > 0 and "turbo farmed into inventory" or "bag full or drop not rolled yet"
    end
    if kind == "Ore" then
        local farmed = xDTaraZ.Stage.FarmTurbo(id, "Ore", amount)
        if farmed > 0 then return true, farmed, "turbo farmed into inventory" end
    end
    if kind == "Pet" then
        local hatched, msg = xDTaraZ.Pet.FarmAndHatchTarget(id, amount)
        return hatched > 0, hatched, msg or (hatched > 0 and ("hatched target pet x" .. hatched) or "incubating target eggs")
    end
    local profile = xDTaraZ.Data.Get()
    local uuid = xDTaraZ.Data.Uuid(profile, id)
    if not uuid and kind == "Ore" then uuid = xDTaraZ.Ore.Ensure(id, 0) profile = xDTaraZ.Data.Get(true) end
    if not uuid then return false, 0, "need an owned copy first" end
    local before = xDTaraZ.Data.Count(profile, id)
    xDTaraZ.Ore.Add(uuid, amount)
    for _ = 1, 4 do
        if not State.Alive then return false, 0, "cancelled" end
        task.wait(0.2)
        local delta = xDTaraZ.Data.Count(xDTaraZ.Data.Get(true), id) - before
        if delta > 0 then return true, delta end
    end
    return false, 0, "no increase confirmed"
end

function xDTaraZ.Spawn.TurboStep()
    local picked = State.SpawnLabels[State.Opt.SpawnItem]
    if picked then
        xDTaraZ.Spawn.Give(picked.id, picked.kind, State.Opt.SpawnAmount or 1000)
    else
        xDTaraZ.Stage.FarmEggsAndFood(15)
        xDTaraZ.Stage.FarmMaxOres(15)
    end
end


function xDTaraZ.Potion.Owned(profile)
    local ids = {}
    local config = xDTaraZ.GameLib.Need(GameConfig.Potion.Config)
    for id, count in pairs(profile.Potion or {}) do
        if config[id] and type(count) == "number" and count > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end


function xDTaraZ.Potion.Extend(amount)
    amount = math.min(1000000, xDTaraZ.Spawn.Amount(amount))
    local config = xDTaraZ.GameLib.Need(GameConfig.Potion.Config)
    local changed = 0
    local profile = xDTaraZ.Data.Get()
    for _, id in ipairs(xDTaraZ.Potion.Owned(profile)) do
        if not State.Alive then break end
        local q = xDTaraZ.Data.Get()
        local buffId = config[id].BuffID
        local before = (q.Buff or {})[buffId] or 0
        local count = math.min(amount, math.floor(q.Potion[id] or 0))
        if count > 0 then
            xDTaraZ.Util.Remote("Potion", "TryUsePotionRE"):FireServer(id, count)
            task.wait(0.3)
            if ((xDTaraZ.Data.Get(true).Buff or {})[buffId] or 0) > before then changed += 1 end
        end
    end
    return changed
end


function xDTaraZ.Ore.Ensure(oreId, need)
    local profile = xDTaraZ.Data.Get()
    local uuid = xDTaraZ.Data.Uuid(profile, oreId)
    if uuid and xDTaraZ.Data.Count(profile, oreId) >= need then return uuid end

    xDTaraZ.Stage.FarmOreTarget(oreId, math.max(1, need - xDTaraZ.Data.Count(profile, oreId)))
    profile = xDTaraZ.Data.Get(true)
    return xDTaraZ.Data.Uuid(profile, oreId)
end


function xDTaraZ.Ore.Top(minimum)
    local top = xDTaraZ.Ore.Owned(xDTaraZ.Data.Get())[1]
    if not top or top.number < minimum then
        xDTaraZ.Stage.FarmMaxOres(3)
        top = xDTaraZ.Ore.Owned(xDTaraZ.Data.Get(true))[1]
    end
    return top and top.number >= minimum and top or nil
end


function xDTaraZ.TokenShop.BuyAll()
    local goodsConfig = xDTaraZ.GameLib.Need(GameConfig.TokenShop.Config)
    local exchange = xDTaraZ.Util.Remote("TokenShop", "ExchangeGoodsRF")
    local profile = xDTaraZ.Data.Get()
    if State.Opt.TokenReveal then
        local reveal = xDTaraZ.Util.Remote("TokenShop", "OpenGoodsRE")
        local opened = false
        for slot, good in pairs(profile.TokenShop and profile.TokenShop.Goods or {}) do
            if State.Alive and not good.Open and not good.Exchanged then
                reveal:FireServer(tostring(slot))
                opened = true
            end
        end
        if opened then task.wait(0.2) profile = xDTaraZ.Data.Get(true) end
    end
    local bought = 0
    for slot, good in pairs(profile.TokenShop and profile.TokenShop.Goods or {}) do
        if not State.Alive then break end
        local entry = goodsConfig[tonumber(slot)] or goodsConfig[tostring(slot)]
        if good.Exchanged or not entry then continue end
        if State.Opt.TokenSkipOwned and good.IsHave then continue end
        if next(State.Opt.TokenTargets) and not State.Opt.TokenTargets[tostring(slot)] then continue end

        if (profile.Token and profile.Token.value or 0) < (entry.Token or 0) then continue end
        if not good.Open then continue end
        local success = exchange:InvokeServer(tostring(slot))
        profile = xDTaraZ.Data.Get(true)
        local updated = profile.TokenShop and profile.TokenShop.Goods and profile.TokenShop.Goods[slot]
        if success == true or (updated and updated.Exchanged) then bought += 1 end
    end
    return bought
end


function xDTaraZ.TokenShop.Choices()
    local choices, ids = {}, {}
    for id, entry in pairs(xDTaraZ.GameLib.Need(GameConfig.TokenShop.Config)) do
        local label = ("%s (%d Token)"):format(entry.DisplayName or entry.MonID or tostring(id), entry.Token or 0)
        table.insert(choices, label)
        ids[label] = tostring(id)
    end
    table.sort(choices)
    return choices, ids
end


function xDTaraZ.Claim.CheckIn()
    local plan = xDTaraZ.GameLib.Api(ReplicatedStorage.LocalData.PlanKData)
    local data = plan.GetData()
    local claimed = 0
    for day, entry in pairs(data.sign or {}) do
        if not State.Alive then break end
        if type(entry) == "table" and entry.Sign and not entry.Claim then
            if plan.TryClaim(tostring(day)) == true then claimed += 1 end
        end
    end
    return claimed
end

function xDTaraZ.Stage.BattleStep()
    local fight = LocalPlayer:GetAttribute("IntoFight")
    if fight and fight ~= "Stage" then return end
    if not LocalPlayer.Character or LocalPlayer:GetAttribute("Dead") then return end
    if not fight then
        local stageId = State.Opt.Stage or xDTaraZ.Stage.Best()
        if not stageId then return end
        local manager = LocalPlayer.PlayerScripts:FindFirstChild("Manager")
        local stageManager = manager and manager:FindFirstChild("StageManager")
        local module = stageManager and stageManager:FindFirstChild("StageUtils")
        if not module then error("StageUtils unavailable while loading", 0) end
        xDTaraZ.GameLib.Api(module).StartFight(stageId)
    end
    if State.Alive and State.Opt.AutoBattle then xDTaraZ.Combat.KillAll() end
end


function xDTaraZ.Gear.SwitchForm(slot)
    local profile = xDTaraZ.Data.Get()
    local uuid = profile.Backpack.equiped[slot]
    local item = uuid and profile.Backpack.have[uuid]
    if not item then return false end
    local config = slot == "Weapon" and GameConfig.Weapon.Show or GameConfig.Armor.Show
    local show = xDTaraZ.GameLib.Need(config)[item.ID]
    if not show or not show.Mutant then return false end
    local wanted = (item.Mutant or show.Mutant) == "A" and "B" or "A"
    xDTaraZ.GameLib.Api(ReplicatedStorage.LocalData.BackpackData).ChangeEquipmentMutant(uuid, wanted)
    local deadline = os.clock() + 2
    repeat
        task.wait(0.1)
        local current = xDTaraZ.GameLib.Api(ReplicatedStorage.LocalData.BackpackData).GetItemData(uuid)
        if current and current.Mutant == wanted then return true end
    until not State.Alive or os.clock() >= deadline
    return false
end


function xDTaraZ.Stage.List()
    local stages = {}
    for stageId in pairs(xDTaraZ.GameLib.Api(GameConfig.Stage.Helper).GetStageEnemyConfig()) do
        table.insert(stages, stageId)
    end
    table.sort(stages, function(a, b) return xDTaraZ.Util.Tier(a) > xDTaraZ.Util.Tier(b) end)
    return stages
end


function xDTaraZ.Stage.Best()
    return xDTaraZ.Stage.List()[1] or "Stage_27"
end


function xDTaraZ.Stage.Collect(stageId, rarities)
    local drops = xDTaraZ.Util.Remote("Stage", "StageFinishedRF"):InvokeServer(stageId)
    if type(drops) ~= "table" then return end
    local getOre = xDTaraZ.Util.Remote("Stage", "GetOreRF")
    local getStone = xDTaraZ.Util.Remote("Stage", "GetEnhantStoneRE")
    for uuid, drop in pairs(drops) do
        if type(drop) == "table" then
            if drop.Type == "Material" then
                getStone:FireServer(uuid)
            else
                getOre:InvokeServer(uuid, true)
            end
        elseif not rarities or rarities[xDTaraZ.Ore.Rarity(drop)] then
            getOre:InvokeServer(uuid, true)
        end
    end
    xDTaraZ.Util.Remote("Stage", "ClaimedAllOreRE"):FireServer()
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Stage.FarmStones(stageId)
    stageId = stageId or xDTaraZ.Stage.Best()
    local finished = xDTaraZ.Util.Remote("Stage", "StageFinishedRF")
    local pickStone = xDTaraZ.Util.Remote("Stage", "GetEnhantStoneRE")
    local getOre = xDTaraZ.Util.Remote("Stage", "GetOreRF")
    xDTaraZ.Util.WaitAll(Config.StoneWorkers, function()
        for _ = 1, Config.StoneCallsPerWorker do
            local drops = finished:InvokeServer(stageId)
            for uuid, drop in pairs(type(drops) == "table" and drops or {}) do
                if type(drop) == "table" then
                    if drop.Type == "Material" then
                        pickStone:FireServer(uuid)
                    else
                        getOre:InvokeServer(uuid, true)
                    end
                end
            end
        end
    end)
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Stage.FarmOreTarget(targetOreId, needed)
    return xDTaraZ.Stage.FarmTurbo(targetOreId, "Ore", needed)
end


function xDTaraZ.Stage.FarmTurbo(targetId, kind, needed)
    needed = math.clamp(math.floor(needed or 1), 1, 1000000)
    local stageId = targetId and State.OreStage[targetId]
    if not stageId then
        if kind == "Egg" or (targetId and targetId:find("^Egg")) then
            stageId = (targetId == "Egg1" and "Stage_10") or "Stage_25"
        elseif targetId and (targetId == "Food_5" or targetId == "Food_6" or targetId:find("^Food_10")) then
            stageId = "Stage_27"
        else
            stageId = xDTaraZ.Stage.Best()
        end
    end

    local finished = xDTaraZ.Util.Remote("Stage", "StageFinishedRF")
    local getOre = xDTaraZ.Util.Remote("Stage", "GetOreRF")
    local pickStone = xDTaraZ.Util.Remote("Stage", "GetEnhantStoneRE")
    local claimAll = xDTaraZ.Util.Remote("Stage", "ClaimedAllOreRE")
    local got = 0

    local workers = math.clamp(Config.TurboFarmWorkers or 24, 8, 32)
    local roundsPerWorker = math.clamp(math.ceil(needed / (workers * 2)), 1, 100)

    if kind == "Egg" then
        xDTaraZ.Pet.TrimEggs(targetId)
    end

    xDTaraZ.Util.WaitAll(workers, function()
        for _ = 1, roundsPerWorker do
            if not State.Alive or got >= needed then break end
            local drops = finished:InvokeServer(stageId)
            if type(drops) == "table" then
                local batchClaims = {}
                for uuid, drop in pairs(drops) do
                    if type(drop) == "table" then
                        if drop.ID then State.OreStage[drop.ID] = stageId end
                        if drop.Type == "Material" then
                            pickStone:FireServer(uuid)
                        elseif not targetId or drop.ID == targetId or kind == "All" or drop.Type == kind then
                            batchClaims[#batchClaims + 1] = uuid
                        end
                    elseif type(drop) == "string" then
                        State.OreStage[drop] = stageId
                        if not targetId or drop == targetId or kind == "Ore" or kind == "All" then
                            batchClaims[#batchClaims + 1] = uuid
                        end
                    end
                end
                for _, dropUuid in ipairs(batchClaims) do
                    task.spawn(function()
                        if getOre:InvokeServer(dropUuid, true) then
                            got += 1
                        end
                    end)
                end
            end
        end
    end)

    claimAll:FireServer()
    xDTaraZ.Data.Get(true)
    return got
end


function xDTaraZ.Stage.FarmDropTarget(targetId, kind, needed)
    return xDTaraZ.Stage.FarmTurbo(targetId, kind, needed)
end


function xDTaraZ.Stage.FarmEggsAndFood(rounds)
    rounds = math.clamp(rounds or Config.EggFarmCalls, 1, 100)
    local stageId = "Stage_25"
    local finished = xDTaraZ.Util.Remote("Stage", "StageFinishedRF")
    local getOre = xDTaraZ.Util.Remote("Stage", "GetOreRF")
    local pickStone = xDTaraZ.Util.Remote("Stage", "GetEnhantStoneRE")
    local claimAll = xDTaraZ.Util.Remote("Stage", "ClaimedAllOreRE")
    local eggs, foods = 0, 0
    xDTaraZ.Pet.TrimEggs("Egg2")
    xDTaraZ.Util.WaitAll(Config.TurboFarmWorkers or 24, function()
        for _ = 1, rounds do
            if not State.Alive then break end
            local drops = finished:InvokeServer(stageId)
            if type(drops) == "table" then
                for uuid, drop in pairs(drops) do
                    if type(drop) == "table" then
                        if drop.Type == "Material" then
                            pickStone:FireServer(uuid)
                        elseif drop.Type == "Egg" then
                            task.spawn(function()
                                if getOre:InvokeServer(uuid, true) then eggs += 1 end
                            end)
                        elseif drop.Type == "Food" then
                            task.spawn(function()
                                if getOre:InvokeServer(uuid, true) then foods += 1 end
                            end)
                        end
                    end
                end
            end
        end
    end)
    claimAll:FireServer()
    xDTaraZ.Data.Get(true)
    if State.Opt.AutoDeleteEggs then xDTaraZ.Pet.TrimEggs() end
    return eggs, foods
end


function xDTaraZ.Stage.FarmMaxOres(rounds)
    rounds = math.clamp(rounds or 20, 1, 100)
    local stageId = State.Opt.Stage or xDTaraZ.Stage.Best() or "Stage_27"
    local finished = xDTaraZ.Util.Remote("Stage", "StageFinishedRF")
    local getOre = xDTaraZ.Util.Remote("Stage", "GetOreRF")
    local pickStone = xDTaraZ.Util.Remote("Stage", "GetEnhantStoneRE")
    local claimAll = xDTaraZ.Util.Remote("Stage", "ClaimedAllOreRE")
    local total = 0
    xDTaraZ.Util.WaitAll(Config.TurboFarmWorkers or 24, function()
        for _ = 1, rounds do
            if not State.Alive then break end
            local drops = finished:InvokeServer(stageId)
            if type(drops) == "table" then
                for uuid, drop in pairs(drops) do
                    if type(drop) == "table" and drop.Type == "Material" then
                        pickStone:FireServer(uuid)
                    else
                        task.spawn(function()
                            if getOre:InvokeServer(uuid, true) then
                                total += 1
                            end
                        end)
                    end
                end
            end
        end
    end)
    claimAll:FireServer()
    xDTaraZ.Data.Get(true)
    return total
end

function xDTaraZ.Stage.ExitFight()
    pcall(function()
        xDTaraZ.GameLib.Api(LocalPlayer.PlayerScripts.Manager.StageManager.StageUtils).ExitFight(true)
    end)
end


function xDTaraZ.Forge.Target()
    for _, target in ipairs(Config.ForgeTargets) do
        if target.name == State.Opt.ForgeTarget then
            return target
        end
    end
    return Config.ForgeTargets[1]
end


function xDTaraZ.Forge.Run(forgeType, oreList)
    local res = xDTaraZ.Util.Remote("Forge", "ForgeRF"):InvokeServer({ ConfigType = forgeType, UUIDList = oreList })
    xDTaraZ.Data.Get(true)
    return res
end


function xDTaraZ.Forge.PickOwned(profile, count)
    local opt = State.Opt
    local candidates = {}
    for _, ore in ipairs(xDTaraZ.Ore.Owned(profile)) do
        local spare = ore.number - opt.KeepPerOre
        if opt.ForgeRarities[ore.rarity] and spare > 0 then
            ore.spare = spare
            table.insert(candidates, ore)
        end
    end
    if not opt.BestOreFirst then
        table.sort(candidates, function(a, b) return a.tier < b.tier end)
    end

    local pick, need = {}, count
    for _, ore in ipairs(candidates) do
        if need <= 0 then break end
        local take = math.min(need, ore.spare)
        pick[ore.uuid] = take
        need -= take
    end
    return need <= 0 and pick or nil
end


function xDTaraZ.Forge.Pick(count)
    local oreId = State.OreLabels[State.Opt.ForgeOre]
    if not oreId then
        return xDTaraZ.Forge.PickOwned(xDTaraZ.Data.Get(), count)
    end
    local uuid = xDTaraZ.Ore.Ensure(oreId, count * State.Opt.ForgePerTick)
    return uuid and { [uuid] = count }
end


function xDTaraZ.Forge.Once()
    local target = xDTaraZ.Forge.Target()
    local pick = xDTaraZ.Forge.Pick(target.ores)
    return pick ~= nil and xDTaraZ.Forge.Run(target.forgeType, pick) ~= nil
end

function xDTaraZ.Forge.Burst()
    local target = xDTaraZ.Forge.Target()
    local perTick = State.Opt.ForgePerTick
    local pick = xDTaraZ.Forge.Pick(target.ores * perTick)
    if not pick then return end
    local uuid = next(pick)
    if next(pick, uuid) == nil then
        for _ = 1, perTick do
            xDTaraZ.Forge.Run(target.forgeType, { [uuid] = target.ores })
        end
        return
    end
    for _ = 1, perTick do
        if not xDTaraZ.Forge.Once() then break end
    end
end

function xDTaraZ.Forge.Step()
    if not State.Opt.ForgeSellJunk then return xDTaraZ.Forge.Burst() end
    local before = xDTaraZ.Data.Snapshot()
    xDTaraZ.Forge.Burst()
    local fresh = xDTaraZ.Data.NewGear(before)
    local profile = State.Profile
    local keep = {}
    for uuid, entry in pairs(fresh) do
        local worn = profile.Backpack.equiped[entry.Type]
        local wornEntry = worn and profile.Backpack.have[worn]
        if not wornEntry or xDTaraZ.Gear.Score(entry, true) > xDTaraZ.Gear.Score(wornEntry, true) then
            keep[uuid] = true
        end
    end
    xDTaraZ.Sell.Fresh(fresh, keep)
end


function xDTaraZ.Sell.Rarity(entry)
    local folder = entry.Type == "Weapon" and "Weapon" or "Armor"
    local itemConfig = xDTaraZ.GameLib.Need(GameConfig[folder].Config)[entry.ID]
    return itemConfig and itemConfig.Rarity
end


function xDTaraZ.Sell.Anchors(profile)
    local anchors, bestPower = {}, {}
    for uuid, entry in pairs(profile.Backpack.have) do
        if not (entry.Type == "Weapon" or entry.Type == "Armor" or entry.Type == "Hat") then continue end
        local helper = xDTaraZ.GameLib.Api(entry.Type == "Weapon" and GameConfig.Weapon.Helper or GameConfig.Armor.Helper)
        local ok, percent = pcall(helper.CheckIsBestPercent, entry.ID)
        if not ok or percent then continue end
        local powerOk, power = pcall(helper.GetMainAffix, entry.ID)
        if powerOk and type(power) == "number" and power > (bestPower[entry.Type] or 0) then
            bestPower[entry.Type] = power
            anchors[entry.Type] = uuid
        end
    end
    local keep = {}
    for _, uuid in pairs(anchors) do
        keep[uuid] = true
    end
    local backpack = xDTaraZ.GameLib.Require(ReplicatedStorage.LocalData.BackpackData)
    if type(backpack) == "table" and type(backpack.IsLocked) == "function" then
        for uuid in pairs(profile.Backpack.have) do
            local ok, locked = pcall(backpack.IsLocked, uuid)
            if ok and locked then keep[uuid] = true end
        end
    end
    return keep
end


function xDTaraZ.Sell.Run(profile)
    local opt = State.Opt
    local equipped = xDTaraZ.Sell.Anchors(profile)
    for _, uuid in pairs(profile.Backpack.equiped) do
        equipped[uuid] = true
    end

    local byId = {}
    for uuid, entry in pairs(profile.Backpack.have) do
        if opt.SellTypes[entry.Type] and not equipped[uuid] then
            byId[entry.ID] = byId[entry.ID] or {}
            table.insert(byId[entry.ID], { uuid = uuid, entry = entry })
        end
    end

    local sell = xDTaraZ.Util.Remote("Backpack", "TrySellItemRE")
    for _, items in pairs(byId) do
        table.sort(items, function(a, b) return (a.entry.Level or 0) > (b.entry.Level or 0) end)
        for index, gear in ipairs(items) do
            if index > opt.KeepPerItem and opt.SellRarities[xDTaraZ.Sell.Rarity(gear.entry)] then
                sell:FireServer(gear.uuid, 1)
            end
        end
    end
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Sell.Fresh(fresh, keep)
    local equipped = xDTaraZ.Sell.Anchors(State.Profile)
    for _, uuid in pairs(State.Profile.Backpack.equiped) do
        equipped[uuid] = true
    end
    local sell = xDTaraZ.Util.Remote("Backpack", "TrySellItemRE")
    for uuid in pairs(fresh) do
        if not equipped[uuid] and not (keep and keep[uuid]) then
            sell:FireServer(uuid, 1)
        end
    end
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Gear.Score(entry, atTarget)
    local balance = xDTaraZ.GameLib.Api(ReplicatedStorage.Utils.BalanceUtils)
    local backpack = xDTaraZ.Data.Get().Backpack
    local potential = table.clone(entry)
    if atTarget then potential.Level = math.max(entry.Level or 0, State.Opt.EnhanceTarget) end
    local value = entry.Type == "Weapon" and balance.GetWeaponTrainValue or balance.GetArmorValue
    local ok, power = pcall(value, LocalPlayer, potential, backpack)
    if not ok or type(power) ~= "number" then return 0 end
    return power * (1 + (entry.Level or 0) * 1e-6 + #(entry.EnchanceList or {}) * 1e-9)
end


function xDTaraZ.Gear.BestOwned(profile, slot, atTarget)
    local bestUuid, bestScore = nil, -1
    for uuid, entry in pairs(profile.Backpack.have) do
        if entry.Type == slot then
            local score = xDTaraZ.Gear.Score(entry, atTarget)
            if score > bestScore then
                bestUuid, bestScore = uuid, score
            end
        end
    end
    return bestUuid, bestScore
end


function xDTaraZ.Gear.EquipBest()
    local profile = xDTaraZ.Data.Get()
    local equip = xDTaraZ.Util.Remote("Backpack", "TryEquipItemRE")
    local changed = 0
    local atTarget = State.Opt.MaxGear and State.Opt.GearEnhance
    for _, slot in ipairs(Config.GearTypes) do
        local best, bestScore = xDTaraZ.Gear.BestOwned(profile, slot, atTarget)
        local current = profile.Backpack.equiped[slot]
        local currentEntry = current and profile.Backpack.have[current]
        if best and best ~= current and bestScore > (currentEntry and xDTaraZ.Gear.Score(currentEntry, atTarget) or -1) then
            equip:FireServer(best, slot)
            changed += 1
        end
    end
    if changed > 0 then xDTaraZ.Data.Get(true) end
    return changed
end

function xDTaraZ.Gear.ForgeBest()
    local before = xDTaraZ.Data.Snapshot()
    for _, spec in ipairs(Config.GearSlots) do
        local top = xDTaraZ.Ore.Top(spec.ores * Config.GearForgeTries)
        if top then
            for _ = 1, Config.GearForgeTries do
                xDTaraZ.Forge.Run(spec.forgeType, { [top.uuid] = spec.ores })
            end
        end
        local best = xDTaraZ.Gear.BestOwned(xDTaraZ.Data.Get(), spec.slot, true)
        if best then
            xDTaraZ.Util.Remote("Backpack", "TryEquipItemRE"):FireServer(best, spec.slot)
        end
    end
    task.wait(0.5)
    xDTaraZ.Sell.Fresh(xDTaraZ.Data.NewGear(before))
end


function xDTaraZ.Gear.MissingForEnhance(profile, level)
    local cost = xDTaraZ.GameLib.Need(GameConfig.Enhant.Config)[level + 1]
    if not cost then return nil end
    if xDTaraZ.Data.Count(profile, "EnhantStone_2") < (cost.EnhantStone_2 or 0) then return "EnhantStone_2" end
    if xDTaraZ.Data.Count(profile, "EnhantStone_1") < (cost.EnhantStone_1 or 0) then return "EnhantStone_1" end
    if profile.Eco.coin < (cost.NeedCoin or 0) then return "Coin" end
    return nil
end


function xDTaraZ.Gear.Gather(missing)
    State.GearNote = missing
    if missing == "Coin" then
        xDTaraZ.Forge.Step()
        xDTaraZ.Sell.Run(xDTaraZ.Data.Get())
    elseif missing == "EnhantStone_1" then
        xDTaraZ.Stage.FarmStones(xDTaraZ.Stage.Best())
    elseif not xDTaraZ.Tower.FarmStep() then
        State.GearNote = "NoTicket"
    end
end


function xDTaraZ.Gear.RuneOrder()
    if State.Runes then return State.Runes end
    local show = xDTaraZ.GameLib.Find("Config.EnchStone.Show")
    local stones = show and xDTaraZ.GameLib.Require(show)
    if not stones then return Config.EnchantPriority end

    local known = {}
    for index, stoneId in ipairs(Config.EnchantPriority) do
        known[stoneId] = index
    end
    local runes = {}
    for stoneId in pairs(stones) do
        if xDTaraZ.Util.Tier(stoneId) >= Config.RuneMinTier then runes[#runes + 1] = stoneId end
    end
    table.sort(runes, function(a, b)
        local ta, tb = xDTaraZ.Util.Tier(a), xDTaraZ.Util.Tier(b)
        if ta ~= tb then return ta > tb end
        local ka, kb = known[a] or math.huge, known[b] or math.huge
        if ka ~= kb then return ka < kb end
        return a < b
    end)
    State.Runes = runes
    return runes
end


function xDTaraZ.Gear.Priority()
    return #State.Opt.EnchantPriority > 0 and State.Opt.EnchantPriority or xDTaraZ.Gear.RuneOrder()
end


function xDTaraZ.Gear.Enchant(profile, uuid)
    local entry = profile.Backpack.have[uuid]
    local used = {}
    for slot = 1, entry.EnchanceNum or 0 do
        local current = entry.EnchanceList and entry.EnchanceList[slot]
        local currentId = current and current.ID
        local wanted
        for _, stoneId in ipairs(xDTaraZ.Gear.Priority()) do
            if not used[stoneId] and (stoneId == currentId or xDTaraZ.Data.Count(profile, stoneId) > 0) then
                wanted = stoneId
                break
            end
        end
        if wanted then
            used[wanted] = true
            if wanted ~= currentId then
                if currentId then
                    xDTaraZ.Util.Remote("Backpack", "UnEnchantRE"):FireServer(uuid, slot)
                    task.wait(0.04)
                end
                xDTaraZ.Util.Remote("Backpack", "EnchantRE"):FireServer(uuid, xDTaraZ.Data.Uuid(profile, wanted), slot)
                task.wait(0.04)
            end
        end
    end
end


function xDTaraZ.Gear.Enhance(profile)
    local target = math.min(State.Opt.EnhanceTarget, xDTaraZ.Util.Tier(xDTaraZ.Util.HighestKey(xDTaraZ.GameLib.Need(GameConfig.Enhant.Config))))
    local enhance = xDTaraZ.Util.Remote("Backpack", "EnhantEquipmentRF")
    for _, spec in ipairs(Config.GearSlots) do
        local uuid = profile.Backpack.equiped[spec.slot]
        local entry = uuid and profile.Backpack.have[uuid]
        if entry and (entry.Level or 0) < target then
            local missing = xDTaraZ.Gear.MissingForEnhance(profile, entry.Level or 0)
            if missing then
                xDTaraZ.Gear.Gather(missing)
                return false
            end
            State.GearNote = "Enhancing"
            local useProtect = xDTaraZ.Data.Count(profile, "EnhantProtect") > 0 and (entry.Level or 0) >= xDTaraZ.GameLib.Api(GameConfig.Enhant.Helper).GetFailLevel()
            xDTaraZ.Util.WaitAll(Config.GearEnhanceWorkers, function()
                for _ = 1, Config.GearEnhanceTries do
                    if not enhance:InvokeServer(uuid, { UseProtect = useProtect }) then return end
                end
            end)
            xDTaraZ.Data.Get(true)
            return false
        end
    end
    return true
end

function xDTaraZ.Gear.MaxStep()
    local opt = State.Opt
    if opt.GearForge and not State.GearForged then
        xDTaraZ.Gear.ForgeBest()
        State.GearForged = true
    end
    if opt.GearEnchant then
        local profile = xDTaraZ.Data.Get()
        for _, spec in ipairs(Config.GearSlots) do
            local uuid = profile.Backpack.equiped[spec.slot]
            if uuid then xDTaraZ.Gear.Enchant(profile, uuid) end
        end
    end
    if not opt.GearEnhance or xDTaraZ.Gear.Enhance(xDTaraZ.Data.Get()) then
        State.GearNote = "Done"
    end
end


function xDTaraZ.Gear.EnhanceSlot(slot, target)
    local enhance = xDTaraZ.Util.Remote("Backpack", "EnhantEquipmentRF")
    local failLevel = xDTaraZ.GameLib.Api(GameConfig.Enhant.Helper).GetFailLevel()
    local level = 0
    for _ = 1, Config.SlotEnhanceRounds do
        local profile = xDTaraZ.Data.Get()
        local uuid = profile.Backpack.equiped[slot]
        local entry = uuid and profile.Backpack.have[uuid]
        if not entry then return nil end
        level = entry.Level or 0
        if level >= target then return level end
        local missing = xDTaraZ.Gear.MissingForEnhance(profile, level)
        if missing == "EnhantStone_1" then
            xDTaraZ.Stage.FarmStones(xDTaraZ.Stage.Best())
        elseif missing then
            return level
        else
            enhance:InvokeServer(uuid, { UseProtect = level >= failLevel and xDTaraZ.Data.Count(profile, "EnhantProtect") > 0 })
        end
    end
    xDTaraZ.Data.Get(true)
    return level
end


function xDTaraZ.Gear.EquippedNames(profile)
    local names = {}
    for _, spec in ipairs(Config.GearSlots) do
        local uuid = profile.Backpack.equiped[spec.slot]
        local entry = uuid and profile.Backpack.have[uuid]
        if entry then
            local shows = xDTaraZ.GameLib.Require(GameConfig[entry.Type == "Weapon" and "Weapon" or "Armor"].Show)
            local show = shows and shows[entry.ID]
            table.insert(names, ("%s +%d"):format(show and show.DisplayName or entry.ID, entry.Level or 0))
        end
    end
    return table.concat(names, " · ")
end


function xDTaraZ.Index.GearCatalog()
    local gear = {}
    local armorHelper = xDTaraZ.GameLib.Api(GameConfig.Armor.Helper)
    for weaponId, weapon in pairs(xDTaraZ.GameLib.Need(GameConfig.Weapon.Config)) do
        table.insert(gear, { id = weaponId, slot = "Weapon", forgeType = "Weapon", forgeable = weapon.TLevel ~= nil })
    end
    for armorId, armor in pairs(xDTaraZ.GameLib.Need(GameConfig.Armor.Config)) do
        table.insert(gear, { id = armorId, slot = armorHelper.GetBigType(armorId) or "Armor", forgeType = "Armor", forgeable = armor.TLevel ~= nil })
    end
    return gear
end


function xDTaraZ.Index.Missing()
    local unlocked = xDTaraZ.Data.Get().Index.unlocked
    local missing = {}
    for _, gear in ipairs(xDTaraZ.Index.GearCatalog()) do
        if State.Opt.IndexTypes[gear.slot] and not unlocked[gear.slot .. "-" .. gear.id] then
            table.insert(missing, gear)
        end
    end
    table.sort(missing, function(a, b)
        if a.forgeable ~= b.forgeable then return a.forgeable end
        return a.id < b.id
    end)
    return missing
end


function xDTaraZ.Index.Plan(gear)
    local cached = State.Plans[gear.id]
    if cached then return cached[1], cached[2], cached[3] end

    local forgeUtils = xDTaraZ.GameLib.Api(ReplicatedStorage.Utils.ForgeUtils)
    local helper = xDTaraZ.GameLib.Api(gear.forgeType == "Weapon" and GameConfig.Weapon.Helper or GameConfig.Armor.Helper)
    local bestChance, bestOre, bestCount = 0, nil, nil
    local sliceStart = os.clock()
    for count = 1, Config.ForgeCountMax do
        local split = helper.GetForgePercentByNumber(count)
        if not split then continue end
        for _, oreId in ipairs(xDTaraZ.Ore.Ids()) do
            if os.clock() - sliceStart > Config.PlanSlice then
                task.wait()
                sliceStart = os.clock()
            end
            local list = { [oreId] = count }
            local ok, chance = pcall(function()
                local low, high = forgeUtils.GetForgeOreResult(list)
                local power = forgeUtils.GetOreAvgPower(list)
                local total = 0
                for subType, share in pairs(split) do
                    if share > 0 then
                        total += share * (forgeUtils.GetEquPercent(gear.forgeType, count, low, high, power, subType)[gear.id] or 0)
                    end
                end
                return total
            end)
            if ok and chance > bestChance then
                bestChance, bestOre, bestCount = chance, oreId, count
            end
        end
    end
    State.Plans[gear.id] = { bestChance, bestOre, bestCount }
    return bestChance, bestOre, bestCount
end


function xDTaraZ.Index.Label(gear)
    local show = xDTaraZ.GameLib.Need(GameConfig[gear.forgeType].Show)[gear.id]
    local name = ("%s [%s]"):format(show and show.DisplayName or gear.id, gear.slot)
    if not gear.forgeable then return name .. " - event" end
    local chance = xDTaraZ.Index.Plan(gear)
    return chance > 0 and ("%s - %.2f%%"):format(name, chance * 100) or name .. " - no recipe"
end


function xDTaraZ.Index.Choices()
    local labels, byLabel = {}, {}
    for _, gear in ipairs(xDTaraZ.Index.Missing()) do
        local label = xDTaraZ.Index.Label(gear)
        byLabel[label] = gear
        table.insert(labels, label)
    end
    State.MissingLabels = byLabel
    return labels
end


function xDTaraZ.Index.Hunt(gear, copies)
    local chance, oreId, count = xDTaraZ.Index.Plan(gear)
    if chance <= 0 then return false end
    local budget = math.min(Config.HuntMaxForges * (copies or 1), math.ceil(Config.HuntTargetHits * (copies or 1) / chance))
    local key = gear.slot .. "-" .. gear.id
    local forged, got = 0, 0
    while forged < budget and State.Alive do
        local uuid = xDTaraZ.Ore.Ensure(oreId, count * Config.HuntBatch)
        if not uuid then return false end
        local before = xDTaraZ.Data.Snapshot()
        local perWorker = math.ceil(Config.HuntBatch / Config.HuntWorkers)
        xDTaraZ.Util.WaitAll(Config.HuntWorkers, function()
            for _ = 1, perWorker do
                xDTaraZ.Forge.Run(gear.forgeType, { [uuid] = count })
            end
        end)
        forged += perWorker * Config.HuntWorkers
        State.IndexNote = ("%s %d/%d"):format(gear.id, forged, budget)
        local fresh = xDTaraZ.Data.NewGear(before)
        local keep = {}
        for freshUuid, entry in pairs(fresh) do
            if entry.ID == gear.id and (not copies or got < copies) then
                keep[freshUuid] = true
                got += 1
            end
        end
        xDTaraZ.Sell.Fresh(fresh, keep)
        if copies then
            State.IndexNote = ("%s %d/%d"):format(gear.id, got, copies)
            if got >= copies then return true end
        elseif State.Profile.Index.unlocked[key] or next(keep) then
            return true
        end
    end
    return false
end


function xDTaraZ.Spawn.GearChoices(slot)
    local labels, byLabel, list = {}, {}, {}
    for _, gear in ipairs(xDTaraZ.Index.GearCatalog()) do
        if not gear.forgeable or gear.slot ~= slot then continue end
        local helper = xDTaraZ.GameLib.Api(gear.forgeType == "Weapon" and GameConfig.Weapon.Helper or GameConfig.Armor.Helper)
        local ok, power = pcall(helper.GetMainAffix, gear.id)
        table.insert(list, { gear, ok and tonumber(power) or 0 })
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for _, pair in ipairs(list) do
        local label = xDTaraZ.Index.Label(pair[1])
        byLabel[label] = pair[1]
        table.insert(labels, label)
    end
    State.GearLabels = byLabel
    return labels
end


function xDTaraZ.Spawn.BestSet()
    local made = 0
    for _, slot in ipairs(Config.GearTypes) do
        local best, bestPower = nil, -1
        for _, gear in ipairs(xDTaraZ.Index.GearCatalog()) do
            if not gear.forgeable or gear.slot ~= slot then continue end
            local helper = xDTaraZ.GameLib.Api(gear.forgeType == "Weapon" and GameConfig.Weapon.Helper or GameConfig.Armor.Helper)
            local ok, power = pcall(helper.GetMainAffix, gear.id)
            power = ok and tonumber(power) or 0
            if power > bestPower then best, bestPower = gear, power end
        end
        if best and xDTaraZ.Index.Hunt(best, 1) then made += 1 end
    end
    task.wait(0.5)
    xDTaraZ.Gear.EquipBest()
    return made
end


function xDTaraZ.Spawn.FullGodSet()
    local made = xDTaraZ.Spawn.BestSet()
    xDTaraZ.Stage.FarmStones(xDTaraZ.Stage.Best())
    local profile = xDTaraZ.Data.Get(true)
    xDTaraZ.Gear.EquipBest()
    profile = xDTaraZ.Data.Get(true)
    for _ = 1, 10 do
        if not State.Alive or xDTaraZ.Gear.Enhance(profile) then break end
        profile = xDTaraZ.Data.Get(true)
        task.wait(0.2)
    end
    for _, spec in ipairs(Config.GearSlots) do
        local uuid = profile.Backpack.equiped[spec.slot]
        if uuid then
            xDTaraZ.Gear.Enchant(profile, uuid)
            xDTaraZ.Util.Remote("Backpack", "SetLockRE"):FireServer(uuid, true)
        end
    end
    return made
end


function xDTaraZ.Index.HuntAll()
    local found, tried = 0, 0
    for _, gear in ipairs(xDTaraZ.Index.Missing()) do
        if not State.Opt.AutoIndex and State.Lock ~= "Index" then break end
        if gear.forgeable and xDTaraZ.Index.Plan(gear) > 0 then
            tried += 1
            if xDTaraZ.Index.Hunt(gear) then found += 1 end
        end
    end
    xDTaraZ.Index.ClaimAll()
    if tried > 0 then State.IndexNote = ("Found %d/%d"):format(found, tried) end
    return found, tried
end

function xDTaraZ.Index.CollectOres()
    for _, stageId in ipairs(xDTaraZ.Stage.List()) do
        xDTaraZ.Stage.Collect(stageId, nil)
    end
    xDTaraZ.Index.ClaimAll()
end

function xDTaraZ.Index.ClaimAll()
    local index = xDTaraZ.Data.Get().Index
    local claimExp = xDTaraZ.Util.Remote("Index", "TryClaimIndexExpRF")
    for key in pairs(index.unlocked) do
        local itemType, itemId = key:match("^(.-)%-(.+)$")
        if itemType and not index.claimed[key] then
            claimExp:InvokeServer(itemType, itemId)
        end
    end
    local claimLevel = xDTaraZ.Util.Remote("Index", "TryClaimLevelRewardRF")
    for _ = 1, Config.IndexLevelClaims do
        if not claimLevel:InvokeServer() then break end
    end
end


function xDTaraZ.Index.Progress()
    local index = xDTaraZ.Data.Get().Index
    local unlocked = 0
    for _ in pairs(index.unlocked) do
        unlocked += 1
    end
    return unlocked, index.level
end


function xDTaraZ.Level.FindBestArea(gen)
    local areas = xDTaraZ.GameLib.Need(GameConfig.TrainArea.Config)
    local ids = {}
    for areaId in pairs(areas) do
        table.insert(ids, tonumber(areaId))
    end
    table.sort(ids, function(a, b) return areas[a].Basic > areas[b].Basic end)

    local function Live()
        return State.Opt.AutoTrain and State.TrainGen == gen
    end

    local into = xDTaraZ.Util.Remote("Train", "IntoAutoTrainRE")
    for _, areaId in ipairs(ids) do
        if not Live() then return nil end
        State.TrainPending = areaId
        into:FireServer(areaId)
        local deadline = os.clock() + Config.TrainAcceptWait
        while Live() and os.clock() < deadline and LocalPlayer:GetAttribute("AutoTrainAreaID") ~= areaId do
            task.wait(0.1)
        end
        if LocalPlayer:GetAttribute("AutoTrainAreaID") == areaId then
            State.TrainPending = nil
            return areaId
        end
    end
    State.TrainPending = nil
    return nil
end

function xDTaraZ.Level.Enter()
    if not State.Opt.AutoTrain or State.TrainEntering then return end
    if State.TrainArea then
        if os.clock() - State.TrainFiredAt < Config.TrainAcceptWait then return end
        State.TrainFiredAt = os.clock()
        xDTaraZ.Util.Remote("Train", "IntoAutoTrainRE"):FireServer(State.TrainArea)
        return
    end

    local gen = State.TrainGen
    State.TrainEntering = true
    local ok, areaId = pcall(xDTaraZ.Level.FindBestArea, gen)
    State.TrainEntering = false
    if not ok then error(areaId, 0) end
    if State.TrainGen == gen and areaId then
        State.TrainArea = areaId
        State.TrainFiredAt = os.clock()
    end
end

function xDTaraZ.Level.Leave()
    local exit = xDTaraZ.Util.Remote("Train", "ExitAutoTrainRE")
    for _ = 1, Config.TrainExitTries do
        local areaId = LocalPlayer:GetAttribute("AutoTrainAreaID") or State.TrainPending or State.TrainArea
        if not areaId then return end
        exit:FireServer(areaId)
        if not State.Alive then
            State.TrainPending = nil
            return
        end

        task.wait(Config.TrainSettle)
        if State.Opt.AutoTrain then return end
        if not LocalPlayer:GetAttribute("AutoTrainAreaID") then
            State.TrainPending = nil
            return
        end
    end
end


function xDTaraZ.Level.SetTraining(enabled)
    State.TrainGen += 1
    if enabled then
        xDTaraZ.Level.Enter()
    else
        xDTaraZ.Level.Leave()
    end
end

function xDTaraZ.Level.Bind()
    table.insert(State.Conns, LocalPlayer:GetAttributeChangedSignal("AutoTrainAreaID"):Connect(function()
        if not State.Opt.AutoTrain or LocalPlayer:GetAttribute("AutoTrainAreaID") then return end
        task.delay(Config.TrainRejoinDelay, function()
            if State.Opt.AutoTrain and not LocalPlayer:GetAttribute("AutoTrainAreaID") then
                xDTaraZ.Util.Try(xDTaraZ.Level.Enter)
            end
        end)
    end))
end


function xDTaraZ.Level.UsePotions(profile)
    local potionConfig = xDTaraZ.GameLib.Need(GameConfig.Potion.Config)
    local now = workspace:GetAttribute("ServerTime") or os.time()
    local buffs = profile.Buff or {}
    for potionName, count in pairs(profile.Potion or {}) do
        local buffId = potionConfig[potionName] and potionConfig[potionName].BuffID
        local active = buffId and type(buffs[buffId]) == "number" and buffs[buffId] > now
        if type(count) == "number" and count > 0 and not active then
            xDTaraZ.Util.Remote("Potion", "TryUsePotionRE"):FireServer(potionName, 1)
        end
    end
end

function xDTaraZ.Level.TrainStep()
    local profile = xDTaraZ.Data.Get()
    xDTaraZ.Level.UsePotions(profile)
    if profile.Eco.rebirth ~= State.TrainRebirth or profile.Eco.level ~= State.TrainLevel then
        State.TrainRebirth = profile.Eco.rebirth
        State.TrainLevel = profile.Eco.level
        State.TrainArea = nil
    end

    if LocalPlayer:GetAttribute("AutoTrainAreaID") then
        State.TrainNilSince = nil
        return
    end
    State.TrainNilSince = State.TrainNilSince or os.clock()
    if os.clock() - State.TrainNilSince < Config.TrainWatchdog then return end
    xDTaraZ.Level.Enter()
end

function xDTaraZ.Level.Rebirth()
    xDTaraZ.Util.Remote("Rebirth", "TryRebirthRE"):FireServer()
    xDTaraZ.Data.Get(true)
end

function xDTaraZ.Level.RebirthStep()
    local profile = xDTaraZ.Data.Get()
    local ok, needLevel = pcall(xDTaraZ.GameLib.Api(GameConfig.Rebirth.Helper).GetNeedLevel, profile.Eco.rebirth + 1)
    if ok and needLevel and profile.Eco.level >= needLevel then
        xDTaraZ.Level.Rebirth()
    end
end

function xDTaraZ.Level.ClickOnce()
    xDTaraZ.GameLib.Api(ReplicatedStorage.CTRL.TrainCTRL).TrainOnce()
end

function xDTaraZ.Level.StartClicking()
    if State.ClickLoop then return end
    State.ClickLoop = task.defer(function()
        while State.Alive and State.Opt.AutoClick do
            xDTaraZ.Scheduler.Run("AutoClick", xDTaraZ.Level.ClickOnce)
            task.wait(Config.ClickInterval)
        end
        State.ClickLoop = nil
    end)
end


function xDTaraZ.Upgrade.Names()
    local names = {}
    for name in pairs(xDTaraZ.GameLib.Need(GameConfig.Upgrade.Config)) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function xDTaraZ.Upgrade.BuySelected()
    local buy = xDTaraZ.Util.Remote("Upgrade", "UpgradeOnceRE")
    for name, selected in pairs(State.Opt.Upgrades) do
        if selected then buy:FireServer(name) end
    end
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Tower.LastRound()
    return #xDTaraZ.GameLib.Need(GameConfig.Dungeon.Config.LootTab)
end


function xDTaraZ.Tower.Enter()
    local deadline = os.clock() + 5
    while State.Entering and os.clock() < deadline do
        task.wait(0.1)
    end
    if State.InTower then return true end
    State.Entering = true
    local ok, entered = pcall(function()
        return xDTaraZ.Util.Remote("Dungeon", "TryIntoDungeonRF"):InvokeServer(1)
    end)
    State.Entering = false
    State.InTower = ok and entered and true or false
    return State.InTower
end

function xDTaraZ.Tower.Exit()
    if not State.InTower then return end
    State.InTower = false
    xDTaraZ.Util.Remote("Dungeon", "ExitDungeonRE"):FireServer()
end


function xDTaraZ.Tower.FarmStep()
    if not xDTaraZ.Tower.Enter() then return false end
    local round = xDTaraZ.Tower.LastRound()
    local start = xDTaraZ.Util.Remote("Dungeon", "StartRoundRE")
    local complete = xDTaraZ.Util.Remote("Dungeon", "CompleteRoundRF")
    start:FireServer(round)
    xDTaraZ.Util.WaitAll(Config.TowerWorkers, function()
        for _ = 1, Config.TowerCallsPerWorker do
            if complete:InvokeServer(round) then
                State.TowerLoot += 1
            end
        end
    end)
    xDTaraZ.Data.Get(true)
    return true
end


function xDTaraZ.Tower.FarmCoins(target)
    target = math.clamp(target or 10000, 100, 1000000)
    local start = (xDTaraZ.Season.Current() or {}).SeasonCoin or 0
    if not xDTaraZ.Tower.Enter() then return 0 end
    local round = xDTaraZ.Tower.LastRound()
    local startRE = xDTaraZ.Util.Remote("Dungeon", "StartRoundRE")
    local completeRF = xDTaraZ.Util.Remote("Dungeon", "CompleteRoundRF")
    local deadline = os.clock() + Config.CoinFarmTimeout
    local gained = 0
    while State.Alive and gained < target and os.clock() < deadline do
        startRE:FireServer(round)
        for _ = 1, 15 do
            if not State.Alive then break end
            local res = completeRF:InvokeServer(round)
            if res then State.TowerLoot += 1 end
        end
        xDTaraZ.Data.Get(true)
        gained = ((xDTaraZ.Season.Current() or {}).SeasonCoin or 0) - start
        task.wait(0.05)
    end
    xDTaraZ.Tower.Exit()
    return math.max(0, gained)
end


function xDTaraZ.Boss.AttackId()
    local weapon = LocalPlayer:GetAttribute("WeaponType")
    return Config.BossAttackIds[weapon] or "G_ATK_1"
end

function xDTaraZ.Boss.Join()
    xDTaraZ.Util.Remote("WorldBoss", "IntoWorldBossFightRE"):FireServer()
    local char = LocalPlayer.Character
    if char and not State.BossReturn then State.BossReturn = char:GetPivot() end
end


function xDTaraZ.Boss.StandNear(boss)
    local char = LocalPlayer.Character
    if not char then return end
    local pos = boss:GetPivot().Position
    if (char:GetPivot().Position - pos).Magnitude > Config.BossReach then
        char:PivotTo(CFrame.new(pos + Vector3.new(0, Config.BossStandHeight, Config.BossStandBack), pos))
    end
end

function xDTaraZ.Boss.Step()
    local bossName = workspace:GetAttribute("CurrentWorldBoss")
    if not bossName then return end
    local attackId = xDTaraZ.Boss.AttackId()
    if not attackId then return end
    if LocalPlayer:GetAttribute("IntoFight") ~= "WorldBoss" then
        xDTaraZ.Boss.Join()
        task.wait(Config.BossJoinSettle)
    end

    local folder = workspace:FindFirstChild("EnemyFolder_Server")
    local boss = folder and folder:FindFirstChild(bossName)
    if not boss or boss:GetAttribute("Dead") then return end
    xDTaraZ.Boss.StandNear(boss)
    local announce = xDTaraZ.Util.Remote("Attack", "UseAnyATKRE")
    local attack = xDTaraZ.Util.Remote("Attack", "AttackEnemyServiceRE")
    for _ = 1, Config.BossHitsPerTick do
        if not (State.Alive and State.Opt.AutoWorldBoss and boss.Parent) or boss:GetAttribute("Dead") then return end
        local timestamp = workspace:GetServerTimeNow()
        announce:FireServer(attackId, timestamp)
        attack:FireServer({ bossName }, { Phase = 1, SkillID = attackId, Attacker = LocalPlayer }, timestamp)
        task.wait(Config.BossHitGap)
    end
end

function xDTaraZ.Boss.ClaimCards()
    local claim = xDTaraZ.Util.Remote("WorldBoss", "TryClaimBossRewardRE")
    for card = 1, Config.BossCards do
        task.spawn(claim.FireServer, claim, tostring(card))
    end
end

function xDTaraZ.Boss.Leave()
    xDTaraZ.Util.Remote("WorldBoss", "ExitWorldBossFightRE"):FireServer()
    LocalPlayer:SetAttribute("IntoFight", nil)
    local char = LocalPlayer.Character
    if State.BossReturn and char then char:PivotTo(State.BossReturn) end
    State.BossReturn = nil
end

function xDTaraZ.Boss.Bind()
    table.insert(State.Conns, xDTaraZ.Util.Remote("WorldBoss", "BossDeadRE").OnClientEvent:Connect(function()
        if not State.Opt.AutoWorldBoss then return end
        State.BossLooting = os.clock()
        task.delay(Config.BossClaimDelay, function()
            if State.Opt.BossCards then xDTaraZ.Util.Try(xDTaraZ.Boss.ClaimCards) end
            task.wait(Config.BossHopAfter)
            xDTaraZ.Util.Try(xDTaraZ.Boss.Leave)
            State.BossDone = os.clock()
            State.BossLooting = nil
        end)
    end))
    table.insert(State.Conns, xDTaraZ.Util.Remote("WorldBoss", "BossEscapeRE").OnClientEvent:Connect(function()
        if State.Opt.AutoWorldBoss then xDTaraZ.Util.Try(xDTaraZ.Boss.Leave) end
    end))
end


function xDTaraZ.Season.Current()
    local seasons = xDTaraZ.Data.Get().Season or {}
    if seasons.Season1 then return seasons.Season1 end
    local bestKey = xDTaraZ.Util.HighestKey(seasons)
    return bestKey and seasons[bestKey] or seasons[next(seasons)]
end


function xDTaraZ.Season.Goods()
    local goods = xDTaraZ.GameLib.Need(GameConfig.Season.GoodsConfig)
    local ids = {}
    for goodId in pairs(goods) do
        table.insert(ids, goodId)
    end
    table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
    local labels, byLabel = {}, {}
    for _, goodId in ipairs(ids) do
        local good = goods[goodId]
        local label = ("%s x%d (%d coin)"):format(good.ID, good.Number, good.NeedSeasonCoin)
        byLabel[label] = goodId
        table.insert(labels, label)
    end
    return labels, byLabel
end


function xDTaraZ.Season.BuyExclusive()
    local goods = xDTaraZ.GameLib.Need(GameConfig.Season.GoodsConfig)
    local exchange = xDTaraZ.Util.Remote("Season", "ExchangeGoodsRE")
    local bought = 0
    for goodId, good in pairs(goods) do
        if not State.Alive then break end
        if good.Type ~= "Weapon" and good.Type ~= "Armor" and good.Type ~= "Hat" then continue end
        local season = xDTaraZ.Season.Current()
        local before = season and ((season.Goods or {})[goodId] or 0) or 0
        if not season or before >= (good.Store or 1) then continue end
        local short = good.NeedSeasonCoin - (season.SeasonCoin or 0)
        if short > 0 then xDTaraZ.Tower.FarmCoins(short) season = xDTaraZ.Season.Current() end
        if not season or (season.SeasonCoin or 0) < good.NeedSeasonCoin then continue end
        exchange:FireServer(goodId)
        task.wait(0.3)
        local updated = xDTaraZ.Season.Current()
        if updated and ((updated.Goods or {})[goodId] or 0) > before then bought += 1 end
    end
    xDTaraZ.Data.Get(true)
    return bought
end

function xDTaraZ.Season.BuyGoods()
    local goods = xDTaraZ.GameLib.Need(GameConfig.Season.GoodsConfig)
    local exchange = xDTaraZ.Util.Remote("Season", "ExchangeGoodsRE")
    for goodId, wanted in pairs(State.Opt.SeasonGoods) do
        local good = goods[goodId]
        if not (wanted and good) then continue end
        for _ = 1, good.Store or 1 do
            if not State.Alive then return end
            local season = xDTaraZ.Season.Current()
            local count = season and ((season.Goods or {})[goodId] or 0) or 0
            if not season or count >= (good.Store or 1) or (season.SeasonCoin or 0) < good.NeedSeasonCoin then break end
            exchange:FireServer(goodId)
            task.wait(0.2)
            local updated = xDTaraZ.Season.Current()
            if not updated or ((updated.Goods or {})[goodId] or 0) <= count then break end
        end
    end
    xDTaraZ.Data.Get(true)
end

function xDTaraZ.Season.Step()
    xDTaraZ.Util.Remote("Season", "TryClaimDailyTicRE"):FireServer()
    xDTaraZ.Util.Remote("Season", "TryClaimAllRewardRE"):FireServer()
    task.wait(0.3)
    xDTaraZ.Season.BuyGoods()
    local season = xDTaraZ.Season.Current()
    if not (season and State.Opt.SeasonSpin) then return end
    local luck = xDTaraZ.Util.Remote("Season", "LuckRE")
    for _ = 1, math.min(season.SeasonTicket or 0, math.clamp(State.Opt.SeasonSpinBatch, 1, 50)) do
        if not State.Alive or not State.Opt.AutoSeason or not State.Opt.SeasonSpin then break end
        luck:FireServer(1)
        task.wait(0.3)
    end
end

function xDTaraZ.Claim.All()
    xDTaraZ.Util.Remote("Offline", "TryClaimOfflineRewardRE"):FireServer()
    xDTaraZ.Util.Remote("Dungeon", "TryClaimDailyDunTicRE"):FireServer()
    xDTaraZ.Util.Remote("Season", "TryClaimDailyTicRE"):FireServer()
    xDTaraZ.Util.Remote("Season", "TryClaimAllRewardRE"):FireServer()
    xDTaraZ.Util.Remote("Player", "TryJoinGroupRE"):FireServer()
    xDTaraZ.Util.Try(xDTaraZ.Claim.CheckIn)
    xDTaraZ.Util.Try(xDTaraZ.Index.ClaimAll)

    local claimQuest = xDTaraZ.Util.Remote("EnhantEvent", "TryClaimQuestRE")
    local claimUpdate = xDTaraZ.Util.Remote("UpdateLog", "TryClaimUPDRewardRE")
    for id = 1, Config.ClaimIdScan do
        claimQuest:FireServer(id)
        claimUpdate:FireServer(id)
    end

    local ok, rewards = pcall(xDTaraZ.GameLib.Api(GameConfig.Online.Helper).GetOnlineRewardConfig)
    for rewardName in pairs(ok and type(rewards) == "table" and rewards or {}) do
        xDTaraZ.Util.Remote("Online", "TryClaimRE"):FireServer(rewardName)
    end
    xDTaraZ.Data.Get(true)
end


function xDTaraZ.Claim.Code(code)
    local message
    local hasListener, messageEvent = pcall(xDTaraZ.Util.Remote, "Message", "MessageRE")
    local conn = hasListener and messageEvent.OnClientEvent:Connect(function(text)
        message = message or tostring(text)
    end)
    local ok, err = pcall(function()
        return xDTaraZ.Util.Remote("Code", "TryUseCodeRF"):InvokeServer(code)
    end)
    local deadline = os.clock() + Config.CodeReplyWait
    while conn and not message and os.clock() < deadline do task.wait(0.05) end
    if conn then conn:Disconnect() end
    if not ok then return "failed: " .. tostring(err) end
    return message or "no reply"
end


function xDTaraZ.Claim.AllCodes()
    local results = {}
    for _, code in ipairs(Config.Codes) do
        table.insert(results, ("%s: %s"):format(code, xDTaraZ.Claim.Code(code)))
    end
    return table.concat(results, "\n")
end


function xDTaraZ.SuperLoot.Kill(uuid)
    if type(uuid) ~= "string" or State.LootPending[uuid] then return false end
    local folder = workspace:FindFirstChild("EnemyFolder") or workspace:FindFirstChild("EnemyFolder_Server")
    local enemy = folder and folder:FindFirstChild(uuid)
    local hp = enemy and enemy:FindFirstChild("HPValue")
    if not hp or type(hp.Value) ~= "number" then return false end

    State.LootPending[uuid] = coroutine.running()
    local ok, claimed = pcall(function()
        local hit = xDTaraZ.GameLib.Api(ReplicatedStorage.Utils.CommunicationUtils).TryGetBindableEvent("Attack", "EnemyHitBE")
        if not hit or not hit:IsA("BindableEvent") then error("EnemyHitBE unavailable", 0) end
        local attackId = xDTaraZ.Boss.AttackId() or "G_ATK_1"
        local info = { SkillID = attackId, IsCrit = State.Opt.AuraCritical, Damage = State.Opt.AuraDamage }
        local rounds = math.min(50, math.max(1, math.ceil(hp.Value)))
        for _ = 1, rounds do
            if not State.Alive then return false end
            hit:Fire(uuid, State.Opt.AuraDamage, info)
        end
        task.wait(0.1)
        local superKill = xDTaraZ.Util.FindRemote("SuperLoot", "KillSuperLootRE")
        if superKill then superKill:FireServer(uuid) end
        task.wait(0.15)
        local getOre = xDTaraZ.Util.FindRemote("Stage", "GetOreRF")
        if getOre then getOre:InvokeServer(uuid) end
        local claimAll = xDTaraZ.Util.FindRemote("Stage", "ClaimedAllOreRE")
        if claimAll then claimAll:FireServer() end
        return true
    end)
    State.LootPending[uuid] = nil
    if not ok then error(claimed, 0) end
    return claimed
end

function xDTaraZ.SuperLoot.KillExisting()
    local folders = { workspace:FindFirstChild("EnemyFolder"), workspace:FindFirstChild("EnemyFolder_Server") }
    for _, folder in ipairs(folders) do
        if not folder then continue end
        for _, enemy in ipairs(folder:GetChildren()) do
            local enemyId = enemy:GetAttribute("EnemyID")
            if type(enemyId) == "string" and enemyId:find("^Super") then
                xDTaraZ.SuperLoot.Queue(enemy.Name)
            end
        end
    end
end


function xDTaraZ.SuperLoot.Queue(uuid)
    if not State.Alive or type(uuid) ~= "string" or State.LootSeen[uuid] then return end
    if #State.LootQueue >= 256 then return end
    State.LootSeen[uuid] = true
    table.insert(State.LootQueue, uuid)
end

function xDTaraZ.SuperLoot.Step()
    local uuid = table.remove(State.LootQueue, 1)
    if not uuid then return end
    xDTaraZ.SuperLoot.Kill(uuid)
end

function xDTaraZ.SuperLoot.Bind()
    table.insert(State.Conns, xDTaraZ.Util.Remote("SuperLoot", "RefreshSuperLootRE").OnClientEvent:Connect(function(_, uuid)
        if State.Opt.SuperLootAura then
            xDTaraZ.SuperLoot.Queue(uuid)
        end
    end))
    local folder = workspace:FindFirstChild("EnemyFolder")
    if folder then
        table.insert(State.Conns, folder.ChildRemoved:Connect(function(enemy)
            State.LootSeen[enemy.Name] = nil
            State.LootPending[enemy.Name] = nil
        end))
    end
end


function xDTaraZ.Combat.KillAll()
    local hit = xDTaraZ.GameLib.Api(ReplicatedStorage.Utils.CommunicationUtils).TryGetBindableEvent("Attack", "EnemyHitBE")
    if not hit or not hit:IsA("BindableEvent") then error("EnemyHitBE unavailable", 0) end

    local damage = State.Opt.AuraDamage
    local weaponType = LocalPlayer:GetAttribute("WeaponType")
    local attackId = Config.BossAttackIds[weaponType] or "K_ATK_1"
    local hitInfo = { SkillID = attackId, IsCrit = State.Opt.AuraCritical, Damage = damage }

    local char = LocalPlayer.Character
    local origin = char and char:GetPivot().Position
    local mapWide = State.Opt.AuraMapWide or (State.Opt.AuraRange == 0)
    local range = State.Opt.AuraRange
    local burst = math.clamp(State.Opt.AuraBurst or 10, 1, 50)
    local targetFilter = State.Opt.AuraTarget or "All"

    local killed = 0
    local announce = xDTaraZ.Util.FindRemote("Attack", "UseAnyATKRE")
    local attackService = xDTaraZ.Util.FindRemote("Attack", "AttackEnemyServiceRE")
    local killEnemy = xDTaraZ.Util.FindRemote("Attack", "KillEnemyRE")
    local killSuper = xDTaraZ.Util.FindRemote("SuperLoot", "KillSuperLootRE")
    local getOre = xDTaraZ.Util.FindRemote("Stage", "GetOreRF")
    local pickStone = xDTaraZ.Util.FindRemote("Stage", "GetEnhantStoneRE")

    local folders = { workspace:FindFirstChild("EnemyFolder"), workspace:FindFirstChild("EnemyFolder_Server") }
    for _, folder in ipairs(folders) do
        if not folder then continue end
        local children = folder:GetChildren()
        for _, enemy in ipairs(children) do
            if not State.Alive or not (State.Opt.KillAura or State.Opt.AutoBattle) then return killed end
            local enemyId = tostring(enemy:GetAttribute("EnemyID") or "")
            local isSuper = enemyId:find("^Super") ~= nil
            local isBoss = folder.Name == "EnemyFolder_Server"

            if targetFilter == "Normal" and (isSuper or isBoss) then continue end
            if targetFilter == "Super" and not isSuper then continue end
            if targetFilter == "Boss" and not isBoss then continue end

            local hp = enemy:FindFirstChild("HPValue")
            if hp and type(hp.Value) == "number" and hp.Value <= 0 then continue end
            if enemy:GetAttribute("Dead") == true then continue end

            if not mapWide and origin and enemy:IsA("Model") then
                if (enemy:GetPivot().Position - origin).Magnitude > range then continue end
            end

            local name = enemy.Name
            local hitRounds = isSuper and math.min(burst, math.max(1, math.ceil(hp and hp.Value or 10))) or 1
            for _ = 1, hitRounds do
                hit:Fire(name, damage, hitInfo)
            end

            if announce and attackService then
                local now = workspace:GetServerTimeNow()
                pcall(announce.FireServer, announce, attackId, now)
                pcall(attackService.FireServer, attackService, { name }, { Phase = 1, SkillID = attackId, Attacker = LocalPlayer }, now)
            end

            if isSuper then
                if killSuper then pcall(killSuper.FireServer, killSuper, name) end
                if getOre then pcall(getOre.InvokeServer, getOre, name) end
            else
                if killEnemy then pcall(killEnemy.FireServer, killEnemy, name) end
            end

            killed += 1
            if killed >= State.Opt.AuraBatch then break end
        end
        if killed >= State.Opt.AuraBatch then break end
    end

    if State.Opt.AutoCollectDrops then
        local claimAll = xDTaraZ.Util.FindRemote("Stage", "ClaimedAllOreRE")
        if claimAll then pcall(claimAll.FireServer, claimAll) end
    end

    return killed
end

function xDTaraZ.Combat.Start()
    if State.AuraLoop then return end
    State.AuraLoop = task.defer(function()
        while State.Alive and State.Opt.KillAura do
            xDTaraZ.Scheduler.Run("KillAura", xDTaraZ.Combat.KillAll)
            task.wait(State.Opt.AuraInterval)
        end
        State.AuraLoop = nil
    end)
end


function xDTaraZ.Guard.HookDamage()
    if State.RestoreDamage then return true end
    local hpCtrl = xDTaraZ.GameLib.Require(ReplicatedStorage.CTRL.HPCTRL)
    local damageOnce = hpCtrl and hpCtrl.DamageOnce
    if type(damageOnce) ~= "function" then return false end

    hpCtrl.DamageOnce = function(target, damage)
        if target == LocalPlayer and State.Opt.GodMode then return false end
        return damageOnce(target, damage)
    end
    State.RestoreDamage = function()
        hpCtrl.DamageOnce = damageOnce
        State.RestoreDamage = nil
    end
    return true
end


function xDTaraZ.Guard.HookOreLoss()
    if State.RestoreNamecall then return true end
    local compat = xDTaraZ.Compat
    if not (compat and compat.Caps.Namecall) then return false end
    local found, lostOre = pcall(xDTaraZ.Util.Remote, "Stage", "LostAllOreRF")
    if not found then
        warn("[LootToForge] keep ore:", lostOre)
        return false
    end

    local original, restore
    original, restore = compat.HookMeta(game, "__namecall", function(self, ...)
        if self == lostOre and State.Opt.KeepOre and getnamecallmethod() == "InvokeServer" then
            return {}
        end
        return original(self, ...)
    end)
    if not original then return false end

    State.RestoreNamecall = function()
        State.RestoreNamecall = nil
        restore()
    end
    return true
end

function xDTaraZ.Guard.UnhookOreLoss()
    if State.RestoreNamecall then State.RestoreNamecall() end
end

function xDTaraZ.Guard.Stop()
    if State.RestoreDamage then State.RestoreDamage() end
    xDTaraZ.Guard.UnhookOreLoss()
end


function xDTaraZ.Race.Choices()
    local classConfig = xDTaraZ.GameLib.Need(GameConfig.Class.Config)
    local show = xDTaraZ.GameLib.Need(GameConfig.Class.Show)
    local ids = {}
    for classId in pairs(classConfig) do
        table.insert(ids, classId)
    end
    table.sort(ids, function(a, b) return classConfig[a].Weight < classConfig[b].Weight end)

    local labels, idByLabel = {}, {}
    for _, classId in ipairs(ids) do
        local label = ("%s (%s)"):format(show[classId] and show[classId].DisplayName or classId, classConfig[classId].Rarity)
        idByLabel[label] = classId
        table.insert(labels, label)
    end
    return labels, idByLabel
end


function xDTaraZ.Race.EquipBest()
    local classData = xDTaraZ.Data.Get().Class
    local classConfig = xDTaraZ.GameLib.Need(GameConfig.Class.Config)
    local bestSlot, bestWeight = nil, math.huge
    for slot, classId in pairs(classData.have) do
        local weight = classConfig[classId] and classConfig[classId].Weight or math.huge
        if weight < bestWeight then bestSlot, bestWeight = slot, weight end
    end
    if not bestSlot or tostring(bestSlot) == tostring(classData.equiped) then return false end
    xDTaraZ.Util.Remote("Class", "ChangeEquipedIndexRE"):FireServer(tostring(bestSlot))
    xDTaraZ.Data.Get(true)
    return true
end


function xDTaraZ.Race.RarityLevel(rarity)
    local ok, level = pcall(xDTaraZ.GameLib.Api(GameConfig.Rarity.Helper).GetRarityLevel, rarity)
    return ok and tonumber(level) or 0
end


function xDTaraZ.Race.Level(classId)
    local info = classId and xDTaraZ.GameLib.Need(GameConfig.Class.Config)[classId]
    return info and xDTaraZ.Race.RarityLevel(info.Rarity) or 0
end


function xDTaraZ.Race.RarityChoices()
    local seen, levels = {}, {}
    for _, info in pairs(xDTaraZ.GameLib.Need(GameConfig.Class.Config)) do
        if seen[info.Rarity] then continue end
        seen[info.Rarity] = true
        table.insert(levels, { info.Rarity, xDTaraZ.Race.RarityLevel(info.Rarity) })
    end
    table.sort(levels, function(a, b) return a[2] < b[2] end)
    local labels, byLabel = { "Off" }, {}
    for _, pair in ipairs(levels) do
        local label = pair[1] .. "+"
        table.insert(labels, label)
        byLabel[label] = pair[2]
    end
    return labels, byLabel
end


function xDTaraZ.Race.Stars(classId)
    local record = xDTaraZ.GameLib.Need(ReplicatedStorage.LocalData.ClassData).GetData().recored
    local entry = record and record[classId]
    return entry and tonumber(entry.Level) or 0
end


function xDTaraZ.Race.IsGoal(classId)
    if not classId then return false end
    local wanted = State.Opt.RaceTargets[classId]
        or (State.Opt.RaceMinLevel ~= nil and xDTaraZ.Race.Level(classId) >= State.Opt.RaceMinLevel)
    return wanted and xDTaraZ.Race.Stars(classId) >= (State.Opt.RaceStar or 0)
end


function xDTaraZ.Race.PickSlot(classData)
    local slot = State.Opt.RaceSlot == "Equipped" and tostring(classData.equiped) or State.Opt.RaceSlot:match("%d+")
    if not (slot and classData.have[slot]) then return nil, "that slot is not unlocked" end
    if classData.lock and classData.lock[slot] then return nil, "that slot is locked" end
    return slot
end


function xDTaraZ.Race.MuteAnim(muted)
    if not xDTaraZ.Compat.Caps.Connections then return end
    local event = xDTaraZ.Util.Remote("Class", "ShowLuckResultRE").OnClientEvent
    for _, conn in ipairs(getconnections(event)) do
        if muted then conn:Disable() else conn:Enable() end
    end
end


function xDTaraZ.Race.EnsureRolls(classStore)
    if (classStore.GetData().luckTimes or 0) > 0 then return true end
    if not State.Opt.RaceBuyRolls then return false end
    local config = xDTaraZ.GameLib.Need(GameConfig.Season.GoodsConfig)
    local season = xDTaraZ.Season.Current()
    for id, good in pairs(config) do
        if good.ID == "ClassRoll" and season and (season.SeasonCoin or 0) >= good.NeedSeasonCoin
            and ((season.Goods or {})[id] or 0) < (good.Store or 1) then
            xDTaraZ.Util.Remote("Season", "ExchangeGoodsRE"):FireServer(id)
            local deadline = os.clock() + Config.RaceResultWait * 2
            repeat task.wait(0.1) until not State.Alive or (classStore.GetData().luckTimes or 0) > 0 or os.clock() >= deadline
            return (classStore.GetData().luckTimes or 0) > 0
        end
    end
    return false
end


function xDTaraZ.Race.RollUntil()
    local classStore = xDTaraZ.GameLib.Need(ReplicatedStorage.LocalData.ClassData)
    local roll = xDTaraZ.Util.Remote("Class", "LuckOnceRE")
    local protectLevel = xDTaraZ.Race.RarityLevel(Config.RaceProtectRarity)
    State.RaceRolls = 0
    while State.Alive and State.Opt.AutoRace do
        local classData = classStore.GetData()
        local slot, why = xDTaraZ.Race.PickSlot(classData)
        if not slot then return "blocked", why end

        local current = classData.have[slot]
        if xDTaraZ.Race.IsGoal(current) then
            if State.Opt.RaceLock then xDTaraZ.Util.Remote("Class", "SetIndexLockRE"):FireServer(slot) end
            return "got", current
        end
        if State.Opt.RaceProtect and xDTaraZ.Race.Level(current) >= protectLevel then
            return "blocked", "this slot holds a Mythic+ race"
        end
        if not xDTaraZ.Race.EnsureRolls(classStore) then return "empty" end

        roll:FireServer(slot)
        State.RaceRolls += 1
        local deadline = os.clock() + Config.RaceResultWait
        repeat task.wait() until classStore.GetData().have[slot] ~= current or os.clock() > deadline
        task.wait(Config.RaceRollDelay)
    end
    return "stopped"
end


function xDTaraZ.Pet.Store(refresh)
    local profile = xDTaraZ.Data.Get(refresh)
    return profile and profile.Pet or {}
end


function xDTaraZ.Pet.Rarity(petId)
    local cfg = xDTaraZ.GameLib.Need(GameConfig.Pet.Config)[petId]
    return cfg and cfg.Rarity
end


function xDTaraZ.Pet.Score(entry)
    if type(entry) ~= "table" or entry.Type ~= "Pet" then return -1 end
    local cfg = xDTaraZ.GameLib.Need(GameConfig.Pet.Config)[entry.ID]
    if not cfg then return 0 end
    local rarityLv = xDTaraZ.Race.RarityLevel(cfg.Rarity)
    local boostSum = 0
    local ok, boosts = pcall(xDTaraZ.GameLib.Api(ReplicatedStorage.Utils.BalanceUtils).GetPetBoosts, entry)
    if ok and type(boosts) == "table" then
        for _, val in pairs(boosts) do
            if type(val) == "number" then boostSum += val end
        end
    end
    local skills = type(entry.ExtraSkill) == "table" and #entry.ExtraSkill or 0
    return rarityLv * 10000 + boostSum * 1000 + (entry.Level or 1) * 10 + skills * 500 + xDTaraZ.Util.Tier(entry.ID)
end

function xDTaraZ.Pet.ResetVFX()
    pcall(function()
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local openGui = gui and gui:FindFirstChild("OpenEggGui")
        if openGui and openGui.Enabled then
            local vfx = ReplicatedStorage:FindFirstChild("GuiUtils")
                and ReplicatedStorage.GuiUtils:FindFirstChild("PetGUI")
                and ReplicatedStorage.GuiUtils.PetGUI:FindFirstChild("OpenEggVFX")
            if vfx then xDTaraZ.GameLib.Api(vfx).Reset() end
        end
    end)
end


function xDTaraZ.Pet.MuteAnim(muted)
    if xDTaraZ.Compat and xDTaraZ.Compat.Caps.Connections then
        local remote = xDTaraZ.Util.FindRemote("Pet", "ShowLuckResult")
        if remote and remote:IsA("RemoteEvent") then
            for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                if muted then conn:Disable() else conn:Enable() end
            end
        end
    end
    if muted then xDTaraZ.Pet.ResetVFX() end
end

function xDTaraZ.Pet.Bind()
    local remote = xDTaraZ.Util.FindRemote("Pet", "ShowLuckResult")
    if remote and remote:IsA("RemoteEvent") then
        table.insert(State.Conns, remote.OnClientEvent:Connect(function()
            if State.Opt.SkipEggAnim then
                task.defer(xDTaraZ.Pet.ResetVFX)
                task.delay(0.15, xDTaraZ.Pet.ResetVFX)
            end
        end))
    end
end


function xDTaraZ.Pet.Counts(petStore)
    petStore = petStore or xDTaraZ.Pet.Store()
    local pets, eggs = 0, 0
    for _, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" then
            pets += 1
        elseif entry.Type == "Egg" and not entry.HatchReadyTick then
            eggs += 1
        end
    end
    return pets, eggs
end


function xDTaraZ.Pet.TrimEggs(preferEggId)
    local petStore = xDTaraZ.Pet.Store()
    local byId, totalEggs = {}, 0
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Egg" and not entry.HatchReadyTick then
            byId[entry.ID] = byId[entry.ID] or {}
            table.insert(byId[entry.ID], uuid)
            totalEggs += 1
        end
    end
    local deleteRE = xDTaraZ.Util.Remote("Pet", "DeleteRE")
    local deleted = 0
    local keepLimit = math.max(1, State.Opt.KeepPerEgg or 10)
    local maxEggs = petStore.maxEggNum or 25
    for eggId, list in pairs(byId) do
        local limit = keepLimit
        if preferEggId and eggId ~= preferEggId and totalEggs >= maxEggs - 3 then
            limit = math.min(limit, math.max(2, math.floor(maxEggs / 4)))
        end
        for i = limit + 1, #list do
            deleteRE:FireServer(list[i])
            deleted += 1
            totalEggs -= 1
        end
    end
    if deleted > 0 then xDTaraZ.Data.Get(true) end
    return deleted
end


function xDTaraZ.Pet.CleanBag()
    local petStore = xDTaraZ.Pet.Store()
    local protected = {}
    for _, uuid in pairs(petStore.equiped or {}) do
        protected[uuid] = true
    end
    local allPets = {}
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" then
            if entry.DeployStartTick then protected[uuid] = true end
            table.insert(allPets, { uuid = uuid, entry = entry, score = xDTaraZ.Pet.Score(entry) })
        end
    end
    table.sort(allPets, function(a, b) return a.score > b.score end)
    for i = 1, math.min(#allPets, math.max(1, State.Opt.KeepBestPets or 6)) do
        protected[allPets[i].uuid] = true
    end
    local deleteRE = xDTaraZ.Util.Remote("Pet", "DeleteRE")
    local deletedPets = 0
    for _, item in ipairs(allPets) do
        local rarity = xDTaraZ.Pet.Rarity(item.entry.ID)
        if not protected[item.uuid] and State.Opt.DeletePetRarities[rarity] then
            deleteRE:FireServer(item.uuid)
            deletedPets += 1
        end
    end
    local deletedEggs = State.Opt.AutoDeleteEggs and xDTaraZ.Pet.TrimEggs() or 0
    if deletedPets > 0 then xDTaraZ.Data.Get(true) end
    return deletedPets, deletedEggs
end


function xDTaraZ.Pet.HatchStep()
    xDTaraZ.Pet.MuteAnim(true)
    local petStore = xDTaraZ.Pet.Store()
    local now = (workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or (workspace:GetAttribute("ServerTime") or os.time())
    local petCount = xDTaraZ.Pet.Counts(petStore)
    local maxPet = petStore.maxPetNum or 25

    if petCount >= maxPet - 2 or State.Opt.AutoSellPet then
        xDTaraZ.Pet.CleanBag()
        petStore = xDTaraZ.Pet.Store(true)
        petCount = xDTaraZ.Pet.Counts(petStore)
    end

    local openRE = xDTaraZ.Util.Remote("Pet", "TryOpenEggRE")
    local hatchRE = xDTaraZ.Util.Remote("Pet", "TryHatchEggRE")
    local opened = 0

    
    for _, uuid in pairs(petStore.hatched or {}) do
        local entry = petStore.have and petStore.have[uuid]
        if entry and (entry.HatchReadyTick or 0) <= now and petCount + opened < maxPet then
            openRE:FireServer(uuid)
            opened += 1
        end
    end

    if opened > 0 then
        xDTaraZ.Pet.ResetVFX()
        petStore = xDTaraZ.Pet.Store(true)
        petCount = xDTaraZ.Pet.Counts(petStore)
    end

    
    local usedSlots = 0
    for _ in pairs(petStore.hatched or {}) do usedSlots += 1 end
    local maxHatch = petStore.maxHatchNum or 3
    local freeSlots = math.max(0, maxHatch - usedSlots)
    local hatched = 0

    if freeSlots > 0 then
        local targetEggId = "Egg2"
        if State.Opt.TargetPet and State.PetTargetLabels and State.PetTargetLabels[State.Opt.TargetPet] then
            local pId = State.PetTargetLabels[State.Opt.TargetPet]
            local eggCfg = xDTaraZ.GameLib.Need(GameConfig.Egg.Config)
            for eggId, data in pairs(eggCfg or {}) do
                if data.PetList then
                    for _, item in ipairs(data.PetList) do
                        local subId = type(item) == "table" and (item.ID or item[1]) or item
                        if subId == pId then targetEggId = eggId break end
                    end
                end
            end
        end

        local candidates = {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Egg" and not entry.HatchReadyTick then
                table.insert(candidates, {
                    uuid = uuid,
                    id = entry.ID,
                    isTarget = (entry.ID == targetEggId),
                    tier = xDTaraZ.Util.Tier(entry.ID)
                })
            end
        end
        table.sort(candidates, function(a, b)
            if a.isTarget ~= b.isTarget then return a.isTarget end
            if State.Opt.HatchBestFirst then return a.tier > b.tier end
            return a.tier < b.tier
        end)

        for i = 1, math.min(freeSlots, #candidates) do
            hatchRE:FireServer(candidates[i].uuid)
            hatched += 1
        end
    end

    if hatched > 0 or opened > 0 then
        xDTaraZ.Data.Get(true)
        xDTaraZ.Pet.ResetVFX()
    end

    if State.Opt.AutoDeleteEggs then xDTaraZ.Pet.TrimEggs() end
    return opened, hatched
end


function xDTaraZ.Pet.InstantHatchAll()
    xDTaraZ.Pet.MuteAnim(true)
    local petStore = xDTaraZ.Pet.Store(true)
    local openRE = xDTaraZ.Util.Remote("Pet", "TryOpenEggRE")
    local hatchRE = xDTaraZ.Util.Remote("Pet", "TryHatchEggRE")
    local now = (workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or (workspace:GetAttribute("ServerTime") or os.time())
    local maxPet = petStore.maxPetNum or 25
    
    xDTaraZ.Pet.CleanBag()
    petStore = xDTaraZ.Pet.Store(true)

    local opened, hatched = 0, 0
    
    for _, uuid in pairs(petStore.hatched or {}) do
        local entry = petStore.have and petStore.have[uuid]
        if entry and (entry.HatchReadyTick or 0) <= now then
            openRE:FireServer(uuid)
            opened += 1
        end
    end

    if opened > 0 then
        xDTaraZ.Pet.ResetVFX()
        petStore = xDTaraZ.Pet.Store(true)
    end

    
    local usedSlots = 0
    for _ in pairs(petStore.hatched or {}) do usedSlots += 1 end
    local maxHatch = petStore.maxHatchNum or 3
    local freeSlots = math.max(0, maxHatch - usedSlots)

    if freeSlots > 0 then
        local candidates = {}
        for uuid, entry in pairs(petStore.have or {}) do
            if entry.Type == "Egg" and not entry.HatchReadyTick then
                table.insert(candidates, { uuid = uuid, tier = xDTaraZ.Util.Tier(entry.ID) })
            end
        end
        table.sort(candidates, function(a, b) return a.tier > b.tier end)
        for i = 1, math.min(freeSlots, #candidates) do
            hatchRE:FireServer(candidates[i].uuid)
            hatched += 1
        end
    end

    xDTaraZ.Pet.ResetVFX()
    xDTaraZ.Data.Get(true)
    if State.Opt.AutoEquipPet then xDTaraZ.Pet.EquipBest() end
    if State.Opt.AutoFeedPet then xDTaraZ.Pet.FeedBest() end
    return opened, hatched
end


function xDTaraZ.Pet.Choices()
    local labels, ids = {}, {}
    local petFolder = GameConfig:FindFirstChild("Pet")
    local petShow = petFolder and petFolder:FindFirstChild("Show") and xDTaraZ.GameLib.Require(petFolder.Show)
    local petCfg = petFolder and petFolder:FindFirstChild("Config") and xDTaraZ.GameLib.Require(petFolder.Config)
    if petShow or petCfg then
        local petIds = {}
        local allPetKeys = {}
        if petShow then for id in pairs(petShow) do allPetKeys[id] = true end end
        if petCfg then for id in pairs(petCfg) do allPetKeys[id] = true end end
        for id in pairs(allPetKeys) do petIds[#petIds + 1] = id end
        table.sort(petIds, function(a, b)
            local rA = petCfg and petCfg[a] and petCfg[a].Rarity or ""
            local rB = petCfg and petCfg[b] and petCfg[b].Rarity or ""
            local lvA = xDTaraZ.Race.RarityLevel(rA)
            local lvB = xDTaraZ.Race.RarityLevel(rB)
            if lvA ~= lvB then return lvA > lvB end
            return xDTaraZ.Util.Tier(a) > xDTaraZ.Util.Tier(b)
        end)
        for _, id in ipairs(petIds) do
            local name = petShow and petShow[id] and (petShow[id].DisplayName or petShow[id].Name) or (petCfg and petCfg[id] and petCfg[id].Name) or id
            local rarity = petCfg and petCfg[id] and petCfg[id].Rarity or "Pet"
            local label = "[" .. rarity .. "] " .. name .. " (" .. id .. ")"
            labels[#labels + 1] = label
            ids[label] = id
        end
    end
    State.PetTargetLabels = ids
    return labels
end


function xDTaraZ.Pet.LockAllGodPets()
    local petStore = xDTaraZ.Pet.Store(true)
    local lockRE = xDTaraZ.Util.Remote("Backpack", "SetLockRE")
    local locked = 0
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" and not entry.Lock then
            local rarity = xDTaraZ.Pet.Rarity(entry.ID)
            local rarityLv = xDTaraZ.Race.RarityLevel(rarity)
            if rarityLv >= 4 or table.find(petStore.equiped or {}, uuid) then
                lockRE:FireServer(uuid, true)
                locked += 1
            end
        end
    end
    return locked
end


function xDTaraZ.Pet.FarmAndHatchTarget(targetPetId, neededCount)
    neededCount = math.max(1, math.floor(neededCount or 1))
    local eggCfg = xDTaraZ.GameLib.Need(GameConfig.Egg.Config)
    local targetEggId = "Egg2"
    for eggId, data in pairs(eggCfg or {}) do
        if data.PetList then
            for _, item in ipairs(data.PetList) do
                local pId = type(item) == "table" and (item.ID or item[1]) or item
                if pId == targetPetId then
                    targetEggId = eggId
                    break
                end
            end
        end
    end

    
    local store = xDTaraZ.Pet.Store(true)
    local targetEggCount = 0
    for _, entry in pairs(store.have or {}) do
        if entry.Type == "Egg" and entry.ID == targetEggId and not entry.HatchReadyTick then
            targetEggCount += 1
        end
    end

    if targetEggCount < 5 then
        xDTaraZ.Pet.TrimEggs(targetEggId)
        xDTaraZ.Stage.FarmTurbo(targetEggId, "Egg", 15)
        store = xDTaraZ.Pet.Store(true)
    end

    
    local opened, hatched = xDTaraZ.Pet.HatchStep()

    store = xDTaraZ.Pet.Store(true)
    local now = (workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or (workspace:GetAttribute("ServerTime") or os.time())
    local minDiff = math.huge
    for _, u in pairs(store.hatched or {}) do
        local it = store.have and store.have[u]
        if it and it.HatchReadyTick then
            local diff = math.max(0, it.HatchReadyTick - now)
            if diff < minDiff then minDiff = diff end
        end
    end

    local newlyGained = 0
    for uuid, entry in pairs(store.have or {}) do
        if entry.Type == "Pet" and entry.ID == targetPetId then
            newlyGained += 1
            if State.Opt.AutoLockTargetPet and not entry.Lock then
                xDTaraZ.Util.Remote("Backpack", "SetLockRE"):FireServer(uuid, true)
            end
        end
    end

    if newlyGained > 0 then
        xDTaraZ.Pet.EquipBest()
        xDTaraZ.Pet.FeedAllMax()
        return newlyGained, ("Acquired %s!"):format(targetPetId)
    end

    if minDiff < math.huge then
        return 0, ("Incubating %s (%ds left)"):format(targetEggId, minDiff)
    end
    return 0, "No eggs incubating"
end

function xDTaraZ.Pet.ChaseStep()
    if not State.Opt.AutoChaseTargetPet then return end
    local picked = State.PetTargetLabels and State.PetTargetLabels[State.Opt.TargetPet]
    if not picked then return end
    local gained = xDTaraZ.Pet.FarmAndHatchTarget(picked, State.Opt.TargetPetCopies or 1)
    if gained >= (State.Opt.TargetPetCopies or 1) then
        State.Opt.AutoChaseTargetPet = false
        if Library and Library.Options and Library.Options.AutoChaseTargetPet then
            Library.Options.AutoChaseTargetPet:SetValue(false)
        end
    end
end

function xDTaraZ.Pet.InfiniteLoopStep()
    local petStore = xDTaraZ.Pet.Store(true)
    local pets, eggs = xDTaraZ.Pet.Counts(petStore)
    local maxEggs = petStore.maxEggNum or 25
    if eggs < maxEggs - 5 then
        xDTaraZ.Stage.FarmEggsAndFood(20)
    end
    xDTaraZ.Pet.HatchStep()
    xDTaraZ.Pet.EquipBest()
    xDTaraZ.Pet.FeedBest()
    xDTaraZ.Pet.DeployStep()
end


function xDTaraZ.Pet.EquipBest()
    local petStore = xDTaraZ.Pet.Store()
    local owned = {}
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" then
            table.insert(owned, { uuid = uuid, score = xDTaraZ.Pet.Score(entry) })
        end
    end
    if #owned == 0 then return 0 end
    table.sort(owned, function(a, b) return a.score > b.score end)

    local maxEquip = petStore.maxEquipNum or 1
    local wanted, wantedList = {}, {}
    for i = 1, math.min(maxEquip, #owned) do
        wanted[owned[i].uuid] = owned[i].score
        table.insert(wantedList, owned[i])
    end

    local currentSet = {}
    for _, uuid in pairs(petStore.equiped or {}) do
        currentSet[uuid] = true
    end

    local equipRE = xDTaraZ.Util.Remote("Pet", "IsEquipPetRE")
    local changed = 0
    for uuid in pairs(currentSet) do
        if not wanted[uuid] then
            local entry = petStore.have and petStore.have[uuid]
            local curScore = entry and xDTaraZ.Pet.Score(entry) or -1
            local bestReplacement = wantedList[1]
            if bestReplacement and bestReplacement.score > curScore then
                equipRE:FireServer(uuid, false)
                currentSet[uuid] = nil
            end
        end
    end
    for _, item in ipairs(wantedList) do
        if not currentSet[item.uuid] then
            equipRE:FireServer(item.uuid, true)
            changed += 1
        end
    end
    if changed > 0 then xDTaraZ.Data.Get(true) end
    return changed
end


function xDTaraZ.Pet.FeedBest()
    local profile = xDTaraZ.Data.Get()
    local petStore = profile.Pet or {}
    local foodCfg = xDTaraZ.GameLib.Need(GameConfig.Food.Config)
    local petHelper = xDTaraZ.GameLib.Api(GameConfig.Pet.Helper)
    local foods = {}
    for uuid, entry in pairs(profile.Backpack.have or {}) do
        local count = math.floor(entry.Number or 0)
        local info = entry.Type == "Food" and foodCfg[entry.ID]
        if info and count >= 1 and (info.Exp or 0) > 0 then
            table.insert(foods, { uuid = uuid, count = count, exp = info.Exp })
        end
    end
    if #foods == 0 then return 0 end
    table.sort(foods, function(a, b) return a.exp > b.exp end)

    local equippedSet = {}
    for _, uuid in pairs(petStore.equiped or {}) do equippedSet[uuid] = true end
    local targets = {}
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" and not petHelper.CheckLevelIsMax(entry.Level or 1, entry.ID) then
            local priority = (equippedSet[uuid] and 1e9 or 0) + (entry.DeployStartTick and 1e8 or 0) + xDTaraZ.Pet.Score(entry)
            table.insert(targets, { uuid = uuid, entry = entry, priority = priority })
        end
    end
    if #targets == 0 then return 0 end
    table.sort(targets, function(a, b) return a.priority > b.priority end)

    local target = targets[1]
    local maxLv = petHelper.GetMaxLevel(target.entry.ID) or 20
    local needExp = -(target.entry.Exp or 0)
    for lv = (target.entry.Level or 1) + 1, maxLv do
        needExp += (petHelper.GetNeedExp(lv) or 0)
    end
    if needExp <= 0 then return 0 end

    local feedMap, usedAny = {}, false
    for _, food in ipairs(foods) do
        if needExp <= 0 then break end
        local use = math.min(food.count, math.max(1, math.ceil(needExp / food.exp)))
        if use > 0 then
            feedMap[food.uuid] = use
            needExp -= use * food.exp
            usedAny = true
        end
    end
    if not usedAny then return 0 end
    xDTaraZ.Util.Remote("Pet", "FeedPetRE"):FireServer(target.uuid, feedMap)
    xDTaraZ.Data.Get(true)
    return 1
end


function xDTaraZ.Pet.FeedAllMax()
    local totalFed = 0
    for _ = 1, 15 do
        local fed = xDTaraZ.Pet.FeedBest()
        if fed <= 0 then break end
        totalFed += fed
        task.wait(0.05)
    end
    return totalFed
end


function xDTaraZ.Pet.DeployStep()
    local petStore = xDTaraZ.Pet.Store()
    if type(petStore.deployRewardList) == "table" and next(petStore.deployRewardList) ~= nil then
        xDTaraZ.Util.Remote("Pet", "ClaimAllDeployRewardRE"):FireServer()
    end
    local deployedCount = 0
    local candidates = {}
    for uuid, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" then
            if entry.DeployStartTick then
                deployedCount += 1
            else
                table.insert(candidates, { uuid = uuid, score = xDTaraZ.Pet.Score(entry) })
            end
        end
    end
    local freeSlots = (petStore.maxDeployNum or 2) - deployedCount
    if freeSlots <= 0 or #candidates == 0 then return 0 end
    table.sort(candidates, function(a, b) return a.score > b.score end)
    local deployRE = xDTaraZ.Util.Remote("Pet", "IsDeployPetRE")
    local deployed = 0
    for i = 1, math.min(freeSlots, #candidates) do
        deployRE:FireServer(candidates[i].uuid, true)
        deployed += 1
    end
    if deployed > 0 then xDTaraZ.Data.Get(true) end
    return deployed
end


function xDTaraZ.Pet.StatusText(profile)
    local prof = profile or xDTaraZ.Data.Get() or {}
    local petStore = prof.Pet or {}
    local pets, eggs = xDTaraZ.Pet.Counts(petStore)
    local hatched = 0
    for _ in pairs(petStore.hatched or {}) do hatched += 1 end
    local deployed = 0
    for _, entry in pairs(petStore.have or {}) do
        if entry.Type == "Pet" and entry.DeployStartTick then deployed += 1 end
    end
    local equippedNames = {}
    local petShow = GameConfig:FindFirstChild("Pet") and GameConfig.Pet:FindFirstChild("Show") and xDTaraZ.GameLib.Require(GameConfig.Pet.Show)
    for _, uuid in pairs(petStore.equiped or {}) do
        local entry = petStore.have and petStore.have[uuid]
        if entry then
            local name = petShow and petShow[entry.ID] and petShow[entry.ID].DisplayName or entry.ID or "Pet"
            table.insert(equippedNames, ("%s Lv.%d"):format(tostring(name), tonumber(entry.Level) or 1))
        end
    end
    local eqText = #equippedNames > 0 and table.concat(equippedNames, ", ") or "None"
    local now = (workspace.GetServerTimeNow and workspace:GetServerTimeNow()) or (workspace:GetAttribute("ServerTime") or os.time())
    local hatchTimers = {}
    for _, uuid in pairs(petStore.hatched or {}) do
        local entry = petStore.have and petStore.have[uuid]
        if entry and entry.HatchReadyTick then
            local diff = math.max(0, math.floor(entry.HatchReadyTick - now))
            table.insert(hatchTimers, diff .. "s")
        end
    end
    local hatchDetail = #hatchTimers > 0 and (" (" .. table.concat(hatchTimers, ", ") .. ")") or ""
    return string.format(
        "Pet: %s\nBags: %d/%d Pets · %d/%d Eggs | Hatch: %d/%d%s | Deploy: %d/%d",
        tostring(eqText),
        tonumber(pets) or 0, tonumber(petStore.maxPetNum) or 25,
        tonumber(eggs) or 0, tonumber(petStore.maxEggNum) or 25,
        tonumber(hatched) or 0, tonumber(petStore.maxHatchNum) or 3,
        tostring(hatchDetail or ""),
        tonumber(deployed) or 0, tonumber(petStore.maxDeployNum) or 2
    )
end


function xDTaraZ.Movement.Humanoid()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
end

function xDTaraZ.Movement.Apply()
    local hum = xDTaraZ.Movement.Humanoid()
    if not hum then return end
    hum.WalkSpeed = State.Opt.SpeedOn and State.Opt.WalkSpeed or (LocalPlayer:GetAttribute("OriWalkSpeed") or 22)
end

function xDTaraZ.Movement.Bind()
    table.insert(State.Conns, UserInputService.JumpRequest:Connect(function()
        local hum = xDTaraZ.Movement.Humanoid()
        if State.Opt.InfJump and hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))
    table.insert(State.Conns, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        xDTaraZ.Movement.Apply()
    end))
end


function xDTaraZ.Session.SetLowGraphics(enabled)
    RunService:Set3dRenderingEnabled(not enabled)
end

function xDTaraZ.Session.Rejoin()
    local queue = queue_on_teleport or queueonteleport
    if queue then queue(Config.ReloadSource) end
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end


function xDTaraZ.Session.HopSmallest()
    local body = xDTaraZ.Util.HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
    local ok, list = pcall(HttpService.JSONDecode, HttpService, body or "")
    local best
    for _, server in ipairs(ok and type(list) == "table" and type(list.data) == "table" and list.data or {}) do
        if server.id == game.JobId or server.playing >= server.maxPlayers then continue end
        if not best or server.playing < best.playing then best = server end
    end
    if not best then return false end
    local queue = queue_on_teleport or queueonteleport
    if queue then queue(Config.ReloadSource) end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
    return true
end


function xDTaraZ.Session.SavePosition()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    State.SavedSpot = root and root.CFrame
    return State.SavedSpot ~= nil
end


function xDTaraZ.Session.ReturnPosition()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not (root and State.SavedSpot) then return false end
    root.CFrame = State.SavedSpot
    return true
end


function xDTaraZ.Boss.HopFlag(enabled)
    local flag = Config.SaveFolder .. "/" .. Config.BossHopFlag
    pcall(function()
        if enabled then
            if not isfolder(Config.SaveFolder) then makefolder(Config.SaveFolder) end
            writefile(flag, tostring(os.time()))
        elseif isfile(flag) then
            delfile(flag)
        end
    end)
end


function xDTaraZ.Boss.SinceLastHop()
    local ok, stamp = pcall(readfile, Config.SaveFolder .. "/" .. Config.BossHopFlag)
    if not ok or not tonumber(stamp) then return nil end
    return os.time() - tonumber(stamp)
end


function xDTaraZ.Boss.HopWanted()
    local since = xDTaraZ.Boss.SinceLastHop()
    return since ~= nil and since < Config.BossHopResume
end


function xDTaraZ.Boss.LoadServers()
    local ok, text = pcall(readfile, Config.SaveFolder .. "/" .. Config.BossHopServers)
    if not ok then return {}, 0 end
    local decoded
    ok, decoded = pcall(HttpService.JSONDecode, HttpService, text)
    if not ok or type(decoded) ~= "table" or type(decoded.ids) ~= "table" then return {}, 0 end
    local fetchedAt = tonumber(decoded.at) or 0
    if os.time() - fetchedAt > Config.HopListTtl then return {}, 0 end
    return decoded.ids, fetchedAt
end


function xDTaraZ.Boss.SaveServers(ids, fetchedAt)
    pcall(function()
        if not isfolder(Config.SaveFolder) then makefolder(Config.SaveFolder) end
        writefile(Config.SaveFolder .. "/" .. Config.BossHopServers, HttpService:JSONEncode({ at = fetchedAt, ids = ids }))
    end)
end


function xDTaraZ.Boss.FetchServers()
    if os.clock() < State.HopBlockedUntil then return {} end
    local body = xDTaraZ.Util.HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
    local ok, list = pcall(HttpService.JSONDecode, HttpService, body or "")
    local ids = {}
    for _, server in ipairs(ok and type(list) == "table" and type(list.data) == "table" and list.data or {}) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(ids, server.id) end
    end
    if #ids > 0 then
        State.HopFails, State.HopBackoff = 0, nil
        return ids
    end
    State.HopFails += 1
    State.HopBackoff = math.min((State.HopBackoff or Config.HopBackoffStart / 2) * 2, Config.HopBackoffMax)
    State.HopBlockedUntil = os.clock() + State.HopBackoff
    warn("[LootToForge] server list refused, retry in", State.HopBackoff, "s, fail", State.HopFails)
    return {}
end


function xDTaraZ.Boss.PickServer()
    local ids, fetchedAt = xDTaraZ.Boss.LoadServers()
    if #ids == 0 then
        ids, fetchedAt = xDTaraZ.Boss.FetchServers(), os.time()
    end
    while #ids > 0 do
        local serverId = table.remove(ids, math.random(#ids))
        if serverId ~= game.JobId then
            xDTaraZ.Boss.SaveServers(ids, fetchedAt)
            return serverId
        end
    end
    xDTaraZ.Boss.SaveServers(ids, fetchedAt)
    return nil
end

function xDTaraZ.Boss.Hop()
    local serverId = xDTaraZ.Boss.PickServer()
    if not serverId then return end
    State.BossHopping = os.clock()
    xDTaraZ.Boss.HopFlag(true)
    local queue = queue_on_teleport or queueonteleport
    if queue and not State.HopQueued then
        queue(Config.ReloadSource)
        State.HopQueued = true
    end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
end


function xDTaraZ.Boss.WorthStaying()
    if State.BossLooting and os.clock() - State.BossLooting < Config.BossLootTimeout then return true end
    local boss = workspace:GetAttribute("CurrentWorldBoss")
    if boss and not State.BossDone then return true end
    if State.BossDone then return os.clock() - State.BossDone < Config.BossHopAfter end
    local nextTick, serverTime = workspace:GetAttribute("NextWorldBossTick"), workspace:GetAttribute("ServerTime")
    if not nextTick or not serverTime then return true end
    return nextTick - serverTime <= State.Opt.BossWaitMinutes * 60
end

function xDTaraZ.Boss.HopGiveUp()
    State.Opt.BossHop = false
    xDTaraZ.Boss.HopFlag(false)
    table.insert(State.Halted, { "BossHop", "no server list from Roblox, try again later" })
end

function xDTaraZ.Boss.HopStep()
    if State.BossHopping then
        if os.clock() - State.BossHopping < Config.HopStall then return end
        State.BossHopping = false
    end
    if xDTaraZ.Boss.WorthStaying() then return end
    if (xDTaraZ.Boss.SinceLastHop() or Config.HopGap) < Config.HopGap then return end
    if State.HopFails >= Config.HopGiveUp then
        xDTaraZ.Boss.HopGiveUp()
        return
    end
    xDTaraZ.Boss.Hop()
end

function xDTaraZ.Session.Bind()
    table.insert(State.Conns, TeleportService.TeleportInitFailed:Connect(function()
        if not State.BossHopping then return end
        State.BossHopping = false
        task.delay(1, xDTaraZ.Util.Try, xDTaraZ.Boss.HopStep)
    end))
    table.insert(State.Conns, LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end))
    table.insert(State.Conns, GuiService.ErrorMessageChanged:Connect(function(msg)
        if State.Opt.AutoRejoin and msg ~= "" and not State.Rejoining then
            State.Rejoining = true
            task.delay(Config.RejoinDelay, xDTaraZ.Session.Rejoin)
        end
    end))
end

xDTaraZ.Scheduler.Jobs = {
    { key = "SuperLootAura", every = Config.KillAuraInterval, run = function() xDTaraZ.SuperLoot.Step() end },
    { key = "AutoBattle", every = Config.KillAuraInterval, run = function() xDTaraZ.Stage.BattleStep() end },
    { key = "AutoCheckIn", every = Config.ClaimInterval, run = function() xDTaraZ.Claim.CheckIn() end },
    { key = "MaxGear", every = 0, run = function() xDTaraZ.Gear.MaxStep() end },
    { key = "CollectOre", every = 0, run = function() xDTaraZ.Stage.Collect(State.Opt.Stage or xDTaraZ.Stage.Best(), State.Opt.CollectRarities) end },
    { key = "AutoForge", every = 0, run = function() xDTaraZ.Forge.Step() end },
    { key = "AutoEquip", every = Config.EquipInterval, run = function() xDTaraZ.Gear.EquipBest() end },
    { key = "AutoSell", every = Config.SellInterval, run = function() xDTaraZ.Sell.Run(xDTaraZ.Data.Get()) end },
    { key = "AutoTrain", every = 1, run = function() xDTaraZ.Level.TrainStep() end },
    { key = "AutoRebirth", every = Config.RebirthInterval, run = function() xDTaraZ.Level.RebirthStep() end },
    { key = "AutoUpgrade", every = Config.UpgradeInterval, run = function() xDTaraZ.Upgrade.BuySelected() end },
    { key = "AutoTower", every = 0, run = function() xDTaraZ.Tower.FarmStep() end },
    { key = "AutoWorldBoss", every = Config.BossInterval, run = function() xDTaraZ.Boss.Step() end },
    { key = "BossHop", every = Config.BossHopInterval, run = function() xDTaraZ.Boss.HopStep() end },
    { key = "AutoClaim", every = Config.ClaimInterval, run = function() xDTaraZ.Claim.All() end },
    { key = "AutoSeason", every = Config.SeasonInterval, run = function() xDTaraZ.Season.Step() end },
    { key = "AutoTokenShop", every = Config.TokenShopInterval, run = function() xDTaraZ.TokenShop.BuyAll() end },
    { key = "AutoBestRace", every = 10, run = function() xDTaraZ.Race.EquipBest() end },
    { key = "TurboSpawn", every = 0, run = function() xDTaraZ.Spawn.TurboStep() end },
    { key = "AutoChaseTargetPet", every = 1, run = function() xDTaraZ.Pet.ChaseStep() end },
    { key = "AutoHatchEgg", every = 1, run = function() xDTaraZ.Pet.HatchStep() end },
    { key = "AutoEquipPet", every = Config.PetInterval, run = function() xDTaraZ.Pet.EquipBest() end },
    { key = "AutoFeedPet", every = Config.PetInterval, run = function() xDTaraZ.Pet.FeedBest() end },
    { key = "AutoDeployPet", every = Config.PetDeployInterval, run = function() xDTaraZ.Pet.DeployStep() end },
    { key = "AutoSellPet", every = Config.SellInterval, run = function() xDTaraZ.Pet.CleanBag() end },
    { key = "AutoIndex", every = Config.IndexInterval, run = function() xDTaraZ.Util.Exclusive("Index", xDTaraZ.Index.HuntAll) end },
}


function xDTaraZ.Scheduler.Run(key, fn)
    if not State.Alive or State.JobRunning[key] then return end
    local result
    local thread = task.defer(function() result = table.pack(pcall(fn)) end)
    State.JobRunning[key] = thread
    local deadline = os.clock() + State.Opt.JobTimeout
    local toggleJob = type(State.Opt[key]) == "boolean"
    while State.Alive and (not toggleJob or State.Opt[key]) and not result and os.clock() < deadline do task.wait(0.05) end
    if not result then
        xDTaraZ.Util.CancelTree(thread)
        result = { false, "job timed out" }
    end
    State.JobRunning[key] = nil
    if not State.Alive or (toggleJob and not State.Opt[key]) then return end
    local ok, err = result[1], result[2]
    State.JobStats[key] = { ok = ok, at = os.clock(), error = not ok and tostring(err) or nil }
    local failures = State.Failures
    if ok then
        failures[key] = nil
        return
    end

    local streak = failures[key]
    if not streak then
        streak = { count = 0, since = os.clock() }
        failures[key] = streak
        xDTaraZ.Util.WarnJob(key, err)
    end
    streak.count += 1
    if streak.count < Config.MaxFailures or os.clock() - streak.since < Config.FailWindow then return end

    failures[key] = nil
    State.Opt[key] = false
    local reason = tostring(err):match("[^\n]*")
    warn("[LootToForge]", key, "stopped:", reason)
    table.insert(State.Halted, { key, reason })
end

xDTaraZ.Scheduler.Groups = {
    SuperLootAura = "combat", KillAura = "combat", AutoBattle = "combat", AutoWorldBoss = "combat",
    AutoTrain = "train", AutoClick = "train", AutoRebirth = "train",
    AutoHatchEgg = "pet", AutoEquipPet = "pet", AutoFeedPet = "pet", AutoDeployPet = "pet", AutoSellPet = "pet",
    BossHop = "travel",
}

function xDTaraZ.Scheduler.Step()
    if not State.Alive then return end
    local now = os.clock()
    if State.Lock and State.LockTime and (now - State.LockTime > 12) then
        State.Lock = nil
        State.LockOwner = nil
        State.LockTime = 0
    end
    if State.Lock then return end

    local active = 0
    for _ in pairs(State.JobGroups) do active += 1 end
    local jobs = xDTaraZ.Scheduler.Jobs
    local cursor = State.ScheduleCursor or 0
    State.ScheduleCursor = cursor % #jobs + 1
    for offset = 1, #jobs do
        if active >= math.clamp(State.Opt.ParallelJobs, 1, 8) then break end
        local index = (cursor + offset - 1) % #jobs + 1
        local job = jobs[index]
        local group = xDTaraZ.Scheduler.Groups[job.key] or "inventory"
        if not State.Opt[job.key] or State.JobRunning[job.key] or State.JobGroups[group] then continue end
        if now - (State.LastRun[job.key] or 0) < job.every then continue end
        State.LastRun[job.key] = now
        active += 1
        local monitor
        monitor = task.defer(function()
            local ok, err = pcall(xDTaraZ.Scheduler.Run, job.key, job.run)
            if State.JobGroups[group] == monitor then State.JobGroups[group] = nil end
            if not ok and State.Alive then xDTaraZ.Util.WarnJob(job.key, err) end
        end)
        State.JobGroups[group] = monitor
    end
end

function xDTaraZ.Scheduler.Start()
    task.spawn(function()
        while State.Alive do
            if not State.Busy then
                State.Busy = true
                xDTaraZ.Util.Try(xDTaraZ.Scheduler.Step)
                State.Busy = false
            end
            task.wait(Config.TickDelay)
        end
    end)
end

function xDTaraZ.Scheduler.Boot()
    for _, bind in ipairs({ xDTaraZ.Movement.Bind, xDTaraZ.Level.Bind, xDTaraZ.SuperLoot.Bind, xDTaraZ.Boss.Bind, xDTaraZ.Pet.Bind, xDTaraZ.Session.Bind }) do
        xDTaraZ.Util.Try(bind)
    end
    xDTaraZ.Scheduler.Start()
end

function xDTaraZ.Scheduler.Stop()
    State.Alive = false
    for _, threads in pairs(State.WorkerBatches) do
        for _, thread in ipairs(threads) do pcall(task.cancel, thread) end
    end
    for _, thread in pairs(State.JobRunning) do pcall(task.cancel, thread) end
    for _, monitor in pairs(State.JobGroups) do xDTaraZ.Util.CancelTree(monitor) end
    for owner in pairs(State.ChildThreads) do xDTaraZ.Util.CancelTree(owner) end
    table.clear(State.JobGroups)
    table.clear(State.ChildThreads)
    State.Lock = nil
    State.LockOwner = nil
    State.LockTime = 0
    table.clear(State.WorkerBatches)
    table.clear(State.JobRunning)
    table.clear(State.LootQueue)
    table.clear(State.LootSeen)
    table.clear(State.LootPending)
    for _, conn in ipairs(State.Conns) do
        conn:Disconnect()
    end
    table.clear(State.Conns)
    if State.Opt.AutoTrain then
        State.Opt.AutoTrain = false
        task.spawn(xDTaraZ.Util.Try, xDTaraZ.Level.SetTraining, false)
    end
    if State.Opt.SpeedOn then
        State.Opt.SpeedOn = false
        xDTaraZ.Movement.Apply()
    end
    if State.Opt.LowGraphics then
        xDTaraZ.Session.SetLowGraphics(false)
    end
    xDTaraZ.Util.Try(xDTaraZ.Pet.MuteAnim, false)
    xDTaraZ.Util.Try(xDTaraZ.Tower.Exit)
    if LocalPlayer:GetAttribute("IntoFight") == "WorldBoss" then xDTaraZ.Util.Try(xDTaraZ.Boss.Leave) end
    xDTaraZ.Guard.Stop()
end

local function BuildInterface()
    local Library = xDTaraZ.Util.LoadLibrary()
    if not Library then return end
    xDTaraZ.Compat = Library.Compat or { Caps = {}, Block = function() end, NeedCap = function() end }
    local Options = Library.Options

    local T = function(en, th) return Library:T(en, th) end
    local opt = State.Opt
    local featureNames = {}
    local uiQueue = {}
    local statusLabel, gearLabel, taskLabel

    
    
    local function Source(fn)
        local ok, first, second = pcall(fn)
        if not ok then
            warn("[LootToForge] menu data:", first)
            return {}, {}
        end
        return first or {}, second or {}
    end

    local rarityNames = Source(xDTaraZ.Util.RarityNames)

    local function Later(fn, ...)
        local args = table.pack(...)
        table.insert(uiQueue, function()
            fn(table.unpack(args, 1, args.n))
        end)
    end

    local function Notify(text, kind, seconds)
        Later(Library.Notify, Library, "Loot To Forge", text, seconds or 4, kind or "Info")
    end

    local function TurnOff(key)
        local toggle = Options[key]
        if toggle and toggle.Value then toggle:SetValue(false) end
    end

    
    
    
    local function SetList(idx, values, pickFirst)
        local dropdown = Options[idx]
        if not dropdown then return end
        dropdown:SetValues(values)
        if pickFirst and values[1] then
            dropdown:SetValue(values[1])
        elseif dropdown.Value ~= opt[idx] then
            dropdown:SetValue(dropdown.Value)
        end
    end

    
    
    local function NeedModule(option, module)
        if xDTaraZ.GameLib.Require(module) then return end
        xDTaraZ.Compat.Block(option, T("Not available on this executor", "ใช้กับ executor นี้ไม่ได้"))
    end

    local function BlockMissing()
        for idx, paths in pairs(xDTaraZ.GameLib.Missing()) do
            warn("[LootToForge]", idx, "blocked, missing:", table.concat(paths, ", "))
            if Options[idx] then xDTaraZ.Compat.Block(Options[idx], T("Not available after a game update", "ใช้ไม่ได้หลังเกมอัปเดต")) end
        end
    end

    local function Pump()
        for _, halt in ipairs(State.Halted) do
            TurnOff(halt[1])
            Notify(("%s stopped: %s"):format(featureNames[halt[1]] or halt[1], halt[2]), "Warning")
        end
        table.clear(State.Halted)

        local jobs = uiQueue
        uiQueue = {}
        for _, job in ipairs(jobs) do
            xDTaraZ.Util.Try(job)
        end
    end

    local actionId = 0
    local function Action(action)
        actionId += 1
        local key = "Action:" .. actionId
        return function()
            if not State.Alive or State.JobRunning[key] then return end
            task.defer(xDTaraZ.Scheduler.Run, key, action)
        end
    end

    
    
    
    local function LongAction(name, action, done)
        return Action(function()
            if State.Lock then return Notify("Busy: " .. State.Lock, "Warning") end
            Notify(name .. "...")
            local acquired, outcome = xDTaraZ.Util.Exclusive(name, action)
            if not acquired then return Notify("An inventory task is still running; retry when it finishes", "Warning") end
            if done then Notify(done(outcome), (outcome == false or outcome == nil or outcome == 0) and "Warning" or "Success") end
        end)
    end

    local function Toggle(group, key, text, description, onChange)
        featureNames[key] = text.EN
        return group:AddToggle(key, {
            Text = text,
            Description = description,
            Default = opt[key],
            Callback = function(value)
                opt[key] = value
                if onChange then
                    onChange(value)
                end
            end,
        })
    end

    local Feature = Toggle

    local function HotkeyFeature(group, key, text, description, onChange)
        return Toggle(group, key, text, description, onChange):AddKeyPicker(key .. "Key", { Default = "None", Mode = "Toggle" })
    end

    local function Check(group, key, text)
        return group:AddCheckbox(key, {
            Text = text,
            Default = opt[key],
            Callback = function(value)
                opt[key] = value
            end,
        })
    end

    local function MultiSelect(group, key, text, description, values)
        opt[key] = xDTaraZ.Util.AllSet(values)
        return group:AddDropdown(key, {
            Text = text,
            Description = description,
            Values = values,
            Multi = true,
            Default = values,
            Searchable = #values > 8,
            Callback = function(selected)
                opt[key] = selected
            end,
        })
    end

    
    
    
    
    
    
    local function Pick(group, key, text, description, source, noSave)
        local values = Source(source)
        opt[key] = values[1]
        return group:AddDropdown(key, {
            Text = text,
            Description = description,
            Values = values,
            Default = 1,
            Searchable = #values > 8,
            NoSave = noSave,
            Callback = function(value)
                opt[key] = value
            end,
        })
    end

    local function NumberInput(group, key, text, description, minimum)
        return group:AddInput(key, {
            Text = text,
            Description = description,
            Default = tostring(opt[key]),
            Numeric = true,
            Finished = true,
            Callback = function(value)
                opt[key] = math.max(minimum or 0, math.floor(tonumber(value) or opt[key]))
            end,
        })
    end

    
    
    local function Decorate(idx, idOf)
        task.defer(function()
            local dropdown = Options[idx]
            if not (dropdown and dropdown.SetImages) then return end
            local ok, images, colors = pcall(xDTaraZ.Look.Maps, dropdown.Values, idOf)
            if not ok then return warn("[LootToForge] item images:", images) end
            Later(function()
                if Options[idx] then Options[idx]:SetImages(images, colors) end
            end)
        end)
    end

    local function OreId(label)
        return State.OreLabels and State.OreLabels[label]
    end

    local function RefreshButton(idx, list)
        return { Text = T("Refresh", "รีเฟรช"), Func = function()
            task.defer(function()
                Later(SetList, idx, (Source(list)))
                if State.Decorators and State.Decorators[idx] then Later(Decorate, idx, State.Decorators[idx]) end
            end)
        end }
    end

    local function BuildMain(tab)
        local statusBox = tab:AddLeftGroupbox(T("Status", "สถานะ"))
        statusLabel = statusBox:AddLabel("Loading...")
        gearLabel = statusBox:AddLabel("Equipped: -")
        taskLabel = statusBox:AddLabel("Working on: Idle")

        local kaitunBox = tab:AddLeftGroupbox(T("Kaitun", "ไก่ตัน"))
        kaitunBox:AddToggle("Kaitun", {
            Text = T("Kaitun (All-in-one)", "ไก่ตัน (ทำทุกอย่าง)"),
            Description = T("Best gear, money, level, rewards and bosses all at once", "ของดีสุด เงิน เลเวล รางวัล และบอส ทำพร้อมกันทั้งหมด"),
            NoSave = true,
            Callback = function(value)
                for _, key in ipairs(Config.KaitunToggles) do
                    if Options[key] then Options[key]:SetValue(value) end
                end
            end,
        })

        local logBox = tab:AddRightGroupbox(T("Update Log", "อัปเดตล่าสุด"), "bell")
        for i = 1, math.min(2, #Config.UpdateLog) do
            local entry = Config.UpdateLog[i]
            logBox:AddParagraph({ Title = entry[1], Content = entry[2] })
        end

        local rewardBox = tab:AddLeftGroupbox(T("Rewards", "รางวัล"))
        Feature(rewardBox, "AutoClaim", T("Auto Claim", "รับรางวัลอัตโนมัติ"), T("Claims every free reward, including index", "รับรางวัลฟรีทุกอย่าง รวมสมุดสะสม"))
        rewardBox:AddButton({ Text = T("Claim Now", "รับเดี๋ยวนี้"), Style = "Success", Func = Action(xDTaraZ.Claim.All) })
        Feature(rewardBox, "AutoCheckIn", T("Auto 30-Day Check-In", "รับเช็กอิน 30 วันอัตโนมัติ"), T("Claims every signed day that still has an unclaimed reward", "รับรางวัลทุกวันที่เช็กอินแล้วและยังไม่ได้รับ"))
        rewardBox:AddButton({ Text = T("Claim Check-In Now", "รับรางวัลเช็กอินเดี๋ยวนี้"), Func = LongAction("Check-In", xDTaraZ.Claim.CheckIn, function(count)
            return ("Claimed %d check-in rewards"):format(count or 0)
        end) })
        rewardBox:AddButton({ Text = T("Redeem All Codes", "ใช้โค้ดทั้งหมด"), Style = "Primary", Func = Action(function()
            Notify(xDTaraZ.Claim.AllCodes(), "Success", 6)
        end) })
    end

    local function BuildGear(tab)
        local formBox = tab:AddRightGroupbox(T("Dual Form", "อุปกรณ์สองร่าง"))
        formBox:AddLabel(T("Switch equipped dual-form gear between A and B", "สลับ A/B ของอุปกรณ์สองร่างที่ใส่อยู่"))
        for _, slot in ipairs(Config.GearTypes) do
            formBox:AddButton({ Text = T("Switch " .. slot .. " Form", "สลับร่าง " .. slot), Func = Action(function()
                local changed = xDTaraZ.Gear.SwitchForm(slot)
                Notify(changed and "Form switched" or "Equip dual-form gear in this slot first", changed and "Success" or "Info")
            end) })
        end

        local gearBox = tab:AddLeftGroupbox(T("Max Gear", "อุปกรณ์สูงสุด"))
        Feature(gearBox, "MaxGear", T("Max Gear", "อุปกรณ์สูงสุด"),
            T("Best gear and runes, enhanced to your target. Finds anything missing by itself", "ของดีสุด รูนดีสุด ตีบวกถึงเป้า ขาดอะไรหาเองหมด"),
            function()
                State.GearForged = false
            end)
        Check(gearBox, "GearForge", T("Forge gear automatically", "หลอมของอัตโนมัติ"))
        Check(gearBox, "GearEnchant", T("Equip runes automatically", "ใส่รูนอัตโนมัติ"))
        Check(gearBox, "GearEnhance", T("Enhance automatically", "ตีบวกอัตโนมัติ"))
        gearBox:AddSlider("EnhanceTarget", {
            Text = T("Enhance Target", "ตีบวกถึง"),
            Description = T("Above +10 the success rate gets very low and can take a long time", "เกิน +10 โอกาสสำเร็จต่ำมาก อาจใช้เวลานาน"),
            Min = 5, Max = 20, Default = opt.EnhanceTarget, Rounding = 0, Prefix = "+",
            Callback = function(value)
                opt.EnhanceTarget = value
            end,
        })
        local runes = xDTaraZ.Gear.RuneOrder()
        opt.EnchantPriority = table.clone(runes)
        gearBox:AddDropdown("EnchantPriority", {
            Text = T("Runes To Use", "รูนที่ใช้"),
            Description = T("Stronger runes go in first", "รูนที่แรงกว่าใส่ก่อน"),
            Values = runes,
            Multi = true,
            Default = runes,
            Searchable = #runes > 8,
            Callback = function(selected)
                local order = {}
                for _, stoneId in ipairs(runes) do
                    if selected[stoneId] then order[#order + 1] = stoneId end
                end
                if #order == 0 then Notify("No rune selected, using all runes", "Warning") end
                opt.EnchantPriority = order
            end,
        })

        local equipBox = tab:AddRightGroupbox(T("Equip", "ใส่ของ"))
        Feature(equipBox, "AutoEquip", T("Auto Equip", "ใส่ของอัตโนมัติ"), T("Always wears your strongest weapon, armor and hat, counting enhance level", "ใส่อาวุธ เกราะ และหมวกที่แรงที่สุดเสมอ นับระดับตีบวกด้วย"))
        equipBox:AddButton({ Text = T("Equip Now", "ใส่ของเดี๋ยวนี้"), Func = function()
            task.defer(function()
                local changed = xDTaraZ.Gear.EquipBest()
                Notify(changed > 0 and ("Equipped %d better item(s)"):format(changed) or "Already wearing your best gear")
            end)
        end })

        equipBox:AddDivider()
        equipBox:AddDropdown("EnhanceSlot", {
            Text = T("Enhance Slot", "ช่องที่ตีบวก"),
            Values = Config.GearTypes,
            Default = opt.EnhanceSlot,
            Callback = function(value)
                opt.EnhanceSlot = value or opt.EnhanceSlot
            end,
        })
        equipBox:AddButton({ Text = T("Enhance To Target", "ตีบวกถึงเป้า"), Style = "Primary", Func = LongAction("Enhance", function()
            return xDTaraZ.Gear.EnhanceSlot(opt.EnhanceSlot, opt.EnhanceTarget)
        end, function(level) return level and ("%s is +%d"):format(opt.EnhanceSlot, level) or "Nothing equipped there" end) })
    end

    local function BuildFarm(tab)
        local stageBox = tab:AddLeftGroupbox(T("Stage", "ด่าน"))
        Pick(stageBox, "Stage", T("Stage", "ด่าน"), T("Any stage, no unlock needed", "เลือกด่านไหนก็ได้ ไม่ต้องปลดล็อก"), xDTaraZ.Stage.List)
        Feature(stageBox, "AutoBattle", T("Auto Battle", "เข้าด่านและฆ่าอัตโนมัติ"), T("Enters the selected stage and clears normal enemies and stage bosses", "เข้าด่านที่เลือกและฆ่ามอนสเตอร์กับบอสด่านทั้งหมด"))
        Feature(stageBox, "CollectOre", T("Auto Collect Ore", "เก็บแร่อัตโนมัติ"), T("Clears the stage and collects its ores nonstop", "เคลียร์ด่านแล้วเก็บแร่ไม่หยุด"))
        MultiSelect(stageBox, "CollectRarities", T("Ore Rarity Filter", "กรอง rarity แร่"), T("Only collect these rarities", "เก็บเฉพาะ rarity ที่เลือก"), rarityNames)

        local combatBox = tab:AddLeftGroupbox(T("Combat", "ต่อสู้"), nil, "OP")
        local killAura = Feature(combatBox, "KillAura", T("Kill Aura", "ฆ่ารอบตัว"), T("Clears all enemies across the whole map instantly", "ฆ่าศัตรูทั้งแมพทันที ยิงทะลุกำแพง ไม่จำกัดระยะ"), function(value)
            if value then xDTaraZ.Combat.Start() end
        end)
        NeedModule(killAura, ReplicatedStorage.Utils.CommunicationUtils)
        Check(combatBox, "AuraMapWide", T("Map-Wide / Infinite Range", "โจมตีทั้งแมพ / ไม่จำกัดระยะ"))
        combatBox:AddDropdown("AuraTarget", {
            Text = T("Target Filter", "ประเภทเป้าหมาย"),
            Values = { "All", "Normal", "Super", "Boss" },
            Default = 1,
            Callback = function(value) opt.AuraTarget = value end,
        })
        NumberInput(combatBox, "AuraBatch", T("Targets Per Sweep", "เป้าหมายต่อรอบ"), T("Number of enemies processed per tick", "จำนวนศัตรูที่ประมวลผลต่อรอบ"), 1)
        combatBox:AddSlider("AuraBurst", {
            Text = T("Attack Burst (Hits/Tick)", "จำนวนฮิตต่อรอบ"), Min = 1, Max = 50,
            Default = opt.AuraBurst, Rounding = 0,
            Callback = function(value) opt.AuraBurst = tonumber(value) or 10 end,
        })
        combatBox:AddSlider("AuraInterval", {
            Text = T("Attack Interval", "ช่วงเวลาโจมตี"), Min = 0.05, Max = 1,
            Default = opt.AuraInterval, Rounding = 2, Suffix = " s",
            Callback = function(value) opt.AuraInterval = math.clamp(tonumber(value) or 0.12, 0.05, 1) end,
        })
        Check(combatBox, "AuraCritical", T("Critical Hits", "โจมตีคริติคอล"))
        Check(combatBox, "AutoCollectDrops", T("Auto Collect Drops", "เก็บของดรอปอัตโนมัติ"))
        Check(combatBox, "AuraSuper", T("Include Ore Bosses", "รวมบอสแร่"))
        Feature(combatBox, "SuperLootAura", T("Kill Ore Boss", "ฆ่าบอสแร่"), T("Handles ore bosses instantly and collects confirmed drops", "จัดการบอสแร่ทันที และรับของที่ยืนยันแล้ว"), function(value)
            if value then
                xDTaraZ.SuperLoot.KillExisting()
            else
                for _, uuid in ipairs(State.LootQueue) do State.LootSeen[uuid] = nil end
                table.clear(State.LootQueue)
            end
        end)
        combatBox:AddButton({ Text = T("Exit Fight Now", "ออกจากการต่อสู้เดี๋ยวนี้"), Style = "Warning", Func = Action(xDTaraZ.Stage.ExitFight) })

        local bossBox = tab:AddRightGroupbox(T("World Boss", "บอสโลก"))
        Feature(bossBox, "AutoWorldBoss", T("Auto World Boss", "บอสโลกอัตโนมัติ"), T("Joins every world boss and kills it", "เข้าบอสโลกทุกรอบแล้วฆ่า"), function(value)
            if not value and LocalPlayer:GetAttribute("IntoFight") == "WorldBoss" then task.spawn(xDTaraZ.Util.Try, xDTaraZ.Boss.Leave) end
        end)
        Check(bossBox, "BossCards", T("Auto Take Reward Card", "เปิดการ์ดรางวัลอัตโนมัติ"))
        Feature(bossBox, "BossHop", T("Boss Server Hop", "ย้ายเซิร์ฟหาบอส"), T("Hops to servers where the boss is up or about to spawn, kills it, then moves on", "ย้ายไปเซิร์ฟที่บอสเกิดอยู่หรือใกล้เกิด ฆ่าแล้วย้ายต่อ"), function(value)
            xDTaraZ.Boss.HopFlag(value)
            if value and Options.AutoWorldBoss and not Options.AutoWorldBoss.Value then Options.AutoWorldBoss:SetValue(true) end
        end)
        bossBox:AddSlider("BossWaitMinutes", {
            Text = T("Wait If Boss Within", "รอถ้าบอสจะเกิดภายใน"),
            Description = T("Stays on a server when the boss spawns this soon", "อยู่เซิร์ฟเดิมถ้าบอสจะเกิดภายในเวลานี้"),
            Min = 0.5, Max = 10, Default = opt.BossWaitMinutes, Rounding = 1, Suffix = " min",
            Callback = function(value)
                opt.BossWaitMinutes = tonumber(value) or opt.BossWaitMinutes
            end,
        })

        local indexBox = tab:AddRightGroupbox(T("Index", "สมุดสะสม"))
        MultiSelect(indexBox, "IndexTypes", T("Index Types", "ประเภทที่จะเก็บ"), nil, Config.GearTypes)
        Pick(indexBox, "MissingItem", T("Missing Item", "ของที่ยังไม่มี"), T("Chance shown is per forge with the best ore", "เปอร์เซ็นต์ = โอกาสต่อการหลอมหนึ่งครั้งด้วยแร่ที่ดีที่สุด"), function()
            return { "..." }
        end, true)
        task.defer(function()
            local ok, labels = pcall(xDTaraZ.Index.Choices)
            if ok then
                Later(SetList, "MissingItem", labels, true)
            else
                warn("[LootToForge] index list:", labels)
            end
        end)
        indexBox:AddButton({ Text = T("Get Selected", "หาชิ้นนี้"), Style = "Primary", Func = LongAction("Index", function()
            local gear = State.MissingLabels[opt.MissingItem]
            return gear and xDTaraZ.Index.Hunt(gear)
        end, function(got)
            Later(SetList, "MissingItem", (Source(xDTaraZ.Index.Choices)))
            return got and "Got it!" or "Not found this time, press again"
        end) }):AddButton(RefreshButton("MissingItem", xDTaraZ.Index.Choices))
        Feature(indexBox, "AutoIndex", T("Auto Complete Index", "เก็บสมุดสะสมอัตโนมัติ"), T("Forges every missing weapon, armor and hat, then claims rewards", "หลอมอาวุธ เกราะ หมวกที่ยังไม่มีทุกชิ้น แล้วรับรางวัล"), nil, true)
        indexBox:AddButton({ Text = T("Collect All Ores", "เก็บแร่ทุกชนิด"), Func = LongAction("Ores", xDTaraZ.Index.CollectOres, function()
            local count, level = xDTaraZ.Index.Progress()
            return ("Index %d, level %d"):format(count, level)
        end) }):AddButton({ Text = T("Claim Rewards", "รับรางวัล"), Style = "Success", Func = Action(xDTaraZ.Index.ClaimAll) })
    end

    local function BuildForge(tab)
        local forgeBox = tab:AddLeftGroupbox(T("Forge", "หลอม"))
        local targetNames = {}
        for _, target in ipairs(Config.ForgeTargets) do
            targetNames[#targetNames + 1] = target.name
        end
        forgeBox:AddDropdown("ForgeTarget", {
            Text = T("Target Gear", "อุปกรณ์ที่จะหลอม"),
            Values = targetNames,
            Default = 1,
            Callback = function(value)
                opt.ForgeTarget = value or opt.ForgeTarget
            end,
        })
        Pick(forgeBox, "ForgeOre", T("Ore To Use", "แร่ที่ใช้หลอม"), T("Uses owned ore and farms missing stock", "ใช้แร่ที่มีและฟาร์มส่วนที่ขาด"), xDTaraZ.Ore.ForgeChoices, nil)
        Decorate("ForgeOre", OreId)
        Feature(forgeBox, "AutoForge", T("Auto Forge", "หลอมอัตโนมัติ"), T("Forges the target gear nonstop", "หลอมอุปกรณ์ที่เลือกไม่หยุด"))
        forgeBox:AddButton({ Text = T("Forge Now", "หลอมเดี๋ยวนี้"), Style = "Primary", Func = Action(xDTaraZ.Forge.Step) })
        forgeBox:AddSlider("ForgePerTick", {
            Text = T("Forges Per Round", "หลอมต่อรอบ"),
            Min = 1, Max = 50, Default = opt.ForgePerTick, Rounding = 0,
            Callback = function(value)
                opt.ForgePerTick = value
            end,
        })
        Check(forgeBox, "ForgeSellJunk", T("Sell worse gear right away", "ขายของที่แย่กว่าที่ใส่ทันที"))

        local oreUseBox = tab:AddRightGroupbox(T("Ore Usage", "การใช้แร่"))
        oreUseBox:AddLabel(T("Used when Ore To Use is Owned ores", "ใช้ตอนแร่ที่ใช้หลอม = Owned ores"))
        Toggle(oreUseBox, "BestOreFirst", T("Spend High Tier Ore First", "ใช้แร่ระดับสูงก่อน"), T("Off = spend the weakest ore first", "ปิด = ใช้แร่ที่อ่อนที่สุดก่อน"))
        MultiSelect(oreUseBox, "ForgeRarities", T("Forge Ore Rarity", "rarity แร่ที่ใช้หลอม"), T("Only these ore rarities are used for forging", "ใช้แร่เฉพาะ rarity ที่เลือกในการหลอม"), rarityNames)
        NumberInput(oreUseBox, "KeepPerOre", T("Keep Per Ore", "เก็บแร่ไว้ชนิดละ"), T("Never forge below this amount of each ore", "ไม่หลอมจนแร่แต่ละชนิดต่ำกว่าจำนวนนี้"))
    end

    local function BuildSell(tab)
        local sellBox = tab:AddLeftGroupbox(T("Auto Sell", "ขายอัตโนมัติ"))
        Feature(sellBox, "AutoSell", T("Auto Sell", "ขายอัตโนมัติ"), T("Sells gear that matches your filters. Equipped gear is never sold", "ขายอุปกรณ์ที่ตรงตัวกรอง ของที่ใส่อยู่จะไม่ขาย"))
        sellBox:AddButton({ Text = T("Sell All Now", "ขายทั้งหมดเดี๋ยวนี้"), Style = "Primary", Func = Action(function()
            xDTaraZ.Sell.Run(xDTaraZ.Data.Get())
            Notify("Sold", "Coin")
        end) })

        local filterBox = tab:AddRightGroupbox(T("Filters", "ตัวกรอง"))
        MultiSelect(filterBox, "SellTypes", T("Sell Item Types", "ประเภทที่จะขาย"), nil, Config.GearTypes)
        MultiSelect(filterBox, "SellRarities", T("Sell Rarity Filter", "กรอง rarity ที่จะขาย"), T("Only sell these rarities", "ขายเฉพาะ rarity ที่เลือก"), rarityNames)
        NumberInput(filterBox, "KeepPerItem", T("Keep Per Item", "เก็บไว้ชิ้นละ"), T("Keeps this many of each item, highest enhance first", "เก็บแต่ละไอเทมไว้ตามจำนวนนี้ เลือกตัวตีบวกสูงสุดก่อน"))
    end

    local function BuildProgress(tab)
        local trainBox = tab:AddLeftGroupbox(T("Training", "ฝึก"))
        Feature(trainBox, "AutoTrain", T("Auto Train", "ฝึกอัตโนมัติ"), T("Trains at the best area nonstop and drinks your potions", "ฝึกโซนดีสุดไม่หยุด ใช้ยาให้เอง"), function(value)
            task.spawn(xDTaraZ.Util.Try, xDTaraZ.Level.SetTraining, value)
        end)
        local autoClick = Feature(trainBox, "AutoClick", T("Auto Click", "คลิกอัตโนมัติ"), T("Clicks to train as fast as the game allows", "คลิกฝึกเร็วสุดเท่าที่เกมยอม"), function(value)
            if value then xDTaraZ.Level.StartClicking() end
        end)
        NeedModule(autoClick, ReplicatedStorage.CTRL.TrainCTRL)
        Feature(trainBox, "AutoRebirth", T("Auto Rebirth", "รีเบิร์ธอัตโนมัติ"), T("Rebirths as soon as your level is high enough", "รีเบิร์ธทันทีเมื่อเลเวลถึง"))
        trainBox:AddButton({ Text = T("Rebirth Now", "รีเบิร์ธเดี๋ยวนี้"), Func = Action(xDTaraZ.Level.Rebirth) })

        local upgradeBox = tab:AddRightGroupbox(T("Upgrades", "อัปเกรด"))
        MultiSelect(upgradeBox, "Upgrades", T("Upgrades To Buy", "อัปเกรดที่จะซื้อ"), nil, (Source(xDTaraZ.Upgrade.Names)))
        Feature(upgradeBox, "AutoUpgrade", T("Auto Buy Upgrades", "ซื้ออัปเกรดอัตโนมัติ"), T("Buys the selected upgrades whenever possible", "ซื้ออัปเกรดที่เลือกทุกครั้งที่ซื้อได้"))
        upgradeBox:AddButton({ Text = T("Buy Upgrade Now", "ซื้ออัปเกรดเดี๋ยวนี้"), Func = Action(xDTaraZ.Upgrade.BuySelected) })
    end

    local function BuildTower(tab)
        local towerBox = tab:AddLeftGroupbox(T("Tower", "หอคอย"))
        Feature(towerBox, "AutoTower", T("Auto Farm Tower", "ฟาร์มหอคอยอัตโนมัติ"), T("Top floor loot nonstop on one ticket: rare stones and season coins", "ของชั้นบนสุดไม่หยุดด้วยตั๋วใบเดียว ได้หินหายากและเหรียญซีซั่น"), function(value)
            task.defer(function()
                if not value then return xDTaraZ.Util.Try(xDTaraZ.Tower.Exit) end
                if not xDTaraZ.Tower.Enter() then Notify("No tower ticket", "Warning") end
            end)
        end)
        towerBox:AddButton({ Text = T("Exit Tower Now", "ออกจากหอคอยเดี๋ยวนี้"), Style = "Warning", Func = function()
            Options.AutoTower:SetValue(false)
            task.spawn(xDTaraZ.Util.Try, xDTaraZ.Tower.Exit)
        end })

        local seasonBox = tab:AddRightGroupbox(T("Season", "ซีซั่น"))
        local goodLabels, goodIds = Source(xDTaraZ.Season.Goods)
        local goodDefault = {}
        for label, goodId in pairs(goodIds) do
            if opt.SeasonGoods[goodId] then table.insert(goodDefault, label) end
        end
        Feature(seasonBox, "AutoSeason", T("Auto Season", "ซีซั่นอัตโนมัติ"), T("Daily ticket, pass rewards, spins and shop", "ตั๋วรายวัน รางวัลพาส สุ่ม และร้าน"))
        seasonBox:AddButton({ Text = T("Season Now", "ซีซั่นเดี๋ยวนี้"), Func = Action(xDTaraZ.Season.Step) })
        Check(seasonBox, "SeasonSpin", T("Auto Spin Tickets", "สุ่มตั๋วอัตโนมัติ"))
        NumberInput(seasonBox, "SeasonSpinBatch", T("Spins Per Cycle", "สุ่มต่อรอบ"), T("1–50; remaining tickets continue next cycle", "1–50 ตั๋วที่เหลือสุ่มรอบถัดไป"), 1)
        seasonBox:AddDropdown("SeasonGoods", {
            Text = T("Shop Items To Buy", "ของในร้านที่จะซื้อ"),
            Values = goodLabels,
            Multi = true,
            Default = goodDefault,
            Searchable = #goodLabels > 8,
            Callback = function(selected)
                local wanted = {}
                for label, on in pairs(selected) do
                    if on and goodIds[label] then wanted[goodIds[label]] = true end
                end
                opt.SeasonGoods = wanted
            end,
        })
    end

    local function BuildSpawn(tab)
        local spawnBox = tab:AddLeftGroupbox(T("Ore & Loot Spawner", "เสกแร่และไอเทม"), nil, "OP")
        Feature(spawnBox, "TurboSpawn", T("Continuous Insane Turbo Spawner", "เสกของรัวแบบไม่จำกัดต่อเนื่อง"), T("Continuously streams selected or top tier loot directly into your backpack", "ฟาร์มเสกไอเทมที่เลือกหรือไอเทมระดับเทพเข้ากระเป๋าต่อเนื่องแบบไม่หยุด"))
        Pick(spawnBox, "SpawnItem", T("Ore / Item / Pet", "แร่ / ไอเทม / สัตว์เลี้ยง"), T("Every ore, egg, fruit, rune and pet; farmed into inventory", "แร่ ไข่ ผลไม้ รูน และสัตว์เลี้ยงทั้งหมด ดึงเข้ากระเป๋าทันที"), xDTaraZ.Spawn.Choices, true)
        Decorate("SpawnItem", function(label) local entry = State.SpawnLabels[label] return entry and entry.id end)
        NumberInput(spawnBox, "SpawnAmount", T("Amount", "จำนวน"), T("Target amount to acquire (up to 1,000,000)", "จำนวนที่ต้องการได้ (สูงสุด 1,000,000)"), 1)
        spawnBox:AddButton({ Text = T("Spawn Selected Item (Turbo)", "เสกไอเทมที่เลือก (เทอร์โบ)"), Style = "Primary", Func = Action(function()
            local picked = State.SpawnLabels[opt.SpawnItem]
            if not picked then return Notify("Pick an item first", "Warning") end
            local acquired, outcome, reason = xDTaraZ.Spawn.Give(picked.id, picked.kind, opt.SpawnAmount)
            Notify(acquired and ("Obtained %s"):format(xDTaraZ.Util.Abbreviate(outcome)) or (reason or "Done"), acquired and "Success" or "Warning")
        end) }):AddButton(RefreshButton("SpawnItem", xDTaraZ.Spawn.Choices))

        spawnBox:AddButton({ Text = T("INSANE Farm Tier 40-48 God Ores", "เสกแร่เทพ Tier 40-48 แบบรัวคลั่ง"), Style = "Success", Func = LongAction("Max Ores", function()
            return xDTaraZ.Stage.FarmMaxOres(50)
        end, function(count)
            return ("Acquired %d god tier ores directly!"):format(count or 0)
        end) })

        spawnBox:AddButton({ Text = T("INSANE Farm Pet Eggs & Fruits (Burst)", "เสกไข่สัตว์เลี้ยงและผลไม้แบบรัวคลั่ง"), Style = "Success", Func = LongAction("Eggs & Fruits", function()
            local eggs, foods = xDTaraZ.Stage.FarmEggsAndFood(50)
            return { eggs = eggs, foods = foods }
        end, function(res)
            if type(res) ~= "table" then return "No drops" end
            return ("+%d eggs · +%d fruits"):format(res.eggs or 0, res.foods or 0)
        end) })

        spawnBox:AddButton({ Text = T("INSANE Farm Enhance Stones", "เสกหินตีบวกทั้งหมดแบบรัวคลั่ง"), Style = "Primary", Func = LongAction("Stones", function()
            local before = xDTaraZ.Data.Count(xDTaraZ.Data.Get(), "EnhantStone_1")
            xDTaraZ.Stage.FarmStones(xDTaraZ.Stage.Best())
            task.wait(0.3)
            return xDTaraZ.Data.Count(xDTaraZ.Data.Get(true), "EnhantStone_1") - before
        end, function(gained) return ("+%d enhance stones"):format(gained or 0) end) })

        spawnBox:AddButton({ Text = T("INSANE Stream All Drops (Burst)", "เสกและดึงดรอปทุกชนิดเข้ากระเป๋าแบบรัว"), Style = "Success", Func = LongAction("Stream Drops", function()
            local eggs, foods = xDTaraZ.Stage.FarmEggsAndFood(50)
            local ores = xDTaraZ.Stage.FarmMaxOres(50)
            return { eggs = eggs, foods = foods, ores = ores }
        end, function(res)
            return ("+%d god ores · +%d eggs · +%d fruits"):format(res.ores or 0, res.eggs or 0, res.foods or 0)
        end) })

        local coinBox = tab:AddRightGroupbox(T("Season Coins & Tower", "เหรียญซีซั่นและหอคอย"), nil, "OP")
        NumberInput(coinBox, "CoinTarget", T("Coins Target", "จำนวนเหรียญเป้าหมาย"), nil, 100)
        coinBox:AddButton({ Text = T("Farm 50,000 Season Coins", "ฟาร์ม 50,000 เหรียญซีซั่นทันที"), Style = "Primary", Func = LongAction("Tower Coins", function()
            return xDTaraZ.Tower.FarmCoins(opt.CoinTarget or 50000)
        end, function(gained) return ("+%s season coins"):format(xDTaraZ.Util.Abbreviate(gained or 0)) end) })

        coinBox:AddButton({ Text = T("Farm Rare Enhance Stones (Tier 2)", "ฟาร์มหินตีบวกหายาก (Tier 2)"), Func = LongAction("Tower Stones", function()
            local before = xDTaraZ.Data.Count(xDTaraZ.Data.Get(), "EnhantStone_2")
            xDTaraZ.Tower.FarmStep()
            task.wait(0.3)
            return xDTaraZ.Data.Count(xDTaraZ.Data.Get(true), "EnhantStone_2") - before
        end, function(gained) return ("+%d rare stones"):format(gained or 0) end) })

        local potionBox = tab:AddRightGroupbox(T("Potions", "ยา"), nil, "OP")
        NumberInput(potionBox, "PotionAmount", T("Potion Amount", "จำนวนยา"), T("Amount to consume for extending active buffs", "จำนวนยาที่จะใช้เพื่อต่อเวลาบัฟ"), 1)
        potionBox:AddButton({ Text = T("Extend All Buff Times", "เพิ่มเวลาบัฟยาทุกชนิด"), Style = "Primary", Func = LongAction("Potion Time", function()
            return xDTaraZ.Potion.Extend(opt.PotionAmount)
        end, function(changed) return ("Extended %d potion buffs"):format(changed or 0) end) })

        local gearBox = tab:AddLeftGroupbox(T("Target Gear", "หลอมอาวุธและชุดเป้าหมาย"), nil, "OP")
        local function LoadGearList(slot)
            task.defer(function()
                local ok, labels = pcall(xDTaraZ.Spawn.GearChoices, slot)
                if ok then
                    Later(SetList, "SpawnGear", labels, true)
                    Later(Decorate, "SpawnGear", function(label)
                        local gear = State.GearLabels and State.GearLabels[label]
                        return gear and gear.id
                    end)
                else
                    warn("[LootToForge] gear list:", labels)
                end
            end)
        end
        opt.GearSlot = Config.GearTypes[1]
        gearBox:AddDropdown("GearSlot", {
            Text = T("Type", "ประเภท"),
            Values = Config.GearTypes,
            Default = 1,
            NoSave = true,
            Callback = function(value)
                opt.GearSlot = value
                LoadGearList(value)
            end,
        })
        opt.SpawnGear = nil
        gearBox:AddDropdown("SpawnGear", {
            Text = T("Gear", "อุปกรณ์"),
            Description = T("Strongest first. Exclusive gear is shop only", "แรงสุดอยู่บน ของ Exclusive มีแค่ในร้าน"),
            Values = { "..." },
            Default = 1,
            Searchable = true,
            NoSave = true,
            Callback = function(value)
                opt.SpawnGear = value
            end,
        })
        LoadGearList(opt.GearSlot)
        NumberInput(gearBox, "GearCopies", T("Copies", "จำนวนชิ้น"), nil, 1)
        gearBox:AddButton({ Text = T("Forge Target Gear", "หลอมอุปกรณ์เป้าหมาย"), Style = "Primary", Func = LongAction("Index", function()
            local gear = State.GearLabels[opt.SpawnGear]
            return gear and xDTaraZ.Index.Hunt(gear, math.max(1, math.floor(opt.GearCopies)))
        end, function(got)
            return got and "Target forged!" or "Not all copies this time, press again"
        end) })
        gearBox:AddButton({ Text = T("Forge Set", "หลอมเซ็ตอุปกรณ์"), Func = LongAction("Index", xDTaraZ.Spawn.BestSet, function(made)
            return ("Forged and equipped %d/3 pieces"):format(made or 0)
        end) })
        gearBox:AddButton({ Text = T("1-Click Forge & Max Full God Set", "หลอมและอัปเกรดเซ็ตเทพเต็มสูบ 1-คลิก"), Style = "Success", Func = LongAction("God Set", xDTaraZ.Spawn.FullGodSet, function(made)
            return ("Forged, equipped, enhanced +20, and enchanted %d god pieces!"):format(made or 0)
        end) })
        gearBox:AddButton({ Text = T("Buy Exclusive Gear", "ซื้อของ Exclusive"), Func = LongAction("Tower", xDTaraZ.Season.BuyExclusive, function(bought)
            return (bought or 0) > 0 and ("Bought %d exclusive pieces"):format(bought) or "Already bought this refresh"
        end) })

        local tokenBox = tab:AddRightGroupbox(T("Token Shop", "ร้าน Token"), nil, "OP")
        Feature(tokenBox, "AutoTokenShop", T("Auto Mystery Shop", "ร้านลึกลับอัตโนมัติ"), T("Reveals cards and buys selected goods using owned tokens", "เปิดการ์ดและซื้อของที่เลือกด้วย Token ที่มี"))
        Check(tokenBox, "TokenReveal", T("Auto Reveal Cards", "เปิดการ์ดอัตโนมัติ"))
        Check(tokenBox, "TokenSkipOwned", T("Skip Owned Goods", "ข้ามของที่มีแล้ว"))
        local tokenLabels, tokenIds = Source(xDTaraZ.TokenShop.Choices)
        tokenBox:AddDropdown("TokenTargets", {
            Text = T("Buy These Goods (Empty = All)", "ของที่จะซื้อ (ว่าง = ทั้งหมด)"), Values = tokenLabels,
            Multi = true, Default = {}, Searchable = true,
            Callback = function(selected)
                local ids = {}
                for label, on in pairs(selected) do if on and tokenIds[label] then ids[tokenIds[label]] = true end end
                opt.TokenTargets = ids
            end,
        })
        tokenBox:AddButton({ Text = T("Buy All Now", "ซื้อทั้งหมดเดี๋ยวนี้"), Func = LongAction("Token Shop", xDTaraZ.TokenShop.BuyAll, function(bought)
            return (bought or 0) > 0 and ("Bought %d items"):format(bought) or "No purchase: check tokens, ownership and selected goods"
        end) })
    end

    local function BuildPet(tab)
        local hatchBox = tab:AddLeftGroupbox(T("Egg Hatchery & Farm", "ฟักไข่และฟาร์มไข่"), nil, "OP")
        Feature(hatchBox, "AutoHatchEgg", T("Auto Hatch When Ready", "เปิดไข่อัตโนมัติเมื่อครบเวลา"), T("Watches incubator and opens ready eggs the exact second timer hits 0, then incubates next", "ตรวจตู้ฟักตลอดเวลาและเปิดไข่ทันทีที่เวลาครบ 0 วิ แล้วใส่ฟองใหม่ต่อเนื่อง"))
        Check(hatchBox, "HatchBestFirst", T("Hatch Rare Eggs First", "ฟักไข่หายากก่อน (Egg2 > Egg1)"))
        Toggle(hatchBox, "SkipEggAnim", T("Skip Egg Cutscene", "ข้ามฉากเปิดไข่"), T("Hides the egg opening cutscene so farming never pauses", "ปิดฉากแอนิเมชันเปิดไข่เพื่อไม่ให้ขัดจังหวะฟาร์ม"), function(value)
            xDTaraZ.Util.Try(xDTaraZ.Pet.MuteAnim, value)
        end)
        hatchBox:AddButton({ Text = T("Open Ready Eggs Now", "เปิดไข่ที่พร้อมเดี๋ยวนี้"), Style = "Primary", Func = Action(function()
            local opened, hatched = xDTaraZ.Pet.HatchStep()
            Notify(opened > 0 and ("Opened %d ready eggs!"):format(opened) or "No eggs ready yet (timer still counting down)", opened > 0 and "Success" or "Info")
        end) })
        hatchBox:AddButton({ Text = T("Farm & Fill Crown Eggs (Egg2)", "ฟาร์มและเติมไข่ Egg2 เต็มตู้"), Style = "Success", Func = LongAction("Egg2 Farm", function()
            xDTaraZ.Pet.TrimEggs("Egg2")
            xDTaraZ.Stage.FarmTurbo("Egg2", "Egg", 15)
            local opened, hatched = xDTaraZ.Pet.HatchStep()
            return hatched
        end, function(hatched)
            return ("Incubated %d new eggs!"):format(hatched or 0)
        end) })
        hatchBox:AddButton({ Text = T("Refill 20 Eggs & Fruits Burst", "เติมไข่และผลไม้ 20 ชิ้น (เต็มกระเป๋า)"), Style = "Primary", Func = LongAction("Pet Farm", function()
            local eggs, foods = xDTaraZ.Stage.FarmEggsAndFood(20)
            return { eggs = eggs, foods = foods }
        end, function(res)
            if type(res) ~= "table" then return "No drops" end
            return ("+%d eggs · +%d fruits"):format(res.eggs or 0, res.foods or 0)
        end) })

        local cleanBox = tab:AddLeftGroupbox(T("Pet Bag Cleanup", "จัดการกระเป๋าสัตว์เลี้ยง"))
        Feature(cleanBox, "AutoSellPet", T("Auto Clean Pet & Egg Bag", "เคลียร์กระเป๋าสัตว์เลี้ยงและไข่อัตโนมัติ"), T("Deletes low-rarity pets while protecting equipped and top pets", "ลบสัตว์เลี้ยงระดับต่ำโดยล็อกตัวที่ใส่และตัวเก่งสุดไว้"))
        local defaultDelete = { "Common", "Uncommon", "Rare", "Epic" }
        opt.DeletePetRarities = xDTaraZ.Util.AllSet(defaultDelete)
        cleanBox:AddDropdown("DeletePetRarities", {
            Text = T("Delete Pet Rarities", "ลบสัตว์เลี้ยงระดับ"),
            Description = T("Only delete unequipped pets of these rarities", "ลบเฉพาะสัตว์เลี้ยงที่ไม่ได้ใส่ในระดับที่เลือก"),
            Values = rarityNames,
            Multi = true,
            Default = defaultDelete,
            Callback = function(selected)
                opt.DeletePetRarities = selected
            end,
        })
        NumberInput(cleanBox, "KeepBestPets", T("Keep Top Pets", "เก็บสัตว์เลี้ยงตัวหลักไว้"), T("Always keeps at least this many highest-scoring pets", "เก็บสัตว์เลี้ยงที่คะแนนสูงสุดไว้อย่างน้อยจำนวนนี้"), 1)
        Check(cleanBox, "AutoDeleteEggs", T("Trim Excess Unhatched Eggs", "ลบไข่ส่วนเกินอัตโนมัติ"))
        NumberInput(cleanBox, "KeepPerEgg", T("Keep Per Egg Type", "เก็บไข่ไว้ชนิดละ"), T("Deletes unhatched eggs above this count per type", "ลบไข่ที่ยังไม่ได้ฟักที่เกินจำนวนนี้ต่อชนิด"), 1)
        cleanBox:AddButton({ Text = T("Clean Pet & Egg Bag Now", "เคลียร์กระเป๋าเดี๋ยวนี้"), Func = Action(function()
            local delPets, delEggs = xDTaraZ.Pet.CleanBag()
            Notify(("Removed %d pets · %d eggs"):format(delPets or 0, delEggs or 0), "Info")
        end) })

        local petBox = tab:AddRightGroupbox(T("Pet Loadout & Feeding", "ใส่สัตว์เลี้ยงและให้อาหาร"), nil, "OP")
        Feature(petBox, "AutoEquipPet", T("Auto Equip Pets", "ใส่สัตว์เลี้ยงอัตโนมัติ"), T("Always equips your highest-scoring pets for maximum stat boosts", "ใส่สัตว์เลี้ยงที่คะแนนสูงสุดเสมอเพื่อรับบัฟสูงสุด"))
        petBox:AddButton({ Text = T("Equip Best Pets Now", "ใส่สัตว์เลี้ยงเทพเดี๋ยวนี้"), Style = "Primary", Func = Action(function()
            local changed = xDTaraZ.Pet.EquipBest()
            Notify(changed > 0 and ("Equipped %d pet(s)"):format(changed) or "Already equipping top pet(s)", "Info")
        end) })
        petBox:AddDivider()
        Feature(petBox, "AutoFeedPet", T("Auto Feed Fruits", "ให้อาหารผลไม้อัตโนมัติ"), T("Feeds owned fruits to your top pets until they reach max level", "ป้อนผลไม้ที่มีให้สัตว์เลี้ยงตัวหลักจนเลเวลตัน"))
        petBox:AddButton({ Text = T("Feed Pet Once", "ป้อนผลไม้หนึ่งครั้ง"), Func = Action(function()
            local fed = xDTaraZ.Pet.FeedBest()
            Notify(fed > 0 and "Fed highest-priority pet!" or "No pet needs EXP or no fruit owned", fed > 0 and "Success" or "Info")
        end) })
        petBox:AddButton({ Text = T("Feed All Pets to Max Level Now", "ป้อนผลไม้ให้อิ่มจนเวลตันทุกตัวทันที"), Style = "Success", Func = Action(function()
            local totalFed = xDTaraZ.Pet.FeedAllMax()
            Notify(totalFed > 0 and ("Fed pets %d times to max level!"):format(totalFed) or "Pets already max level or out of fruits", totalFed > 0 and "Success" or "Info")
        end) })

        local deployBox = tab:AddRightGroupbox(T("Pet Expedition", "ส่งสัตว์เลี้ยงสำรวจ"))
        Feature(deployBox, "AutoDeployPet", T("Auto Deploy & Claim Rewards", "ส่งสำรวจและรับรางวัลอัตโนมัติ"), T("Deploys best available pets on expeditions and claims all loot", "ส่งสัตว์เลี้ยงสำรวจและรับของรางวัลทั้งหมดอัตโนมัติ"))
        deployBox:AddButton({ Text = T("Deploy & Claim Now", "ส่งสำรวจและรับรางวัลเดี๋ยวนี้"), Style = "Success", Func = Action(function()
            xDTaraZ.Util.Remote("Pet", "ClaimAllDeployRewardRE"):FireServer()
            local deployed = xDTaraZ.Pet.DeployStep()
            Notify(("Claimed rewards · Deployed %d pet(s)"):format(deployed or 0), "Success")
        end) })

        local targetBox = tab:AddRightGroupbox(T("Target Pet Hunt & Auto-Hatch", "ล่าสัตว์เลี้ยงตามสั่ง"), nil, "OP")
        Pick(targetBox, "TargetPet", T("Target Pet", "สัตว์เลี้ยงที่ต้องการ"), T("Select any pet to hunt: farms its parent egg and auto-hatches", "เลือกสัตว์เลี้ยงตัวที่ต้องการ ระบบจะฟาร์มไข่ตรงใบและฟักเมื่อครบเวลา"), xDTaraZ.Pet.Choices, true)
        Decorate("TargetPet", function(label) return State.PetTargetLabels and State.PetTargetLabels[label] end)
        NumberInput(targetBox, "TargetPetCopies", T("Target Copies", "จำนวนที่ต้องการได้"), T("Number of target pets to acquire", "จำนวนตัวที่ต้องการเสกล่า"), 1)
        Feature(targetBox, "AutoChaseTargetPet", T("Auto Chase Target Pet", "ล่าสัตว์เลี้ยงตัวนี้อัตโนมัติ"), T("Automatically farms required eggs, incubates, opens on 0s, max-feeds, and locks", "ฟาร์มไข่ตรงใบ ใส่ตู้ฟัก เปิดทันทีที่ครบเวลา อัปเวลตันและล็อคตัวอัตโนมัติ"))
        Check(targetBox, "AutoLockTargetPet", T("Auto Lock Target Pet", "ล็อคสัตว์เลี้ยงที่ได้อัตโนมัติ"))
        targetBox:AddButton({ Text = T("Farm & Incubate Target Egg Now", "ฟาร์มและใส่ไข่เป้าหมายเข้าตู้เดี๋ยวนี้"), Style = "Primary", Func = LongAction("Pet Hunt", function()
            local picked = State.PetTargetLabels and State.PetTargetLabels[opt.TargetPet]
            if not picked then return nil end
            local gained, msg = xDTaraZ.Pet.FarmAndHatchTarget(picked, opt.TargetPetCopies or 1)
            return msg or (gained > 0 and ("Acquired %d!"):format(gained) or "Incubating")
        end, function(msg)
            return tostring(msg or "Done")
        end) }):AddButton(RefreshButton("TargetPet", xDTaraZ.Pet.Choices))
        targetBox:AddButton({ Text = T("Lock All High-Tier Pets", "ล็อคสัตว์เลี้ยงระดับแรร์ทั้งหมด"), Style = "Success", Func = Action(function()
            local locked = xDTaraZ.Pet.LockAllGodPets()
            Notify(("Locked %d high-tier pets"):format(locked or 0), "Success")
        end) })
    end

    local function BuildPlayer(tab)
        local raceBox = tab:AddLeftGroupbox(T("Race", "เผ่า"))
        local raceLabels, raceIds = Source(xDTaraZ.Race.Choices)
        raceBox:AddDropdown("RaceTargets", {
            Text = T("Target Races", "เผ่าที่ต้องการ"),
            Values = raceLabels,
            Multi = true,
            Default = {},
            Searchable = #raceLabels > 8,
            Callback = function(selected)
                local ids = {}
                for label, on in pairs(selected) do
                    if on and raceIds[label] then ids[raceIds[label]] = true end
                end
                opt.RaceTargets = ids
            end,
        })
        Decorate("RaceTargets", function(label) return raceIds[label] end)
        local rarityLabels, rarityLevels = Source(xDTaraZ.Race.RarityChoices)
        raceBox:AddDropdown("RaceMinRarity", {
            Text = T("Or Any Race Of", "หรือเผ่าระดับ"),
            Values = rarityLabels,
            Default = 1,
            Callback = function(value)
                opt.RaceMinLevel = rarityLevels[value]
            end,
        })
        local starByLabel = { ["Any"] = 0, ["2 Stars+"] = 2, ["3 Stars"] = 3 }
        raceBox:AddDropdown("RaceStar", {
            Text = T("Target Stars", "ดาวที่ต้องการ"),
            Values = { "Any", "2 Stars+", "3 Stars" },
            Default = 1,
            Callback = function(value)
                opt.RaceStar = starByLabel[value] or 0
            end,
        })
        raceBox:AddDropdown("RaceSlot", {
            Text = T("Roll Slot", "ช่องที่สุ่ม"),
            Values = Config.RaceSlots,
            Default = 1,
            Callback = function(value)
                opt.RaceSlot = value
            end,
        })
        Feature(raceBox, "AutoRace", T("Auto Roll Race", "สุ่มเผ่าอัตโนมัติ"), T("Rolls in the background until a chosen race shows up", "สุ่มเบื้องหลังจนกว่าจะได้เผ่าที่เลือก"), function(value)
            if not value or State.Rolling then return end
            if not next(opt.RaceTargets) and not opt.RaceMinLevel then
                Notify("Pick a target race first", "Warning")
                return Later(TurnOff, "AutoRace")
            end
            State.Rolling = true
            task.defer(function()
                if not opt.RaceAnim then xDTaraZ.Util.Try(xDTaraZ.Race.MuteAnim, true) end
                local ok, outcome, detail = pcall(xDTaraZ.Race.RollUntil)
                xDTaraZ.Util.Try(xDTaraZ.Race.MuteAnim, false)
                State.Rolling = false
                local used = State.RaceRolls or 0
                if not ok then
                    warn("[LootToForge] race roll:", outcome)
                elseif outcome == "got" then
                    Notify(("Got %s after %d rolls!"):format(tostring(detail), used), "Success", 8)
                elseif outcome == "empty" then
                    Notify("Out of race rolls. Enable Buy Rolls When Empty or collect season rewards", "Warning")
                elseif outcome == "blocked" then
                    Notify("Can't roll: " .. tostring(detail), "Warning")
                end
                Later(TurnOff, "AutoRace")
            end)
        end)
        Check(raceBox, "RaceBuyRolls", T("Buy Rolls When Empty", "ซื้อ roll เมื่อหมด"))
        Check(raceBox, "RaceLock", T("Lock Slot When Found", "ได้แล้วล็อกช่อง"))
        Check(raceBox, "RaceProtect", T("Never Replace Mythic+", "ไม่สุ่มทับเผ่า Mythic ขึ้นไป"))
        Check(raceBox, "RaceAnim", T("Show Roll Animation", "แสดงฉากสุ่ม"))
        Feature(raceBox, "AutoBestRace", T("Auto Equip Rare Race", "ใส่อัตโนมัติตามความหายาก"), T("Switches to your rarest race", "สลับไปใช้เผ่าที่หายากที่สุด"))
        raceBox:AddButton({ Text = T("Switch Now", "สลับเดี๋ยวนี้"), Func = Action(function()
            Notify(xDTaraZ.Race.EquipBest() and "Switched race slot" or "Already on your rarest race")
        end) })

        local moveBox = tab:AddRightGroupbox(T("Movement", "การเคลื่อนที่"))
        HotkeyFeature(moveBox, "SpeedOn", T("Speed", "ความเร็ว"), nil, xDTaraZ.Movement.Apply)
        moveBox:AddSlider("WalkSpeed", {
            Text = T("Walk Speed", "ความเร็วเดิน"),
            Min = 16, Max = 250, Default = opt.WalkSpeed, Rounding = 0,
            Callback = function(value)
                opt.WalkSpeed = value
                xDTaraZ.Movement.Apply()
            end,
        })
        HotkeyFeature(moveBox, "InfJump", T("Infinite Jump", "กระโดดไม่จำกัด"))

        local guardBox = tab:AddRightGroupbox(T("Survival", "เอาตัวรอด"))
        local godMode = Feature(guardBox, "GodMode", T("Invincible", "อมตะ"), T("Monsters and bosses can't kill you", "มอนสเตอร์และบอสฆ่าไม่ตาย"), function(value)
            if not value then
                if State.RestoreDamage then State.RestoreDamage() end
            elseif not xDTaraZ.Guard.HookDamage() then
                Notify("Invincible is not available on this executor", "Warning")
                task.defer(TurnOff, "GodMode")
            end
        end)
        NeedModule(godMode, ReplicatedStorage.CTRL.HPCTRL)
        local keepOre = Feature(guardBox, "KeepOre", T("Keep Ore On Death", "ตายแล้วแร่ไม่หาย"), nil, function(value)
            if not value then
                xDTaraZ.Guard.UnhookOreLoss()
            elseif not xDTaraZ.Guard.HookOreLoss() then
                Notify("Keep Ore On Death is not supported on this executor", "Warning")
                task.defer(TurnOff, "KeepOre")
            end
        end)
        xDTaraZ.Compat.NeedCap(keepOre, "Namecall")
    end

    local function BuildSettings(window)
        local settingsTab = window:AddSettingsTab()
        local runtimeBox = settingsTab:AddLeftGroupbox(T("Performance", "ประสิทธิภาพ"))
        NumberInput(runtimeBox, "ParallelJobs", T("Concurrent Tasks", "จำนวนงานพร้อมกัน"), T("1–8; inventory changes run in order", "1–8 งาน การแก้กระเป๋าทำตามลำดับ"), 1)
        NumberInput(runtimeBox, "WorkerLimit", T("Workers Per Task", "จำนวน worker ต่องาน"), T("1–32; lower this for slow connections", "1–32 ลดเมื่อเน็ตช้า"), 1)
        NumberInput(runtimeBox, "JobTimeout", T("Task Timeout (seconds)", "เวลารองานสูงสุด (วินาที)"), nil, 5)
        runtimeBox:AddButton({ Text = T("Retry Stopped Features", "ลองฟีเจอร์ที่หยุดอีกครั้ง"), Func = function()
            table.clear(xDTaraZ.GameLib.Failed)
            table.clear(State.RemoteCache)
            for key, info in pairs(State.JobStats) do
                if not info.ok and Options[key] then
                    State.Failures[key] = nil
                    State.LastRun[key] = nil
                    Options[key]:SetValue(true)
                end
            end
            Notify("Retry requested", "Info")
        end })
        local sessionBox = settingsTab:AddRightGroupbox(T("Session", "เซสชัน"))
        Toggle(sessionBox, "AutoRejoin", T("Auto Rejoin", "เข้าเกมใหม่อัตโนมัติ"), T("Rejoins the game by itself after a disconnect", "หลุดแล้วเข้าเกมใหม่เอง"))
        Toggle(sessionBox, "LowGraphics", T("FPS Boost", "เพิ่ม FPS"), T("Turns off 3D rendering to save CPU and GPU", "ปิดการแสดงผล 3D ประหยัด CPU/GPU"), xDTaraZ.Session.SetLowGraphics)
        sessionBox:AddButton({ Text = T("Rejoin Now", "เข้าเกมใหม่เดี๋ยวนี้"), Func = Action(xDTaraZ.Session.Rejoin) })
        sessionBox:AddButton({ Text = T("Hop To Emptiest Server", "ย้ายไปเซิร์ฟคนน้อยสุด"), Func = Action(function()
            if not xDTaraZ.Session.HopSmallest() then Notify("Server list unavailable, try again", "Warning") end
        end) })

        local spotBox = settingsTab:AddRightGroupbox(T("Position", "ตำแหน่ง"))
        spotBox:AddButton({ Text = T("Save Position", "บันทึกตำแหน่ง"), Func = Action(function()
            Notify(xDTaraZ.Session.SavePosition() and "Position saved" or "No character", "Info")
        end) }):AddButton({ Text = T("Go Back", "กลับไปจุดที่บันทึก"), Func = Action(function()
            if not xDTaraZ.Session.ReturnPosition() then Notify("Save a position first", "Warning") end
        end) })
    end

    local noteText = {
        EnhantStone_1 = "farming enhance stones",
        EnhantStone_2 = "farming rare enhance stones",
        Coin = "farming coins",
        Enhancing = "enhancing",
        NoTicket = "need a tower ticket",
        Done = "all at target",
    }

    local function TaskText()
        if State.Lock == "Index" then return "Index " .. (State.IndexNote or "planning") end
        if State.Lock then return State.Lock end
        if opt.MaxGear then return "Max Gear, " .. (noteText[State.GearNote] or "starting") end
        return "Idle"
    end

    local function UpdateStatus()
        local ok, profile = pcall(xDTaraZ.Data.Get)
        if not (ok and profile and statusLabel) then return end
        local eco = profile.Eco or {}
        local line = ("Level %d · Rebirth %d · Coins %s"):format(tonumber(eco.level) or 1, tonumber(eco.rebirth) or 0, xDTaraZ.Util.Abbreviate(eco.coin or 0))
        if (State.TowerLoot or 0) > 0 then
            line ..= ("\nTower loot x%d"):format(State.TowerLoot)
        end
        Later(statusLabel.SetText, statusLabel, line)
        local gearLine = "Equipped: " .. tostring(xDTaraZ.Gear.EquippedNames(profile) or "None")
        local petLine = tostring(xDTaraZ.Pet.StatusText(profile) or "")
        Later(gearLabel.SetText, gearLabel, gearLine .. "\n" .. petLine)
        Later(taskLabel.SetText, taskLabel, "Working on: " .. tostring(TaskText() or "Idle"))
    end

    local function BuildTabs()
        local Window = Library.Window
        Window:AddTabSection(T("Farm", "ฟาร์ม"))
        local MainTab = Window:AddTab(T("Main", "หลัก"), "house", T("Status, all-in-one mode and rewards", "สถานะ โหมดทำทุกอย่าง และรางวัล"))
        local GearTab = Window:AddTab(T("Gear", "อุปกรณ์"), "sword", T("Best gear, equip and enhance", "อุปกรณ์ที่ดีสุด ใส่ของ และตีบวก"))
        local PetTab = Window:AddTab(T("Pets & Eggs", "สัตว์เลี้ยงและไข่"), "heart", T("Hatch eggs, equip, feed, deploy and clean pet bag", "ฟักไข่ ใส่ ให้อาหาร ส่งสำรวจ และเคลียร์กระเป๋าสัตว์เลี้ยง"))
        local FarmTab = Window:AddTab(T("Combat & Farm", "ต่อสู้และฟาร์ม"), "swords", T("Stages, monsters, bosses and index", "ด่าน มอนสเตอร์ บอส และสมุดสะสม"))
        local ForgeTab = Window:AddTab(T("Forge", "หลอม"), "zap", T("Forge gear from any ore", "หลอมอุปกรณ์จากแร่ไหนก็ได้"))
        local SellTab = Window:AddTab(T("Sell", "ขาย"), "upload", T("Sell gear by type and rarity", "ขายอุปกรณ์ตามประเภทและ rarity"))
        Window:AddTabSection(T("Progress", "ความคืบหน้า"))
        local ProgressTab = Window:AddTab(T("Upgrade & Rebirth", "อัปเกรดและรีเบิร์ธ"), "sliders-horizontal", T("Training, rebirth and upgrades", "ฝึก รีเบิร์ธ และอัปเกรด"))
        local TowerTab = Window:AddTab(T("Tower", "หอคอย"), "shield", T("Tower loot and season pass", "ของจากหอคอย และซีซั่นพาส"))
        local SpawnTab = Window:AddTab(T("Spawn Items", "เสกของ"), "target", T("Target forging, shops, potions and tower coins", "หลอมเป้าหมาย ร้าน ยา และเหรียญหอคอย"))
        Window:AddTabSection(T("Other", "อื่นๆ"))
        local PlayerTab = Window:AddTab(T("Player", "ผู้เล่น"), "user", T("Race, movement and survival", "เผ่า การเคลื่อนที่ และเอาตัวรอด"))

        local sections = {
            { BuildMain, MainTab },
            { BuildGear, GearTab },
            { BuildPet, PetTab },
            { BuildFarm, FarmTab },
            { BuildForge, ForgeTab },
            { BuildSell, SellTab },
            { BuildProgress, ProgressTab },
            { BuildTower, TowerTab },
            { BuildSpawn, SpawnTab },
            { BuildPlayer, PlayerTab },
            { BuildSettings, Window },
        }
        for _, section in ipairs(sections) do
            xDTaraZ.Util.Try(section[1], section[2])
        end
        xDTaraZ.Util.Try(BlockMissing)

        Library:Every(Config.PumpInterval, Pump)
        task.spawn(function()
            while State.Alive do
                UpdateStatus()
                task.wait(Config.StatusInterval)
            end
        end)
    end

    local function Unload()
        Library:Unload()
    end
    Library:OnUnload(xDTaraZ.Scheduler.Stop)
    Library:OnUnload(function()
        if getgenv().LootToForgeUnload == Unload then getgenv().LootToForgeUnload = nil end
    end)
    getgenv().LootToForgeUnload = Unload

    Library:CreateWindow({
        Title = "LelHub Loot To Forge",
        SubTitle = "by LelSploit",
        MenuKey = Enum.KeyCode.RightShift,
        ConfigFolder = Config.SaveFolder,
        Language = "Auto",
        Theme = "Halloween",
        OnUnlocked = function()
            BuildTabs()
            xDTaraZ.Util.Try(xDTaraZ.Scheduler.Boot)
            Notify("Loaded", "Success")
            xDTaraZ.Util.Try(Library.LoadAutoloadConfig, Library)
            if xDTaraZ.Boss.HopWanted() and Options.BossHop then Options.BossHop:SetValue(true) end
        end,
    })
end

if getgenv().LootToForgeUnload then
    pcall(getgenv().LootToForgeUnload)
end


BuildInterface()
