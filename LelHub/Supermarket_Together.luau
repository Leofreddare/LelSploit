local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Supermarket Together", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local player = game.Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")


local cashierActive = false
local warehousemanActive = false
local porterActive = false
local autoKickerActive = false
local options = {
    License = {
        {
            HideId = "rbxassetid://134513576519333",
            Name = "License_17",
            Price = 0,
            Action = "BuyLicense",
            PlayerLv = 100,
            ImgId = "rbxassetid://79881044317587"
        },
        "BuyLicense"
    },
    Expansion = {
        {
            Action = "BuyExpan",
            Price = 0,
            Name = "Expand_8",
            PlayerLv = 1000,
            ImgId = "rbxassetid://107600043694511"
        },
        "BuyExpan"
    },
    Warehouse = {
        {
            Action = "BuyWarehouse",
            Price = 0,
            Name = "Unlock Storage 5",
            PlayerLv = 10000,
            ImgId = "rbxassetid://93956785774375"
        },
        "BuyWarehouse"
    }
}


local function getGPState(name)
    if name == "Cashier" then return cashierActive
    elseif name == "Porter" then return porterActive
    elseif name == "Warehouseman" then return warehousemanActive
    end
    return false
end

local function toggleGP(name)
    local target
    if name == "Cashier" then
        cashierActive = not cashierActive
        target = cashierActive
    elseif name == "Porter" then
        porterActive = not porterActive
        target = porterActive
    elseif name == "Warehouseman" then
        warehousemanActive = not warehousemanActive
        target = warehousemanActive
    end
    RS.Events.Goods.GamePassRE:FireServer(name, target)
    return target
end

local function buyItem(itemName, quant)
    RS.Events.Data.BuyShopGoodsRE:FireServer({[itemName] = quant})
end

local function giveCash(amount)
    RS.Events.Data.BuyLicenseRE:FireServer({
        HideId = "rbxassetid://134513576519333",
        Name = "License_1",
        Price = -amount,
        Action = "BuyLicense",
        PlayerLv = 100,
        ImgId = "rbxassetid://79881044317587"
    }, "BuyLicense")
end

local function sellBoxes(itemType)
	if itemType == "Sell Furniture Box" then 
		itemType = "SellShelves"
	elseif itemType == "Sell Product Box" then
		itemType = "SellBox"
	end
    for _, i in ipairs(workspace.Resources.Product:GetChildren()) do
        if (itemType == "SellBox" and (i:GetAttribute("ShelvesType") == "Shelves" or i:GetAttribute("Decorations"))) then continue end
        if (itemType == "SellShelves" and i:GetAttribute("ShelvesType") == "Shelf") then continue end
        workspace.Resources.ScreenRE:FireServer("TakeBox", i)
        RS.Events.Building.PlacementRE:FireServer(itemType, i)
    end
end

local function expand(area)
    local args = options[area]
    if args then
        RS.Events.Data.BuyLicenseRE:FireServer(unpack(args))
    end
end

local function placeAnything(itemName)
    giveCash(800)
    buyItem("RedShelf", 1)
    task.wait(0.35)
    workspace.Resources.ScreenRE:FireServer("TakeBox", workspace.Resources.Product.RedShelfBox)
    RS.Events.Building.PlacementRE:FireServer("PlaceShelves", "RedShelf", CFrame.new(718.84, 5.84, 287.22))
    task.wait(0.4)
    RS.Events.Building.PlacementRE:FireServer("MoveShelves", workspace.Resources.Building.RedShelf)
    RS.Events.Building.PlacementRE:FireServer("PlaceShelves", itemName, CFrame.new(718.84, 5.84, 287.22))
end


local function funAction1()
    
	local rackName, itemStore = "DryRack", "OliveOil"
	local numSpaces, usedBoxes = 0, {}
	local function fireRS(path, ...)
		local obj = RS
		for _, child in ipairs(path) do
			obj = obj:WaitForChild(child)
		end
		obj:FireServer(...)
	end
	local function fireWS(path, ...)
		local obj = workspace
		for _, child in ipairs(path) do
			obj = obj:WaitForChild(child)
		end
		obj:FireServer(...)
	end
	local function sellHeld()
		for _, i in ipairs(workspace.Resources.Carried:GetChildren()) do
			fireRS({"Events","Building","PlacementRE"}, "SellBox", i)
		end
	end
	local function setColors(eventPath, colors)
		for _, c in ipairs(colors) do
			fireRS(eventPath, unpack(c))
		end
	end
	for _, rack in ipairs(workspace.Resources.Building:GetChildren()) do
		if rack.Name ~= rackName then continue end
		numSpaces += 8
		for _, folder in ipairs(rack.StorageFolder:GetChildren()) do
			local items = {}
			for _, item in ipairs(folder:GetChildren()) do
				table.insert(items, item)
			end
			fireWS({"Resources","ScreenRE"}, "RecycleProduct", items)
			sellHeld()
		end
	end
	fireRS({"Events","Data","BuyShopNameRE"}, "Olive Oil Store")
	giveCash(numSpaces * 41 + 800)
	print(numSpaces)
	buyItem(itemStore, numSpaces)
	task.wait(0.25)
	for _, rack in ipairs(workspace.Resources.Building:GetChildren()) do
		if rack.Name ~= rackName then continue end
		for _, det in ipairs(rack.DetectorFolder:GetChildren()) do
			task.wait(0.2)
			for _, box in ipairs(workspace.Resources.Product:GetChildren()) do
				if box.Name == itemStore.."Box" and not usedBoxes[box] then
					usedBoxes[box] = true
					fireWS({"Resources","ScreenRE"}, "PutProduct", box, det, rack)
					break
				end
			end
		end
	end
	local seaGreen = {
		{"SeaGreen","WallColor"},
		{"SeaGreen","BoardColor"},
		{"SeaGreen","Board2Color"},
		{"SeaGreen","CellingColor"},
		{"SeaGreen","SignColor"}
	}
	setColors({"Events","Data","BuyWallRE"}, seaGreen)
	setColors({"Events","Decoration","ChangeWallRE"}, seaGreen)
	setColors({"Events","Decoration","ChangeWallRE"}, {{"DefaultPaper","WallPaper"}})
end

local function toggleAutoKicker()
    local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UserInputService = game:GetService("UserInputService")
	local TeleportRE = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Phone"):WaitForChild("TeleportRE")
	local localPlayer = Players.LocalPlayer
	local exclusionList = {
		["myUsername"] = true,
		["myExampleName2"] = true
	}
	exclusionList[localPlayer.Name] = true
	
	if autoKickerActive then
		
		autoKickerActive = false
		print("Auto-Kicker stopped.")
		return
	end
	
	
	autoKickerActive = true
	print("Running AutoKicker - Press X to stop or toggle the button")
	
	
	local connection
	connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.X then
			autoKickerActive = false
			connection:Disconnect()
			print("Auto-Kicker stopped by user (X key).")
		end
	end)
	
	
	spawn(function()
		while autoKickerActive do
			for _, player in ipairs(Players:GetPlayers()) do
				if not autoKickerActive then break end 
				if not exclusionList[player.Name] then
					local args = {
						"Kick",
						player
					}
					print("Kicked " .. player.Name)
					TeleportRE:FireServer(unpack(args))
					wait(0.5)
				end
			end
			wait(1)
		end
		
		if connection then
			connection:Disconnect()
		end
	end)
end

local function funAction3()
    local usedBoxes = {}
    local function sellHeld()
        local carried = workspace.Resources.Carried:FindFirstChildWhichIsA("Model")
        if carried then
            RS.Events.Building.PlacementRE:FireServer("SellBox", carried)
        end
    end
    local function waitForBox(productName)
        local box
        local timeout = os.clock() + 5
        repeat
            for _, b in ipairs(workspace.Resources.Product:GetChildren()) do
                if b.Name == productName.."Box" and not usedBoxes[b] then
                    box = b
                    break
                end
            end
            if not box then task.wait(0.05) end
        until box or os.clock() > timeout
        return box
    end
    for _, building in ipairs(workspace.Resources.Building:GetChildren()) do
        if building:GetAttribute("BuildingType") ~= "Shelves" then continue end
        local dFolder = building:FindFirstChild("DetectorFolder")
        local sFolder = building:FindFirstChild("StorageFolder")
        if not dFolder or not sFolder then continue end
        for i = 1, #dFolder:GetChildren() do
            local detector = dFolder:FindFirstChild(i)
            local storage = sFolder:FindFirstChild(i)
            if not detector or not storage then continue end
            local productName = detector:GetAttribute("ProductName")
            if not productName then continue end
            buyItem(productName, 1)
            local storedItems = storage:GetChildren()
            if #storedItems > 0 then
                workspace.Resources.ScreenRE:FireServer("RecycleProduct", storedItems)
                sellHeld()
            end
            local box = waitForBox(productName)
            if not box then
                warn("No box found for", productName, "within timeout")
            else
                usedBoxes[box] = true
                workspace.Resources.ScreenRE:FireServer("PutProduct", box, detector, building)
            end
        end
    end
    print("Restocked!")
end


local ON_COLOR = Color3.fromRGB(0, 180, 0)
local OFF_COLOR = Color3.fromRGB(180, 0, 0)
local ACCENT_COLOR = Color3.fromRGB(70, 130, 180)


local gui = Instance.new("ScreenGui")
gui.Name = "ControlPanel"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")


local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 440)
frame.Position = UDim2.new(0.3, 0, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)


local titleBar = Instance.new("Frame", frame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
titleBar.BorderSizePixel = 0
local titleCorner = Instance.new("UICorner", titleBar)
titleCorner.CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1, -35, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Control Panel"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 2.5)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.TextScaled = true
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)


local scrollFrame = Instance.new("ScrollingFrame", frame)
scrollFrame.Size = UDim2.new(1, -10, 1, -40)
scrollFrame.Position = UDim2.new(0, 5, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local yPos = 5


local function addSpace(px) yPos += px end

local function makeSection(text)
    local section = Instance.new("Frame", scrollFrame)
    section.Size = UDim2.new(1, -10, 0, 25)
    section.Position = UDim2.new(0, 5, 0, yPos)
    section.BackgroundColor3 = ACCENT_COLOR
    section.BorderSizePixel = 0
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 4)
    
    local lbl = Instance.new("TextLabel", section)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    addSpace(30)
end

local function makeToggle(name)
    local btn = Instance.new("TextButton", scrollFrame)
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = name
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0
    btn.BackgroundColor3 = getGPState(name) and ON_COLOR or OFF_COLOR
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local function refresh()
        btn.BackgroundColor3 = getGPState(name) and ON_COLOR or OFF_COLOR
    end
    btn.MouseButton1Click:Connect(function()
        toggleGP(name)
        refresh()
    end)
    addSpace(30)
end

local function makeCompactInput(labelText, placeholder, onSubmit, buttonText, textPH)
    buttonText = buttonText or "Go"
    local container = Instance.new("Frame", scrollFrame)
    container.Size = UDim2.new(1, -20, 0, 45)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, 0, 0, 15)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextScaled = true
    
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(0.75, -5, 0, 25)
    box.Position = UDim2.new(0, 0, 0, 20)
    box.PlaceholderText = placeholder
    box.Text = textPH
    box.ClearTextOnFocus = false
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.BorderSizePixel = 0
    box.TextScaled = true
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(0.25, -5, 0, 25)
    btn.Position = UDim2.new(0.75, 0, 0, 20)
    btn.Text = buttonText
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = ACCENT_COLOR
    btn.BorderSizePixel = 0
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        if box.Text ~= "" then onSubmit(box.Text) end
    end)
    addSpace(50)
end

local function makeBuyItem()
    local container = Instance.new("Frame", scrollFrame)
    container.Size = UDim2.new(1, -20, 0, 45)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, 0, 0, 15)
    lbl.Text = "Buy Item"
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextScaled = true
    
    local nameBox = Instance.new("TextBox", container)
    nameBox.Size = UDim2.new(0.55, -5, 0, 25)
    nameBox.Position = UDim2.new(0, 0, 0, 20)
    nameBox.PlaceholderText = "Item name"
    nameBox.Text = "OliveOil"
    nameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    nameBox.TextColor3 = Color3.new(1, 1, 1)
    nameBox.BorderSizePixel = 0
    nameBox.TextScaled = true
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 4)
    
    local qtyBox = Instance.new("TextBox", container)
    qtyBox.Size = UDim2.new(0.2, -5, 0, 25)
    qtyBox.Position = UDim2.new(0.55, 0, 0, 20)
    qtyBox.PlaceholderText = "Qty"
    qtyBox.Text = "1"
    qtyBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    qtyBox.TextColor3 = Color3.new(1, 1, 1)
    qtyBox.BorderSizePixel = 0
    qtyBox.TextScaled = true
    Instance.new("UICorner", qtyBox).CornerRadius = UDim.new(0, 4)
    
    local buyBtn = Instance.new("TextButton", container)
    buyBtn.Size = UDim2.new(0.25, -5, 0, 25)
    buyBtn.Position = UDim2.new(0.75, 0, 0, 20)
    buyBtn.Text = "Buy"
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
    buyBtn.BorderSizePixel = 0
    buyBtn.TextScaled = true
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 4)
    
    buyBtn.MouseButton1Click:Connect(function()
        local itemName = nameBox.Text
        local qty = tonumber(qtyBox.Text)
        if itemName ~= "" and qty and qty > 0 then
            buyItem(itemName, math.floor(qty))
        end
    end)
    addSpace(50)
end

local function makeDropdown(label, choices, func)
    local btn = Instance.new("TextButton", scrollFrame)
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = label .. " ^"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local popup
    btn.MouseButton1Click:Connect(function()
        if popup and popup.Parent then
            popup:Destroy()
            popup = nil
            btn.Text = label .. " ^"
            return
        end
        btn.Text = label .. " v"
        popup = Instance.new("Frame", gui)
        popup.Size = UDim2.new(0, 180, 0, #choices * 25)
        
        popup.Position = UDim2.new(0, frame.AbsolutePosition.X + frame.AbsoluteSize.X + 5, 0, btn.AbsolutePosition.Y)
        popup.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        popup.BorderSizePixel = 0
        popup.ZIndex = 10
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 4)
        
        for i, choice in ipairs(choices) do
            local cBtn = Instance.new("TextButton", popup)
            cBtn.Size = UDim2.new(1, -4, 0, 25)
            cBtn.Position = UDim2.new(0, 2, 0, (i-1)*25)
            cBtn.Text = choice
            cBtn.TextColor3 = Color3.new(1, 1, 1)
            cBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            cBtn.BorderSizePixel = 0
            cBtn.TextScaled = true
            cBtn.ZIndex = 11
            Instance.new("UICorner", cBtn).CornerRadius = UDim.new(0, 3)
            cBtn.MouseButton1Click:Connect(function()
                func(choice)
                if popup then 
                    popup:Destroy() 
                    popup = nil 
                    btn.Text = label .. " ^"
                end
            end)
        end
    end)
    addSpace(30)
end

local function makeButton(text, onClick, color)
    color = color or Color3.fromRGB(80, 80, 160)
    local btn = Instance.new("TextButton", scrollFrame)
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(onClick)
    addSpace(30)
end

local function makeAutoKickerToggle()
    local btn = Instance.new("TextButton", scrollFrame)
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = "Auto-Kicker (Owner Only)"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0
    btn.BackgroundColor3 = OFF_COLOR
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local function refresh()
        btn.BackgroundColor3 = autoKickerActive and ON_COLOR or OFF_COLOR
        btn.Text = autoKickerActive and "Auto-Kicker (RUNNING)" or "Auto-Kicker (Owner Only)"
    end
    
    btn.MouseButton1Click:Connect(function()
        toggleAutoKicker()
        refresh()
    end)
    addSpace(30)
end


makeSection("Gamepass Toggles")
makeToggle("Cashier")
makeToggle("Porter")
makeToggle("Warehouseman")

makeSection("Buy & Place")
makeBuyItem()
makeCompactInput("Place Item", "Item name", placeAnything, "Place", "AutoCashier")

makeSection("Sell & Expand")
makeDropdown("Sell Boxes", {"Sell Furniture Box", "Sell Product Box"}, sellBoxes)
makeDropdown("Expansions", {"License", "Expansion", "Warehouse"}, expand)

makeSection("Money")
makeCompactInput("Give Cash", "Amount", function(amountStr)
    local amount = tonumber(amountStr)
    if amount and amount ~= 0 then
        giveCash(amount)
    end
end, "Give", "100")

makeSection("Automation")
makeButton("Get Olive Oiled", funAction1, Color3.fromRGB(100, 120, 60))
makeAutoKickerToggle()
makeButton("Auto-Restock", funAction3, Color3.fromRGB(60, 120, 100))

print("Compact Control Panel loaded.")
]====])
