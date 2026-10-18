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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Combat Warriors")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
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

