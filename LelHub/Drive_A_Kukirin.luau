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

local function normalizeText(value)
    return tostring(value):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function normalizeName(value)
    return tostring(value):gsub("[^%w]", ""):lower()
end

local function findNamed(parent, name)
    if not parent then
        return nil
    end

    local directChild = parent:FindFirstChild(name)

    if directChild then
        return directChild
    end

    local expectedName = normalizeName(name)

    for _, descendant in ipairs(parent:GetDescendants()) do
        if normalizeName(descendant.Name) == expectedName then
            return descendant
        end
    end

    return nil
end

local function findPath(parent, ...)
    for _, name in ipairs({ ... }) do
        parent = parent and parent:FindFirstChild(name)
    end

    return parent
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

local function ownerMatches(player, owner)
    if not owner or not owner.Parent then
        return false
    end

    local success, value = pcall(function()
        return owner.Value
    end)

    if not success and (owner:IsA("TextLabel") or owner:IsA("TextBox") or owner:IsA("TextButton")) then
        value = owner.Text
        success = true
    end

    if not success or value == nil then
        return false
    end

    if typeof(value) == "Instance" then
        return value == player or value == player.Character
    end

    if type(value) == "string" then
        return normalizeText(value) == normalizeText(player.Name)
    end

    return type(value) == "number" and value == player.UserId
end

local function ownsScooter(player, scooter)
    return ownerMatches(player, scooter:FindFirstChild("ScooterOwner"))
        or scooter:GetAttribute("OwnerUserId") == player.UserId
end

local function findOwnedScooter(context)
    for _, object in ipairs(context.Workspace:GetChildren()) do
        if object:IsA("Model") and ownsScooter(context.Player, object) then
            return object
        end
    end

    return nil
end

local function findMountedScooter(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local weld = root and root:FindFirstChild("ScooterMountWeld")
    local mountedPart = weld and weld.Part0
    local scooter = mountedPart and mountedPart:FindFirstAncestorOfClass("Model")

    return scooter, root, weld
end

local function findDriveBody(scooter)
    if not scooter then
        return nil
    end

    return scooter:FindFirstChild(scooter:GetAttribute("DriveRootName") or "Body")
end

local function scooterRemote(context, name)
    return findPath(context.ReplicatedStorage, "ScooterRemotes", name)
end

local function sendScooterInput(context, steer, dismount)
    local remote = scooterRemote(context, "ScooterInput")

    if remote then
        remote:FireServer({
            throttle = dismount and 0 or 1,
            brake = 0,
            steer = steer or 0,
            wheelie = dismount and 0 or 1,
            dismount = dismount or false,
            stamp = os.clock(),
        })
    end
end

local function prepareMountPrompt(scooter)
    if not scooter then
        return nil
    end

    local fallback

    for _, descendant in ipairs(scooter:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            fallback = fallback or descendant

            if descendant.Name:lower():find("mount", 1, true) then
                fallback = descendant
                break
            end
        end
    end

    if fallback then
        fallback.Enabled = true
        fallback.HoldDuration = 0
        fallback.MaxActivationDistance = math.huge
        fallback.RequiresLineOfSight = false
    end

    return fallback
end

local function calculateTopSpeed(context, scooterName)
    local template = findPath(context.ReplicatedStorage, "Scooters", scooterName)

    if not template then
        return 50
    end

    local baseSpeed = finiteNumber(template:GetAttribute("TopSpeedKmh"), 50)
    local motorWatts = finiteNumber(template:GetAttribute("MotorWatts"), 0)
    local upgrades = {}
    local attributeName = "ScooterCustom_" .. scooterName:gsub("[^%w]", "_")
    local encoded = context.Player:GetAttribute(attributeName)

    if type(encoded) == "string" and encoded ~= "" then
        local success, decoded = pcall(function()
            return context.HttpService:JSONDecode(encoded)
        end)

        if success and type(decoded) == "table" and type(decoded.u) == "table" then
            upgrades = decoded.u
        end
    end

    local speed = baseSpeed

    if upgrades.VescController == true then
        speed = speed + 5
    end

    if upgrades.WeightReduction == true then
        speed = speed + 3
    end

    if upgrades.DualMotor == true and template:GetAttribute("DualMotor") ~= true then
        speed = speed + math.floor(baseSpeed * 0.15 + 0.5)
    end

    if upgrades.BatteryUpgrade == true and motorWatts > 0 then
        local powerRatio = (motorWatts + 1000) / motorWatts
        speed = speed + math.min(8, math.floor(baseSpeed * (powerRatio ^ (1 / 3) - 1) + 0.5))
    end

    if upgrades.BatteryUpgradeXL == true then
        speed = speed + 5
    end

    return speed
end

local function calculateFarmSteering(body, center, topSpeed)
    local velocity = body.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude / 1.56
    local speedFraction = math.clamp(speed / math.max(1, topSpeed), 0, 1)
    local look = body.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)

    if forward.Magnitude < 0.01 then
        forward = Vector3.new(0, 0, -1)
    else
        forward = forward.Unit
    end

    local offset = Vector3.new(body.Position.X - center.X, 0, body.Position.Z - center.Z)
    local distance = offset.Magnitude
    local steer = 0

    if distance > 1 then
        local radial = offset / distance
        local tangent = Vector3.new(-radial.Z, 0, radial.X)
        local correction = math.clamp(-(distance - 4) * 0.24, -0.9, 0.9)
        local desired = tangent + radial * correction

        if desired.Magnitude > 0.01 then
            desired = desired.Unit
            local angle = math.atan2(forward:Cross(desired).Y, forward:Dot(desired))
            steer = -math.clamp(angle * 2.8, -1, 1)
        end
    end

    local steeringLimit = 0.95 - speedFraction * 0.35
    local pitch = math.abs(math.deg(math.asin(math.clamp(look.Y, -1, 1))))

    if pitch > 22 then
        steeringLimit = steeringLimit * (1 - math.clamp((pitch - 22) / 40, 0, 1) * 0.5)
    end

    local right = body.CFrame.RightVector
    local roll = math.abs(math.deg(math.asin(math.clamp(right.Y, -1, 1))))

    if roll > 25 then
        steeringLimit = steeringLimit * (1 - math.clamp((roll - 25) / 25, 0, 1))
    end

    steeringLimit = math.clamp(steeringLimit, 0.1, 0.95)

    if math.abs(steer) > steeringLimit then
        steer = math.sign(steer) * steeringLimit
    end

    return steer
end

local function ensureDirectory(path)
    assert(makefolder and isfolder, "This executor does not support configuration folders")
    local current = ""

    for segment in path:gmatch("[^/]+") do
        current = current == "" and segment or current .. "/" .. segment

        if not isfolder(current) then
            makefolder(current)
        end
    end
end

local function createConfigurationManager(context, interface)
    local manager = {
        Path = "WindUI/DriveAKukirin/config/",
        Configs = {},
    }

    function manager:AllConfigs()
        if not listfiles then
            return {}
        end

        ensureDirectory(self.Path)
        local names = {}

        for _, path in ipairs(listfiles(self.Path)) do
            local name = path:match("([^/\\]+)%.json$")

            if name then
                table.insert(names, name)
            end
        end

        table.sort(names)
        return names
    end

    function manager:CreateConfig(name)
        assert(type(name) == "string" and name ~= "" and not name:find("[/\\]"), "Invalid configuration name")

        if self.Configs[name] then
            return self.Configs[name]
        end

        local configuration = {
            Path = self.Path .. name .. ".json",
            CustomData = {},
            AutoLoad = false,
        }

        function configuration:Set(key, value)
            self.CustomData[key] = value
        end

        function configuration:Get(key)
            return self.CustomData[key]
        end

        function configuration:Save()
            assert(writefile, "This executor does not support saving configurations")
            ensureDirectory(manager.Path)

            local data = {
                __version = 1.2,
                __elements = {},
                __custom = self.CustomData,
                __autoload = self.AutoLoad,
            }

            for flag, control in pairs(interface.Options) do
                data.__elements[flag] = {
                    __type = control.Type,
                    value = control.Type == "Slider" and control.Value.Default or control.Value,
                }
            end

            writefile(self.Path, context.HttpService:JSONEncode(data))
            return data
        end

        function configuration:Load()
            assert(readfile and isfile and isfile(self.Path), "Configuration file does not exist")
            local data = context.HttpService:JSONDecode(readfile(self.Path))

            for flag, stored in pairs(data.__elements or data) do
                local control = interface.Options[flag]

                if control and type(stored) == "table" then
                    control:Set(stored.value)
                end
            end

            self.CustomData = data.__custom or {}
            self.AutoLoad = data.__autoload or false
            return self.CustomData
        end

        function configuration:Delete()
            assert(delfile, "This executor does not support deleting configurations")
            delfile(self.Path)
            manager.Configs[name] = nil
            return true
        end

        self.Configs[name] = configuration
        return configuration
    end

    return manager
end

local function createInterface(context)
    local libraryUrl = "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"
    local library = loadstring(game:HttpGetAsync(libraryUrl))()
    local window = library:CreateWindow({
        Title = "Lelsploit hub",
        SubTitle = "by lelsploit",
        TabWidth = 160,
        Size = UDim2.fromOffset(530, 325),
        Resize = true,
        MinSize = Vector2.new(470, 380),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.Q,
    })

    local interface = {
        Library = library,
        Window = window,
        Options = {},
        Tabs = {},
        Building = true,
    }

    interface.ConfigManager = createConfigurationManager(context, interface)
    window.ConfigManager = interface.ConfigManager

    function interface:Notify(configuration)
        return library:Notify({
            Title = configuration.Title or "Lelsploit hub",
            Content = configuration.Content or configuration.Desc or "",
            Duration = configuration.Duration or 5,
        })
    end

    function interface:AddTab(title, icon)
        local tab = window:CreateTab({ Title = title, Icon = icon })
        self.Tabs[title] = tab
        return tab
    end

    function interface:AddSlider(section, configuration, callback)
        local minimum = configuration.Minimum
        local maximum = configuration.Maximum
        local default = configuration.Default
        local step = configuration.Step or 1
        local integerOnly = configuration.Flag == "Speed_Multiplier"
        local decimals = math.max(0, math.ceil(-math.log10(step)))
        local raw = section:CreateSlider(configuration.Flag, {
            Title = configuration.Title,
            Min = minimum,
            Max = maximum,
            Default = default,
            Rounding = decimals,
        })

        local control = {
            Raw = raw,
            Type = "Slider",
            __type = "Slider",
            Value = { Min = minimum, Max = maximum, Default = default },
        }

        local nativeSetValue = raw.SetValue
        local numberBox = raw.Instance.Frame:FindFirstChildWhichIsA("TextBox", true)

        function raw:SetValue(value)
            local number = finiteNumber(value, nil)

            if not number then
                if numberBox then
                    numberBox.Text = tostring(control.Value.Default)
                end

                return false
            end

            number = math.max(minimum, number)

            if integerOnly then
                number = math.floor(number + 0.5)
            end

            nativeSetValue(self, math.clamp(number, minimum, maximum))
            rawset(self, "Value", number)
            control.Value.Default = number

            if numberBox then
                numberBox.Text = tostring(number)
            end

            if not interface.Building then
                callback(number)
            end

            return true
        end

        function control:Set(value)
            return raw:SetValue(value)
        end

        function control:SetTitle(value)
            raw:SetTitle(value)
        end

        function control:SetDesc(value)
            raw:SetDesc(value)
        end

        function control:Destroy()
            raw:Destroy()
        end

        control.SetValue = control.Set
        self.Options[configuration.Flag] = control
        control:Set(default)
        return control
    end

    function interface:AddToggle(section, title, flag, callback)
        local raw = section:CreateToggle(flag, { Title = title, Default = false })
        local control = {
            Raw = raw,
            Type = "Toggle",
            __type = "Toggle",
            Value = false,
        }

        raw:OnChanged(function(value)
            control.Value = value

            if not interface.Building then
                callback(value)
            end
        end)

        function control:Set(value)
            raw:SetValue(value)
        end

        function control:SetTitle(value)
            raw:SetTitle(value)
        end

        function control:Destroy()
            raw:Destroy()
        end

        control.SetValue = control.Set
        self.Options[flag] = control
        return control
    end

    function interface:AddButton(section, title, callback)
        return section:CreateButton({ Title = title, Callback = callback })
    end

    return interface
end

local function createSpeedBoost(context)
    local controller = {
        Enabled = false,
        Multiplier = 1,
        HookInstalled = false,
    }

    local scope = createScope()

    function controller:Update(deltaTime)
        if not self.Enabled or self.Multiplier <= 1 then
            return
        end

        local scooter = findMountedScooter(context.Player)
        local body = findDriveBody(scooter)
        local predictedSpeed = math.abs(finiteNumber(context.Player:GetAttribute("ScooterPredictedSpeed"), 0))

        if not body or predictedSpeed < 3 then
            return
        end

        local hover = body:FindFirstChild("HoverBP")

        if hover and hover:IsA("AlignPosition") then
            hover.MaxVelocity = 124.8 * self.Multiplier * 2
        end

        local driveVelocity = body:FindFirstChild("DriveVelocity")

        if driveVelocity and driveVelocity.Velocity.Magnitude > 0.1 then
            driveVelocity.Velocity = driveVelocity.Velocity * self.Multiplier
        end

        local look = body.CFrame.LookVector
        local horizontal = Vector3.new(look.X, 0, look.Z)

        if horizontal.Magnitude > 0.01 then
            local distance = predictedSpeed * 1.56 * (self.Multiplier - 1) * deltaTime
            body.CFrame = body.CFrame + horizontal.Unit * distance
        end
    end

    function controller:Install()
        if self.HookInstalled then
            return true
        end

        self.HookInstalled = true
        self.Connection = scope:Connect(context.RunService.PreSimulation, function(deltaTime)
            self:Update(deltaTime)
        end)

        return true
    end

    function controller:Stop()
        scope:Clean()
        self.Connection = nil
        self.HookInstalled = false
    end

    function controller:SetMultiplier(value)
        self.Multiplier = math.max(1, finiteNumber(value, 1))
        self.Enabled = self.Multiplier > 1

        if self.Enabled then
            self:Install()
        else
            self:Stop()
        end
    end

    function controller:Destroy()
        self:SetMultiplier(1)
    end

    return controller
end

local function createQuestClaims(context)
    local controller = {
        Enabled = false,
        ScanInterval = 3,
        RefreshInterval = 15,
        LastRefreshAt = 0,
    }

    local scope = createScope()

    function controller:GetQuestList()
        return findPath(context.Player, "PlayerGui", "QuestMenu", "Main", "Quests", "List")
    end

    function controller:ClaimEligible()
        local list = self:GetQuestList()
        local remote = scooterRemote(context, "QuestRemote")

        if not list or not remote then
            return
        end

        for _, quest in ipairs(list:GetChildren()) do
            if quest:IsA("GuiObject") then
                local questId = quest:GetAttribute("QuestId")
                local category = quest:GetAttribute("Category")
                local progress = finiteNumber(quest:GetAttribute("Progress"), 0)
                local goal = finiteNumber(quest:GetAttribute("Goal"), math.huge)
                local claimed = quest:GetAttribute("Claimed") == true

                if questId and category and not claimed and progress >= goal then
                    pcall(function()
                        remote:FireServer("Claim", category, questId)
                    end)
                end
            end
        end
    end

    function controller:Start()
        if self.Enabled then
            return
        end

        self.Enabled = true
        self.LastRefreshAt = 0

        scope:Spawn(function()
            while self.Enabled do
                pcall(function()
                    self:ClaimEligible()
                end)

                task.wait(self.ScanInterval)
            end
        end)

        scope:Spawn(function()
            while self.Enabled do
                local remote = scooterRemote(context, "QuestRemote")

                if remote then
                    pcall(function()
                        remote:FireServer("GetData")
                    end)

                    self.LastRefreshAt = os.clock()
                end

                task.wait(self.RefreshInterval)
            end
        end)
    end

    function controller:Stop()
        self.Enabled = false
        scope:Clean()
    end

    function controller:Destroy()
        self:Stop()
    end

    return controller
end

local function createAutoFarm(context)
    local controller = {
        Enabled = false,
        Scooter = nil,
        Body = nil,
        BestScooter = nil,
        CurrentSteerValue = nil,
        TeleportPos = Vector3.new(3086, 4, -2683),
        Generation = 0,
    }

    local scope = createScope()
    local savedJump

    function controller:GetBestOwnedScooter()
        local owned = context.Player:FindFirstChild("OwnedScooters")
        local templates = context.ReplicatedStorage:FindFirstChild("Scooters")

        if not owned or not templates then
            return nil
        end

        local bestName
        local bestSpeed = -1

        for _, entry in ipairs(owned:GetChildren()) do
            if entry:IsA("BoolValue") and entry.Value == true then
                local template = templates:FindFirstChild(entry.Name)
                local speed = template and finiteNumber(template:GetAttribute("TopSpeedKmh"), 0)

                if speed and speed > bestSpeed then
                    bestName = entry.Name
                    bestSpeed = speed
                end
            end
        end

        return bestName
    end

    function controller:GetScooterFinalTopSpeed(name)
        return calculateTopSpeed(context, name)
    end

    function controller:DestroyLocalScooter()
        for _, object in ipairs(context.Workspace:GetChildren()) do
            if object:IsA("Model") and ownsScooter(context.Player, object) then
                pcall(function()
                    object:Destroy()
                end)
            end
        end
    end

    function controller:MoveToCenter(root, scooter)
        local body = findDriveBody(scooter)
        local facing = Vector3.new(0, 0, -1)

        if body then
            body.CFrame = CFrame.lookAt(self.TeleportPos, self.TeleportPos + facing)
            body.AssemblyLinearVelocity = Vector3.zero
            body.AssemblyAngularVelocity = Vector3.zero
        end

        if root then
            local position = self.TeleportPos + Vector3.new(0, 3, 0)
            root.CFrame = CFrame.lookAt(position, position + facing)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        self.Scooter = scooter
        self.Body = body
    end

    function controller:MountScooter(scooter, timeout, interval)
        local character = context.Player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not root then
            return false
        end

        local position = scooter:GetPivot().Position + Vector3.new(0, 4, 0)
        root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.35)

        local prompt = prepareMountPrompt(scooter)

        if not prompt then
            return false
        end

        local deadline = os.clock() + timeout

        while self.Enabled and os.clock() < deadline do
            pcall(fireproximityprompt, prompt)
            task.wait(interval)

            local mounted = findMountedScooter(context.Player)

            if mounted then
                task.wait(0.4)
                local _, currentRoot = findMountedScooter(context.Player)
                self:MoveToCenter(currentRoot, mounted)
                return true
            end
        end

        return false
    end

    function controller:UpdateSteering()
        if not self.Enabled then
            return
        end

        local scooter = findMountedScooter(context.Player)
        local body = findDriveBody(scooter)

        if not body or not body.Parent then
            return
        end

        self.Scooter = scooter
        self.Body = body

        local topSpeed = finiteNumber(scooter:GetAttribute("TopSpeedKmh"), self.FinalTopSpeed or 60)
        local steer = calculateFarmSteering(body, self.TeleportPos, topSpeed)
        self.CurrentSteerValue = steer

        context.Player:SetAttribute("ScooterLocalSteer", steer)
        context.Player:SetAttribute("ScooterLocalThrottle", 1)
        context.Player:SetAttribute("ScooterLocalBrake", 0)
        context.Player:SetAttribute("ScooterLocalWheelie", 1)
        sendScooterInput(context, steer, false)
    end

    function controller:Fail(message)
        self.Enabled = false
        scope:Clean()
        context.Notify({ Title = "Auto Farm", Content = message, Duration = 4 })
    end

    function controller:Start()
        if self.Enabled then
            return
        end

        local character = context.Player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local bestName = self:GetBestOwnedScooter()
        local spawnRemote = scooterRemote(context, "SpawnScooter")

        if not root then
            return
        end

        if not bestName then
            context.Notify({ Title = "Auto Farm", Content = "No scooters owned.", Duration = 3 })
            return
        end

        if not spawnRemote then
            return
        end

        self.Enabled = true
        self.Generation = self.Generation + 1
        self.BestScooter = bestName
        self.FinalTopSpeed = self:GetScooterFinalTopSpeed(bestName)
        self.CurrentSteerValue = nil

        scope:Spawn(function()
            local success, message = xpcall(function()
                if root:FindFirstChild("ScooterMountWeld") then
                    sendScooterInput(context, 0, true)
                    task.wait(1.2)
                end

                if not self.Enabled then
                    return
                end

                self:DestroyLocalScooter()
                task.wait(0.3)
                spawnRemote:FireServer(bestName)

                local scooter
                local deadline = os.clock() + 15

                repeat
                    scooter = findOwnedScooter(context)

                    if not scooter then
                        task.wait(0.2)
                    end
                until scooter or not self.Enabled or os.clock() >= deadline

                if not self.Enabled then
                    return
                end

                if not scooter then
                    self:Fail("Scooter never appeared.")
                    return
                end

                self.Scooter = scooter
                task.wait(0.3)

                if not prepareMountPrompt(scooter) then
                    self:Fail("No mount prompt.")
                    return
                end

                if not self:MountScooter(scooter, 12, 0.5) then
                    self:Fail("Failed to mount.")
                    return
                end

                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid then
                    savedJump = {
                        Humanoid = humanoid,
                        JumpPower = humanoid.JumpPower,
                        JumpHeight = humanoid.JumpHeight,
                    }

                    humanoid.JumpPower = 0
                    humanoid.JumpHeight = 0
                end

                self.CurrentSteerValue = 0
                scope:Connect(context.RunService.Heartbeat, function()
                    self:UpdateSteering()
                end)

                scope:Spawn(function()
                    while self.Enabled do
                        task.wait(0.5)
                        local mounted = findMountedScooter(context.Player)

                        if not mounted and self.Enabled then
                            local available = findOwnedScooter(context)

                            if not available then
                                spawnRemote:FireServer(bestName)
                                local retryDeadline = os.clock() + 6

                                repeat
                                    task.wait(0.2)
                                    available = findOwnedScooter(context)
                                until available or not self.Enabled or os.clock() >= retryDeadline
                            end

                            if available and self.Enabled then
                                self:MountScooter(available, 6, 0.3)
                            end
                        end
                    end
                end)

                context.Notify({
                    Title = "Auto Farm",
                    Content = "Circling on " .. bestName .. " (top " .. self.FinalTopSpeed .. " km/h)",
                    Duration = 3,
                })
            end, describeError)

            if not success then
                self:Fail(tostring(message))
            end
        end)
    end

    function controller:Stop()
        if not self.Enabled then
            return
        end

        self.Enabled = false
        self.Generation = self.Generation + 1
        self.CurrentSteerValue = nil
        local generation = self.Generation
        scope:Clean()

        if savedJump and savedJump.Humanoid.Parent then
            savedJump.Humanoid.JumpPower = savedJump.JumpPower
            savedJump.Humanoid.JumpHeight = savedJump.JumpHeight
        end

        savedJump = nil
        pcall(sendScooterInput, context, 0, true)
        self.Scooter = nil
        self.Body = nil

        task.spawn(function()
            task.wait(0.5)

            if self.Generation ~= generation then
                return
            end

            self:DestroyLocalScooter()
            task.wait(0.2)

            if self.Generation == generation then
                local character = context.Player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if humanoid then
                    humanoid.Health = 0
                end

                context.Notify({ Title = "Auto Farm", Content = "Stopped", Duration = 2 })
            end
        end)
    end

    function controller:Destroy()
        self:Stop()
        scope:Clean()
    end

    return controller
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
    local elapsed = 0
    local destroyed = false

    local controller = {
        Values = {
            WalkSpeed = humanoid and humanoid.WalkSpeed or 16,
            JumpPower = humanoid and humanoid.JumpPower or 50,
            HipHeight = humanoid and humanoid.HipHeight or 2,
            FOV = camera and camera.FieldOfView or 70,
            FlySpeed = 50,
        },
        Overrides = {},
        InfiniteJump = false,
        Noclip = false,
        Fly = false,
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

        for property, value in pairs(self.Overrides) do
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
        if context.Input:GetFocusedTextBox() then
            return Vector3.zero
        end

        local direction = Vector3.zero

        if context.Input:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + cameraFrame.LookVector
        end

        if context.Input:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - cameraFrame.LookVector
        end

        if context.Input:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + cameraFrame.RightVector
        end

        if context.Input:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - cameraFrame.RightVector
        end

        if context.Input:IsKeyDown(Enum.KeyCode.E) then
            direction = direction + Vector3.yAxis
        end

        if context.Input:IsKeyDown(Enum.KeyCode.Q) then
            direction = direction - Vector3.yAxis
        end

        return direction.Magnitude > 0 and direction.Unit or direction
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
        end
    end)

    scope:Connect(context.RunService.RenderStepped, function()
        if not controller.Fly then
            return
        end

        local activeCamera = context.Workspace.CurrentCamera
        local activeHumanoid = currentHumanoid()
        local root = currentRoot()

        if not activeCamera or not activeHumanoid or not root then
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

    function controller:Destroy()
        if destroyed then
            return
        end

        destroyed = true
        self.Fly = false
        self.Noclip = false
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

local function createSpeedDisplay(context)
    local controller = {
        RawValue = 0,
        DisplayValue = 0,
        DashboardValue = 0,
        Multiplier = 1,
        Calibrated = false,
    }

    local segmentNames = { "A", "B", "C", "D", "E", "F", "G" }
    local digitPatterns = {
        [0] = "ABCDEF",
        [1] = "BC",
        [2] = "ABDEG",
        [3] = "ABCDG",
        [4] = "BCFG",
        [5] = "ACDFG",
        [6] = "ACDEFG",
        [7] = "ABC",
        [8] = "ABCDEFG",
        [9] = "ABCDFG",
    }

    local segmentSets = {}
    local digitsByMask = {}

    for number = 0, 9 do
        local mask = 0
        local activeSegments = {}

        for letter in digitPatterns[number]:gmatch(".") do
            activeSegments[letter] = true
        end

        for index, letter in ipairs(segmentNames) do
            if activeSegments[letter] then
                mask = mask + 2 ^ (index - 1)
            end
        end

        segmentSets[number] = activeSegments
        digitsByMask[mask] = number
    end

    local hudProperties = {
        "Position",
        "Size",
        "AnchorPoint",
        "Rotation",
        "LayoutOrder",
        "ZIndex",
        "TextColor3",
        "TextTransparency",
        "TextSize",
        "FontFace",
        "RichText",
        "TextScaled",
        "TextXAlignment",
        "TextYAlignment",
        "TextStrokeColor3",
        "TextStrokeTransparency",
        "BackgroundColor3",
        "BackgroundTransparency",
    }

    local digitProperties = {
        "Position",
        "Size",
        "AnchorPoint",
        "Rotation",
        "LayoutOrder",
        "ZIndex",
    }

    local lifetime = createScope()
    local digitEvents = createScope()
    local overlayEvents = createScope()
    local hudEvents = createScope()
    local hudOverlayEvents = createScope()
    local digitFrames = {}
    local numberCandidates = {}
    local digitOverlays = {}
    local recentHudSpeeds = {}
    local selectedCandidate
    local dashboardRoot
    local dashboardOwner
    local rawHudLabel
    local visibleHudLabel
    local originalHudVisibility
    local expectedHudText
    local lastError
    local lastDashboardScan = -math.huge
    local lastStatus = -math.huge
    local retryAfter = -math.huge
    local multiplier = 1
    local refreshing = false
    local started = false
    local destroyed = false
    local requestRefresh
    local renderBinding = "LelSpeedDisplay_" .. tostring(context.Player.UserId)

    local function log(...)
        print("[Speedo]", ...)
    end

    local function reportError(message)
        if message ~= lastError then
            warn("[Speedo]", message)
            lastError = message
        end
    end

    local function transparencyProperty(segment)
        if segment:IsA("ImageLabel") or segment:IsA("ImageButton") then
            return "ImageTransparency"
        end

        if segment:IsA("TextLabel") or segment:IsA("TextButton") then
            return "TextTransparency"
        end

        return "BackgroundTransparency"
    end

    local function cloneVisual(source, name)
        local wasArchivable = source.Archivable
        source.Archivable = true

        local success, copy = pcall(function()
            return source:Clone()
        end)

        source.Archivable = wasArchivable
        assert(success and copy, "Unable to clone " .. source:GetFullName())
        copy.Name = name
        copy:SetAttribute("LelSpeedDisplayCopy", true)

        for _, descendant in ipairs(copy:GetDescendants()) do
            if descendant:IsA("LuaSourceContainer") then
                descendant:Destroy()
            end
        end

        return copy
    end

    local function isDisplayCopy(object, root)
        while object and object ~= root do
            if object:GetAttribute("LelSpeedDisplayCopy") then
                return true
            end

            object = object.Parent
        end

        return false
    end

    local function clearDigitOverlays()
        overlayEvents:Clean()

        for _, overlay in ipairs(digitOverlays) do
            overlay.Display:Destroy()

            if overlay.Source.Parent then
                overlay.Source.Visible = overlay.OriginalVisible
            end
        end

        digitOverlays = {}
    end

    local function clearHudOverlay()
        hudOverlayEvents:Clean()
        expectedHudText = nil

        if visibleHudLabel then
            visibleHudLabel:Destroy()
            visibleHudLabel = nil
        end

        if rawHudLabel and rawHudLabel.Parent and originalHudVisibility ~= nil then
            rawHudLabel.Visible = originalHudVisibility
        end

        originalHudVisibility = nil
    end

    local function detachHud()
        hudEvents:Clean()
        clearHudOverlay()
        rawHudLabel = nil
    end

    local function resetDashboard()
        clearDigitOverlays()
        digitEvents:Clean()
        digitFrames = {}
        numberCandidates = {}
        recentHudSpeeds = {}
        selectedCandidate = nil
        dashboardRoot = nil
        dashboardOwner = nil
        controller.Calibrated = false
    end

    local function resolveDashboard()
        for _, owner in ipairs(context.Workspace:GetDescendants()) do
            local name = normalizeName(owner.Name)

            if name:find("owner", 1, true) and ownerMatches(context.Player, owner) then
                local screen = findNamed(owner.Parent, "Screen")
                local root = findNamed(findNamed(screen, "DashboardUI"), "RealDash")

                if not root then
                    local removableScreen = findNamed(owner.Parent, "ScreenRemove")
                    local face = findNamed(removableScreen, "ScreenFace")
                    local fallback = findNamed(findNamed(face, "DashboardUI"), "RealDash")
                    root = findNamed(fallback, "Canvas") or fallback
                end

                if root then
                    return root, owner
                end
            end
        end

        return nil, nil
    end

    local function collectDigitFrames(root)
        local result = {}

        if not root then
            return result
        end

        for _, frame in ipairs(root:GetDescendants()) do
            if frame:IsA("GuiObject") and not isDisplayCopy(frame, root) then
                local complete = true

                for _, letter in ipairs(segmentNames) do
                    local segment = frame:FindFirstChild(letter)

                    if not segment or not segment:IsA("GuiObject") then
                        complete = false
                        break
                    end
                end

                if complete then
                    table.insert(result, frame)
                end
            end
        end

        return result
    end

    local function readDigit(digit)
        local mask = 0

        for index, letter in ipairs(segmentNames) do
            local segment = digit.Segments[letter]

            if not segment.Parent then
                return nil
            end

            if segment.Visible and segment[transparencyProperty(segment)] < 0.5 then
                mask = mask + 2 ^ (index - 1)
            end
        end

        if mask == 0 then
            return 0
        end

        return digitsByMask[mask]
    end

    local function readNumber(candidate, values)
        local result = 0

        for _, digit in ipairs(candidate.Digits) do
            local value = values[digit]

            if value == nil or value == false then
                return nil
            end

            result = result * 10 + value
        end

        return result
    end

    local function buildNumberCandidates()
        local rows = {}
        local knownOrders = {}
        local orders = {
            { 1, 2, 3 },
            { 1, 3, 2 },
            { 2, 1, 3 },
            { 2, 3, 1 },
            { 3, 1, 2 },
            { 3, 2, 1 },
        }

        for index, digit in ipairs(digitFrames) do
            local frame = digit.Frame
            local position = frame.AbsolutePosition
            local size = frame.AbsoluteSize
            local configuredSize = frame.Size
            digit.Index = index
            digit.Left = position.X
            digit.CenterY = position.Y + size.Y / 2
            digit.Width = math.max(1, size.X)
            digit.Height = math.max(1, size.Y)
            digit.PreferredSize = (
                math.abs(configuredSize.X.Scale) < 0.0001
                and math.abs(configuredSize.Y.Scale) < 0.0001
                and math.abs(configuredSize.X.Offset - 52) < 0.5
                and math.abs(configuredSize.Y.Offset - 100) < 0.5
            ) or (math.abs(size.X - 52) < 2 and math.abs(size.Y - 100) < 2)

            local matchingRow

            for _, row in ipairs(rows) do
                local heightRatio = digit.Height / row[1].Height
                local aligned = math.abs(digit.CenterY - row[1].CenterY) < math.max(3, digit.Height * 0.4)

                if heightRatio >= 0.7 and heightRatio <= 1.43 and aligned then
                    matchingRow = row
                    break
                end
            end

            if not matchingRow then
                matchingRow = {}
                table.insert(rows, matchingRow)
            end

            table.insert(matchingRow, digit)
        end

        local function addGroup(first, middle, last, aligned)
            local group = { first, middle, last }
            table.sort(group, function(left, right)
                return left.Left < right.Left
            end)

            for _, order in ipairs(orders) do
                local hundreds = group[order[1]]
                local tens = group[order[2]]
                local ones = group[order[3]]
                local key = hundreds.Index .. ":" .. tens.Index .. ":" .. ones.Index
                local existing = knownOrders[key]

                if existing then
                    existing.Aligned = existing.Aligned or aligned
                else
                    local preferredCount = (hundreds.PreferredSize and 1 or 0)
                        + (tens.PreferredSize and 1 or 0)
                        + (ones.PreferredSize and 1 or 0)

                    local candidate = {
                        Digits = { hundreds, tens, ones },
                        Ordered = order[1] == 1 and order[2] == 2,
                        Aligned = aligned,
                        PreferredCount = preferredCount,
                        MatchedSpeeds = {},
                        DistinctMatches = 0,
                    }

                    knownOrders[key] = candidate
                    table.insert(numberCandidates, candidate)
                end
            end
        end

        for _, row in ipairs(rows) do
            table.sort(row, function(left, right)
                return left.Left < right.Left
            end)

            for index = 1, #row - 2 do
                local first, middle, last = row[index], row[index + 1], row[index + 2]
                local firstGap = middle.Left - first.Left
                local lastGap = last.Left - middle.Left

                if firstGap <= math.max(first.Width, middle.Width) * 2.5
                    and lastGap <= math.max(middle.Width, last.Width) * 2.5 then
                    addGroup(first, middle, last, true)
                end
            end
        end

        if #digitFrames <= 16 then
            for first = 1, #digitFrames - 2 do
                for middle = first + 1, #digitFrames - 1 do
                    for last = middle + 1, #digitFrames do
                        addGroup(digitFrames[first], digitFrames[middle], digitFrames[last], #digitFrames == 3)
                    end
                end
            end
        end

        log("Dashboard digits:", #digitFrames, "Number assignments:", #numberCandidates)
    end

    local function bindDashboard(root, frames, owner)
        resetDashboard()

        if not root or #frames == 0 then
            return
        end

        dashboardRoot = root
        dashboardOwner = owner

        for _, frame in ipairs(frames) do
            local digit = { Frame = frame, Segments = {} }

            for _, letter in ipairs(segmentNames) do
                local segment = frame:FindFirstChild(letter)
                digit.Segments[letter] = segment

                local function changed()
                    if not selectedCandidate and requestRefresh then
                        requestRefresh()
                    end
                end

                digitEvents:Connect(segment:GetPropertyChangedSignal("Visible"), changed)
                digitEvents:Connect(segment:GetPropertyChangedSignal(transparencyProperty(segment)), changed)
            end

            table.insert(digitFrames, digit)
        end

        log("Dashboard:", root:GetFullName())
        buildNumberCandidates()
    end

    local function readHudSpeed()
        local label = findPath(context.Player, "PlayerGui", "ScooterHUD", "ForzaDash", "SpeedText")

        if label ~= rawHudLabel then
            detachHud()
            rawHudLabel = label

            if label then
                local function changed()
                    if visibleHudLabel and label.Visible then
                        label.Visible = false
                    end

                    if requestRefresh then
                        requestRefresh()
                    end
                end

                hudEvents:Connect(label:GetPropertyChangedSignal("Text"), changed)
                hudEvents:Connect(label:GetPropertyChangedSignal("Visible"), changed)

                for _, property in ipairs(hudProperties) do
                    hudEvents:Connect(label:GetPropertyChangedSignal(property), changed)
                end
            end
        end

        if not rawHudLabel then
            return nil
        end

        local text = tostring(rawHudLabel.Text):gsub("<[^>]*>", ""):gsub(",", "")
        local number = finiteNumber(text:match("%d+%.?%d*"), nil)
        return number and math.max(0, math.floor(number + 0.5)) or nil
    end

    local function updateHud(rawSpeed)
        local adjustedSpeed = math.floor(rawSpeed * multiplier + 0.5)
        controller.RawValue = rawSpeed
        controller.DisplayValue = adjustedSpeed

        if multiplier <= 1 then
            clearHudOverlay()
            return
        end

        if visibleHudLabel and visibleHudLabel.Parent ~= rawHudLabel.Parent then
            clearHudOverlay()
        end

        if not visibleHudLabel then
            visibleHudLabel = cloneVisual(rawHudLabel, "__LelSpeedHUD")
            originalHudVisibility = rawHudLabel.Visible

            hudOverlayEvents:Connect(visibleHudLabel:GetPropertyChangedSignal("Text"), function()
                if visibleHudLabel and expectedHudText and visibleHudLabel.Text ~= expectedHudText then
                    visibleHudLabel.Text = expectedHudText
                end
            end)

            hudOverlayEvents:Connect(visibleHudLabel:GetPropertyChangedSignal("Visible"), function()
                if visibleHudLabel and not visibleHudLabel.Visible then
                    visibleHudLabel.Visible = true
                end
            end)
        end

        local plainText = tostring(rawHudLabel.Text):gsub("<[^>]*>", "")
        expectedHudText = plainText:gsub("%d[%d,]*%.?%d*", tostring(adjustedSpeed), 1)
        visibleHudLabel.Text = expectedHudText

        for _, property in ipairs(hudProperties) do
            visibleHudLabel[property] = rawHudLabel[property]
        end

        rawHudLabel.Visible = false
        visibleHudLabel.Visible = true
        visibleHudLabel.Parent = rawHudLabel.Parent
    end

    local function matchRank(value, hudSpeed, now)
        if value == nil then
            return 0
        end

        if value == hudSpeed then
            return 2
        end

        for _, recent in ipairs(recentHudSpeeds) do
            if now - recent.Time <= 0.35 and recent.Value == value then
                return 1
            end
        end

        return 0
    end

    local function identifySpeedDigits(hudSpeed, now)
        if selectedCandidate then
            return
        end

        local recent = recentHudSpeeds[#recentHudSpeeds]

        if not recent or recent.Value ~= hudSpeed then
            table.insert(recentHudSpeeds, { Value = hudSpeed, Time = now })
        end

        while #recentHudSpeeds > 0 and (now - recentHudSpeeds[1].Time > 0.35 or #recentHudSpeeds > 12) do
            table.remove(recentHudSpeeds, 1)
        end

        local digitValues = {}

        for _, digit in ipairs(digitFrames) do
            local value = readDigit(digit)
            digitValues[digit] = value ~= nil and value or false
        end

        local bestCandidate
        local bestScore = -math.huge

        for _, candidate in ipairs(numberCandidates) do
            local value = readNumber(candidate, digitValues)
            local rank = matchRank(value, hudSpeed, now)

            if rank > 0 then
                if not candidate.MatchedSpeeds[value] then
                    candidate.MatchedSpeeds[value] = true
                    candidate.DistinctMatches = candidate.DistinctMatches + 1
                end

                local onlyGroup = #digitFrames == 3 and candidate.Ordered

                if candidate.DistinctMatches >= 2 or onlyGroup then
                    local score = math.min(candidate.DistinctMatches, 8) * 30
                        + rank
                        + (candidate.Aligned and 40 or 0)
                        + (candidate.Ordered and 15 or 0)
                        + candidate.PreferredCount * 5

                    if score > bestScore then
                        bestCandidate = candidate
                        bestScore = score
                    end
                end
            end
        end

        if bestCandidate then
            clearDigitOverlays()
            selectedCandidate = bestCandidate
            controller.Calibrated = true
            log("Speed display selected. HUD:", hudSpeed)

            for index, digit in ipairs(selectedCandidate.Digits) do
                log("Place:", 10 ^ (3 - index), digit.Frame:GetFullName())
            end
        elseif now - lastStatus >= 2 then
            lastStatus = now
            log("Matching dashboard digits against raw HUD speed:", hudSpeed)
        end
    end

    local function createDigitOverlays()
        for _, digit in ipairs(selectedCandidate.Digits) do
            local source = digit.Frame
            local display = cloneVisual(source, "__LelSpeedDigit")
            local overlay = {
                Source = source,
                Display = display,
                OriginalVisible = source.Visible,
                Digit = digit,
            }

            table.insert(digitOverlays, overlay)

            overlayEvents:Connect(source:GetPropertyChangedSignal("Visible"), function()
                if not destroyed and multiplier > 1 and source.Visible then
                    source.Visible = false
                end
            end)

            overlayEvents:Connect(display:GetPropertyChangedSignal("Visible"), function()
                if not destroyed and multiplier > 1 and not display.Visible then
                    display.Visible = true
                end
            end)

            for _, letter in ipairs(segmentNames) do
                local segment = display:FindFirstChild(letter)
                local property = transparencyProperty(segment)

                local function protectSegment()
                    if destroyed or overlay.ExpectedNumber == nil or multiplier <= 1 then
                        return
                    end

                    local active = segmentSets[overlay.ExpectedNumber][letter] == true
                    local expected = active and 0 or 0.93

                    if not segment.Visible then
                        segment.Visible = true
                    end

                    if math.abs(segment[property] - expected) > 0.0001 then
                        segment[property] = expected
                    end
                end

                overlayEvents:Connect(segment:GetPropertyChangedSignal("Visible"), protectSegment)
                overlayEvents:Connect(segment:GetPropertyChangedSignal(property), protectSegment)
            end

            source.Visible = false
            display.Visible = true
            display.Parent = source.Parent
        end
    end

    local function updateDashboard(rawSpeed)
        if not selectedCandidate then
            return
        end

        if multiplier <= 1 then
            clearDigitOverlays()
            controller.DashboardValue = rawSpeed
            return
        end

        if #digitOverlays == 0 then
            createDigitOverlays()
        end

        local value = math.clamp(math.floor(rawSpeed * multiplier + 0.5), 0, 999)
        local text = string.format("%03d", value)
        controller.DashboardValue = value

        for index, overlay in ipairs(digitOverlays) do
            local number = tonumber(text:sub(index, index))
            overlay.ExpectedNumber = number

            for _, property in ipairs(digitProperties) do
                overlay.Display[property] = overlay.Source[property]
            end

            overlay.Source.Visible = false
            overlay.Display.Visible = true

            for _, letter in ipairs(segmentNames) do
                local original = overlay.Digit.Segments[letter]
                local segment = overlay.Display:FindFirstChild(letter)
                segment.BackgroundColor3 = original.BackgroundColor3
                segment.Visible = true
                segment[transparencyProperty(segment)] = segmentSets[number][letter] and 0 or 0.93
            end
        end
    end

    local function refreshDisplays()
        local boost = context.SpeedBoost
        multiplier = boost.Enabled and math.max(1, finiteNumber(boost.Multiplier, 1)) or 1
        controller.Multiplier = multiplier
        local rawSpeed = readHudSpeed()

        if rawSpeed == nil then
            clearDigitOverlays()
            clearHudOverlay()
            return
        end

        updateHud(rawSpeed)

        if not dashboardRoot or not dashboardRoot.Parent or #digitFrames == 0 then
            if os.clock() - lastStatus >= 3 then
                lastStatus = os.clock()
                log("Waiting for dashboard A-G frames. Raw HUD:", rawSpeed)
            end

            return
        end

        for _, digit in ipairs(digitFrames) do
            if not digit.Frame.Parent then
                resetDashboard()
                lastDashboardScan = -math.huge
                return
            end
        end

        for _, overlay in ipairs(digitOverlays) do
            if overlay.Display.Parent ~= overlay.Source.Parent then
                clearDigitOverlays()
                break
            end
        end

        identifySpeedDigits(rawSpeed, os.clock())
        updateDashboard(rawSpeed)
    end

    requestRefresh = function()
        if destroyed or refreshing then
            return
        end

        refreshing = true
        local success, message = xpcall(refreshDisplays, describeError)
        refreshing = false

        if not success then
            reportError(message)
            pcall(clearDigitOverlays)
            pcall(clearHudOverlay)
        end
    end

    local function pollDashboard(now)
        local interval = dashboardRoot and #digitFrames > 0 and 2 or 0.5

        if now - lastDashboardScan < interval then
            return
        end

        lastDashboardScan = now
        local root, owner = dashboardRoot, dashboardOwner

        if not root or not root.Parent or not ownerMatches(context.Player, owner) then
            root, owner = resolveDashboard()
        end

        local frames = collectDigitFrames(root)
        local changed = root ~= dashboardRoot or #frames ~= #digitFrames

        if not changed then
            local knownFrames = {}

            for _, digit in ipairs(digitFrames) do
                knownFrames[digit.Frame] = digit
            end

            for _, frame in ipairs(frames) do
                local digit = knownFrames[frame]

                if not digit then
                    changed = true
                    break
                end

                for _, letter in ipairs(segmentNames) do
                    if frame:FindFirstChild(letter) ~= digit.Segments[letter] then
                        changed = true
                        break
                    end
                end

                if changed then
                    break
                end
            end
        end

        if changed then
            bindDashboard(root, frames, owner)
        end
    end

    local function beforeRender()
        if destroyed or os.clock() < retryAfter then
            return
        end

        local success, message = xpcall(function()
            pollDashboard(os.clock())
            requestRefresh()
        end, describeError)

        if not success then
            retryAfter = os.clock() + 1
            reportError(message)
            pcall(resetDashboard)
            pcall(detachHud)
            lastDashboardScan = -math.huge
        end
    end

    function controller:Refresh()
        requestRefresh()
    end

    function controller:Start()
        if started or destroyed then
            return
        end

        started = true

        if context.RunService.BindToRenderStep and Enum and Enum.RenderPriority then
            context.RunService:UnbindFromRenderStep(renderBinding)
            context.RunService:BindToRenderStep(renderBinding, Enum.RenderPriority.Last.Value + 1, beforeRender)

            lifetime:Add(function()
                context.RunService:UnbindFromRenderStep(renderBinding)
            end)
        else
            lifetime:Connect(context.RunService.RenderStepped, beforeRender)
        end

        lifetime:Connect(context.RunService.Heartbeat, requestRefresh)
        beforeRender()
    end

    function controller:Destroy()
        if destroyed then
            return
        end

        destroyed = true
        lifetime:Clean()
        detachHud()
        resetDashboard()
    end

    function controller.Cleanup()
        controller:Destroy()
    end

    return controller
end

local function populateInterface(interface, speedBoost, quests, autoFarm, playerControls, speedDisplay)
    local mainTab = interface:AddTab("Main", "monitor")
    local playerTab = interface:AddTab("Player", "user")
    local speedSection = mainTab:CreateSection("Speed")
    local questSection = mainTab:CreateSection("Quests")
    local farmSection = mainTab:CreateSection("Auto Farm")
    local movementSection = playerTab:CreateSection("Movement")
    local cameraSection = playerTab:CreateSection("Camera")
    local teleportSection = playerTab:CreateSection("Teleport")

    interface:AddSlider(speedSection, {
        Title = "Speed Multiplier",
        Flag = "Speed_Multiplier",
        Minimum = 1,
        Maximum = 12,
        Default = 1,
        Step = 1,
    }, function(value)
        speedBoost:SetMultiplier(value)
        speedDisplay:Refresh()
    end)

    interface:AddToggle(questSection, "Auto Claim Quests", "QuestAutoClaim_Enabled", function(enabled)
        if enabled then
            quests:Start()
        else
            quests:Stop()
        end
    end)

    interface:AddToggle(farmSection, "Auto Farm Money", "AutoFarm_Enabled", function(enabled)
        if enabled then
            autoFarm:Start()
        else
            autoFarm:Stop()
        end
    end)

    local values = playerControls.Values
    local movementSliders = {
        {
            Title = "WalkSpeed",
            Property = "WalkSpeed",
            Flag = "IY_WalkSpeed",
            Minimum = 1,
            Maximum = 100,
            Default = values.WalkSpeed,
        },
        {
            Title = "Jump Power",
            Property = "JumpPower",
            Flag = "IY_JumpPower",
            Minimum = 1,
            Maximum = 100,
            Default = values.JumpPower,
        },
        {
            Title = "Hip Height",
            Property = "HipHeight",
            Flag = "IY_HipHeight",
            Minimum = -5,
            Maximum = math.max(5, values.HipHeight),
            Default = values.HipHeight,
            Step = 0.1,
        },
    }

    for _, configuration in ipairs(movementSliders) do
        interface:AddSlider(movementSection, configuration, function(value)
            playerControls:SetMovement(configuration.Property, value)
        end)
    end

    interface:AddToggle(movementSection, "Infinite Jump", "IY_InfiniteJump", function(enabled)
        playerControls.InfiniteJump = enabled
    end)

    interface:AddToggle(movementSection, "Noclip", "IY_Noclip", function(enabled)
        playerControls:SetNoclip(enabled)
    end)

    interface:AddToggle(movementSection, "Fly", "IY_Fly", function(enabled)
        playerControls:SetFly(enabled)
    end)

    interface:AddSlider(cameraSection, {
        Title = "FOV",
        Flag = "IY_FOV",
        Minimum = 1,
        Maximum = 120,
        Default = values.FOV,
    }, function(value)
        playerControls:SetMovement("FOV", value)
    end)

    interface:AddButton(teleportSection, "Give Teleport Tool", function()
        playerControls:GiveTeleportTool()
    end)

    interface.Building = false
    interface.Window:SelectTab(1)
end

local function destroyPreviousHub(previousHub)
    if not previousHub then
        return
    end

    if type(previousHub.Cleanup) == "function" then
        pcall(previousHub.Cleanup)
        return
    end

    if previousHub.SpeedoController and type(previousHub.SpeedoController.Cleanup) == "function" then
        pcall(previousHub.SpeedoController.Cleanup)
    end

    if type(previousHub.PlayerControlsCleanup) == "function" then
        pcall(previousHub.PlayerControlsCleanup)
    end

    if type(previousHub.MainControlsCleanup) == "function" then
        pcall(previousHub.MainControlsCleanup)
    end

    local connections = previousHub.ConnectionController and previousHub.ConnectionController.Connections

    for _, connection in pairs(connections or {}) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    local threads = previousHub.TasksController and previousHub.TasksController.Tasks

    for _, thread in pairs(threads or {}) do
        pcall(task.cancel, thread)
    end

    local previousInterface = previousHub.UIController and previousHub.UIController.WindUI
    local previousLibrary = previousInterface and previousInterface.Library

    if previousLibrary then
        pcall(function()
            previousLibrary:Destroy()
        end)
    end
end

local function launch()
    local globalEnvironment = getgenv()
    destroyPreviousHub(globalEnvironment.MystrixHub)

    local context = {
        Player = game:GetService("Players").LocalPlayer,
        RunService = game:GetService("RunService"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        HttpService = game:GetService("HttpService"),
        Input = game:GetService("UserInputService"),
        Workspace = workspace,
        Destroying = false,
    }

    assert(context.Player, "Lelsploit hub requires a local player")
    local interface = createInterface(context)

    context.Notify = function(configuration)
        if not context.Destroying then
            interface:Notify(configuration)
        end
    end

    local speedBoost = createSpeedBoost(context)
    local quests = createQuestClaims(context)
    local autoFarm = createAutoFarm(context)
    local playerControls = createPlayerControls(context)
    context.SpeedBoost = speedBoost
    local speedDisplay = createSpeedDisplay(context)
    local lifetime = createScope()

    local hub = {
        Functions = {},
        SpeedBoostController = speedBoost,
        QuestAutoClaimController = quests,
        AutoFarmController = autoFarm,
        PlayerControls = playerControls,
        SpeedoController = speedDisplay,
        UIController = {
            Window = interface.Window,
            WindUI = interface,
            Tabs = interface.Tabs,
        },
        ConfigController = interface.ConfigManager,
    }

    function hub.Functions.SetSpeedMultiplier(value)
        speedBoost:SetMultiplier(value)
        speedDisplay:Refresh()
    end

    function hub.Functions.StartAutoFarm()
        autoFarm:Start()
    end

    function hub.Functions.StopAutoFarm()
        autoFarm:Stop()
    end

    function hub.Functions.GetDashboardSpeed()
        return speedDisplay.RawValue
    end

    function hub.Functions.GetAdjustedSpeed()
        return speedDisplay.DisplayValue
    end

    function hub.Functions.FindSpawnedScooter()
        return findOwnedScooter(context)
    end

    function hub.Functions.GetScooterFinalTopSpeed(name)
        return calculateTopSpeed(context, name)
    end

    function hub.Cleanup()
        if context.Destroying then
            return
        end

        context.Destroying = true
        lifetime:Clean()
        speedDisplay:Destroy()
        quests:Destroy()
        autoFarm:Destroy()
        speedBoost:Destroy()
        playerControls:Destroy()

        if not interface.Library.Unloaded then
            interface.Library:Destroy()
        end

        if globalEnvironment.MystrixHub == hub then
            globalEnvironment.MystrixHub = nil
        end
    end

    globalEnvironment.MystrixHub = hub
    globalEnvironment.WindUI = interface

    populateInterface(interface, speedBoost, quests, autoFarm, playerControls, speedDisplay)
    lifetime:Connect(interface.Library.OnUnload, hub.Cleanup)
    speedDisplay:Start()
    return hub
end

return launch()
