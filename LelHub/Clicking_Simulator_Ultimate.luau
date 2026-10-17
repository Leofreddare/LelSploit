local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Clicking Simulator Ultimate", Style = "Native", Parameters = {{ Key = "AutoTap", Title = "Auto Tap", Default = true },}, Action = "Start auto tap" }, [====[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

_G.AutoTap = LelHubValue("AutoTap", true) 

if setclipboard then
    setclipboard("https://discord.gg/3R7AtzjFEQ")
elseif toclipboard then
    toclipboard("https://discord.gg/3R7AtzjFEQ")
end

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

StarterGui:SetCore("SendNotification", {
    Title = "Casual Hub",
    Text = "Have fun skids",
    Duration = 10
})
]====])
