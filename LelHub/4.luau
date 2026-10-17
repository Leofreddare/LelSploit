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

    local utilityTab = ui(window, "Tab", { Title = "Utilities", Icon = "sparkles" })
    local movement = ui(utilityTab, "Section", "Movement")

    if configuration.BasicMovement then
        for _, entry in ipairs({ { "WalkSpeed", "Walk speed", 16, 16, 500 }, { "JumpPower", "Jump power", 50, 0, 500 }, { "HipHeight", "Hip height", 2, 0, 50 } }) do
            local property = entry[1]
            slider(movement, property, entry[2], entry[3], entry[4], entry[5], function(value)
                basicValues[property] = value
            end)
        end

        toggle(movement, "Noclip", "Noclip", function(value)
            basicFlags.Noclip = value

            if not value then
                restoreBasicCollisions()
            end
        end)
        toggle(movement, "InfiniteJump", "Infinite jump", function(value)
            basicFlags.InfiniteJump = value
        end)
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local environment = type(getgenv) == "function" and getgenv() or _G

if environment.LelHubWheelieCleanup then
    pcall(environment.LelHubWheelieCleanup)
end

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local Window = Library:CreateWindow({
    Title = "LelHub Wheelie District",
    SubTitle = "by LelSploit",
    TabWidth = 150,
    Size = UDim2.fromOffset(670, 460),
    MinSize = Vector2.new(480, 360),
    Resize = true,
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift,
})
local vehicleTab = Window:CreateTab({ Title = "Vehicle", Icon = "bike" })
local FLY_SPEED = 60
local DRIVE_SPEED = 250
local WHEELIE_ANGLE = 30
local DRIVE_HOVER = 2.5
local mode = "off"
local wheelieOn = false
local aimOn = false
local currentVehicle, vehicleRoot
local bodyVelocity, bodyGyro
local alignAttach, alignOrient
local connections = {}
local syncing = true
local setMode

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function pressed(key)
    return not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(key)
end

local flyControl = vehicleTab:CreateToggle("VehicleFly", { Title = "Vehicle fly", Default = false })
local driveControl = vehicleTab:CreateToggle("VehicleDrive", { Title = "Drive assist", Default = false })
local aimControl = vehicleTab:CreateToggle("MouseAim", { Title = "Camera steering", Default = false })
local wheelieControl = vehicleTab:CreateToggle("Wheelie", { Title = "Auto wheelie", Default = false })
flyControl:OnChanged(function(value)
    if not syncing then
        setMode(value and "fly" or (mode == "fly" and "off" or mode))
    end
end)
driveControl:OnChanged(function(value)
    if not syncing then
        setMode(value and "drive" or (mode == "drive" and "off" or mode))
    end
end)
aimControl:OnChanged(function(value)
    if not syncing then
        aimOn = value
    end
end)
wheelieControl:OnChanged(function(value)
    if not syncing then
        wheelieOn = value
    end
end)
for _, entry in ipairs({
    { "FlySpeed", "Fly speed", 60, 10, 500, function(value) FLY_SPEED = value end },
    { "DriveSpeed", "Drive speed", 250, 16, 1400, function(value) DRIVE_SPEED = value end },
    { "WheelieAngle", "Wheelie angle", 30, 0, 75, function(value) WHEELIE_ANGLE = value end },
    { "HoverHeight", "Drive height", 2.5, 0, 12, function(value) DRIVE_HOVER = value end },
}) do
    local control = vehicleTab:CreateSlider(entry[1], { Title = entry[2], Default = entry[3], Min = entry[4], Max = entry[5], Rounding = 1 })
    control:OnChanged(entry[6])
end

local function refreshButtons()
    syncing = true
    flyControl:SetValue(mode == "fly")
    driveControl:SetValue(mode == "drive")
    aimControl:SetValue(aimOn)
    wheelieControl:SetValue(wheelieOn)
    syncing = false
end

local function getVehicle()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local seat = hum.SeatPart
    if not seat then return nil end
    local vehicle = seat.Parent
    if not vehicle or not vehicle:IsA("Model") then vehicle = seat end
    return vehicle, seat
end

local function releaseAlign()
    if alignOrient then alignOrient:Destroy(); alignOrient = nil end
    if alignAttach then alignAttach:Destroy(); alignAttach = nil end
end

local function cleanupForces()
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro     then bodyGyro:Destroy();     bodyGyro     = nil end
    releaseAlign()
end

local function updateVehicle()
    local vehicle, seat = getVehicle()
    if vehicle then
        if currentVehicle ~= vehicle then
            cleanupForces()
            currentVehicle = vehicle
            vehicleRoot = seat.AssemblyRootPart or seat
        end
    else
        if currentVehicle then
            cleanupForces()
            currentVehicle, vehicleRoot = nil, nil
        end
    end
end

local function ensureVelocity3D()
    if not vehicleRoot then return end
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.P = 1000
        bodyVelocity.Parent = vehicleRoot
    end
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
end

local function ensureVelocityGround()
    if not vehicleRoot then return end
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.P = 2000
        bodyVelocity.Parent = vehicleRoot
    end
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
end

local function ensureBodyGyro()
    if not vehicleRoot then return end
    if not bodyGyro then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.P = 1000
        bodyGyro.D = 50
        bodyGyro.Parent = vehicleRoot
    end
end

local function disableBodyGyro()
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
end

local function ensureAlign()
    if not vehicleRoot then return end
    if not alignAttach or not alignAttach.Parent then
        alignAttach = Instance.new("Attachment")
        alignAttach.Parent = vehicleRoot
    end
    if not alignOrient or not alignOrient.Parent then
        alignOrient = Instance.new("AlignOrientation")
        alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOrient.Attachment0 = alignAttach
        alignOrient.RigidityEnabled = true
        alignOrient.Enabled = false
        alignOrient.Parent = vehicleRoot
    end
end

local function setAlign(cf)
    if cf then
        ensureAlign()
        alignOrient.CFrame = cf
        alignOrient.Enabled = true
    elseif alignOrient then
        alignOrient.Enabled = false
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundY()
    if not vehicleRoot then return nil end
    rayParams.FilterDescendantsInstances = { currentVehicle, LocalPlayer.Character }
    local origin = Vector3.new(vehicleRoot.Position.X, vehicleRoot.Position.Y + 500, vehicleRoot.Position.Z)
    local hit = Workspace:Raycast(origin, Vector3.new(0, -1200, 0), rayParams)
    return hit and hit.Position.Y or nil
end

local function groundInfo()
    if not vehicleRoot then return nil end
    rayParams.FilterDescendantsInstances = { currentVehicle, LocalPlayer.Character }
    local origin = Vector3.new(vehicleRoot.Position.X, vehicleRoot.Position.Y + 500, vehicleRoot.Position.Z)
    local hit = Workspace:Raycast(origin, Vector3.new(0, -1200, 0), rayParams)
    return hit
end

setMode = function(newMode)
    mode = newMode
    if mode == "off" and not (wheelieOn or aimOn) then cleanupForces() end
    refreshButtons()
end

local mainLoop = RunService.RenderStepped:Connect(function(dt)
    updateVehicle()
    if not vehicleRoot then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end
    local camCF = camera.CFrame
    local camLook  = camCF.LookVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
    if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit else flatLook = Vector3.new(0, 0, -1) end
    local worldUp  = Vector3.new(0, 1, 0)

    local function pitched(base, deg)
        local r = math.rad(deg)
        return base * math.cos(r) + worldUp * math.sin(r)
    end

    local carLook = vehicleRoot.CFrame.LookVector
    local carFlat = Vector3.new(carLook.X, 0, carLook.Z)
    if carFlat.Magnitude > 0.001 then carFlat = carFlat.Unit else carFlat = flatLook end

    local function alignmentCF(baseDir)
        local dir = baseDir
        if wheelieOn then dir = pitched(dir, WHEELIE_ANGLE) end
        return CFrame.lookAt(vehicleRoot.Position, vehicleRoot.Position + dir, worldUp)
    end

    if mode == "off" then
        if wheelieOn or aimOn then
            if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
            disableBodyGyro()
            local base = aimOn and flatLook or carFlat
            setAlign(alignmentCF(base))
        else
            setAlign(nil)
        end

    elseif mode == "fly" then
        setAlign(nil)
        ensureVelocity3D(); ensureBodyGyro()

        local moveDir = Vector3.zero
        if pressed(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if pressed(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if pressed(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if pressed(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if pressed(Enum.KeyCode.Space) then moveDir = moveDir + worldUp end
        if pressed(Enum.KeyCode.LeftShift) then moveDir = moveDir - worldUp end
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end

        bodyVelocity.Velocity = moveDir * FLY_SPEED
        bodyGyro.CFrame = camCF

    elseif mode == "drive" then
        disableBodyGyro()

        local axis = 0
        if pressed(Enum.KeyCode.W) then axis = axis + 1 end
        if pressed(Enum.KeyCode.S) then axis = axis - 1 end

        local hit = groundInfo()
        local groundYVal = hit and hit.Position.Y or nil
        local targetY = groundYVal and (groundYVal + vehicleRoot.Size.Y / 2 + DRIVE_HOVER) or nil

        ensureVelocityGround()

        local v = carFlat * (axis * DRIVE_SPEED)

        if targetY then
            local diff = targetY - vehicleRoot.Position.Y
            local yVel = math.clamp(diff * 8, -80, 80)

            if vehicleRoot.Position.Y < targetY - 1 then
                local rot = vehicleRoot.CFrame - vehicleRoot.Position
                vehicleRoot.CFrame = CFrame.new(vehicleRoot.Position.X, targetY, vehicleRoot.Position.Z) * rot
                yVel = 0
            end

            bodyVelocity.Velocity = Vector3.new(v.X, yVel, v.Z)
        else
            bodyVelocity.Velocity = Vector3.new(v.X, -20, v.Z)
        end

        if aimOn or wheelieOn then
            local base = aimOn and flatLook or carFlat
            setAlign(alignmentCF(base))
        else
            setAlign(nil)
        end
    end
end)
table.insert(connections, mainLoop)

track(LocalPlayer.CharacterAdded:Connect(function()
    wait(0.1)
    setMode("off")
    wheelieOn = false
    aimOn = false
    refreshButtons()
    updateVehicle()
end))


local cleaned = false
local function cleanupWheelie()
    if cleaned then return end
    cleaned = true
    mode = "off"
    wheelieOn = false
    aimOn = false
    cleanupForces()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    connections = {}
    if not Library.Unloaded then Library:Destroy() end
end

environment.LelHubWheelieCleanup = cleanupWheelie
if Library.OnUnload then track(Library.OnUnload:Connect(cleanupWheelie)) end
vehicleTab:CreateButton({ Title = "Stop vehicle", Callback = function()
    if vehicleRoot then
        vehicleRoot.AssemblyLinearVelocity = Vector3.zero
        vehicleRoot.AssemblyAngularVelocity = Vector3.zero
    end
    setMode("off")
end })
vehicleTab:CreateButton({ Title = "Flip upright", Callback = function()
    if vehicleRoot then
        local look = vehicleRoot.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
        local position = vehicleRoot.Position + Vector3.new(0, 3, 0)
        vehicleRoot.CFrame = CFrame.lookAt(position, position + forward)
        vehicleRoot.AssemblyLinearVelocity = Vector3.zero
        vehicleRoot.AssemblyAngularVelocity = Vector3.zero
    end
end })
local sharedControls = installLelHubControls(Library, Window, {
    Name = "wheelie",
    BasicMovement = true,
    Cleanup = cleanupWheelie,
})
syncing = false
refreshButtons()
Window:SelectTab(1)
