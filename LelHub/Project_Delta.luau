local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Project Delta", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local v1 = game:GetService("RunService");
local v2 = game:GetService("UserInputService");
local v3 = game:GetService("ReplicatedStorage");
local v4 = game:GetService("Players");

local v5 = v4.LocalPlayer;
local v6 = workspace.CurrentCamera;
local v7 = workspace.AiZones;
local v8, v9 = pcall(require, v3.Modules.FPS.Bullet);

if not hookfunction then 
	return v5:Kick("Executor Doesn't Have hookfunction.");
end;

if not v8 then 
	return v5:Kick("Couldn't Require Bullet Module. Make Sure The Game Is Loaded");
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
	local z11, z12 = nil, z1.Fov.Radius;

	for _, z13 in z6() do 
		if not z13:FindFirstChild("HumanoidRootPart") then continue end;
		local z14 = z13:FindFirstChild(z1.HitPart);
		if not z14 then continue end;
		if z1.WallCheck and not z3(v6.CFrame.Position, z14, ...) then continue end;
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
		if z1.WallCheck and not z3(v6.CFrame.Position, z19, ...) then continue end;
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

		dat:SetAttribute("Drag", 0); 

		local pred = (z1.Prediction and z26(t, aim.Position, spd, acc)) or t.Position;
		local drop = z25(aim.Position, pred, spd, acc);
		local newAim = {
			["CFrame"] = CFrame.new(aim.Position, pred + drop)
		};

		return z27(a, b, c, d, newAim, e, ammo, tickVal, recoil);
	end;

	return z27(a, b, c, d, aim, e, ammo, tickVal, recoil);
end);

warn("[SilentAim] Enabled. Obfuscated Version.")
]====])
