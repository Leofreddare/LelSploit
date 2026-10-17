local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()

local Window = Library:CreateWindow{
    Title = "LelHub",
    SubTitle = "by LelSploit",
    TabWidth = 200,
    Size = UDim2.fromOffset(620, 380),
    Resize = true,
    MinSize = Vector2.new(560, 420),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.Q
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
        while true do
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

-- ------------------------------------------------------------ PRICE DUMPER
local function dumpPrices()
    local folders = getBlockFolders()
    if #folders == 0 then
        warn("[LelSploit] no block folders found")
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
        warn("[LelSploit] no clipboard function available")
        return 0
    end

    return count
end

-- ------------------------------------------------------------ ITEM FINDER
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
        print("[LelSploit] price dumper: copied " .. tostring(n) .. " items to clipboard")
    end
})

task.spawn(function()
    task.wait(2)
    refreshItemList(true)
    while true do
        task.wait(2)
        refreshItemList(false)
    end
end)

-- ------------------------------------------------------------ SPACING + ESP SECTION
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

-- ------------------------------------------------------------ MISC: ANTI-AFK
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

-- ------------------------------------------------------------ MISC: PLAYER ESP
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

-- ------------------------------------------------------------ MISC: VENDING ESP
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