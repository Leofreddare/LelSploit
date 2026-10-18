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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Anime Vanguards")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer


local KEY_MAP = {
    Button1 = Enum.KeyCode.A,
    Button2 = Enum.KeyCode.S,
    Button3 = Enum.KeyCode.D,
    Button4 = Enum.KeyCode.F,
    Button5 = Enum.KeyCode.G
}

local EARLY_HIT_PIXELS = 15  
local TAP_DURATION = 0.02    

local autoPlayEnabled = false
local isMinigameRunning = false
local activeNotes = {}
local renderConnection = nil

local function pressKey(key, state)
    VirtualInputManager:SendKeyEvent(state, key, false, game)
end

local function releaseAllKeys()
    for _, data in pairs(activeNotes) do
        if data.Pressed and not data.Released then
            pressKey(data.Key, false)
            data.Released = true
        end
    end
end

LelUI:Control(nil, "Toggle", "Auto guitar", autoPlayEnabled, function(value)
    autoPlayEnabled = value
    if not autoPlayEnabled then releaseAllKeys() end
end)
local function getMinigameBottom()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GuitarMinigame = PlayerGui:FindFirstChild("GuitarMinigame")
        if GuitarMinigame and GuitarMinigame:FindFirstChild("Page") and GuitarMinigame.Page:FindFirstChild("Main") then
            return GuitarMinigame.Page.Main:FindFirstChild("Bottom")
        end
    end
    return nil
end

local function registerNote(note, buttonName, buttonElement)
    local key = KEY_MAP[buttonName]
    if not key then return end

    activeNotes[note] = {
        Key = key,
        Button = buttonElement,
        Pressed = false,
        Released = false,
        IsHold = false,
        Direction = 1,
        LastY = nil
    }
end

local function setupMinigame(bottom)
    table.clear(activeNotes)

    for buttonName, key in pairs(KEY_MAP) do
        local button = bottom:FindFirstChild(buttonName)
        if button and button:FindFirstChild("Conveyor") then
            local conveyor = button.Conveyor
            
            for _, child in ipairs(conveyor:GetChildren()) do
                if child.Name == "Note" and child:IsA("GuiObject") then
                    registerNote(child, buttonName, button)
                end
            end

            Hub:Connect(conveyor.ChildAdded, function(child)
                if child.Name == "Note" and child:IsA("GuiObject") then
                    registerNote(child, buttonName, button)
                end
            end)

            Hub:Connect(conveyor.ChildRemoved, function(child)
                local noteData = activeNotes[child]
                if noteData then
                    if noteData.Pressed and not noteData.Released then
                        pressKey(noteData.Key, false)
                    end
                    activeNotes[child] = nil
                end
            end)
        end
    end

    renderConnection = Hub:Connect(RunService.Heartbeat, function()
        if not autoPlayEnabled then return end

        for note, data in pairs(activeNotes) do
            if not note.Parent or data.Released then continue end

            local noteY = note.AbsolutePosition.Y + (note.AbsoluteSize.Y / 2)
            local buttonY = data.Button.AbsolutePosition.Y + (data.Button.AbsoluteSize.Y / 2)

            if data.LastY then
                if noteY > data.LastY + 0.5 then
                    data.Direction = 1
                elseif noteY < data.LastY - 0.5 then
                    data.Direction = -1
                end
            end
            data.LastY = noteY

            if not data.Pressed then
                local targetY = buttonY - EARLY_HIT_PIXELS

                if noteY >= targetY and noteY <= (buttonY + 40) then
                    data.Pressed = true
                    
                    if note:FindFirstChild("Hold") then
                        data.IsHold = true
                    end
                    
                    pressKey(data.Key, true)

                    if not data.IsHold then
                        task.delay(TAP_DURATION, function()
                            if autoPlayEnabled and activeNotes[note] and not data.Released then
                                pressKey(data.Key, false)
                                data.Released = true
                            end
                        end)
                    end
                end
            elseif data.IsHold then
                local holdElement = note:FindFirstChild("Hold")
                if holdElement then
                    local holdTop = holdElement.AbsolutePosition.Y
                    local holdBottom = holdTop + holdElement.AbsoluteSize.Y
                    
                    if data.Direction == 1 then
                        if holdTop >= buttonY then
                            pressKey(data.Key, false)
                            data.Released = true
                        end
                    elseif data.Direction == -1 then
                        if holdBottom <= buttonY then
                            pressKey(data.Key, false)
                            data.Released = true
                        end
                    end
                else
                    pressKey(data.Key, false)
                    data.Released = true
                end
            end
        end
    end)
end

local function cleanupMinigame()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    releaseAllKeys()
    table.clear(activeNotes)
end

Hub:Add(function() autoPlayEnabled = false cleanupMinigame() end)
task.spawn(function()
    while not Hub.Stopped do
        local bottomPath = getMinigameBottom()

        if bottomPath and not isMinigameRunning then
            isMinigameRunning = true
            setupMinigame(bottomPath)
        elseif not bottomPath and isMinigameRunning then
            isMinigameRunning = false
            cleanupMinigame()
        end
        task.wait(0.5)
    end
end)

end)
