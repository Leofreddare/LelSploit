local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Infinite Nights With Freddy (DOOM)", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera


local ESP_COLOR = Color3.fromRGB(255, 0, 0)
local ESP_THICKNESS = 1
local FONT = Drawing.Fonts.UI
local TEXT_SIZE = 14
local MAX_DISTANCE = 500

local espObjects = {}

local function createESP(model)
    local data = {}

    local highlight = Instance.new("BoxHandleAdornment")
    highlight.Size = model:GetExtentsSize()
    highlight.Color3 = ESP_COLOR
    highlight.AlwaysOnTop = true
    highlight.Transparency = 0.5
    highlight.ZIndex = 5
    highlight.Adornee = model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart
    highlight.Parent = game.CoreGui

    local label = Drawing.new("Text")
    label.Text = model.Name
    label.Size = TEXT_SIZE
    label.Font = FONT
    label.Color = ESP_COLOR
    label.Outline = true
    label.Center = true
    label.Visible = false

    data.highlight = highlight
    data.label = label
    data.model = model

    return data
end

local function removeESP(data)
    if data.highlight then data.highlight:Destroy() end
    if data.label then data.label:Remove() end
end

local function findAnimatronics()
    local folder = workspace:FindFirstChild("Animatronics")
    if not folder then
        warn("No se encontró la carpeta 'Animatronics' en Workspace.")
        return
    end

    
    for _, data in pairs(espObjects) do
        removeESP(data)
    end
    espObjects = {}

    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            espObjects[model] = createESP(model)
        end
    end
end

RunService.RenderStepped:Connect(function()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    for model, data in pairs(espObjects) do
        if not model or not model.Parent then
            removeESP(data)
            espObjects[model] = nil
        else
            local rootOrPrimary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if rootOrPrimary then
                local position = rootOrPrimary.Position
                local screenPos, onScreen = Camera:WorldToViewportPoint(position)
                local dist = rootPart and (rootPart.Position - position).Magnitude or 0

                if onScreen and dist <= MAX_DISTANCE then
                    data.label.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                    data.label.Visible = true

                    data.label.Text = string.format("%s [%.0fm]", model.Name, dist)
                else
                    data.label.Visible = false
                end
            end
        end
    end
end)

local folder = workspace:FindFirstChild("Animatronics")
if folder then
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            espObjects[child] = createESP(child)
        end
    end)

    folder.ChildRemoved:Connect(function(child)
        if espObjects[child] then
            removeESP(espObjects[child])
            espObjects[child] = nil
        end
    end)
end

findAnimatronics()
print("ESP de Animatronics activado.")
]====])
