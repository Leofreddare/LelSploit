if not game:IsLoaded() then game.Loaded:Wait() end
local base = "https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/"
local function read(file) return assert(loadstring(game:HttpGetAsync(base .. file))) end
local routes = read("g.luau")()
local environment = getgenv()
environment.LelHubCatalog = routes.C
local selected = routes.U[game.GameId] or routes.P[game.PlaceId]
if not selected then
    local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset) end)
    if ok and info and info.Name then selected = routes.N[info.Name:lower():gsub("%b[]", ""):gsub("%b()", ""):gsub("[^%w]", "")] end
end
local allowed = {}
for _, entry in ipairs(routes.C) do allowed[entry.File] = true end
local session = {Loading = false}
environment.LelHubLoader = session
function session.LoadModule(file, cleanup)
    if session.Loading or not allowed[file] then return false end
    session.Loading = true
    task.spawn(function()
        local ok = pcall(function()
            local chunk = read(file)
            if cleanup then cleanup() end
            chunk()
        end)
        session.Loading = false
        if not ok and file ~= "0.luau" then read("0.luau")() end
    end)
    return true
end
if not selected then pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title="LelHub",Text="LelHub doesn't support this game yet. Opening Global.",Duration=5}) end) end
session.LoadModule((selected or "0") .. ".luau")
