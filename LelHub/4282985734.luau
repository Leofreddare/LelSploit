local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Combat Warriors")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local section = Hub.Tabs.Game:CreateSection("Hitboxes")
local enabled, size, transparency = false, 10, 0.7
local originals = {}
local function restore()
    for part, values in pairs(originals) do if part.Parent then for property, value in pairs(values) do part[property] = value end end end
    originals = {}
end
Hub:Toggle(section, "HeadHitbox", "Head Hitbox", function(value) enabled = value if not value then restore() end end, false)
Hub:Slider(section, "HeadSize", "Hitbox Size", 10, 2, 30, function(value) size = value end)
Hub:Slider(section, "HeadTransparency", "Transparency", 0.7, 0, 1, function(value) transparency = value end, 2)
Hub:Button(section, "Reset Hitboxes", function() enabled = false restore() Hub.Controls.HeadHitbox:SetValue(false) end)
local elapsed = 0
Hub:Connect(game:GetService("RunService").Heartbeat, function(delta)
    elapsed = elapsed + delta
    if not enabled or elapsed < 0.1 then return end
    elapsed = 0
    local players = game:GetService("Players")
    for _, target in ipairs(players:GetPlayers()) do
        local head = target ~= players.LocalPlayer and target.Character and target.Character:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            if not originals[head] then originals[head] = { Size = head.Size, Transparency = head.Transparency, CanCollide = head.CanCollide, Massless = head.Massless } end
            head.Size, head.Transparency, head.CanCollide, head.Massless = Vector3.new(size, size, size), transparency, false, true
        end
    end
    for part in pairs(originals) do if not part.Parent then originals[part] = nil end end
end)
Hub:Add(restore)

