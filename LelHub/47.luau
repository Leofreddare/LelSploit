local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Rising of Aliens")
local LelUI = Hub.Native
local LelAPI = Hub:Interface("Rayfield")
task.spawn(function()
local SupportedGame = 99365835174711

if game.PlaceId ~= SupportedGame then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Rising of Aliens Script",
        Text = "Game not supported",
        Duration = 5
    })
    return
end

local Rayfield = LelAPI

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Rising of Aliens Script",
    LoadingTitle = "Rising of Aliens Script",
    LoadingSubtitle = "Loading...",
    ShowText = "ROA SCRIPT",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Rising of Aliens Script",
        FileName = "Configuration"
    },
    KeySystem = false
})

local function HasMaxMastery()
    local mastery = LocalPlayer:WaitForChild("PlayerStats"):WaitForChild("Mastery")
    return mastery.Value >= 250
end

local function GetMastery()
    local mastery = LocalPlayer:WaitForChild("PlayerStats"):WaitForChild("Mastery")
    return mastery.Value
end

local function IsOmnitrixHolder()
    return LocalPlayer.Team and LocalPlayer.Team.Name == "OmnitrixHolders"
end

local function IsAnodite()
    return LocalPlayer.Team and LocalPlayer.Team.Name == "Anodites"
end

local function IsOsmosian()
    return LocalPlayer.Team and LocalPlayer.Team.Name == "Osmosians"
end

local function IsScriptOwner()
    local allowedIDs = {USERID, USERID}
    for _, id in ipairs(allowedIDs) do
        if LocalPlayer.UserId == id then
            return true
        end
    end
    return false
end

local function GiveMastery()
    if HasMaxMastery() then
        return false
    end
    local args = {0, true}
    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("MasteryEvent"):FireServer(unpack(args))
    return true
end

local BatteryCooldown = false
local OmnitrixCooldown = false
local FakeCooldown = false
local AnoditeCooldown = false
local OsmosianTransformCooldown = false
local OsmosianDetransformCooldown = false

local GetMaxMasteryRunning = false
local MaxMasteryThread = nil
local GetMasteryV2Running = false
local GetMasteryV2Thread = nil

local OmnitrixTab = Window:CreateTab("Omnitrix", 4483362458)

OmnitrixTab:CreateSection("Choose Omnitrix")

OmnitrixTab:CreateButton({
    Name = "AF",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if OmnitrixCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 3 seconds", Duration = 2 })    
            return    
        end    
        OmnitrixCooldown = true    
        local args = { "AF", "AF" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Changed to AF", Duration = 3 })    
        task.wait(3)    
        OmnitrixCooldown = false
    end
})

OmnitrixTab:CreateButton({
    Name = "OS",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if OmnitrixCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 3 seconds", Duration = 2 })    
            return    
        end    
        OmnitrixCooldown = true    
        local args = { "OS", "OS" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Changed to OS", Duration = 3 })    
        task.wait(3)    
        OmnitrixCooldown = false
    end
})

OmnitrixTab:CreateButton({
    Name = "UA",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if OmnitrixCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 3 seconds", Duration = 2 })    
            return    
        end    
        OmnitrixCooldown = true    
        local args = { "UA", "UA" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Changed to UA", Duration = 3 })    
        task.wait(3)    
        OmnitrixCooldown = false
    end
})

OmnitrixTab:CreateButton({
    Name = "Fake Recalibration",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if FakeCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 14 seconds", Duration = 2 })    
            return    
        end    
        FakeCooldown = true    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixEffectEvent"):FireServer()    
        Rayfield:Notify({ Title = "Success", Content = "Fake Recalibration Activated", Duration = 3 })    
        task.wait(14)    
        FakeCooldown = false
    end
})

OmnitrixTab:CreateSection("Skins")

local SelectedOS = "OS"
OmnitrixTab:CreateDropdown({
    Name = "Choose OS Skin",
    Options = {"OS", "OSMad", "Delta", "Absolute", "OSRecal", "OSInfected"},
    CurrentOption = {"OS"},
    MultipleOptions = false,
    Flag = "OSDropdown",
    Callback = function(Option) SelectedOS = Option[1] end,
})

OmnitrixTab:CreateButton({
    Name = "Equip Selected OS",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        local args = { SelectedOS, "OS" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Equipped "..SelectedOS, Duration = 3 })
    end
})

local SelectedAF = "AF"
OmnitrixTab:CreateDropdown({
    Name = "Choose AF Skin",
    Options = {"AF", "AFSkin1", "AFSkin2", "AFSkin3", "OSRec", "AFInfected"},
    CurrentOption = {"AF"},
    MultipleOptions = false,
    Flag = "AFDropdown",
    Callback = function(Option) SelectedAF = Option[1] end,
})

OmnitrixTab:CreateButton({
    Name = "Equip Selected AF",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        local args = { SelectedAF, "AF" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Equipped "..SelectedAF, Duration = 3 })
    end
})

local SelectedUA = "UA"
OmnitrixTab:CreateDropdown({
    Name = "Choose UA Skin",
    Options = {"UA", "UASkin1", "UASkin2", "UAInfected"},
    CurrentOption = {"UA"},
    MultipleOptions = false,
    Flag = "UADropdown",
    Callback = function(Option) SelectedUA = Option[1] end,
})

OmnitrixTab:CreateButton({
    Name = "Equip Selected UA",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        local args = { SelectedUA, "UA" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("OmnitrixAllEvent"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Equipped "..SelectedUA, Duration = 3 })
    end
})

OmnitrixTab:CreateSection("Mastery")

OmnitrixTab:CreateParagraph({
    Title = "Instruction",
    Content = "Press the mastery button to get mastery ofc :D also its FE and u actually get mastery"
})

OmnitrixTab:CreateButton({
    Name = "Get Mastery",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning or GetMasteryV2Running then return end
        if GiveMastery() then
            Rayfield:Notify({ Title = "Success", Content = "Mastery Given", Duration = 3 })
        end
    end
})

OmnitrixTab:CreateButton({
    Name = "Get Max Mastery",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end
        if HasMaxMastery() then    
            Rayfield:Notify({ Title = "Max Mastery", Content = "Max Mastery already reached", Duration = 3 })    
            return    
        end

        GetMaxMasteryRunning = true
        if MaxMasteryThread then MaxMasteryThread:Disconnect() end

        MaxMasteryThread = task.spawn(function()
            while GetMaxMasteryRunning and not HasMaxMastery() do
                local currentMastery = GetMastery()
                if currentMastery >= 246 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if HasMaxMastery() then
                Rayfield:Notify({ Title = "Complete", Content = "Max Mastery (250) reached!", Duration = 3 })
            end
            GetMaxMasteryRunning = false
            MaxMasteryThread = nil
        end)
    end
})


OmnitrixTab:CreateSection("Get Mastery V2")

OmnitrixTab:CreateParagraph({
    Title = "Instructions",
    Content = [[1. Enter target mastery (1-250)
2. Click Get Mastery (V2) to start
3. Slows down when within 5 of target
4. Shows error if already past target
5. Click Stop to cancel anytime]]
})

local TargetMasteryInput = OmnitrixTab:CreateInput({
    Name = "Target Mastery (1-250)",
    PlaceholderText = "Enter number (1-250)",
    CurrentText = "",
    RemoveTextAfter = false,
    Flag = "TargetMasteryInput",
    Callback = function(Text) end,
})

OmnitrixTab:CreateButton({
    Name = "Get Mastery (V2)",
    Callback = function()
        if not IsOmnitrixHolder() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in OmnitrixHolders", Duration = 3 })    
            return    
        end
        
        local input = TargetMasteryInput:Get()
        local target = tonumber(input)
        if not target then target = 1 end
        if target < 1 then target = 1 end
        if target > 250 then target = 250 end
        
        local current = GetMastery()
        if current >= target then
            Rayfield:Notify({ Title = "Already Past", Content = "ur already past that mastery", Duration = 4 })
            return
        end
        
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end

        GetMasteryV2Running = true
        if GetMasteryV2Thread then GetMasteryV2Thread:Disconnect() end

        GetMasteryV2Thread = task.spawn(function()
            while GetMasteryV2Running and GetMastery() < target do
                local curr = GetMastery()
                if target - curr <= 5 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if GetMastery() >= target then
                Rayfield:Notify({ Title = "Complete", Content = "Reached Mastery " .. target .. "!", Duration = 3 })
            end
            GetMasteryV2Running = false
            GetMasteryV2Thread = nil
        end)
    end
})

OmnitrixTab:CreateButton({
    Name = "Stop Get Mastery (V2)",
    Callback = function()
        if not GetMasteryV2Running then
            Rayfield:Notify({ Title = "Not Running", Content = "Get Mastery V2 is not running", Duration = 2 })
            return
        end
        GetMasteryV2Running = false
        if GetMasteryV2Thread then
            GetMasteryV2Thread:Disconnect()
            GetMasteryV2Thread = nil
        end
        Rayfield:Notify({ Title = "Stopped", Content = "Get Mastery V2 stopped", Duration = 2 })
    end
})

local AnoditeTab = Window:CreateTab("Anodite", 4483362458)

AnoditeTab:CreateSection("Transformation")

AnoditeTab:CreateButton({
    Name = "Activate Transform",
    Callback = function()
        if not IsAnodite() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Anodites team", Duration = 3 })    
            return    
        end    
        if AnoditeCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 3 seconds", Duration = 2 })    
            return    
        end    
        AnoditeCooldown = true    
        local args = { "Activate" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RaceEvents"):WaitForChild("AnoditeStage1Event"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Anodite Activated", Duration = 3 })    
        task.wait(3)    
        AnoditeCooldown = false
    end
})

AnoditeTab:CreateButton({
    Name = "Deactivate Transform",
    Callback = function()
        if not IsAnodite() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Anodites team", Duration = 3 })    
            return    
        end    
        if AnoditeCooldown then    
            Rayfield:Notify({ Title = "Cooldown", Content = "Wait 3 seconds", Duration = 2 })    
            return    
        end    
        AnoditeCooldown = true    
        local args = { "Deactivate" }    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RaceEvents"):WaitForChild("AnoditeStage1Event"):FireServer(unpack(args))    
        Rayfield:Notify({ Title = "Success", Content = "Anodite Deactivated", Duration = 3 })    
        task.wait(3)    
        AnoditeCooldown = false
    end
})

AnoditeTab:CreateSection("Mastery")

AnoditeTab:CreateButton({
    Name = "Get Mastery",
    Callback = function()
        if not IsAnodite() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Anodites team", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning or GetMasteryV2Running then return end
        if GiveMastery() then
            Rayfield:Notify({ Title = "Success", Content = "Mastery Given", Duration = 3 })
        end
    end
})

AnoditeTab:CreateButton({
    Name = "Get Max Mastery",
    Callback = function()
        if not IsAnodite() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Anodites team", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end
        if HasMaxMastery() then    
            Rayfield:Notify({ Title = "Max Mastery", Content = "Max Mastery already reached", Duration = 3 })    
            return    
        end

        GetMaxMasteryRunning = true
        if MaxMasteryThread then MaxMasteryThread:Disconnect() end

        MaxMasteryThread = task.spawn(function()
            while GetMaxMasteryRunning and not HasMaxMastery() do
                local currentMastery = GetMastery()
                if currentMastery >= 246 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if HasMaxMastery() then
                Rayfield:Notify({ Title = "Complete", Content = "Max Mastery (250) reached!", Duration = 3 })
            end
            GetMaxMasteryRunning = false
            MaxMasteryThread = nil
        end)
    end
})

local OsmosianTab = Window:CreateTab("Osmosian", 4483362458)

OsmosianTab:CreateSection("Mastery")

OsmosianTab:CreateButton({
    Name = "Get Mastery",
    Callback = function()
        if not IsOsmosian() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Osmosians team", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning or GetMasteryV2Running then return end
        if GiveMastery() then
            Rayfield:Notify({ Title = "Success", Content = "Mastery Given", Duration = 3 })
        end
    end
})

OsmosianTab:CreateButton({
    Name = "Get Max Mastery",
    Callback = function()
        if not IsOsmosian() then    
            Rayfield:Notify({ Title = "Failed", Content = "You are not in the Osmosians team", Duration = 3 })    
            return    
        end    
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end
        if HasMaxMastery() then    
            Rayfield:Notify({ Title = "Max Mastery", Content = "Max Mastery already reached", Duration = 3 })    
            return    
        end

        GetMaxMasteryRunning = true
        if MaxMasteryThread then MaxMasteryThread:Disconnect() end

        MaxMasteryThread = task.spawn(function()
            while GetMaxMasteryRunning and not HasMaxMastery() do
                local currentMastery = GetMastery()
                if currentMastery >= 246 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if HasMaxMastery() then
                Rayfield:Notify({ Title = "Complete", Content = "Max Mastery (250) reached!", Duration = 3 })
            end
            GetMaxMasteryRunning = false
            MaxMasteryThread = nil
        end)
    end
})

local MasteryTab = Window:CreateTab("Mastery", 4483362458)

MasteryTab:CreateSection("Universal Mastery")

MasteryTab:CreateButton({
    Name = "Get Mastery",
    Callback = function()
        if GetMaxMasteryRunning or GetMasteryV2Running then return end
        if GiveMastery() then
            Rayfield:Notify({ Title = "Success", Content = "Mastery Given", Duration = 3 })
        end
    end
})

MasteryTab:CreateButton({
    Name = "Get Max Mastery",
    Callback = function()
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end
        if HasMaxMastery() then    
            Rayfield:Notify({ Title = "Max Mastery", Content = "Max Mastery already reached", Duration = 3 })    
            return    
        end

        GetMaxMasteryRunning = true
        if MaxMasteryThread then MaxMasteryThread:Disconnect() end

        MaxMasteryThread = task.spawn(function()
            while GetMaxMasteryRunning and not HasMaxMastery() do
                local currentMastery = GetMastery()
                if currentMastery >= 246 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if HasMaxMastery() then
                Rayfield:Notify({ Title = "Complete", Content = "Max Mastery (250) reached!", Duration = 3 })
            end
            GetMaxMasteryRunning = false
            MaxMasteryThread = nil
        end)
    end
})


MasteryTab:CreateSection("Get Mastery V2")

MasteryTab:CreateParagraph({
    Title = "Instructions",
    Content = [[1. Enter target mastery (1-250)
2. Click Get Mastery (V2) to start
3. Slows down when within 5 of target
4. Shows error if already past target
5. Click Stop to cancel anytime]]
})

local GlobalTargetMasteryInput = MasteryTab:CreateInput({
    Name = "Target Mastery (1-250)",
    PlaceholderText = "Enter number (1-250)",
    CurrentText = "",
    RemoveTextAfter = false,
    Flag = "GlobalTargetMasteryInput",
    Callback = function(Text) end,
})

MasteryTab:CreateButton({
    Name = "Get Mastery (V2)",
    Callback = function()
        local input = GlobalTargetMasteryInput:Get()
        local target = tonumber(input)
        if not target then target = 1 end
        if target < 1 then target = 1 end
        if target > 250 then target = 250 end
        
        local current = GetMastery()
        if current >= target then
            Rayfield:Notify({ Title = "Already Past", Content = "ur already past that mastery", Duration = 4 })
            return
        end
        
        if GetMaxMasteryRunning then    
            Rayfield:Notify({ Title = "Already Running", Content = "Max mastery is running", Duration = 2 })    
            return    
        end
        if GetMasteryV2Running then    
            Rayfield:Notify({ Title = "Already Running", Content = "Get Mastery V2 is running", Duration = 2 })    
            return    
        end

        GetMasteryV2Running = true
        if GetMasteryV2Thread then GetMasteryV2Thread:Disconnect() end

        GetMasteryV2Thread = task.spawn(function()
            while GetMasteryV2Running and GetMastery() < target do
                local curr = GetMastery()
                if target - curr <= 5 then
                    task.wait(1)
                else
                    task.wait(0.2)
                end
                GiveMastery()
            end
            if GetMastery() >= target then
                Rayfield:Notify({ Title = "Complete", Content = "Reached Mastery " .. target .. "!", Duration = 3 })
            end
            GetMasteryV2Running = false
            GetMasteryV2Thread = nil
        end)
    end
})

MasteryTab:CreateButton({
    Name = "Stop Get Mastery (V2)",
    Callback = function()
        if not GetMasteryV2Running then
            Rayfield:Notify({ Title = "Not Running", Content = "Get Mastery V2 is not running", Duration = 2 })
            return
        end
        GetMasteryV2Running = false
        if GetMasteryV2Thread then
            GetMasteryV2Thread:Disconnect()
            GetMasteryV2Thread = nil
        end
        Rayfield:Notify({ Title = "Stopped", Content = "Get Mastery V2 stopped", Duration = 2 })
    end
})

local TeleportTab = Window:CreateTab("Teleports", 4483362458)

TeleportTab:CreateSection("Map Teleports")

TeleportTab:CreateButton({
    Name = "Colors",
    Callback = function()
        local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()    
        local HRP = Character:WaitForChild("HumanoidRootPart")    
        HRP.CFrame = CFrame.new(1704, 206, -1336)    
        Rayfield:Notify({ Title = "Success", Content = "Teleported to Colors", Duration = 3 })
    end
})

local PathTab = Window:CreateTab("Path", 4483362458)

PathTab:CreateSection("Path Controls")

PathTab:CreateButton({
    Name = "Remove Path",
    Callback = function()
        if LocalPlayer.Team and LocalPlayer.Team.Name == "Humans" then    
            Rayfield:Notify({ Title = "Failed", Content = "Pick a path first", Duration = 3 })    
            return    
        end    
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("PATHRemoveEvent"):FireServer()    
        Rayfield:Notify({ Title = "Success", Content = "Path Removed", Duration = 3 })
    end
})

local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("UI")

SettingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        Rayfield:Destroy()
    end
})

local SOwnerTab = Window:CreateTab("S-Owner", 4483362458)

local SelectedPlayer = nil

SOwnerTab:CreateSection("S-Owner Commands")

local PlayerList = {}
local PlayerDropdown = SOwnerTab:CreateDropdown({
    Name = "Choose Player",
    Options = {},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "KillPlayerDropdown",
    Callback = function(Option) SelectedPlayer = Option[1] end,
})

local function GetPlayers()
    local NewList = {}
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            table.insert(NewList, Player.Name)
        end
    end
    table.sort(NewList)
    return NewList
end

local function ListsEqual(Table1, Table2)
    if #Table1 ~= #Table2 then return false end
    for i = 1, #Table1 do
        if Table1[i] ~= Table2[i] then return false end
    end
    return true
end

PlayerList = GetPlayers()
PlayerDropdown:Refresh(PlayerList)

task.spawn(function()
    while true do
        task.wait(2)
        local NewPlayers = GetPlayers()
        if not ListsEqual(PlayerList, NewPlayers) then
            PlayerList = NewPlayers
            PlayerDropdown:Refresh(PlayerList)
            if SelectedPlayer and not table.find(PlayerList, SelectedPlayer) then
                SelectedPlayer = nil
            end
        end
    end
end)

SOwnerTab:CreateButton({
    Name = "Kill",
    Callback = function()
        if not IsScriptOwner() then
            Rayfield:Notify({ Title = "Denied", Content = "You are not the script owner", Duration = 3 })
            return
        end
        if not SelectedPlayer then
            Rayfield:Notify({ Title = "Failed", Content = "Choose a player", Duration = 3 }) 
            return
        end
        local Target = Players:FindFirstChild(SelectedPlayer)
        if not Target or not Target.Character then
            Rayfield:Notify({ Title = "Failed", Content = "Player/Character not found", Duration = 3 }) 
            return
        end
        local TargetHumanoid = Target.Character:FindFirstChild("Humanoid")
        if not TargetHumanoid then
            Rayfield:Notify({ Title = "Failed", Content = "Humanoid missing", Duration = 3 }) 
            return
        end
        if not LocalPlayer.Character then
            Rayfield:Notify({ Title = "Failed", Content = "Your character not found", Duration = 3 })
            return
        end
        local Hits = math.random(18,26)
        Rayfield:Notify({ Title = "Attack Started", Content = "Hits: "..Hits, Duration = 3 })
        for i = 1, Hits do
            if not Target.Character then break end
            local args = {
                game:GetService("Players"):WaitForChild(SelectedPlayer).Character:WaitForChild("Humanoid"),
                "Punch"
            }
            game:GetService("Players").LocalPlayer.Character:WaitForChild("Skills"):WaitForChild("Punch-F"):WaitForChild("AttackEvent"):FireServer(unpack(args))
            task.wait(0.1)
        end
        Rayfield:Notify({ Title = "Success", Content = "Attacked "..SelectedPlayer, Duration = 3 })
    end
})

SOwnerTab:CreateSection("Omnitrix Transform")

local SelectedOmnitrixTransform = "Fasttrack"

SOwnerTab:CreateDropdown({
    Name = "Choose Alien",
    Options = {"Fasttrack"},
    CurrentOption = {"Fasttrack"},
    MultipleOptions = false,
    Flag = "OmnitrixTransformDropdown",
    Callback = function(Option) SelectedOmnitrixTransform = Option[1] end,
})

SOwnerTab:CreateButton({
    Name = "Transform",
    Callback = function()
        if not IsScriptOwner() then
            Rayfield:Notify({ Title = "Denied", Content = "You are not the script owner", Duration = 3 })
            return
        end
        local args = { SelectedOmnitrixTransform }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Transform"):FireServer(unpack(args))
        Rayfield:Notify({ Title = "Success", Content = "Transformed to "..SelectedOmnitrixTransform, Duration = 3 })
    end
})

SOwnerTab:CreateButton({
    Name = "Detransform",
    Callback = function()
        if not IsScriptOwner() then
            Rayfield:Notify({ Title = "Denied", Content = "You are not the script owner", Duration = 3 })
            return
        end
        local args = { true }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Detransform"):FireServer(unpack(args))
        Rayfield:Notify({ Title = "Success", Content = "Detransformed", Duration = 3 })
    end
})

SOwnerTab:CreateSection("Ultimates")

local SelectedUltimate = "XLR8"

SOwnerTab:CreateDropdown({
    Name = "Choose Ultimate",
    Options = {"XLR8", "Diamondhead"},
    CurrentOption = {"XLR8"},
    MultipleOptions = false,
    Flag = "UltimateDropdown",
    Callback = function(Option) SelectedUltimate = Option[1] end,
})

SOwnerTab:CreateButton({
    Name = "Transform (U)",
    Callback = function()
        if not IsScriptOwner() then
            Rayfield:Notify({ Title = "Denied", Content = "You are not the script owner", Duration = 3 })
            return
        end
        local args = { SelectedUltimate }
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("UltimateTransform"):FireServer(unpack(args))
        Rayfield:Notify({ Title = "Success", Content = "Ultimate Transformed to "..SelectedUltimate, Duration = 3 })
    end
})

Rayfield:Notify({
    Title = "Rising of Aliens Script",
    Content = "Loaded Successfully!",
    Duration = 5
})

end)
