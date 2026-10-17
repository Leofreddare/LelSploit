local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Build a Brainrot", Style = "Native", Parameters = {}, Action = "Buy tools and claim rewards" }, [====[
repeat task.wait() until game:IsLoaded()
local get_all_tools = true 
local get_cash = true 
local multi_equip_tools = {"All"}
if get_all_tools then for _,tool in ipairs(game:GetService("ReplicatedStorage"):WaitForChild("Tools"):GetChildren()) do game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("buyTool"):FireServer(tool.Name) end end
if get_cash then game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("giveRewards"):FireServer("Cash",9200000000000000000) end
if buy_builds then while task.wait() do for _,builds in ipairs(buy_builds) do game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("buyPlaceable"):FireServer(builds) end end for _,build in next,game:GetService("ReplicatedStorage").Builds:GetChildren() do print(build.Name) end end
if multi_equip_tools then for _,tool in ipairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do if table.find(multi_equip_tools,"All") or table.find(multi_equip_tools,tool.Name) then tool.Parent = game:GetService("Players").LocalPlayer.Character end end end
]====])
