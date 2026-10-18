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


local function createLelHub(name)
    local environment = type(getgenv) == "function" and getgenv() or _G
    environment.LelHubModules = environment.LelHubModules or {}
    local previous = environment.LelHubModules[name]
    if previous then previous.Cleanup() end
    for _, active in pairs(environment.LelHubModules) do if active and active.Cleanup then active.Cleanup() end end
    if environment.LelHubGlobal and environment.LelHubGlobal.Cleanup then environment.LelHubGlobal.Cleanup() end
    local library = lelHubLoadInterface()
    local window = prepareLelHubWindow(library:CreateWindow({ Title = lelHubTitle("LelHub Fluxo PVP"), SubTitle = "by LelSploit", Size = UDim2.fromOffset(760, 540), MinSize = Vector2.new(480, 360), TabWidth = 155, Resize = true, Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.RightShift }))
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


local function createRayfieldCompatibility(name)
    local hub = createLelHub(name)
    local api = { Hub = hub }
    local count = 0
    function api:Notify(configuration) hub:Notify(configuration.Content or configuration.Title or "") end
    function api:Destroy() hub.Cleanup() end
    function api:LoadConfiguration() end
    function api:CreateWindow()
        local window = {}
        function window:CreateTab(title)
            local raw = hub:Tab(title, "grid")
            local tab = {}
            local function key(options)
                count = count + 1
                return options.Flag or name .. "_" .. count
            end
            function tab:CreateSection(title) return raw:CreateSection(title) end
            function tab:CreateLabel() return {} end
            function tab:CreateParagraph() return {} end
            function tab:CreateToggle(options)
                return hub:Toggle(raw, key(options), options.Name, options.Callback, options.CurrentValue)
            end
            function tab:CreateSlider(options)
                local increment = options.Increment or 1
                local minimum, maximum = options.Range[1], options.Range[2]
                if options.Name:lower():find("walk", 1, true) then minimum, maximum = 16, 500 end
                local rounding = math.max(0, math.ceil(-math.log(increment) / math.log(10)))
                return hub:Slider(raw, key(options), options.Name, options.CurrentValue or minimum, minimum, maximum, options.Callback, rounding)
            end
            function tab:CreateDropdown(options)
                local multi = options.MultipleOptions == true
                local current = options.CurrentOption or {}
                local default = multi and {} or current[1]
                if multi then for _, value in ipairs(current) do default[value] = true end end
                local control = raw:CreateDropdown(key(options), { Title = options.Name, Values = options.Options or {}, Default = default, Multi = multi })
                control:OnChanged(function(value)
                    local values = {}
                    if multi then for item, enabled in pairs(value or {}) do if enabled then table.insert(values, item) end end
                    elseif value ~= nil then values[1] = value end
                    if options.Callback then options.Callback(values) end
                end)
                return control
            end
            function tab:CreateInput(options)
                local control = raw:CreateInput(key(options), { Title = options.Name, Default = options.CurrentValue or "", Placeholder = options.PlaceholderText or "", Finished = true })
                control:OnChanged(function(value) if options.Callback then options.Callback(value) end end)
                return control
            end
            function tab:CreateButton(options) return hub:Button(raw, options.Name, options.Callback) end
            return tab
        end
        api.Window = window
        return window
    end
    function api:Finish(configuration) return hub:Finish(configuration) end
    return api
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace:FindFirstChild("CustomCamera")
if not Camera or not Camera:IsA("Camera") then
    Camera = Workspace.CurrentCamera
end

local Rayfield
local function LoadRayfield()
    Rayfield = createRayfieldCompatibility("Fluxo_PVP")
end
LoadRayfield()

local Settings = {
    AimEnabled  = true,
    AimKey      = Enum.UserInputType.MouseButton2,
    FOV         = 150,
    Smoothness  = 1.0,
    YOffset     = 1.5,
    VisCheck    = false,
    TeamCheck   = false,
    AutoSwitch  = true,
    OverrideCam = false,

    ESPEnabled  = true,
    ESPBoxes    = true,
    ESPTracers  = true,
    ESPInfo     = true,
    ESPDrawFOV  = true,
    ESPMaxDist  = 5000,
    ESPBoxScale = 1.5,

    HitboxEnabled      = false,
    HitboxSize         = 10,
    HitboxTransparency = 0.6,

    Notifications = true,
}

local CurrentTarget  = nil
local HoldingAim     = false
local ESPTable       = {}
local ScriptActive   = true

local FOVDraw = Drawing.new("Circle")
FOVDraw.Thickness    = 1
FOVDraw.NumSides     = 64
FOVDraw.Filled       = false
FOVDraw.ZIndex       = 1
FOVDraw.Transparency = 1
FOVDraw.Color        = Color3.fromRGB(255, 255, 255)

local TargetDraw = Drawing.new("Circle")
TargetDraw.Thickness = 2.5
TargetDraw.NumSides  = 32
TargetDraw.Filled    = false
TargetDraw.ZIndex    = 5
TargetDraw.Color     = Color3.fromRGB(255, 50, 50)

local function Notify(text)
    if not Settings.Notifications then return end
    pcall(function()
        Rayfield:Notify({
            Title    = "VoidScripts",
            Content  = text,
            Duration = 4,
            Image    = 4483362458,
        })
    end)
end

local function IsAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetAimPart(char)
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function GetAimPosition(part)
    return part.Position + Vector3.new(0, Settings.YOffset, 0)
end

local function GetHealth(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        return math.floor(hum.Health), math.floor(hum.MaxHealth)
    end
    return 0, 100
end

local function IsVisible(character, worldPos)
    if not Settings.VisCheck then return true end
    local origin    = Camera.CFrame.Position
    local direction = worldPos - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, direction, rayParams)
    if result and result.Instance then
        return result.Instance:IsDescendantOf(character)
    end
    return true
end

local function IsTargetValid(player)
    if player == LocalPlayer then return false end
    if Settings.TeamCheck and player.Team == LocalPlayer.Team then return false end
    return true
end

local function GetESP(player)
    if not ESPTable[player] then
        local box = Drawing.new("Square")
        box.Thickness = 1
        box.Filled    = false
        box.Visible   = false

        local tracer = Drawing.new("Line")
        tracer.Thickness = 1
        tracer.Visible   = false

        local info = Drawing.new("Text")
        info.Size    = 13
        info.Center  = true
        info.Outline = true
        info.Font    = 2
        info.Visible = false

        ESPTable[player] = { Box = box, Tracer = tracer, Info = info }
    end
    return ESPTable[player]
end

local function RemoveESP(player)
    local data = ESPTable[player]
    if data then
        data.Box:Remove()
        data.Tracer:Remove()
        data.Info:Remove()
        ESPTable[player] = nil
    end
end

local function GetClosestPlayer()
    local screenCenter = Camera.ViewportSize / 2
    local closest      = nil
    local closestDist  = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if IsTargetValid(player) then
            local char = player.Character
            local part = char and GetAimPart(char)
            if part and IsAlive(char) then
                local aimPos = GetAimPosition(part)
                local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                if onScreen then
                    local screenDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                    if screenDist <= Settings.FOV and IsVisible(char, aimPos) then
                        local dist3D = (part.Position - Camera.CFrame.Position).Magnitude
                        if dist3D < closestDist then
                            closestDist = dist3D
                            closest = {
                                Player   = player,
                                Part     = part,
                                Position = pos,
                                Distance = dist3D,
                                Notified = false,
                            }
                        end
                    end
                end
            end
        end
    end

    return closest
end

local function RecursiveFindTools(folder, path, results)
    results = results or {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Tool") then
            table.insert(results, { Path = path .. obj.Name, Tool = obj })
        elseif obj:IsA("Folder") or obj:IsA("Model") then
            RecursiveFindTools(obj, path .. obj.Name .. ".", results)
        end
    end
    return results
end

local function GiveTool(tool, path)
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then
        Notify("No backpack found!")
        return
    end
    local clone = tool:Clone()
    clone.Parent = bp
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and char and not char:FindFirstChildOfClass("Tool") then
        pcall(function() hum:EquipTool(clone) end)
    end
    Notify("Gave: " .. tostring(path))
end

local AimKeyMap = {
    ["Right Mouse"]  = Enum.UserInputType.MouseButton2,
    ["Left Mouse"]   = Enum.UserInputType.MouseButton1,
    ["Middle Mouse"] = Enum.UserInputType.MouseButton3,
    ["Left Shift"]   = Enum.KeyCode.LeftShift,
    ["Left Alt"]     = Enum.KeyCode.LeftAlt,
    ["Left Control"] = Enum.KeyCode.LeftControl,
    ["E"]            = Enum.KeyCode.E,
    ["Q"]            = Enum.KeyCode.Q,
    ["F"]            = Enum.KeyCode.F,
    ["C"]            = Enum.KeyCode.C,
    ["V"]            = Enum.KeyCode.V,
    ["X"]            = Enum.KeyCode.X,
    ["Z"]            = Enum.KeyCode.Z,
    ["T"]            = Enum.KeyCode.T,
}
local AimKeyOptions = {
    "Right Mouse", "Left Mouse", "Middle Mouse", "Left Shift", "Left Alt",
    "Left Control", "E", "Q", "F", "C", "V", "X", "Z", "T",
}

local BuildUI

local function ReloadUI()
    if Rayfield then
        pcall(function() Rayfield:Destroy() end)
    end
    LoadRayfield()
    BuildUI()
    Rayfield:Finish()
end

function BuildUI()
    local Window = Rayfield:CreateWindow({
        Name             = "Void Scripts | FluxoPVP",
        LoadingTitle     = "Void Scripts",
        LoadingSubtitle  = "FluxoPVP Edition",
        ConfigurationSaving = {
            Enabled    = true,
            FolderName = "VoidScripts",
            FileName   = "VoidScriptsConfig",
        },
        KeySystem = false,
    })

    local AimTab    = Window:CreateTab("Aim", 4483362458)
    local ESPTab    = Window:CreateTab("ESP", 4483362458)
    local HitboxTab = Window:CreateTab("Hitbox", 4483362458)
    local GunTab    = Window:CreateTab("Guns", 4483362458)
    local MiscTab   = Window:CreateTab("Misc", 4483362458)

    AimTab:CreateSection("Aimbot")

    AimTab:CreateToggle({
        Name         = "Enable Aim Lock",
        CurrentValue = Settings.AimEnabled,
        Flag         = "AimEnabled",
        Callback     = function(v)
            Settings.AimEnabled = v
            Notify("Aim: " .. tostring(v))
        end,
    })

    AimTab:CreateSlider({
        Name         = "FOV Radius",
        Range        = { 10, 800 },
        Increment    = 1,
        Suffix       = "px",
        CurrentValue = Settings.FOV,
        Flag         = "AimFOV",
        Callback     = function(v) Settings.FOV = v end,
    })

    AimTab:CreateSlider({
        Name         = "Smoothness (1 = Hard Lock)",
        Range        = { 0.01, 1 },
        Increment    = 0.01,
        Suffix       = "",
        CurrentValue = Settings.Smoothness,
        Flag         = "AimSmoothness",
        Callback     = function(v) Settings.Smoothness = v end,
    })

    AimTab:CreateSlider({
        Name         = "Y-Offset",
        Range        = { 0, 5 },
        Increment    = 0.1,
        Suffix       = "studs",
        CurrentValue = Settings.YOffset,
        Flag         = "AimYOffset",
        Callback     = function(v) Settings.YOffset = v end,
    })

    AimTab:CreateSection("Filters")

    AimTab:CreateToggle({
        Name         = "Visibility Check",
        CurrentValue = Settings.VisCheck,
        Flag         = "AimVisCheck",
        Callback     = function(v) Settings.VisCheck = v end,
    })

    AimTab:CreateToggle({
        Name         = "Team Check",
        CurrentValue = Settings.TeamCheck,
        Flag         = "AimTeamCheck",
        Callback     = function(v) Settings.TeamCheck = v end,
    })

    AimTab:CreateToggle({
        Name         = "Auto Switch Target",
        CurrentValue = Settings.AutoSwitch,
        Flag         = "AimAutoSwitch",
        Callback     = function(v) Settings.AutoSwitch = v end,
    })

    AimTab:CreateToggle({
        Name         = "Override Camera",
        CurrentValue = Settings.OverrideCam,
        Flag         = "AimOverrideCam",
        Callback     = function(v) Settings.OverrideCam = v end,
    })

    AimTab:CreateSection("Input")

    AimTab:CreateDropdown({
        Name           = "Aim Key",
        Options        = AimKeyOptions,
        CurrentOption  = { "Right Mouse" },
        MultipleOptions = false,
        Flag           = "AimKeyDropdown",
        Callback       = function(Option)
            local name = type(Option) == "table" and Option[1] or Option
            local mapped = AimKeyMap[name]
            if mapped then
                Settings.AimKey = mapped
                Notify("Aim key set to " .. name)
            end
        end,
    })

    ESPTab:CreateSection("Visuals")

    ESPTab:CreateToggle({
        Name         = "Master ESP",
        CurrentValue = Settings.ESPEnabled,
        Flag         = "ESPEnabled",
        Callback     = function(v) Settings.ESPEnabled = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Boxes",
        CurrentValue = Settings.ESPBoxes,
        Flag         = "ESPBoxes",
        Callback     = function(v) Settings.ESPBoxes = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Tracers",
        CurrentValue = Settings.ESPTracers,
        Flag         = "ESPTracers",
        Callback     = function(v) Settings.ESPTracers = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Player Info",
        CurrentValue = Settings.ESPInfo,
        Flag         = "ESPInfo",
        Callback     = function(v) Settings.ESPInfo = v end,
    })

    ESPTab:CreateToggle({
        Name         = "Draw FOV Circle",
        CurrentValue = Settings.ESPDrawFOV,
        Flag         = "ESPDrawFOV",
        Callback     = function(v) Settings.ESPDrawFOV = v end,
    })

    ESPTab:CreateSlider({
        Name         = "Max Distance",
        Range        = { 50, 5000 },
        Increment    = 10,
        Suffix       = "studs",
        CurrentValue = Settings.ESPMaxDist,
        Flag         = "ESPMaxDist",
        Callback     = function(v) Settings.ESPMaxDist = v end,
    })

    ESPTab:CreateSlider({
        Name         = "Box Scale",
        Range        = { 0.5, 3.0 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = Settings.ESPBoxScale,
        Flag         = "ESPBoxScale",
        Callback     = function(v) Settings.ESPBoxScale = v end,
    })

    HitboxTab:CreateSection("Hitbox Expander")

    HitboxTab:CreateToggle({
        Name         = "Enable Hitbox Expander",
        CurrentValue = Settings.HitboxEnabled,
        Flag         = "HitboxEnabled",
        Callback     = function(v)
            Settings.HitboxEnabled = v
            Notify("Hitbox: " .. tostring(v))
        end,
    })

    HitboxTab:CreateSlider({
        Name         = "Hitbox Size",
        Range        = { 1, 30 },
        Increment    = 0.5,
        Suffix       = "studs",
        CurrentValue = Settings.HitboxSize,
        Flag         = "HitboxSize",
        Callback     = function(v) Settings.HitboxSize = v end,
    })

    HitboxTab:CreateSlider({
        Name         = "Hitbox Visibility",
        Range        = { 0, 1 },
        Increment    = 0.1,
        Suffix       = "",
        CurrentValue = Settings.HitboxTransparency,
        Flag         = "HitboxTransparency",
        Callback     = function(v) Settings.HitboxTransparency = v end,
    })

    GunTab:CreateSection("Recursive Gun Giver")
    GunTab:CreateLabel("Scans ReplicatedStorage.GunModels recursively for Tools.")

    local gunList, gunMap = {}, {}
    do
        local folder = ReplicatedStorage:FindFirstChild("GunModels")
        if folder then
            for _, entry in ipairs(RecursiveFindTools(folder, "GunModels.")) do
                table.insert(gunList, entry.Path)
                gunMap[entry.Path] = entry.Tool
            end
        end
    end

    local gunOptions = (#gunList > 0) and gunList or { "<No guns found>" }
    local selectedGun = gunList[1]

    local gunDropdown = GunTab:CreateDropdown({
        Name            = "Select Gun",
        Options         = gunOptions,
        CurrentOption   = { gunOptions[1] },
        MultipleOptions = false,
        Flag            = "GunSelect",
        Callback        = function(Option)
            selectedGun = type(Option) == "table" and Option[1] or Option
        end,
    })

    GunTab:CreateButton({
        Name     = "Give Selected Gun",
        Callback = function()
            if not selectedGun or not gunMap[selectedGun] then
                Notify("No gun selected!")
                return
            end
            GiveTool(gunMap[selectedGun], selectedGun)
        end,
    })

    GunTab:CreateButton({
        Name     = "Give ALL Guns",
        Callback = function()
            if #gunList == 0 then
                Notify("No guns found in GunModels.")
                return
            end
            for path, tool in pairs(gunMap) do
                GiveTool(tool, path)
            end
        end,
    })

    GunTab:CreateButton({
        Name     = "Refresh Gun List",
        Callback = function()
            Notify("Rescanning GunModels...")
            gunList, gunMap = {}, {}
            local folder = ReplicatedStorage:FindFirstChild("GunModels")
            if folder then
                for _, entry in ipairs(RecursiveFindTools(folder, "GunModels.")) do
                    table.insert(gunList, entry.Path)
                    gunMap[entry.Path] = entry.Tool
                end
            end
            gunOptions = #gunList > 0 and gunList or { "<No guns found>" }
            selectedGun = gunList[1]
            gunDropdown:SetValues(gunOptions)
            gunDropdown:SetValue(gunOptions[1])
        end,
    })

    MiscTab:CreateSection("General")

    MiscTab:CreateToggle({
        Name         = "Notifications",
        CurrentValue = Settings.Notifications,
        Flag         = "Notifications",
        Callback     = function(v) Settings.Notifications = v end,
    })

    MiscTab:CreateButton({
        Name     = "Join Discord",
        Callback = function()
            local link = "https://discord.gg/fuECzR3dM3"
            local success, err = pcall(function()
                setclipboard(link)
            end)
            if success then
                Notify("Copied to Clipboard")
            else
                Notify("Failed to copy: " .. tostring(err))
            end
        end,
    })

    MiscTab:CreateButton({
        Name     = "Unload Script",
        Callback = function()
            ScriptActive = false

            for _, p in ipairs(Players:GetPlayers()) do
                RemoveESP(p)
                local char = p.Character
                if char then
                    local old = char:FindFirstChild("DevHitbox")
                    if old then old:Destroy() end
                end
            end

            pcall(function() FOVDraw:Remove() end)
            pcall(function() TargetDraw:Remove() end)

            Notify("Unloaded.")
            task.wait(0.2)
            pcall(function() Rayfield:Destroy() end)
        end,
    })

    pcall(function() Rayfield:LoadConfiguration() end)
end

BuildUI()
Rayfield:Finish()

Rayfield.Hub:Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if not ScriptActive then return end

    if input.KeyCode == Settings.AimKey or input.UserInputType == Settings.AimKey then
        HoldingAim = true
    end
end)

Rayfield.Hub:Connect(UserInputService.InputEnded, function(input)
    if input.KeyCode == Settings.AimKey or input.UserInputType == Settings.AimKey then
        HoldingAim   = false
        CurrentTarget = nil
    end
end)

Rayfield.Hub:Connect(RunService.RenderStepped, function()
    if not ScriptActive then return end

    if not Camera or not Camera.Parent then
        Camera = Workspace:FindFirstChild("CustomCamera")
        if not Camera or not Camera:IsA("Camera") then
            Camera = Workspace.CurrentCamera
        end
    end
    if not Camera then return end

    if Settings.ESPDrawFOV then
        FOVDraw.Position = Camera.ViewportSize / 2
        FOVDraw.Radius   = Settings.FOV
        FOVDraw.Visible  = true
    else
        FOVDraw.Visible = false
    end

    if Settings.AimEnabled and HoldingAim then
        local valid = false

        if CurrentTarget then
            local char = CurrentTarget.Player.Character
            local part = char and GetAimPart(char)
            if part and IsAlive(char) and IsTargetValid(CurrentTarget.Player) then
                local aimPos = GetAimPosition(part)
                local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                if onScreen then
                    local sd = (Vector2.new(pos.X, pos.Y) - Camera.ViewportSize / 2).Magnitude
                    if sd <= Settings.FOV and IsVisible(char, aimPos) then
                        valid = true
                        CurrentTarget.Part     = part
                        CurrentTarget.Position = pos
                        CurrentTarget.Distance = (part.Position - Camera.CFrame.Position).Magnitude
                    end
                end
            end
        end

        if not valid then
            CurrentTarget = Settings.AutoSwitch and GetClosestPlayer() or nil
        end

        if CurrentTarget then
            local part   = CurrentTarget.Part
            local aimPos = GetAimPosition(part)

            if Settings.OverrideCam then
                Camera.CameraType = Enum.CameraType.Scriptable
            end

            local targetCF = CFrame.new(Camera.CFrame.Position, aimPos)
            if Settings.Smoothness >= 0.99 then
                Camera.CFrame = targetCF
            else
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, Settings.Smoothness)
            end

            local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
            if onScreen then
                TargetDraw.Position = Vector2.new(pos.X, pos.Y)
                TargetDraw.Radius   = math.clamp(500 / pos.Z, 5, 30)
                TargetDraw.Visible  = true
            else
                TargetDraw.Visible = false
            end

            if not CurrentTarget.Notified then
                CurrentTarget.Notified = true
                Notify("Locked: " .. CurrentTarget.Player.Name ..
                       " | " .. math.floor(CurrentTarget.Distance) .. " studs")
            end
        else
            TargetDraw.Visible = false
        end
    else
        CurrentTarget      = nil
        TargetDraw.Visible = false
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local data = GetESP(player)
            data.Box.Visible    = false
            data.Tracer.Visible = false
            data.Info.Visible   = false

            if Settings.ESPEnabled then
                local char = player.Character
                local part = char and GetAimPart(char)
                if part and IsAlive(char) and IsTargetValid(player) then
                    local dist = (part.Position - Camera.CFrame.Position).Magnitude
                    if dist <= Settings.ESPMaxDist then
                        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenPos = Vector2.new(pos.X, pos.Y)
                            local hp, maxHp = GetHealth(char)
                            local locked    = CurrentTarget and CurrentTarget.Player == player

                            if Settings.ESPTracers then
                                data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                data.Tracer.To   = screenPos
                                data.Tracer.Color = locked and Color3.fromRGB(255, 0, 0)
                                                             or Color3.fromRGB(255, 255, 255)
                                data.Tracer.Transparency = locked and 1 or 0.6
                                data.Tracer.Visible = true
                            end

                            if Settings.ESPBoxes then
                                local scale = math.clamp(1500 / pos.Z, 40, 200) * Settings.ESPBoxScale
                                data.Box.Size     = Vector2.new(scale * 0.65, scale)
                                data.Box.Position = screenPos - data.Box.Size / 2
                                data.Box.Color    = locked and Color3.fromRGB(255, 0, 0)
                                                             or Color3.fromRGB(0, 255, 100)
                                data.Box.Visible  = true
                            end

                            if Settings.ESPInfo then
                                data.Info.Position = screenPos - Vector2.new(0, 40)
                                data.Info.Text     = player.Name .. "\nHP:" .. hp .. "/" .. maxHp ..
                                                     " | " .. math.floor(dist) .. " studs"
                                data.Info.Color    = locked and Color3.fromRGB(255, 200, 50)
                                                             or Color3.fromRGB(255, 255, 255)
                                data.Info.Visible  = true
                            end
                        end
                    end
                end
            end
        end
    end

    if Settings.HitboxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local expander = char:FindFirstChild("DevHitbox")
                        if not expander then
                            expander = Instance.new("Part")
                            expander.Name       = "DevHitbox"
                            expander.Shape      = Enum.PartType.Ball
                            expander.Material   = Enum.Material.ForceField
                            expander.Color      = Color3.fromRGB(255, 0, 0)
                            expander.CanCollide = false
                            expander.Anchored   = false
                            expander.Parent     = char

                            local weld = Instance.new("Weld", expander)
                            weld.Part0 = hrp
                            weld.Part1 = expander
                        end
                        expander.Size = Vector3.new(
                            Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize
                        )
                        expander.Transparency = 1 - Settings.HitboxTransparency
                    end
                end
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char then
                    local old = char:FindFirstChild("DevHitbox")
                    if old then old:Destroy() end
                end
            end
        end
    end
end)

Rayfield.Hub:Connect(Players.PlayerRemoving, function(player)
    RemoveESP(player)
    if CurrentTarget and CurrentTarget.Player == player then
        CurrentTarget = nil
    end
end)

Notify("Void Scripts Loaded | FluxoPVP Edition")

Rayfield.Hub:Add(function()
    ScriptActive = false
    HoldingAim = false
    for _, target in ipairs(Players:GetPlayers()) do
        RemoveESP(target)
        local character = target.Character
        local hitbox = character and character:FindFirstChild("DevHitbox")
        if hitbox then hitbox:Destroy() end
    end
    pcall(function() FOVDraw:Remove() end)
    pcall(function() TargetDraw:Remove() end)
end)
