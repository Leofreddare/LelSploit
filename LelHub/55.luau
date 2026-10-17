local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Supermarket Together")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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


local tab = Hub.Tabs.Game
for _, name in ipairs({"Cashier", "Porter", "Warehouseman"}) do
    Hub:Toggle(tab, "Pass_" .. name, name, function(state)
        if getGPState(name) ~= state then toggleGP(name) end
    end, false)
end
local item, quantity, placement, amount = "OliveOil", 1, "AutoCashier", 100
Hub:Input("Item", item, function(value) item = value end)
Hub:Input("Quantity", "1", function(value) quantity = tonumber(value) end)
Hub:Button(tab, "Buy item", function() if item ~= "" and quantity and quantity > 0 then buyItem(item, math.floor(quantity)) end end)
Hub:Input("Place item", placement, function(value) placement = value end)
Hub:Button(tab, "Place", function() if placement ~= "" then placeAnything(placement) end end)
LelUI:Control(nil, "Dropdown", "Sell boxes", nil, sellBoxes, {"Sell Furniture Box", "Sell Product Box"})
LelUI:Control(nil, "Dropdown", "Expansion", nil, expand, {"License", "Expansion", "Warehouse"})
Hub:Input("Cash amount", "100", function(value) amount = tonumber(value) end)
Hub:Button(tab, "Give cash", function() if amount and amount ~= 0 then giveCash(amount) end end)
Hub:Button(tab, "Get Olive Oiled", funAction1)
Hub:Toggle(tab, "AutoKicker", "Auto kicker", function(value) if autoKickerActive ~= value then toggleAutoKicker() end end, false)
Hub:Button(tab, "Restock", funAction3)
Hub:Add(function() autoKickerActive = false end)

end)
