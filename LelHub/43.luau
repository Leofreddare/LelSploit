local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Jujutsu Shenanigans")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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
    
    task.delay(config.delay, function()
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
    
    local connection = animator.AnimationPlayed:Connect(function(track)
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
    
    ClientUser.CharacterAdded:Connect(function(char)
        handler:Cleanup()
        task.wait(0.2)
        handler:AttachToCharacter(char)
    end)
end

InitializeSystem()

end)
