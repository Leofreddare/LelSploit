local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Survive Zombie Arena")
local LelUI = Hub.Native
local Instance = LelUI.Instance
task.spawn(function()
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

end)
