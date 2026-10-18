local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Sniper Arena")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV = 180
Hub:Slider(section, "Game_FOV", "FOV", 180, 30, 1000, function(value) preferences.FOV = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local RS_but_cooler = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CC = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    CC = workspace.CurrentCamera
end)


local Circle = Drawing.new("Circle")
current:Add(function() pcall(function() Circle:Remove() end) end)
Circle.Visible = true
Circle.Thickness = 1
Circle.Radius = preferences.FOV
Circle.Transparency = 0.7
Circle.Color = Color3.fromRGB(255, 255, 255)
Circle.Filled = false
Circle.NumSides = 64

local ES = require(RS.Remote.EntityService)
local CSC = require(RS.Client.CombatController.ClientComponent.ClientShootableComponent)

local thingy = nil

local function target()
    local LocalEntity = ES.GetLocalEntity()
    if not LocalEntity or not LocalEntity.World or not LocalEntity.World.EntitiesByTeam then return nil end
    local MousePos = UIS:GetMouseLocation()
    local closestDis = preferences.FOV
    local ClosestTarget = nil
    for _, TeamDict in pairs(LocalEntity.World.EntitiesByTeam) do
        local Items = TeamDict._items or TeamDict
        for _, Entity in pairs(Items) do
            if not ES.IsLocalEntity(Entity) and Entity:IsAlive() then
                local Inst = Entity.Instance
                local Character = (Inst and Inst:IsA("Player")) and Inst.Character or Inst
                if Character then
                    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                    if Humanoid and Humanoid.Health > 0 then
                        local Part = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Head")
                        if Part and Part:IsA("BasePart") then
                            local ScreenPos, OnScreen = CC:WorldToViewportPoint(Part.Position)
                            if OnScreen then
                                local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude
                                if Distance <= closestDis then
                                    closestDis = Distance
                                    ClosestTarget = { Part = Part, Position = Part.Position }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return ClosestTarget
end

local function upvalues(func)
    for i, val in ipairs(debug.getupvalues(func)) do
        if type(val) == "function" then
            local ok, ret1, ret2, ret3 = pcall(val)
            if ok then
                if typeof(ret1) == "CFrame" and typeof(ret3) == "table" then
                    local OldOriginFn = val
                    current:Add(function() debug.setupvalue(func, i, OldOriginFn) end)
                    debug.setupvalue(func, i, function(...)
                        local cf, pos, meta = OldOriginFn(...)
                        if thingy then
                            return CFrame.lookAt(cf.Position, thingy.Position), pos, meta
                        end
                        return cf, pos, meta
                    end)
                elseif typeof(ret1) == "Vector3" and typeof(ret2) == "Instance" then
                    local OldTargetFn = val
                    current:Add(function() debug.setupvalue(func, i, OldTargetFn) end)
                    debug.setupvalue(func, i, function(...)
                        if thingy then
                            return thingy.Position, thingy.Part
                        end
                        return OldTargetFn(...)
                    end)
                end
            end
        end
    end
end

local LS = CSC.LocalShoot
upvalues(LS)
upvalues(CSC.Shoot)

local hook; hook = hookfunction(LS, function(Self, ...)
    thingy = target()
    local result = hook(Self, ...)
    thingy = nil
    return result
end)

current:Connect(RS_but_cooler.RenderStepped, function()
    Circle.Radius = preferences.FOV
    Circle.Position = UIS:GetMouseLocation()
end)

end, false)
