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
        { Name = "Global", File = "global.luau" },
        { Name = "Universal Enhancements", File = "Universal_Enhancements.luau" },
        { Name = "Client Tools", File = "Client_Tools.luau" },
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
    local window = library:CreateWindow({ Title = "LelHub", SubTitle = "by LelSploit", Size = UDim2.fromOffset(680, 470), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift })
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

local function createRayfieldCompatibility(name)
    local hub = createLelHub(name)
    local api = { Hub = hub }
    local count = 0
    function api:Notify(configuration) hub:Notify(configuration.Content or configuration.Title or "") end
    function api:Destroy() hub.Cleanup() end
    function api:LoadConfiguration() end
    function api:CreateWindow()
        local window = {}
        function window:CreateTab(title)
            local raw = hub:Tab(title, "grid")
            local tab = {}
            local function key(options)
                count = count + 1
                return options.Flag or name .. "_" .. count
            end
            function tab:CreateSection(title) return raw:CreateSection(title) end
            function tab:CreateLabel() return {} end
            function tab:CreateParagraph() return {} end
            function tab:CreateToggle(options)
                return hub:Toggle(raw, key(options), options.Name, options.Callback, options.CurrentValue)
            end
            function tab:CreateSlider(options)
                local increment = options.Increment or 1
                local minimum, maximum = options.Range[1], options.Range[2]
                if options.Name:lower():find("walk", 1, true) then minimum, maximum = 16, 500 end
                local rounding = math.max(0, math.ceil(-math.log(increment) / math.log(10)))
                return hub:Slider(raw, key(options), options.Name, options.CurrentValue or minimum, minimum, maximum, options.Callback, rounding)
            end
            function tab:CreateDropdown(options)
                local multi = options.MultipleOptions == true
                local current = options.CurrentOption or {}
                local default = multi and {} or current[1]
                if multi then for _, value in ipairs(current) do default[value] = true end end
                local control = raw:CreateDropdown(key(options), { Title = options.Name, Values = options.Options or {}, Default = default, Multi = multi })
                control:OnChanged(function(value)
                    local values = {}
                    if multi then for item, enabled in pairs(value or {}) do if enabled then table.insert(values, item) end end
                    elseif value ~= nil then values[1] = value end
                    if options.Callback then options.Callback(values) end
                end)
                return control
            end
            function tab:CreateInput(options)
                local control = raw:CreateInput(key(options), { Title = options.Name, Default = options.CurrentValue or "", Placeholder = options.PlaceholderText or "", Finished = true })
                control:OnChanged(function(value) if options.Callback then options.Callback(value) end end)
                return control
            end
            function tab:CreateButton(options) return hub:Button(raw, options.Name, options.Callback) end
            return tab
        end
        api.Window = window
        return window
    end
    function api:Finish(configuration) return hub:Finish(configuration) end
    return api
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace:FindFirstChild("CustomCamera")
if not Camera or not Camera:IsA("Camera") then
    Camera = Workspace.CurrentCamera
end

local Rayfield
local function LoadRayfield()
    Rayfield = createRayfieldCompatibility("Fluxo_PVP")
end
LoadRayfield()

local Settings = {
    AimEnabled  = true,
    AimKey      = Enum.UserInputType.MouseButton2,
    FOV         = 150,
    Smoothness  = 1.0,
    YOffset     = 1.5,
    VisCheck    = false,
    TeamCheck   = false,
    AutoSwitch  = true,
    OverrideCam = false,

    ESPEnabled  = true,
    ESPBoxes    = true,
    ESPTracers  = true,
    ESPInfo     = true,
    ESPDrawFOV  = true,
    ESPMaxDist  = 5000,
    ESPBoxScale = 1.5,

    HitboxEnabled      = false,
    HitboxSize         = 10,
    HitboxTransparency = 0.6,

    Notifications = true,
}

local CurrentTarget  = nil
local HoldingAim     = false
local ESPTable       = {}
local ScriptActive   = true

local FOVDraw = Drawing.new("Circle")
FOVDraw.Thickness    = 1
FOVDraw.NumSides     = 64
FOVDraw.Filled       = false
FOVDraw.ZIndex       = 1
FOVDraw.Transparency = 1
FOVDraw.Color        = Color3.fromRGB(255, 255, 255)

local TargetDraw = Drawing.new("Circle")
TargetDraw.Thickness = 2.5
TargetDraw.NumSides  = 32
TargetDraw.Filled    = false
TargetDraw.ZIndex    = 5
TargetDraw.Color     = Color3.fromRGB(255, 50, 50)

local function Notify(text)
    if not Settings.Notifications then return end
    pcall(function()
        Rayfield:Notify({
            Title    = "VoidScripts",
            Content  = text,
            Duration = 4,
            Image    = 4483362458,
        })
    end)
end

local function IsAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetAimPart(char)
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function GetAimPosition(part)
    return part.Position + Vector3.new(0, Settings.YOffset, 0)
end

local function GetHealth(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        return math.floor(hum.Health), math.floor(hum.MaxHealth)
    end
    return 0, 100
end

local function IsVisible(character, worldPos)
    if not Settings.VisCheck then return true end
    local origin    = Camera.CFrame.Position
    local direction = worldPos - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, direction, rayParams)
    if result and result.Instance then
        return result.Instance:IsDescendantOf(character)
    end
    return true
end

local function IsTargetValid(player)
    if player == LocalPlayer then return false end
    if Settings.TeamCheck and player.Team == LocalPlayer.Team then return false end
    return true
end

local function GetESP(player)
    if not ESPTable[player] then
        local box = Drawing.new("Square")
        box.Thickness = 1
        box.Filled    = false
        box.Visible   = false

        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Visible   = false

        local info = Drawing.new("Text")
        info.Size    = 13
        info.Center  = true
        info.Outline = true
        info.Font    = 2
        info.Visible = false

        ESPTable[player] = { Box = box, Tracer = tracer, Info = info }
    end
    return ESPTable[player]
end

local function RemoveESP(player)
    local data = ESPTable[player]
    if data then
        data.Box:Remove()
        data.Tracer:Remove()
        data.Info:Remove()
        ESPTable[player] = nil
    end
end

local function GetClosestPlayer()
    local screenCenter = Camera.ViewportSize / 2
    local closest      = nil
    local closestDist  = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if IsTargetValid(player) then
            local char = player.Character
            local part = char and GetAimPart(char)
            if part and IsAlive(char) then
                local aimPos = GetAimPosition(part)
                local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                if onScreen then
                    local screenDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                    if screenDist <= Settings.FOV and IsVisible(char, aimPos) then
                        local dist3D = (part.Position - Camera.CFrame.Position).Magnitude
                        if dist3D < closestDist then
                            closestDist = dist3D
                            closest = {
                                Player   = player,
                                Part     = part,
                                Position = pos,
                                Distance = dist3D,
                                Notified = false,
                            }
                        end
                    end
                end
            end
        end
    end

    return closest
end

local function RecursiveFindTools(folder, path, results)
    results = results or {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Tool") then
            table.insert(results, { Path = path .. obj.Name, Tool = obj })
        elseif obj:IsA("Folder") or obj:IsA("Model") then
            RecursiveFindTools(obj, path .. obj.Name .. ".", results)
        end
    end
    return results
end

local function GiveTool(tool, path)
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then
        Notify("No backpack found!")
        return
    end
    local clone = tool:Clone()
    clone.Parent = bp
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and char and not char:FindFirstChildOfClass("Tool") then
        pcall(function() hum:EquipTool(clone) end)
    end
    Notify("Gave: " .. tostring(path))
end

local AimKeyMap = {
    ["Right Mouse"]  = Enum.UserInputType.MouseButton2,
    ["Left Mouse"]   = Enum.UserInputType.MouseButton1,
    ["Middle Mouse"] = Enum.UserInputType.MouseButton3,
    ["Left Shift"]   = Enum.KeyCode.LeftShift,
    ["Left Alt"]     = Enum.KeyCode.LeftAlt,
    ["Left Control"] = Enum.KeyCode.LeftControl,
    ["E"]            = Enum.KeyCode.E,
    ["Q"]            = Enum.KeyCode.Q,
    ["F"]            = Enum.KeyCode.F,
    ["C"]            = Enum.KeyCode.C,
    ["V"]            = Enum.KeyCode.V,
    ["X"]            = Enum.KeyCode.X,
    ["Z"]            = Enum.KeyCode.Z,
    ["T"]            = Enum.KeyCode.T,
}
local AimKeyOptions = {
    "Right Mouse", "Left Mouse", "Middle Mouse", "Left Shift", "Left Alt",
    "Left Control", "E", "Q", "F", "C", "V", "X", "Z", "T",
}

local BuildUI

local function ReloadUI()
    if Rayfield then
        pcall(function() Rayfield:Destroy() end)
    end
    LoadRayfield()
    BuildUI()
    Rayfield:Finish()
end

function BuildUI()
    local Window = Rayfield:CreateWindow({
        Name             = "Void Scripts | FluxoPVP",
        LoadingTitle     = "Void Scripts",
        LoadingSubtitle  = "FluxoPVP Edition",
        ConfigurationSaving = {
            Enabled    = true,
            FolderName = "VoidScripts",
            FileName   = "VoidScriptsConfig",
        },
        KeySystem = false,
    })

    local AimTab    = Window:CreateTab("Aim", 4483362458)
    local ESPTab    = Window:CreateTab("ESP", 4483362458)
    local HitboxTab = Window:CreateTab("Hitbox", 4483362458)
    local GunTab    = Window:CreateTab("Guns", 4483362458)
    local MiscTab   = Window:CreateTab("Misc", 4483362458)

    AimTab:CreateSection("Aimbot")

    AimTab:CreateToggle({
        Name         = "Enable Aim Lock",
        CurrentValue = Settings.AimEnabled,
        Flag         = "AimEnabled",
        Callback     = function(v)
            Settings.AimEnabled = v
            Notify("Aim: " .. tostring(v))
        end,
    })

    AimTab:CreateSlider({
        Name         = "FOV Radius",
        Range        = { 10, 800 },
        Increment    = 1,
        Suffix       = "px",
        CurrentValue = Settings.FOV,
        Flag         = "AimFOV",
        Callback     = function(v) Settings.FOV = v end,
    })

    AimTab:CreateSlider({
        Name         = "Smoothness (1 = Hard Lock)",
        Range        = { 0.01, 1 },
        Increment    = 0.01,
        Suffix       = "",
        CurrentValue = Settings.Smoothness,
        Flag         = "AimSmoothness",
        Callback     = function(v) Settings.Smoothness = v end,
    })

    AimTab:CreateSlider({
        Name         = "Y-Offset",
        Range        = { 0, 5 },
        Increment    = 0.1,
        Suffix       = "studs",
        CurrentValue = Settings.YOffset,
        Flag         = "AimYOffset",
        Callback     = function(v) Settings.YOffset = v end,
    })

    AimTab:CreateSection("Filters")

    AimTab:CreateToggle({
        Name         = "Visibility Check",
        CurrentValue = Settings.VisCheck,
        Flag         = "AimVisCheck",
        Callback     = function(v) Settings.VisCheck = v end,
    })

    AimTab:CreateToggle({
        Name         = "Team Check",
        CurrentValue = Settings.TeamCheck,
        Flag         = "AimTeamCheck",
        Callback     = function(v) Settings.TeamCheck = v end,
    })

    AimTab:CreateToggle({
        Name         = "Auto Switch Target",
        CurrentValue = Settings.AutoSwitch,
        Flag         = "AimAutoSwitch",
        Callback     = function(v) Settings.AutoSwitch = v end,
    })

    AimTab:CreateToggle({
        Name         = "Override Camera",
        CurrentValue = Settings.OverrideCam,
        Flag         = "AimOverrideCam",
        Callback     = function(v) Settings.OverrideCam = v end,
    })

    AimTab:CreateSection("Input")

    AimTab:CreateDropdown({
        Name           = "Aim Key",
        Options        = AimKeyOptions,
        CurrentOption  = { "Right Mouse" },
        MultipleOptions = false,
        Flag           = "AimKeyDropdown",
        Callback       = function(Option)
            local name = type(Option) == "table" and Option[1] or Option
            local mapped = AimKeyMap[name]
            if mapped then
                Settings.AimKey = mapped
                Notify("Aim key set to " .. name)
            end
        end,
    })

    ESPTab:CreateSection("Visuals")

    ESPTab:CreateToggle({
        Name         = "Master ESP",
        CurrentValue = Settings.ESPEnabled,
        Flag         = "ESPEnabled",
        Callback     = function(v) Settings.ESPEnabled = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Boxes",
        CurrentValue = Settings.ESPBoxes,
        Flag         = "ESPBoxes",
        Callback     = function(v) Settings.ESPBoxes = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Tracers",
        CurrentValue = Settings.ESPTracers,
        Flag         = "ESPTracers",
        Callback     = function(v) Settings.ESPTracers = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Player Info",
        CurrentValue = Settings.ESPInfo,
        Flag         = "ESPInfo",
        Callback     = function(v) Settings.ESPInfo = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Draw FOV Circle",
        CurrentValue = Settings.ESPDrawFOV,
        Flag         = "ESPDrawFOV",
        Callback     = function(v) Settings.ESPDrawFOV = v end,
    })

    ESPTab:CreateSlider({
        Name         = "Max Distance",
        Range        = { 50, 5000 },
        Increment    = 10,
        Suffix       = "studs",
        CurrentValue = Settings.ESPMaxDist,
        Flag         = "ESPMaxDist",
        Callback     = function(v) Settings.ESPMaxDist = v end,
    })

    ESPTab:CreateSlider({
        Name         = "Box Scale",
        Range        = { 0.5, 3.0 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = Settings.ESPBoxScale,
        Flag         = "ESPBoxScale",
        Callback     = function(v) Settings.ESPBoxScale = v end,
    })

    HitboxTab:CreateSection("Hitbox Expander")

    HitboxTab:CreateToggle({
        Name         = "Enable Hitbox Expander",
        CurrentValue = Settings.HitboxEnabled,
        Flag         = "HitboxEnabled",
        Callback     = function(v)
            Settings.HitboxEnabled = v
            Notify("Hitbox: " .. tostring(v))
        end,
    })

    HitboxTab:CreateSlider({
        Name         = "Hitbox Size",
        Range        = { 1, 30 },
        Increment    = 0.5,
        Suffix       = "studs",
        CurrentValue = Settings.HitboxSize,
        Flag         = "HitboxSize",
        Callback     = function(v) Settings.HitboxSize = v end,
    })

    HitboxTab:CreateSlider({
        Name         = "Hitbox Visibility",
        Range        = { 0, 1 },
        Increment    = 0.1,
        Suffix       = "",
        CurrentValue = Settings.HitboxTransparency,
        Flag         = "HitboxTransparency",
        Callback     = function(v) Settings.HitboxTransparency = v end,
    })

    GunTab:CreateSection("Recursive Gun Giver")
    GunTab:CreateLabel("Scans ReplicatedStorage.GunModels recursively for Tools.")

    local gunList, gunMap = {}, {}
    do
        local folder = ReplicatedStorage:FindFirstChild("GunModels")
        if folder then
            for _, entry in ipairs(RecursiveFindTools(folder, "GunModels.")) do
                table.insert(gunList, entry.Path)
                gunMap[entry.Path] = entry.Tool
            end
        end
    end

    local gunOptions = (#gunList > 0) and gunList or { "<No guns found>" }
    local selectedGun = gunList[1]

    local gunDropdown = GunTab:CreateDropdown({
        Name            = "Select Gun",
        Options         = gunOptions,
        CurrentOption   = { gunOptions[1] },
        MultipleOptions = false,
        Flag            = "GunSelect",
        Callback        = function(Option)
            selectedGun = type(Option) == "table" and Option[1] or Option
        end,
    })

    GunTab:CreateButton({
        Name     = "Give Selected Gun",
        Callback = function()
            if not selectedGun or not gunMap[selectedGun] then
                Notify("No gun selected!")
                return
            end
            GiveTool(gunMap[selectedGun], selectedGun)
        end,
    })

    GunTab:CreateButton({
        Name     = "Give ALL Guns",
        Callback = function()
            if #gunList == 0 then
                Notify("No guns found in GunModels.")
                return
            end
            for path, tool in pairs(gunMap) do
                GiveTool(tool, path)
            end
        end,
    })

    GunTab:CreateButton({
        Name     = "Refresh Gun List",
        Callback = function()
            Notify("Rescanning GunModels...")
            gunList, gunMap = {}, {}
            local folder = ReplicatedStorage:FindFirstChild("GunModels")
            if folder then
                for _, entry in ipairs(RecursiveFindTools(folder, "GunModels.")) do
                    table.insert(gunList, entry.Path)
                    gunMap[entry.Path] = entry.Tool
                end
            end
            gunOptions = #gunList > 0 and gunList or { "<No guns found>" }
            selectedGun = gunList[1]
            gunDropdown:SetValues(gunOptions)
            gunDropdown:SetValue(gunOptions[1])
        end,
    })

    MiscTab:CreateSection("General")

    MiscTab:CreateToggle({
        Name         = "Notifications",
        CurrentValue = Settings.Notifications,
        Flag         = "Notifications",
        Callback     = function(v) Settings.Notifications = v end,
    })

    MiscTab:CreateButton({
        Name     = "Join Discord",
        Callback = function()
            local link = "https://discord.gg/fuECzR3dM3"
            local success, err = pcall(function()
                setclipboard(link)
            end)
            if success then
                Notify("Copied to Clipboard")
            else
                Notify("Failed to copy: " .. tostring(err))
            end
        end,
    })

    MiscTab:CreateButton({
        Name     = "Unload Script",
        Callback = function()
            ScriptActive = false

            for _, p in ipairs(Players:GetPlayers()) do
                RemoveESP(p)
                local char = p.Character
                if char then
                    local old = char:FindFirstChild("DevHitbox")
                    if old then old:Destroy() end
                end
            end

            pcall(function() FOVDraw:Remove() end)
            pcall(function() TargetDraw:Remove() end)

            Notify("Unloaded.")
            task.wait(0.2)
            pcall(function() Rayfield:Destroy() end)
        end,
    })

    pcall(function() Rayfield:LoadConfiguration() end)
end

BuildUI()
Rayfield:Finish()

Rayfield.Hub:Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if not ScriptActive then return end

    if input.KeyCode == Settings.AimKey or input.UserInputType == Settings.AimKey then
        HoldingAim = true
    end
end)

Rayfield.Hub:Connect(UserInputService.InputEnded, function(input)
    if input.KeyCode == Settings.AimKey or input.UserInputType == Settings.AimKey then
        HoldingAim   = false
        CurrentTarget = nil
    end
end)

Rayfield.Hub:Connect(RunService.RenderStepped, function()
    if not ScriptActive then return end

    if not Camera or not Camera.Parent then
        Camera = Workspace:FindFirstChild("CustomCamera")
        if not Camera or not Camera:IsA("Camera") then
            Camera = Workspace.CurrentCamera
        end
    end
    if not Camera then return end

    if Settings.ESPDrawFOV then
        FOVDraw.Position = Camera.ViewportSize / 2
        FOVDraw.Radius   = Settings.FOV
        FOVDraw.Visible  = true
    else
        FOVDraw.Visible = false
    end

    if Settings.AimEnabled and HoldingAim then
        local valid = false

        if CurrentTarget then
            local char = CurrentTarget.Player.Character
            local part = char and GetAimPart(char)
            if part and IsAlive(char) and IsTargetValid(CurrentTarget.Player) then
                local aimPos = GetAimPosition(part)
                local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                if onScreen then
                    local sd = (Vector2.new(pos.X, pos.Y) - Camera.ViewportSize / 2).Magnitude
                    if sd <= Settings.FOV and IsVisible(char, aimPos) then
                        valid = true
                        CurrentTarget.Part     = part
                        CurrentTarget.Position = pos
                        CurrentTarget.Distance = (part.Position - Camera.CFrame.Position).Magnitude
                    end
                end
            end
        end

        if not valid then
            CurrentTarget = Settings.AutoSwitch and GetClosestPlayer() or nil
        end

        if CurrentTarget then
            local part   = CurrentTarget.Part
            local aimPos = GetAimPosition(part)

            if Settings.OverrideCam then
                Camera.CameraType = Enum.CameraType.Scriptable
            end

            local targetCF = CFrame.new(Camera.CFrame.Position, aimPos)
            if Settings.Smoothness >= 0.99 then
                Camera.CFrame = targetCF
            else
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, Settings.Smoothness)
            end

            local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
            if onScreen then
                TargetDraw.Position = Vector2.new(pos.X, pos.Y)
                TargetDraw.Radius   = math.clamp(500 / pos.Z, 5, 30)
                TargetDraw.Visible  = true
            else
                TargetDraw.Visible = false
            end

            if not CurrentTarget.Notified then
                CurrentTarget.Notified = true
                Notify("Locked: " .. CurrentTarget.Player.Name ..
                       " | " .. math.floor(CurrentTarget.Distance) .. " studs")
            end
        else
            TargetDraw.Visible = false
        end
    else
        CurrentTarget      = nil
        TargetDraw.Visible = false
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local data = GetESP(player)
            data.Box.Visible    = false
            data.Tracer.Visible = false
            data.Info.Visible   = false

            if Settings.ESPEnabled then
                local char = player.Character
                local part = char and GetAimPart(char)
                if part and IsAlive(char) and IsTargetValid(player) then
                    local dist = (part.Position - Camera.CFrame.Position).Magnitude
                    if dist <= Settings.ESPMaxDist then
                        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenPos = Vector2.new(pos.X, pos.Y)
                            local hp, maxHp = GetHealth(char)
                            local locked    = CurrentTarget and CurrentTarget.Player == player

                            if Settings.ESPTracers then
                                data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                data.Tracer.To   = screenPos
                                data.Tracer.Color = locked and Color3.fromRGB(255, 0, 0)
                                                             or Color3.fromRGB(255, 255, 255)
                                data.Tracer.Transparency = locked and 1 or 0.6
                                data.Tracer.Visible = true
                            end

                            if Settings.ESPBoxes then
                                local scale = math.clamp(1500 / pos.Z, 40, 200) * Settings.ESPBoxScale
                                data.Box.Size     = Vector2.new(scale * 0.65, scale)
                                data.Box.Position = screenPos - data.Box.Size / 2
                                data.Box.Color    = locked and Color3.fromRGB(255, 0, 0)
                                                             or Color3.fromRGB(0, 255, 100)
                                data.Box.Visible  = true
                            end

                            if Settings.ESPInfo then
                                data.Info.Position = screenPos - Vector2.new(0, 40)
                                data.Info.Text     = player.Name .. "\nHP:" .. hp .. "/" .. maxHp ..
                                                     " | " .. math.floor(dist) .. " studs"
                                data.Info.Color    = locked and Color3.fromRGB(255, 200, 50)
                                                             or Color3.fromRGB(255, 255, 255)
                                data.Info.Visible  = true
                            end
                        end
                    end
                end
            end
        end
    end

    if Settings.HitboxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local expander = char:FindFirstChild("DevHitbox")
                        if not expander then
                            expander = Instance.new("Part")
                            expander.Name       = "DevHitbox"
                            expander.Shape      = Enum.PartType.Ball
                            expander.Material   = Enum.Material.ForceField
                            expander.Color      = Color3.fromRGB(255, 0, 0)
                            expander.CanCollide = false
                            expander.Anchored   = false
                            expander.Parent     = char

                            local weld = Instance.new("Weld", expander)
                            weld.Part0 = hrp
                            weld.Part1 = expander
                        end
                        expander.Size = Vector3.new(
                            Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize
                        )
                        expander.Transparency = 1 - Settings.HitboxTransparency
                    end
                end
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char then
                    local old = char:FindFirstChild("DevHitbox")
                    if old then old:Destroy() end
                end
            end
        end
    end
end)

Rayfield.Hub:Connect(Players.PlayerRemoving, function(player)
    RemoveESP(player)
    if CurrentTarget and CurrentTarget.Player == player then
        CurrentTarget = nil
    end
end)

Notify("Void Scripts Loaded | FluxoPVP Edition")

Rayfield.Hub:Add(function()
    ScriptActive = false
    HoldingAim = false
    for _, target in ipairs(Players:GetPlayers()) do
        RemoveESP(target)
        local character = target.Character
        local hitbox = character and character:FindFirstChild("DevHitbox")
        if hitbox then hitbox:Destroy() end
    end
    pcall(function() FOVDraw:Remove() end)
    pcall(function() TargetDraw:Remove() end)
end)
