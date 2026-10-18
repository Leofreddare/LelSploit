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
    control(targetSection, "Toggle", "Orbit", false, function(value) orbit = value end)
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
    local elapsed = 0
    connect(runService.Heartbeat, function(delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        local step = elapsed
        elapsed = 0
        local human, root = humanoid(), rootOf(player.Character)
        if bunnyHop and human and human.FloorMaterial ~= Enum.Material.Air then human.Jump = true end
        if autoUse and os.clock() - lastUse >= useDelay then lastUse = os.clock() local tool = heldTool() if tool then pcall(function() tool:Activate() end) end end
        local selected = target()
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
    local library = lelHubLoadInterface()
    local window = prepareLelHubWindow(library:CreateWindow({
        Title = lelHubTitle("LelHub Drive A Kukirin"),
        SubTitle = "by LelSploit",
        TabWidth = 160,
        Size = UDim2.fromOffset(670, 460),
        Resize = true,
        MinSize = Vector2.new(480, 360),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightShift,
    }))

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
        local tab = window:CreateTab({ Title = lelHubTitle(title), Icon = icon })
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
        local raw = section:CreateToggle(flag, { Title = lelHubTitle(title), Default = false })
        local control = {
            Raw = raw,
            Type = "Toggle",
            __type = "Toggle",
            Value = false,
        }

        bindLelHubChange(raw, function(value)
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
        return section:CreateButton({ Title = lelHubTitle(title), Callback = callback })
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
    local scope = createScope()
    local controller = {
        Enabled = false,
        Generation = 0,
        Status = "Stopped",
        ActivePrompt = nil,
        HasCompletedDelivery = false,
    }
    local lastNotice = -math.huge

    local function characterParts()
        local character = context.Player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0 and root then
            return character, humanoid, root
        end
    end

    local function active(generation)
        return controller.Enabled and controller.Generation == generation and not context.Destroying
    end

    local function pause(duration, generation)
        local deadline = os.clock() + duration

        while active(generation) and os.clock() < deadline do
            task.wait(math.min(0.1, deadline - os.clock()))
        end

        return active(generation)
    end

    local function findPrompt(parent, name)
        local object = findNamed(parent, name)

        if object and object:IsA("ProximityPrompt") then
            return object
        end

        return object and object:FindFirstChildWhichIsA("ProximityPrompt", true) or nil
    end

    local function findWorkerRoot()
        local worker = findNamed(context.Workspace, "Worker")
        local root = findNamed(worker, "HumanoidRootPart")
        return root and root:IsA("BasePart") and root or nil
    end

    local function findJobPrompt()
        local job = findNamed(context.Workspace, "DeliveryJOB")
        local prompt = findPrompt(job, "DeliveryJobPrompt")

        if prompt then
            return prompt
        end

        if job then
            if job:IsA("ProximityPrompt") then
                return job
            end

            prompt = job:FindFirstChildWhichIsA("ProximityPrompt", true)

            if prompt then
                return prompt
            end
        end

        return findPrompt(findNamed(context.Workspace, "Worker"), "DeliveryJobPrompt")
    end

    local function deliveryTarget()
        for _, npc in ipairs(context.Workspace:GetChildren()) do
            if npc:IsA("Model") and npc.Name:match("^NPC%s*%d+$") then
                local root = npc:FindFirstChild("HumanoidRootPart")
                local prompt = findPrompt(root, "DeliverPrompt")

                if root and root:IsA("BasePart") and prompt and prompt.Enabled then
                    return root, prompt
                end
            end
        end
    end

    local function setWaiting(message)
        controller.Status = message

        if os.clock() - lastNotice >= 10 then
            lastNotice = os.clock()
            context.Notify({ Title = lelHubTitle("Delivery Farm"), Content = message, Duration = 3 })
        end
    end

    local stabilityScope = createScope()
    local stabilityState

    local function restoreCharacter()
        stabilityScope:Clean()
        local saved = stabilityState
        stabilityState = nil

        if not saved then
            return
        end

        if saved.Root.Parent then
            saved.Root.Anchored = saved.Anchored
        end

        if saved.Humanoid.Parent then
            saved.Humanoid.AutoRotate = saved.AutoRotate
        end

        for part, canCollide in pairs(saved.Collisions) do
            if part.Parent then
                part.CanCollide = canCollide
            end
        end
    end

    local function stabilizeCharacter(character, humanoid, root)
        if stabilityState and stabilityState.Character ~= character then
            restoreCharacter()
        end

        if not stabilityState then
            stabilityState = {
                Character = character,
                Humanoid = humanoid,
                Root = root,
                Anchored = root.Anchored,
                AutoRotate = humanoid.AutoRotate,
                Collisions = {},
            }

            local saved = stabilityState
            local function disableCollision(part)
                if part:IsA("BasePart") then
                    if saved.Collisions[part] == nil then
                        saved.Collisions[part] = part.CanCollide
                    end

                    part.CanCollide = false
                end
            end

            for _, part in ipairs(character:GetDescendants()) do
                disableCollision(part)
            end

            stabilityScope:Connect(character.DescendantAdded, disableCollision)
        end

        if not stabilityState.Velocity or not stabilityState.Velocity.Parent then
            local velocity = Instance.new("BodyVelocity")
            velocity.Name = "LelHubDeliveryStabilizer"
            velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            velocity.P = 15000
            velocity.Velocity = Vector3.zero
            velocity.Parent = root
            stabilityState.Velocity = stabilityScope:Add(velocity)
        end

        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        humanoid.AutoRotate = false
        return stabilityState
    end

    local function maintainStability()
        local saved = stabilityState

        if not saved then
            return
        end

        if context.Player.Character ~= saved.Character or not saved.Root.Parent or saved.Humanoid.Health <= 0 then
            restoreCharacter()
            return
        end

        saved.Root.Anchored = false
        saved.Humanoid.AutoRotate = false
        saved.Root.AssemblyLinearVelocity = Vector3.zero
        saved.Root.AssemblyAngularVelocity = Vector3.zero

        for part in pairs(saved.Collisions) do
            if part.Parent then
                part.CanCollide = false
            end
        end

        if saved.Velocity and saved.Velocity.Parent then
            saved.Velocity.Velocity = Vector3.zero
        else
            stabilizeCharacter(saved.Character, saved.Humanoid, saved.Root)
        end
    end

    local function moveNear(target, generation, standOff, tolerance)
        local character, humanoid, root = characterParts()

        if not character or not target.Parent then
            return false
        end

        if root:FindFirstChild("ScooterMountWeld") then
            pcall(sendScooterInput, context, 0, true)

            if not pause(0.4, generation) then
                return false
            end
        end

        if humanoid.SeatPart then
            humanoid.Sit = false

            if not pause(0.25, generation) then
                return false
            end
        end

        if not active(generation) or context.Player.Character ~= character or not root.Parent or not target.Parent then
            return false
        end

        if root:FindFirstChild("ScooterMountWeld") or humanoid.SeatPart then
            setWaiting("Waiting to dismount before teleporting.")
            return false
        end

        local saved = stabilizeCharacter(character, humanoid, root)

        for _ = 1, 3 do
            if not active(generation) or context.Player.Character ~= character or not root.Parent or not target.Parent then
                return false
            end

            local targetFrame = target:IsA("Attachment") and target.WorldCFrame or target.CFrame
            saved.TargetFrame = targetFrame * CFrame.new(0, 0, standOff or 2)
            character:PivotTo(saved.TargetFrame * root.CFrame:Inverse() * character:GetPivot())
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            if not pause(0.05, generation) or context.Player.Character ~= character then
                return false
            end

            if root.Parent and (root.Position - saved.TargetFrame.Position).Magnitude <= (tolerance or 1.5) then
                return true
            end
        end

        setWaiting("Direct teleport did not reach the destination; retrying.")
        return false
    end

    local function interact(prompt, fallback, generation, attempt)
        if not active(generation) or not prompt.Parent or not prompt.Enabled or not characterParts() then
            return false
        end

        local anchor = prompt.Parent

        while anchor and not anchor:IsA("BasePart") and not anchor:IsA("Attachment") do
            anchor = anchor.Parent
        end

        anchor = anchor or fallback
        local range = math.max(0.5, prompt.MaxActivationDistance)

        if not anchor or not moveNear(anchor, generation, math.min(2, range * 0.4), math.min(0.75, range * 0.2)) then
            return false
        end

        if not prompt.Parent or not prompt.Enabled then
            return false
        end

        if not pause(0.25, generation) or not prompt.Parent or not prompt.Enabled then
            return false
        end

        local _, _, root = characterParts()
        local anchorFrame = anchor:IsA("Attachment") and anchor.WorldCFrame or anchor.CFrame

        if not root or (root.Position - anchorFrame.Position).Magnitude > range then
            return false
        end

        local success, message = pcall(function()
            local holdDuration = math.max(0, prompt.HoldDuration)

            if type(fireproximityprompt) == "function" and (attempt or 1) % 2 == 0 then
                fireproximityprompt(prompt, holdDuration)
            else
                controller.ActivePrompt = prompt
                prompt:InputHoldBegin()

                if not pause(holdDuration + 0.15, generation) then
                    return
                end

                prompt:InputHoldEnd()
                controller.ActivePrompt = nil
            end
        end)

        if not success then
            if controller.ActivePrompt then
                pcall(function()
                    controller.ActivePrompt:InputHoldEnd()
                end)
                controller.ActivePrompt = nil
            end

        end

        return success and active(generation)
    end

    local function readJobCountdown()
        local playerGui = context.Player:FindFirstChildOfClass("PlayerGui")
        local deliveryUI = playerGui and playerGui:FindFirstChild("DeliveryUI")
        local toast = deliveryUI and deliveryUI:FindFirstChild("Toast")

        if not toast then
            return nil
        end

        local objects = { toast }

        for _, descendant in ipairs(toast:GetDescendants()) do
            table.insert(objects, descendant)
        end

        for _, object in ipairs(objects) do
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                local visible = true
                local ancestor = object

                while ancestor and ancestor ~= playerGui do
                    if ancestor:IsA("GuiObject") and not ancestor.Visible then
                        visible = false
                        break
                    end

                    ancestor = ancestor.Parent
                end

                local text = object.Text:gsub("<[^>]*>", ""):lower()
                local seconds = tonumber(text:match("next%s+job%s+in%s+(%d+%.?%d*)%s*s"))

                if visible and seconds then
                    return seconds
                end
            end
        end
    end

    local function requestJob(workerRoot, generation)
        for attempt = 1, 4 do
            if not active(generation) then
                return nil
            end

            local root, deliveryPrompt = deliveryTarget()

            if root then
                return root, deliveryPrompt
            end

            local jobPrompt = findJobPrompt()

            if not jobPrompt or not jobPrompt.Enabled then
                setWaiting(jobPrompt and "Worker job prompt is disabled; waiting for it to enable."
                    or "At Worker; waiting for DeliveryJOB's job prompt to load.")

                if not pause(0.5, generation) then
                    return nil
                end
            elseif interact(jobPrompt, workerRoot, generation, attempt) then
                controller.Status = "Checking Worker response"
                local deadline = os.clock() + 1.5
                local cooldownDeadline

                repeat
                    root, deliveryPrompt = deliveryTarget()

                    if root then
                        return root, deliveryPrompt
                    end

                    local seconds = controller.HasCompletedDelivery and readJobCountdown() or nil

                    if seconds and not cooldownDeadline then
                        cooldownDeadline = os.clock() + seconds + 0.5
                    end

                    if not pause(0.1, generation) then
                        return nil
                    end
                until os.clock() >= deadline

                if cooldownDeadline then
                    controller.Status = "Waiting for the next delivery job"

                    while active(generation) and os.clock() < cooldownDeadline do
                        root, deliveryPrompt = deliveryTarget()

                        if root then
                            return root, deliveryPrompt
                        end

                        if not pause(math.min(0.1, cooldownDeadline - os.clock()), generation) then
                            return nil
                        end
                    end

                    return nil
                end
            end
        end

        setWaiting("Worker interaction was not confirmed; retrying the job prompt.")
        return nil
    end

    local function completeDelivery(targetRoot, prompt, generation)
        for attempt = 1, 4 do
            if not active(generation) then
                return false
            end

            if not prompt.Parent or not prompt.Enabled then
                return true
            end

            if interact(prompt, targetRoot, generation, attempt) then
                controller.Status = "Confirming NPC delivery"
                local deadline = os.clock() + 1.5

                repeat
                    if not prompt.Parent or not prompt.Enabled then
                        return true
                    end

                    if not pause(0.1, generation) then
                        return false
                    end
                until os.clock() >= deadline
            end
        end

        setWaiting("NPC delivery was not confirmed; staying here to retry.")
        return false
    end

    local function runDelivery(generation)
        local targetRoot, prompt = deliveryTarget()

        if not targetRoot then
            local workerRoot = findWorkerRoot()

            if not workerRoot then
                setWaiting("Worker.HumanoidRootPart is not loaded yet.")
                pause(1, generation)
                return
            end

            controller.Status = "Moving to Worker to accept a job"

            if not moveNear(workerRoot, generation) then
                return
            end

            controller.Status = "Accepting delivery job from Worker"
            targetRoot, prompt = requestJob(workerRoot, generation)
        end

        if not targetRoot or not active(generation) then
            return
        end

        controller.Status = "Delivering to " .. targetRoot.Parent.Name

        if not moveNear(targetRoot, generation) or not prompt.Parent or not prompt.Enabled then
            return
        end

        controller.Status = "Waiting 4.5 seconds before interacting with the delivery NPC"

        if not pause(4.5, generation) or not targetRoot.Parent or not prompt.Parent or not prompt.Enabled then
            return
        end

        if not completeDelivery(targetRoot, prompt, generation) then
            return
        end

        controller.HasCompletedDelivery = true
        controller.Status = "Returning to Worker"
        local workerRoot = findWorkerRoot()

        if workerRoot and workerRoot:IsA("BasePart") then
            if not moveNear(workerRoot, generation) then
                return
            end
        end

        if workerRoot and active(generation) then
            controller.Status = "Checking next job wait time with Worker"
            requestJob(workerRoot, generation)
        end
    end

    function controller:Stop()
        local wasEnabled = self.Enabled
        self.Enabled = false
        self.Generation = self.Generation + 1
        self.Status = "Stopped"

        if self.ActivePrompt then
            pcall(function()
                self.ActivePrompt:InputHoldEnd()
            end)
            self.ActivePrompt = nil
        end

        scope:Clean()
        restoreCharacter()

        if wasEnabled then
            context.Notify({ Title = lelHubTitle("Delivery Farm"), Content = "Stopped", Duration = 2 })
        end
    end

    function controller:Start()
        if self.Enabled or context.Destroying then
            return
        end

        self.Enabled = true
        self.Generation = self.Generation + 1
        self.Status = "Starting delivery farm"
        self.HasCompletedDelivery = false
        local generation = self.Generation
        context.Notify({ Title = lelHubTitle("Delivery Farm"), Content = "Delivery loop started. Waiting only for the game's job countdown between deliveries.", Duration = 4 })

        scope:Connect(context.RunService.PreSimulation, maintainStability)
        scope:Connect(context.Player.CharacterRemoving, restoreCharacter)

        scope:Spawn(function()
            local success, message = xpcall(function()
                while active(generation) do
                    if characterParts() then
                        runDelivery(generation)
                    else
                        controller.Status = "Waiting for your character"
                    end

                    if not pause(0.25, generation) then
                        return
                    end
                end
            end, describeError)

            if not success and active(generation) then
                controller:Stop()
                context.Notify({ Title = lelHubTitle("Delivery Farm"), Content = "Stopped after an error. Check the console for details.", Duration = 5 })
            end
        end)
    end

    function controller:Destroy()
        self:Stop()
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
    local lastDashboardScan = -math.huge
    local retryAfter = -math.huge
    local multiplier = 1
    local refreshing = false
    local started = false
    local destroyed = false
    local requestRefresh
    local renderBinding = "LelSpeedDisplay_" .. tostring(context.Player.UserId)

    local function reportError()
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

    local function mountedScooter()
        local model = findMountedScooter(context.Player)
        while model and model ~= context.Workspace do
            if model:IsA("Model") and model:IsDescendantOf(context.Workspace) and ownsScooter(context.Player, model) then return model end
            model = model.Parent
        end
    end

    local function liveDashboard(root, owner)
        return root and root:IsDescendantOf(context.Workspace)
            and owner and owner:IsDescendantOf(context.Workspace)
            and ownerMatches(context.Player, owner)
    end

    local function resolveDashboard()
        local mounted = mountedScooter()
        local search = mounted and mounted:IsDescendantOf(context.Workspace) and mounted or context.Workspace
        for _, owner in ipairs(search:GetDescendants()) do
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

    end

    local function bindDashboard(root, frames, owner)
        resetDashboard()

        if not root or #frames == 0 then
            return
        end

        dashboardRoot = root
        dashboardOwner = owner
        local function invalidate()
            if dashboardRoot == root and not liveDashboard(root, owner) then
                resetDashboard()
                lastDashboardScan, retryAfter = -math.huge, -math.huge
            end
        end
        digitEvents:Connect(root.AncestryChanged, invalidate)
        if owner then
            digitEvents:Connect(owner.AncestryChanged, invalidate)
            local property = owner:IsA("ValueBase") and "Value" or "Text"
            digitEvents:Connect(owner:GetPropertyChangedSignal(property), invalidate)
        end

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

        if not liveDashboard(dashboardRoot, dashboardOwner) then
            if dashboardRoot then resetDashboard() lastDashboardScan = -math.huge end
            return
        end
        if #digitFrames == 0 then return end

        for _, digit in ipairs(digitFrames) do
            if not digit.Frame:IsDescendantOf(dashboardRoot) then
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
        local interval = dashboardRoot and #digitFrames > 0 and 1 or 0.5

        if now - lastDashboardScan < interval then
            return
        end

        lastDashboardScan = now
        local root, owner = dashboardRoot, dashboardOwner

        local mounted = mountedScooter()
        if not liveDashboard(root, owner) or (mounted and owner and not owner:IsDescendantOf(mounted)) then
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

        lifetime:Connect(context.Workspace.DescendantAdded, function(object)
            local name = object.Name:lower()
            if name == "scooterowner" or name == "realdash" or name:match("^digit") then
                lastDashboardScan, retryAfter = -math.huge, -math.huge
            end
        end)
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
        Title = lelHubTitle("Speed Multiplier"),
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

    interface:AddToggle(farmSection, "Auto Farm Deliveries", "AutoFarm_Enabled", function(enabled)
        if enabled then
            autoFarm:Start()
        else
            autoFarm:Stop()
        end
    end)

    local values = playerControls.Values
    local movementSliders = {
        {
            Title = lelHubTitle("WalkSpeed"),
            Property = "WalkSpeed",
            Flag = "IY_WalkSpeed",
            Minimum = 16,
            Maximum = 500,
            Default = math.clamp(values.WalkSpeed, 16, 500),
        },
        {
            Title = lelHubTitle("Jump Power"),
            Property = "JumpPower",
            Flag = "IY_JumpPower",
            Minimum = 0,
            Maximum = 500,
            Default = values.JumpPower,
        },
        {
            Title = lelHubTitle("Hip Height"),
            Property = "HipHeight",
            Flag = "IY_HipHeight",
            Minimum = -5,
            Maximum = math.max(50, values.HipHeight),
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
        Title = lelHubTitle("FOV"),
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
    local shared = installLelHubControls(interface.Library, interface.Window, {
        Name = "kukirin",
        PlayerTab = interface.Tabs.Player,
        Cleanup = hub.Cleanup,
    })
    lifetime:Add(shared.Cleanup)
    hub.SharedControls = shared
    speedDisplay:Start()
    return hub
end

return launch()
