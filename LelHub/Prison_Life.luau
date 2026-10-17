local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Prison Life", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local FOV_Size = 100
local HIT_PART = "Head"

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")

local local_player = players.LocalPlayer

local fov_circle = Drawing.new("Circle")
fov_circle.Position = user_input_service:GetMouseLocation()
fov_circle.Visible = true
fov_circle.Color = Color3.fromRGB(255, 255, 255)
fov_circle.Radius = FOV_Size
fov_circle.Transparency = 1
fov_circle.Filled = false
fov_circle.NumSides = 64

run_service.PreRender:Connect(function()
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
    local closest_player, closest_position = get_closest_player(HIT_PART, FOV_Size)
    if closest_player and closest_position then
        return closest_player.Character[HIT_PART], closest_position
    end
    return old(...)
end))
]====])
