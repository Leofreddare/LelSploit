local Hub = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/u.luau"))()("Project Delta")
local LelUI = Hub.Native
local Instance = LelUI.Instance
local task = Hub:OwnedTasks()
local spawn = task.spawn
local section = Hub.Tabs.Game:CreateSection("Combat")
local preferences = {}
preferences.Radius = 600
preferences.Prediction = true
preferences.WallCheck = true
Hub:Slider(section, "AimFOV", "FOV", 600, 30, 1000, function(value) preferences.Radius = value end)
Hub:Toggle(section, "AimPrediction", "Prediction", function(value) preferences.Prediction = value end, true)
Hub:Toggle(section, "AimWallCheck", "Wall Check", function(value) preferences.WallCheck = value end, true)
Hub:SourceController(section, "Silent Aim", function(current, task, hookfunction, hookmetamethod)
local function quiet(...) end
local spawn = task.spawn
local v1 = game:GetService("RunService");
local v2 = game:GetService("UserInputService");
local v3 = game:GetService("ReplicatedStorage");
local v4 = game:GetService("Players");

local v5 = v4.LocalPlayer;
local v6 = workspace.CurrentCamera;
local v7 = workspace.AiZones;
local v8, v9 = pcall(require, v3.Modules.FPS.Bullet);

if not hookfunction then 
	Hub:Notify("Your executor does not support hookfunction.") return;
end;

if not v8 then 
	Hub:Notify("The bullet module is not loaded.") return;
end;

local z1 = {
	Enabled = true,
	WallCheck = true,
	HitPart = "Head",
	Prediction = true,
	Fov = {
		Visible = false,
		Radius = 600
	}
};

local function z2(p1)
	return p1 and p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
		and p1.Character:FindFirstChild("Humanoid") and p1.Character.Humanoid.Health > 0;
end;

local function z3(p2, p3, ...)
	local z4 = { v6, ... };
	if z2(v5) then 
		table.insert(z4, v5.Character);
	end;
	local z5 = workspace:FindPartOnRayWithIgnoreList(Ray.new(p2, p3.Position - p2), z4, false, true);
	return z5 and z5:IsDescendantOf(p3.Parent);
end;

local function z6()
	local z7 = {};
	for _, z8 in v7:GetChildren() do
		for _, z9 in z8:GetChildren() do
			table.insert(z7, z9);
		end;
	end;
	return z7;
end;

local function z10(...)
	local z11, z12 = nil, preferences.Radius;

	for _, z13 in z6() do 
		if not z13:FindFirstChild("HumanoidRootPart") then continue end;
		local z14 = z13:FindFirstChild(z1.HitPart);
		if not z14 then continue end;
		if preferences.WallCheck and not z3(v6.CFrame.Position, z14, ...) then continue end;
		local z15, z16 = v6:WorldToViewportPoint(z14.Position);
		if not z16 then continue end;
		local z17 = (Vector2.new(z15.X, z15.Y) - v6.ViewportSize / 2).Magnitude;
		if z17 < z12 then
			z12 = z17;
			z11 = z14;
		end;
	end;

	for i, z18 in v4:GetPlayers() do
		if z18 == v5 then continue end;
		if not z2(z18) then continue end;
		local z19 = z18.Character:FindFirstChild(z1.HitPart);
		if not z19 then continue end;
		if preferences.WallCheck and not z3(v6.CFrame.Position, z19, ...) then continue end;
		local z20, z21 = v6:WorldToViewportPoint(z19.Position);
		if not z21 then continue end;
		local z22 = (Vector2.new(z20.X, z20.Y) - v6.ViewportSize / 2).Magnitude;
		if z22 < z12 then
			z12 = z22;
			z11 = z19;
		end;
	end;

	return z11;
end;

local function z23(a, b, c)
	local d = b^2 - 4 * a * c;
	if d < 0 then return nil, nil end;
	local sqrtD = math.sqrt(d);
	local r1 = (-b - sqrtD) / (2 * a);
	local r2 = (-b + sqrtD) / (2 * a);
	return r1, r2;
end;

local function z24(dir, grav, speed)
	local r1, r2 = z23(
		grav:Dot(grav) / 4,
		grav:Dot(dir) - speed^2,
		dir:Dot(dir)
	);
	if r1 and r2 then
		if r1 > 0 and r1 < r2 then return math.sqrt(r1) end;
		if r2 > 0 and r2 < r1 then return math.sqrt(r2) end;
	end;
	return 0;
end;

local function z25(o, t, spd, acc)
	local g = Vector3.yAxis * (acc * 2);
	local time = z24(t - o, g, spd);
	return 0.5 * g * time^2;
end;

local function z26(t, o, spd, acc)
	local g = Vector3.yAxis * (acc * 2);
	local time = z24(t.Position - o, g, spd);
	return t.Position + (t.Velocity * time);
end;

local drag = {}
current:Add(function() for object, value in pairs(drag) do if object.Parent then object:SetAttribute("Drag", value[1]) end end end)
local z27;
z27 = hookfunction(v9.CreateBullet, function(a, b, c, d, aim, e, ammo, tickVal, recoil)
	if not z1.Enabled then
		return z27(a, b, c, d, aim, e, ammo, tickVal, recoil);
	end;

	local t = z10(b, c, d, aim);
	if t then
		local dat = v3.AmmoTypes:FindFirstChild(ammo);
		local acc = dat:GetAttribute("ProjectileDrop");
		local spd = dat:GetAttribute("MuzzleVelocity");

		if not drag[dat] then drag[dat] = { dat:GetAttribute("Drag") } end
		dat:SetAttribute("Drag", 0); 

		local pred = (preferences.Prediction and z26(t, aim.Position, spd, acc)) or t.Position;
		local drop = z25(aim.Position, pred, spd, acc);
		local newAim = {
			["CFrame"] = CFrame.new(aim.Position, pred + drop)
		};

		return z27(a, b, c, d, newAim, e, ammo, tickVal, recoil);
	end;

	return z27(a, b, c, d, aim, e, ammo, tickVal, recoil);
end);

quiet("[SilentAim] Enabled. Obfuscated Version.")

end, false)
