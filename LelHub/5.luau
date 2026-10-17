local function lelHubTitle(value)
    local title = tostring(value or "")
    title = title:gsub("<[^>]*>", ""):gsub("_", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local names = {
        ["Walk speed"] = "WalkSpeed", ["Walk Speed"] = "WalkSpeed", ["WalkSpeed"] = "WalkSpeed",
        ["Jump power"] = "JumpPower", ["Hip height"] = "HipHeight", ["NoClip"] = "Noclip",
        ["Fly"] = "Flight", ["Fly Mode"] = "Flight", ["Player flight"] = "Flight",
        ["Fly Speed"] = "Flight Speed", ["Fly speed"] = "Flight Speed",
        ["Infinite jump"] = "Infinite Jump", ["Auto walk"] = "Auto Walk", ["Prevent sitting"] = "Anti Sit",
        ["Hold Shift to sprint"] = "Sprint", ["Sprint speed"] = "Sprint Speed", ["Spin speed"] = "Spin Speed",
        ["Field of view"] = "Field of View", ["Fullbright Intensity"] = "Brightness",
        ["Player outlines"] = "Player ESP", ["Entity Highlight"] = "Entity ESP",
        ["Gold Highlight"] = "Gold ESP", ["Item Highlight"] = "Item ESP", ["ToolShed ESP"] = "Toolshed ESP",
        ["Rainbow ESP"] = "Rainbow ESP", ["Enable Text"] = "ESP Text", ["Text Size"] = "Text Size",
        ["Text Offset Y"] = "Text Offset", ["Max ESP Distance"] = "ESP Distance",
        ["Anti CamShake"] = "No Camera Shake", ["Aura"] = "Kill Aura", ["Aura mode"] = "Aura Mode",
        ["Aura radius"] = "Aura Radius", ["Speed"] = "Speed Override", ["Collect speed"] = "Collect Speed",
        ["Auto guitar"] = "Auto Guitar", ["Farm wins"] = "Auto Wins", ["Fast parry"] = "Auto Parry",
        ["Destroy UI"] = "Unload LelHub", ["Unload"] = "Unload LelHub", ["Ball ESP (Highlight)"] = "Ball ESP",
        ["Master Sell Loop"] = "Auto Sell", ["Auto Spam Spins"] = "Auto Spin",
        ["Remove All Knives"] = "Remove Plot Knives", ["Include Inventory in Loop"] = "Sell Inventory",
        ["Auto Collect GradeTokens"] = "Auto Grade Tokens", ["Auto Collect Cash"] = "Auto Cash",
        ["Auto Open Ready Packs"] = "Auto Open Packs", ["Hide accessories locally"] = "Hide Accessories",
        ["Restore movement"] = "Restore Movement", ["Camera zoom distance"] = "Zoom Distance",
        ["Restore camera zoom"] = "Reset Zoom", ["Return camera to character"] = "Reset Camera",
        ["Highlight murderer"] = "Murderer ESP", ["Highlight sheriff / gun holder"] = "Sheriff / Hero ESP",
        ["Highlight innocents"] = "Innocent ESP", ["Show player names"] = "Names",
        ["Show role labels"] = "Roles", ["Show distance"] = "Distance", ["Include your character"] = "Self ESP",
        ["Highlight other players"] = "Player ESP", ["Names and distance"] = "Names / Distance",
        ["Use team colors"] = "Team Colors", ["Vehicle fly"] = "Vehicle Flight",
        ["Vehicle fly speed"] = "Flight Speed", ["Toggle fly key"] = "Flight Key",
        ["Highlight transparency"] = "Fill Transparency", ["Refresh highlights"] = "Refresh ESP",
    }
    return names[title] or title
end

local function installLelHubSpacing(window, connect)
    local holder = window.ContainerHolder
    if typeof(holder) ~= "Instance" then return end
    local seen = {}
    local function style(object)
        if seen[object] or not object:IsA("UIListLayout") then return end
        local container = object.Parent
        if not container then return end
        local isTab = container:IsA("ScrollingFrame") and container.Parent == holder
        local sectionRoot = container.Parent
        local isSection = sectionRoot and sectionRoot.Parent and sectionRoot.Parent:IsA("ScrollingFrame") and sectionRoot.Parent.Parent == holder and container.Position.Y.Offset == 24
        if not isTab and not isSection then return end
        seen[object] = true
        object.Padding = UDim.new(0, 10)
        if isTab then
            local padding = container:FindFirstChildOfClass("UIPadding")
            if padding then
                padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 4), UDim.new(0, 14)
                padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
            end
            local function resizeCanvas()
                container.CanvasSize = UDim2.fromOffset(0, object.AbsoluteContentSize.Y + 16)
            end
            connect(object:GetPropertyChangedSignal("AbsoluteContentSize"), resizeCanvas)
            resizeCanvas()
        end
    end
    for _, object in ipairs(holder:GetDescendants()) do style(object) end
    connect(holder.DescendantAdded, function(object)
        if object:IsA("UIListLayout") then task.defer(function() if object.Parent then style(object) end end) end
    end)
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
    local accessoryConnection
    local accessoryCharacter
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

    installLelHubSpacing(window, connect)

    local function notify(message)
        if not destroyed then
            library:Notify({ Title = lelHubTitle("LelHub"), Content = message, Duration = 3 })
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
        return register(parent, "Toggle", id, { Title = lelHubTitle(title), Default = false }, callback)
    end

    local function slider(parent, id, title, default, minimum, maximum, callback, rounding)
        return register(parent, "Slider", id, { Title = lelHubTitle(title), Default = default, Min = minimum, Max = maximum, Rounding = rounding or 0 }, function(value)
            local number = tonumber(value)

            if number and number == number and math.abs(number) ~= math.huge then
                callback(math.clamp(number, minimum, maximum))
            end
        end)
    end

    local function button(parent, title, callback)
        return ui(parent, "Button", { Title = lelHubTitle(title), Callback = function()
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
        if accessoryConnection then accessoryConnection:Disconnect() accessoryConnection = nil end
        accessoryCharacter = nil
        for object, properties in pairs(accessoryParts) do
            if object.Parent then
                for property, value in pairs(properties) do object[property] = value end
            end
        end
        accessoryParts = {}
    end

    local function hideAccessoryObject(object)
        local accessory = object:FindFirstAncestorWhichIsA("Accoutrement") or object:FindFirstAncestorWhichIsA("Accessory")
        if not accessory or not accessoryCharacter or not accessory:IsDescendantOf(accessoryCharacter) then return end
        local properties
        if object:IsA("BasePart") then
            properties = { Transparency = 1, LocalTransparencyModifier = 1, CastShadow = false }
        elseif object:IsA("Decal") or object:IsA("Texture") then
            properties = { Transparency = 1 }
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") or object:IsA("WrapLayer") then
            properties = { Enabled = false }
        end
        if not properties then return end
        local saved = accessoryParts[object]
        if not saved then saved = {} accessoryParts[object] = saved end
        for property, value in pairs(properties) do
            if saved[property] == nil then saved[property] = object[property] end
            object[property] = value
        end
    end

    local function hideAccessories(character)
        if not state.HideAccessories or not character then return end
        if accessoryCharacter ~= character then
            restoreAccessories()
            accessoryCharacter = character
            accessoryConnection = character.DescendantAdded:Connect(function(object)
                if not state.HideAccessories or destroyed then return end
                hideAccessoryObject(object)
                for _, descendant in ipairs(object:GetDescendants()) do hideAccessoryObject(descendant) end
            end)
        end
        for _, object in ipairs(character:GetDescendants()) do hideAccessoryObject(object) end
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
        if configuration.ResetMovement then configuration.ResetMovement() end
        local _, humanoid, root = parts()
        local saved = humanoid and originals[humanoid]
        local values = {
            WalkSpeed = saved and saved.WalkSpeed or (humanoid == sprintHumanoid and sprintOriginal) or humanoid and humanoid.WalkSpeed or 16,
            JumpPower = saved and saved.JumpPower or humanoid and humanoid.JumpPower or 50,
            HipHeight = saved and saved.HipHeight or humanoid and humanoid.HipHeight or 2,
        }
        basicValues = {}
        for _, id in ipairs({ "Fly", "Noclip", "InfiniteJump", "Sprint", "AutoWalk", "NoSit", "Spin" }) do
            if controls[id] then controls[id]:SetValue(false) end
        end
        basicFlags.Fly, basicFlags.Noclip, basicFlags.InfiniteJump = false, false, false
        state.Sprint, state.AutoWalk, state.NoSit, state.Spin = false, false, false, false
        releaseSprint()
        releaseSpin()
        stopBasicFlight()
        restoreBasicCollisions()
        if humanoid then humanoid:Move(Vector3.zero, false) end
        if root then root.AssemblyLinearVelocity = Vector3.zero root.AssemblyAngularVelocity = Vector3.zero end
        for target, properties in pairs(originals) do
            if target.Parent then
                for property, value in pairs(properties) do target[property] = value end
            end
        end
        originals = setmetatable({}, { __mode = "k" })
        local wasLoading = loading
        loading = true
        for id, value in pairs(values) do if controls[id] then controls[id]:SetValue(value) end end
        loading = wasLoading
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
        local flight = ui(utilityTab, "Section", "Flight")
        toggle(flight, "Fly", "Flight", function(value)
            basicFlags.Fly = value

            if not value then
                stopBasicFlight()
            end
        end)
        slider(flight, "FlySpeed", "Fly speed", 100, 1, 500, function(value)
            basicFlags.FlySpeed = value
        end)

    end

    movement = ui(utilityTab, "Section", "Movement Options")
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
    button(movement, "Restore movement", restoreBasicMovement)

    local characterSection = ui(utilityTab, "Section", "Character")
    toggle(characterSection, "HideAccessories", "Hide accessories locally", function(value)
        state.HideAccessories = value

        if value then hideAccessories(player.Character) else restoreAccessories() end
    end)
    local cameraSection = ui(utilityTab, "Section", "Camera")
    if configuration.BasicMovement then
        slider(cameraSection, "FOV", "Field of view", 70, 30, 120, function(value)
            local camera = workspace.CurrentCamera

            if camera then
                if not originalCamera then
                    originalCamera = camera
                    originalFov = camera.FieldOfView
                end

                camera.FieldOfView = value
            end
        end)
    end
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
    register(places, "Input", "WaypointName", { Title = lelHubTitle("Position name"), Default = "Home", Finished = true }, function(value)
        waypointName = tostring(value):sub(1, 40)
    end)
    local waypointDropdown = register(places, "Dropdown", "Waypoint", { Title = lelHubTitle("Saved position"), Values = {}, Multi = false }, function(value)
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
    register(places, "Input", "Coordinates", { Title = lelHubTitle("Coordinates"), Default = "", Placeholder = "X, Y, Z", Finished = true }, function(value)
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
    local esp = { Names = true, Health = true, Distance = false, TeamCheck = false, TeamColors = false, Range = 3000, Fill = 1 }
    local function clearESP(target)
        local entry = outlines[target]
        if entry then entry.Highlight:Destroy() entry.Billboard:Destroy() outlines[target] = nil end
    end
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
        local playersTab = ui(window, "Tab", { Title = lelHubTitle("Players"), Icon = "users" })
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
        playerDropdown = register(playersTab, "Dropdown", "TargetPlayer", { Title = lelHubTitle("Player"), Values = names, Default = "Select a player", Multi = false }, function(value)
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
        local espSection = ui(playersTab, "Section", "ESP")
        toggle(espSection, "PlayerOutlines", "Player ESP", function(value)
            outlinesEnabled = value
            if not value then for target in pairs(outlines) do clearESP(target) end end
        end)
        for _, item in ipairs({ { "Names", "Names", true }, { "Health", "Health", true }, { "Distance", "Distance", false }, { "TeamCheck", "Team Check", false }, { "TeamColors", "Team Colors", false } }) do
            local property = item[1]
            register(espSection, "Toggle", "ESP" .. property, { Title = item[2], Default = item[3] }, function(value) esp[property] = value end)
        end
        slider(espSection, "ESPRange", "Max Distance", 3000, 100, 10000, function(value) esp.Range = value end)
        slider(espSection, "ESPFill", "Fill Transparency", 1, 0, 1, function(value) esp.Fill = value end, 2)
        connect(players.PlayerAdded, function() refreshPlayers() end)
        connect(players.PlayerRemoving, function(target)
            refreshPlayers(target)
            if selectedPlayer == target then restoreSpectate() selectedPlayer = nil end
            clearESP(target)
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
        local _, _, myRoot = parts()
        for _, target in ipairs(players:GetPlayers()) do
            if target ~= player then
                local character = target.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local distance = root and myRoot and (root.Position - myRoot.Position).Magnitude or math.huge
                local teammate = not player.Neutral and not target.Neutral and player.Team ~= nil and player.Team == target.Team
                local visible = outlinesEnabled and root and humanoid and humanoid.Health > 0 and distance <= esp.Range and not (esp.TeamCheck and teammate)
                local entry = outlines[target]
                if entry and (not visible or entry.Character ~= character) then clearESP(target) entry = nil end
                if visible then
                    if not entry then
                        local highlight = Instance.new("Highlight")
                        highlight.Name, highlight.Adornee, highlight.Parent = "LelHubESP", character, character
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        local billboard = Instance.new("BillboardGui")
                        billboard.Name, billboard.Adornee, billboard.Parent = "LelHubESPLabel", root, root
                        billboard.Size, billboard.StudsOffset, billboard.AlwaysOnTop = UDim2.fromOffset(220, 60), Vector3.new(0, 3.5, 0), true
                        local label = Instance.new("TextLabel")
                        label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
                        label.Font, label.TextSize, label.TextStrokeTransparency = Enum.Font.GothamMedium, 14, 0.4
                        label.Parent = billboard
                        entry = { Highlight = highlight, Billboard = billboard, Text = label, Character = character }
                        outlines[target] = entry
                    end
                    local color = esp.TeamColors and target.TeamColor and target.TeamColor.Color or Color3.fromRGB(120, 160, 255)
                    entry.Highlight.FillColor, entry.Highlight.OutlineColor = color, color
                    entry.Highlight.FillTransparency, entry.Highlight.OutlineTransparency = esp.Fill, 0
                    local lines = {}
                    if esp.Names then table.insert(lines, target.DisplayName or target.Name) end
                    if esp.Health then table.insert(lines, tostring(math.ceil(humanoid.Health)) .. " HP") end
                    if esp.Distance then table.insert(lines, tostring(math.floor(distance)) .. " studs") end
                    entry.Billboard.Enabled, entry.Text.TextColor3, entry.Text.Text = #lines > 0, color, table.concat(lines, "\n")
                end
            end
        end
    end)

    local settingsTab = configuration.SettingsTab or ui(window, "Tab", { Title = lelHubTitle("Settings"), Icon = "settings" })
    local appearance = ui(settingsTab, "Section", "Appearance")
    register(appearance, "Dropdown", "Theme", { Title = lelHubTitle("Theme"), Values = library.Themes or { "Dark", "Light" }, Default = library.Theme or "Dark", Multi = false }, function(value)
        library:SetTheme(value)
    end)
    local menuBind = ui(appearance, "Keybind", "LelShared_MenuKey", {
        Title = lelHubTitle("Menu key"),
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
    local showButton = register(appearance, "Toggle", "ShowButton", { Title = lelHubTitle("Show menu button"), Default = true }, function(value)
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
    local moduleChoice = moduleFiles.Global and "Global" or moduleNames[1]
    register(moduleSection, "Dropdown", "HubChoice", { Title = lelHubTitle("Choose hub"), Values = moduleNames, Default = moduleChoice, Multi = false }, function(value)
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
        for target in pairs(outlines) do clearESP(target) end
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
    connect(player.CharacterAdded, function(character)
        hideAccessories(character)
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
            hideAccessories(character)
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
    local window = library:CreateWindow({ Title = lelHubTitle("LelHub Violence District"), SubTitle = "by LelSploit", Size = UDim2.fromOffset(760, 540), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift })
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
        if not self.Stopped then library:Notify({ Title = lelHubTitle("LelHub"), Content = tostring(message), Duration = 4 }) end
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
        local options = { Title = lelHubTitle(title), Default = settings.Default }
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

if game.GameId ~= 6739698191 then
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = lelHubTitle("LelHub"), Text = "LelHub: this script is for Violence District only", Duration = 4 })
    return
end

if not LPH_OBFUSCATED then
    local function Passthrough(fn) return fn end
    LPH_JIT, LPH_JIT_MAX, LPH_NO_VIRTUALIZE = Passthrough, Passthrough, Passthrough
end

local environment = getgenv and getgenv() or _G
if type(environment.ViolenceDistrictUnload) == "function" then
    pcall(environment.ViolenceDistrictUnload)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local vector3New, cframeNew, cframeLookAt = Vector3.new, CFrame.new, CFrame.lookAt
local vectorZero = Vector3.zero
local osClock, mathHuge = os.clock, math.huge

local xDTaraZ = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, type(value) == "function" and LPH_JIT(value) or value)
    end,
})

xDTaraZ.Config = {
    UiSource = "https://raw.githubusercontent.com/xDTaraZz/Roblox-Scripts/refs/heads/main/ui.lua",
    UpdateLog = {
        { "2026-10-03", "Classic LelHub UI is back\nBetter executor support\nBug fixes & better UI" },
    },
    SaveFolder = "Violence District",
    Intro = true,
    LoadTimeout = 10,
    AlertTries = 20,
    AlertRetry = 0.5,
    JobFailLimit = 5,
    JobFailWindow = 10,
    StatusInterval = 1,
    RepairTick = 0.25,
    GenDone = 100,
    SpareGens = 1,
    AttackReach = 2,
    LungeDelay = 0.21,
    AuraCooldown = 1.1,
    CarryDelay = 0.8,
    Settle = 0.55,
    FinishFirst = 85,
    ArriveRadius = 4,
    DriftLimit = 12,
    DangerKeep = 2,
    DangerPick = 2.5,
    DistanceWeight = 0.05,
    HealMax = 15,
    HealMinUseful = 3,
    HelpBan = 8,
    UnhookReach = 10,
    GuardTick = 0.05,
    FarmDodge = 24,
    SwingTail = 0.4,
    LegitReach = 9,
    ServerReach = 4.2,
    ParryRange = 14,
    ParryPanic = 6,
    ParryClosing = 12,
    ParryRetry = 1,
    ParryFast = 0.25,
    ParryScan = 5,
    LegitAngle = 0.5,
    HookRest = 1,
    UnhookHold = 2.5,
    StallTime = 8,
    StallBan = 30,
    HookTween = 0.2,
    GenBreakTime = 2,
    KickRegress = 25,
    SelfUnhookRetry = 1,
    SelfUnhookMax = 12,
    DodgeCooldown = 1.5,
    RolePending = 8,
    JumpVelocity = 50,
    AlertRadius = 60,
    ShopDelay = 0.6,
    FirstLevelCost = 750,
    EscapeRetry = 6,
    ShopInterval = 10,
    SurvivorSpeed = 21,
    KillerSpeed = 18.7,
    ObjectEspRefresh = 1,
    ModelRescan = 10,
}

xDTaraZ.State = {
    Alive = true,
    Connections = {},
}

xDTaraZ.Options = {
    AntiAfk = false,
    RoleMode = "Any",
    Speed = false,
    SpeedValue = 24,
    Noclip = false,
    NoSlow = false,
    NoFall = false,
    FreeTurn = false,
    AntiShake = false,
    AntiBlind = false,
    SmartHitbox = false,
    SlashMode = "Rage",
    InfiniteJump = false,
    Fullbright = false,
    NoFog = false,

    AutoRepair = false,
    PerfectSkillCheck = false,
    InstantEscape = false,
    EscapeDelay = 0,
    AutoHeal = false,
    AutoUnhook = false,
    AutoDodge = false,
    DodgeRadius = 20,
    AutoSelfUnhook = false,
    AutoParry = false,
    NoParryCooldown = false,
    KillerAlert = false,

    AutoBuyPerks = false,
    AutoLevelPerks = false,
    KeepScrews = 0,

    KillAura = false,
    AuraRange = 500,
    AutoHook = false,
    AutoBreakGens = false,
    AntiStun = false,

    EspGenerators = false,
    EspHooks = false,
    EspGates = false,
    EspPallets = false,
    EspWindows = false,
}

xDTaraZ.Util = {}
local Util = xDTaraZ.Util


local function Resolve(...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "function" then return candidate end
    end
    return nil
end

Util.Request = Resolve(request, http_request, type(syn) == "table" and syn.request, type(http) == "table" and http.request)
Util.SetClipboard = Resolve(setclipboard, toclipboard)
Util.GetHui = Resolve(gethui, get_hidden_gui)
Util.GetConnections = Resolve(getconnections, get_signal_cons)
Util.FireSignal = Resolve(firesignal)
Util.FireTouch = Resolve(firetouchinterest)
Util.GetGc = Resolve(getgc, get_gc_objects)
Util.NameCallMethod = Resolve(getnamecallmethod)
Util.HookMetamethod = Resolve(hookmetamethod)
Util.Closure = Resolve(newcclosure) or function(fn) return fn end

Util.RawCaps = {
    Connections = function() return Util.GetConnections ~= nil end,
    Signals = function() return Util.FireSignal ~= nil end,
    Gc = function() return Util.GetGc ~= nil end,
    Namecall = function() return Util.HookMetamethod ~= nil and Util.NameCallMethod ~= nil end,
}


function Util.Can(cap)
    local library = xDTaraZ.Library
    if library == nil then return false end
    if library.Compat then return (library.Compat.Has(cap)) end
    for _, name in ipairs(type(cap) == "table" and cap or { cap }) do
        local probe = Util.RawCaps[name]
        if not (probe and probe()) then return false end
    end
    return true
end


function Util.HookMeta(object, method, handler)
    local compat = xDTaraZ.Library and xDTaraZ.Library.Compat
    if compat then return compat.HookMeta(object, method, handler) end
    if not Util.HookMetamethod then return nil end

    local ok, original = pcall(Util.HookMetamethod, object, method, Util.Closure(handler))
    if not ok or type(original) ~= "function" then return nil end
    return original, function()
        Util.HookMetamethod(object, method, original)
    end
end


function Util.HttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    if not Util.Request then return nil end
    local sent, response = pcall(Util.Request, { Url = url, Method = "GET" })
    if sent and type(response) == "table" and tonumber(response.StatusCode) == 200 and type(response.Body) == "string" then
        return response.Body
    end
    return nil
end


function Util.Alert(text)
    warn("[ViolenceDistrict] " .. text)
    task.spawn(function()
        local starterGui = game:GetService("StarterGui")
        for _ = 1, xDTaraZ.Config.AlertTries do
            if pcall(starterGui.SetCore, starterGui, "SendNotification", { Title = lelHubTitle("LelHub"), Text = text, Duration = 10 }) then return end
            task.wait(xDTaraZ.Config.AlertRetry)
        end
    end)
end


function Util.LoadLibrary()
    return createCompatibilityLibrary("Violence_District")
end

function Util.Copy(text)
    if not Util.SetClipboard then return false end
    Util.SetClipboard(text)
    return true
end


function Util.Try(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[ViolenceDistrict] " .. label .. ": " .. tostring(err)) end
    return ok, err
end


function Util.Mount(instance)
    local ok, hui = pcall(Util.GetHui or error)
    if ok and typeof(hui) == "Instance" and pcall(function() instance.Parent = hui end) then return end
    if pcall(function() instance.Parent = game:GetService("CoreGui") end) then return end
    instance.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", xDTaraZ.Config.LoadTimeout)
end

function xDTaraZ:Connect(signal, handler)
    local connection = signal:Connect(handler)
    table.insert(self.State.Connections, connection)
    return connection
end

xDTaraZ.GameLib = {}
local GameLib = xDTaraZ.GameLib

GameLib.Folder = ReplicatedStorage:WaitForChild("Remotes", xDTaraZ.Config.LoadTimeout)


function GameLib.FindRemote(...)
    local root = GameLib.Folder
    if not root then return nil end
    local node = root
    for _, step in ipairs({ ... }) do
        node = node and node:FindFirstChild(step)
    end
    if node then return node end

    local name, found = select(select("#", ...), ...), nil
    for _, desc in ipairs(root:GetDescendants()) do
        if desc.Name ~= name or not (desc:IsA("BaseRemoteEvent") or desc:IsA("RemoteFunction")) then continue end
        if found then return nil end
        found = desc
    end
    return found
end

GameLib.RemotePaths = {
    Repair = { "Generator", "RepairEvent" },
    GenCheck = { "Generator", "SkillCheckEvent" },
    GenResult = { "Generator", "SkillCheckResultEvent" },
    Heal = { "Healing", "HealEvent" },
    HealCheck = { "Healing", "SkillCheckEvent" },
    HealResult = { "Healing", "SkillCheckResultEvent" },
    Unhook = { "Carry", "UnHookEvent" },
    SelfUnhook = { "Carry", "SelfUnHookEvent" },
    Fall = { "Mechanics", "Fall" },
    Carry = { "Carry", "CarrySurvivorEvent" },
    Hook = { "Carry", "HookEvent" },
    HookCommit = { "Carry", "HookCommit" },
    BreakGen = { "Generator", "BreakGenEvent" },
    BreakGenCommit = { "Generator", "BreakGenCommit" },
    Lunge = { "Attacks", "Lunge" },
    Stun = { "Pallet", "Jason", "Stun" },
    StunOver = { "Pallet", "Jason", "Stunover" },
    Attack = { "Attacks", "BasicAttack" },
    BuyPerk = { "Shop", "PurchasePerk" },
    LevelPerk = { "Shop", "LevelUpPerk" },
    PerkInfo = { "Shop", "GetPerkInfo" },
}

GameLib.Remote = {}
for key, path in pairs(GameLib.RemotePaths) do
    GameLib.Remote[key] = GameLib.FindRemote(table.unpack(path))
end

GameLib.Needs = {
    AutoRepair = { "Repair" },
    PerfectSkillCheck = { "GenCheck", "HealCheck", "GenResult", "HealResult" },
    AutoHeal = { "Heal" },
    AutoUnhook = { "Unhook" },
    AutoSelfUnhook = { "SelfUnhook" },
    NoFall = { "Fall" },
    KillAura = { "Lunge", "Attack" },
    AutoHook = { "Carry", "Hook", "HookCommit" },
    AutoBreakGens = { "BreakGen", "BreakGenCommit" },
    AntiStun = { "Stun", "StunOver" },
    AutoBuyPerks = { "BuyPerk", "PerkInfo" },
    AutoLevelPerks = { "LevelPerk", "PerkInfo" },
}


function GameLib.Missing(idx)
    for _, key in ipairs(GameLib.Needs[idx] or {}) do
        if not GameLib.Remote[key] then return table.concat(GameLib.RemotePaths[key], "/") end
    end
    return nil
end

xDTaraZ.Player = { Client = LocalPlayer }

function xDTaraZ.Player:Bind(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid", xDTaraZ.Config.LoadTimeout)
    self.Root = character:WaitForChild("HumanoidRootPart", xDTaraZ.Config.LoadTimeout)
end

function xDTaraZ.Player:IsAlive()
    return self.Humanoid ~= nil and self.Humanoid.Health > 0 and self.Root ~= nil and self.Root.Parent ~= nil
end


function xDTaraZ.Player.Role(player)
    local team = (player or LocalPlayer).Team
    return team and team.Name or nil
end


function xDTaraZ.Player.Disabled(character)
    if not character then return true end
    return character:GetAttribute("Knocked") == true
        or character:GetAttribute("IsHooked") == true
        or character:GetAttribute("IsCarried") == true
end

function xDTaraZ.Player.Killer()
    local team = Teams:FindFirstChild("Killer")
    local killer = team and team:GetPlayers()[1]
    return killer and killer.Character
end

function xDTaraZ.Player.Survivors()
    local team = Teams:FindFirstChild("Survivors")
    local list = {}
    if not team then return list end
    for _, player in ipairs(team:GetPlayers()) do
        local char = player.Character
        if player ~= LocalPlayer and char and char:FindFirstChild("HumanoidRootPart") then
            list[#list + 1] = char
        end
    end
    return list
end

function xDTaraZ.Player.Teleport(cframe)
    local hrp = xDTaraZ.Player.Root
    if not hrp then return end
    hrp.CFrame = cframe
    hrp.AssemblyLinearVelocity = vectorZero
end

xDTaraZ.Map = {}

function xDTaraZ.Map.Root()
    return Workspace:FindFirstChild("Map")
end

function xDTaraZ.Map.Tagged(tag)
    local map = xDTaraZ.Map.Root()
    local list = {}
    if not map then return list end
    for _, part in ipairs(CollectionService:GetTagged(tag)) do
        if part:IsA("BasePart") and part:IsDescendantOf(map) then
            list[#list + 1] = part
        end
    end
    return list
end

xDTaraZ.Map.Cache = { Map = nil, Models = {}, Scanned = {}, Total = 0 }


function xDTaraZ.Map.Models(name)
    local map = xDTaraZ.Map.Root()
    local cache = xDTaraZ.Map.Cache
    if not map then return {} end
    if cache.Map ~= map then
        cache.Map, cache.Models, cache.Scanned = map, {}, {}
    end
    local list = cache.Models[name]
    local fresh = osClock() - (cache.Scanned[name] or 0) < xDTaraZ.Config.ModelRescan
    if list and fresh and (not list[1] or list[1]:IsDescendantOf(map)) then return list end
    cache.Scanned[name] = osClock()
    list = {}
    for _, inst in ipairs(map:GetDescendants()) do
        if inst.Name == name and inst:IsA("Model") then list[#list + 1] = inst end
    end
    cache.Models[name] = list
    return list
end


function xDTaraZ.Map.Generators()
    return xDTaraZ.Map.Models("Generator")
end


function xDTaraZ.Map.PointsOf(gen)
    local cache = xDTaraZ.Map.Cache
    cache.Points = cache.Points or setmetatable({}, { __mode = "k" })
    local list = cache.Points[gen]
    if list and list[1] and list[1].Parent then return list end
    list = {}
    for _, point in ipairs(xDTaraZ.Map.Tagged("GeneratorPoint")) do
        if point:IsDescendantOf(gen) then list[#list + 1] = point end
    end
    cache.Points[gen] = list
    return list
end

function xDTaraZ.Map.GenProgress(model)
    return tonumber(model:GetAttribute("RepairProgress")) or 0
end


function xDTaraZ.Map.GensLeft()
    local gens = xDTaraZ.Map.Generators()
    local cache = xDTaraZ.Map.Cache
    local map = xDTaraZ.Map.Root()
    if cache.TotalMap ~= map then cache.TotalMap, cache.Total = map, 0 end
    cache.Total = math.max(cache.Total, #gens)
    local done = 0
    for _, gen in ipairs(gens) do
        if xDTaraZ.Map.GenProgress(gen) >= xDTaraZ.Config.GenDone then done += 1 end
    end
    return math.max(cache.Total - xDTaraZ.Config.SpareGens - done, 0)
end


function xDTaraZ.Map.Nearest(parts, pos, filter)
    local best, bestDist = nil, mathHuge
    for _, part in ipairs(parts) do
        if filter and not filter(part) then continue end
        local dist = (part.Position - pos).Magnitude
        if dist < bestDist then best, bestDist = part, dist end
    end
    return best, bestDist
end

xDTaraZ.Scheduler = { Jobs = {}, Halts = {}, Booted = false }


function xDTaraZ.Scheduler.Every(name, interval, fn, toggles, extra)
    extra = extra or {}
    xDTaraZ.Scheduler.Jobs[name] = {
        Interval = interval, Fn = fn, Last = 0, Running = false, Toggles = toggles or {},
        Core = extra.Core or toggles == nil, Restore = extra.Restore,
    }
end


function xDTaraZ.Scheduler.SwitchOff(job)
    local switched = {}
    for _, idx in ipairs(job.Toggles) do
        if xDTaraZ.Options[idx] then
            xDTaraZ.Options[idx] = false
            switched[#switched + 1] = idx
        end
    end
    return switched
end


function xDTaraZ.Scheduler.Fail(name, job, err)
    local streak = job.Streak
    if not streak then
        streak = { count = 0, since = osClock() }
        job.Streak = streak
        warn("[ViolenceDistrict] job " .. name .. ":", err)
    end
    streak.count += 1
    if streak.count < xDTaraZ.Config.JobFailLimit or osClock() - streak.since < xDTaraZ.Config.JobFailWindow then return end

    local switched = xDTaraZ.Scheduler.SwitchOff(job)
    if job.Core and #switched == 0 then return end
    job.Streak = nil
    job.Stopped = not job.Core and #switched == 0
    if job.Restore then Util.Try("restore " .. name, job.Restore) end

    local reason = tostring(err):match("^[^\n]*")
    warn("[ViolenceDistrict] job " .. name .. " stopped: " .. reason)
    if #switched > 0 then
        table.insert(xDTaraZ.Scheduler.Halts, { Toggles = switched, Message = name .. " stopped: " .. reason })
    end
end


function xDTaraZ.Scheduler.Wakes(job)
    for _, idx in ipairs(job.Toggles) do
        if xDTaraZ.Options[idx] then
            job.Stopped = nil
            return true
        end
    end
    return false
end

function xDTaraZ.Scheduler.Step()
    local now = osClock()
    for name, job in pairs(xDTaraZ.Scheduler.Jobs) do
        if job.Running or now - job.Last < job.Interval then continue end
        if job.Stopped and not xDTaraZ.Scheduler.Wakes(job) then continue end
        job.Last = now
        job.Running = true
        task.spawn(function()
            local ok, err = pcall(job.Fn)
            job.Running = false
            if ok then
                job.Streak = nil
            else
                xDTaraZ.Scheduler.Fail(name, job, err)
            end
        end)
    end
end

function xDTaraZ.Scheduler.Boot()
    if xDTaraZ.Scheduler.Booted then return end
    xDTaraZ.Scheduler.Booted = true
    xDTaraZ:Connect(RunService.Heartbeat, xDTaraZ.Scheduler.Step)
end

xDTaraZ.Player.AntiAfk = { Connection = nil }

function xDTaraZ.Player.AntiAfk.OnIdled()
    if not xDTaraZ.Options.AntiAfk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero)
end

function xDTaraZ.Player.AntiAfk.Arm()
    if xDTaraZ.Player.AntiAfk.Connection then return end
    xDTaraZ.Player.AntiAfk.Connection = xDTaraZ:Connect(LocalPlayer.Idled, xDTaraZ.Player.AntiAfk.OnIdled)
end

xDTaraZ.Role = { Pending = 0 }

function xDTaraZ.Role.Step()
    local mode = xDTaraZ.Options.RoleMode
    if mode ~= "Survivor only" and mode ~= "Prefer killer" then return end
    if LocalPlayer:GetAttribute("AllowKiller") == (mode == "Prefer killer") or osClock() < xDTaraZ.Role.Pending then return end
    local settings = LocalPlayer.PlayerGui:FindFirstChild("Settings", true)
    local button = settings and settings:FindFirstChild("chance", true)
    button = button and button:FindFirstChildWhichIsA("GuiButton")
    if not button or not xDTaraZ.Role.Supported() then return end
    xDTaraZ.Role.Pending = osClock() + xDTaraZ.Config.RolePending
    if not Util.Can("Connections") then
        Util.FireSignal(button.MouseButton1Click)
        return
    end
    for _, conn in ipairs(Util.GetConnections(button.MouseButton1Click)) do
        conn:Fire()
    end
end


function xDTaraZ.Role.Supported()
    return Util.Can("Connections") or Util.Can("Signals")
end

xDTaraZ.Movement = { Collide = {}, JumpConn = nil, Walk = nil, Lifted = nil, LiftedTo = nil }

function xDTaraZ.Movement.Frame()
    local hum, char = xDTaraZ.Player.Humanoid, xDTaraZ.Player.Character
    if not hum or not char then return end

    if xDTaraZ.Options.Speed then
        if not xDTaraZ.Movement.Walk then
            xDTaraZ.Movement.Walk = xDTaraZ.Movement.Lifted or hum.WalkSpeed
            xDTaraZ.Movement.Lifted, xDTaraZ.Movement.LiftedTo = nil, nil
        end
        hum.WalkSpeed = xDTaraZ.Options.SpeedValue
    elseif xDTaraZ.Movement.Walk then
        hum.WalkSpeed = xDTaraZ.Movement.Walk
        xDTaraZ.Movement.Walk = nil
    end
    if xDTaraZ.Options.NoSlow and not xDTaraZ.Options.Speed and hum.WalkSpeed > 0 then
        local base = xDTaraZ.Movement.BaseSpeed(char)
        if hum.WalkSpeed < base then
            xDTaraZ.Movement.Lifted = hum.WalkSpeed
            xDTaraZ.Movement.LiftedTo = base
            hum.WalkSpeed = base
        end
    elseif xDTaraZ.Movement.Lifted then
        xDTaraZ.Movement.DropLift(hum, char)
    end

    if xDTaraZ.Options.FreeTurn and not hum.AutoRotate and not char:GetAttribute("overridelookscript") and not char:GetAttribute("Immobile") then
        local root = xDTaraZ.Player.Root
        local look = Workspace.CurrentCamera.CFrame.LookVector
        local flat = vector3New(look.X, 0, look.Z)
        if root and flat.Magnitude > 0 then root.CFrame = cframeLookAt(root.Position, root.Position + flat) end
    end

    if xDTaraZ.Options.Noclip then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.CanCollide then
                xDTaraZ.Movement.Collide[part] = true
                part.CanCollide = false
            end
        end
    elseif next(xDTaraZ.Movement.Collide) then
        xDTaraZ.Movement.RestoreCollide()
    end
end


function xDTaraZ.Movement.BaseSpeed(char)
    if xDTaraZ.Player.Role() == "Killer" then
        return tonumber(char:GetAttribute("Speed")) or xDTaraZ.Config.KillerSpeed
    end
    return xDTaraZ.Config.SurvivorSpeed
end


function xDTaraZ.Movement.DropLift(hum, char)
    local before, wrote = xDTaraZ.Movement.Lifted, xDTaraZ.Movement.LiftedTo
    xDTaraZ.Movement.Lifted, xDTaraZ.Movement.LiftedTo = nil, nil
    if char:GetAttribute("Sprinting") or hum.WalkSpeed ~= wrote then return end
    hum.WalkSpeed = before
end

function xDTaraZ.Movement.RestoreCollide()
    for part in pairs(xDTaraZ.Movement.Collide) do
        if part.Parent then part.CanCollide = true end
    end
    table.clear(xDTaraZ.Movement.Collide)
end

function xDTaraZ.Movement.OnJump()
    if not xDTaraZ.Options.InfiniteJump then return end
    local hrp = xDTaraZ.Player.Root
    if not hrp then return end
    local vel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = vector3New(vel.X, xDTaraZ.Config.JumpVelocity, vel.Z)
end

function xDTaraZ.Movement.Start()
    xDTaraZ:Connect(RunService.Stepped, xDTaraZ.Movement.Frame)
    xDTaraZ:Connect(UserInputService.JumpRequest, xDTaraZ.Movement.OnJump)
end

function xDTaraZ.Movement.Release()
    xDTaraZ.Movement.RestoreCollide()
    local hum = xDTaraZ.Player.Humanoid
    local char = xDTaraZ.Player.Character
    if hum and hum.Parent and char and xDTaraZ.Movement.Lifted then xDTaraZ.Movement.DropLift(hum, char) end
    if hum and hum.Parent and xDTaraZ.Movement.Walk then hum.WalkSpeed = xDTaraZ.Movement.Walk end
    xDTaraZ.Movement.Walk = nil
    xDTaraZ.Movement.Lifted, xDTaraZ.Movement.LiftedTo = nil, nil
end

xDTaraZ.World = { Saved = nil }

function xDTaraZ.World.Save()
    if xDTaraZ.World.Saved then return end
    xDTaraZ.World.Saved = {
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        Atmosphere = {},
    }
    for _, atmo in ipairs(Lighting:GetChildren()) do
        if atmo:IsA("Atmosphere") then xDTaraZ.World.Saved.Atmosphere[atmo] = atmo.Density end
    end
end

function xDTaraZ.World.Step()
    local bright, fog = xDTaraZ.Options.Fullbright, xDTaraZ.Options.NoFog
    if not bright and not fog then
        xDTaraZ.World.Restore()
        return
    end
    xDTaraZ.World.Save()
    local saved = xDTaraZ.World.Saved

    if bright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.Brightness, Lighting.ClockTime = saved.Brightness, saved.ClockTime
        Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient = saved.GlobalShadows, saved.Ambient, saved.OutdoorAmbient
    end

    Lighting.FogEnd = fog and 1e6 or saved.FogEnd
    Lighting.FogStart = fog and 1e6 or saved.FogStart
    for atmo, density in pairs(saved.Atmosphere) do
        if atmo.Parent then atmo.Density = fog and 0 or density end
    end
end

function xDTaraZ.World.Restore()
    local saved = xDTaraZ.World.Saved
    if not saved then return end
    xDTaraZ.World.Saved = nil
    Lighting.Brightness, Lighting.ClockTime = saved.Brightness, saved.ClockTime
    Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient = saved.GlobalShadows, saved.Ambient, saved.OutdoorAmbient
    Lighting.FogEnd, Lighting.FogStart = saved.FogEnd, saved.FogStart
    for atmo, density in pairs(saved.Atmosphere) do
        if atmo.Parent then atmo.Density = density end
    end
end

xDTaraZ.Block = { Muted = {}, Own = {}, Restore = nil }


local function RemoteSignal(folder, ...)
    local node = ReplicatedStorage:FindFirstChild("Remotes")
    for _, name in ipairs({ folder, ... }) do
        node = node and node:FindFirstChild(name)
    end
    if not node then return nil end
    return node:IsA("BindableEvent") and node.Event or node.OnClientEvent
end

xDTaraZ.Block.Rules = {
    { Option = "PerfectSkillCheck", Signals = { RemoteSignal("Generator", "SkillCheckEvent"), RemoteSignal("Healing", "SkillCheckEvent") } },
    { Option = "AntiStun", Signals = { RemoteSignal("Pallet", "Jason", "Stun") } },
    { Option = "AntiBlind", Signals = { RemoteSignal("Items", "Flashlight", "GotBlinded") } },
    { Option = "AntiShake", Signals = { RemoteSignal("Game", "shake") } },
}

function xDTaraZ.Block.Keep(fn)
    xDTaraZ.Block.Own[fn] = true
end

function xDTaraZ.Block.Mute(rule)
    local muted = xDTaraZ.Block.Muted[rule] or {}
    xDTaraZ.Block.Muted[rule] = muted
    for _, signal in ipairs(rule.Signals) do
        for _, conn in ipairs(Util.GetConnections(signal)) do
            if conn.Enabled and not xDTaraZ.Block.Own[conn.Function] then
                pcall(function() conn:Disable() end)
                muted[#muted + 1] = conn
            end
        end
    end
end

function xDTaraZ.Block.Unmute(rule)
    local muted = xDTaraZ.Block.Muted[rule]
    if not muted then return end
    for _, conn in ipairs(muted) do pcall(function() conn:Enable() end) end
    xDTaraZ.Block.Muted[rule] = nil
end

function xDTaraZ.Block.Step()
    xDTaraZ.Block.SyncFall()
    if not Util.Can("Connections") then return end
    for _, rule in ipairs(xDTaraZ.Block.Rules) do
        if xDTaraZ.Options[rule.Option] then xDTaraZ.Block.Mute(rule) else xDTaraZ.Block.Unmute(rule) end
    end
end

function xDTaraZ.Block.Release()
    xDTaraZ.Block.SyncFall()
    for _, rule in ipairs(xDTaraZ.Block.Rules) do xDTaraZ.Block.Unmute(rule) end
end


function xDTaraZ.Block.SyncFall()
    local wanted = xDTaraZ.Options.NoFall and xDTaraZ.State.Alive
    if wanted and not xDTaraZ.Block.Restore then
        xDTaraZ.Block.HookFall()
    elseif not wanted and xDTaraZ.Block.Restore then
        local restore = xDTaraZ.Block.Restore
        xDTaraZ.Block.Restore = nil
        pcall(restore)
    end
end

function xDTaraZ.Block.HookFall()
    local fall = GameLib.Remote.Fall
    if not (fall and Util.Can("Namecall")) then return end
    local original, restore
    original, restore = Util.HookMeta(game, "__namecall", function(self, ...)
        if self == fall and xDTaraZ.Options.NoFall and xDTaraZ.State.Alive and Util.NameCallMethod() == "FireServer" then return nil end
        return original(self, ...)
    end)
    xDTaraZ.Block.Restore = restore
end

xDTaraZ.Survivor = {
    Job = nil,
    Gen = nil,
    Banned = {},
    Map = nil,
    Status = "Off",
    RoundStart = 0,
    Escapes = 0,
    LastEscape = 0,
}

xDTaraZ.Survivor.Rank = { Unhook = 3, Heal = 2, Repair = 1 }


function xDTaraZ.Survivor.NewJob(kind, target, remote)
    return { Kind = kind, Target = target, Remote = remote, Since = osClock(), Fired = false, Progress = 0, Checked = osClock() }
end

function xDTaraZ.Survivor.Finish()
    local job = xDTaraZ.Survivor.Job
    xDTaraZ.Survivor.Job = nil
    if not (job and job.Fired) or job.Kind == "Unhook" or not job.Target.Parent then return end
    pcall(function() job.Remote:FireServer(job.Target, false) end)
end


function xDTaraZ.Survivor.Hold(target, locked)
    local hrp = xDTaraZ.Player.Root
    if not hrp then return end
    local teammate = target.Name == "HumanoidRootPart"
    local spot = teammate and (target.CFrame * cframeNew(0, 0, 2.5)).Position or target.Position
    local flat = vector3New(hrp.Position.X - spot.X, 0, hrp.Position.Z - spot.Z).Magnitude
    if flat <= (locked and xDTaraZ.Config.DriftLimit or xDTaraZ.Config.ArriveRadius) then return end
    local look = teammate and target.Position or spot + target.CFrame.LookVector
    xDTaraZ.Player.Teleport(cframeLookAt(spot, look))
end


function xDTaraZ.Survivor.Danger(pos, scale)
    local opts = xDTaraZ.Options
    if not opts.AutoDodge then return false end
    local killer = xDTaraZ.Player.Killer()
    local root = killer and killer:FindFirstChild("HumanoidRootPart")
    return root ~= nil and (root.Position - pos).Magnitude <= opts.DodgeRadius * (scale or xDTaraZ.Config.DangerKeep)
end

function xDTaraZ.Survivor.GenUsable(gen)
    if not gen or not gen.Parent then return false end
    if xDTaraZ.Map.GenProgress(gen) >= xDTaraZ.Config.GenDone then return false end
    return osClock() >= (xDTaraZ.Survivor.Banned[gen] or 0)
end


function xDTaraZ.Survivor.PointOn(gen)
    local job = xDTaraZ.Survivor.Job
    for _, point in ipairs(xDTaraZ.Map.PointsOf(gen)) do
        local mine = job and job.Target == point
        if not mine and CollectionService:HasTag(point, "doing action") then continue end
        if xDTaraZ.Survivor.Danger(point.Position, xDTaraZ.Config.DangerPick) then continue end
        return point
    end
    return nil
end


function xDTaraZ.Survivor.PickGenPoint(pos, peek)
    local gen = xDTaraZ.Survivor.Gen
    local point = xDTaraZ.Survivor.GenUsable(gen) and xDTaraZ.Survivor.PointOn(gen)
    if point then return point end

    local best, bestScore = nil, mathHuge
    for _, candidate in ipairs(xDTaraZ.Map.Generators()) do
        if not xDTaraZ.Survivor.GenUsable(candidate) then continue end
        local spot = xDTaraZ.Survivor.PointOn(candidate)
        if not spot then continue end
        local score = (xDTaraZ.Config.GenDone - xDTaraZ.Map.GenProgress(candidate)) + (spot.Position - pos).Magnitude * xDTaraZ.Config.DistanceWeight
        if score < bestScore then best, bestScore = spot, score end
    end
    if not peek then xDTaraZ.Survivor.Gen = best and best:FindFirstAncestor("Generator") end
    return best
end


function xDTaraZ.Survivor.HealTarget(downedOnly)
    local me = xDTaraZ.Player.Root
    local best, bestScore = nil, mathHuge
    for _, char in ipairs(xDTaraZ.Player.Survivors()) do
        local hrp = char.HumanoidRootPart
        if hrp:GetAttribute("CanGetHealed") ~= true or char:GetAttribute("IsHooked") or char:GetAttribute("IsCarried") then continue end
        if char:GetAttribute("IsBeingHealed") or osClock() < (xDTaraZ.Survivor.Banned[char] or 0) then continue end
        local downed = char:GetAttribute("Knocked") == true
        if downedOnly and not downed then continue end
        if xDTaraZ.Survivor.Danger(hrp.Position, xDTaraZ.Config.DangerPick) then continue end
        local score = (downed and 0 or 1000) + (me and (hrp.Position - me.Position).Magnitude or 0)
        if score < bestScore then best, bestScore = hrp, score end
    end
    return best
end

function xDTaraZ.Survivor.UnhookTarget()
    local points = xDTaraZ.Map.Tagged("UnhookPoint")
    for _, char in ipairs(xDTaraZ.Player.Survivors()) do
        if char:GetAttribute("IsHooked") ~= true or osClock() < (xDTaraZ.Survivor.Banned[char] or 0) then continue end
        local point, dist = xDTaraZ.Map.Nearest(points, char.HumanoidRootPart.Position)
        if point and dist < xDTaraZ.Config.UnhookReach and not xDTaraZ.Survivor.Danger(point.Position, xDTaraZ.Config.DangerPick) then
            return point, char
        end
    end
    return nil
end


function xDTaraZ.Survivor.JobAlive(job)
    local target = job.Target
    if not target.Parent or xDTaraZ.Survivor.Danger(target.Position) then return false end
    local age = osClock() - job.Since
    if job.Kind == "Heal" then
        local ok = age <= xDTaraZ.Config.HealMax and target:GetAttribute("CanGetHealed") == true
        if not ok and age < xDTaraZ.Config.HealMinUseful then
            xDTaraZ.Survivor.Banned[target.Parent] = osClock() + xDTaraZ.Config.HelpBan
        end
        return ok
    end
    if job.Kind == "Unhook" then
        if age < xDTaraZ.Config.UnhookHold then return true end
        if job.Char then xDTaraZ.Survivor.Banned[job.Char] = osClock() + xDTaraZ.Config.HelpBan end
        return false
    end
    return xDTaraZ.Survivor.GenUsable(target:FindFirstAncestor("Generator")) and xDTaraZ.Map.GensLeft() > 0
end


function xDTaraZ.Survivor.Candidate(pos)
    local opts, remote = xDTaraZ.Options, GameLib.Remote
    local job = xDTaraZ.Survivor.Job
    local rank = job and xDTaraZ.Survivor.Rank[job.Kind] or 0
    local finishing = job and job.Kind == "Repair"
        and xDTaraZ.Map.GenProgress(job.Target:FindFirstAncestor("Generator")) >= xDTaraZ.Config.FinishFirst

    if opts.AutoUnhook and rank < 3 and not finishing then
        local point, char = xDTaraZ.Survivor.UnhookTarget()
        if point then
            local unhook = xDTaraZ.Survivor.NewJob("Unhook", point, remote.Unhook)
            unhook.Char = char
            return unhook
        end
    end
    if opts.AutoHeal and rank < 2 and not finishing then
        local hrp = xDTaraZ.Survivor.HealTarget(true)
        if hrp then return xDTaraZ.Survivor.NewJob("Heal", hrp, remote.Heal) end
    end
    if job then return nil end
    if opts.AutoRepair and xDTaraZ.Map.GensLeft() > 0 then
        local point = xDTaraZ.Survivor.PickGenPoint(pos)
        if point then return xDTaraZ.Survivor.NewJob("Repair", point, remote.Repair) end
    end
    if opts.AutoHeal then
        local hrp = xDTaraZ.Survivor.HealTarget(false)
        if hrp then return xDTaraZ.Survivor.NewJob("Heal", hrp, remote.Heal) end
    end
    return nil
end

function xDTaraZ.Survivor.Watchdog(job)
    if job.Kind ~= "Repair" or osClock() - job.Checked < xDTaraZ.Config.StallTime then return end
    local gen = job.Target:FindFirstAncestor("Generator")
    local progress = xDTaraZ.Map.GenProgress(gen)
    job.Checked = osClock()
    if progress > job.Progress then
        job.Progress = progress
        return
    end
    xDTaraZ.Survivor.Banned[gen] = osClock() + xDTaraZ.Config.StallBan
    xDTaraZ.Survivor.Gen = nil
    xDTaraZ.Survivor.Finish()
end

function xDTaraZ.Survivor.Run(job)
    xDTaraZ.Survivor.Hold(job.Target, job.Fired and job.Kind ~= "Heal")
    if not job.Fired and osClock() - job.Since >= xDTaraZ.Config.Settle then
        job.Fired = true
        job.Progress = job.Kind == "Repair" and xDTaraZ.Map.GenProgress(job.Target:FindFirstAncestor("Generator")) or 0
        job.Checked = osClock()
        if job.Kind == "Unhook" then job.Remote:FireServer(job.Target) else job.Remote:FireServer(job.Target, true) end
    end
    if job.Fired then xDTaraZ.Survivor.Watchdog(job) end
    xDTaraZ.Survivor.Status = (job.Fired and job.Kind or "Moving to " .. job.Kind) .. " · gens left " .. xDTaraZ.Map.GensLeft()
end


function xDTaraZ.Survivor.FinishLine()
    local hrp = xDTaraZ.Player.Root
    if not hrp then return nil end
    return xDTaraZ.Map.Nearest(xDTaraZ.Map.Tagged("EscapePart"), hrp.Position, function(part)
        return not part.CanCollide
    end)
end

function xDTaraZ.Survivor.EscapeNow()
    local line = xDTaraZ.Survivor.FinishLine()
    if not line then return false end
    xDTaraZ.Survivor.Finish()
    xDTaraZ.Player.Teleport(line.CFrame + vector3New(0, 3, 0))
    local hrp = xDTaraZ.Player.Root
    if Util.FireTouch and hrp then
        Util.FireTouch(hrp, line, 0)
        Util.FireTouch(hrp, line, 1)
    end
    return true
end

function xDTaraZ.Survivor.Enabled()
    local opts = xDTaraZ.Options
    return opts.AutoRepair or opts.AutoHeal or opts.AutoUnhook or opts.InstantEscape
end


function xDTaraZ.Survivor.TryEscape()
    local opts = xDTaraZ.Options
    local ready = opts.InstantEscape and (osClock() - xDTaraZ.Survivor.RoundStart >= opts.EscapeDelay or xDTaraZ.Map.GensLeft() == 0)
    if not ready then return false end
    if osClock() - xDTaraZ.Survivor.LastEscape < xDTaraZ.Config.EscapeRetry then return true end
    if not xDTaraZ.Survivor.EscapeNow() then return false end
    xDTaraZ.Survivor.LastEscape = osClock()
    xDTaraZ.Survivor.Escapes += 1
    xDTaraZ.Survivor.Status = "Escaped"
    return true
end

function xDTaraZ.Survivor.Step()
    if not xDTaraZ.Survivor.Enabled() then
        xDTaraZ.Survivor.Finish()
        xDTaraZ.Survivor.Status = "Off"
        return
    end
    local map = xDTaraZ.Map.Root()
    if map ~= xDTaraZ.Survivor.Map then
        xDTaraZ.Survivor.Map = map
        xDTaraZ.Survivor.RoundStart = osClock()
    end
    if not xDTaraZ.State.Alive or xDTaraZ.Player.Role() ~= "Survivors" or not xDTaraZ.Player:IsAlive() then
        xDTaraZ.Survivor.Gen = nil
        table.clear(xDTaraZ.Survivor.Banned)
        xDTaraZ.Survivor.Finish()
        xDTaraZ.Survivor.Status = "Not a survivor"
        return
    end
    if xDTaraZ.Player.Disabled(xDTaraZ.Player.Character) then
        xDTaraZ.Survivor.Finish()
        xDTaraZ.Survivor.Status = "Downed / hooked"
        return
    end
    if xDTaraZ.Survivor.TryEscape() then return end

    local job = xDTaraZ.Survivor.Job
    if job and not xDTaraZ.Survivor.JobAlive(job) then
        xDTaraZ.Survivor.Finish()
        job = nil
    end
    local better = xDTaraZ.Survivor.Candidate(xDTaraZ.Player.Root.Position)
    if better then
        xDTaraZ.Survivor.Finish()
        xDTaraZ.Survivor.Job = better
        job = better
    end
    if not job then
        xDTaraZ.Survivor.Status = "Waiting · gens left " .. xDTaraZ.Map.GensLeft()
        return
    end
    xDTaraZ.Survivor.Run(job)
end

xDTaraZ.Guard = { Dodges = 0, LastUnhook = 0, UnhookTries = 0, LastDodge = 0 }


function xDTaraZ.Guard.SafeSpot(killerPos)
    local best, bestDist = nil, 0
    for _, gen in ipairs(xDTaraZ.Map.Generators()) do
        if not xDTaraZ.Survivor.GenUsable(gen) then continue end
        local point = xDTaraZ.Survivor.PointOn(gen)
        local dist = point and (point.Position - killerPos).Magnitude or 0
        if dist > bestDist then best, bestDist = point, dist end
    end
    return best
end

function xDTaraZ.Guard.Step()
    local opts = xDTaraZ.Options
    if not (opts.AutoDodge or opts.AutoSelfUnhook) or not xDTaraZ.State.Alive then return end
    if xDTaraZ.Player.Role() ~= "Survivors" or not xDTaraZ.Player:IsAlive() then return end
    local char, hrp = xDTaraZ.Player.Character, xDTaraZ.Player.Root

    if not char:GetAttribute("IsHooked") then xDTaraZ.Guard.UnhookTries = 0 end
    if opts.AutoSelfUnhook and char:GetAttribute("IsHooked") and xDTaraZ.Guard.UnhookTries < xDTaraZ.Config.SelfUnhookMax
        and osClock() - xDTaraZ.Guard.LastUnhook >= xDTaraZ.Config.SelfUnhookRetry then
        xDTaraZ.Guard.LastUnhook = osClock()
        xDTaraZ.Guard.UnhookTries += 1
        GameLib.Remote.SelfUnhook:FireServer()
        return
    end
    if not opts.AutoDodge or xDTaraZ.Player.Disabled(char) or osClock() - xDTaraZ.Guard.LastDodge < xDTaraZ.Config.DodgeCooldown then return end

    local killer = xDTaraZ.Player.Killer()
    local root = killer and killer:FindFirstChild("HumanoidRootPart")
    if not root or (root.Position - hrp.Position).Magnitude > opts.DodgeRadius then return end
    local spot = xDTaraZ.Guard.SafeSpot(root.Position)
    if not spot or (spot.Position - root.Position).Magnitude <= opts.DodgeRadius then return end
    xDTaraZ.Guard.LastDodge = osClock()
    xDTaraZ.Survivor.Finish()
    xDTaraZ.Survivor.Gen = spot:FindFirstAncestor("Generator")
    xDTaraZ.Player.Teleport(spot.CFrame + vector3New(0, 3, 0))
    xDTaraZ.Guard.Dodges += 1
end

xDTaraZ.Alert = { Near = false, Distance = nil }

function xDTaraZ.Alert.Step()
    local hrp = xDTaraZ.Player.Root
    local killer = xDTaraZ.Player.Killer()
    local root = killer and killer:FindFirstChild("HumanoidRootPart")
    if not (hrp and root) or xDTaraZ.Player.Role() ~= "Survivors" then
        xDTaraZ.Alert.Near, xDTaraZ.Alert.Distance = false, nil
        return
    end
    local dist = (root.Position - hrp.Position).Magnitude
    xDTaraZ.Alert.Distance = dist
    local near = dist <= xDTaraZ.Config.AlertRadius
    if near and not xDTaraZ.Alert.Near and xDTaraZ.Options.KillerAlert and xDTaraZ.Library then
        xDTaraZ.Library:Notify("Killer nearby", ("%d m away"):format(dist), 3, "Warning")
    end
    xDTaraZ.Alert.Near = near
end

xDTaraZ.SkillCheck = { Started = false, Checks = 0 }

function xDTaraZ.SkillCheck.OnGen(point, checkId)
    if not xDTaraZ.Options.PerfectSkillCheck then return end
    xDTaraZ.SkillCheck.Checks += 1
    GameLib.Remote.GenResult:FireServer("success", 1, point, checkId)
end

function xDTaraZ.SkillCheck.OnHeal(point)
    if not xDTaraZ.Options.PerfectSkillCheck then return end
    xDTaraZ.SkillCheck.Checks += 1
    GameLib.Remote.HealResult:FireServer("success", 1, point)
end

function xDTaraZ.SkillCheck.Start()
    local remote = GameLib.Remote
    if xDTaraZ.SkillCheck.Started or not (remote.GenCheck and remote.HealCheck and remote.GenResult and remote.HealResult) then return end
    xDTaraZ.SkillCheck.Started = true
    xDTaraZ.Block.Keep(xDTaraZ.SkillCheck.OnGen)
    xDTaraZ.Block.Keep(xDTaraZ.SkillCheck.OnHeal)
    xDTaraZ:Connect(remote.GenCheck.OnClientEvent, xDTaraZ.SkillCheck.OnGen)
    xDTaraZ:Connect(remote.HealCheck.OnClientEvent, xDTaraZ.SkillCheck.OnHeal)
end

function xDTaraZ.Survivor.Sacrifice()
    local hum = xDTaraZ.Player.Humanoid
    if not hum or xDTaraZ.Player.Role() ~= "Survivors" then return false end
    xDTaraZ.Survivor.Finish()
    hum.Health = 0
    return true
end

xDTaraZ.Parry = { Last = 0, Count = 0, Clients = setmetatable({}, { __mode = "k" }), Scanned = 0 }

function xDTaraZ.Parry.Remote()
    return GameLib.FindRemote("Items", "Parrying Dagger", "parry")
end

function xDTaraZ.Parry.Holding()
    return LocalPlayer:GetAttribute("EquippedItem") == "Parrying Dagger"
end


function xDTaraZ.Parry.Threat()
    local hrp = xDTaraZ.Player.Root
    local killer = xDTaraZ.Player.Killer()
    local root = killer and killer:FindFirstChild("HumanoidRootPart")
    if not (hrp and root) then return false end
    local offset = hrp.Position - root.Position
    if offset.Magnitude > xDTaraZ.Config.ParryRange then return false end
    local closing = root.AssemblyLinearVelocity:Dot(offset.Unit)
    return closing >= xDTaraZ.Config.ParryClosing or offset.Magnitude <= xDTaraZ.Config.ParryPanic
end

function xDTaraZ.Parry.FindClients()
    if not Util.Can("Gc") or osClock() - xDTaraZ.Parry.Scanned < xDTaraZ.Config.ParryScan then return end
    xDTaraZ.Parry.Scanned = osClock()
    for _, obj in ipairs(Util.GetGc(true)) do
        if type(obj) == "table" and rawget(obj, "isParryOnCooldown") ~= nil and rawget(obj, "parryEvent") then
            xDTaraZ.Parry.Clients[obj] = true
        end
    end
end

function xDTaraZ.Parry.ClearCooldowns()
    xDTaraZ.Parry.FindClients()
    for client in pairs(xDTaraZ.Parry.Clients) do
        client.isParryOnCooldown = false
        client.isParryResolving = false
        client.cooldownToken = (client.cooldownToken or 0) + 1
    end
end

function xDTaraZ.Parry.Step()
    local opts = xDTaraZ.Options
    if not (opts.AutoParry or opts.NoParryCooldown) or not xDTaraZ.State.Alive then return end
    if xDTaraZ.Player.Role() ~= "Survivors" or not xDTaraZ.Parry.Holding() then return end
    if opts.NoParryCooldown then xDTaraZ.Parry.ClearCooldowns() end
    if not opts.AutoParry or xDTaraZ.Player.Disabled(xDTaraZ.Player.Character) then return end

    local retry = opts.NoParryCooldown and xDTaraZ.Config.ParryFast or xDTaraZ.Config.ParryRetry
    if osClock() - xDTaraZ.Parry.Last < retry or not xDTaraZ.Parry.Threat() then return end
    local remote = xDTaraZ.Parry.Remote()
    if not remote then return end
    xDTaraZ.Parry.Last = osClock()
    xDTaraZ.Parry.Count += 1
    remote:FireServer()
end

xDTaraZ.Killer = { Status = "Off", LastSwing = 0, Hits = 0, Breaks = 0, Kicked = {} }

function xDTaraZ.Killer.Behind(targetRoot)
    local pos = targetRoot.Position - targetRoot.CFrame.LookVector * xDTaraZ.Config.AttackReach
    return cframeLookAt(pos, targetRoot.Position)
end


function xDTaraZ.Killer.Pick(knocked, range)
    local hrp = xDTaraZ.Player.Root
    local best, bestDist = nil, range
    for _, char in ipairs(xDTaraZ.Player.Survivors()) do
        if (char:GetAttribute("Knocked") == true) ~= knocked then continue end
        if char:GetAttribute("IsHooked") or char:GetAttribute("IsCarried") then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local dist = (char.HumanoidRootPart.Position - hrp.Position).Magnitude
        if dist < bestDist then best, bestDist = char, dist end
    end
    return best
end

function xDTaraZ.Killer.Swing(target)
    local root = target.HumanoidRootPart
    local remote = GameLib.Remote
    local stop = osClock() + xDTaraZ.Config.LungeDelay + xDTaraZ.Config.SwingTail
    local fired = false
    remote.Lunge:FireServer()
    local start = osClock()
    while osClock() < stop and root.Parent and xDTaraZ.State.Alive and xDTaraZ.Options.KillAura do
        xDTaraZ.Player.Teleport(xDTaraZ.Killer.Behind(root))
        if not fired and osClock() - start >= xDTaraZ.Config.LungeDelay then
            fired = true
            remote.Attack:FireServer()
        end
        RunService.Heartbeat:Wait()
    end
    if target:GetAttribute("Knocked") then xDTaraZ.Killer.Hits += 1 end
end


function xDTaraZ.Killer.Live(option, hrp)
    return xDTaraZ.State.Alive and xDTaraZ.Options[option] and xDTaraZ.Player:IsAlive() and xDTaraZ.Player.Root == hrp
end

function xDTaraZ.Killer.Carry(target)
    local hrp = xDTaraZ.Player.Root
    xDTaraZ.Player.Teleport(xDTaraZ.Killer.Behind(target.HumanoidRootPart))
    task.wait(xDTaraZ.Config.Settle)
    if not xDTaraZ.Killer.Live("AutoHook", hrp) or not target:GetAttribute("Knocked") then return end
    GameLib.Remote.Carry:FireServer(target)
    task.wait(xDTaraZ.Config.CarryDelay)
end


function xDTaraZ.Killer.Commit(option, point, offset, remote, commit)
    local hrp = xDTaraZ.Player.Root
    if not hrp then return false end
    local seat = point.CFrame * cframeNew(offset)
    xDTaraZ.Player.Teleport(seat * cframeNew(0, 0, 3))
    task.wait(xDTaraZ.Config.Settle)
    if not xDTaraZ.Killer.Live(option, hrp) then return false end
    remote:FireServer(point)
    local tween = TweenService:Create(hrp, TweenInfo.new(xDTaraZ.Config.HookTween), { CFrame = seat })
    tween:Play()
    tween.Completed:Wait()
    if not xDTaraZ.Killer.Live(option, hrp) then return false end
    commit:FireServer(point)
    return true
end

function xDTaraZ.Killer.Hook()
    local hrp = xDTaraZ.Player.Root
    local point = hrp and xDTaraZ.Map.Nearest(xDTaraZ.Map.Tagged("HookPoint"), hrp.Position)
    if not point then return end
    if xDTaraZ.Killer.Commit("AutoHook", point, vector3New(0, 0.6, 0), GameLib.Remote.Hook, GameLib.Remote.HookCommit) then
        task.wait(xDTaraZ.Config.HookRest)
    end
end


function xDTaraZ.Killer.GenToBreak()
    local best, bestProgress = nil, 0
    for _, point in ipairs(xDTaraZ.Map.Tagged("GeneratorPoint")) do
        local gen = point:FindFirstAncestor("Generator")
        local progress = gen and xDTaraZ.Map.GenProgress(gen) or 0
        local fresh = gen and osClock() - (xDTaraZ.Killer.Kicked[gen] or 0) > xDTaraZ.Config.KickRegress
        if fresh and progress > bestProgress and progress < xDTaraZ.Config.GenDone then
            best, bestProgress = point, progress
        end
    end
    return best
end

function xDTaraZ.Killer.BreakGen(point)
    if not xDTaraZ.Killer.Commit("AutoBreakGens", point, vector3New(0, 0, 1), GameLib.Remote.BreakGen, GameLib.Remote.BreakGenCommit) then return end
    task.wait(xDTaraZ.Config.GenBreakTime)
    xDTaraZ.Killer.Kicked[point:FindFirstAncestor("Generator")] = osClock()
    xDTaraZ.Killer.Breaks += 1
end

xDTaraZ.AntiStun = { Count = 0 }

function xDTaraZ.AntiStun.OnStun()
    if not xDTaraZ.Options.AntiStun or xDTaraZ.Player.Role() ~= "Killer" then return end
    xDTaraZ.AntiStun.Count += 1
    GameLib.Remote.StunOver:FireServer()
end

function xDTaraZ.AntiStun.Start()
    if not (GameLib.Remote.Stun and GameLib.Remote.StunOver) then return end
    xDTaraZ.Block.Keep(xDTaraZ.AntiStun.OnStun)
    xDTaraZ:Connect(GameLib.Remote.Stun.OnClientEvent, xDTaraZ.AntiStun.OnStun)
end


function xDTaraZ.Killer.InFront()
    local hrp = xDTaraZ.Player.Root
    local look = hrp.CFrame.LookVector
    for _, char in ipairs(xDTaraZ.Player.Survivors()) do
        if char:GetAttribute("Knocked") or char:GetAttribute("IsHooked") or char:GetAttribute("IsCarried") then continue end
        local offset = char.HumanoidRootPart.Position - hrp.Position
        if offset.Magnitude <= xDTaraZ.Config.LegitReach and look:Dot(offset.Unit) >= xDTaraZ.Config.LegitAngle then return char end
    end
    return nil
end


function xDTaraZ.Killer.LegitSwing(target)
    local remote = GameLib.Remote
    local root = target.HumanoidRootPart
    local function Close()
        local hrp = xDTaraZ.Player.Root
        if not (xDTaraZ.Options.SmartHitbox and hrp and root.Parent) then return end
        local offset = root.Position - hrp.Position
        if offset.Magnitude <= xDTaraZ.Config.ServerReach then return end
        local spot = root.Position - offset.Unit * xDTaraZ.Config.AttackReach
        xDTaraZ.Player.Teleport(cframeLookAt(vector3New(spot.X, hrp.Position.Y, spot.Z), vector3New(root.Position.X, hrp.Position.Y, root.Position.Z)))
    end
    Close()
    remote.Lunge:FireServer()
    task.wait(xDTaraZ.Config.LungeDelay)
    Close()
    remote.Attack:FireServer()
end

function xDTaraZ.Killer.Enabled()
    local opts = xDTaraZ.Options
    return opts.KillAura or opts.AutoHook or opts.AutoBreakGens
end

function xDTaraZ.Killer.Step()
    if not xDTaraZ.Killer.Enabled() then
        xDTaraZ.Killer.Status = "Off"
        return
    end
    if not xDTaraZ.State.Alive or xDTaraZ.Player.Role() ~= "Killer" or not xDTaraZ.Player:IsAlive() then
        xDTaraZ.Killer.Status = "Not the killer"
        return
    end
    local char, opts = xDTaraZ.Player.Character, xDTaraZ.Options

    if char:GetAttribute("CarriedSurvivorId") then
        if opts.AutoHook then xDTaraZ.Killer.Hook() end
        xDTaraZ.Killer.Status = "Carrying"
        return
    end

    if opts.AutoHook then
        local downed = xDTaraZ.Killer.Pick(true, opts.AuraRange)
        if downed then
            xDTaraZ.Killer.Status = "Picking up " .. downed.Name
            xDTaraZ.Killer.Carry(downed)
            return
        end
    end

    if opts.KillAura and GameLib.Remote.Lunge and GameLib.Remote.Attack and osClock() - xDTaraZ.Killer.LastSwing >= xDTaraZ.Config.AuraCooldown then
        local legit = opts.SlashMode == "Legit"
        local target = legit and xDTaraZ.Killer.InFront() or not legit and xDTaraZ.Killer.Pick(false, opts.AuraRange)
        if target then
            xDTaraZ.Killer.LastSwing = osClock()
            xDTaraZ.Killer.Status = "Hitting " .. target.Name
            if legit then xDTaraZ.Killer.LegitSwing(target) else xDTaraZ.Killer.Swing(target) end
            return
        end
    end
    if opts.AutoBreakGens then
        local point = xDTaraZ.Killer.GenToBreak()
        if point then
            xDTaraZ.Killer.Status = "Breaking generator"
            xDTaraZ.Killer.BreakGen(point)
            return
        end
    end
    xDTaraZ.Killer.Status = ("Hunting · downs %d · gens kicked %d"):format(xDTaraZ.Killer.Hits, xDTaraZ.Killer.Breaks)
end

xDTaraZ.Teleport = {}

function xDTaraZ.Teleport.Places()
    local names = { "Nearest Generator", "Best Generator", "Exit Gate", "Nearest Hook", "Killer", "Farthest From Killer" }
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then names[#names + 1] = player.Name end
    end
    return names
end


function xDTaraZ.Teleport.Resolve(choice)
    local hrp = xDTaraZ.Player.Root
    if not hrp then return nil end
    local pos = hrp.Position
    local function At(part) return part and part.CFrame + vector3New(0, 3, 0) end

    if choice == "Nearest Generator" then
        return At(xDTaraZ.Map.Nearest(xDTaraZ.Map.Tagged("GeneratorPoint"), pos, function(point)
            local gen = point:FindFirstAncestor("Generator")
            return gen and xDTaraZ.Map.GenProgress(gen) < xDTaraZ.Config.GenDone
        end))
    elseif choice == "Best Generator" then
        return At(xDTaraZ.Survivor.PickGenPoint(pos, true))
    elseif choice == "Exit Gate" then
        local gate = xDTaraZ.Map.Models("Gate")[1]
        local part = gate and (gate:FindFirstChild("ExitLever", true) or gate:FindFirstChildWhichIsA("BasePart", true))
        return part and (part:IsA("Model") and part:GetPivot() or part.CFrame) + vector3New(0, 3, 0)
    elseif choice == "Nearest Hook" then
        return At(xDTaraZ.Map.Nearest(xDTaraZ.Map.Tagged("HookPoint"), pos))
    elseif choice == "Killer" then
        local killer = xDTaraZ.Player.Killer()
        return killer and At(killer:FindFirstChild("HumanoidRootPart"))
    elseif choice == "Farthest From Killer" then
        local killer = xDTaraZ.Player.Killer()
        local root = killer and killer:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local best, bestDist = nil, 0
        for _, point in ipairs(xDTaraZ.Map.Tagged("GeneratorPoint")) do
            local dist = (point.Position - root.Position).Magnitude
            if dist > bestDist then best, bestDist = point, dist end
        end
        return At(best)
    end
    local player = Players:FindFirstChild(choice)
    return player and player.Character and At(player.Character:FindFirstChild("HumanoidRootPart"))
end

function xDTaraZ.Teleport.Go(choice)
    local cframe = xDTaraZ.Teleport.Resolve(choice)
    if not cframe then return false end
    xDTaraZ.Player.Teleport(cframe)
    return true
end

xDTaraZ.Esp = { Count = 0, Marks = {}, Folder = nil }


function xDTaraZ.Esp.Targets()
    local list = {}
    local mine = xDTaraZ.Player.Role()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local role = xDTaraZ.Player.Role(player)
        if player == LocalPlayer or not char or (role ~= "Survivors" and role ~= "Killer") then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local tag = role == "Killer" and "KILLER" or char:GetAttribute("IsHooked") and "Hooked"
            or char:GetAttribute("Knocked") and "Downed" or nil
        list[#list + 1] = {
            Model = char,
            Name = tag and (player.DisplayName .. " [" .. tag .. "]") or player.DisplayName,
            Health = hum.Health,
            MaxHealth = hum.MaxHealth > 0 and hum.MaxHealth or 100,
            Friendly = mine == role,
            Root = char:FindFirstChild("HumanoidRootPart"),
        }
    end
    xDTaraZ.Esp.Count = #list
    return list
end

xDTaraZ.Esp.Kinds = {
    { Option = "EspGenerators", Glow = true, Color = Color3.fromRGB(255, 196, 64), Find = xDTaraZ.Map.Generators, Label = function(model)
        local progress = xDTaraZ.Map.GenProgress(model)
        if progress >= xDTaraZ.Config.GenDone then return "Gen DONE" end
        return ("Gen %d%%"):format(progress)
    end },
    { Option = "EspHooks", Glow = true, Color = Color3.fromRGB(235, 70, 70), Find = function()
        local list = {}
        for _, point in ipairs(xDTaraZ.Map.Tagged("HookPoint")) do list[#list + 1] = point.Parent end
        return list
    end, Label = function() return "Hook" end },
    { Option = "EspGates", Glow = true, Color = Color3.fromRGB(90, 220, 120), Find = function() return xDTaraZ.Map.Models("Gate") end, Label = function() return "Exit Gate" end },
    { Option = "EspPallets", Color = Color3.fromRGB(200, 150, 90), Find = function()
        local list = {}
        for _, point in ipairs(xDTaraZ.Map.Tagged("PalletPoint")) do list[#list + 1] = point.Parent end
        return list
    end, Label = function() return "Pallet" end },
    { Option = "EspWindows", Color = Color3.fromRGB(110, 170, 255), Find = function()
        local list = {}
        for _, point in ipairs(xDTaraZ.Map.Tagged("VaultPoint")) do
            local model = point.Parent
            if model and model.Name == "Window" and not table.find(list, model) then list[#list + 1] = model end
        end
        return list
    end, Label = function() return "Window" end },
}

function xDTaraZ.Esp.Holder()
    local folder = xDTaraZ.Esp.Folder
    if folder and folder.Parent then return folder end
    folder = Instance.new("Folder")
    folder.Name = "MarioObjectEsp"
    Util.Mount(folder)
    xDTaraZ.Esp.Folder = folder
    return folder
end

function xDTaraZ.Esp.Make(model, kind)
    local holder = xDTaraZ.Esp.Holder()
    local light
    if kind.Glow then
        light = Instance.new("Highlight")
        light.Adornee = model
        light.FillColor = kind.Color
        light.FillTransparency = 0.75
        light.OutlineColor = kind.Color
        light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        light.Parent = holder
    end

    local board = Instance.new("BillboardGui")
    board.Adornee = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
    board.Size = UDim2.fromOffset(120, 22)
    board.StudsOffset = vector3New(0, 3, 0)
    board.AlwaysOnTop = true
    board.Parent = holder

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.TextColor3 = kind.Color
    text.TextStrokeTransparency = 0.3
    text.Parent = board
    return { Light = light, Board = board, Text = text }
end

function xDTaraZ.Esp.Drop(model)
    local mark = xDTaraZ.Esp.Marks[model]
    if not mark then return end
    if mark.Light then mark.Light:Destroy() end
    mark.Board:Destroy()
    xDTaraZ.Esp.Marks[model] = nil
end

function xDTaraZ.Esp.Step()
    local map = xDTaraZ.Map.Root()
    local seen = {}
    local hrp = xDTaraZ.Player.Root
    if map then
        for _, kind in ipairs(xDTaraZ.Esp.Kinds) do
            if not xDTaraZ.Options[kind.Option] then continue end
            for _, model in ipairs(kind.Find()) do
                seen[model] = true
                local mark = xDTaraZ.Esp.Marks[model] or xDTaraZ.Esp.Make(model, kind)
                xDTaraZ.Esp.Marks[model] = mark
                local label = kind.Label(model)
                local part = mark.Board.Adornee
                if hrp and part then label ..= (" · %dm"):format((part.Position - hrp.Position).Magnitude) end
                mark.Text.Text = label
            end
        end
    end
    for model in pairs(xDTaraZ.Esp.Marks) do
        if not seen[model] or not model.Parent then xDTaraZ.Esp.Drop(model) end
    end
end

function xDTaraZ.Esp.Clear()
    for model in pairs(xDTaraZ.Esp.Marks) do xDTaraZ.Esp.Drop(model) end
    if xDTaraZ.Esp.Folder then xDTaraZ.Esp.Folder:Destroy() end
    xDTaraZ.Esp.Folder = nil
end

function xDTaraZ.Esp.GetStatus()
    local visuals = xDTaraZ.Library and xDTaraZ.Library.Visuals
    local players = visuals and visuals:Get("Enabled") and (xDTaraZ.Esp.Count .. " players") or "players off"
    local objects = 0
    for _ in pairs(xDTaraZ.Esp.Marks) do objects += 1 end
    return players .. " · " .. objects .. " objects"
end

xDTaraZ.Shop = { Status = "Off", Maxed = {}, Owned = {}, LevelCost = {}, Bought = 0, Leveled = 0, Busy = false, LastWallet = nil }

function xDTaraZ.Shop.Remote(name)
    return GameLib.FindRemote("Shop", name)
end


function xDTaraZ.Shop.Names(folder)
    local list = {}
    local root = ReplicatedStorage:FindFirstChild(folder)
    for _, child in ipairs(root and root:GetChildren() or {}) do
        if not child.Name:find("^!") then list[#list + 1] = child.Name end
    end
    table.sort(list)
    return list
end

function xDTaraZ.Shop.Wallet()
    return tonumber(LocalPlayer:GetAttribute("Screws")) or 0, tonumber(LocalPlayer:GetAttribute("Gears")) or 0
end


function xDTaraZ.Shop.Info(getter, name)
    local remote = xDTaraZ.Shop.Remote(getter)
    if not remote then return nil end
    local ok, info = pcall(remote.InvokeServer, remote, name)
    return ok and type(info) == "table" and info or nil
end


function xDTaraZ.Shop.Locked(fn, ...)
    if xDTaraZ.Shop.Busy then return 0 end
    xDTaraZ.Shop.Busy = true
    local ok, got = pcall(fn, ...)
    xDTaraZ.Shop.Busy = false
    if not ok then
        warn("[ViolenceDistrict] shop: " .. tostring(got))
        return 0
    end
    return got
end

function xDTaraZ.Shop.BuyPerks()
    local buy = xDTaraZ.Shop.Remote("PurchasePerk")
    if not buy then return 0 end
    local count = 0
    local _, gears = xDTaraZ.Shop.Wallet()
    for _, name in ipairs(xDTaraZ.Shop.Names("Perks")) do
        if not xDTaraZ.State.Alive then break end
        if xDTaraZ.Shop.Owned[name] then continue end
        local info = xDTaraZ.Shop.Info("GetPerkInfo", name)
        if info and info.owned then xDTaraZ.Shop.Owned[name] = true end
        if not info or info.owned or gears < (info.price or mathHuge) then continue end
        buy:FireServer(name)
        gears -= info.price
        count += 1
        task.wait(xDTaraZ.Config.ShopDelay)
    end
    xDTaraZ.Shop.Bought += count
    return count
end

function xDTaraZ.Shop.LevelPerks()
    local level = xDTaraZ.Shop.Remote("LevelUpPerk")
    if not level then return 0 end
    local count = 0
    for _, name in ipairs(xDTaraZ.Shop.Names("Perks")) do
        if xDTaraZ.Shop.Maxed[name] then continue end
        local screws = xDTaraZ.Shop.Wallet()
        local before = xDTaraZ.Shop.Info("GetPerkInfo", name)
        if not before or not before.owned then continue end
        if not xDTaraZ.State.Alive then break end
        local cost = xDTaraZ.Shop.LevelCost[name] or xDTaraZ.Shop.MaxCost()
        if screws - cost < xDTaraZ.Options.KeepScrews then continue end
        level:FireServer(name)
        task.wait(xDTaraZ.Config.ShopDelay)
        local after = xDTaraZ.Shop.Info("GetPerkInfo", name)
        local spent = screws - xDTaraZ.Shop.Wallet()
        if after and after.level ~= before.level then
            xDTaraZ.Shop.LevelCost[name] = math.max(spent, cost or 0)
            count += 1
        elseif spent == 0 and cost and screws > cost * 2 then
            xDTaraZ.Shop.Maxed[name] = true
        end
    end
    xDTaraZ.Shop.Leveled += count
    return count
end


function xDTaraZ.Shop.BuyList(kind, names)
    local buy = xDTaraZ.Shop.Remote("Purchase" .. kind)
    if not buy then return 0 end
    local count = 0
    for key, picked in pairs(names or {}) do
        local name = type(key) == "number" and picked or key
        if not picked or type(name) ~= "string" then continue end
        local owned
        if kind == "Killer" then
            local check = xDTaraZ.Shop.Remote("CheckKillerOwnership")
            local ok, got = pcall(function() return check and check:InvokeServer(name) end)
            owned = ok and got == true
        else
            local info = xDTaraZ.Shop.Info("GetItemInfo", name)
            owned = info and info.owned
        end
        local price = kind == "Killer" and xDTaraZ.Shop.KillerPrice(name) or (xDTaraZ.Shop.Info("GetItemInfo", name) or {}).price
        if owned or not price or xDTaraZ.Shop.Wallet() - price < xDTaraZ.Options.KeepScrews then continue end
        buy:FireServer(name)
        count += 1
        task.wait(xDTaraZ.Config.ShopDelay)
    end
    return count
end


function xDTaraZ.Shop.MaxCost()
    local most = xDTaraZ.Config.FirstLevelCost
    for _, cost in pairs(xDTaraZ.Shop.LevelCost) do most = math.max(most, cost) end
    return most
end

function xDTaraZ.Shop.KillerPrice(name)
    local remote = xDTaraZ.Shop.Remote("GetKillerPrice")
    local ok, price = pcall(function() return remote and remote:InvokeServer(name) end)
    return ok and tonumber(price) or nil
end

function xDTaraZ.Shop.Step()
    local opts = xDTaraZ.Options
    if not (opts.AutoBuyPerks or opts.AutoLevelPerks) then
        xDTaraZ.Shop.Status = "Off"
        xDTaraZ.Shop.LastWallet = nil
        return
    end
    local wallet = table.concat({ xDTaraZ.Shop.Wallet() }, "/")
    if wallet == xDTaraZ.Shop.LastWallet then return end
    xDTaraZ.Shop.LastWallet = wallet
    if opts.AutoBuyPerks then xDTaraZ.Shop.Locked(xDTaraZ.Shop.BuyPerks) end
    if opts.AutoLevelPerks then xDTaraZ.Shop.Locked(xDTaraZ.Shop.LevelPerks) end
    local screws, gears = xDTaraZ.Shop.Wallet()
    xDTaraZ.Shop.Status = ("bought %d · leveled %d · %d screws · %d gears"):format(xDTaraZ.Shop.Bought, xDTaraZ.Shop.Leveled, screws, gears)
end

xDTaraZ.UI = { Labels = {}, FarmSaved = nil }
local Library, T

function xDTaraZ.UI.Detach(fn)
    return function(...)
        local packed = table.pack(...)
        task.defer(function()
            local ok, err = pcall(fn, table.unpack(packed, 1, packed.n))
            if not ok then warn("[ViolenceDistrict] ui: " .. tostring(err)) end
        end)
    end
end


function xDTaraZ.UI.List(read, ...)
    local ok, list = pcall(read, ...)
    return ok and type(list) == "table" and list or {}
end


function xDTaraZ.UI.Guard(widget, allow, refusal)
    local function Refuse()
        Library:Notify(refusal[1], refusal[2], 4, "Warning")
        task.defer(widget.SetValue, widget, refusal[3])
    end

    if type(widget.AddGuard) == "function" then
        widget:AddGuard(function(value)
            if allow(value) then return true end
            Refuse()
            return false
        end)
        return widget
    end

    widget:OnChanged(function(value)
        if not allow(value) then Refuse() end
    end)
    return widget
end


function xDTaraZ.UI.NeedCap(idx, cap)
    if Library.Compat then
        Library.Compat.NeedCap(idx, cap)
        return
    end
    local toggle = Library.Toggles[idx]
    if not toggle then return end
    local title = toggle.Info and toggle.Info.Text or "LelHub"
    xDTaraZ.UI.Guard(toggle, function(value)
        return value ~= true or Util.Can(cap)
    end, { title, T("Not supported on this executor", "ใช้กับ executor นี้ไม่ได้"), false })
end


function xDTaraZ.UI.GuardRole(role)
    return xDTaraZ.UI.Guard(role, function(value)
        return value == "Any" or xDTaraZ.Role.Supported()
    end, { "LelHub", T("Role choice is not supported on this executor", "เลือกบทบาทใช้กับ executor นี้ไม่ได้"), "Any" })
end


function xDTaraZ.UI.Bind(widget, key)
    xDTaraZ.Options[key] = widget.Value
    widget:OnChanged(function(value) xDTaraZ.Options[key] = value end)
    return widget
end

function xDTaraZ.UI.BuildMain(window)
    window:AddTabSection(T("Main", "หลัก"))
    local tab = window:AddTab(T("Main", "หลัก"), "mushroom", T("Status and links", "สถานะและลิงก์"))

    local farm = tab:AddLeftGroupbox(T("Auto Farm", "ฟาร์มอัตโนมัติ"), "star")
    farm:AddToggle("AutoFarm", { Text = T("Auto Farm", "ฟาร์มอัตโนมัติ"), Description = T("Plays both roles for you: repairs, escapes, hunts and hooks", "เล่นให้ทั้งสองฝั่ง ซ่อม หนี ล่า แขวน"), Risky = true, Callback = xDTaraZ.UI.Detach(xDTaraZ.UI.SetFarm) }):AddKeyPicker("AutoFarmKey", { Default = "None", Mode = "Toggle" })
    xDTaraZ.UI.GuardRole(farm:AddDropdown("RoleMode", { Text = T("Role", "บทบาท"), Description = T("Survivor only never gets killer; Prefer killer keeps you in the killer pool", "Survivor only ไม่ถูกสุ่มเป็นฆาตกร / Prefer killer อยู่ในกลุ่มสุ่มฆาตกรเสมอ"), Values = { "Any", "Survivor only", "Prefer killer" }, Default = "Any" }))
    farm:AddSlider("FarmEscapeAfter", { Text = T("Survivor: escape after", "ผู้รอด: หนีหลัง"), Description = T("0 = never escape, stay and farm the whole round", "0 = ไม่หนี อยู่ฟาร์มจนจบรอบ"), Min = 0, Max = 900, Default = 0, Suffix = "s" })

    local status = tab:AddLeftGroupbox(T("Round", "รอบนี้"), "star")
    local labels = xDTaraZ.UI.Labels
    labels.Role = status:AddParagraph({ Title = T("Role", "บทบาท"), Content = "-" })
    labels.Survivor = status:AddParagraph({ Title = T("Survivor", "ผู้รอดชีวิต"), Content = "-" })
    labels.Killer = status:AddParagraph({ Title = T("Killer", "ฆาตกร"), Content = "-" })


    local logBox = tab:AddRightGroupbox(T("Update Log", "อัปเดตล่าสุด"), "bell")
    for i = 1, math.min(2, #xDTaraZ.Config.UpdateLog) do
        local entry = xDTaraZ.Config.UpdateLog[i]
        logBox:AddParagraph({ Title = entry[1], Content = entry[2] })
    end

    local panic = tab:AddRightGroupbox(T("Quick", "ด่วน"), "bomb")
    panic:AddButton({ Text = T("Panic — all off", "ฉุกเฉิน ปิดทั้งหมด"), Style = "Danger", Func = xDTaraZ.UI.Detach(function()
        xDTaraZ.UI.FarmSaved = nil
        for _, toggle in pairs(Library.Toggles) do
            if toggle.Value == true then toggle:SetValue(false) end
        end
    end) })

    local activity = tab:AddRightGroupbox(T("Activity", "กิจกรรม"), "eye")
    labels.Esp = activity:AddParagraph({ Title = T("ESP", "ESP"), Content = "-" })
    labels.Shop = activity:AddParagraph({ Title = T("Shop", "ร้านค้า"), Content = "-" })
end

xDTaraZ.UI.FarmKeys = {
    "AutoRepair", "PerfectSkillCheck", "AutoHeal", "AutoUnhook", "AutoDodge", "AutoSelfUnhook", "InstantEscape", "NoSlow",
    "KillAura", "AutoHook", "AutoBreakGens", "AntiStun", "AntiAfk",
}

function xDTaraZ.UI.SetFarm(on)
    local options = Library.Options
    local tuned = { EscapeDelay = options.FarmEscapeAfter.Value, DodgeRadius = xDTaraZ.Config.FarmDodge }
    if on then
        if xDTaraZ.UI.FarmSaved then return end
        xDTaraZ.UI.FarmSaved = {}
        for key in pairs(tuned) do xDTaraZ.UI.FarmSaved[key] = options[key].Value end
        for _, key in ipairs(xDTaraZ.UI.FarmKeys) do xDTaraZ.UI.FarmSaved[key] = options[key].Value end
        for key, value in pairs(tuned) do options[key]:SetValue(value) end
        for _, key in ipairs(xDTaraZ.UI.FarmKeys) do options[key]:SetValue(true) end
        if options.FarmEscapeAfter.Value <= 0 then options.InstantEscape:SetValue(false) end
        return
    end
    local saved = xDTaraZ.UI.FarmSaved
    xDTaraZ.UI.FarmSaved = nil
    if not saved then return end
    for key, value in pairs(saved) do
        if options[key] then options[key]:SetValue(value) end
    end
end

function xDTaraZ.UI.BuildSurvivor(window)
    window:AddTabSection(T("Roles", "บทบาท"))
    local tab = window:AddTab(T("Survivor", "ผู้รอดชีวิต"), "heart", T("Generators, team and escape", "เครื่องปั่นไฟ ทีม และการหนี"))

    local work = tab:AddLeftGroupbox(T("Objectives", "ภารกิจ"), "gear")
    work:AddToggle("AutoRepair", { Text = T("Auto repair", "ซ่อมอัตโนมัติ"), Description = T("Repairs the best generator hands-free", "ซ่อมเครื่องที่ดีที่สุดให้เอง"), Risky = true })
    work:AddToggle("PerfectSkillCheck", { Text = T("Auto Skill Check", "สกิลเช็คอัตโนมัติ") })
    work:AddToggle("AutoHeal", { Text = T("Auto heal teammates", "รักษาเพื่อนอัตโนมัติ"), Risky = true })
    work:AddToggle("AutoUnhook", { Text = T("Auto unhook teammates", "ปลดเพื่อนจากตะขอ"), Risky = true })

    local escape = tab:AddLeftGroupbox(T("Escape", "หนี"), "flag")
    escape:AddToggle("InstantEscape", { Text = T("Instant escape", "หนีออกทันที"), Description = T("Leaves the round without repairing anything", "ออกจากรอบโดยไม่ต้องซ่อม"), Risky = true })
    escape:AddSlider("EscapeDelay", { Text = T("Escape after", "หนีหลังเริ่มรอบ"), Min = 0, Max = 900, Default = 0, Suffix = "s" })
    escape:AddButton({ Text = T("Escape Now", "หนีออกตอนนี้"), Style = "Warning", Func = xDTaraZ.UI.Detach(function()
        if not xDTaraZ.Survivor.EscapeNow() then
            Library:Notify(T("Escape", "หนี"), T("No exit found this round", "ไม่พบทางออกในรอบนี้"), 3, "Warning")
        end
    end) })

    local safety = tab:AddRightGroupbox(T("Safety", "ความปลอดภัย"), "boo")
    safety:AddToggle("AutoDodge", { Text = T("Auto dodge killer", "หลบฆาตกรอัตโนมัติ"), Description = T("Teleports away when the killer gets close and keeps other jobs away from him", "วาร์ปหนีเมื่อฆาตกรเข้าใกล้ และไม่ไปทำงานใกล้ฆาตกร"), Risky = true })
    safety:AddSlider("DodgeRadius", { Text = T("Dodge distance", "ระยะหลบ"), Min = 6, Max = 40, Default = 20, Suffix = "m" })
    safety:AddToggle("AutoSelfUnhook", { Text = T("Auto self-unhook", "ปลดตัวเองจากตะขอ"), Risky = true })
    safety:AddToggle("AutoParry", { Text = T("Auto parry (beta)", "ปัดป้องอัตโนมัติ (beta)"), Description = T("Needs the Parrying Dagger equipped", "ต้องใส่ Parrying Dagger") })
    safety:AddToggle("NoParryCooldown", { Text = T("No parry cooldown (beta)", "ปัดป้องไม่มีคูลดาวน์ (beta)") })
    xDTaraZ.UI.NeedCap("NoParryCooldown", "Gc")
    safety:AddToggle("KillerAlert", { Text = T("Killer alert", "เตือนฆาตกรเข้าใกล้") })
    safety:AddButton({ Text = T("Sacrifice Self", "สละชีพตัวเอง"), Style = "Danger", Func = xDTaraZ.UI.Detach(function()
        if not xDTaraZ.Survivor.Sacrifice() then
            Library:Notify(T("Sacrifice", "สละชีพ"), T("Only works as a survivor", "ใช้ได้ตอนเป็นผู้รอดเท่านั้น"), 3, "Warning")
        end
    end) })
end

function xDTaraZ.UI.BuildKiller(window)
    local tab = window:AddTab(T("Killer", "ฆาตกร"), "swords", T("Hunting and hooking", "ล่าและแขวน"))

    local hunt = tab:AddLeftGroupbox(T("Hunt", "ล่า"), "target")
    hunt:AddToggle("KillAura", { Text = T("Auto slash", "ฟันอัตโนมัติ"), Description = T("Rage jumps behind anyone in range, Legit only swings at whoever is in front of you", "Rage วาร์ปไปฟันทุกคนในระยะ / Legit ฟันเฉพาะคนตรงหน้า"), Risky = true }):AddKeyPicker("KillAuraKey", { Default = "None", Mode = "Toggle" })
    hunt:AddToggle("SmartHitbox", { Text = T("Reach Assist", "ช่วยเพิ่มระยะฟัน"), Description = T("Legit swings still land on targets a few studs out of reach", "โหมด Legit ฟันโดนแม้เป้าอยู่เกินระยะนิดหน่อย"), Risky = true })
    hunt:AddDropdown("SlashMode", { Text = T("Slash mode", "โหมดฟัน"), Values = { "Rage", "Legit" }, Default = "Rage" })
    hunt:AddSlider("AuraRange", { Text = T("Range", "ระยะ"), Min = 10, Max = 500, Default = 500, Suffix = "m" })

    local chores = tab:AddRightGroupbox(T("Hooks & Generators", "ตะขอและเครื่องปั่นไฟ"), "gear")
    chores:AddToggle("AutoHook", { Text = T("Auto carry + hook", "แบกและแขวนอัตโนมัติ"), Description = T("Picks up anyone downed and hooks them", "แบกคนล้มแล้วแขวนตะขอให้"), Risky = true })
    chores:AddToggle("AutoBreakGens", { Text = T("Auto kick generators", "เตะเครื่องปั่นไฟอัตโนมัติ"), Description = T("Kicks the most repaired generator when nobody is in range", "เตะเครื่องที่ซ่อมไปเยอะสุดตอนไม่มีเป้า"), Risky = true })

    local defense = tab:AddRightGroupbox(T("Defense", "ป้องกัน"), "shield")
    defense:AddToggle("AntiStun", { Text = T("Anti pallet stun (beta)", "กันพาเลทสตัน (beta)") })
    xDTaraZ.UI.NeedCap("AntiStun", "Connections")
    defense:AddToggle("AntiBlind", { Text = T("Anti blind (beta)", "กันแสงไฟฉาย (beta)"), Description = T("Flashlights no longer blind you", "ไม่โดนไฟฉายแยงตา") })
    xDTaraZ.UI.NeedCap("AntiBlind", "Connections")
    defense:AddToggle("FreeTurn", { Text = T("No turn limit", "หมุนตัวได้อิสระ"), Description = T("Keep turning while attacking or lunging", "หันตัวได้ตอนฟันและพุ่ง") })
end

function xDTaraZ.UI.BuildPlayer(window)
    window:AddTabSection(T("Player", "ผู้เล่น"))
    local tab = window:AddTab(T("Player", "ผู้เล่น"), "player", T("Movement, world and teleport", "การเคลื่อนที่ โลก และวาร์ป"))

    local move = tab:AddLeftGroupbox(T("Movement", "การเคลื่อนที่"), "zap")
    move:AddToggle("Speed", { Text = T("Speed", "วิ่งเร็ว"), Risky = true }):AddKeyPicker("SpeedKey", { Default = "None", Mode = "Toggle" })
    move:AddSlider("SpeedValue", { Text = T("Walk speed", "ความเร็ว"), Min = 16, Max = 60, Default = 24 })
    move:AddToggle("NoSlow", { Text = T("No slow", "ไม่โดนสโลว์"), Description = T("Never drops below your normal run speed", "ความเร็วไม่ต่ำกว่าวิ่งปกติ") })
    move:AddToggle("NoFall", { Text = T("No fall (beta)", "ไม่เซตอนตก (beta)"), Description = T("No landing stumble after a drop", "ลงพื้นแล้วไม่เซ") })
    xDTaraZ.UI.NeedCap("NoFall", "Namecall")
    move:AddToggle("Noclip", { Text = T("Noclip", "เดินทะลุ") }):AddKeyPicker("NoclipKey", { Default = "None", Mode = "Toggle" })
    move:AddToggle("InfiniteJump", { Text = T("Infinite jump", "กระโดดไม่จำกัด"), Description = T("Jump anywhere, even mid-air", "กระโดดได้ทุกที่ แม้กลางอากาศ") })

    local world = tab:AddRightGroupbox(T("World", "โลก"), "star")
    world:AddToggle("Fullbright", { Text = T("Fullbright", "สว่างทั้งแมพ") })
    world:AddToggle("AntiShake", { Text = T("Anti camera shake", "กันจอสั่น") })
    xDTaraZ.UI.NeedCap("AntiShake", "Connections")
    world:AddToggle("NoFog", { Text = T("No fog", "ไม่มีหมอก") })
    world:AddToggle("AntiAfk", { Text = T("Anti AFK", "กันหลุด AFK"), Callback = xDTaraZ.UI.Detach(xDTaraZ.Player.AntiAfk.Arm) })

    xDTaraZ.UI.BuildTeleport(tab)
end

function xDTaraZ.UI.BuildShop(window)
    local tab = window:AddTab(T("Shop", "ร้านค้า"), "shop", T("Perks, items and killers", "เพิร์ค ไอเทม ฆาตกร"))

    local perks = tab:AddLeftGroupbox(T("Perks", "เพิร์ค"), "star")
    perks:AddToggle("AutoBuyPerks", { Text = T("Auto buy perks", "ซื้อเพิร์คอัตโนมัติ"), Description = T("Unlocks every perk you can afford with Gears", "ปลดล็อกเพิร์คทุกตัวที่ Gears พอ") })
    perks:AddToggle("AutoLevelPerks", { Text = T("Auto level perks", "อัปเลเวลเพิร์คอัตโนมัติ"), Description = T("Spends Screws to level owned perks", "ใช้ Screws อัปเลเวลเพิร์คที่มี") })
    perks:AddSlider("KeepScrews", { Text = T("Keep Screws", "เก็บ Screws ไว้"), Description = T("Never spends below this", "ไม่ใช้ต่ำกว่าจำนวนนี้"), Min = 0, Max = 20000, Default = 0 })
    perks:AddButton({ Text = T("Buy + Level Now", "ซื้อ + อัปตอนนี้"), Style = "Primary", Func = xDTaraZ.UI.Detach(function()
        local bought, leveled = xDTaraZ.Shop.Locked(xDTaraZ.Shop.BuyPerks), xDTaraZ.Shop.Locked(xDTaraZ.Shop.LevelPerks)
        Library:Notify(T("Perks", "เพิร์ค"), ("Bought %d, leveled %d"):format(bought, leveled), 4, "Success")
    end) })

    local store = tab:AddRightGroupbox(T("Items & Killers", "ไอเทมและฆาตกร"), "coin")
    local items = store:AddDropdown("ShopItems", { Text = T("Items", "ไอเทม"), Values = xDTaraZ.UI.List(xDTaraZ.Shop.Names, "Items"), Multi = true, Default = {}, AllowNull = true, Searchable = true })
    store:AddButton({ Text = T("Buy Selected Items", "ซื้อไอเทมที่เลือก"), Func = xDTaraZ.UI.Detach(function()
        Library:Notify(T("Shop", "ร้านค้า"), ("Bought %d items"):format(xDTaraZ.Shop.Locked(xDTaraZ.Shop.BuyList, "Item", items.Value)), 4, "Coin")
    end) })
    local killers = store:AddDropdown("ShopKillers", { Text = T("Killers", "ฆาตกร"), Values = xDTaraZ.UI.List(xDTaraZ.Shop.Names, "Killers"), Multi = true, Default = {}, AllowNull = true, Searchable = true })
    store:AddButton({ Text = T("Buy Selected Killers", "ซื้อฆาตกรที่เลือก"), Func = xDTaraZ.UI.Detach(function()
        Library:Notify(T("Shop", "ร้านค้า"), ("Bought %d killers"):format(xDTaraZ.Shop.Locked(xDTaraZ.Shop.BuyList, "Killer", killers.Value)), 4, "Coin")
    end) })
    store:AddButton({ Text = T("Refresh lists", "รีเฟรชรายการ"), Func = xDTaraZ.UI.Detach(function()
        items:SetValues(xDTaraZ.Shop.Names("Items"))
        killers:SetValues(xDTaraZ.Shop.Names("Killers"))
    end) })
end


function xDTaraZ.UI.BuildTeleport(tab)
    local box = tab:AddRightGroupbox(T("Teleport", "วาร์ป"), "pipe")
    local places = box:AddDropdown("TeleportTarget", { Text = T("Destination", "ปลายทาง"), Values = xDTaraZ.UI.List(xDTaraZ.Teleport.Places), Default = "Nearest Generator", Searchable = true })
    box:AddButton({ Text = T("Teleport Now", "วาร์ปตอนนี้"), Style = "Primary", Func = xDTaraZ.UI.Detach(function()
        if not xDTaraZ.Teleport.Go(places.Value) then
            Library:Notify(T("Teleport", "วาร์ป"), T("Destination not found this round", "ไม่พบปลายทางในรอบนี้"), 3, "Warning")
        end
    end) }):AddButton({ Text = T("Refresh", "รีเฟรช"), Func = xDTaraZ.UI.Detach(function()
        places:SetValues(xDTaraZ.Teleport.Places())
    end) })
end

function xDTaraZ.UI.BuildVisuals(window)
    window:AddTabSection(T("Visuals", "การมองเห็น"))
    local tab = window:AddVisualsTab({ Provider = xDTaraZ.Esp.Targets, Preview = true })
    local objects = tab:AddLeftGroupbox(T("Objects", "วัตถุ"), "eye")
    objects:AddToggle("EspGenerators", { Text = T("Generators + progress", "เครื่องปั่นไฟ + ความคืบหน้า") })
    objects:AddToggle("EspHooks", { Text = T("Hooks", "ตะขอ") })
    objects:AddToggle("EspGates", { Text = T("Exit gates", "ประตูทางออก") })
    objects:AddToggle("EspPallets", { Text = T("Pallets", "พาเลท") })
    objects:AddToggle("EspWindows", { Text = T("Windows", "หน้าต่าง") })
end

function xDTaraZ.UI.RefreshStatus()
    local labels = xDTaraZ.UI.Labels
    if not (labels.Role and labels.Survivor and labels.Killer and labels.Esp and labels.Shop) then return end
    local dist = xDTaraZ.Alert.Distance
    labels.Role:SetContent((xDTaraZ.Player.Role() or "-") .. " · gens left " .. xDTaraZ.Map.GensLeft() .. (dist and (" · killer %dm"):format(dist) or ""))
    labels.Survivor:SetContent(("%s · checks %d · dodges %d · escapes %d"):format(xDTaraZ.Survivor.Status, xDTaraZ.SkillCheck.Checks, xDTaraZ.Guard.Dodges, xDTaraZ.Survivor.Escapes))
    labels.Killer:SetContent(xDTaraZ.Killer.Status .. " · stuns dodged " .. xDTaraZ.AntiStun.Count)
    labels.Esp:SetContent(xDTaraZ.Esp.GetStatus())
    labels.Shop:SetContent(xDTaraZ.Shop.Status)
end


function xDTaraZ.UI.DrainHalts()
    local halts = xDTaraZ.Scheduler.Halts
    if not halts[1] then return end
    xDTaraZ.Scheduler.Halts = {}
    for _, halt in ipairs(halts) do
        Util.Try("halt", function()
            for _, idx in ipairs(halt.Toggles) do
                local toggle = Library.Toggles[idx]
                if toggle and toggle.Value then toggle:SetValue(false) end
            end
            Library:Notify("Violence District", halt.Message, 6, "Warning")
        end)
    end
end

function xDTaraZ.UI.Pump()
    xDTaraZ.UI.DrainHalts()
    xDTaraZ.UI.RefreshStatus()
end

function xDTaraZ.UI.Build()
    local window = Library.Window
    for _, section in ipairs({ "BuildMain", "BuildSurvivor", "BuildKiller", "BuildPlayer", "BuildShop", "BuildVisuals" }) do
        Util.Try("ui " .. section, xDTaraZ.UI[section], window)
    end
    window:AddTabSection(T("Other", "อื่นๆ"))
    Util.Try("ui settings", window.AddSettingsTab, window)

    for key in pairs(xDTaraZ.Options) do
        local widget = Library.Options[key] or Library.Toggles[key]
        if widget then xDTaraZ.UI.Bind(widget, key) end
    end
    Util.Try("ui gate", xDTaraZ.UI.GateRemotes)
end


function xDTaraZ.UI.GateRemotes()
    if not Library.Compat then return end
    local reason = T("Not found after a game update", "หาไม่เจอหลังเกมอัปเดต")
    for idx in pairs(GameLib.Needs) do
        local missing = GameLib.Missing(idx)
        if missing and Library.Toggles[idx] then
            Library.Compat.Block(idx, reason)
            warn("[ViolenceDistrict] " .. idx .. " off, missing remote " .. missing)
        end
    end
end


local function BuildInterface()
    Library = Util.LoadLibrary()
    if not Library then return false end

    xDTaraZ.Library = Library
    T = function(en, th) return Library:T(en, th) end
    Library:CreateWindow({
        Title = lelHubTitle("LelHub Violence District"),
        SubTitle = "by LelSploit",
        MenuKey = Enum.KeyCode.RightShift,
        ConfigFolder = xDTaraZ.Config.SaveFolder,
        Language = "Auto",
        Theme = "Overworld",
        Intro = xDTaraZ.Config.Intro,
        OnUnlocked = function()
            xDTaraZ.UI.Build()
            task.defer(Util.Try, "boot", xDTaraZ.Boot)
            Library:Every(xDTaraZ.Config.StatusInterval, xDTaraZ.UI.Pump)
            task.defer(Util.Try, "autoload", Library.LoadAutoloadConfig, Library)
        end,
    })
    Library:OnUnload(function()
        xDTaraZ:Unload()
    end)
    return true
end

function xDTaraZ.Boot()
    xDTaraZ:Connect(LocalPlayer.CharacterAdded, function(character)
        xDTaraZ.Survivor.Job = nil
        xDTaraZ.Movement.Release()
        xDTaraZ.Player:Bind(character)
    end)

    xDTaraZ.Movement.Start()
    xDTaraZ.SkillCheck.Start()
    xDTaraZ.AntiStun.Start()

    xDTaraZ.Scheduler.Every("Survivor", xDTaraZ.Config.RepairTick, xDTaraZ.Survivor.Step, { "AutoRepair", "AutoHeal", "AutoUnhook", "InstantEscape" }, { Core = true, Restore = xDTaraZ.Survivor.Finish })
    xDTaraZ.Scheduler.Every("Guard", xDTaraZ.Config.GuardTick, xDTaraZ.Guard.Step, { "AutoDodge", "AutoSelfUnhook" })
    xDTaraZ.Scheduler.Every("Block", 1, xDTaraZ.Block.Step, { "PerfectSkillCheck", "AntiStun", "AntiBlind", "AntiShake", "NoFall" }, { Restore = xDTaraZ.Block.Release })
    xDTaraZ.Scheduler.Every("Parry", xDTaraZ.Config.GuardTick, xDTaraZ.Parry.Step, { "AutoParry", "NoParryCooldown" })
    xDTaraZ.Scheduler.Every("Killer", 0.1, xDTaraZ.Killer.Step, { "KillAura", "AutoHook", "AutoBreakGens" })
    xDTaraZ.Scheduler.Every("World", 0.5, xDTaraZ.World.Step, { "Fullbright", "NoFog" }, { Restore = xDTaraZ.World.Restore })
    xDTaraZ.Scheduler.Every("Role", 3, xDTaraZ.Role.Step)
    xDTaraZ.Scheduler.Every("Alert", 0.5, xDTaraZ.Alert.Step, { "KillerAlert" }, { Core = true })
    xDTaraZ.Scheduler.Every("Shop", xDTaraZ.Config.ShopInterval, xDTaraZ.Shop.Step, { "AutoBuyPerks", "AutoLevelPerks" })
    xDTaraZ.Scheduler.Every("ObjectEsp", xDTaraZ.Config.ObjectEspRefresh, xDTaraZ.Esp.Step, { "EspGenerators", "EspHooks", "EspGates", "EspPallets", "EspWindows" }, { Core = true })
    xDTaraZ.Scheduler.Boot()
end

function xDTaraZ:Unload()
    self.State.Alive = false
    if environment.ViolenceDistrictUnload == self.UnloadFn then environment.ViolenceDistrictUnload = nil end
    table.clear(xDTaraZ.Scheduler.Jobs)
    xDTaraZ.Survivor.Finish()
    xDTaraZ.Block.Release()
    xDTaraZ.Movement.Release()
    xDTaraZ.World.Restore()
    xDTaraZ.Esp.Clear()
    for _, connection in ipairs(self.State.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.State.Connections)
end

xDTaraZ.UnloadFn = function()
    if xDTaraZ.Library and not xDTaraZ.Library.Unloaded then
        xDTaraZ.Library:Unload()
    else
        xDTaraZ:Unload()
    end
end
environment.ViolenceDistrictUnload = xDTaraZ.UnloadFn

if LocalPlayer.Character then
    xDTaraZ.Player:Bind(LocalPlayer.Character)
end


if BuildInterface() then


end
