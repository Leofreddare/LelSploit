local function lelHubFetchSource(url)
    local function text(value)
        if type(value) ~= "string" or not value:find("%S") then return end
        local start = value:sub(1, 160):gsub("^%s+", "")
        start = start:lower()
        if start:find("<!doctype", 1, true) or start:find("<html", 1, true) or start:find("404: not found", 1, true) then return end
        return value
    end
    local methods = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
    }
    local send = request or http_request or (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    if type(send) == "function" then
        table.insert(methods, function()
            local response = send({ Url = url, Method = "GET", Timeout = 15 })
            if type(response) == "string" then return response end
            if type(response) ~= "table" or response.Success == false then return end
            local status = tonumber(response.StatusCode or response.Status)
            if status and (status < 200 or status >= 300) then return end
            return response.Body or response.body
        end)
    end
    for attempt = 1, 2 do
        for _, fetch in ipairs(methods) do
            local ok, response = pcall(fetch)
            local source = ok and text(response)
            if source then return source end
        end
        if attempt < 2 then task.wait(0.25) end
    end
    error("[LelHub] Download returned no script text: " .. url, 0)
end

local function lelHubCompileRemote(url, name)
    if type(loadstring) ~= "function" then error("[LelHub] This executor does not provide loadstring.", 0) end
    local source = lelHubFetchSource(url)
    local ok, chunk, message = pcall(loadstring, source, name or "LelHub/Remote")
    if not ok or type(chunk) ~= "function" then error("[LelHub] Downloaded script could not compile: " .. tostring(message or chunk), 0) end
    return chunk
end

local function lelHubLoadInterface()
    local urls = {
        "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/f.luau",
        "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau",
    }
    local lastError
    for _, url in ipairs(urls) do
        local ok, library = pcall(function() return lelHubCompileRemote(url, "LelHub/Fluent")() end)
        if ok and type(library) == "table" and type(library.CreateWindow) == "function" then return library end
        lastError = ok and "The interface did not return a valid library." or tostring(library)
    end
    error("[LelHub] Could not load the interface. " .. tostring(lastError), 0)
end

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
        if not stopped then library:Notify({ Title = "LelHub", Content = message, Duration = 4 }) end
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
        local settings = { Title = title, Default = default }
        if kind == "Slider" then settings.Min, settings.Max, settings.Rounding = minimum, maximum, 2 end
        if kind == "Dropdown" then settings.Values, settings.Multi = minimum, false end
        local item = parent["Create" .. kind](parent, "LelReviewed_" .. name .. "_" .. sequence, settings)
        local initializing = true
        bindLelHubChange(item, function(value) if not initializing and not stopped then callback(value, item) end end)
        initializing = false
        return item
    end
    local function button(parent, title, callback)
        parent:CreateButton({ Title = title, Callback = function() if not stopped then launch(callback) end end })
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
        local section = window:CreateTab({ Title = "Collectibles", Icon = "map-pin" }):CreateSection("Pumpkins")
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
        local section = window:CreateTab({ Title = "Event Items", Icon = "package" }):CreateSection("EventFolder")
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
        local tab = window:CreateTab({ Title = "Prison", Icon = "map" })
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
        local section = window:CreateTab({ Title = "Arena", Icon = "shield" }):CreateSection("Anti Void")
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
        local section = window:CreateTab({ Title = "Collector", Icon = "leaf" }):CreateSection("Tokens")
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
        local section = window:CreateTab({ Title = "Auto Farm", Icon = "waves" }):CreateSection("Sea Farm")
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
        local section = window:CreateTab({ Title = "Interactions", Icon = "hand" }):CreateSection("Proximity Prompts")
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
    local function notify(message) library:Notify({ Title = "LelHub", Content = message, Duration = 4 }) end
    local function control(parent, kind, title, default, callback, values, maximum)
        if kind == "Slider" then callback, values, maximum = maximum, callback, values end
        serial = serial + 1
        local options = { Title = title, Default = default }
        if kind == "Slider" then options.Min, options.Max, options.Rounding = values, maximum, 2 end
        if kind == "Dropdown" then options.Values, options.Multi = values, false end
        local item = parent["Create" .. kind](parent, "LelExpanded_" .. serial, options)
        local initializing = true
        bindLelHubChange(item, function(value) if not initializing and not stopped then callback(value) end end)
        initializing = false
        return item
    end
    local function button(parent, title, callback)
        parent:CreateButton({ Title = title, Callback = function()
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
    local playerTab = configuration.ExpandedPlayerTab or window:CreateTab({ Title = "Player", Icon = "user" })
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
    local playersTab = configuration.ExpandedPlayersTab or window:CreateTab({ Title = "Players", Icon = "users" })
    local selected, follow, orbit, orbitRadius, followDistance, angle = nil, false, false, 8, 5, 0
    local orbitRoot, orbitTarget, orbitHuman, orbitAutoRotate, orbitCenter
    local smoothedRadius = orbitRadius
    local function releaseOrbit()
        if orbitHuman and orbitHuman.Parent then orbitHuman.AutoRotate = orbitAutoRotate end
        orbitRoot, orbitTarget, orbitHuman, orbitCenter = nil, nil, nil, nil
        configuration.LelHubOrbitActive = false
    end
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
    local function target()
        if configuration.GetSelectedPlayer then return configuration.GetSelectedPlayer() end
        return selected
    end
    if not configuration.GetSelectedPlayer then
        targetDropdown = control(targetSection, "Dropdown", "Target", "None", function(value) selected = players:FindFirstChild(value) end, names)
    end
    control(targetSection, "Toggle", "Follow", false, function(value) follow = value end)
    control(targetSection, "Slider", "Follow Distance", 5, 2, 30, function(value) followDistance = value end)
    control(targetSection, "Toggle", "Orbit", false, function(value)
        orbit = value
        if not value then releaseOrbit() end
    end)
    control(targetSection, "Slider", "Orbit Radius", 8, 3, 40, function(value) orbitRadius = value end)
    if not configuration.HasPlayerTeleport then
    button(targetSection, "Teleport To Player", function()
        local selected = target()
        local root = selected and rootOf(selected.Character)
        if root then return teleport(root.CFrame * CFrame.new(0, 0, followDistance)) end
        return "Select an available target."
    end)
    end
    button(targetSection, "Copy Username", function() local selected = target() if selected and setclipboard then setclipboard(selected.Name) end end)
    button(targetSection, "Copy User ID", function() local selected = target() if selected and setclipboard then setclipboard(tostring(selected.UserId)) end end)
    connect(players.PlayerAdded, function() refresh() end)
    connect(players.PlayerRemoving, refresh)
    local world = window:CreateTab({ Title = "Environment", Icon = "sun" })
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
    local orbitBinding = "LelHubOrbit_" .. game:GetService("HttpService"):GenerateGUID(false)
    runService:BindToRenderStep(orbitBinding, Enum.RenderPriority.Camera.Value - 1, function(delta)
        local selected = target()
        local other = selected and rootOf(selected.Character)
        local human, root = humanoid(), rootOf(player.Character)
        local targetHuman = selected and selected.Character and selected.Character:FindFirstChildOfClass("Humanoid")
        if stopped or library.Unloaded or not orbit or not selected or selected == player
            or selected.Parent ~= players or not other or not root or not human
            or human.Health <= 0 or human.SeatPart or human.PlatformStand or root.Anchored
            or (targetHuman and targetHuman.Health <= 0) or input:GetFocusedTextBox()
            or (configuration.IsMovementBlocked and configuration.IsMovementBlocked()) then
            releaseOrbit()
            return
        end
        if orbitRoot ~= root or orbitTarget ~= other or orbitHuman ~= human then
            releaseOrbit()
            orbitRoot, orbitTarget, orbitHuman = root, other, human
            orbitAutoRotate = human.AutoRotate
            orbitCenter, smoothedRadius = other.Position, orbitRadius
            local offset = root.Position - other.Position
            angle = math.atan2(offset.Z, offset.X)
        end
        configuration.LelHubOrbitActive = true
        human.AutoRotate = false
        human:Move(Vector3.zero, false)
        local step = math.clamp(delta, 0, 0.1)
        angle = (angle + step) % (math.pi * 2)
        orbitCenter = orbitCenter:Lerp(other.Position, 1 - math.exp(-18 * step))
        smoothedRadius = smoothedRadius + (orbitRadius - smoothedRadius) * (1 - math.exp(-12 * step))
        local position = orbitCenter + Vector3.new(math.cos(angle) * smoothedRadius, 0, math.sin(angle) * smoothedRadius)
        local frame = CFrame.lookAt(position, orbitCenter)
        root.CFrame = root.CFrame:Lerp(frame, 1 - math.exp(-16 * step))
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end)
    local elapsed = 0
    connect(runService.Heartbeat, function(delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        local human, root = humanoid(), rootOf(player.Character)
        if bunnyHop and human and human.FloorMaterial ~= Enum.Material.Air then human.Jump = true end
        if autoUse and os.clock() - lastUse >= useDelay then lastUse = os.clock() local tool = heldTool() if tool then pcall(function() tool:Activate() end) end end
        local selected = target()
        local other = selected and rootOf(selected.Character)
        if other and root and human and not human.SeatPart and human.Health > 0 then
            if not orbit and follow and (root.Position - other.Position).Magnitude > followDistance then
                human:MoveTo((other.CFrame * CFrame.new(0, 0, followDistance)).Position)
            end
        end
        if noFog then lighting.FogEnd = 1000000 for _, object in ipairs(lighting:GetChildren()) do if object:IsA("Atmosphere") then effect(object) end end end
    end)
    return function()
        if stopped then return end
        stopped = true
        runService:UnbindFromRenderStep(orbitBinding)
        releaseOrbit()
        if follow then local human = humanoid() if human then human:Move(Vector3.zero) end end
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for object in pairs(restores) do restore(object) end
        for _, object in ipairs(resources) do object:Destroy() end
    end
end

local function prepareLelHubWindow(window)
    if window.LelHubTabs then return window end
    local tabs = {}
    window.LelHubTabs = tabs
    local createTab = window.Tab or window.CreateTab or window.AddTab
    local function title(value, section)
        local text = tostring(value or ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
        if not section and text:lower() == "utilities" then text = "Player" end
        if not section and text:lower() == "environment" then text = "World" end
        if section then text = text:gsub("%s+[Oo]ptions$", "") end
        return text, text:lower():gsub("[^%w]", "")
    end
    local function create(self, configuration)
        local options = type(configuration) == "table" and configuration or { Title = configuration }
        local name, key = title(options.Title)
        if tabs[key] then return tabs[key] end
        local copy = {}
        for property, value in pairs(options) do copy[property] = value end
        copy.Title = name
        local tab = createTab(self, copy)
        tabs[key] = tab
        local sections = {}
        local createSection = tab.Section or tab.CreateSection or tab.AddSection
        local function section(parent, heading)
            local label, id = title(heading, true)
            if not sections[id] then sections[id] = createSection(parent, label) end
            return sections[id]
        end
        tab.Section, tab.CreateSection, tab.AddSection = section, section, section
        return tab
    end
    window.Tab, window.CreateTab, window.AddTab = create, create, create
    return window
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
    configuration.IsMovementBlocked = configuration.IsMovementBlocked or function() return basicFlags.Fly end
    local autoWalkBinding = "LelHubAutoWalk_" .. http:GenerateGUID(false)
    local autoWalkHumanoid
    local autoWalkDirection = Vector3.new(0, 0, -1)

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
    end

    installLelHubSpacing(window, connect)

    local function notify(message)
        if not destroyed then
            library:Notify({ Title = "LelHub", Content = message, Duration = 3 })
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

    local function releaseAutoWalk()
        if autoWalkHumanoid and autoWalkHumanoid.Parent then
            autoWalkHumanoid:Move(Vector3.zero, false)
        end
        autoWalkHumanoid = nil
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
        releaseAutoWalk()
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

    local utilityTab = configuration.PlayerTab or ui(window, "Tab", { Title = "Player", Icon = "user" })
    local movement

    if configuration.BasicMovement then
        movement = ui(utilityTab, "Section", "Movement")
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

    movement = movement or ui(utilityTab, "Section", "Movement")
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
        if not value then releaseAutoWalk() end
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
    register(places, "Input", "WaypointName", { Title = "Position name", Default = "Home", Finished = true }, function(value)
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
    waypointDropdown = register(places, "Dropdown", "Waypoint", { Title = "Saved position", Values = {}, Multi = false }, function(value)
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
    register(coordinates, "Input", "Coordinates", { Title = "Coordinates", Default = "", Placeholder = "X, Y, Z", Finished = true }, function(value)
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
        local playersTab = ui(window, "Tab", { Title = "Players", Icon = "users" })
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
        playerDropdown = register(playersTab, "Dropdown", "TargetPlayer", { Title = "Player", Values = names, Default = "Select a player", Multi = false }, function(value)
            selectedPlayer = value ~= "Select a player" and players:FindFirstChild(value) or nil
        end)
        button(playersTab, "Teleport To Player", function()
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

    if configuration.BasicMovement then
        configuration.GetSelectedPlayer = function() return selectedPlayer end
        configuration.HasPlayerTeleport = true
    end
    configuration.ExpandedPlayerTab = utilityTab
    expandedCleanup = installLelHubExpandedTools(library, window, configuration)

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
    local routes = moduleEnvironment.LelHubRoutes
    if tostring(configuration.Name):lower() == "global" and not routes then
        local ok, result = pcall(function()
            return lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/g.luau", "LelHub/Routes")()
        end)
        if ok and type(result) == "table" and type(result.P) == "table" and type(result.U) == "table" then routes = result moduleEnvironment.LelHubRoutes = routes end
    end
    local catalog = moduleEnvironment.LelHubCatalog or (routes and routes.C) or {
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
    if tostring(configuration.Name):lower() == "global" then
        local selected = routes and (routes.U[game.GameId] or routes.P[game.PlaceId])
        local file = selected and selected .. ".luau" or tostring(game.PlaceId) .. ".luau"
        for name, candidate in pairs(moduleFiles) do if candidate == file then moduleChoice = name break end end
    end
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
        local success, chunk = pcall(lelHubCompileRemote, "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/" .. file, "LelHub/" .. file)
        if not success then return "The selected hub could not download or compile. Try again." end
        closeCurrent()
        chunk()
    end)

    local function cleanup()
        if destroyed then
            return
        end

        destroyed = true
        runService:UnbindFromRenderStep(autoWalkBinding)
        releaseAutoWalk()

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
        releaseAutoWalk()
        releaseSprint()
        releaseSpin()
        stopBasicFlight()
        restoreBasicCollisions()
        restoreAccessories()
    end)
    connect(player.CharacterAdded, function(character)
        hideAccessories(character)
    end)
    runService:BindToRenderStep(autoWalkBinding, Enum.RenderPriority.Character.Value + 1, function()
        if destroyed or library.Unloaded then
            cleanup()
            return
        end
        local _, humanoid, root = parts()
        if not state.AutoWalk or not humanoid or not root or humanoid.Health <= 0
            or input:GetFocusedTextBox() or humanoid.SeatPart or humanoid.PlatformStand
            or root.Anchored or basicFlags.Fly or configuration.LelHubOrbitActive
            or (configuration.IsMovementBlocked and configuration.IsMovementBlocked()) then
            releaseAutoWalk()
            return
        end
        if autoWalkHumanoid ~= humanoid then
            releaseAutoWalk()
            autoWalkHumanoid = humanoid
        end
        local camera = workspace.CurrentCamera
        local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
        local direction = Vector3.new(look.X, 0, look.Z)
        if direction.Magnitude < 0.01 then
            look = root.CFrame.LookVector
            direction = Vector3.new(look.X, 0, look.Z)
        end
        if direction.Magnitude >= 0.01 then autoWalkDirection = direction.Unit end
        humanoid:Move(autoWalkDirection, false)
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

local function createLelHub(name)
    local environment = type(getgenv) == "function" and getgenv() or _G
    environment.LelHubModules = environment.LelHubModules or {}
    local previous = environment.LelHubModules[name]
    if previous then previous.Cleanup() end
    for _, active in pairs(environment.LelHubModules) do if active and active.Cleanup then active.Cleanup() end end
    if environment.LelHubGlobal and environment.LelHubGlobal.Cleanup then environment.LelHubGlobal.Cleanup() end
    local library = lelHubLoadInterface()
    local window = prepareLelHubWindow(library:CreateWindow({ Title = "LelHub " .. name, SubTitle = "by LelSploit", Size = UDim2.fromOffset(760, 540), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift }))
    local hub = { Library = library, Window = window, Connections = {}, Resources = {}, Tabs = {}, Controls = {}, Stopped = false }
    local serial = 0
    function hub:Connect(signal, callback)
        local connection = signal:Connect(function(...) if not self.Stopped then callback(...) end end)
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
        local tab = window:CreateTab({ Title = lelHubTitle(title), Icon = icon or "grid" })
        self.Tabs[title] = tab
        return tab
    end
    function hub:Toggle(tab, id, title, callback, default)
        local raw = tab:CreateToggle(id, { Title = lelHubTitle(title), Default = default == true })
        self.Controls[id] = raw
        bindLelHubChange(raw, function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Slider(tab, id, title, default, minimum, maximum, callback, decimals)
        local raw = tab:CreateSlider(id, { Title = lelHubTitle(title), Default = default, Min = minimum, Max = maximum, Rounding = decimals or 0 })
        self.Controls[id] = raw
        bindLelHubChange(raw, function(value) if not self.Stopped then callback(value) end end)
        return raw
    end
    function hub:Dropdown(tab, id, title, values, default, callback)
        local raw = tab:CreateDropdown(id, { Title = lelHubTitle(title), Values = values, Default = default, Multi = false })
        self.Controls[id] = raw
        bindLelHubChange(raw, function(value) if not self.Stopped then callback(value) end end)
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
        self.Tabs.Player, self.Tabs.Players = self.Shared.Player, self.Shared.Players
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
        local title = lelHubTitle(config.Title or config.Name or config.Text or "Option")
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
        local initializing = true
        bindLelHubChange(native, function(value)
            if hub.Stopped or api.Unloaded or (api.Controller and not api.Controller.Active) then return end
            control.Value = value
            if initializing then return end
            if config.Callback then config.Callback(valueForCallback(value)) end
            for _, callback in ipairs(control.Callbacks) do callback(value) end
        end)
        initializing = false
        function control:SetValue(value)
            if kind == "Dropdown" and type(value) == "table" and not spec.Multi then value = value[1] end
            if kind == "Colorpicker" and native.SetValueRGB then native:SetValueRGB(value) else native:SetValue(value) end
        end
        control.Set = control.SetValue
        function control:GetValue() return self.Value end
        control.Get = control.GetValue
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
            local key = config.CurrentKeybind or config.Default or "None"
            if typeof(key) == "EnumItem" then key = key.Name end
            local settings = { Title = config.Name or config.Title, Default = key, Mode = config.HoldToInteract and "Hold" or "Toggle" }
            if style == "Vapor" then settings.ChangedCallback = config.Callback else settings.Callback = config.Callback end
            return raw:CreateKeybind(nextId(), settings)
        end
        function group:CreateLabel(value)
            local text = type(value) == "table" and (value.Text or value.Title or value.Content) or value
            text = tostring(text or "")
            if text:lower():find("developer:", 1, true) then return status() end
            local native = raw:CreateParagraph(nextId(), { Title = "", Content = text })
            local label = { Native = native, Value = text }
            function label:Set(value)
                self.Value = tostring(type(value) == "table" and (value.Content or value.Text or value.Title or "") or value)
                native:SetValue(self.Value)
            end
            label.SetText, label.SetTitle, label.SetContent = label.Set, label.Set, label.Set
            function label:Destroy() if native.Destroy then native:Destroy() end end
            label.Remove = label.Destroy
            return label
        end
        group.AddLabel = group.CreateLabel
        for _, method in ipairs({ "CreateParagraph", "AddParagraph", "CreateDivider", "AddDivider" }) do group[method] = status end
        return group
    end
    local window = {}
    local firstGameTab = true
    function window:CreateTab(title, icon)
        if type(title) == "table" then icon, title = title.Icon, title.Title or title.Name end
        local raw = hub.Tabs[title]
        if not raw and firstGameTab and title ~= "Settings" and title ~= "Player" and title ~= "Players" then
            raw, firstGameTab = hub.Tabs.Game, false
            hub.Tabs[title] = raw
        end
        raw = raw or hub:Tab(title, type(icon) == "string" and icon or "grid")
        return wrap(raw)
    end
    window.Tab, window.AddTab = window.CreateTab, window.CreateTab
    function window:Destroy() hub.Cleanup() end
    window.Close = window.Destroy
    function window:CreateToggleKeybind(tab, config) return tab:CreateKeybind(config) end
    function window:CreateFloatingButton(config)
        local result = hub:Button(hub.Tabs.Game or hub:Tab("Game"), config.Text or config.Title or "Action", config.Callback or config.OnClick or config.ClickCallback)
        local instance = result and (result.Frame or result.Instance)
        if type(instance) == "table" then instance = instance.Frame end
        return { Instance = typeof(instance) == "Instance" and instance or nil, SetPosition = function() end, Destroy = function()
            if result and result.Destroy then result:Destroy() elseif typeof(instance) == "Instance" then instance:Destroy() end
        end }
    end
    function api:CreateWindow() return window end
    function api:Notify(config) hub:Notify(config.Content or config.Text or config.Title or "") end
    function api:Unload() api.Unloaded = true hub.Cleanup() end
    api.Destroy = api.Unload
    for _, method in ipairs({ "SetTheme", "LoadConfiguration", "SetLibrary", "BuildConfigSection", "ApplyToTab", "LoadAutoloadConfig", "IgnoreThemeSettings", "SetIgnoreIndexes", "SetFolder", "SetSaveFile" }) do api[method] = function() end end
    return api
end

local function installLelHubLifecycle(hub)
    function hub:OwnedTasks()
        local threads = {}
        local function launch(schedule, callback, ...)
            if self.Stopped then return end
            for thread in pairs(threads) do if coroutine.status(thread) == "dead" then threads[thread] = nil end end
            local args = table.pack(...)
            local thread = schedule(function()
                if self.Stopped then return end
                local ok = pcall(callback, table.unpack(args, 1, args.n))
                threads[coroutine.running()] = nil
                if not ok and not self.Stopped then self:Notify("A game routine could not start in the current game state.") end
            end)
            if coroutine.status(thread) ~= "dead" then threads[thread] = true end
            return thread
        end
        local tasks = setmetatable({
            spawn = function(callback, ...) return launch(task.spawn, callback, ...) end,
            defer = function(callback, ...) return launch(task.defer, callback, ...) end,
            delay = function(seconds, callback, ...) return launch(function(run) return task.delay(seconds, run) end, callback, ...) end,
        }, { __index = task })
        self:Add(function()
            for thread in pairs(threads) do if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then pcall(task.cancel, thread) end end
        end)
        return tasks
    end
    function hub:Loop(section, title, interval, callback)
        local enabled, busy, elapsed = false, false, 0
        local worker
        local toggle = self:Toggle(section, "Loop_" .. title, title, function(value)
            enabled = value
            elapsed = 0
            if not value and worker then pcall(task.cancel, worker) worker, busy = nil, false end
        end, false)
        self:Connect(game:GetService("RunService").Heartbeat, function(delta)
            elapsed = elapsed + delta
            if not enabled or busy or elapsed < interval() then return end
            busy, elapsed = true, 0
            worker = task.spawn(function()
                local ok = pcall(callback)
                busy, worker = false, nil
                if not ok and enabled then toggle:SetValue(false) self:Notify(title .. " is unavailable in the current game state.") end
            end)
        end)
        self:Add(function() enabled = false if worker then pcall(task.cancel, worker) end end)
        return toggle
    end
    function hub:SourceController(section, title, callback, oneShot)
        local session
        local function stop()
            if not session then return end
            session.Active = false
            for _, thread in ipairs(session.Threads) do if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then pcall(task.cancel, thread) end end
            for _, connection in ipairs(session.Connections) do pcall(function() connection:Disconnect() end) end
            for index = #session.Cleanup, 1, -1 do pcall(session.Cleanup[index]) end
            session = nil
        end
        local toggle
        local function start(value)
            stop()
            if not value then return end
            local current = { Active = true, Threads = {}, Connections = {}, Cleanup = {} }
            session = current
            function current:Add(cleanup) table.insert(self.Cleanup, cleanup) end
            function current:Connect(signal, handler)
                local connection = signal:Connect(function(...) if self.Active then handler(...) end end)
                table.insert(self.Connections, connection)
                return connection
            end
            local function launch(delay, handler, ...)
                for index = #current.Threads, 1, -1 do if coroutine.status(current.Threads[index]) == "dead" then table.remove(current.Threads, index) end end
                local args = table.pack(...)
                local thread = task.delay(delay, function()
                    if not current.Active then return end
                    local ok = pcall(handler, table.unpack(args, 1, args.n))
                    if not ok and current.Active then if toggle then toggle:SetValue(false) else stop() end hub:Notify(title .. " is unavailable in this game state or executor.") end
                end)
                table.insert(current.Threads, thread)
                return thread
            end
            local tasks = setmetatable({
                spawn = function(handler, ...) return launch(0, handler, ...) end,
                defer = function(handler, ...) return launch(0, handler, ...) end,
                delay = launch,
            }, { __index = task })
            local function hook(target, replacement)
                local original = hookfunction(target, replacement)
                current:Add(function() hookfunction(target, original) end)
                return original
            end
            local function meta(object, method, replacement)
                local original = hookmetamethod(object, method, replacement)
                current:Add(function() hookmetamethod(object, method, original) end)
                return original
            end
            tasks.spawn(callback, current, tasks, hook, meta)
        end
        if oneShot then
            self:Button(section, title == "Client Compatibility" and "Install Client Compatibility" or title, function() if not session then start(true) end end)
        else
            toggle = self:Toggle(section, "Source_" .. title, title, start, false)
        end
        self:Add(stop)
        return toggle
    end
end

local function installNativeUI(hub)
    local native = { Objects = {}, Roots = {}, Groups = {}, Controls = {}, Bindings = {}, Sequence = 0 }
    local gameTab = hub.Tabs.Game or hub:Tab("Game", "gamepad-2")
    local function id()
        native.Sequence = native.Sequence + 1
        return "Game_" .. native.Sequence
    end
    function native:Group(parent)
        local current = parent
        while current do
            if self.Groups[current] then return self.Groups[current] end
            current = current.Parent
        end
        return gameTab
    end
    function native:Page(parent, title)
        local frame = Instance.new("Frame")
        frame.Name, frame.Parent = title, parent
        self.Groups[frame] = hub.Tabs[title] or hub:Tab(title)
        table.insert(self.Objects, frame)
        return frame
    end
    function native:Section(parent, title)
        local frame = Instance.new("Frame")
        frame.Parent = parent
        self.Groups[frame] = self:Group(parent):CreateSection(title)
        table.insert(self.Objects, frame)
        return frame
    end
    function native:Control(parent, kind, title, default, callback, minimum, maximum)
        local group = self:Group(parent)
        local settings = { Title = lelHubTitle(title), Default = default }
        if kind == "Slider" then
            settings.Min, settings.Max, settings.Rounding = minimum, maximum, 2
            if title:lower():find("walk", 1, true) then settings.Min, settings.Max = 16, 500 end
        elseif kind == "Dropdown" then settings.Values, settings.Multi = minimum, false
        elseif kind == "Input" then settings.Finished = true end
        local control = group["Create" .. kind](group, id(), settings)
        local initializing = true
        bindLelHubChange(control, function(value)
            if not initializing and not hub.Stopped then callback(value) end
        end)
        initializing = false
        return control
    end
    function native:Button(parent, title, callback)
        return hub:Button(self:Group(parent), title, callback)
    end
    function native:Label(parent, title, value)
        local label = Instance.new("TextLabel")
        label.Parent, label.Text = parent, value or ""
        table.insert(self.Objects, label)
        local paragraph = self:Group(parent):CreateParagraph(id(), { Title = title, Content = label.Text })
        hub:Connect(label:GetPropertyChangedSignal("Text"), function() paragraph:SetValue(label.Text) end)
        return label
    end
    local function title(object)
        local text = object:IsA("TextButton") and object.Text or object:IsA("TextBox") and object.PlaceholderText or ""
        if text == "" then
            local parent = object.Parent
            for _ = 1, 2 do
                if not parent then break end
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text ~= "" and #child.Text < 100 then text = child.Text break end
                end
                if text ~= "" then break end
                parent = parent.Parent
            end
        end
        return lelHubTitle(text ~= "" and text or object.Name)
    end
    local ignored = { X=true, ["×"]=true, ["✕"]=true, ["−"]=true, Close=true, Menu=true, Main=true, Settings=true, Credits=true, Combat=true, Movement=true, Visuals=true, Farming=true, Misc=true, Rage=true, Tracker=true, Teleports=true }
    local ignoredNames = {closebtn=true,closebutton=true,btnclose=true,hidebtn=true,openbutton=true,reopenbtn=true,mainbtn=true,trackbtn=true,telebtn=true,tabbtn=true,catbutton=true}
    function native:Bind(object, event, alias, callback)
        if type(alias) == "function" then callback, alias = alias, nil end
        local connection = hub:Connect(object[event], callback)
        local root = object:FindFirstAncestorWhichIsA("ScreenGui")
        if not root or not self.Roots[root] then return connection end
        self.Roots[root].Menu = true
        root.Enabled = false
        local bindings = self.Bindings[object] or {}
        self.Bindings[object] = bindings
        bindings[event] = bindings[event] or {}
        table.insert(bindings[event], callback)
        task.defer(function()
            if hub.Stopped or self.Controls[object] or not object.Parent then return end
            if alias and ignoredNames[alias:lower()] then return end
            local label = title(object)
            if ignored[label] then return end
            if event == "FocusLost" and object:IsA("TextBox") then
                self.Controls[object] = self:Control(object.Parent, "Input", label, object.Text, function(value)
                    object.Text = tostring(value)
                    for _, handler in ipairs(bindings.FocusLost) do handler(true) end
                end)
            elseif object:IsA("GuiButton") then
                self.Controls[object] = self:Button(object.Parent, label, function()
                    local handlers = bindings.Activated or bindings.MouseButton1Click or bindings.MouseButton1Down or {}
                    for _, handler in ipairs(handlers) do handler() end
                end)
                if object:IsA("TextButton") then hub:Connect(object:GetPropertyChangedSignal("Text"), function()
                    local control = self.Controls[object]
                    if control and control.SetTitle then control:SetTitle(title(object)) end
                end) end
            end
        end)
        return connection
    end
    native.Instance = { new = function(class, parent)
        local object = Instance.new(class, parent)
        table.insert(native.Objects, object)
        if object:IsA("ScreenGui") then
            native.Roots[object] = { Menu = false }
            hub:Connect(object:GetPropertyChangedSignal("Enabled"), function()
                if native.Roots[object].Menu and object.Enabled then object.Enabled = false end
            end)
        end
        return object
    end }
    hub:Add(function()
        for index = #native.Objects, 1, -1 do pcall(function() native.Objects[index]:Destroy() end) end
    end)
    return native
end

return function(name)
    local hub = createLelHub(name)
    hub.Native = installNativeUI(hub)
    function hub:Interface(style) return createGameInterface(self, style) end
    function hub:Input(title, default, callback)
        return self.Native:Control(nil, "Input", title, default, callback)
    end
    installLelHubLifecycle(hub)
    hub:Finish()
    return hub
end
