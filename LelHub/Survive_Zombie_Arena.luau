local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Survive Zombie Arena", Style = "Native", Parameters = {}, Action = "Apply weapon settings" }, [====[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfig = require(ReplicatedStorage.Data.GunConfig)
local UpgradeShopData = require(ReplicatedStorage.Data.UpgradeShopData)

local FAST_RATE = 0.01


GunConfig.Defaults.FireRate = FAST_RATE

for gunName, gun in pairs(GunConfig.Guns) do
    gun.FireRate = FAST_RATE
    gun.SoundCooldown = FAST_RATE
    gun.Automatic = true
    gun.AutoFire = true
    gun.HoldToFire = true
    gun.FullAuto = true
end

for gunName, weapon in pairs(UpgradeShopData.Weapons) do
    if weapon.Tiers then
        for _, tier in pairs(weapon.Tiers) do
            tier.FireRate = FAST_RATE
        end
    end
end

print("FireRate patched in GunConfig + UpgradeShopData + Join Discord For More OP Scripts")
]====])
