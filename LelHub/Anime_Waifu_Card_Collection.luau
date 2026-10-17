local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Anime Waifu Card Collection", Style = "Rayfield", Parameters = {}, Action = "Enable game features" }, [====[
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local CollectRemote = remotes:WaitForChild("CollectHeldPack")
local CollectAllCardCash = remotes:WaitForChild("CollectAllCardCash")
local PackReroll = remotes:WaitForChild("PackReroll")
local PackPurchase = remotes:WaitForChild("PackPurchase")
local EquipPackTool = remotes:WaitForChild("EquipPackTool")

local Rayfield = LelHubUI

local Window = Rayfield:CreateWindow({
   Name = "Waifu Script",
   LoadingTitle = "Loading Script",
   LoadingSubtitle = "by PotatoIsCool",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "PotatoScripts", 
      FileName = "PotatosAnimeScript"
   },
   KeySystem = false,
})

local SaveFile = getgenv and getgenv() or SaveFile 
SaveFile.AutoCollect = false
SaveFile.AutoRoll = false


local MainTab = Window:CreateTab("Main", 4483362458)
local Section = MainTab:CreateSection("Main")
local Toggle = MainTab:CreateToggle({
   Name = "Auto Collect Cash",
   CurrentValue = false,
   Flag = "AutoCollectFlag",
   Callback = function(Value)
      SaveFile.AutoCollect = Value
      
      if SaveFile.AutoCollect then
         task.spawn(function()
            while SaveFile.AutoCollect do
               CollectAllCardCash:FireServer()
               task.wait(1) 
            end
         end)
      end
   end,
})


local Button = MainTab:CreateButton({
   Name = "Collect All Cash",
   Callback = function()
      CollectAllCardCash:FireServer()
   end,
})

local TweenService = game:GetService("TweenService")

MainTab:CreateButton({
   Name = "Collect All GradeTokens (BETA)",
   Callback = function()
      local character = Player.Character or Player.CharacterAdded:Wait()
      local hrp = character:WaitForChild("HumanoidRootPart")
      local originalCFrame = hrp.CFrame

      local systems = Workspace:FindFirstChild("Systems")
      if not systems then return end
      local obbyTokens = systems:FindFirstChild("GradeObbyTokens")
      if not obbyTokens then return end

      local function dropOnToken(tokenPart)
         hrp.CFrame = tokenPart.CFrame + Vector3.new(0, 15, 0)
         task.wait(0.8)
      end

      for _, diffName in ipairs({"Easy", "Medium", "Hard"}) do
         local diffFolder = obbyTokens:FindFirstChild(diffName)
         if diffFolder then
            for _, slot in ipairs(diffFolder:GetChildren()) do
               local tokenPart = slot:FindFirstChild("GradeTokenPart")
               if tokenPart then
                  dropOnToken(tokenPart)
                  if tokenPart and tokenPart.Parent then
                     dropOnToken(tokenPart)
                  end
               end
            end
         end
      end

      task.wait(0.2)
      hrp.CFrame = originalCFrame
   end,
})

MainTab:CreateToggle({
   Name = "Auto Collect GradeTokens",
   CurrentValue = false,
   Flag = "AutoGradeTokenFlag",
   Callback = function(Value)
      SaveFile.AutoGradeToken = Value
      if SaveFile.AutoGradeToken then
         task.spawn(function()
            local cooldowns = {
               Easy = 5 * 60,
               Medium = 10 * 60,
               Hard = 15 * 60,
            }
            local lastCollected = {
               Easy = {},
               Medium = {},
               Hard = {},
            }

            local function dropOnToken(tokenPart)
               local character = Player.Character or Player.CharacterAdded:Wait()
               local hrp = character:WaitForChild("HumanoidRootPart")
               hrp.CFrame = tokenPart.CFrame + Vector3.new(0, 15, 0)
               task.wait(0.8)
            end

            while SaveFile.AutoGradeToken do
               local character = Player.Character or Player.CharacterAdded:Wait()
               local hrp = character:WaitForChild("HumanoidRootPart")
               local originalCFrame = hrp.CFrame

               local systems = Workspace:FindFirstChild("Systems")
               local obbyTokens = systems and systems:FindFirstChild("GradeObbyTokens")

               if obbyTokens then
                  local now = os.time()

                  for _, diffName in ipairs({"Easy", "Medium", "Hard"}) do
                     local diffFolder = obbyTokens:FindFirstChild(diffName)
                     if diffFolder then
                        for _, slot in ipairs(diffFolder:GetChildren()) do
                           local tokenPart = slot:FindFirstChild("GradeTokenPart")
                           if tokenPart then
                              local lastTime = lastCollected[diffName][slot.Name] or 0
                              local cd = cooldowns[diffName]

                              if (now - lastTime) >= cd then
                                 dropOnToken(tokenPart)
                                 if not (tokenPart and tokenPart.Parent) then
                                    lastCollected[diffName][slot.Name] = now
                                    Rayfield:Notify({
                                       Title = "GradeToken",
                                       Content = "Collected " .. diffName .. " - " .. slot.Name,
                                       Duration = 3,
                                       Image = 4483362458,
                                    })
                                 else
                                    dropOnToken(tokenPart)
                                    if not (tokenPart and tokenPart.Parent) then
                                       lastCollected[diffName][slot.Name] = now
                                    end
                                 end
                              end
                           end
                        end
                     end
                  end

                  hrp.CFrame = originalCFrame
               end

               task.wait(1)
            end
         end)
      end
   end,
})

local Paragraph = MainTab:CreateParagraph({Title = "Note From Developer:", Content = "There is not to much features. But nobody has made a script for this game and someone was asking for it. So I made it."})


SaveFile.SelectedRarities = {
    ["All"] = false,
    ["Normal"] = false,
    ["Gold"] = false,
    ["Platinum"] = false,
    ["Emerald"] = false,
    ["Diamond"] = false,
    ["Rainbow"] = false,
    ["Nebula"] = false
}

SaveFile.SelectedRanks = {
    ["Princess"] = false, 
    ["Queen"] = false, 
    ["Matriarch"] = false, 
    ["Empress"] = false,
     ["Seraph"] = false, 
     ["Divine"] = false, 
    ["Celestial"] = false, 
    ["Goddess"] = false, 
    ["Valkyrie"] = false, 
    ["Archon"] = false,
    ["Eternal"] = false,
    ["Radiant"] = false,
	["Beyond"] = false
}

SaveFile.AutoBuyPacks = false

local AutoBuy = Window:CreateTab("AutoBuy", 4483362458)
local Dropdown = AutoBuy:CreateDropdown({
   Name = "Select Active Packs",
   Options = {
      "Princess", "Queen", "Matriarch", "Empress", "Seraph",
      "Divine", "Celestial", "Goddess", "Valkyrie", "Archon",
      "Eternal", "Radiant", "Beyond"
   },

   CurrentOption = {}, 
   MultipleOptions = true, 
   Flag = "RankDropdown", 
   Callback = function(Options)
      for rank, _ in pairs(SaveFile.SelectedRanks) do
         SaveFile.SelectedRanks[rank] = false
      end

      for _, selectedName in ipairs(Options) do
         SaveFile.SelectedRanks[selectedName] = true
      end

   end,
})

local RarityDropdown = AutoBuy:CreateDropdown({
    Name = "Select Rarities",
    Options = {
        "All", "Normal", "Gold", "Platinum", "Emerald", "Diamond", "Rainbow", "Nebula"
    },
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "RarityDropdown",
    Callback = function(Options)
        for rarity, _ in pairs(SaveFile.SelectedRarities) do
            SaveFile.SelectedRarities[rarity] = false
        end

        for _, selected in ipairs(Options) do
            SaveFile.SelectedRarities[selected] = true
        end
    end,
})

local Toggle = AutoBuy:CreateToggle({
   Name = "Auto Roll Packs",
   CurrentValue = false,
   Flag = "AutoRollFlag",
   Callback = function(Value)
      SaveFile.AutoRoll = Value
      
      if SaveFile.AutoRoll then
         task.spawn(function()
            while SaveFile.AutoRoll do
               PackReroll:FireServer()
               task.wait(3) 
            end
         end)
      end
   end,
})

local BuyToggle = AutoBuy:CreateToggle({
   Name = "Auto Buy Selected Packs",
   CurrentValue = false,
   Flag = "AutoBuyFlag",
   Callback = function(Value)
      SaveFile.AutoBuyPacks = Value
      
      if SaveFile.AutoBuyPacks then
         task.spawn(function()
            while SaveFile.AutoBuyPacks do
               local myPlot = Workspace.Map.PlotModels:FindFirstChild(Player.Name)
               local station = myPlot and myPlot:FindFirstChild("Systems") 
                  and myPlot.Systems:FindFirstChild("ActivePackStation")
                  and myPlot.Systems.ActivePackStation:FindFirstChild("Station")
                  and myPlot.Systems.ActivePackStation.Station:FindFirstChild("PackParts")

               if station then
                  for i = 1, 4 do
                     local packFolderName = "Pack" .. i
                     local packFolder = station:FindFirstChild(packFolderName)
                     
                     if packFolder then
                        for _, item in ipairs(packFolder:GetChildren()) do
                            if item.Name:find("ActivePack") then

                                local itemRank = item.Name:gsub("ActivePack%-", "")

                                local gui = item:FindFirstChild("PackPriceBillboardGui")
                                local frame = gui and gui:FindFirstChild("Frame")
                                local label = frame and frame:FindFirstChild("VariantLabel")

                                local itemRarity = label and label.Text or ""
                                itemRarity = itemRarity ~= "" and itemRarity or "Normal"

                                if SaveFile.SelectedRanks[itemRank] then
                                    if SaveFile.SelectedRarities["All"] or SaveFile.SelectedRarities[itemRarity] then
                                        PackPurchase:FireServer(i)
                                        task.wait(0.5)
                                        break
                                    end
                                end
                            end
                        end
                     end
                  end
               end
               task.wait(1) 
            end
         end)
      end
   end,
})

local AutoPlace = Window:CreateTab("AutoPlace", 4483362458)
local Toggle = AutoPlace:CreateToggle({
   Name = "Auto Open Ready Packs",
   CurrentValue = false,
   Flag = "AutoOpenFlag",
   Callback = function(Value)
      SaveFile.AutoOpenPacks = Value
      
      if SaveFile.AutoOpenPacks then
         task.spawn(function()
            while SaveFile.AutoOpenPacks do
               local myPlot = Workspace.Map.PlotModels:FindFirstChild(Player.Name)
               
               if myPlot and myPlot:FindFirstChild("Systems") and myPlot.Systems:FindFirstChild("PlacedPacks") then
                  local packs = myPlot.Systems.PlacedPacks:GetChildren()
                  
                  for _, pack in ipairs(packs) do
                     
                     local timerLabel = pack:FindFirstChild("PackModel") 
                        and pack.PackModel:FindFirstChild("PackTimerBillboardGui")
                        and pack.PackModel.PackTimerBillboardGui:FindFirstChild("Frame")
                        and pack.PackModel.PackTimerBillboardGui.Frame:FindFirstChild("TimerLabel")

                     if timerLabel and timerLabel.Text == "Ready" then
                        local packID = pack.Name
                        CollectRemote:FireServer(packID)
                        task.wait(0.1)
                     end
                  end
               end
               
               task.wait(2) 
            end
         end)
      end
   end,
})

local function getPlayerPlot()
    local plotFolder = workspace:WaitForChild("Map"):WaitForChild("PlotModels")
    local userPlot = plotFolder:FindFirstChild(Player.Name)
    
    if userPlot then
        return userPlot:FindFirstChild("Base") or userPlot:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function getInventoryFromUI()
    local hotbar = Player.PlayerGui:FindFirstChild("HotbarGui")
    local mainFrame = hotbar and hotbar:FindFirstChild("MainFrame")
    local items = {}

    if not mainFrame then 
        warn("MainFrame not found!")
        return items 
    end

    for _, obj in pairs(mainFrame:GetChildren()) do
        if obj:IsA("TextButton") and obj.Visible then
            local fullName = obj.Name 
            
            local amountLabel = obj:FindFirstChild("AmountLabel")
            local amount = 1 
            
            if amountLabel then
                local cleanText = amountLabel.Text:gsub("%D", "")
                amount = tonumber(cleanText) or 1
            end
            
            local splitName = string.split(fullName, "_")
            
            if splitName[1] and splitName[2] then
                local rankName = splitName[1] 
                local pType = "_" .. splitName[2] 
                
                if pType == "_Normal" then
                    pType = "Normal"
                end

                print("FOUND: " .. rankName .. " | QUANTITY: " .. amount)
                table.insert(items, {Rank = rankName, Type = pType, Quantity = amount})
            end
        end
    end

    return items
end

local function equipAndPlace(rank, pType, position)
    local character = Player.Character or Player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")
    
    hrp.CFrame = CFrame.new(position + Vector3.new(0, 5, 0))
    task.wait(0.1) 

    humanoid:UnequipTools()
    
    EquipPackTool:FireServer(rank, pType)
    
    local tool = nil
    local start = tick()
    while not tool and (tick() - start) < 1.2 do
        tool = character:FindFirstChildOfClass("Tool") or Player.Backpack:FindFirstChildWhichIsA("Tool")
        task.wait(0.05)
    end

    if tool then
        if tool.Parent == Player.Backpack then
            humanoid:EquipTool(tool)
        end
        
        tool:Activate() 
        
        local placementRemote = ReplicatedStorage.Remotes:FindFirstChild("PlaceItem")
        if placementRemote then
            placementRemote:FireServer(tool.Name, position)
        end
    end
end

AutoPlace:CreateToggle({
   Name = "Auto Place Packs",
   CurrentValue = false,
   Flag = "AutoPlaceUI",
   Callback = function(Value)
      SaveFile.AutoPlace = Value
      
      if SaveFile.AutoPlace then
         task.spawn(function()
            local plotBase = getPlayerPlot()
            if not plotBase then return end

            local size = plotBase.Size
            local margin = 4
            local minX, maxX = -(size.X / 2) + margin, (size.X / 2) - margin
            local minZ, maxZ = -(size.Z / 2) + margin, (size.Z / 2) - margin

            while SaveFile.AutoPlace do
               local visibleItems = getInventoryFromUI()
               
               if #visibleItems == 0 then
                  task.wait(2)
               end

               for _, data in pairs(visibleItems) do
                  for i = 1, data.Quantity do
                      if not SaveFile.AutoPlace then break end
                      
                      local targetPos = (plotBase.CFrame * CFrame.new(
                         math.random(minX, maxX), 
                         (size.Y / 2) + 0.5, 
                         math.random(minZ, maxZ)
                      )).Position

                      equipAndPlace(data.Rank, data.Type, targetPos)
                      task.wait(0.5)
                  end
                  
                  if not SaveFile.AutoPlace then break end
               end
               
               task.wait(1)
            end
         end)
      end
   end,
})

local CreditsTab = Window:CreateTab("Credits", 4483362458)
local Section = CreditsTab:CreateSection("Credits")
local Paragraph = CreditsTab:CreateParagraph({Title = "Note:", Content = "Screw The Skids, We post Open Sourced."})
local Label = CreditsTab:CreateLabel("Developer: PotatoIsCool", 4483362458, Color3.fromRGB(255, 255, 255), false)

local AntiAfkEnabled = false
local AntiAfkThread
local VIM = game:GetService("VirtualInputManager") 

CreditsTab:CreateToggle({
   Name = "Anti-AFK",
   CurrentValue = false,
   Flag = "AntiAfkFlag",
   Callback = function(Value)
      AntiAfkEnabled = Value
      
      local UIS = game:GetService("UserInputService")
      local VirtualUser = game:GetService("VirtualUser")

      if AntiAfkThread then
         task.cancel(AntiAfkThread)
         AntiAfkThread = nil
      end

      if AntiAfkEnabled then
         AntiAfkThread = task.spawn(function()
            while AntiAfkEnabled do
               task.wait(300) 

               VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
               task.wait(0.01)
               VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            end
         end)

         Rayfield:Notify({
            Title = "Anti-AFK Active",
            Content = "Spoofing + Movement (W) active.",
            Duration = 3,
            Image = 4483362458,
         })
      else
         VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)

         Rayfield:Notify({
            Title = "Anti-AFK Disabled",
            Content = "All anti-afk routines stopped.",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

local Themes = {
    ["Default"] = "Default",
    ["Amber Glow"] = "AmberGlow",
    ["Amethyst"] = "Amethyst",
    ["Bloom"] = "Bloom",
    ["Dark Blue"] = "DarkBlue",
    ["Green"] = "Green",
    ["Light"] = "Light",
    ["Ocean"] = "Ocean",
    ["Serenity"] = "Serenity"
}

local ThemeList = {}
for name, _ in pairs(Themes) do
    table.insert(ThemeList, name)
end

CreditsTab:CreateDropdown({
   Name = "Select UI Theme",
   Options = ThemeList,
   CurrentOption = {"Default"},
   MultipleOptions = false,
   Flag = "ThemeSelector", 
   Callback = function(Option)
      local selectedName = Option[1] 
      local themeId = Themes[selectedName]
      if themeId and Window then
          Window.ModifyTheme(themeId)
          
          if SaveFile then
              SaveFile.CurrentTheme = themeId
          end
      else
          warn("Window variable not found! Make sure your window is named 'Window'.")
      end
   end,
})

local function sendSuggestion() end
CreditsTab:CreateInput({
   Name = "Suggested Features",
   PlaceholderText = "Type your idea and press Enter...",
   RemoveTextAfterFocusLost = true, 
   Callback = function(Text)
      sendSuggestion(Text)
   end,
})

local DestroyButton = CreditsTab:CreateButton({Name = "Destroy UI", Callback = function()
      SaveFile.AutoCollect = false
      SaveFile.AutoRoll = false
      SaveFile.AutoOpenPacks = false
      SaveFile.AutoBuyPacks = false
      Rayfield:Destroy()
   end,
})
]====])
