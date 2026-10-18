local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Prison Life")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.FOV_Size = 100
Hub:Slider(section, "Game_FOV_Size", "FOV", 100, 30, 1000, function(value) preferences.FOV_Size = value end)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn

local HIT_PART = "Head"

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")

local local_player = players.LocalPlayer

local fov_circle = Drawing.new("Circle")
current:Add(function() pcall(function() fov_circle:Remove() end) end)
fov_circle.Position = user_input_service:GetMouseLocation()
fov_circle.Visible = true
fov_circle.Color = Color3.fromRGB(255, 255, 255)
fov_circle.Radius = preferences.FOV_Size
current:Connect(current, run_service.Heartbeat, function() fov_circle.Radius = preferences.FOV_Size end)
fov_circle.Transparency = 1
fov_circle.Filled = false
fov_circle.NumSides = 64

current:Connect(run_service.PreRender, function()
    fov_circle.Position = user_input_service:GetMouseLocation()
end)

local function get_closest_player(part_name, fov)
    fov = fov or math.huge
    local closest_player = nil
    local closest_position = nil
    local closest_distance = fov

    for _, player in players:GetPlayers() do
        if player == local_player or player.Team == local_player.Team then
            continue
        end
        
        local character = player.Character
        if not character then
            continue
        end
        
        local part = character:FindFirstChild(part_name)
        if not part then
            continue
        end
        
        local screen_position = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
        if screen_position.Z <= 0 then
            continue
        end
        
        local screen_center = user_input_service:GetMouseLocation()
        local screen_distance = (Vector2.new(screen_position.X, screen_position.Y) - screen_center).Magnitude
        
        if screen_distance < closest_distance then
            closest_player = player
            closest_position = part.Position
            closest_distance = screen_distance
        end
    end

    return closest_player, closest_position
end

LPH_NO_UPVALUES = function(Function)
    return function(...)
        return Function(...)
    end
end

local castRay = filtergc("function", {Name = "castRay"}, true)
local old; old = hookfunction(castRay, LPH_NO_UPVALUES(function(...)
    local closest_player, closest_position = get_closest_player(HIT_PART, preferences.FOV_Size)
    if closest_player and closest_position then
        return closest_player.Character[HIT_PART], closest_position
    end
    return old(...)
end))

end, false)
