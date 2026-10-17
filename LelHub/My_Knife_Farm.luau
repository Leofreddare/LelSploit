local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "My Knife Farm", Style = "Rayfield", Parameters = {}, Action = "Enable game features" }, [====[
local Rayfield = LelHubUI

local player = game:GetService("Players").LocalPlayer
local myPlot = nil

local function assignMyPlot()
    local function clean(str) return str:gsub("%W", ""):lower() end
    local myCleanName = clean(player.Name)
    local myCleanDisplayName = clean(player.DisplayName)
    
    for i = 1, 8 do
        local plotName = "Plot_" .. i
        local plotFolder = workspace.Plots:FindFirstChild(plotName)
        if plotFolder then
            local nameplate = plotFolder:FindFirstChild("Plot_Models") and plotFolder.Plot_Models:FindFirstChild("BaseModel") and plotFolder.Plot_Models.BaseModel:FindFirstChild("BillBoardC")
            if nameplate then
                local cleanLabel = clean(nameplate.Nameplate.SurfaceGui.NameOf.Text)
                if string.find(cleanLabel, myCleanName) or string.find(cleanLabel, myCleanDisplayName) then
                    myPlot = plotFolder
                    break
                end
            end
        end
    end
end

assignMyPlot()
if not myPlot then myPlot = workspace.Plots.Plot_1 end

local baseModel = myPlot.Plot_Models.BaseModel
local conveyor = baseModel.PackConveyor
local spawnClick = baseModel.ButtonModel.PacketClick.ClickDetector
local virtualUser = game:GetService("VirtualUser")
local BuyCaseRemote = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Game"):WaitForChild("CaseTriggered")
local spinRemote = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Rewards"):WaitForChild("SpinRewards")
local sellThisRemote = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Game"):WaitForChild("SellThis")
local spinAmountLabel = player.PlayerGui.SpinUI.MainFrame.SpinAmount
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local pickupCFrame = baseModel.BoxStand.CFrame * CFrame.new(0, 3, 0)
local sellCFrame = baseModel.SellButton.SellP.CFrame * CFrame.new(0, 2, 0)
local boxPrompt = baseModel.BoxStand.ProximityPrompt

local selectedSwordRarity = {}
local selectedMutationRarity = {}
local selectedChestRarities = {} 
local sellCaseRarities = {}
local sellKnifeRarities = {}
local caseRarirites = {"Common", "Rare", "Epic", "Elite", "Legendary", "Mythic", "Secret", "Limited", "Exclusive", "Timeless", "Godly", "Soul", "Fruit", "Ninja", "Historical", "Shadow", "Frost", "Demon", "Arsenal"}
local autoRollEnabled = false 
local autoBuyEnabled = false
local autoSellEnabled = false
local autoSellInventory = false
local autoSpinEnabled = false
local autoUpgradeEnabled = false
local sellInterval = 60

local currentCamera = game.Workspace.CurrentCamera
player.Idled:Connect(function()
    virtualUser:Button2Down(Vector2.zero, currentCamera.CFrame)
    task.wait(1)
    virtualUser:Button2Up(Vector2.zero, currentCamera.CFrame)
end)

local Window = Rayfield:CreateWindow({
    Name = "⚡ My knife FARM | " .. (player.Name),
    LoadingTitle = "My knife FARM",
    LoadingSubtitle = "Version 0.3",
    ConfigurationSaving = { Enabled = true, FolderName = "KnifeFarmConfig", FileName = "Main" },
    KeySystem = false
})

local Tab = Window:CreateTab("Main", "scroll")
local EcoTab = Window:CreateTab("Economy", "dollar-sign")
local PlotTab = Window:CreateTab("Plot", "home")
local SettingsTab = Window:CreateTab("Settings", "settings")

local StatusLabel = Tab:CreateLabel("Status: Idle", "info")
local SellTimerLabel = EcoTab:CreateLabel("Next Sell In: --:--", "clock")

local function isMatch(selectedTable, value)
    if not selectedTable or next(selectedTable) == nil then return false end
    for k, v in pairs(selectedTable) do
        local key = tostring(type(k) == "string" and k or v)
        if string.find(string.lower(value), string.lower(key)) then return true end
    end
    return false
end

local function getKnifeValue(tool)
    local billboard = tool:FindFirstChild("BillboardGui", true)
    local givingAmount = billboard and billboard:FindFirstChild("GivingAmount")
    
    if givingAmount and givingAmount:IsA("TextLabel") then
        local cleanString = givingAmount.Text:gsub("[$,/knife%s]", "")
        return tonumber(cleanString) or 0
    end
    return 0
end

local function findCurrentBest()
    local backpack = player:WaitForChild("Backpack")
    local best = nil
    local high = -1
    
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and not item:FindFirstChildOfClass("Model") then
            local val = getKnifeValue(item)
            if val > high then
                high = val
                best = item
            end
        end
    end
    return best
end

local function findMatchingChest()
    local backpack = player:WaitForChild("Backpack")
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local caseModel = item:FindFirstChildOfClass("Model")
            if caseModel then
                local rarity = caseModel.Name
                if isMatch(selectedChestRarities, rarity) then
                    return item
                end
            end
        end
    end
    return nil
end

local function sellInventoryItems()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    
    local scanning = true
    while scanning and autoSellEnabled do
        local backpack = player:WaitForChild("Backpack")
        local targetItem = nil
        
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local rarity = ""
                local mutation = "Normal"
                local isCase = false
                local isKnife = false

                local mutLabel = item:FindFirstChild("EventRarity", true)
                if mutLabel and mutLabel:IsA("TextLabel") and mutLabel.Text ~= "" then
                    mutation = mutLabel.Text
                end

                if isMatch(selectedMutationRarity, mutation) then
                    continue 
                end

                local modelChild = item:FindFirstChildOfClass("Model")
                if modelChild then
                    isCase = true
                    rarity = modelChild.Name
                end

                if not isCase then
                    local rarityLabel = item:FindFirstChild("RarityText", true)
                    if rarityLabel and rarityLabel:IsA("TextLabel") then
                        isKnife = true
                        rarity = rarityLabel.Text
                    end
                end

                if (isCase and isMatch(sellCaseRarities, rarity)) or (isKnife and isMatch(sellKnifeRarities, rarity)) then
                    targetItem = item
                    break 
                end
            end
        end

        if targetItem then
            local tries = 0
            repeat
                if not targetItem or not targetItem.Parent then break end
                humanoid:EquipTool(targetItem)
                task.wait(0.3) 
                if targetItem.Parent == character then
                    sellThisRemote:FireServer()
                    task.wait(0.2)
                end
                tries = tries + 1
            until not targetItem.Parent or tries > 10
        else
            scanning = false
        end
    end
end

task.spawn(function()
    conveyor.SpawnedCase.ChildAdded:Connect(function(child)
        if not autoRollEnabled then return end
        task.spawn(function()
            task.wait(0.01)
            local rLabel = child:FindFirstChild("Rarity", true)
            if rLabel then
                while (rLabel.Text == "" or rLabel.Text == "Label") and autoRollEnabled do task.wait(0.02) end
                local curR = rLabel.Text

                if isMatch(selectedSwordRarity, curR) then
                    if autoBuyEnabled then
                        BuyCaseRemote:FireServer()
                    else
                        autoRollEnabled = false
                        Rayfield.Flags["caseRoll"]:Set(false)
                        Rayfield:Notify({Title = "Match Found!", Content = "Found: " .. curR, Duration = 5, Image = "check-circle"})
                    end
                end
            end
        end)
    end)
end)

Tab:CreateSection("Roll Automation")

Tab:CreateToggle({
    Name = "Auto Roll Cases",
    Info = "High-speed clicking for the roll button",
    CurrentValue = false,
    Flag = "caseRoll",
    Callback = function(Value)
        autoRollEnabled = Value
        if autoRollEnabled then
            StatusLabel:Set("Status: Rolling...", "zap")
            task.spawn(function()
                while autoRollEnabled do
                    fireclickdetector(spawnClick)
                    task.wait(0.05)
                end
            end)
        else
            StatusLabel:Set("Status: Idle", "info")
        end
    end,
})

Tab:CreateToggle({
    Name = "Auto Buy Matches",
    CurrentValue = false,
    Callback = function(V) autoBuyEnabled = V end,
})

Tab:CreateSection("Roll Filters")

Tab:CreateDropdown({
    Name = "Rarities to Buy/Keep",
    Options = caseRarirites,
    MultipleOptions = true,
    Callback = function(O) selectedSwordRarity = O end,
})

EcoTab:CreateSection("Auto Sell Control")

EcoTab:CreateToggle({
    Name = "Master Sell Loop",
    Info = "Handles box teleporting and bag cleaning",
    CurrentValue = false,
    Flag = "autoSell",
    Callback = function(Value)
        autoSellEnabled = Value
        if autoSellEnabled then
            task.spawn(function()
                while autoSellEnabled do
                    local returnPos = rootPart.CFrame
                    rootPart.CFrame = pickupCFrame
                    task.wait(0.4)
                    local pTimeout = 0
                    while autoSellEnabled and not character:FindFirstChild("OpenBox") and pTimeout < 40 do
                        if boxPrompt then fireproximityprompt(boxPrompt) end
                        task.wait(0.1)
                        pTimeout = pTimeout + 1
                    end
                    rootPart.CFrame = sellCFrame
                    task.wait(0.5)
                    if autoSellInventory then 
                        StatusLabel:Set("Status: Cleaning Bag...", "shopping-bag")
                        sellInventoryItems() 
                    end
                    rootPart.CFrame = returnPos
                    StatusLabel:Set("Status: Rolling...", "zap")
                    local timeLeft = sellInterval
                    while timeLeft > 0 and autoSellEnabled do
                        SellTimerLabel:Set(string.format("Next Sell In: %02d:%02d", math.floor(timeLeft/60), timeLeft%60), "clock")
                        task.wait(1)
                        timeLeft = timeLeft - 1
                    end
                end
            end)
        end
    end,
})

EcoTab:CreateDropdown({
    Name = "Sell Interval",
    Options = {"1 Minute", "5 Minutes", "10 Minutes", "20 Minutes"},
    CurrentValue = "1 Minute",
    Callback = function(O)
        local val = type(O) == "table" and O[1] or O
        sellInterval = tonumber(string.match(val, "%d+")) * 60
    end,
})

EcoTab:CreateSection("Safety Shield")

EcoTab:CreateDropdown({
    Name = "Keep Mutations (Protects from Selling)",
    Info = "Any item with these mutations will NEVER be sold",
    Options = {"Rusty", "Normal", "Golden", "Space", "Blood", "Dark", "Candy", "Rainbow", "Emerald", "Blue Gem"},
    MultipleOptions = true,
    Callback = function(O) selectedMutationRarity = O end,
})

EcoTab:CreateSection("Inventory Cleaning")

EcoTab:CreateToggle({
    Name = "Include Inventory in Loop",
    CurrentValue = false,
    Callback = function(V) autoSellInventory = V end,
})

EcoTab:CreateDropdown({
    Name = "Cases to Sell",
    Options = caseRarirites,
    MultipleOptions = true,
    Callback = function(O) sellCaseRarities = O end,
})

EcoTab:CreateDropdown({
    Name = "Knives to Sell",
    Options = caseRarirites,
    MultipleOptions = true,
    Callback = function(O) sellKnifeRarities = O end,
})

PlotTab:CreateSection("Plot Management")

PlotTab:CreateToggle({
    Name = "Auto Upgrade Knives",
    Info = "Instantly clicks all Upgrade Buttons from across the map",
    CurrentValue = false,
    Flag = "autoUpgrade",
    Callback = function(Value)
        autoUpgradeEnabled = Value
        if autoUpgradeEnabled then
            task.spawn(function()
                while autoUpgradeEnabled do
                    local slotsFolder = myPlot.Plot_Models.BaseModel:FindFirstChild("Slots")
                    if slotsFolder then
                        for _, slot in pairs(slotsFolder:GetChildren()) do
                            if not autoUpgradeEnabled then break end

                            local upgradePart = slot:FindFirstChild("UpgradePart")
                            if upgradePart then
                                local priceLabel = upgradePart:FindFirstChild("Price", true)
                                
                                if priceLabel and priceLabel.Text ~= "Max" then
                                    local cd = upgradePart:FindFirstChild("ClickDetector")
                                    if cd then
                                        fireclickdetector(cd)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.5) 
                end
            end)
        end
    end,
})

PlotTab:CreateButton({
    Name = "Equip Best Knives",
    Info = "Equips the highest earning knives",
    Callback = function()
        local slotsFolder = myPlot.Plot_Models.BaseModel:FindFirstChild("Slots")
        local oldPos = rootPart.CFrame
        local placedCount = 0

        for _, slot in pairs(slotsFolder:GetChildren()) do
            local standPart = slot:FindFirstChild("StandPart")
            local prompt = standPart and standPart:FindFirstChild("ProximityPrompt")

            if prompt and prompt.ActionText == "Place" then
                
                local hasCaseModel = false
                if slot:FindFirstChild("StandModel") then
                    for _, child in pairs(slot.StandModel:GetChildren()) do
                        if string.find(string.lower(child.Name), "case") or string.find(string.lower(child.Name), "chest") then
                            hasCaseModel = true
                            break
                        end
                    end
                end

                if not hasCaseModel then
                    local knifeToUse = findCurrentBest() 
                    
                    if knifeToUse then
                        humanoid:EquipTool(knifeToUse)
                        task.wait(0.1)

                        rootPart.CFrame = standPart.CFrame * CFrame.new(0, 3, 0)
                        task.wait(0.12) 
                        
                        local attempts = 0
            
                        while prompt.ActionText ~= "Remove" and "Open" and attempts < 5 do
                            fireproximityprompt(prompt)
                            task.wait(0.2)
                            attempts = attempts + 1
                        end
                        placedCount = placedCount + 1
                    else
                        break 
                    end
                end
            end
        end

        rootPart.CFrame = oldPos
        Rayfield:Notify({
            Title = "Stands Updated", 
            Content = "Filled " .. placedCount .. " empty stands while ignoring all chests.", 
            Duration = 5,
            Image = "shield-check"
        })
    end,
})

PlotTab:CreateButton({
    Name = "Remove All Knives",
    Info = "Removes all knives from the plot",
    Callback = function()
        local slotsFolder = myPlot.Plot_Models.BaseModel:FindFirstChild("Slots")
        if not slotsFolder then return end

        local oldPos = rootPart.CFrame
        local totalRemoved = 0

        for _, slot in pairs(slotsFolder:GetChildren()) do
            local standPart = slot:FindFirstChild("StandPart")
            local prompt = standPart and standPart:FindFirstChild("ProximityPrompt")
            
            if prompt and prompt.ActionText == "Remove" then
                rootPart.CFrame = standPart.CFrame * CFrame.new(0, 3, 0)
                task.wait(0.1) 
                local attempts = 0

                while prompt.ActionText == "Remove" and attempts < 10 do
                    fireproximityprompt(prompt)
                    task.wait(0.15)
                    attempts = attempts + 1
                end
                
                if prompt.ActionText ~= "Remove" then
                    totalRemoved = totalRemoved + 1
                end
            end
        end

        rootPart.CFrame = oldPos 
        
        Rayfield:Notify({
            Title = "Cleaning Complete", 
            Content = "Confirmed removal of " .. totalRemoved .. " knives.", 
            Duration = 3, 
            Image = "check-circle"
        })
    end,
})

PlotTab:CreateSection("Chest Management")

PlotTab:CreateDropdown({
    Name = "Chests to Place",
    Options = caseRarirites,
    MultipleOptions = true,
    Callback = function(O) selectedChestRarities = O end,
})

PlotTab:CreateButton({
    Name = "Place Selected Chests in Slots",
    Info = "Fills empty slots with the chests selected in the filter above",
    Callback = function()
        local slotsFolder = myPlot.Plot_Models.BaseModel:FindFirstChild("Slots")
        local oldPos = rootPart.CFrame
        local placedCount = 0

        for _, slot in pairs(slotsFolder:GetChildren()) do
            local standPart = slot:FindFirstChild("StandPart")
            local prompt = standPart and standPart:FindFirstChild("ProximityPrompt")

            if prompt and prompt.ActionText == "Place" then
                local chestToUse = findMatchingChest()
                
                if chestToUse then
                    humanoid:EquipTool(chestToUse)
                    task.wait(0.1)

                    rootPart.CFrame = standPart.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.15)
                    
                    local attempts = 0

                    while prompt.ActionText == "Place" and attempts < 5 do
                        fireproximityprompt(prompt)
                        task.wait(0.25)
                        attempts = attempts + 1
                    end
                    
                    if prompt.ActionText == "Skip" then
                        placedCount = placedCount + 1
                    end
                else
                    break 
                end
            end
        end

        rootPart.CFrame = oldPos
        Rayfield:Notify({
            Title = "Chests Placed", 
            Content = "Successfully placed " .. placedCount .. " chests on your plot.", 
            Duration = 5,
            Image = "package"
        })
    end,
})

SettingsTab:CreateSection("SYSTEM")

SettingsTab:CreateToggle({
    Name = "Auto Spam Spins",
    Info = "Uses all available spins and checks for new ones every minute",
    CurrentValue = false,
    Flag = "autoSpin",
    Callback = function(Value)
        autoSpinEnabled = Value
        if autoSpinEnabled then
            task.spawn(function()
                while autoSpinEnabled do
                    local spinCount = tonumber(string.match(spinAmountLabel.Text, "%d+")) or 0
                    
                    if spinCount > 0 then
                        StatusLabel:Set("Status: Spaming Spins!", "star")
                        for i = 1, spinCount do
                            if not autoSpinEnabled then break end
                            spinRemote:FireServer()
                            task.wait(0.1)
                        end
                    end
                    
                    StatusLabel:Set("Status: Idle (Waiting for Spins)", "clock")
                    
                    for i = 1, 60 do
                        if not autoSpinEnabled then break end
                        task.wait(1)
                    end
                end
                StatusLabel:Set("Status: Idle", "info")
            end)
        end
    end,
})

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function() Rayfield:Destroy() end,
})

SettingsTab:CreateSection("Made by Zenbo!")

Rayfield:Notify({Title = "Ready", Content = "Economy filters organized.", Duration = 3, Image = "settings"})
]====])
