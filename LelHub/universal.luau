local function bindLelHubChange(control, callback)
    local initial = true
    control:OnChanged(function(...)
        if initial then initial = false return end
        callback(...)
    end)
end

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
    local titleBar = window.TitleBar
    if type(titleBar) == "table" and typeof(titleBar.TitleHolder) == "Instance" and typeof(titleBar.Title) == "Instance" and typeof(titleBar.SubTitle) == "Instance" then
        local holder = titleBar.TitleHolder
        holder.Position = UDim2.fromOffset(16, 6)
        holder.Size = UDim2.new(1, -140, 0, 30)
        holder.ClipsDescendants = true
        local layout = holder:FindFirstChildOfClass("UIListLayout")
        if not layout then layout = Instance.new("UIListLayout") layout.Parent = holder end
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Padding = UDim.new(0, 2)
        for index, label in ipairs({ titleBar.Title, titleBar.SubTitle }) do
            label.AutomaticSize = Enum.AutomaticSize.None
            label.Size = UDim2.new(1, 0, 0, index == 1 and 16 or 12)
            label.LayoutOrder = index
            label.TextSize = index == 1 and 13 or 11
            label.TextScaled = false
            label.TextWrapped = false
            label.TextTruncate = Enum.TextTruncate.AtEnd
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Center
        end
    end
    local holder = window.ContainerHolder
    if typeof(holder) ~= "Instance" then return end
    local seen = {}
    local function style(object)
        if seen[object] then return end
        if object:IsA("UIPadding") then
            local frame = object.Parent
            if frame and frame:IsA("Frame") and frame.Parent and frame.Parent:IsA("TextButton") then
                object.PaddingTop, object.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
                seen[object] = true
            end
            return
        end
        if not object:IsA("UIListLayout") then return end
        local container = object.Parent
        if not container then return end
        local isTab = container:IsA("ScrollingFrame") and container.Parent == holder
        local sectionRoot = container.Parent
        local isSection = sectionRoot and sectionRoot.Parent and sectionRoot.Parent:IsA("ScrollingFrame") and sectionRoot.Parent.Parent == holder and container.Position.Y.Offset == 24
        if not isTab and not isSection then return end
        seen[object] = true
        object.Padding = UDim.new(0, isTab and 8 or 4)
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
        if object:IsA("UIListLayout") or object:IsA("UIPadding") then task.defer(function() if object.Parent then style(object) end end) end
    end)
end

local function installLelHubReviewedFeatures(library, window, configuration)
    local name = tostring(configuration.Name or ""):lower():gsub("[^a-z0-9]", "")
    if name == "kukirin" then name = "driveakukirin" end
    local supported = { driveakukirin = true, fixitup = true, prisonlife = true, slapbattles = true, cropincremental = true, doors = true, splitthesea = true }
    if not supported[name] then return end
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local runService = game:GetService("RunService")
    local connections, resources, threads = {}, {}, {}
    local stopped, sequence = false, 0
    local function connect(event, callback)
        local connection = event:Connect(function(...) if not stopped then callback(...) end end)
        table.insert(connections, connection)
        return connection
    end
    local function notify(message)
        if not stopped then library:Notify({ Title = lelHubTitle("LelHub"), Content = message, Duration = 4 }) end
    end
    local function rootPart()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and humanoid.Health > 0 and root then return root, humanoid end
    end
    local function teleport(frame)
        local root, humanoid = rootPart()
        if not root then return false end
        if humanoid.SeatPart then notify("Leave your vehicle first.") return false end
        root.CFrame = frame
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        return true
    end
    local function launch(callback)
        for index = #threads, 1, -1 do if coroutine.status(threads[index]) == "dead" then table.remove(threads, index) end end
        local thread = task.spawn(function()
            local success = pcall(callback)
            if not success and not stopped then notify("That action could not complete.") end
        end)
        table.insert(threads, thread)
    end
    local function control(parent, kind, title, default, callback, minimum, maximum)
        sequence = sequence + 1
        local settings = { Title = lelHubTitle(title), Default = default }
        if kind == "Slider" then settings.Min, settings.Max, settings.Rounding = minimum, maximum, 2 end
        if kind == "Dropdown" then settings.Values, settings.Multi = minimum, false end
        local item = parent["Create" .. kind](parent, "LelReviewed_" .. name .. "_" .. sequence, settings)
        local initializing = true
        bindLelHubChange(item, function(value) if not initializing and not stopped then callback(value, item) end end)
        initializing = false
        return item
    end
    local function button(parent, title, callback)
        parent:CreateButton({ Title = lelHubTitle(title), Callback = function() if not stopped then launch(callback) end end })
    end
    local function physical(object)
        if object:IsA("BasePart") then return object end
        if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true) end
    end
    local function marker(object, color)
        local highlight = Instance.new("Highlight")
        highlight.Name, highlight.Adornee, highlight.Parent = "LelHubItemESP", object, object
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency, highlight.OutlineTransparency = 0.8, 0
        highlight.FillColor, highlight.OutlineColor = color, color
        resources[highlight] = true
        return highlight
    end
    if name == "driveakukirin" then
        local section = window:CreateTab({ Title = lelHubTitle("Collectibles"), Icon = "map-pin" }):CreateSection("Pumpkins")
        local enabled, delay, elapsed, nextMove = false, 1, 0, 0
        local candidates, visited = {}, setmetatable({}, { __mode = "k" })
        local function index(object)
            if (object:IsA("BasePart") or object:IsA("Model")) and object.Name:lower():find("pumpkin", 1, true) then
                local model = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChildOfClass("Humanoid") then return end
                candidates[object] = true
            end
        end
        local function scan()
            for _, object in ipairs(workspace:GetDescendants()) do index(object) end
        end
        local function nearest()
            local root = rootPart()
            if not root then return end
            local best, bestPart, distance
            for object in pairs(candidates) do
                if not object:IsDescendantOf(workspace) then candidates[object] = nil
                elseif not visited[object] then
                    local part = physical(object)
                    if part then
                        local current = (root.Position - part.Position).Magnitude
                        if not distance or current < distance then best, bestPart, distance = object, part, current end
                    end
                end
            end
            return best, bestPart
        end
        local function visit()
            local object, part = nearest()
            if not part then return false end
            if teleport(part.CFrame + Vector3.new(0, 3, 0)) then
                visited[object] = true
                local parent = object.Parent
                while parent and parent ~= workspace do
                    if candidates[parent] then visited[parent] = true end
                    parent = parent.Parent
                end
                for _, descendant in ipairs(object:GetDescendants()) do if candidates[descendant] then visited[descendant] = true end end
                return true
            end
        end
        control(section, "Toggle", "Auto Pumpkin TP", false, function(value) enabled = value if value then scan() nextMove = elapsed end end)
        control(section, "Slider", "Teleport Interval", 1, function(value) delay = value end, 0.5, 5)
        button(section, "Teleport to Next Pumpkin", function() scan() if not visit() then notify("No unvisited pumpkin found.") end end)
        button(section, "Reset Pumpkin Route", function() visited = setmetatable({}, { __mode = "k" }) scan() end)
        connect(workspace.DescendantAdded, index)
        connect(runService.Heartbeat, function(delta)
            if not enabled then return end
            elapsed = elapsed + delta
            if elapsed < nextMove then return end
            nextMove = elapsed + delay
            visit()
        end)
    elseif name == "fixitup" then
        local section = window:CreateTab({ Title = lelHubTitle("Event Items"), Icon = "package" }):CreateSection("EventFolder")
        local enabled, range, elapsed = false, 300, 0
        local markers = {}
        local function clear()
            for object, highlight in pairs(markers) do resources[highlight] = nil highlight:Destroy() markers[object] = nil end
        end
        local function items()
            local folder = workspace:FindFirstChild("EventFolder")
            return folder and folder:GetDescendants() or {}
        end
        control(section, "Toggle", "Event Item ESP", false, function(value) enabled = value if not value then clear() end end)
        control(section, "Slider", "ESP Range", 300, function(value) range = value end, 25, 1500)
        button(section, "Teleport to Nearest Event Item", function()
            local root = rootPart()
            if not root then return end
            local nearest, distance
            for _, part in ipairs(items()) do
                if part:IsA("BasePart") then
                    local current = (root.Position - part.Position).Magnitude
                    if current <= range and (not distance or current < distance) then nearest, distance = part, current end
                end
            end
            if nearest then teleport(nearest.CFrame + Vector3.new(0, 3, 0)) else notify("No event item found in range.") end
        end)
        connect(runService.Heartbeat, function(delta)
            elapsed = elapsed + delta
            if elapsed < 0.4 then return end
            elapsed = 0
            if not enabled then return end
            local root = rootPart()
            local live = {}
            if root then
                for _, part in ipairs(items()) do
                    if part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= range then
                        live[part] = true
                        if not markers[part] then markers[part] = marker(part, Color3.fromRGB(120, 170, 240)) end
                    end
                end
            end
            for part, highlight in pairs(markers) do
                if not live[part] then resources[highlight] = nil highlight:Destroy() markers[part] = nil end
            end
        end)
    elseif name == "prisonlife" then
        local tab = window:CreateTab({ Title = lelHubTitle("Prison"), Icon = "map" })
        local locations = tab:CreateSection("Locations")
        local destinations = {
            ["Yard"] = Vector3.new(779, 98, 2458), ["Cafeteria"] = Vector3.new(960, 100, 2320),
            ["Kitchen"] = Vector3.new(905, 99, 2225), ["Cells"] = Vector3.new(918, 100, 2380),
            ["Criminal Base"] = Vector3.new(-943, 94, 2063), ["Prison Roof"] = Vector3.new(825, 118, 2390),
        }
        local selected = "Yard"
        control(locations, "Dropdown", "Destination", selected, function(value) selected = value end, { "Yard", "Cafeteria", "Kitchen", "Cells", "Criminal Base", "Prison Roof" })
        button(locations, "Teleport", function() local position = destinations[selected] if position then teleport(CFrame.new(position)) end end)
        local weapons = tab:CreateSection("Weapons")
        local weapon, busy = "Remington 870", false
        control(weapons, "Dropdown", "Weapon", weapon, function(value) weapon = value end, { "Remington 870", "M4A1", "AK-47" })
        local function owned(value)
            local backpack, character = player:FindFirstChildOfClass("Backpack"), player.Character
            return (backpack and backpack:FindFirstChild(value)) or (character and character:FindFirstChild(value))
        end
        local function getWeapon(value)
            if owned(value) then return true end
            local folder = workspace:FindFirstChild("ITEM_SPAWNS") or workspace:FindFirstChild("Prison_ITEMS")
            local remoteFolder = workspace:FindFirstChild("Remote")
            local remote = remoteFolder and remoteFolder:FindFirstChild("ItemHandler")
            local root = rootPart()
            if not folder or not remote or not remote:IsA("RemoteFunction") or not root then notify("Weapon pickup is unavailable.") return end
            local part
            for _, object in ipairs(folder:GetDescendants()) do
                if object.Name:lower():find(value:lower(), 1, true) then part = physical(object) if part then break end end
            end
            if not part then notify("Weapon spawn not found.") return end
            local original = root.CFrame
            if not teleport(part.CFrame + Vector3.new(0, 2, 0)) then return end
            for _ = 1, 6 do
                if stopped or not part.Parent or owned(value) then break end
                pcall(function() remote:InvokeServer(part) end)
                task.wait(0.2)
            end
            if not stopped and player.Character and root:IsDescendantOf(player.Character) then teleport(original) end
            return owned(value) ~= nil
        end
        local function request(all)
            if busy then return end
            busy = true
            local success = pcall(function()
                if all then
                    for _, value in ipairs({ "Remington 870", "M4A1", "AK-47" }) do if stopped then break end getWeapon(value) end
                else getWeapon(weapon) end
            end)
            busy = false
            if not success then notify("Weapon pickup could not complete.") end
        end
        button(weapons, "Get Weapon", function() request(false) end)
        button(weapons, "Get All Weapons", function() request(true) end)
    elseif name == "slapbattles" then
        local section = window:CreateTab({ Title = lelHubTitle("Arena"), Icon = "shield" }):CreateSection("Anti Void")
        local platform
        control(section, "Toggle", "Anti Void", false, function(value)
            if platform then resources[platform] = nil platform:Destroy() platform = nil end
            if value then
                platform = Instance.new("Part")
                platform.Name, platform.Size, platform.Position = "LelHubAntiVoid", Vector3.new(4000, 3, 4000), Vector3.new(0, -9.75, 0)
                platform.Anchored, platform.CanCollide, platform.Transparency = true, true, 0.9
                platform.Parent = workspace
                resources[platform] = true
            end
        end)
    elseif name == "cropincremental" then
        local section = window:CreateTab({ Title = lelHubTitle("Collector"), Icon = "leaf" }):CreateSection("Tokens")
        local enabled, delay, elapsed, nextTouch = false, 0.1, 0, 0
        local lastTouch = setmetatable({}, { __mode = "k" })
        control(section, "Toggle", "Touch Collect", false, function(value, item)
            if value and type(firetouchinterest) ~= "function" then notify("Touch collection is unavailable in this executor.") item:SetValue(false) return end
            enabled = value
        end)
        control(section, "Slider", "Touch Interval", 0.1, function(value) delay = value end, 0.1, 2)
        button(section, "Reset Token History", function() lastTouch = setmetatable({}, { __mode = "k" }) end)
        connect(runService.Heartbeat, function(delta)
            if not enabled then return end
            elapsed = elapsed + delta
            if elapsed < nextTouch then return end
            nextTouch = elapsed + delay
            local root = rootPart()
            local folder = workspace:FindFirstChild("Tokens")
            if not root or not folder then return end
            for _, part in ipairs(folder:GetDescendants()) do
                if part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") and (not lastTouch[part] or elapsed - lastTouch[part] >= 5) then
                    lastTouch[part] = elapsed
                    local success = pcall(firetouchinterest, root, part, 0)
                    if success then pcall(firetouchinterest, root, part, 1) end
                    break
                end
            end
        end)
    elseif name == "splitthesea" then
        local section = window:CreateTab({ Title = lelHubTitle("Auto Farm"), Icon = "waves" }):CreateSection("Sea Farm")
        local split, loot, sell, elapsed, nextSplit, nextLoot, nextSell = false, false, false, 0, 0, 0, 0
        local interval, pendingSell = 4, nil
        local touched = setmetatable({}, { __mode = "k" })
        local moved = setmetatable({}, { __mode = "k" })
        local function restoreLoot()
            for part, frame in pairs(moved) do if part.Parent then part.CFrame = frame end moved[part] = nil end
        end
        resources[restoreLoot] = true
        local function remote(value)
            local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            local item = folder and folder:FindFirstChild(value)
            return item and item:IsA("RemoteEvent") and item or nil
        end
        local function plot()
            local islandName = player:GetAttribute("IslandName") or player:GetAttribute("CurrentIsland")
            local plotName = player:GetAttribute("PlotName")
            local islands = workspace:FindFirstChild("Islands")
            local island = islandName and islands and islands:FindFirstChild(islandName)
            local plots = island and island:FindFirstChild("Plots")
            return plotName and plots and plots:FindFirstChild(plotName) or nil
        end
        local function sellAll()
            local event = remote("SellRequest")
            if event then event:FireServer({ Mode = "SellAll" }) else notify("Selling is unavailable.") end
        end
        control(section, "Toggle", "Auto Split", false, function(value) split = value if value then nextSplit = elapsed end end)
        control(section, "Toggle", "Auto Loot", false, function(value) loot = value if not value then restoreLoot() end end)
        control(section, "Toggle", "Auto Sell", false, function(value) sell = value nextSell = elapsed + interval end)
        control(section, "Slider", "Split Interval", 4, function(value) interval = value end, 4, 30)
        button(section, "Sell All", sellAll)
        connect(runService.Heartbeat, function(delta)
            elapsed = elapsed + delta
            if split and elapsed >= nextSplit then
                nextSplit = elapsed + interval
                local owned = plot()
                local event = remote("SplitRequest")
                if owned and owned:GetAttribute("PlotBusy") ~= true and event then event:FireServer(1, true) pendingSell = elapsed + 3.5 end
            end
            if sell and ((pendingSell and elapsed >= pendingSell) or (not pendingSell and elapsed >= nextSell)) then
                pendingSell = nil
                nextSell = elapsed + interval
                sellAll()
            end
            if not loot or elapsed < nextLoot then return end
            nextLoot = elapsed + 0.3
            local root = rootPart()
            local folder = workspace:FindFirstChild("ActiveLoot")
            if not root or not folder then return end
            local plotName, count = player:GetAttribute("PlotName"), 0
            for _, item in ipairs(folder:GetChildren()) do
                local owner = item:GetAttribute("PlotName")
                if (not owner or owner == plotName) and (not touched[item] or elapsed - touched[item] >= 2) then
                    local event = item:GetAttribute("PickupType") == "Interact" and remote("InteractRequest")
                    if event then event:FireServer(item.Name)
                    else
                        local part = physical(item)
                        if part then
                            if not moved[part] then moved[part] = part.CFrame end
                            part.CFrame = root.CFrame
                        end
                    end
                    touched[item] = elapsed
                    count = count + 1
                    if count >= 8 then break end
                end
            end
        end)
    elseif name == "doors" then
        local section = window:CreateTab({ Title = lelHubTitle("Interactions"), Icon = "hand" }):CreateSection("Proximity Prompts")
        local instant, auto, range, interval, elapsed, nextPrompt = false, false, 10, 0.4, 0, 0
        local prompts, durations, holds = {}, {}, {}
        local function add(object)
            if object:IsA("ProximityPrompt") then
                prompts[object] = true
                if instant and durations[object] == nil then durations[object] = object.HoldDuration object.HoldDuration = 0 end
            end
        end
        local function restore()
            for prompt, duration in pairs(durations) do if prompt.Parent then prompt.HoldDuration = duration end durations[prompt] = nil end
        end
        resources[restore] = true
        local function releaseHolds()
            for prompt in pairs(holds) do pcall(function() prompt:InputHoldEnd() end) holds[prompt] = nil end
        end
        resources[releaseHolds] = true
        control(section, "Toggle", "Instant Interact", false, function(value)
            instant = value
            if value then for _, object in ipairs(workspace:GetDescendants()) do add(object) end else restore() end
        end)
        control(section, "Toggle", "Auto Interact", false, function(value)
            auto = value
            if value then for _, object in ipairs(workspace:GetDescendants()) do add(object) end else releaseHolds() end
        end)
        control(section, "Slider", "Interact Range", 10, function(value) range = value end, 2, 20)
        control(section, "Slider", "Interact Interval", 0.4, function(value) interval = value end, 0.2, 3)
        connect(workspace.DescendantAdded, add)
        connect(runService.Heartbeat, function(delta)
            if not auto then return end
            elapsed = elapsed + delta
            if elapsed < nextPrompt then return end
            nextPrompt = elapsed + interval
            local root = rootPart()
            if not root then return end
            local best, distance
            for prompt in pairs(prompts) do
                if not prompt.Parent then prompts[prompt] = nil durations[prompt] = nil
                elseif prompt.Enabled then
                    local parent = prompt.Parent
                    local position = parent:IsA("Attachment") and parent.WorldPosition or (physical(parent) and physical(parent).Position)
                    if position then
                        local current = (root.Position - position).Magnitude
                        if current <= math.min(range, prompt.MaxActivationDistance) and (not distance or current < distance) then best, distance = prompt, current end
                    end
                end
            end
            if best then
                nextPrompt = elapsed + math.max(interval, best.HoldDuration + 0.1)
                launch(function()
                    if stopped or not auto or not best.Parent or not best.Enabled then return end
                    local duration = best.HoldDuration
                    if type(fireproximityprompt) == "function" then fireproximityprompt(best, duration)
                    else
                        holds[best] = true
                        best:InputHoldBegin()
                        task.wait(duration)
                        if holds[best] then pcall(function() best:InputHoldEnd() end) holds[best] = nil end
                    end
                end)
            end
        end)
    end
    return function()
        if stopped then return end
        stopped = true
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, thread in ipairs(threads) do pcall(task.cancel, thread) end
        for resource in pairs(resources) do pcall(function() if type(resource) == "function" then resource() else resource:Destroy() end end) end
    end
end

local function installLelHubExpandedTools(library, window, configuration)
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local runService = game:GetService("RunService")
    local input = game:GetService("UserInputService")
    local lighting = game:GetService("Lighting")
    local connections, restores, resources = {}, {}, {}
    local stopped, serial = false, 0
    local baselines = setmetatable({}, { __mode = "k" })
    local function connect(signal, callback)
        local connection = signal:Connect(function(...) if not stopped then callback(...) end end)
        table.insert(connections, connection)
        return connection
    end
    local function notify(message) library:Notify({ Title = lelHubTitle("LelHub"), Content = message, Duration = 4 }) end
    local function control(parent, kind, title, default, callback, values, maximum)
        if kind == "Slider" then callback, values, maximum = maximum, callback, values end
        serial = serial + 1
        local options = { Title = lelHubTitle(title), Default = default }
        if kind == "Slider" then options.Min, options.Max, options.Rounding = values, maximum, 2 end
        if kind == "Dropdown" then options.Values, options.Multi = values, false end
        local item = parent["Create" .. kind](parent, "LelExpanded_" .. serial, options)
        local initializing = true
        bindLelHubChange(item, function(value) if not initializing and not stopped then callback(value) end end)
        initializing = false
        return item
    end
    local function button(parent, title, callback)
        parent:CreateButton({ Title = lelHubTitle(title), Callback = function()
            if stopped then return end
            local ok, result = pcall(callback)
            if not ok then notify("That action is unavailable right now.") elseif type(result) == "string" then notify(result) end
        end })
    end
    local function rootOf(character) return character and character:FindFirstChild("HumanoidRootPart") end
    local function humanoid() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end
    local function teleport(frame)
        local root, human = rootOf(player.Character), humanoid()
        if not root or not human or human.Health <= 0 then return end
        if human.SeatPart then return "Leave your seat first." end
        root.CFrame = frame
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    local function remember(object, property)
        restores[object] = restores[object] or {}
        if restores[object][property] == nil then
            local saved = baselines[object] and baselines[object][property]
            if saved then restores[object][property] = { saved[1] } else restores[object][property] = { object[property] } end
        end
    end
    local function restore(object)
        for property, value in pairs(restores[object] or {}) do pcall(function() object[property] = value[1] end) end
        restores[object] = nil
    end
    local human = humanoid()
    if human then baselines[human] = { JumpHeight = { human.JumpHeight }, UseJumpPower = { human.UseJumpPower }, MaxSlopeAngle = { human.MaxSlopeAngle } } end
    baselines[lighting] = {}
    for _, property in ipairs({ "FogStart", "FogEnd", "ClockTime", "Brightness", "GlobalShadows" }) do baselines[lighting][property] = { lighting[property] } end
    baselines[workspace] = { Gravity = { workspace.Gravity } }
    local playerTab = configuration.ExpandedPlayerTab or window:CreateTab({ Title = lelHubTitle("Player"), Icon = "user" })
    local jumping = playerTab:CreateSection("Jumping")
    local bunnyHop, jumpHeight, slope = false, nil, nil
    local resetting = false
    local bunnyControl = control(jumping, "Toggle", "Bunny Hop", false, function(value) bunnyHop = value end)
    local heightControl = control(jumping, "Slider", "JumpHeight", 7.2, 0, 100, function(value)
        if resetting then return end
        jumpHeight = value
        local human = humanoid()
        if human then remember(human, "JumpHeight") remember(human, "UseJumpPower") human.UseJumpPower = false human.JumpHeight = value end
    end)
    local slopeControl = control(jumping, "Slider", "Max Slope Angle", 89, 0, 89, function(value)
        if resetting then return end
        slope = value
        local human = humanoid()
        if human then remember(human, "MaxSlopeAngle") human.MaxSlopeAngle = value end
    end)
    button(jumping, "Reset Jump Settings", function()
        bunnyHop, jumpHeight, slope = false, nil, nil
        bunnyControl:SetValue(false)
        for object, values in pairs(restores) do if values.JumpHeight or values.MaxSlopeAngle then restore(object) end end
        local human = humanoid()
        if human then
            resetting = true
            heightControl:SetValue(human.JumpHeight)
            slopeControl:SetValue(human.MaxSlopeAngle)
            resetting = false
        end
    end)
    local tools = playerTab:CreateSection("Tools")
    local autoUse, useDelay, lastUse = false, 0.5, 0
    local function heldTool() return player.Character and player.Character:FindFirstChildOfClass("Tool") end
    control(tools, "Toggle", "Auto Use Tool", false, function(value) autoUse = value end)
    control(tools, "Slider", "Use Interval", 0.5, 0.1, 5, function(value) useDelay = value end)
    button(tools, "Use Held Tool", function() local tool = heldTool() if tool then tool:Activate() end end)
    button(tools, "Equip All Tools", function()
        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack and player.Character then for _, tool in ipairs(backpack:GetChildren()) do if tool:IsA("Tool") then tool.Parent = player.Character end end end
    end)
    button(tools, "Unequip Tools", function() local human = humanoid() if human then human:UnequipTools() end end)
    local navigation = playerTab:CreateSection("Navigation")
    local clickTeleport = false
    control(navigation, "Toggle", "Ctrl Click Teleport", false, function(value) clickTeleport = value end)
    button(navigation, "Stop Velocity", function()
        local root = rootOf(player.Character)
        if root then root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero end
    end)
    connect(input.InputBegan, function(key, processed)
        if not processed and clickTeleport and key.UserInputType == Enum.UserInputType.MouseButton1 and input:IsKeyDown(Enum.KeyCode.LeftControl) then teleport(player:GetMouse().Hit + Vector3.new(0, 3, 0)) end
    end)
    connect(player.CharacterAdded, function(character)
        local human = character:WaitForChild("Humanoid", 10)
        if not human or stopped then return end
        if jumpHeight then remember(human, "JumpHeight") remember(human, "UseJumpPower") human.UseJumpPower = false human.JumpHeight = jumpHeight end
        if slope then remember(human, "MaxSlopeAngle") human.MaxSlopeAngle = slope end
    end)
    local playersTab = configuration.ExpandedPlayersTab or window:CreateTab({ Title = lelHubTitle("Players"), Icon = "users" })
    local selected, follow, orbit, orbitRadius, followDistance, angle = nil, false, false, 8, 5, 0
    local targetSection = playersTab:CreateSection("Target Actions")
    local names, targetDropdown = { "None" }, nil
    local function refresh(leaving)
        names = { "None" }
        for _, target in ipairs(players:GetPlayers()) do if target ~= player and target ~= leaving then table.insert(names, target.Name) end end
        table.sort(names)
        if targetDropdown then targetDropdown:SetValues(names) end
        if selected == leaving then selected, follow, orbit = nil, false, false end
    end
    refresh()
    targetDropdown = control(targetSection, "Dropdown", "Target", "None", function(value) selected = players:FindFirstChild(value) end, names)
    control(targetSection, "Toggle", "Follow", false, function(value) follow = value end)
    control(targetSection, "Slider", "Follow Distance", 5, 2, 30, function(value) followDistance = value end)
    control(targetSection, "Toggle", "Orbit", false, function(value) orbit = value end)
    control(targetSection, "Slider", "Orbit Radius", 8, 3, 40, function(value) orbitRadius = value end)
    button(targetSection, "Teleport Behind Target", function()
        local root = selected and rootOf(selected.Character)
        if root then return teleport(root.CFrame * CFrame.new(0, 0, followDistance)) end
        return "Select an available target."
    end)
    button(targetSection, "Copy Username", function() if selected and setclipboard then setclipboard(selected.Name) end end)
    button(targetSection, "Copy User ID", function() if selected and setclipboard then setclipboard(tostring(selected.UserId)) end end)
    connect(players.PlayerAdded, function() refresh() end)
    connect(players.PlayerRemoving, refresh)
    local world = window:CreateTab({ Title = lelHubTitle("Environment"), Icon = "sun" })
    local scene = world:CreateSection("Lighting")
    local noFog, noEffects, noParticles = false, false, false
    control(scene, "Toggle", "No Fog", false, function(value)
        noFog = value
        if value then remember(lighting, "FogStart") remember(lighting, "FogEnd") lighting.FogStart, lighting.FogEnd = 0, 1000000
        else for object in pairs(restores) do if object:IsA("Atmosphere") then restore(object) end end for _, property in ipairs({ "FogStart", "FogEnd" }) do if restores[lighting] and restores[lighting][property] then lighting[property] = restores[lighting][property][1] restores[lighting][property] = nil end end end
    end)
    local function effect(object)
        if noEffects and object:IsA("PostEffect") then remember(object, "Enabled") object.Enabled = false end
        if noFog and object:IsA("Atmosphere") then remember(object, "Density") object.Density = 0 end
        if noParticles and (object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")) then remember(object, "Enabled") object.Enabled = false end
    end
    control(scene, "Toggle", "No Post Effects", false, function(value)
        noEffects = value
        if value then for _, object in ipairs(lighting:GetDescendants()) do effect(object) end local camera = workspace.CurrentCamera if camera then for _, object in ipairs(camera:GetDescendants()) do effect(object) end end
        else for object in pairs(restores) do if object:IsA("PostEffect") then restore(object) end end end
    end)
    control(scene, "Slider", "Time of Day", lighting.ClockTime, 0, 24, function(value) remember(lighting, "ClockTime") lighting.ClockTime = value end)
    control(scene, "Slider", "Brightness", lighting.Brightness, 0, 10, function(value) remember(lighting, "Brightness") lighting.Brightness = value end)
    control(scene, "Toggle", "No Shadows", false, function(value) remember(lighting, "GlobalShadows") if value then lighting.GlobalShadows = false else lighting.GlobalShadows = restores[lighting].GlobalShadows[1] end end)
    button(scene, "Reset Lighting", function()
        noFog, noEffects = false, false
        restore(lighting)
        for object in pairs(restores) do if object:IsA("Atmosphere") or object:IsA("PostEffect") then restore(object) end end
    end)
    local physics = world:CreateSection("Physics")
    control(physics, "Slider", "Gravity", workspace.Gravity, 0, 500, function(value) remember(workspace, "Gravity") workspace.Gravity = value end)
    button(physics, "Reset Gravity", function() restore(workspace) end)
    local performance = world:CreateSection("Effects")
    control(performance, "Toggle", "Hide Particles", false, function(value)
        noParticles = value
        if value then for _, object in ipairs(workspace:GetDescendants()) do effect(object) end
        else for object in pairs(restores) do if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then restore(object) end end end
    end)
    connect(workspace.DescendantAdded, effect)
    connect(lighting.DescendantAdded, effect)
    local elapsed = 0
    connect(runService.Heartbeat, function(delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        local step = elapsed
        elapsed = 0
        local human, root = humanoid(), rootOf(player.Character)
        if bunnyHop and human and human.FloorMaterial ~= Enum.Material.Air then human.Jump = true end
        if autoUse and os.clock() - lastUse >= useDelay then lastUse = os.clock() local tool = heldTool() if tool then pcall(function() tool:Activate() end) end end
        local other = selected and rootOf(selected.Character)
        if other and root and human and not human.SeatPart and human.Health > 0 then
            if orbit then
                angle = angle + step
                teleport(CFrame.new(other.Position + Vector3.new(math.cos(angle) * orbitRadius, 0, math.sin(angle) * orbitRadius), other.Position))
            elseif follow and (root.Position - other.Position).Magnitude > followDistance then human:MoveTo((other.CFrame * CFrame.new(0, 0, followDistance)).Position) end
        end
        if noFog then lighting.FogEnd = 1000000 for _, object in ipairs(lighting:GetChildren()) do if object:IsA("Atmosphere") then effect(object) end end end
    end)
    return function()
        if stopped then return end
        stopped = true
        if follow then local human = humanoid() if human then human:Move(Vector3.zero) end end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for object in pairs(restores) do restore(object) end
        for _, object in ipairs(resources) do object:Destroy() end
    end
end

local function installLelHubControls(library, window, configuration)
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local input = game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local tweenService = game:GetService("TweenService")
    local http = game:GetService("HttpService")
    local connections = {}
    local reviewedCleanup = installLelHubReviewedFeatures(library, window, configuration)
    local expandedCleanup
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
        bindLelHubChange(control, function(value)
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
        for _, entry in ipairs({ { "WalkSpeed", "Walk speed", 16, 16, 500 }, { "JumpPower", "Jump power", 50, 0, 500 }, { "HipHeight", "Hip height", (select(2, parts()) and select(2, parts()).HipHeight) or 4, 0, 50 } }) do
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
    local waypointDropdown

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
    waypointDropdown = register(places, "Dropdown", "Waypoint", { Title = lelHubTitle("Saved position"), Values = {}, Multi = false }, function(value)
        selectedWaypoint = value
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
    local coordinates = ui(utilityTab, "Section", "Coordinates")
    register(coordinates, "Input", "Coordinates", { Title = lelHubTitle("Coordinates"), Default = "", Placeholder = "X, Y, Z", Finished = true }, function(value)
        coordinateText = tostring(value)
    end)
    button(coordinates, "Teleport to coordinates", function()
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
    button(coordinates, "Copy coordinates", function()
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
        configuration.ExpandedPlayersTab = playersTab
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

    configuration.ExpandedPlayerTab = utilityTab
    expandedCleanup = installLelHubExpandedTools(library, window, configuration)

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
    launcher.Image = "rbxassetid://74822717324149"
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
        { Name = "Global", File = "global.luau" },
        { Name = "Universal Enhancements", File = "universal.luau" },
        { Name = "Client Tools", File = "client.luau" },
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

        if reviewedCleanup then reviewedCleanup() end
        if expandedCleanup then expandedCleanup() end
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

    return { Cleanup = cleanup, Controls = controls, Launcher = launcher, Settings = settingsTab, Player = utilityTab, Players = configuration.ExpandedPlayersTab, State = state }
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

    local bindingName = "LelHubUniversalCamera_" .. tostring(context.Player.UserId)
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

local function installAimControls(context, library, window, worldTab, cameraTab)
    local scope = createScope()
    local state = { Aim = false, TeamCheck = true, VisibleCheck = true, Radius = 150, Smoothness = 0.25, Part = "Head", Circle = false, Crosshair = false, Boxes = false, Tracers = false, Trigger = false }
    local holding = false
    local drawings = {}
    local lastShot = -math.huge
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "LelHubCombatOverlay", false, true, 10000
    gui.Parent = context.Player:WaitForChild("PlayerGui")
    scope:Add(gui)

    local function frame(parent, color)
        local object = Instance.new("Frame")
        object.BorderSizePixel, object.BackgroundColor3, object.Parent = 0, color, parent
        return object
    end
    local accent = Color3.fromRGB(116, 159, 255)
    local circle = frame(gui, accent)
    circle.BackgroundTransparency = 1
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(1, 0), circle
    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color, circleStroke.Thickness, circleStroke.Parent = accent, 1, circle
    local horizontal = frame(gui, accent)
    local vertical = frame(gui, accent)
    horizontal.AnchorPoint, vertical.AnchorPoint = Vector2.new(0.5, 0.5), Vector2.new(0.5, 0.5)
    horizontal.Size, vertical.Size = UDim2.fromOffset(18, 2), UDim2.fromOffset(2, 18)

    local tab = window:CreateTab({ Title = lelHubTitle("Aim"), Icon = "crosshair" })
    local function toggle(key, title)
        local control = tab:CreateToggle("LelAim_" .. key, { Title = lelHubTitle(title), Default = state[key] })
        control:OnChanged(function(value) state[key] = value end)
    end
    toggle("Aim", "Hold right mouse to aim")
    toggle("TeamCheck", "Ignore teammates")
    toggle("VisibleCheck", "Visibility check")
    local radius = tab:CreateSlider("LelAim_Radius", { Title = lelHubTitle("Aim radius"), Default = 150, Min = 20, Max = 700, Rounding = 0 })
    radius:OnChanged(function(value) state.Radius = value end)
    local smoothing = tab:CreateSlider("LelAim_Smoothness", { Title = lelHubTitle("Aim smoothness"), Default = 0.25, Min = 0.01, Max = 1, Rounding = 2 })
    smoothing:OnChanged(function(value) state.Smoothness = value end)
    local part = tab:CreateDropdown("LelAim_Part", { Title = lelHubTitle("Aim part"), Values = { "Head", "HumanoidRootPart" }, Default = "Head", Multi = false })
    part:OnChanged(function(value) state.Part = value end)
    toggle("Circle", "Aim circle")
    toggle("Crosshair", "Crosshair")
    toggle("Boxes", "Player boxes")
    toggle("Tracers", "Player tracers")
    toggle("Trigger", "Auto activate equipped tool")

    local lighting = context.Lighting
    local savedFog
    local savedShadows
    local savedZoom
    local noFog = false
    local noShadows = false
    local thirdPerson = false
    local thirdDistance = 12
    local fogControl = worldTab:CreateToggle("LelScene_NoFog", { Title = lelHubTitle("Remove fog"), Default = false })
    fogControl:OnChanged(function(value)
        noFog = value
        if value then savedFog = savedFog or { lighting.FogStart, lighting.FogEnd }
        elseif savedFog then lighting.FogStart, lighting.FogEnd = savedFog[1], savedFog[2] savedFog = nil end
    end)
    local shadowControl = worldTab:CreateToggle("LelScene_NoShadows", { Title = lelHubTitle("Remove shadows"), Default = false })
    shadowControl:OnChanged(function(value)
        noShadows = value
        if value then
            if savedShadows == nil then savedShadows = lighting.GlobalShadows end
        elseif savedShadows ~= nil then lighting.GlobalShadows = savedShadows savedShadows = nil end
    end)
    local function restoreZoom()
        if savedZoom then
            context.Player.CameraMinZoomDistance = savedZoom[1]
            context.Player.CameraMaxZoomDistance = math.max(savedZoom[1], savedZoom[2])
            savedZoom = nil
        end
    end
    local thirdControl = cameraTab:CreateToggle("LelScene_ThirdPerson", { Title = lelHubTitle("Third person"), Default = false })
    thirdControl:OnChanged(function(value)
        thirdPerson = value
        if value then savedZoom = savedZoom or { context.Player.CameraMinZoomDistance, context.Player.CameraMaxZoomDistance }
        else restoreZoom() end
    end)
    local thirdSlider = cameraTab:CreateSlider("LelScene_ThirdDistance", { Title = lelHubTitle("Third person distance"), Default = 12, Min = 6, Max = 40, Rounding = 0 })
    thirdSlider:OnChanged(function(value) thirdDistance = value end)
    scope:Connect(context.RunService.Heartbeat, function()
        if noFog then lighting.FogStart, lighting.FogEnd = 1000000, 1000000 end
        if noShadows then lighting.GlobalShadows = false end
        if thirdPerson then
            context.Player.CameraMaxZoomDistance = math.max(thirdDistance, context.Player.CameraMaxZoomDistance)
            context.Player.CameraMinZoomDistance = thirdDistance
        end
    end)
    scope:Add(function()
        if savedFog then lighting.FogStart, lighting.FogEnd = savedFog[1], savedFog[2] end
        if savedShadows ~= nil then lighting.GlobalShadows = savedShadows end
        restoreZoom()
    end)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local function visible(character, position, camera)
        params.FilterDescendantsInstances = { context.Player.Character }
        local hit = context.Workspace:Raycast(camera.CFrame.Position, position - camera.CFrame.Position, params)
        return not hit or hit.Instance:IsDescendantOf(character)
    end
    local function clear(target)
        local entry = drawings[target]
        if entry then entry.Box:Destroy() entry.Tracer:Destroy() drawings[target] = nil end
    end
    scope:Connect(context.Players.PlayerRemoving, clear)
    scope:Connect(context.Input.InputBegan, function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then holding = true end
    end)
    scope:Connect(context.Input.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then holding = false end
    end)
    scope:Connect(context.Input.WindowFocusReleased, function() holding = false end)
    scope:Connect(context.RunService.RenderStepped, function(deltaTime)
        local camera = context.Workspace.CurrentCamera
        if not camera then return end
        local center = camera.ViewportSize / 2
        circle.Position, circle.Size, circle.Visible = UDim2.fromOffset(center.X, center.Y), UDim2.fromOffset(state.Radius * 2, state.Radius * 2), state.Circle
        horizontal.Position, vertical.Position = UDim2.fromOffset(center.X, center.Y), UDim2.fromOffset(center.X, center.Y)
        horizontal.Visible, vertical.Visible = state.Crosshair, state.Crosshair
        if not state.Aim and not state.Boxes and not state.Tracers and not state.Trigger then
            for target in pairs(drawings) do clear(target) end
            return
        end
        local best, bestDistance = nil, state.Radius
        for _, target in ipairs(context.Players:GetPlayers()) do
            if target ~= context.Player then
                local character = target.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local aimPart = character and (character:FindFirstChild(state.Part) or root)
                local friendly = target.Team and target.Team == context.Player.Team
                if root and aimPart and humanoid and humanoid.Health > 0 then
                    local screen, onScreen = camera:WorldToViewportPoint(aimPart.Position)
                    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if onScreen and distance < bestDistance and (not state.TeamCheck or not friendly)
                        and (not state.VisibleCheck or visible(character, aimPart.Position, camera)) then
                        best, bestDistance = aimPart, distance
                    end
                    local entry = drawings[target]
                    if state.Boxes or state.Tracers then
                        if not entry then
                            local box = frame(gui, accent)
                            box.BackgroundTransparency = 1
                            local stroke = Instance.new("UIStroke")
                            stroke.Color, stroke.Thickness, stroke.Parent = accent, 1, box
                            entry = { Box = box, Tracer = frame(gui, accent) }
                            entry.Tracer.AnchorPoint = Vector2.new(0, 0.5)
                            drawings[target] = entry
                        end
                        local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
                        local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                        local height = math.abs(bottom.Y - top.Y)
                        local width = height * 0.55
                        entry.Box.Position = UDim2.fromOffset(screen.X - width / 2, top.Y)
                        entry.Box.Size, entry.Box.Visible = UDim2.fromOffset(width, height), state.Boxes and onScreen
                        local start = Vector2.new(center.X, camera.ViewportSize.Y - 12)
                        local finish = Vector2.new(screen.X, bottom.Y)
                        local delta = finish - start
                        entry.Tracer.Position = UDim2.fromOffset(start.X, start.Y)
                        entry.Tracer.Size = UDim2.fromOffset(delta.Magnitude, 1)
                        entry.Tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                        entry.Tracer.Visible = state.Tracers and onScreen
                    elseif entry then clear(target) end
                else
                    clear(target)
                end
            end
        end
        if state.Aim and holding and best and not context.Input:GetFocusedTextBox() then
            local goal = CFrame.lookAt(camera.CFrame.Position, best.Position)
            local fraction = 1 - (1 - state.Smoothness) ^ (math.min(deltaTime, 0.1) * 60)
            camera.CFrame = camera.CFrame:Lerp(goal, fraction)
        end
        if state.Trigger and best and bestDistance <= 8 and os.clock() - lastShot >= 0.2 and not context.Input:GetFocusedTextBox() then
            local character = context.Player.Character
            local tool = character and character:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() lastShot = os.clock() end
        end
    end)
    scope:Add(function() for target in pairs(drawings) do clear(target) end end)
    return function() scope:Clean() end
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
        local result = invoke(window, "Tab", { Title = lelHubTitle(title), Icon = icon })
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
        bindLelHubChange(control, function(nextValue)
            settings[id] = nextValue
            apply(id, nextValue)
        end)
        return control
    end

    local function toggle(parent, id, title, default, callback, description)
        return register(invoke(parent, "Toggle", id, {
            Title = lelHubTitle(title),
            Default = default,
        }), id, default, callback)
    end

    local function slider(parent, id, title, default, minimum, maximum, callback, rounding)
        return register(invoke(parent, "Slider", id, {
            Title = lelHubTitle(title),
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
            Title = lelHubTitle(title),
            Values = values,
            Default = default,
            Multi = false,
        }), id, default, callback)
    end

    local function button(parent, title, callback, description)
        return invoke(parent, "Button", {
            Title = lelHubTitle(title),
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
            Title = lelHubTitle(title),
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
    overlay.Name = "LelHubUniversalControls"
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

    lifetime:Add(installAimControls(context, library, window, worldTab, cameraTab))
    building = false
    local shared = installLelHubControls(library, window, {
        Name = "universal",
        SettingsTab = settingsTab,
        ExpandedPlayersTab = playersTab,
        PlayerTab = playerTab,
        ResetMovement = function()
            cameraControls:Stop()
            controls.PlayerFly:SetValue(false)
            controls.Noclip:SetValue(false)
            controls.InfiniteJump:SetValue(false)
            playerControls:ResetMovement()
            for _, id in ipairs({ "WalkSpeed", "JumpPower", "HipHeight", "FOV" }) do controls[id]:SetValue(defaults[id]) end
            playerControls:ResetMovement()
            playerControls:RestoreCollisions()
            playerControls:StopFlight()
        end,
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
    local previous = environment.LelHubUniversal

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

        if environment.LelHubUniversal == hub then
            environment.LelHubUniversal = nil
        end
    end

    hub.Destroy = hub.Cleanup
    environment.LelHubUniversal = hub
    context.Notify = function(message)
        if not context.Destroying then
            library:Notify({ Title = lelHubTitle("LelHub"), Content = message, Duration = 5 })
        end
    end

    local initialized, message = xpcall(function()
        local window = library:CreateWindow({
            Title = lelHubTitle("LelHub Universal Enhancements"),
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
