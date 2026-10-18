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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Jujutsu Shenanigans")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.Delay = 1
Hub:Slider(section, "CounterDelay", "Timing Multiplier", 1, 0.5, 2, function(value) preferences.Delay = value end, 2)
Hub:SourceController(section, "Auto Counter", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local ServiceProvider = setmetatable({}, {
    __index = function(self, serviceName)
        local service = game:GetService(serviceName)
        rawset(self, serviceName, service)
        return service
    end
})

local ClientUser = ServiceProvider.Players.LocalPlayer
local UserInputService = ServiceProvider.UserInputService

local Configuration = {
    AnimationDatabase = {
        [100962226150441] = {delay = 0.18, action = "Three"},
        [95852624447551] = {delay = 0.18, action = "Three"},
        [74145636023952] = {delay = 0.18, action = "Three"},
        [72475960800126] = {delay = 0.20, action = "Three"},
        [100081544058065] = {delay = 0.3, action = "Two"},
        [123167492985370] = {delay = 0.6, action = "Two"},
    }
}

local InputSimulator = {}
InputSimulator.__index = InputSimulator

function InputSimulator.new()
    local self = setmetatable({}, InputSimulator)
    self.Manager = ServiceProvider.VirtualInputManager
    self.isProcessing = false
    return self
end

function InputSimulator:Execute(actionKey)
    if self.isProcessing then return end
    
    if UserInputService.TouchEnabled then
        self.isProcessing = true
        
        local keyEnum = Enum.KeyCode[actionKey]
        if not keyEnum then 
            self.isProcessing = false
            return 
        end
        
        task.wait(0.05)
        
        if not UserInputService:GetTouchPosition() then
            self.Manager:SendKeyEvent(true, keyEnum, false, game)
            task.wait(0.05)
            self.Manager:SendKeyEvent(false, keyEnum, false, game)
        end
        
        task.wait(0.1)
        self.isProcessing = false
    else
        local keyEnum = Enum.KeyCode[actionKey]
        if not keyEnum then return end
        
        self.Manager:SendKeyEvent(true, keyEnum, false, game)
        self.Manager:SendKeyEvent(false, keyEnum, false, game)
    end
end

local AnimationHandler = {}
AnimationHandler.__index = AnimationHandler

function AnimationHandler.new(inputSimulator)
    local self = setmetatable({}, AnimationHandler)
    self.InputController = inputSimulator
    self.ActiveConnections = {}
    return self
end

function AnimationHandler:ExtractAnimationID(fullId)
    return tonumber(fullId:match("%d+$"))
end

function AnimationHandler:ProcessAnimation(animationTrack, humanoidRef)
    local rawID = self:ExtractAnimationID(animationTrack.Animation.AnimationId)
    local config = Configuration.AnimationDatabase[rawID]
    
    if not config then return end
    
    task.delay(config.delay * preferences.Delay, function()
        if humanoidRef.Health > 0 then
            self.InputController:Execute(config.action)
        end
    end)
end

function AnimationHandler:AttachToCharacter(characterModel)
    local humanoid = characterModel:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    local animator = humanoid:WaitForChild("Animator", 5)
    if not animator then return end
    
    local connection = current:Connect(animator.AnimationPlayed, function(track)
        self:ProcessAnimation(track, humanoid)
    end)
    
    table.insert(self.ActiveConnections, connection)
end

function AnimationHandler:Cleanup()
    for _, conn in ipairs(self.ActiveConnections) do
        conn:Disconnect()
    end
    self.ActiveConnections = {}
end

local function InitializeSystem()
    local simulator = InputSimulator.new()
    local handler = AnimationHandler.new(simulator)
    
    if ClientUser.Character then
        handler:AttachToCharacter(ClientUser.Character)
    end
    
    current:Connect(ClientUser.CharacterAdded, function(char)
        handler:Cleanup()
        task.wait(0.2)
        handler:AttachToCharacter(char)
    end)
end

InitializeSystem()

end, false)
