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
                warn("[LelHub Anti-idle] " .. tostring(message))
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
            warn("[LelHub Vehicles] " .. message)
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

    local function paragraph(parent, id, title, content)
        return invoke(parent, "Paragraph", id, { Title = title, Content = content })
    end

    local function apply(id, value)
        if not building and not context.Destroying then
            local success, message = xpcall(function()
                callbacks[id](value)
            end, describeError)

            if not success then
                warn("[LelHub] " .. message)
                context.Notify("That control could not be applied. Details are in the console.")
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
            Description = description,
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
            Description = description,
            Callback = function()
                local success, result, message = xpcall(callback, describeError)

                if not success then
                    warn("[LelHub] " .. tostring(result))
                    context.Notify("The action could not finish. Details are in the console.")
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
    paragraph(playerTab, "Welcome", "LelHub Global", "Universal controls by lelsploit. Right Shift opens or hides the menu. Changes stay active after respawning.")

    local movement = section(playerTab, "Movement")

    for _, configuration in ipairs({
        { "WalkSpeed", "Walk speed", 0, 500 },
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

    local status = paragraph(vehicleTab, "VehicleStatus", "Vehicle status", "Sit in a vehicle to use these controls.")
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
    paragraph(driving, "DrivingHelp", "Driving controls", "Acceleration adds horizontal speed while its key is held. Brake slows horizontal speed. Values use thousandths, matching Universal Car Speed Changer.")
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

    local interfaceSection = section(settingsTab, "Interface")
    dropdown(interfaceSection, "Theme", "Theme", library.Themes or { "Dark", "Darker", "Light" }, library.Theme or "Dark", function(value)
        library:SetTheme(value)
    end)
    local menuKey = keybind(interfaceSection, "MenuKey", "Open / hide menu key", "RightShift", function(value)
        library.MinimizeKey = Enum.KeyCode[value]
    end)
    library.MinimizeKeybind = menuKey
    paragraph(interfaceSection, "Credits", "LelHub Global • by lelsploit", "UI: Fluent Renewed. Vehicle physics flight uses the Infinite Yield approach. Universal vehicle controls adapted from Universal Car Speed Changer.\nInfinite Yield: github.com/EdgeIY/infiniteyield (MIT).")
    paragraph(interfaceSection, "Compatibility", "Session information", "Place: " .. tostring(game.PlaceId) .. "\nExperience: " .. tostring(game.GameId) .. "\nVehicle controls require a seated vehicle you can simulate locally.")

    local profilePath = "LelHub/global-profile.json"
    button(interfaceSection, "Save settings", function()
        if not writefile or not makefolder or not isfolder then
            return false, "This environment cannot save settings files."
        end

        if not isfolder("LelHub") then
            makefolder("LelHub")
        end

        writefile(profilePath, context.HttpService:JSONEncode(settings))
        return true, "Global settings saved."
    end)
    button(interfaceSection, "Load saved settings", function()
        if not readfile or not isfile or not isfile(profilePath) then
            return false, "No saved global settings were found."
        end

        local data = context.HttpService:JSONDecode(readfile(profilePath))
        assert(type(data) == "table", "Saved settings are invalid")

        for id, value in pairs(data) do
            if controls[id] and id ~= "SelectedPlayer" and type(value) == type(defaults[id]) then
                if id:match("Key$") then
                    if parseKeyCode(value) then
                        controls[id]:SetValue(value, "Hold")
                        settings[id] = value
                        callbacks[id](value)
                    end
                else
                    controls[id]:SetValue(value)
                end
            end
        end

        return true, "Saved global settings loaded."
    end)
    button(interfaceSection, "Unload LelHub Global", function()
        hub.Cleanup()
    end, "Restores movement, camera, collisions, lighting and springs; removes flight and ESP.")

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

    local menuButton = overlayButton("LelHub", UDim2.new(1, -16, 1, -18))
    lifetime:Connect(menuButton.Activated, function()
        window:Minimize()
    end)
    local stopButton = overlayButton("Stop camera", UDim2.new(1, -128, 1, -18), 120)
    stopButton.Visible = false
    cameraControls.OnChanged = function(mode)
        stopButton.Visible = mode ~= "None"
    end
    lifetime:Connect(stopButton.Activated, function()
        cameraControls:Stop()
    end)

    if context.Input.TouchEnabled then
        local upButton = overlayButton("Rise", UDim2.new(1, -16, 1, -70), 70)
        local downButton = overlayButton("Descend", UDim2.new(1, -16, 1, -114), 70)
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

    local elapsed = 0
    lifetime:Connect(context.RunService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime

        if elapsed >= 0.25 then
            elapsed = 0
            local description = vehicles.Model and vehicles.Model.Name .. " • " .. math.floor(vehicles.Speed + 0.5) .. " studs/s"
                or "Sit in a vehicle to use these controls."
            status:SetValue(description)
        end
    end)

    building = false
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
                warn("[LelHub cleanup] " .. tostring(message))
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
            SubTitle = "by lelsploit",
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
