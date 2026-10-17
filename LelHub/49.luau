local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("DOORS")
local LelUI = Hub.Native
local LelAPI = Hub:Interface("Obsidian")
task.spawn(function()
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = LelAPI
local ThemeManager = LelAPI
local SaveManager = LelAPI
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "CDoors",
    Footer = "CDoors open source at https://rscripts.net/script/cdoors-open-source-NkT4",
    Icon = 12294295267,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab("Main", "house"),
    ESP = Window:AddTab("ESP", "eye"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings")
}

local PlayerBox = Tabs.Main:AddLeftGroupbox("Player")
local GoldLabel = PlayerBox:AddLabel("Current Gold: Loading...")
PlayerBox:AddSlider("GoldSlider", { Text = "Gold Amount", Default = 50, Min = 1, Max = 1000, Rounding = 0 })

PlayerBox:AddButton("Add Gold", function()
    local goldObj = LocalPlayer:FindFirstChild("Gold")
    if goldObj then goldObj.Value = goldObj.Value + Options.GoldSlider.Value end
end)

PlayerBox:AddToggle("ToggleJump", {
    Text = "Toggle Jump",
    Default = false,
    Callback = function(Value)
        local char = workspace:FindFirstChild(LocalPlayer.Name)
        if char then
            char:SetAttribute("CanJump", Value)
        end
    end
})

PlayerBox:AddToggle("ToggleSlide", {
    Text = "Toggle Slide",
    Default = false,
    Callback = function(Value)
        local char = workspace:FindFirstChild(LocalPlayer.Name)
        if char then
            char:SetAttribute("CanSlide", Value)
        end
    end
})

local Visuals = Tabs.Main:AddLeftGroupbox("Visuals")

Visuals:AddCheckbox("Fullbright", {
    Text = "Fullbright",
    Default = false,
    Callback = function(Value)
        Lighting.ClockTime = Value and 12 or 14
        Lighting.GlobalShadows = not Value
        Lighting.Brightness = Value and Options.BrightnessSlider.Value or 1
    end
})

Visuals:AddSlider("BrightnessSlider", {
    Text = "Fullbright Intensity",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        if Toggles.Fullbright.Value then
            Lighting.Brightness = Value
        end
    end
})

local AntiBox = Tabs.Main:AddRightGroupbox("Anti-Entities")

local function ToggleRemote(name, state)
    local remote = Remotes:FindFirstChild(name) or _G[name .. "_Storage"]
    if state then
        if remote then
            _G[name .. "_Storage"] = remote
            remote.Parent = nil
        end
    else
        local storage = _G[name .. "_Storage"]
        if storage then
            storage.Parent = Remotes
        end
    end
end

AntiBox:AddToggle("AntiA90", { Text = "Anti A-90", Default = false, Callback = function(v) ToggleRemote("A90", v) end })
AntiBox:AddToggle("AntiDread", { Text = "Anti Dread", Default = false, Callback = function(v) ToggleRemote("Dread", v) end })
AntiBox:AddToggle("AntiScreech", { Text = "Anti Screech", Default = false, Callback = function(v) ToggleRemote("Screech", v) end })
AntiBox:AddToggle("AntiGiggle", { Text = "Anti Giggle", Default = false, Callback = function(v) ToggleRemote("Giggle", v) end })
AntiBox:AddToggle("AntiHaste", { Text = "Anti Haste", Default = false, Callback = function(v) ToggleRemote("Haste", v) end })

AntiBox:AddToggle("AntiCamShake", { 
    Text = "Anti CamShake", 
    Default = false, 
    Callback = function(v) 
        local list = {"CamShake", "CamShakeClient", "CamShakeRelative", "CamShakeRelativeClient"}
        for _, name in pairs(list) do ToggleRemote(name, v) end
    end 
})

local ESPTabBox = Tabs.ESP:AddLeftTabbox()
local ESPTab = ESPTabBox:AddTab("ESP")
local SettingsTab = ESPTabBox:AddTab("Settings")

ESPTab:AddToggle("DoorESP", { Text = "Door ESP", Default = false })
    :AddColorPicker("FillColor", { Default = Color3.fromRGB(120, 0, 0) })

ESPTab:AddToggle("ObjESP", { Text = "Objective ESP", Default = false })
    :AddColorPicker("ObjColor", { Default = Color3.fromRGB(0, 0, 255) })

ESPTab:AddToggle("EntityESP", { Text = "Entity Highlight", Default = false })
    :AddColorPicker("EntityColor", { Default = Color3.fromRGB(255, 0, 0) })

ESPTab:AddToggle("GoldPileESP", { Text = "Gold Highlight", Default = false })
    :AddColorPicker("GoldColor", { Default = Color3.fromRGB(255, 225, 0) })

ESPTab:AddToggle("ItemESP", { Text = "Item Highlight", Default = false })
    :AddColorPicker("ItemColor", { Default = Color3.fromRGB(0, 255, 255) })

ESPTab:AddToggle("HidingESP", { Text = "Hiding ESP", Default = false })
    :AddColorPicker("HideCol", { Default = Color3.fromRGB(100, 100, 100) })

ESPTab:AddToggle("ShedESP", { Text = "ToolShed ESP", Default = false })
    :AddColorPicker("ShedCol", { Default = Color3.fromRGB(139, 69, 19) })

ESPTab:AddToggle("PlayerESP", { Text = "Player ESP", Default = false })
    :AddColorPicker("PCol", { Default = Color3.fromRGB(0, 255, 0) })

SettingsTab:AddToggle("RainbowESP", { Text = "Rainbow ESP", Default = false })
SettingsTab:AddToggle("EnableText", { Text = "Enable Text", Default = false })
SettingsTab:AddSlider("TextSize", { Text = "Text Size", Default = 29, Min = 10, Max = 40, Rounding = 0 })
SettingsTab:AddSlider("TextHeight", { Text = "Text Offset Y", Default = 0.2, Min = -5, Max = 15, Rounding = 1 })
SettingsTab:AddSlider("MaxDistance", { Text = "Max ESP Distance", Default = 1000, Min = 50, Max = 5000, Rounding = 0 })

local activeESPs = {}
local EntityNames = {"Rush", "Ambush", "Seek", "Eyes", "Screech", "Halt", "A-60", "A-120", "GiggleCeiling", "MonumentEntity", "SallyMoving", "JeffTheKiller", "GloombatSwarm", "FigureRig"}
local ObjList = {"LibraryHintPaper", "LiveHintBook", "KeyObtain", "LeverForGate", "LiveBreakerPolePickup", "ElectricalKeyObtain"}
local ItemList = {"AK-47","AlarmClock","Aloe","AN-94","Anchors","A-90sStopSign","BackdoorKey","BackdoorLock","Bandage","BandagePack","Battery","BatteryPack","BigBomb","BlueKeycard","BluePrince","Bomb","Bread","BreakerPole","Bulklight","Buddy","Cactus","Candle","CarmelApple","Cheese","ChocolateBar","Citamines","ColtAnaconda","Cookie","Crossbow","Crucifix","DBShotgun","DesertEagle","ElectricalKey","ElectricalRoomFuse","EnergyDrink","ExecutionRoomKey","Flashlight","FreezeGun","Flamethrower","G36C","Generator","GeneratorFuse","GiftLauncher","GlitchFragment","GweenSoda","GuidanceCandy","Headlamp","HealingPad","HolyHandGrenade","HasteLever","Hookshot","HotelKey","HotelLock","IceTripmine","InvincibilityStar","JackoBomb","Keycard","Knockbomb","Landmine","Lantern","LaserPointer","Level5Keycard","LibearyBook","LibearyLock","LibearyPaper","Light_Bulb","Lockpick","Lolipop","MG42","M14","M16A2","M1911","M249","M5K","M4A1","MoonlightCandle","MoonlightFloat","MoonlightSmoothie","Monkey","Nanner","NannerPeel","NestGenerator","NVCS-3000","OrangeKeycard","P90","Paintingoval","Paintingrectanglelyingshortsides","Paintingrectanglelyinglongsides","PaintingSquare","PlantofVirdis","Potion","R870","RedEnergyDrink","Rock","Roto_Door","RubberChicken","SacredHerb","SaltShaker","Shakelight","Shears","SkeletonKey","Smoothie","SmallShieldPotion","SpeedBoostPad","SprayPaint","StarlightBottle","StarlightJug","StarlightVial","Straplight","StrawberryCandy","StrongHerb","StrongerHerb","StrongestHerb","SuperHerb","SweetHerb","ThrowableHatStand","ThrowableNormalCardboardBox","ThrowableOfficeChair","ThrowablePottedPlant","ThrowableRegalChair","ThrowableRegalOttoman","ThrowableStool","ThrowableTrashCan","ThrowableWideCardboardBox","ThrowableWoodenChair","ThrowableWoodenCrate","TipJar","Vitamins"}
local HSList = {"Locker_Large", "Toolshed", "Wardrobe", "Bed", "Backdoor_Wardrobe", "Rooms_Locker", "CircularVent"}


local function Cleanup(obj, data)
    pcall(function()
        if data.Highlight then data.Highlight:Destroy() end
        if data.Box then data.Box:Destroy() end
        if data.Bill then data.Bill:Destroy() end
    end)
    activeESPs[obj] = nil
end

local function CreateESP(obj, name, type)
    if activeESPs[obj] then return end
    
    local objN = obj.Name
    
    if objN == "LiveHintBook" or objN == "FigureRig" or objN == "LiveBreakerPolePickup" or objN == "ElectricalKeyObtain" then
        local displayName = (objN == "LiveHintBook" and "Book") or 
                            (objN == "FigureRig" and "Figure") or 
                            (objN == "LiveBreakerPolePickup" and "Breaker") or 
                            (objN == "ElectricalKeyObtain" and "Electrical Key")
        activeESPs[obj] = { Name = displayName, Type = type }
        return
    end

    local lowerN = objN:lower()
    if lowerN:find("bookcase") or lowerN:find("modular_bookshelf") then
        return
    end

    activeESPs[obj] = { Name = name, Type = type }
end

task.spawn(function()
    while true do
        local rooms = workspace:FindFirstChild("CurrentRooms")
        if rooms then
            for _, room in pairs(rooms:GetChildren()) do
                for _, child in pairs(room:GetDescendants()) do
                    local n = child.Name
                    
                    if Toggles.EntityESP.Value and table.find(EntityNames, n) then
                        CreateESP(child, n == "FigureRig" and "Figure" or n, "Entity")
                    elseif Toggles.ObjESP.Value and table.find(ObjList, n) then
                        local d = (n == "KeyObtain" and "Key") or 
                                  (n == "LeverForGate" and "Lever") or 
                                  (n == "LiveHintBook" and "Book") or 
                                  (n == "LiveBreakerPolePickup" and "Breaker") or 
                                  (n == "ElectricalKeyObtain" and "Electrical Key") or n
                        CreateESP(child, d, "Objective")
                    elseif Toggles.DoorESP.Value and n == "Door" and child:IsA("BasePart") then
                        CreateESP(child, "Door", "Door")
                    elseif Toggles.GoldPileESP.Value and n == "GoldPile" then
                        CreateESP(child, "Gold", "Gold")
                    elseif Toggles.ItemESP.Value and table.find(ItemList, n) then
                        CreateESP(child, n, "Item")
                    elseif Toggles.HidingESP.Value and table.find(HSList, n) then
                        CreateESP(child, n, "Hiding")
                    elseif Toggles.ShedESP.Value and n == "Toolshed_Small" then
                        CreateESP(child, "Tool Shed", "Shed")
                    end
                end
                task.wait(0.01)
            end
        end
        
        for _, ent in pairs(workspace:GetChildren()) do
            if table.find(EntityNames, ent.Name) then 
                CreateESP(ent, ent.Name == "FigureRig" and "Figure" or ent.Name, "Entity") 
            end
        end
        task.wait(1.5)
    end
end)

local function UpdateESP()
    local rainbow = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    local char = LocalPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Collision"))
    if not root then return end

    for obj, data in pairs(activeESPs) do
        local isEnabled = (data.Type == "Door" and Toggles.DoorESP.Value) or
                          (data.Type == "Objective" and Toggles.ObjESP.Value) or
                          (data.Type == "Entity" and Toggles.EntityESP.Value) or
                          (data.Type == "Gold" and Toggles.GoldPileESP.Value) or
                          (data.Type == "Item" and Toggles.ItemESP.Value) or
                          (data.Type == "Player" and Toggles.PlayerESP.Value)

        if not obj or not obj.Parent or not isEnabled then 
            Cleanup(obj, data) 
            continue 
        end

        local targetPos = (obj:IsA("Model") and obj:GetPivot().Position) or (obj:IsA("BasePart") and obj.Position)
        if not targetPos then continue end
        
        local dist = (root.Position - targetPos).Magnitude
        if dist > Options.MaxDistance.Value then
            if data.Highlight then data.Highlight.Enabled = false end
            if data.Box then data.Box.Visible = false end
            if data.Bill then data.Bill.Enabled = false end
            continue 
        end

        local _, onScreen = Camera:WorldToViewportPoint(targetPos)
        if onScreen then
            local color = Options.FillColor.Value
            if data.Type == "Entity" then color = Options.EntityColor.Value 
            elseif data.Type == "Player" then color = Options.PCol.Value
            elseif data.Type == "Gold" then color = Options.GoldColor.Value
            elseif data.Type == "Item" then color = Options.ItemColor.Value
            elseif data.Type == "Objective" then color = Options.ObjColor.Value end
            if Toggles.RainbowESP.Value then color = rainbow end

            if data.Type == "Door" then
                if not data.Box then
                    data.Box = Instance.new("BoxHandleAdornment", obj); data.Box.AlwaysOnTop = true; data.Box.Adornee = obj; data.Box.ZIndex = 5
                end
                data.Box.Visible = true; data.Box.Size = obj.Size; data.Box.Color3 = color; data.Box.Transparency = 0.7
            else
                if not data.Highlight then data.Highlight = Instance.new("Highlight", obj) end
                data.Highlight.Enabled = true; data.Highlight.FillColor = color; data.Highlight.OutlineColor = color; data.Highlight.FillTransparency = 0.5
            end

            if not data.Bill then
                data.Bill = Instance.new("BillboardGui", obj); data.Bill.AlwaysOnTop = true; data.Bill.Size = UDim2.new(0, 150, 0, 40)
                local txt = Instance.new("TextLabel", data.Bill); txt.BackgroundTransparency = 1; txt.Size = UDim2.new(1, 0, 1, 0); txt.Font = "SourceSansBold"; txt.Name = "L"; txt.TextStrokeTransparency = 0
            end
            data.Bill.Enabled = Toggles.EnableText.Value
            data.Bill.StudsOffset = Vector3.new(0, Options.TextHeight.Value, 0)
            local lbl = data.Bill:FindFirstChild("L")
            if lbl then
                lbl.TextColor3 = color; lbl.TextSize = Options.TextSize.Value
                lbl.Text = data.Name .. " [" .. math.floor(dist) .. "]"
            end
        else
            if data.Highlight then data.Highlight.Enabled = false end
            if data.Box then data.Box.Visible = false end
            if data.Bill then data.Bill.Enabled = false end
        end
    end
end

local connection = RunService.RenderStepped:Connect(UpdateESP)

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function()
    connection:Disconnect()
    for obj, data in pairs(activeESPs) do Cleanup(obj, data) end
    Library:Unload()
end)

ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library); SaveManager:BuildConfigSection(Tabs["UI Settings"]); ThemeManager:ApplyToTab(Tabs["UI Settings"]); SaveManager:LoadAutoloadConfig()

end)
