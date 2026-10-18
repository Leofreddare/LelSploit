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

local Hub = lelHubCompileRemote("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau")()("Femboy Simulator")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
task.spawn(function()
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local player = Players.LocalPlayer


local tele = game:GetService('ReplicatedStorage'):WaitForChild('Teleporter')
tele:Clone().Parent = player.Backpack


local Events = ReplicatedStorage:WaitForChild('Events')
local RebirthEvent = Events:WaitForChild('Rebirth')
assert(RebirthEvent:IsA('RemoteEvent'), 'Events.Rebirth must be a RemoteEvent')

local RollEnchant = Events:WaitForChild('RollEnchant') 

local HireWorker = Events:WaitForChild('HireWorker') 

local GetQuest = Events:WaitForChild('GetQuest') 
local ClaimQuest = Events:WaitForChild('ClaimQuest') 


local pg = player:WaitForChild('PlayerGui')
local screen = pg:WaitForChild('Screen')

local workersGui = screen:WaitForChild('Workers')
local workersContainer = workersGui:WaitForChild('Container')
local workersSubtitle = workersContainer:WaitForChild('Subtitle') 

local enchants = screen:WaitForChild('Enchants')
local container = enchants:WaitForChild('Container')
local enchantLabel = container:WaitForChild('Enchant') 

local function makeToggle(labelText, onToggle)
    return LelUI:Control(nil, "Toggle", labelText, false, onToggle)
end

local rebirthToken = 0 
local enchantToken = 0 
local workerToken = 0
local questToken = 0

local function setAutoRebirth(on)
    rebirthToken += 1
    local myToken = rebirthToken
    if on then
        task.spawn(function()
            while myToken == rebirthToken do
                
                pcall(function()
                    RebirthEvent:FireServer()
                end)
                task.wait(1)
            end
        end)
    end
end


local function isEnchantGoal(text)
    text = tostring(text or ''):gsub('%s+', ''):upper()
    return text == 'X'
end

local function setAutoEnchant(on)
    enchantToken += 1
    local myToken = enchantToken
    if on then
        task.spawn(function()
            while myToken == enchantToken do
                if not isEnchantGoal(enchantLabel.Text) then
                    
                    pcall(function()
                        if RollEnchant:IsA('RemoteEvent') then
                            RollEnchant:FireServer()
                        elseif RollEnchant:IsA('RemoteFunction') then
                            RollEnchant:InvokeServer()
                        else
                            warn(
                                'RollEnchant must be RemoteEvent or RemoteFunction'
                            )
                        end
                    end)
                    task.wait(0.1)
                else
                    
                    task.wait(0.2)
                end
            end
        end)
    end
end


local function isWorkerGoal(text)
    text = tostring(text or '') 
    text = text
        :gsub('^%s+', '') 
        :gsub('%s+$', '') 
        :gsub('%s+', ' ') 
        :upper() 
    return text == 'BUY A WORKER (X30)'
end

local function setAutoWorker(on)
    workerToken += 1
    local myToken = workerToken
    if on then
        task.spawn(function()
            while myToken == workerToken do
                if not isWorkerGoal(workersSubtitle.Text) then
                    
                    pcall(function()
                        if HireWorker:IsA('RemoteEvent') then
                            HireWorker:FireServer()
                        elseif HireWorker:IsA('RemoteFunction') then
                            HireWorker:InvokeServer()
                        else
                            warn(
                                'HireWorker must be RemoteEvent or RemoteFunction'
                            )
                        end
                    end)
                    task.wait(0.1)
                else
                    
                    task.wait(0.2)
                end
            end
        end)
    end
end

local function setAutoQuest(on)
    questToken += 1
    local myToken = questToken
    if on then
        task.spawn(function()
            while myToken == questToken do
                pcall(function()
                    if GetQuest:IsA('RemoteEvent') then
                        GetQuest:FireServer()
                    elseif GetQuest:IsA('RemoteFunction') then
                        GetQuest:InvokeServer()
                    else
                        warn('GetQuest must be RemoteEvent or RemoteFunction')
                    end

                    if ClaimQuest:IsA('RemoteEvent') then
                        ClaimQuest:FireServer()
                    elseif ClaimQuest:IsA('RemoteFunction') then
                        ClaimQuest:InvokeServer()
                    else
                        warn('ClaimQuest must be RemoteEvent or RemoteFunction')
                    end
                end)
                task.wait(0.5)
            end
        end)
    end
end

makeToggle('Auto Rebirth', function(on)
    setAutoRebirth(on)
end)


makeToggle('Auto Enchant', function(on)
    setAutoEnchant(on)
end)

makeToggle('Auto Workers', function(on)
    setAutoWorker(on)
end)

makeToggle('Questing Blud', function(on)
    setAutoQuest(on)
end)

Hub:Add(function() setAutoRebirth(false) setAutoEnchant(false) setAutoWorker(false) setAutoQuest(false) end)

end)
