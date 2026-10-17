local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = "LelHub",
    SubTitle = "by LelSploit",
    TabWidth = 160,
    Size = UDim2.fromOffset(530, 325),
    Resize = true,
    MinSize = Vector2.new(470, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.Q
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

-- ------------------------------------------------------------ RESOURCES
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

-- Big Tree ESP
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

-- ============================================================
-- COMBAT: Cultist ESP, Aimbot, Triggerbot
-- ============================================================
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
            -- real connection, disconnected on toggle off, checked every iteration
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

-- ------------------------------------------------------------ KIDS
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

-- ------------------------------------------------------------ LANDMARKS
Tabs.Landmarks:CreateButton{
    Title = "Teleport to Landmark",
    Callback = function()
        local t = getClosestToOrigin(landmarkName, { landmarksFolder })
        if not t then return end
        local p = t:FindFirstChildWhichIsA("BasePart") or t:FindFirstChildWhichIsA("BasePart", true)
        if p then humanoidRootPart.CFrame = p.CFrame + Vector3.new(0, 5, 0) end
    end
}

-- ============================================================
-- TEAMMATES (with free-look spectate)
-- ============================================================
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

    -- free-look: lock cursor position, hide cursor, grab deltas
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

        -- mouse look
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

-- ------------------------------------------------------------ PLAYER
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

-- ============================================================
-- BACKGROUND LOOKUPS
-- ============================================================
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