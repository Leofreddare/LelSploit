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
if lelEnvironment.LelHubislandsCleanup then
    pcall(lelEnvironment.LelHubislandsCleanup)
end

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = "LelHub Islands",
    SubTitle = "by LelSploit",
    TabWidth = 150,
    Size = UDim2.fromOffset(670, 460),
    Resize = true,
    MinSize = Vector2.new(480, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
}

local ShopTab = Window:CreateTab{ Title = "Shop Utils", Icon = "phosphor-storefront-bold" }
local MiscTab = Window:CreateTab{ Title = "Miscellaneous", Icon = "phosphor-squares-four-bold" }

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

local SELL_FILL     = Color3.fromRGB(0, 255, 130)
local SELL_OUTLINE  = Color3.fromRGB(255, 255, 255)
local ITEMS_FILL    = Color3.fromRGB(255, 120, 40)
local ITEMS_OUTLINE = Color3.fromRGB(255, 230, 200)
local RESTOCK_FILL    = Color3.fromRGB(255, 40, 40)
local RESTOCK_OUTLINE = Color3.fromRGB(255, 200, 200)
local BAL_FILL      = Color3.fromRGB(60, 160, 255)
local BAL_OUTLINE   = Color3.fromRGB(220, 240, 255)
local FINDER_FILL    = Color3.fromRGB(220, 120, 255)
local FINDER_OUTLINE = Color3.fromRGB(255, 220, 255)
local CANRESTOCK_FILL    = Color3.fromRGB(255, 230, 40)
local CANRESTOCK_OUTLINE = Color3.fromRGB(255, 255, 200)

local SCAN_INTERVAL = 0.5
local FINDER_DURATION = 10

local sellActive, itemsActive, restockActive, balanceActive = false, false, false, false
local canRestockActive = false
local restockMinAmount = 0
local includeSellInList = false

local sellNeedsCoinHL, hasItemsHL, needsRestockHL, buyHasBalanceHL, canRestockHL = {}, {}, {}, {}, {}
local finderHL = {}
local finderTimers = {}

local playerEspActive = false
local playerHighlights = {}
local playerConns = {}

local vendingEspItemActive = false
local vendingEspBalanceActive = false
local vendingBills = {}

local antiAfkConn = nil

local function isVendingMachine(name)
    return name == "vendingMachine" or name:match("^vendingMachine%d+$") ~= nil
end

local function readMode(vm)
    local inst = vm:FindFirstChild("Mode")
    if not inst or not inst:IsA("ValueBase") then return nil end
    local m = inst.Value
    if type(m) == "number" then return m end
    if type(m) == "string" then
        local l = m:lower()
        if l == "sell" then return 1 end
        if l == "buy" then return 0 end
    end
    return nil
end

local function readNum(inst)
    if not inst or not inst:IsA("ValueBase") then return nil end
    return tonumber(inst.Value)
end

local function getSellingTool(vm)
    local contents = vm:FindFirstChild("SellingContents")
    if not contents then return nil end
    for _, ch in ipairs(contents:GetChildren()) do
        if ch:IsA("Tool") then return ch end
    end
    return nil
end

local function toolKey(tool)
    if not tool then return nil end
    local dn = tool:FindFirstChild("DisplayName")
    if dn and dn:IsA("ValueBase") then
        local v = tostring(dn.Value)
        if v ~= "" then return v end
    end
    return tool.Name
end

local function getToolDisplayName(vm)
    local tool = getSellingTool(vm)
    if not tool then return nil end
    return toolKey(tool)
end

local function getAmountFromSellingContents(vm)
    local tool = getSellingTool(vm)
    if not tool then return nil end
    local amt = tool:FindFirstChild("Amount")
    if amt then return readNum(amt) end
    return nil
end

local function getBlockFolders()
    local out = {}
    local islands = workspace:FindFirstChild("Islands")
    if not islands then return out end
    for _, child in ipairs(islands:GetChildren()) do
        if child:IsA("Model") then
            local blocks = child:FindFirstChild("Blocks")
            if blocks then table.insert(out, blocks) end
        end
    end
    return out
end

local function getMesh(vm)
    local direct = vm:FindFirstChild("VendingMachine")
    if direct and direct:IsA("BasePart") then return direct end
    for _, d in ipairs(vm:GetDescendants()) do
        if d.Name == "VendingMachine" and d:IsA("BasePart") then return d end
    end
    return nil
end

local function formatAmount(n)
    n = tonumber(n) or 0
    if n < 1000 then return tostring(math.floor(n)) end
    local units = {
        {1e12, "T"},
        {1e9,  "B"},
        {1e6,  "M"},
        {1e3,  "k"},
    }
    for _, u in ipairs(units) do
        if n >= u[1] then
            local v = n / u[1]
            local s = string.format("%.1f", v)
            s = s:gsub("%.0$", "")
            return s .. u[2]
        end
    end
    return tostring(math.floor(n))
end

local function commafy(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local grouped = string.gsub(string.reverse(s), "(%d%d%d)", "%1,")
    grouped = string.gsub(string.reverse(grouped), "^,", "")
    return grouped
end

local function computeRestockableStock(folders)
    local stock = {}

    local function addBackpackTool(tool)
        if not tool:IsA("Tool") then return end
        local key = toolKey(tool)
        if key then stock[key] = (stock[key] or 0) + 1 end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do addBackpackTool(t) end
    end

    local char = player.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do addBackpackTool(t) end
    end

    for _, blocks in ipairs(folders) do
        for _, vm in ipairs(blocks:GetChildren()) do
            if isVendingMachine(vm.Name) and readMode(vm) == 1 then
                local tool = getSellingTool(vm)
                if tool then
                    local amt = getAmountFromSellingContents(vm) or 0
                    local contrib = amt - 1
                    if contrib < 0 then contrib = 0 end
                    local key = toolKey(tool)
                    if key then
                        stock[key] = (stock[key] or 0) + contrib
                    end
                end
            end
        end
    end

    return stock
end

local function eval(vm)
    if not vm or not vm.Parent then return false, false, false, false end
    local mode = readMode(vm)
    if mode == nil then return false, false, false, false end

    local coin  = readNum(vm:FindFirstChild("CoinBalance")) or 0
    local price = readNum(vm:FindFirstChild("TransactionPrice")) or 0
    local amt   = getAmountFromSellingContents(vm)

    local sellNeedsCoin = (mode == 1) and (coin < price)
    local sellHasItems  = (mode == 1) and (amt ~= nil) and (amt > 1)

    local buyNeedsRestock = false
    if mode == 0 then
        if restockMinAmount == 0 then
            buyNeedsRestock = (getSellingTool(vm) == nil)
        else
            local a = amt or 0
            buyNeedsRestock = (a < restockMinAmount)
        end
    end

    local buyHasBalance = (mode == 0) and (coin > 0)

    return sellNeedsCoin, sellHasItems, buyNeedsRestock, buyHasBalance
end

local function evalCanRestock(vm, stockMap)
    if not vm or not vm.Parent then return false end
    if readMode(vm) ~= 0 then return false end

    local tool = getSellingTool(vm)
    if not tool then return false end
    local key = toolKey(tool)
    if not key then return false end

    local pool = stockMap[key] or 0
    if pool <= 0 then return false end

    local own = getAmountFromSellingContents(vm)
    if own == nil then own = 0 end

    if vm.Name == "vendingMachine" then
        return own < 300
    else
        return own < 1000
    end
end

local function makeHL(vm, store, name, fill, outline)
    local mesh = getMesh(vm)
    if not mesh then return end

    local ex = store[vm]
    if ex and ex.Parent and ex.Adornee == mesh then
        ex.FillColor = fill
        ex.OutlineColor = outline
        return
    end
    if ex and ex.Parent then ex:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name = name
    hl.Adornee = mesh
    hl.FillColor = fill
    hl.OutlineColor = outline
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = mesh
    store[vm] = hl
end

local function dropHL(vm, store)
    local hl = store[vm]
    if hl and hl.Parent then hl:Destroy() end
    store[vm] = nil
end

local function sweep(store, seen)
    for vm in pairs(store) do
        if not seen[vm] or not vm.Parent then dropHL(vm, store) end
    end
end

local function clearStore(store)
    for vm, hl in pairs(store) do
        if hl and hl.Parent then hl:Destroy() end
        store[vm] = nil
    end
end

local function scanOnce()
    local folders = getBlockFolders()
    if #folders == 0 then return end

    local stockMap = nil
    if canRestockActive then stockMap = computeRestockableStock(folders) end

    local sNC, sHI, sRS, sHB, sCR = {}, {}, {}, {}, {}

    for _, blocks in ipairs(folders) do
        for _, vm in ipairs(blocks:GetChildren()) do
            if isVendingMachine(vm.Name) then
                local nc, hi, rs, hb = eval(vm)
                if sellActive and nc then
                    sNC[vm] = true
                    makeHL(vm, sellNeedsCoinHL, "LelHubSellNeedsCoin", SELL_FILL, SELL_OUTLINE)
                end
                if itemsActive and hi then
                    sHI[vm] = true
                    makeHL(vm, hasItemsHL, "LelHubHasItems", ITEMS_FILL, ITEMS_OUTLINE)
                end
                if restockActive and rs then
                    sRS[vm] = true
                    makeHL(vm, needsRestockHL, "LelHubNeedsRestock", RESTOCK_FILL, RESTOCK_OUTLINE)
                end
                if balanceActive and hb then
                    sHB[vm] = true
                    makeHL(vm, buyHasBalanceHL, "LelHubBuyHasBalance", BAL_FILL, BAL_OUTLINE)
                end
                if canRestockActive and evalCanRestock(vm, stockMap) then
                    sCR[vm] = true
                    makeHL(vm, canRestockHL, "LelHubCanRestock", CANRESTOCK_FILL, CANRESTOCK_OUTLINE)
                end
            end
        end
    end

    if sellActive then sweep(sellNeedsCoinHL, sNC) else clearStore(sellNeedsCoinHL) end
    if itemsActive then sweep(hasItemsHL, sHI) else clearStore(hasItemsHL) end
    if restockActive then sweep(needsRestockHL, sRS) else clearStore(needsRestockHL) end
    if balanceActive then sweep(buyHasBalanceHL, sHB) else clearStore(buyHasBalanceHL) end
    if canRestockActive then sweep(canRestockHL, sCR) else clearStore(canRestockHL) end
end

local function startScan()
    task.spawn(function()
        while not Library.Unloaded do
            scanOnce()
            task.wait(SCAN_INTERVAL)
        end
    end)
end

local function bindDescendant()
    task.spawn(function()
        local islands = workspace:WaitForChild("Islands", 30)
        if not islands then return end
        islands.DescendantAdded:Connect(function(inst)
            if not isVendingMachine(inst.Name) then return end
            task.defer(function()
                if not inst.Parent then return end
                local nc, hi, rs, hb = eval(inst)
                if sellActive and nc then makeHL(inst, sellNeedsCoinHL, "LelHubSellNeedsCoin", SELL_FILL, SELL_OUTLINE) end
                if itemsActive and hi then makeHL(inst, hasItemsHL, "LelHubHasItems", ITEMS_FILL, ITEMS_OUTLINE) end
                if restockActive and rs then makeHL(inst, needsRestockHL, "LelHubNeedsRestock", RESTOCK_FILL, RESTOCK_OUTLINE) end
                if balanceActive and hb then makeHL(inst, buyHasBalanceHL, "LelHubBuyHasBalance", BAL_FILL, BAL_OUTLINE) end
            end)
        end)
    end)
end


local function dumpPrices()
    local folders = getBlockFolders()
    if #folders == 0 then
        return 0
    end

    local items, order, count = {}, {}, 0

    for _, blocks in ipairs(folders) do
        for _, vm in ipairs(blocks:GetChildren()) do
            if isVendingMachine(vm.Name) then
                local price = readNum(vm:FindFirstChild("TransactionPrice"))
                local mode  = readMode(vm)
                local tool  = getSellingTool(vm)
                if price and price > 0 and mode ~= nil and tool then
                    local label = getToolDisplayName(vm)
                    if label then
                        local slot = items[label]
                        if not slot then
                            slot = {}
                            items[label] = slot
                            count = count + 1
                            order[count] = label
                        end
                        if mode == 1 then
                            slot.sell = price
                        else
                            slot.buy = price
                        end
                    end
                end
            end
        end
    end

    local lines = { "**LelSploit HUB**", "" }
    for i = 1, count do
        local name = order[i]
        local d = items[name]
        table.insert(lines, "**" .. name .. "**")
        if d.buy then
            table.insert(lines, "- Buy Price: $" .. commafy(d.buy))
        end
        if d.sell then
            table.insert(lines, "- Sell Price: $" .. commafy(d.sell))
        end
    end

    local output = table.concat(lines, "\n")

    if setclipboard then
        setclipboard(output)
    elseif toclipboard then
        toclipboard(output)
    else
        return 0
    end

    return count
end


local finderItems = {}
local finderSelection = ""
local lastFinderSignature = ""

local function collectItemList()
    local seen, out = {}, {}
    local folders = getBlockFolders()
    for _, blocks in ipairs(folders) do
        for _, vm in ipairs(blocks:GetChildren()) do
            if isVendingMachine(vm.Name) then
                local mode = readMode(vm)
                if mode ~= nil then
                    if includeSellInList or mode == 0 then
                        local label = getToolDisplayName(vm)
                        if label and not seen[label] then
                            seen[label] = true
                            table.insert(out, label)
                        end
                    end
                end
            end
        end
    end
    table.sort(out)
    return out
end

local ItemDropdown
ItemDropdown = ShopTab:AddDropdown("FinderItemDropdown", {
    Title = "Item Finder",
    Values = {},
    Multi = false,
    Default = "",
    Callback = function(v) finderSelection = v end
})

local function refreshItemList(force)
    local newList = collectItemList()
    local sig = table.concat(newList, "\1")
    if not force and sig == lastFinderSignature then return end
    lastFinderSignature = sig
    finderItems = newList
    pcall(function() ItemDropdown:SetValues(finderItems) end)
end

local function dropFinder(vm)
    local hl = finderHL[vm]
    if hl and hl.Parent then hl:Destroy() end
    finderHL[vm] = nil
    if finderTimers[vm] then
        task.cancel(finderTimers[vm])
        finderTimers[vm] = nil
    end
end

local function highlightMatches(itemName)
    for vm in pairs(finderHL) do dropFinder(vm) end

    if not itemName or itemName == "" then return end

    local folders = getBlockFolders()
    for _, blocks in ipairs(folders) do
        for _, vm in ipairs(blocks:GetChildren()) do
            if isVendingMachine(vm.Name) then
                local mode = readMode(vm)
                if mode ~= nil then
                    local eligible = includeSellInList or mode == 0
                    if eligible then
                        local label = getToolDisplayName(vm)
                        if label and label == itemName then
                            makeHL(vm, finderHL, "LelHubItemFinder", FINDER_FILL, FINDER_OUTLINE)
                            finderTimers[vm] = task.delay(FINDER_DURATION, function()
                                dropFinder(vm)
                            end)
                        end
                    end
                end
            end
        end
    end
end

ShopTab:AddToggle("IncludeSellToggle", {
    Title = "Include Sell Vending Machines",
    Default = false,
    Callback = function(state)
        includeSellInList = state
        refreshItemList(true)
    end
})

ShopTab:AddButton({
    Title = "Highlight Item",
    Callback = function()
        highlightMatches(finderSelection)
    end
})

ShopTab:AddButton({
    Title = "Price Dumper",
    Description = "Scrapes every vending machine's buy and sell prices, then copies a formatted list to your clipboard.",
    Callback = function()
        local n = dumpPrices()
    end
})

task.spawn(function()
    task.wait(2)
    refreshItemList(true)
    while not Library.Unloaded do
        task.wait(2)
        refreshItemList(false)
    end
end)


ShopTab:AddSection(" ")
ShopTab:AddSection("ESP")

ShopTab:AddToggle("SellNeedsCoinToggle", {
    Title = "Sell — Needs Coin",
    Default = false,
    Callback = function(state)
        sellActive = state
        if not state then clearStore(sellNeedsCoinHL) end
    end
})

ShopTab:AddToggle("SellHasItemsToggle", {
    Title = "Sell — Has Items",
    Default = false,
    Callback = function(state)
        itemsActive = state
        if not state then clearStore(hasItemsHL) end
    end
})

ShopTab:AddToggle("BuyNeedsRestockToggle", {
    Title = "Buy — Needs Restock",
    Default = false,
    Callback = function(state)
        restockActive = state
        if not state then clearStore(needsRestockHL) end
    end
})

ShopTab:AddSlider("RestockMinAmountSlider", {
    Title = "Restock Minimum Amount",
    Default = 0, Min = 0, Max = 999, Rounding = 0,
    Callback = function(v) restockMinAmount = v end
})

ShopTab:AddToggle("BuyHasBalanceToggle", {
    Title = "Buy — Has Balance",
    Default = false,
    Callback = function(state)
        balanceActive = state
        if not state then clearStore(buyHasBalanceHL) end
    end
})

ShopTab:AddToggle("CanRestockToggle", {
    Title = "Can Restock",
    Default = false,
    Callback = function(state)
        canRestockActive = state
        if not state then clearStore(canRestockHL) end
    end
})


local function enableAntiAfk()
    if antiAfkConn then return end
    antiAfkConn = player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

local function disableAntiAfk()
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
end

MiscTab:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "Simulates a right-click when Roblox detects inactivity so you never get kicked.",
    Default = false,
    Callback = function(state)
        if state then enableAntiAfk() else disableAntiAfk() end
    end
})


local function clearPlayerHL(p)
    local hl = playerHighlights[p]
    if hl and hl.Parent then hl:Destroy() end
    playerHighlights[p] = nil
end

local function addPlayerHL(p)
    if not p or p == player then return end
    local char = p.Character
    if not char then return end
    if playerHighlights[p] and playerHighlights[p].Parent then return end

    local hl = Instance.new("Highlight")
    hl.Name = "LelHubPlayerESP"
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(255, 90, 90)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    playerHighlights[p] = hl
end

local function bindPlayerConns()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            addPlayerHL(p)
            table.insert(playerConns, p.CharacterAdded:Connect(function()
                task.wait(0.3)
                if playerEspActive then addPlayerHL(p) end
            end))
            table.insert(playerConns, p.CharacterRemoving:Connect(function()
                clearPlayerHL(p)
            end))
        end
    end
    table.insert(playerConns, Players.PlayerAdded:Connect(function(p)
        task.wait(0.5)
        if playerEspActive then
            addPlayerHL(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.3)
                if playerEspActive then addPlayerHL(p) end
            end)
        end
    end))
    table.insert(playerConns, Players.PlayerRemoving:Connect(function(p)
        clearPlayerHL(p)
    end))
end

local function unbindPlayerConns()
    for _, c in ipairs(playerConns) do
        if c and c.Disconnect then c:Disconnect() end
    end
    playerConns = {}
end

MiscTab:AddToggle("PlayerEspToggle", {
    Title = "Player ESP",
    Default = false,
    Callback = function(state)
        playerEspActive = state
        if state then
            for _, p in ipairs(Players:GetPlayers()) do addPlayerHL(p) end
            bindPlayerConns()
            task.spawn(function()
                while playerEspActive do
                    task.wait(1)
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and (not playerHighlights[p] or not playerHighlights[p].Parent) then
                            addPlayerHL(p)
                        end
                    end
                end
            end)
        else
            unbindPlayerConns()
            for p in pairs(playerHighlights) do clearPlayerHL(p) end
        end
    end
})


local function ensureVendingBill(vm)
    local mesh = getMesh(vm)
    if not mesh then return nil end

    local existing = vendingBills[vm]
    if existing and existing.Parent then return existing end

    local bb = Instance.new("BillboardGui")
    bb.Name = "LelHubVendingESP"
    bb.Adornee = mesh
    bb.Size = UDim2.new(0, 160, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 500

    local itemLbl = Instance.new("TextLabel")
    itemLbl.Name = "ItemLabel"
    itemLbl.BackgroundTransparency = 1
    itemLbl.Font = Enum.Font.GothamBold
    itemLbl.TextScaled = true
    itemLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemLbl.TextStrokeTransparency = 0.2
    itemLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    itemLbl.Text = ""
    itemLbl.Visible = false
    itemLbl.Parent = bb

    local balLbl = Instance.new("TextLabel")
    balLbl.Name = "BalanceLabel"
    balLbl.BackgroundTransparency = 1
    balLbl.Font = Enum.Font.GothamBold
    balLbl.TextScaled = true
    balLbl.TextColor3 = Color3.fromRGB(255, 220, 90)
    balLbl.TextStrokeTransparency = 0.2
    balLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    balLbl.Text = ""
    balLbl.Visible = false
    balLbl.Parent = bb

    bb.Parent = mesh
    vendingBills[vm] = bb
    return bb
end

local function dropVendingBill(vm)
    local bb = vendingBills[vm]
    if bb and bb.Parent then bb:Destroy() end
    vendingBills[vm] = nil
end

local function clearVendingBills()
    for vm in pairs(vendingBills) do dropVendingBill(vm) end
end

local function updateVendingBill(vm)
    local showItem = vendingEspItemActive
    local showBal  = vendingEspBalanceActive

    if not showItem and not showBal then
        dropVendingBill(vm)
        return
    end

    local bb = ensureVendingBill(vm)
    if not bb then return end

    local itemLbl = bb:FindFirstChild("ItemLabel")
    local balLbl  = bb:FindFirstChild("BalanceLabel")
    if not itemLbl or not balLbl then return end

    if showItem then
        local dn = getToolDisplayName(vm) or "(empty)"
        itemLbl.Text = dn
        itemLbl.Visible = true
    else
        itemLbl.Text = ""
        itemLbl.Visible = false
    end

    if showBal then
        local coin = readNum(vm:FindFirstChild("CoinBalance")) or 0
        balLbl.Text = "$" .. formatAmount(coin)
        balLbl.Visible = true
    else
        balLbl.Text = ""
        balLbl.Visible = false
    end

    if showItem and showBal then
        bb.Size = UDim2.new(0, 160, 0, 38)
        itemLbl.Size = UDim2.new(1, 0, 0.5, 0)
        itemLbl.Position = UDim2.new(0, 0, 0, 0)
        balLbl.Size = UDim2.new(1, 0, 0.5, 0)
        balLbl.Position = UDim2.new(0, 0, 0.5, 0)
    elseif showItem then
        bb.Size = UDim2.new(0, 160, 0, 22)
        itemLbl.Size = UDim2.new(1, 0, 1, 0)
        itemLbl.Position = UDim2.new(0, 0, 0, 0)
    else
        bb.Size = UDim2.new(0, 160, 0, 22)
        balLbl.Size = UDim2.new(1, 0, 1, 0)
        balLbl.Position = UDim2.new(0, 0, 0, 0)
    end
end

local function runVendingEspLoop()
    task.spawn(function()
        while vendingEspItemActive or vendingEspBalanceActive do
            local folders = getBlockFolders()
            local seen = {}
            for _, blocks in ipairs(folders) do
                for _, vm in ipairs(blocks:GetChildren()) do
                    if isVendingMachine(vm.Name) then
                        seen[vm] = true
                        updateVendingBill(vm)
                    end
                end
            end
            for vm in pairs(vendingBills) do
                if not seen[vm] or not vm.Parent then dropVendingBill(vm) end
            end
            task.wait(0.5)
        end
    end)
end

MiscTab:AddToggle("VendingItemEspToggle", {
    Title = "Vending Machine Item ESP",
    Default = false,
    Callback = function(state)
        vendingEspItemActive = state
        if state then runVendingEspLoop() else
            for vm in pairs(vendingBills) do
                if not vendingEspBalanceActive then dropVendingBill(vm) end
            end
        end
    end
})

MiscTab:AddToggle("VendingBalanceEspToggle", {
    Title = "Vending Machine Balance ESP",
    Default = false,
    Callback = function(state)
        vendingEspBalanceActive = state
        if state then runVendingEspLoop() else
            for vm in pairs(vendingBills) do
                if not vendingEspItemActive then dropVendingBill(vm) end
            end
        end
    end
})

MiscTab:AddSlider("VendingEspRangeSlider", {
    Title = "Vending ESP Max Distance",
    Default = 500, Min = 50, Max = 2000, Rounding = 0,
    Callback = function(v)
        for _, bb in pairs(vendingBills) do
            if bb and bb.Parent then bb.MaxDistance = v end
        end
    end
})

Window:SelectTab(1)

startScan()
bindDescendant()
local sharedControls = installLelHubControls(Library, Window, {
    Name = "islands",
    BasicMovement = true,
    ShutdownLegacy = true,
})
lelEnvironment.LelHubislandsCleanup = function()
    if not Library.Unloaded then Library:Destroy() end
end
