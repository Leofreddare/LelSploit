local environment = type(getgenv) == "function" and getgenv() or _G
local runtime = environment.LelHubGameRuntime
if not runtime then
    local source = game:HttpGetAsync("https://raw.githubusercontent.com/Leofreddare/LelSploit/main/LelHub/LelHubRuntime.luau")
    local chunk, message = loadstring(source, "LelHub/Runtime")
    assert(chunk, message)
    runtime = chunk()
    environment.LelHubGameRuntime = runtime
end

return runtime.Open({ Name = "Crop Incremental", Style = "Native", Parameters = {}, Action = "Enable game features" }, [====[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local TokenNames, TokenOrder = {}, {}

local function addTokenName(name)
	if name and not TokenNames[name] then
		TokenNames[name] = true
		table.insert(TokenOrder, name)
	end
end


do
	local stuff = ReplicatedStorage:FindFirstChild("Stuff")
	local tokens = stuff and stuff:FindFirstChild("Tokens")
	if tokens then
		for _, c in ipairs(tokens:GetChildren()) do addTokenName(c.Name) end
	end
end

do
	local live = workspace:FindFirstChild("Tokens")
	if live then
		for _, c in ipairs(live:GetChildren()) do addTokenName(c.Name) end
	end
end

local old = PlayerGui:FindFirstChild("Chimera_MinTabs")
if old then old:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "Chimera_MinTabs"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
Gui.DisplayOrder = 9999
Gui.Parent = PlayerGui

local Root = Instance.new("Frame")
Root.Size = UDim2.new(0, 300, 0, 380)
Root.Position = UDim2.new(0, 20, 0.55, -130)
Root.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Root.BackgroundTransparency = 0.4
Root.Active, Root.Draggable = true, true
Root.Parent = Gui

local Title = Instance.new("TextLabel", Root)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 8, 0, 6)
Title.Size = UDim2.new(1, -16, 0, 18)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 15
Title.TextColor3 = Color3.fromRGB(255, 220, 120)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "Token Tracker — Chimera__Gaming"

local Tabs = Instance.new("Frame", Root)
Tabs.BackgroundTransparency = 1
Tabs.Position = UDim2.new(0, 8, 0, 28)
Tabs.Size = UDim2.new(1, -16, 0, 26)

local function makeTabBtn(text, x)
	local b = Instance.new("TextButton", Tabs)
	b.Size = UDim2.new(0, 120, 1, 0)
	b.Position = UDim2.new(0, x, 0, 0)
	b.BackgroundColor3 = Color3.fromRGB(45,45,45)
	b.BackgroundTransparency = 0.3
	b.TextColor3 = Color3.fromRGB(235,235,235)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 16
	b.Text = text
	return b
end

local MainBtn  = makeTabBtn("Main", 0)
local TrackBtn = makeTabBtn("Token Tracker", 124)
local TeleBtn  = makeTabBtn("Teleports", 248)

local NOTE_HEIGHT, NOTE_PAD = 84, 8

local Body = Instance.new("Frame", Root)
Body.Name = "Body"
Body.BackgroundTransparency = 1
Body.Position = UDim2.new(0, 8, 0, 58)
Body.Size = UDim2.new(1, -16, 1, -(58 + NOTE_HEIGHT + NOTE_PAD))

local MainTab = Instance.new("Frame", Body)
MainTab.BackgroundTransparency = 1
MainTab.Size = UDim2.new(1, 0, 1, 0)

local function makeBtn(y, text)
	local b = Instance.new("TextButton", MainTab)
	b.Size = UDim2.new(1, 0, 0, 28)
	b.Position = UDim2.new(0, 0, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(42,42,42)
	b.BackgroundTransparency = 0.3
	b.TextColor3 = Color3.fromRGB(235,235,235)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 16
	b.Text = text
	return b
end

local function hum()
	local c = Player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function HRP()
	local c = Player.Character
	return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local defaultWalk, defaultJump
local wsOn, jpOn = false, false

local function captureDefaults()
	local h = hum()
	if h then
		defaultWalk = h.WalkSpeed
		defaultJump = h.JumpPower
	end
end
captureDefaults()

Player.CharacterAdded:Connect(function()
	repeat task.wait() until hum()
	captureDefaults()
	if wsOn then hum().WalkSpeed = 50 end
	if jpOn then hum().JumpPower = 100 end
end)


local WalkBtn = makeBtn(0, "WalkSpeed 50: OFF")
WalkBtn.MouseButton1Click:Connect(function()
	wsOn = not wsOn
	local h = hum(); if not h then return end
	if wsOn then
		if not defaultWalk then defaultWalk = h.WalkSpeed end
		h.WalkSpeed = 50
		WalkBtn.Text = "WalkSpeed 50: ON"
		WalkBtn.BackgroundColor3 = Color3.fromRGB(60,95,60)
	else
		h.WalkSpeed = defaultWalk or 16
		WalkBtn.Text = "WalkSpeed 50: OFF"
		WalkBtn.BackgroundColor3 = Color3.fromRGB(42,42,42)
	end
end)


local JumpBtn = makeBtn(32, "Jump Power 100: OFF")
JumpBtn.MouseButton1Click:Connect(function()
	jpOn = not jpOn
	local h = hum(); if not h then return end
	if jpOn then
		if not defaultJump then defaultJump = h.JumpPower end
		h.JumpPower = 100
		JumpBtn.Text = "Jump Power 100: ON"
		JumpBtn.BackgroundColor3 = Color3.fromRGB(60,95,60)
	else
		h.JumpPower = defaultJump or 50
		JumpBtn.Text = "Jump Power 100: OFF"
		JumpBtn.BackgroundColor3 = Color3.fromRGB(42,42,42)
	end
end)


local INTERVAL_SINGLE = 0.015
local DWELL_SINGLE = 0.010
local SEARCH_RADIUS = 1200
local TOUCH_OFFSET = Vector3.new(0, 2.0, 0)

local function nearestToken(touchPart)
	local root = workspace:FindFirstChild("Tokens")
	if not (root and touchPart) then return nil end
	local best, bestDist
	for _, c in ipairs(root:GetChildren()) do
		for _, d in ipairs(c:IsA("BasePart") and {c} or c:GetDescendants()) do
			if d:IsA("BasePart") then
				local dist = (d.Position - touchPart.Position).Magnitude
				if dist <= SEARCH_RADIUS and (not bestDist or dist < bestDist) then
					best, bestDist = d, dist
				end
			end
		end
	end
	return best
end

local TPCollectBtn = makeBtn(64, "TP Collect (Tokens): OFF")
local tpEnabled, tpLoopRunning = false, false

TPCollectBtn.MouseButton1Click:Connect(function()
	tpEnabled = not tpEnabled
	TPCollectBtn.Text = tpEnabled and "TP Collect (Tokens): ON" or "TP Collect (Tokens): OFF"
	TPCollectBtn.BackgroundColor3 = tpEnabled and Color3.fromRGB(60,95,60) or Color3.fromRGB(42,42,42)
	if tpEnabled and not tpLoopRunning then
		tpLoopRunning = true
		task.spawn(function()
			while tpEnabled do
				local hrp = HRP()
				local token = hrp and nearestToken(hrp)
				if hrp and token then
					local old = hrp.CFrame
					pcall(function() hrp.CFrame = CFrame.new(token.Position + TOUCH_OFFSET) end)
					task.wait(DWELL_SINGLE)
					pcall(function() hrp.CFrame = old end)
				end
				task.wait(INTERVAL_SINGLE)
			end
			tpLoopRunning = false
		end)
	end
end)


local Note = Instance.new("TextLabel", MainTab)
Note.BackgroundTransparency = 1
Note.Size = UDim2.new(1, 0, 0, NOTE_HEIGHT)
Note.Position = UDim2.new(0, 0, 1, -(NOTE_HEIGHT + 6))
Note.Font = Enum.Font.SourceSans
Note.TextSize = 13
Note.TextXAlignment = Enum.TextXAlignment.Left
Note.TextYAlignment = Enum.TextYAlignment.Top
Note.TextColor3 = Color3.fromRGB(255, 200, 64)
Note.TextWrapped = true
Note.Text = "Last Updated: 10/22\nBuild v3.0\nOpenSourcing Code.\n⚠️ Use at your own risk."

local TrackerTab = Instance.new("Frame", Body)
TrackerTab.BackgroundTransparency = 1
TrackerTab.Size = UDim2.new(1, 0, 1, 0)
TrackerTab.Visible = false

local listHolder = Instance.new("Frame", TrackerTab)
listHolder.BackgroundTransparency = 1
listHolder.Size = UDim2.new(1, 0, 1, 0)

local layout = Instance.new("UIListLayout", listHolder)
layout.Padding = UDim.new(0, 2)

local rows = {}
local function addRow(name)
	local lbl = Instance.new("TextLabel", listHolder)
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.Font = Enum.Font.SourceSans
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(235,235,235)
	lbl.Text = name .. ": 0"
	rows[name] = lbl
end
for _, n in ipairs(TokenOrder) do addRow(n) end

local function countActive(name)
	local root = workspace:FindFirstChild("Tokens")
	if not root then return 0 end
	local total = 0
	for _, ch in ipairs(root:GetChildren()) do
		if ch.Name == name then
			for _, d in ipairs(ch:IsA("BasePart") and {ch} or ch:GetDescendants()) do
				if d:IsA("BasePart") then total += 1 end
			end
		end
	end
	return total
end

local function discoverNewTokens()
	local root = workspace:FindFirstChild("Tokens")
	if not root then return end
	for _, ch in ipairs(root:GetChildren()) do
		if ch.Name and not rows[ch.Name] then
			addTokenName(ch.Name)
			addRow(ch.Name)
		end
	end
end

task.spawn(function()
	while true do
		discoverNewTokens()
		for name, lbl in pairs(rows) do
			lbl.Text = ("%s: %d"):format(name, countActive(name))
		end
		task.wait(1)
	end
end)

local TeleTab = Instance.new("Frame", Body)
TeleTab.BackgroundTransparency = 1
TeleTab.Size = UDim2.new(1, 0, 1, 0)
TeleTab.Visible = false

local TP_2X      = Vector3.new(-330.00, 56.00,  -94.00)
local TP_SPAWN   = Vector3.new(-0.10,  5.11,  -0.10)
local TP_KEY1    = Vector3.new(107.80, 5.11, -148.47)
local TP_KEY2    = Vector3.new(-358.06, 2.21, -199.77)
local TP_SKULL     = Vector3.new(-524.63, 40.71,  -21.61)
local TP_SUNFLOWER = Vector3.new(-375.00,  4.91, -119.40)
local TP_SUGARCUBE = Vector3.new(-368.69, 37.06, -311.47)
local TP_DUMBELL   = Vector3.new(-308.03, 72.91, -156.15)
local TP_STAR      = Vector3.new( -31.03, 66.61, -411.08)
local TP_ENZYMES   = Vector3.new( 28.52, 60.96, -553.92)
local TP_CRAFT     = Vector3.new( -90.45, 21.31, -222.40)
local TP_EVENT     = Vector3.new(-462.24, 40.41,    5.36)

local function tpTo(v3)
	local c = Player.Character or Player.CharacterAdded:Wait()
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = CFrame.new(v3) end
end

local ROW_H, GAP, yCursor = 28, 6, 0
local function section(title)
	local h = Instance.new("TextLabel", TeleTab)
	h.BackgroundTransparency = 1
	h.Position = UDim2.new(0, 0, 0, yCursor)
	h.Size = UDim2.new(1, 0, 0, 18)
	h.Font = Enum.Font.SourceSansBold
	h.TextSize = 14
	h.TextColor3 = Color3.fromRGB(255, 220, 120)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = title
	yCursor += 22
end

local function row2(leftText, leftFn, rightText, rightFn)
	local f = Instance.new("Frame", TeleTab)
	f.BackgroundTransparency = 1
	f.Position = UDim2.new(0, 0, 0, yCursor)
	f.Size = UDim2.new(1, 0, 0, ROW_H)
	local function halfBtn(left, text, fn)
		local b = Instance.new("TextButton", f)
		b.Size = UDim2.new(0.5, -3, 1, 0)
		b.Position = left and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 3, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(42,42,42)
		b.BackgroundTransparency = 0.3
		b.TextColor3 = Color3.fromRGB(235,235,235)
		b.Font = Enum.Font.SourceSansBold
		b.TextSize = 16
		b.Text = text
		b.MouseButton1Click:Connect(fn)
	end
	if leftText  then halfBtn(true,  leftText,  leftFn)  end
	if rightText then halfBtn(false, rightText, rightFn) end
	yCursor += ROW_H + GAP
end

section("Quick")
row2("2x Coins", function() tpTo(TP_2X) end, "Spawn", function() tpTo(TP_SPAWN) end)

section("Amulets")
row2("Skull", function() tpTo(TP_SKULL) end, "Sunflower", function() tpTo(TP_SUNFLOWER) end)
row2("SugarCube", function() tpTo(TP_SUGARCUBE) end, "Dumbell", function() tpTo(TP_DUMBELL) end)
row2("Star", function() tpTo(TP_STAR) end, "Enzymes", function() tpTo(TP_ENZYMES) end)

section("Shops")
row2("Crafting Shop", function() tpTo(TP_CRAFT) end, "Event Area", function() tpTo(TP_EVENT) end)

section("Keys")
row2("Key 1 Shop", function() tpTo(TP_KEY1) end, "Key 2 Shop", function() tpTo(TP_KEY2) end)

local function setTab(which)
	MainTab.Visible = (which == "Main")
	TrackerTab.Visible = (which == "Tracker")
	TeleTab.Visible = (which == "Teleports")
	MainBtn.BackgroundColor3 = MainTab.Visible and Color3.fromRGB(60,60,60) or Color3.fromRGB(35,35,35)
	TrackBtn.BackgroundColor3 = TrackerTab.Visible and Color3.fromRGB(60,60,60) or Color3.fromRGB(35,35,35)
	TeleBtn.BackgroundColor3 = TeleTab.Visible and Color3.fromRGB(60,60,60) or Color3.fromRGB(35,35,35)
end

MainBtn.MouseButton1Click:Connect(function() setTab("Main") end)
TrackBtn.MouseButton1Click:Connect(function() setTab("Tracker") end)
TeleBtn.MouseButton1Click:Connect(function() setTab("Teleports") end)
setTab("Main")
]====])
