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
        local title = config.Title or config.Name or config.Text or "Option"
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
        native:OnChanged(function(value)
            if hub.Stopped or api.Unloaded or (api.Controller and not api.Controller.Active) then return end
            control.Value = value
            if config.Callback then config.Callback(valueForCallback(value)) end
            for _, callback in ipairs(control.Callbacks) do callback(value) end
        end)
        function control:SetValue(value)
            if kind == "Dropdown" and type(value) == "table" and not spec.Multi then value = value[1] end
            if kind == "Colorpicker" and native.SetValueRGB then native:SetValueRGB(value) else native:SetValue(value) end
        end
        control.Set = control.SetValue
        function control:GetValue() return self.Value end
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
            return raw:CreateKeybind(nextId(), { Title = config.Name or config.Title, Default = config.CurrentKeybind or config.Default or "None", Mode = config.HoldToInteract and "Hold" or "Toggle", Callback = config.Callback })
        end
        for _, method in ipairs({ "CreateParagraph", "CreateLabel", "AddLabel", "AddParagraph", "CreateDivider", "AddDivider" }) do group[method] = status end
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
        return { Destroy = function() if result and result.Destroy then result:Destroy() end end }
    end
    function api:CreateWindow() return window end
    function api:Notify(config) hub:Notify(config.Content or config.Text or config.Title or "") end
    function api:Unload() api.Unloaded = true hub.Cleanup() end
    api.Destroy = api.Unload
    for _, method in ipairs({ "SetTheme", "LoadConfiguration", "SetLibrary", "BuildConfigSection", "ApplyToTab", "LoadAutoloadConfig", "IgnoreThemeSettings", "SetIgnoreIndexes", "SetFolder", "SetSaveFile" }) do api[method] = function() end end
    return api
end

local function createGameController(hub, source, options)
    local controller = { Active = false, Threads = {}, Connections = {}, Objects = {}, DrawingObjects = {}, Mirrors = {}, Signals = {}, Values = options.Inputs or {} }
    local proxies, originals = {}, {}
    local services = {}
    local sourceEnvironment
    local gameTab = hub:Tab("Game", "gamepad-2")
    local lastError = -math.huge
    local function report(message)
        if controller.Active and os.clock() - lastError > 5 then
            lastError = os.clock()
            hub:Notify(tostring(message))
        end
    end
    local function unwrap(value) return originals[value] or value end
    local function arguments(...)
        local values = table.pack(...)
        for index = 1, values.n do values[index] = unwrap(values[index]) end
        return values
    end
    local function invoke(callback, ...)
        if not controller.Active then return end
        local result = table.pack(pcall(callback, ...))
        if not result[1] then report(result[2]) return end
        return table.unpack(result, 2, result.n)
    end
    local function signal(raw, owner, name)
        local object = {}
        controller.Signals[owner] = controller.Signals[owner] or {}
        local listeners = controller.Signals[owner][name] or {}
        controller.Signals[owner][name] = listeners
        function object:Connect(callback)
            local entry = { Callback = callback, Enabled = true }
            local connection = raw:Connect(function(...) if entry.Enabled then invoke(callback, ...) end end)
            table.insert(listeners, entry)
            local wrapper = {}
            function wrapper:Disconnect() entry.Enabled = false connection:Disconnect() end
            function wrapper:Disable() entry.Enabled = false end
            function wrapper:Enable() entry.Enabled = true end
            setmetatable(wrapper, { __index = function(_, key) return connection[key] end })
            table.insert(controller.Connections, wrapper)
            return wrapper
        end
        object.connect = object.Connect
        function object:Once(callback)
            local connection
            connection = self:Connect(function(...) connection:Disconnect() callback(...) end)
            return connection
        end
        function object:Wait() return raw:Wait() end
        originals[object] = raw
        return object
    end
    local wrap
    local function wrapResults(...)
        local values = table.pack(...)
        for index = 1, values.n do
            local value = values[index]
            if proxies[value] then values[index] = proxies[value]
            elseif type(value) == "table" then
                local copy = {}
                for key, item in pairs(value) do copy[key] = proxies[item] or item end
                values[index] = copy
            end
        end
        return table.unpack(values, 1, values.n)
    end
    wrap = function(raw)
        if proxies[raw] then return proxies[raw] end
        local proxy, signalCache = {}, {}
        proxies[raw], originals[proxy] = proxy, raw
        setmetatable(proxy, {
            __index = function(_, key)
                local value = raw[key]
                if typeof(value) == "RBXScriptSignal" then
                    if not signalCache[key] then signalCache[key] = signal(value, raw, key) end
                    return signalCache[key]
                end
                if type(value) == "function" then
                    return function(_, ...)
                        local args = arguments(...)
                        if key == "BindToRenderStep" then
                            local callback = args[3]
                            args[3] = function(...) return invoke(callback, ...) end
                            table.insert(controller.Objects, function() raw:UnbindFromRenderStep(args[1]) end)
                        end
                        local result = table.pack(value(raw, table.unpack(args, 1, args.n)))
                        if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
                            return signal(result[1], raw, key .. tostring(args[1]))
                        end
                        return wrapResults(table.unpack(result, 1, result.n))
                    end
                end
                return proxies[value] or value
            end,
            __newindex = function(_, key, value)
                if raw:IsA("ScreenGui") and key == "Enabled" then raw.Enabled = false else raw[key] = unwrap(value) end
            end,
            __tostring = function() return tostring(raw) end,
        })
        return proxy
    end
    local function spawn(callback, delay, ...)
        local args = table.pack(...)
        local function run()
            if controller.Active then invoke(callback, table.unpack(args, 1, args.n)) end
        end
        local thread
        if delay then thread = task.delay(delay, run) else thread = task.spawn(run) end
        table.insert(controller.Threads, thread)
        return thread
    end
    local function fire(object, name, ...)
        local listeners = controller.Signals[object] and controller.Signals[object][name]
        local count = 0
        for _, entry in ipairs(listeners or {}) do
            if entry.Enabled then invoke(entry.Callback, ...) count = count + 1 end
        end
        return count
    end
    local function title(object)
        local text = object:IsA("TextButton") and object.Text or object:IsA("TextBox") and object.PlaceholderText or ""
        if text == "" or text:match("^[%s✓✔✕]*$") then
            local container = object.Parent
            for _ = 1, 2 do
                if not container then break end
                for _, child in ipairs(container:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text ~= "" and #child.Text < 100 then text = child.Text break end
                end
                if text ~= "" then break end
                container = container.Parent
            end
        end
        text = text:gsub("<[^>]+>", ""):gsub("\n", " ")
        if text == "" then text = object.Name end
        return text
    end
    local ignored = { ["X"] = true, ["✕"] = true, ["×"] = true, ["Close"] = true, ["Menu"] = true, ["Main"] = true, ["Settings"] = true, ["Credits"] = true }
    local function insideScreen(object)
        return object:FindFirstAncestorWhichIsA("ScreenGui") ~= nil
    end
    local mirrorSequence = 0
    local function mirror(object)
        if controller.Mirrors[object] or not object.Parent or not insideScreen(object) then return end
        local handlers = controller.Signals[object] or {}
        local label = title(object)
        if ignored[label] then return end
        mirrorSequence = mirrorSequence + 1
        local key = "Source_" .. mirrorSequence
        if object:IsA("GuiButton") and (handlers.MouseButton1Click or handlers.Activated or handlers.MouseButton1Down) then
            local button = hub:Button(gameTab, label, function()
                if fire(object, "Activated") == 0 and fire(object, "MouseButton1Click") == 0 then
                    fire(object, "MouseButton1Down")
                    fire(object, "MouseButton1Up")
                end
            end)
            controller.Mirrors[object] = button
            if object:IsA("TextButton") then table.insert(controller.Connections, object:GetPropertyChangedSignal("Text"):Connect(function()
                if button.SetTitle then button:SetTitle(title(object)) end
            end)) end
        elseif object:IsA("TextBox") and (handlers.FocusLost or handlers.GetPropertyChangedSignalText or handlers.Changed) then
            local input = gameTab:CreateInput(key, { Title = label, Default = object.Text, Finished = true })
            input:OnChanged(function(value)
                object.Text = tostring(value)
                fire(object, "FocusLost", true)
            end)
            controller.Mirrors[object] = input
        elseif object:IsA("Frame") and handlers.InputBegan then
            local lower = (object.Name .. " " .. label):lower()
            if not (lower:find("slider") or lower:find("track") or lower:find("bar")) then return end
            local slider = hub:Slider(gameTab, key, label .. " (%)", 50, 0, 100, function(percent)
                local position, size = object.AbsolutePosition, object.AbsoluteSize
                local input = { UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin, Position = Vector3.new(position.X + size.X * percent / 100, position.Y, 0) }
                fire(object, "InputBegan", input)
                local service = game:GetService("UserInputService")
                fire(service, "InputChanged", { UserInputType = Enum.UserInputType.MouseMovement, Position = input.Position })
                fire(service, "InputEnded", { UserInputType = Enum.UserInputType.MouseButton1, Position = input.Position })
                fire(object, "InputEnded", input)
            end)
            controller.Mirrors[object] = slider
        end
    end
    function controller:Stop()
        if not self.Active then return end
        self.Active = false
        for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        for _, thread in ipairs(self.Threads) do if thread ~= coroutine.running() then pcall(task.cancel, thread) end end
        for _, object in ipairs(self.DrawingObjects) do pcall(function() object:Remove() end) end
        for index = #self.Objects, 1, -1 do
            local object = self.Objects[index]
            pcall(function() if type(object) == "function" then object() else object:Destroy() end end)
        end
    end
    function controller:Start()
        if self.Active or self.Started then return end
        if type(setfenv) ~= "function" or type(loadstring) ~= "function" then
            hub:Notify("This executor does not support script environments.")
            return
        end
        local chunk, message = loadstring(source, "LelHub/" .. options.Name)
        if not chunk then hub:Notify(message) return end
        self.Started, self.Active = true, true
        local globals = setmetatable({}, { __index = type(getgenv) == "function" and getgenv() or _G })
        self.Globals = globals
        sourceEnvironment = setmetatable({ _G = globals, getgenv = function() return globals end }, { __index = getfenv() })
        sourceEnvironment.print, sourceEnvironment.warn = function() end, function() end
        sourceEnvironment.setclipboard, sourceEnvironment.toclipboard = function() end, function() end
        sourceEnvironment.Instance = { new = function(className, parent)
            local object = Instance.new(className, unwrap(parent))
            table.insert(self.Objects, object)
            if object:IsA("ScreenGui") then object.Enabled = false end
            if object:IsA("GuiObject") or object:IsA("LayerCollector") then return wrap(object) end
            return object
        end }
        sourceEnvironment.task = {
            spawn = function(callback, ...) return spawn(callback, nil, ...) end,
            defer = function(callback, ...) return spawn(callback, 0, ...) end,
            delay = function(seconds, callback, ...) return spawn(callback, seconds, ...) end,
            cancel = task.cancel,
            wait = function(seconds)
                if not self.Active then error("LelHub stopped", 0) end
                local elapsed = task.wait(seconds)
                if not self.Active then error("LelHub stopped", 0) end
                return elapsed
            end,
        }
        sourceEnvironment.wait, sourceEnvironment.spawn, sourceEnvironment.delay = sourceEnvironment.task.wait, sourceEnvironment.task.spawn, sourceEnvironment.task.delay
        local gameProxy = {}
        originals[gameProxy] = game
        setmetatable(gameProxy, { __index = function(_, key)
            if key == "GetService" or key == "service" then
                return function(_, name)
                    if not services[name] then services[name] = wrap(game:GetService(name)) end
                    return services[name]
                end
            end
            local value = game[key]
            if typeof(value) == "Instance" and value.Parent == game then return wrap(value) end
            if type(value) == "function" then return function(_, ...) local args = arguments(...) return value(game, table.unpack(args, 1, args.n)) end end
            return value
        end })
        sourceEnvironment.game = gameProxy
        sourceEnvironment.workspace, sourceEnvironment.Workspace = wrap(workspace), wrap(workspace)
        sourceEnvironment.typeof = function(value) return typeof(unwrap(value)) end
        sourceEnvironment.require = function(module) return require(unwrap(module)) end
        if getrawmetatable then sourceEnvironment.getrawmetatable = function(target) return getrawmetatable(unwrap(target)) end end
        if getconnections then sourceEnvironment.getconnections = function(event) return getconnections(unwrap(event)) end end
        if cloneref then sourceEnvironment.cloneref = function(target)
            local result = cloneref(unwrap(target))
            return proxies[result] or result
        end end
        if Drawing then sourceEnvironment.Drawing = { new = function(kind)
            local object = Drawing.new(kind)
            table.insert(self.DrawingObjects, object)
            return object
        end } end
        local nativeHook = hookfunction
        if nativeHook then sourceEnvironment.hookfunction = function(target, callback)
            local previous
            previous = nativeHook(target, function(...) if self.Active then return callback(...) end return previous(...) end)
            return previous
        end end
        local nativeMetahook = hookmetamethod
        if nativeMetahook then sourceEnvironment.hookmetamethod = function(target, method, callback)
            local previous
            previous = nativeMetahook(unwrap(target), method, function(...) if self.Active then return callback(...) end return previous(...) end)
            return previous
        end end
        sourceEnvironment.loadstring = function(text, name)
            local nested, errorMessage = loadstring(text, name)
            if nested then setfenv(nested, sourceEnvironment) end
            return nested, errorMessage
        end
        sourceEnvironment.LelHubUI = options.UI
        sourceEnvironment.LelHubInputs = self.Values
        sourceEnvironment.LelHubValue = function(key, default)
            local value = self.Values[key]
            if value == nil then return default end
            return value
        end
        setfenv(chunk, sourceEnvironment)
        spawn(chunk)
        local elapsed = 0
        table.insert(self.Connections, game:GetService("RunService").Heartbeat:Connect(function(delta)
            elapsed = elapsed + delta
            if not self.Active or elapsed < 0.2 then return end
            elapsed = 0
            for _, object in ipairs(self.Objects) do
                if typeof(object) == "Instance" then pcall(mirror, object) end
            end
        end))
    end
    hub:Add(function() controller:Stop() end)
    for _, setting in ipairs(options.Parameters or {}) do
        local key, default = setting.Key, setting.Default
        controller.Values[key] = default
        local function update(value)
            controller.Values[key] = value
            if controller.Globals then controller.Globals[key] = value end
        end
        if type(default) == "boolean" then
            hub:Toggle(gameTab, "Parameter_" .. key, setting.Title or key, update, default)
        else
            local field = gameTab:CreateInput("Parameter_" .. key, { Title = setting.Title or key, Default = tostring(default), Finished = true })
            field:OnChanged(function(value)
                if type(default) == "number" then value = tonumber(value) if value == nil then return end end
                update(value)
            end)
        end
    end
    hub:Button(gameTab, options.Action or "Enable game features", function() controller:Start() end)
    hub:Button(gameTab, "Stop game features", function()
        controller:Stop()
        hub:Notify("Stopped. Reload this hub to restart. Some game changes reset when you rejoin.")
    end)
    controller.Tab = gameTab
    return controller
end

local runtime = {}
function runtime.Open(options, source)
    local hub = createLelHub(options.Name)
    local api = createGameInterface(hub, options.Style)
    options.UI = api
    local controller = createGameController(hub, source, options)
    api.Controller = controller
    hub.GameController = controller
    hub:Finish()
    return hub
end
return runtime
