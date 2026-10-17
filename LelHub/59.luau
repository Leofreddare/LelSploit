local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Clicking Simulator Ultimate")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

_G.AutoTap = true 

local function waitRemote(name)
    local function scan(parent)
        for _, v in ipairs(parent:GetChildren()) do
            if v.Name == name and v:IsA("RemoteEvent") then return v end
            local found = scan(v)
            if found then return found end
        end
    end
    while true do
        local found = scan(ReplicatedStorage)
        if found then return found end
        task.wait(0.5)
    end
end

task.spawn(function()
    local TapsRemote = waitRemote("Taps")
    while true do
        if _G.AutoTap then
            pcall(function() TapsRemote:FireServer() end)
        end
        task.wait()
    end
end)

end)
