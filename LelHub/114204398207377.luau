local function lelHubFetchSource(url)
    local function text(value)
        if type(value) ~= "string" or not value:find("%S") then return end
        local start = value:sub(1, 160):gsub("^%s+", "")
        start = start:lower()
        if start:find("<!doctype", 1, true) or start:find("<html", 1, true) or start:find("404: not found", 1, true) then return end
        return value
    end
    local methods = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
    }
    local send = request or http_request or (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    if type(send) == "function" then
        table.insert(methods, function()
            local response = send({ Url = url, Method = "GET", Timeout = 15 })
            if type(response) == "string" then return response end
            if type(response) ~= "table" or response.Success == false then return end
            local status = tonumber(response.StatusCode or response.Status)
            if status and (status < 200 or status >= 300) then return end
            return response.Body or response.body
        end)
    end
    for attempt = 1, 2 do
        for _, fetch in ipairs(methods) do
            local ok, response = pcall(fetch)
            local source = ok and text(response)
            if source then return source end
        end
        if attempt < 2 then task.wait(0.25) end
    end
    error("[LelHub] Download returned no script text: " .. url, 0)
end

local function lelHubCompileRemote(url, name)
    if type(loadstring) ~= "function" then error("[LelHub] This executor does not provide loadstring.", 0) end
    local source = lelHubFetchSource(url)
    local ok, chunk, message = pcall(loadstring, source, name or "LelHub/Remote")
    if not ok or type(chunk) ~= "function" then error("[LelHub] Downloaded script could not compile: " .. tostring(message or chunk), 0) end
    return chunk
end

local function lelHubLoadInterface()
    local urls = {
        "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/f.luau",
        "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau",
    }
    local lastError
    for _, url in ipairs(urls) do
        local ok, library = pcall(function() return lelHubCompileRemote(url, "LelHub/Fluent")() end)
        if ok and type(library) == "table" and type(library.CreateWindow) == "function" then return library end
        lastError = ok and "The interface did not return a valid library." or tostring(library)
    end
    error("[LelHub] Could not load the interface. " .. tostring(lastError), 0)
end

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Survive Zombie Arena")
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

