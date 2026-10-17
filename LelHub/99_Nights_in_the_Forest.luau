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

local lelEnvironment = type(getgenv) == "function" and getgenv() or _G
if lelEnvironment.LelHubforestCleanup then
    pcall(lelEnvironment.LelHubforestCleanup)
end

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = "LelHub",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(670, 460),
    Resize = true,
    MinSize = Vector2.new(480, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
}

local Tabs = {
    Resources  = Window:CreateTab{ Title = "Resources",  Icon = "phosphor-tree-bold" },
    Player     = Window:CreateTab{ Title = "Player",     Icon = "phosphor-user-circle-bold" },
    Combat     = Window:CreateTab{ Title = "Combat",     Icon = "phosphor-crosshair-bold" },
    Kids       = Window:CreateTab{ Title = "Kids",       Icon = "phosphor-user-focus-bold" },
    Landmarks  = Window:CreateTab{ Title = "Landmarks",  Icon = "phosphor-map-pin-bold" },
    Teammates  = Window:CreateTab{ Title = "Teammates",  Icon = "phosphor-users-three-bold" }
}

local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local VirtualInputManager   = game:GetService("VirtualInputManager")
local UserInputService      = game:GetService("UserInputService")
local RunService            = game:GetService("RunService")
local Lighting              = game:GetService("Lighting")
local ContextActionService  = game:GetService("ContextActionService")
local player                = Players.LocalPlayer
local character
local humanoidRootPart
local inventory, sack, itemsFolder, characters, mapFolder, landmarksFolder

local items, kids, landmarks, teammates = {}, {}, {}, {}
local name, kidName, landmarkName, teammateName
local lastPos, bringAllActive = nil, false
local visitedChests = {}

local pickupRadius = 20
local flySpeed     = 100
local freecamSpeed = 50
local aimIntensity = 150
local playerSpeed  = 16
local playerJump   = 50

local function addSpacer(tab) pcall(function() tab:AddSection(" ") end) end
local function isChestName(n)
    if not n then return false end
    return string.find(string.lower(n), "chest") ~= nil
end

local function findSack()
    if inventory then
        for _, i in pairs(inventory:GetChildren()) do
            if string.find(i.Name, "Sack") then return i end
        end
    end
    if character then
        for _, i in pairs(character:GetChildren()) do
            if string.find(i.Name, "Sack") then return i end
        end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, i in pairs(bp:GetChildren()) do
            if string.find(i.Name, "Sack") then return i end
        end
    end
end

local function refreshSack() sack = findSack() end

local function onCharacterAdded(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.2)
    refreshSack()
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

local function isSackFull()
    if not sack then return true end
    local c, cap = sack:GetAttribute("NumberItems"), sack:GetAttribute("Capacity")
    if c == nil then
        for _, ch in ipairs(sack:GetChildren()) do
            if ch:GetAttribute("NumberItems") ~= nil then
                c, cap = ch:GetAttribute("NumberItems"), ch:GetAttribute("Capacity")
                break
            end
        end
    end
    if c == nil or cap == nil then return false end
    return c >= cap
end

local function storeItem(item)
    if not item or not item.Parent then return true end
    if not sack then refreshSack() end
    if not sack then return false end
    local part = item:FindFirstChildWhichIsA("BasePart")
    if not part then return false end
    local rf = ReplicatedStorage:FindFirstChild("RemoteEvents")
    local remote = rf and rf:FindFirstChild("RequestBagStoreItem")
    if not remote then return false end
    for attempt = 1, 2 do
        if not item.Parent then return true end
        humanoidRootPart.CFrame = part.CFrame
        task.wait(0.15)
        pcall(function() remote:InvokeServer(sack, item) end)
        local w = 0
        while item.Parent and w < 0.4 do task.wait(0.02); w = w + 0.02 end
        if not item.Parent then return true end
    end
    return false
end

local function dropAllFromSack(count)
    if count <= 0 then return end
    local cam = workspace.CurrentCamera
    if character and sack then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(sack) end); task.wait(0.15) end
    end
    local skyPos = humanoidRootPart.Position + Vector3.new(0, 800, 0)
    local screen = cam:WorldToScreenPoint(skyPos)
    VirtualInputManager:SendMouseMoveEvent(screen.X, screen.Y, game)
    task.wait(0.1)
    for i = 1, count do
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F, false, game)
        task.wait(0.07)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        task.wait(0.18)
    end
end

local function getClosestToOrigin(targetName, containers)
    if not targetName or targetName == "" then return nil end
    local isChest = isChestName(targetName)
    local best, bestDist = nil, math.huge
    for _, c in ipairs(containers) do
        if c then
            for _, item in pairs(c:GetChildren()) do
                if item.Name == targetName and item.Parent then
                    if not (isChest and visitedChests[item]) then
                        local part = item:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local d = (part.Position - Vector3.new(0,0,0)).Magnitude
                            if d < bestDist then bestDist = d; best = item end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function findClosestValid(folder, targetName)
    if not folder then return nil end
    local isChest = isChestName(targetName)
    local best, bd = nil, math.huge
    for _, item in pairs(folder:GetChildren()) do
        if item.Name == targetName and item.Parent then
            if not (isChest and visitedChests[item]) then
                local p = item:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d = (p.Position - Vector3.new(0,0,0)).Magnitude
                    if d < bd then bd = d; best = item end
                end
            end
        end
    end
    return best
end

local ItemsDropdown = Tabs.Resources:CreateDropdown("ItemsList", { Title = "Items List", Values = {}, Multi = false, Default = "" })
ItemsDropdown:OnChanged(function(v) name = v; visitedChests = {} end)

local KidsDropdown = Tabs.Kids:CreateDropdown("KidsList", { Title = "Kids List", Values = {}, Multi = false, Default = "" })
KidsDropdown:OnChanged(function(v) kidName = v end)

local LandmarkDropdown = Tabs.Landmarks:CreateDropdown("LandmarksList", { Title = "Landmarks List", Values = {}, Multi = false, Default = "" })
LandmarkDropdown:OnChanged(function(v) landmarkName = v end)

local TeammateDropdown = Tabs.Teammates:CreateDropdown("TeammateList", { Title = "Teammate List", Values = {}, Multi = false, Default = "" })
TeammateDropdown:OnChanged(function(v) teammateName = v end)


Tabs.Resources:CreateButton{
    Title = "Teleport to Item",
    Callback = function()
        local t = getClosestToOrigin(name, { itemsFolder, characters })
        if not t then return end
        local p = t:FindFirstChildWhichIsA("BasePart")
        if p then
            humanoidRootPart.CFrame = p.CFrame
            if isChestName(name) then visitedChests[t] = true end
        end
    end
}

Tabs.Resources:CreateButton{
    Title = "Bring Item",
    Callback = function()
        if not sack then refreshSack() end
        if not sack then return end
        if not itemsFolder then itemsFolder = workspace:FindFirstChild("Items") end
        if not itemsFolder or not name or name == "" then return end
        lastPos = humanoidRootPart.CFrame
        local best = findClosestValid(itemsFolder, name)
        if not best then return end
        local ok = storeItem(best)
        if isChestName(name) then visitedChests[best] = true end
        humanoidRootPart.CFrame = lastPos
        task.wait(0.25)
        if ok then dropAllFromSack(1) end
    end
}

Tabs.Resources:CreateButton{
    Title = "Bring All",
    Callback = function()
        if bringAllActive then bringAllActive = false; return end
        if not sack then refreshSack() end
        if not sack then return end
        if not name or name == "" then return end
        if not itemsFolder then itemsFolder = workspace:FindFirstChild("Items") end
        if not itemsFolder then return end
        bringAllActive = true
        lastPos = humanoidRootPart.CFrame
        local storedCount = 0
        while bringAllActive do
            if isSackFull() then break end
            local nextItem = findClosestValid(itemsFolder, name)
            if not nextItem then break end
            if storeItem(nextItem) then storedCount = storedCount + 1 end
            if isChestName(name) then visitedChests[nextItem] = true end
        end
        humanoidRootPart.CFrame = lastPos
        task.wait(0.3)
        dropAllFromSack(storedCount)
        bringAllActive = false
    end
}

addSpacer(Tabs.Resources)

Tabs.Resources:CreateButton{
    Title = "Pickup Nearby Items",
    Callback = function()
        if not sack then refreshSack() end
        if not itemsFolder then itemsFolder = workspace:FindFirstChild("Items") end
        if not itemsFolder or not sack then return end
        local startPos = humanoidRootPart.CFrame
        local myPos = humanoidRootPart.Position
        local cands = {}
        for _, item in pairs(itemsFolder:GetChildren()) do
            local p = item:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (p.Position - myPos).Magnitude
                if d <= pickupRadius then table.insert(cands, { item = item, dist = d }) end
            end
        end
        table.sort(cands, function(a, b) return a.dist < b.dist end)
        local storedCount = 0
        for _, e in ipairs(cands) do
            if isSackFull() then break end
            if e.item and e.item.Parent then
                if storeItem(e.item) then storedCount = storedCount + 1 end
            end
        end
        humanoidRootPart.CFrame = startPos
        task.wait(0.2)
        dropAllFromSack(storedCount)
    end
}

Tabs.Resources:AddSlider("PickupRadiusSlider", {
    Title = "Pickup Radius", Description = "Studs radius",
    Default = 20, Min = 5, Max = 500, Rounding = 0,
    Callback = function(v) pickupRadius = v end
})


local BIG_TREE_NAMES = { TreeBig1 = true, TreeBig2 = true, TreeBig3 = true }
local treeHighlights = {}
local espActive = false
local espConnections = {}
local scanRunning = false

local function makeHighlight(obj, color, name)
    if treeHighlights[obj] then return end
    if not obj or not obj.Parent then return end
    local hl = Instance.new("Highlight")
    hl.Name = name or "LelHubESP"
    hl.Adornee = obj
    hl.FillColor = color or Color3.fromRGB(0, 255, 130)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0.3
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = obj
    treeHighlights[obj] = hl
end

local function clearHighlights()
    for _, hl in pairs(treeHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    treeHighlights = {}
end

local function scanAsync()
    if scanRunning then return end
    scanRunning = true
    task.spawn(function()
        if mapFolder then
            for _, obj in ipairs(mapFolder:GetDescendants()) do
                if not espActive then scanRunning = false; return end
                if obj:IsA("Model") and BIG_TREE_NAMES[obj.Name] then
                    makeHighlight(obj, Color3.fromRGB(0, 255, 130), "LelHubTreeESP")
                end
            end
        end
        scanRunning = false
    end)
end

Tabs.Resources:AddToggle("BigTreeESP", {
    Title = "Big Tree ESP",
    Default = false,
    Callback = function(state)
        espActive = state
        if state then
            scanAsync()
            if mapFolder then
                table.insert(espConnections, mapFolder.DescendantAdded:Connect(function(obj)
                    if not espActive then return end
                    if obj:IsA("Model") and BIG_TREE_NAMES[obj.Name] then
                        task.defer(function()
                            if espActive and obj.Parent then
                                makeHighlight(obj, Color3.fromRGB(0, 255, 130), "LelHubTreeESP")
                            end
                        end)
                    end
                end))
            end
        else
            clearHighlights()
            for _, c in ipairs(espConnections) do
                if c and c.Disconnect then c:Disconnect() end
            end
            espConnections = {}
        end
    end
})


local CULTIST_NAMES = { Cultist = true, ["Crossbow Cultist"] = true }
local cultistHighlights = {}
local cultistEspActive = false
local cultistEspConnections = {}
local cultistScanRunning = false
local lastCultistPoll = 0

local function makeCultistHighlight(obj)
    if cultistHighlights[obj] then return end
    if not obj or not obj.Parent then return end
    local hl = Instance.new("Highlight")
    hl.Name = "LelHubCultistESP"
    hl.Adornee = obj
    hl.FillColor = Color3.fromRGB(255, 40, 40)
    hl.OutlineColor = Color3.fromRGB(255, 200, 200)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.15
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = obj
    cultistHighlights[obj] = hl
end

local function clearCultistHighlights()
    for _, hl in pairs(cultistHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    cultistHighlights = {}
end

local function cultistScanAsync()
    if cultistScanRunning then return end
    cultistScanRunning = true
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not cultistEspActive then cultistScanRunning = false; return end
            if obj:IsA("Model") and CULTIST_NAMES[obj.Name] then
                makeCultistHighlight(obj)
            end
        end
        cultistScanRunning = false
    end)
end

Tabs.Combat:AddToggle("CultistESP", {
    Title = "Cultist ESP",
    Default = false,
    Callback = function(state)
        cultistEspActive = state
        if state then
            cultistScanAsync()
            table.insert(cultistEspConnections, workspace.DescendantAdded:Connect(function(obj)
                if not cultistEspActive then return end
                if obj:IsA("Model") and CULTIST_NAMES[obj.Name] then
                    task.defer(function()
                        if cultistEspActive and obj.Parent then
                            makeCultistHighlight(obj)
                        end
                    end)
                end
            end))

            table.insert(cultistEspConnections, RunService.Heartbeat:Connect(function()
                if not cultistEspActive then return end
                local now = tick()
                if now - lastCultistPoll < 1 then return end
                lastCultistPoll = now
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if not cultistEspActive then return end
                    if obj:IsA("Model") and CULTIST_NAMES[obj.Name] and not cultistHighlights[obj] then
                        makeCultistHighlight(obj)
                    end
                end
            end))
        else
            clearCultistHighlights()
            for _, c in ipairs(cultistEspConnections) do
                if c and c.Disconnect then c:Disconnect() end
            end
            cultistEspConnections = {}
        end
    end
})

addSpacer(Tabs.Combat)

local function getAimTargets()
    local list = {}
    if characters then
        for _, m in ipairs(characters:GetChildren()) do
            if m:IsA("Model") then
                local head, hum = m:FindFirstChild("Head"), m:FindFirstChildOfClass("Humanoid")
                if head and head:IsA("BasePart") and hum and hum.Health > 0 then
                    table.insert(list, head)
                end
            end
        end
    end
    return list
end

local function screenPosOf(wp)
    local cam = workspace.CurrentCamera
    local sp, on = cam:WorldToViewportPoint(wp.Position)
    if not on then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function findNearestToCursor()
    local mp = UserInputService:GetMouseLocation()
    local best, bd = nil, aimIntensity
    for _, head in ipairs(getAimTargets()) do
        local sp = screenPosOf(head)
        if sp then
            local d = (sp - mp).Magnitude
            if d < bd then bd = d; best = head end
        end
    end
    return best
end

local function targetUnderCursor()
    local cam = workspace.CurrentCamera
    local mp = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mp.X, mp.Y)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { character }
    local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, rp)
    if res and res.Instance then
        local model = res.Instance:FindFirstAncestorOfClass("Model")
        if model and characters and model.Parent == characters then
            local h = model:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return model end
        end
    end
    return nil
end

local function snapToTarget(target)
    local cam = workspace.CurrentCamera
    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, target.Position)
    if humanoidRootPart then
        local flat = Vector3.new(target.Position.X - humanoidRootPart.Position.X, 0, target.Position.Z - humanoidRootPart.Position.Z)
        if flat.Magnitude > 0.05 then
            humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + flat.Unit)
        end
    end
end

local aimbotActive, aimbotFiring = false, false
local AIMBOT_ACTION = "LelHubAimbotFire"

local function aimbotHandler(_, state, _)
    if not aimbotActive then return Enum.ContextActionResult.Pass end
    if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
    if aimbotFiring then return Enum.ContextActionResult.Sink end
    aimbotFiring = true
    task.spawn(function()
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool then tool.Enabled = false end
        local t = findNearestToCursor()
        if t then snapToTarget(t); task.wait(0.04) end
        if tool then tool.Enabled = true end
        if t then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
            VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
        end
        task.wait(0.15)
        aimbotFiring = false
    end)
    return Enum.ContextActionResult.Sink
end

local function unbindAimbotAction()
    pcall(function() ContextActionService:UnbindAction(AIMBOT_ACTION) end)
end

local function bindAimbotAction()
    unbindAimbotAction()
    ContextActionService:BindActionAtPriority(AIMBOT_ACTION, aimbotHandler, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1)
end

Tabs.Combat:AddToggle("AimbotToggle", {
    Title = "Aimbot", Default = false,
    Callback = function(state)
        aimbotActive = state
        if state then bindAimbotAction() else unbindAimbotAction() end
    end
})

Tabs.Combat:AddSlider("AimbotIntensitySlider", {
    Title = "Aimbot Intensity", Description = "Snap radius",
    Default = 150, Min = 20, Max = 600, Rounding = 0,
    Callback = function(v) aimIntensity = v end
})

local triggerbotActive, triggerLoop, triggerDebounce = false, nil, false

Tabs.Combat:AddToggle("TriggerbotToggle", {
    Title = "Triggerbot", Default = false,
    Callback = function(state)
        triggerbotActive = state
        if state then
            if triggerLoop then return end
            triggerLoop = RunService.RenderStepped:Connect(function()
                if not triggerbotActive or triggerDebounce then return end
                local t = targetUnderCursor()
                if not t then
                    local head = findNearestToCursor()
                    if head then
                        local model = head:FindFirstAncestorOfClass("Model")
                        if model and model.Parent == characters then
                            local h = model:FindFirstChildOfClass("Humanoid")
                            if h and h.Health > 0 then t = model end
                        end
                    end
                end
                if t then
                    triggerDebounce = true
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                    task.wait(0.15)
                    triggerDebounce = false
                end
            end)
        else
            if triggerLoop then triggerLoop:Disconnect(); triggerLoop = nil end
        end
    end
})


Tabs.Kids:CreateButton{
    Title = "Bring Kid",
    Callback = function()
        if not sack then refreshSack() end
        if not sack then return end
        local t = getClosestToOrigin(kidName, { itemsFolder, characters })
        if not t then return end
        lastPos = humanoidRootPart.CFrame
        local ok = false
        if not isSackFull() then ok = storeItem(t) end
        humanoidRootPart.CFrame = lastPos
        task.wait(0.25)
        if ok then dropAllFromSack(1) end
    end
}

Tabs.Kids:CreateButton{
    Title = "Teleport to Kid",
    Callback = function()
        local t = getClosestToOrigin(kidName, { itemsFolder, characters })
        if not t then return end
        local p = t:FindFirstChildWhichIsA("BasePart")
        if p then humanoidRootPart.CFrame = p.CFrame end
    end
}


Tabs.Landmarks:CreateButton{
    Title = "Teleport to Landmark",
    Callback = function()
        local t = getClosestToOrigin(landmarkName, { landmarksFolder })
        if not t then return end
        local p = t:FindFirstChildWhichIsA("BasePart") or t:FindFirstChildWhichIsA("BasePart", true)
        if p then humanoidRootPart.CFrame = p.CFrame + Vector3.new(0, 5, 0) end
    end
}


local spectatingPlayer = nil
local spectateConn     = nil
local originalCamType, originalCamSubject = nil, nil
local savedSpectateMouseBehavior, savedSpectateMouseIcon = nil, nil
local spectateYaw, spectatePitch = 0, 0
local spectateGui      = nil

local function stopSpectate()
    if spectateConn then spectateConn:Disconnect(); spectateConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType    = originalCamType or Enum.CameraType.Custom
        cam.CameraSubject = originalCamSubject or (character and character:FindFirstChildOfClass("Humanoid"))
    end
    UserInputService.MouseBehavior    = savedSpectateMouseBehavior or Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = savedSpectateMouseIcon ~= false
    spectatingPlayer = nil
    spectateYaw, spectatePitch = 0, 0
    if spectateGui then spectateGui:Destroy(); spectateGui = nil end
end

local function showStopButton()
    if spectateGui then spectateGui:Destroy() end
    spectateGui = Instance.new("ScreenGui")
    spectateGui.Name = "LelHubSpectateStop"
    spectateGui.ResetOnSpawn = false
    spectateGui.IgnoreGuiInset = true
    spectateGui.Parent = player:WaitForChild("PlayerGui")

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.Position = UDim2.new(1, -60, 0, 16)
    btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = "X"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 20
    btn.AutoButtonColor = false
    btn.Parent = spectateGui

    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(240, 240, 240); stroke.Thickness = 1; stroke.Transparency = 0.6; stroke.Parent = btn

    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(220, 70, 70) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50) end)
    btn.MouseButton1Click:Connect(stopSpectate)
end

local function spectatePlayerByName(playerName)
    if not playerName or playerName == "" then return end
    local target = Players:FindFirstChild(playerName)
    if not target or target == player then return end
    stopSpectate()
    local cam = workspace.CurrentCamera
    originalCamType    = cam.CameraType
    originalCamSubject = cam.CameraSubject
    spectatingPlayer   = target
    spectateYaw, spectatePitch = 0, 0
    cam.CameraType     = Enum.CameraType.Scriptable


    savedSpectateMouseBehavior = UserInputService.MouseBehavior
    savedSpectateMouseIcon     = UserInputService.MouseIconEnabled
    UserInputService.MouseBehavior    = Enum.MouseBehavior.LockCurrentPosition
    UserInputService.MouseIconEnabled = false

    showStopButton()

    local focusHeight = 3
    local orbitDistance = 14

    spectateConn = RunService.RenderStepped:Connect(function()
        if not spectatingPlayer then return end
        local tChar = spectatingPlayer.Character
        local tHRP  = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end


        local delta = UserInputService:GetMouseDelta()
        if delta.Magnitude > 0 then
            spectateYaw   = spectateYaw   - delta.X * 0.006
            spectatePitch = math.clamp(spectatePitch - delta.Y * 0.006, -math.rad(80), math.rad(80))
        end

        local focus = tHRP.Position + Vector3.new(0, focusHeight, 0)
        local rot = CFrame.Angles(0, spectateYaw, 0) * CFrame.Angles(spectatePitch, 0, 0)
        local offsetCF = rot * CFrame.new(0, 0, orbitDistance)
        workspace.CurrentCamera.CFrame = CFrame.new(focus) * offsetCF
    end)
end

local function teleportToTeammate(playerName)
    if not playerName or playerName == "" then return end
    local target = Players:FindFirstChild(playerName)
    if not target or target == player then return end
    local tChar = target.Character
    local tHRP  = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    humanoidRootPart.CFrame = tHRP.CFrame * CFrame.new(0, 0, 4)
end

Tabs.Teammates:CreateButton{
    Title = "Teleport to Teammate",
    Callback = function() teleportToTeammate(teammateName) end
}

Tabs.Teammates:CreateButton{
    Title = "Spectate Teammate",
    Callback = function() spectatePlayerByName(teammateName) end
}

Tabs.Teammates:CreateButton{
    Title = "Stop Spectating",
    Callback = function() stopSpectate() end
}

addSpacer(Tabs.Teammates)

local teammateHighlights = {}
local teammateEspActive = false
local teammateEspConnections = {}

local function clearTeammateEsp()
    for _, hl in pairs(teammateHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    teammateHighlights = {}
end

local function addHighlightFor(p)
    if not p or p == player or teammateHighlights[p] then return end
    local char = p.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Name = "LelHubTeammateESP"
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(60, 255, 120)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    teammateHighlights[p] = hl
end

Tabs.Teammates:AddToggle("TeammateESP", {
    Title = "Teammate ESP",
    Default = false,
    Callback = function(state)
        teammateEspActive = state
        if state then
            for _, p in ipairs(Players:GetPlayers()) do addHighlightFor(p) end
            table.insert(teammateEspConnections, Players.PlayerAdded:Connect(function(p)
                task.wait(1)
                if teammateEspActive then addHighlightFor(p) end
            end))
            table.insert(teammateEspConnections, Players.PlayerRemoving:Connect(function(p)
                local hl = teammateHighlights[p]
                if hl and hl.Parent then hl:Destroy() end
                teammateHighlights[p] = nil
            end))
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then
                    table.insert(teammateEspConnections, p.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if teammateEspActive then addHighlightFor(p) end
                    end))
                    table.insert(teammateEspConnections, p.CharacterRemoving:Connect(function()
                        local hl = teammateHighlights[p]
                        if hl and hl.Parent then hl:Destroy() end
                        teammateHighlights[p] = nil
                    end))
                end
            end
            table.insert(teammateEspConnections, task.spawn(function()
                while teammateEspActive do
                    task.wait(0.5)
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and not teammateHighlights[p] then
                            addHighlightFor(p)
                        end
                    end
                end
            end))
        else
            clearTeammateEsp()
            for _, c in ipairs(teammateEspConnections) do
                if type(c) == "RBXScriptConnection" and c.Disconnect then
                    c:Disconnect()
                end
            end
            teammateEspConnections = {}
        end
    end
})


Tabs.Player:AddSlider("PlayerSpeedSlider", {
    Title = "Walk Speed", Description = "Player walk speed",
    Default = 16, Min = 16, Max = 500, Rounding = 0,
    Callback = function(v)
        playerSpeed = v
        if character then
            local h = character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = v end
        end
    end
})

Tabs.Player:AddSlider("PlayerJumpSlider", {
    Title = "Jump Power", Description = "Player jump power",
    Default = 50, Min = 50, Max = 500, Rounding = 0,
    Callback = function(v)
        playerJump = v
        if character then
            local h = character:FindFirstChildOfClass("Humanoid")
            if h then h.UseJumpPower = true; h.JumpPower = v end
        end
    end
})

addSpacer(Tabs.Player)

local flyActive, flyBV, flyBG, flyLoop = false, nil, nil, nil

local function startFlyLoop()
    if flyLoop then return end
    flyLoop = RunService.RenderStepped:Connect(function()
        if not flyActive then return end
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBV.P = 1000; flyBV.Parent = hrp
        end
        if not flyBG or not flyBG.Parent then
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBG.P = 1000; flyBG.D = 50; flyBG.Parent = hrp
        end
        local cam = workspace.CurrentCamera
        local d = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then d = d - Vector3.new(0,1,0) end
        if d.Magnitude > 0 then d = d.Unit end
        flyBV.Velocity = d * flySpeed
        flyBG.CFrame = cam.CFrame
    end)
end

Tabs.Player:AddToggle("FlyToggle", {
    Title = "Fly", Default = false,
    Callback = function(state)
        flyActive = state
        if state then startFlyLoop()
        else
            if flyLoop then flyLoop:Disconnect(); flyLoop = nil end
            if flyBV then flyBV:Destroy(); flyBV = nil end
            if flyBG then flyBG:Destroy(); flyBG = nil end
        end
    end
})

Tabs.Player:AddSlider("FlySpeedSlider", {
    Title = "Fly Speed", Description = "Player fly speed",
    Default = 100, Min = 10, Max = 500, Rounding = 0,
    Callback = function(v) flySpeed = v end
})

local freecamActive, freecamLoop, freecamCF = false, nil, nil
local savedCamType, savedCamSubj, savedMouse = nil, nil, nil

local function startFreecam()
    local cam = workspace.CurrentCamera
    savedCamType, savedCamSubj = cam.CameraType, cam.CameraSubject
    savedMouse = UserInputService.MouseBehavior
    freecamCF = cam.CFrame
    cam.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    if character then
        local h = character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 0; h.JumpPower = 0 end
    end
    if freecamLoop then return end
    freecamLoop = RunService.RenderStepped:Connect(function(dt)
        if not freecamActive then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local delta = UserInputService:GetMouseDelta()
        if delta.Magnitude > 0 then
            freecamCF = freecamCF * CFrame.Angles(0, -delta.X*0.003, 0) * CFrame.Angles(-delta.Y*0.003, 0, 0)
        end
        local d = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + freecamCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - freecamCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + freecamCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - freecamCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.new(0,1,0) end
        if d.Magnitude > 0 then d = d.Unit end
        freecamCF = freecamCF + d * freecamSpeed * dt
        camera.CFrame = freecamCF
    end)
end

local function stopFreecam()
    if freecamLoop then freecamLoop:Disconnect(); freecamLoop = nil end
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = savedCamType or Enum.CameraType.Custom
        if savedCamSubj then cam.CameraSubject = savedCamSubj
        elseif character then
            local h = character:FindFirstChildOfClass("Humanoid")
            if h then cam.CameraSubject = h end
        end
    end
    UserInputService.MouseBehavior = savedMouse or Enum.MouseBehavior.Default
    if character then
        local h = character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = playerSpeed; h.JumpPower = playerJump end
    end
end

Tabs.Player:AddToggle("FreecamToggle", {
    Title = "Freecam", Default = false,
    Callback = function(state)
        freecamActive = state
        if state then startFreecam() else stopFreecam() end
    end
})

Tabs.Player:AddSlider("FreecamSpeedSlider", {
    Title = "Freecam Speed", Description = "Camera movement speed",
    Default = 50, Min = 5, Max = 500, Rounding = 0,
    Callback = function(v) freecamSpeed = v end
})

local noclipActive, noclipLoop = false, nil

local function startNoclipLoop()
    if noclipLoop then return end
    noclipLoop = RunService.Stepped:Connect(function()
        if not noclipActive or not character then return end
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

Tabs.Player:AddToggle("NoclipToggle", {
    Title = "Noclip", Default = false,
    Callback = function(state)
        noclipActive = state
        if state then startNoclipLoop()
        else
            if noclipLoop then noclipLoop:Disconnect(); noclipLoop = nil end
            if character then
                for _, p in ipairs(character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end
    end
})

addSpacer(Tabs.Player)

local fullbrightActive, fullbrightLoop, originalLighting = false, nil, nil

local function applyFullbright()
    Lighting.Brightness = 3
    Lighting.ClockTime = 12
    Lighting.Ambient = Color3.fromRGB(200,200,200)
    Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
end

Tabs.Player:AddToggle("FullbrightToggle", {
    Title = "Fullbright", Default = false,
    Callback = function(state)
        fullbrightActive = state
        if state then
            originalLighting = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd }
            applyFullbright()
            if not fullbrightLoop then
                fullbrightLoop = RunService.Heartbeat:Connect(function()
                    if fullbrightActive then applyFullbright() end
                end)
            end
        else
            if fullbrightLoop then fullbrightLoop:Disconnect(); fullbrightLoop = nil end
            if originalLighting then
                Lighting.Brightness = originalLighting.Brightness
                Lighting.ClockTime = originalLighting.ClockTime
                Lighting.Ambient = originalLighting.Ambient
                Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
                Lighting.GlobalShadows = originalLighting.GlobalShadows
                Lighting.FogEnd = originalLighting.FogEnd
            end
        end
    end
})

Tabs.Player:CreateButton{
    Title = "Teleport to Campfire",
    Callback = function()
        if bringAllActive then bringAllActive = false; task.wait(0.2) end
        local map = workspace:FindFirstChild("Map")
        local camp = map and map:FindFirstChild("Campground")
        local fire = camp and camp:FindFirstChild("MainFire")
        if fire then
            local c = fire:FindFirstChild("Center")
            if c then humanoidRootPart.CFrame = c.CFrame * CFrame.new(0,13,0) end
        end
    end
}


task.spawn(function()
    local t = 0
    while not inventory and t < 30 do
        inventory = player:FindFirstChild("Inventory")
        if not inventory then task.wait(0.5); t = t + 0.5 end
    end
    if inventory then
        inventory.ChildAdded:Connect(function(c)
            if string.find(c.Name, "Sack") then sack = c end
        end)
        inventory.ChildRemoved:Connect(function(c)
            if sack and c == sack then refreshSack() end
        end)
    end
    refreshSack()

    local ft = 0
    while (not itemsFolder or not characters) and ft < 30 do
        itemsFolder = itemsFolder or workspace:FindFirstChild("Items")
        characters  = characters  or workspace:FindFirstChild("Characters")
        mapFolder   = mapFolder   or workspace:FindFirstChild("Map")
        landmarksFolder = landmarksFolder or (mapFolder and mapFolder:FindFirstChild("Landmarks"))
        if not itemsFolder or not characters then task.wait(0.5); ft = ft + 0.5 end
    end

    local d1, d2, d3, d4 = false, false, false, false
    local function updItems()
        if d1 or not itemsFolder then return end
        d1 = true
        task.delay(0.1, function()
            local seen, out = {}, {}
            for _, i in pairs(itemsFolder:GetChildren()) do
                if typeof(i.Name) == "string" and not seen[i.Name] then
                    seen[i.Name] = true; table.insert(out, i.Name)
                end
            end
            table.sort(out)
            items = out
            pcall(function() ItemsDropdown:SetValues(items) end)
            d1 = false
        end)
    end
    local function updKids()
        if d2 or not characters then return end
        d2 = true
        task.delay(0.1, function()
            local out = {}
            for _, k in pairs(characters:GetChildren()) do
                if string.find(k.Name, "Child") then table.insert(out, k.Name) end
            end
            table.sort(out)
            kids = out
            pcall(function() KidsDropdown:SetValues(kids) end)
            d2 = false
        end)
    end
    local function updLandmarks()
        if d3 or not landmarksFolder then return end
        d3 = true
        task.delay(0.1, function()
            local seen, out = {}, {}
            for _, o in ipairs(landmarksFolder:GetChildren()) do
                if typeof(o.Name) == "string" and not seen[o.Name] then
                    seen[o.Name] = true; table.insert(out, o.Name)
                end
            end
            table.sort(out)
            landmarks = out
            pcall(function() LandmarkDropdown:SetValues(landmarks) end)
            d3 = false
        end)
    end
    local lastTeammateSig = ""
    local function updTeammates()
        if d4 then return end
        d4 = true
        task.delay(0.1, function()
            local out = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then table.insert(out, p.Name) end
            end
            table.sort(out)
            local sig = table.concat(out, ",")
            if sig ~= lastTeammateSig then
                lastTeammateSig = sig
                teammates = out
                pcall(function() TeammateDropdown:SetValues(teammates) end)
            end
            d4 = false
        end)
    end
    updItems(); updKids(); updLandmarks(); updTeammates()

    if itemsFolder then itemsFolder.ChildAdded:Connect(updItems); itemsFolder.ChildRemoved:Connect(updItems) end
    if characters then characters.ChildAdded:Connect(updKids); characters.ChildRemoved:Connect(updKids) end
    if landmarksFolder then landmarksFolder.ChildAdded:Connect(updLandmarks); landmarksFolder.ChildRemoved:Connect(updLandmarks) end
    Players.PlayerAdded:Connect(function() task.wait(0.5); updTeammates() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.5); updTeammates() end)
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if character then
        local h = character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = playerSpeed; h.UseJumpPower = true; h.JumpPower = playerJump end
    end
end)

Window:SelectTab(1)
local sharedControls = installLelHubControls(Library, Window, {
    Name = "forest",
    BasicMovement = false,
    ShutdownLegacy = true,
})
lelEnvironment.LelHubforestCleanup = function()
    if not Library.Unloaded then Library:Destroy() end
end
