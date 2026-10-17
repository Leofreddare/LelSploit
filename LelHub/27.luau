local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Emergency Hamburg")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

local DetectionTable = nil
local AnticheatFolder = RS:FindFirstChild("GpP")
local blocked = 0
local EventsDetection = nil
local blockedRemotes = {}

local Anticheat_IDS = {
    "9e50ff5b-cf0f-4298-8408-c3df60fc8b16",
    "4827d0ba-b8d7-4835-8638-a638c3a05add",
    "f533d2e3-6945-4c50-98cf-d24de0cdd2eb",
    "eed59c99-087b-41a6-a6e1-4eafa101c8cf"
}

for _, v in getgc(true) do
    if type(v) == "table" then
        for _, id in pairs(Anticheat_IDS) do
            if rawget(v, id) then
                EventsDetection = v; break
            end
        end
    end
end

if EventsDetection then
    for _, v in Anticheat_IDS do
        if rawget(EventsDetection, v) then
            rawset(EventsDetection, v, newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end))
        end
    end
end

if AnticheatFolder then
    for _, id in Anticheat_IDS do
        local remote = AnticheatFolder:FindFirstChild(id)

        if remote then
            blockedRemotes[remote] = true
        end
    end
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and blockedRemotes[self] then
        blocked += 1

        return
    end

    return oldNamecall(self, ...)
end))


for _, v in getgc(true) do
    if type(v) == "table" and rawget(v, "checkWalkSpeed") and rawget(v, "checkJumpHeight") then
        DetectionTable = v

        break
    end
end

if DetectionTable then
    DetectionTable.checkWalkSpeed = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.checkJumpHeight = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.checkUseJumpPower = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
    DetectionTable.handleGuiName = newcclosure(function() return "EZ -- $Murmansk / Gong Yoo" end)
end

local function disableHumConnections(Humanoid)
    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("WalkSpeed")) do
        con:Disable()
    end

    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("JumpHeight")) do
        con:Disable()
    end

    for _, con in getconnections(Humanoid:GetPropertyChangedSignal("UseJumpPower")) do
        con:Disable()
    end
end

if Humanoid then
    disableHumConnections(Humanoid)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    disableHumConnections(char:WaitForChild("Humanoid"))
end)

warn("Bypassed Client AC! ~ Credit: $Murmansk // GongYoo - https://guns.lol/mcletshacks")

end)
