local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Survive Zombie Arena")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Weapons")
local rapid, automatic, interval = false, false, 0.05
local originals, configs = {}, nil
local fields = { "Automatic", "AutoFire", "HoldToFire", "FullAuto" }
local function save(object, property)
    originals[object] = originals[object] or {}
    if not originals[object][property] then originals[object][property] = { object[property] } end
end
local function restore()
    for object, values in pairs(originals) do for property, value in pairs(values) do object[property] = value[1] end end
    originals = {}
end
local function apply()
    restore()
    if not rapid and not automatic then return end
    if not configs then
        local data = game:GetService("ReplicatedStorage"):FindFirstChild("Data")
        if not data or not data:FindFirstChild("GunConfig") or not data:FindFirstChild("UpgradeShopData") then Hub:Notify("Weapon modules are not loaded.") return end
        configs = { require(data.GunConfig), require(data.UpgradeShopData) }
    end
    local gun, shop = configs[1], configs[2]
    if rapid and gun.Defaults then save(gun.Defaults, "FireRate") gun.Defaults.FireRate = interval end
    for _, config in pairs(gun.Guns or {}) do
        if rapid then for _, property in ipairs({ "FireRate", "SoundCooldown" }) do save(config, property) config[property] = interval end end
        if automatic then for _, property in ipairs(fields) do save(config, property) config[property] = true end end
    end
    if rapid then for _, weapon in pairs(shop.Weapons or {}) do for _, tier in pairs(weapon.Tiers or {}) do save(tier, "FireRate") tier.FireRate = interval end end end
end
local rapidControl = Hub:Toggle(section, "RapidFire", "Rapid Fire", function(value) rapid = value apply() end, false)
local autoControl = Hub:Toggle(section, "Automatic", "Automatic Fire", function(value) automatic = value apply() end, false)
Hub:Slider(section, "FireInterval", "Fire Interval", interval, 0.01, 1, function(value) interval = value apply() end, 2)
Hub:Button(section, "Restore Weapons", function() rapidControl:SetValue(false) autoControl:SetValue(false) restore() end)
Hub:Add(restore)

