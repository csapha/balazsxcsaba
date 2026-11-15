-- GDD 7.1 Loading screen (ReplicatedFirst: it shows before anything else loads).
--   "SELL A SCHNITZEL" text logo (gold, thick ink outline) – a mallet slams onto it (squash + shake),
--   a schnitzel-shaped progress bar that "breads" from pale dough to golden brown,
--   "Tap to skip" (never hold the player up), and a slowly drifting schnitzel pattern behind.
-- It closes when the game UI is up (data loaded) – or on a tap. Then it sets the local player's "LoadingDone"
-- attribute, so the tutorial intro (camera flight) starts after it.
-- Plain Instances only: the shared modules / packages are not loaded yet at this point.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SCHNITZEL_ICON = "rbxassetid://98613698863535"
local MALLET_ICON = "rbxassetid://94788295391267" -- the "Strength" icon of the UI set
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromHex("0B0A12")
local DOUGH = Color3.fromHex("F3E2B3")
local GOLDEN = Color3.fromHex("C9781E")
local MIN_SHOW = 2.5 -- seconds (the mallet animation)
local MAX_WAIT = 30

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, mode: Enum.ApplyStrokeMode?)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function label(text: string, size: number, top: Color3, bottom: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(900, size + 10)
	stroke(l, math.max(3, size / 12))
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = l
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.BorderSizePixel = 0
local backGradient = Instance.new("UIGradient")
backGradient.Rotation = 90
backGradient.Color = ColorSequence.new(Color3.fromHex("3A1E0E"), Color3.fromHex("120A06"))
backGradient.Parent = background
background.Parent = gui

-- the drifting schnitzel pattern
local pattern = Instance.new("ImageLabel")
pattern.Size = UDim2.new(1, 240, 1, 240)
pattern.Position = UDim2.fromOffset(-120, -120)
pattern.BackgroundTransparency = 1
pattern.Image = SCHNITZEL_ICON
pattern.ImageTransparency = 0.9
pattern.ScaleType = Enum.ScaleType.Tile
pattern.TileSize = UDim2.fromOffset(120, 120)
pattern.Parent = background

local stage = Instance.new("Frame")
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.5)
stage.Size = UDim2.fromOffset(1000, 600)
stage.BackgroundTransparency = 1
stage.Parent = background
local stageScale = Instance.new("UIScale")
stageScale.Parent = stage

local small = label("SELL A", 56, Color3.fromHex("FFF4D6"), Color3.fromHex("E8C987"))
small.Position = UDim2.fromScale(0.5, 0.26)
small.Parent = stage
local big = label("SCHNITZEL", 120, Color3.fromHex("FFE066"), Color3.fromHex("E8781C"))
big.Position = UDim2.fromScale(0.5, 0.42)
big.Parent = stage
local logoScale = Instance.new("UIScale")
logoScale.Parent = big

local mallet = Instance.new("ImageLabel")
mallet.AnchorPoint = Vector2.new(0.2, 0.9)
mallet.Position = UDim2.fromScale(0.78, 0.3)
mallet.Size = UDim2.fromOffset(150, 150)
mallet.BackgroundTransparency = 1
mallet.Image = MALLET_ICON
mallet.ScaleType = Enum.ScaleType.Fit
mallet.Rotation = 60
mallet.Parent = stage

-- schnitzel-shaped progress bar: a rounded "cutlet" that breads from pale dough to golden brown
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Position = UDim2.fromScale(0.5, 0.72)
bar.Size = UDim2.fromOffset(520, 46)
bar.BackgroundColor3 = Color3.fromHex("2A1A10")
bar.Parent = stage
corner(bar, UDim.new(0.5, 0))
stroke(bar, 4, Enum.ApplyStrokeMode.Border)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = DOUGH
fill.BorderSizePixel = 0
fill.Parent = bar
corner(fill, UDim.new(0.5, 0))
local crumbs = Instance.new("ImageLabel")
crumbs.Size = UDim2.fromScale(1, 1)
crumbs.BackgroundTransparency = 1
crumbs.Image = SCHNITZEL_ICON
crumbs.ImageTransparency = 0.75
crumbs.ScaleType = Enum.ScaleType.Tile
crumbs.TileSize = UDim2.fromOffset(46, 46)
crumbs.Parent = fill
corner(crumbs, UDim.new(0.5, 0))
local cutlet = Instance.new("ImageLabel")
cutlet.AnchorPoint = Vector2.new(0.5, 0.5)
cutlet.Position = UDim2.fromScale(0, 0.5)
cutlet.Size = UDim2.fromOffset(70, 70)
cutlet.BackgroundTransparency = 1
cutlet.Image = SCHNITZEL_ICON
cutlet.ScaleType = Enum.ScaleType.Fit
cutlet.ZIndex = 3
cutlet.Parent = bar

local tip = label("Getting the pans hot...", 26, Color3.new(1, 1, 1), Color3.fromHex("C9C9D2"))
tip.Position = UDim2.fromScale(0.5, 0.82)
tip.Parent = stage

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(0.5, 1)
skip.Position = UDim2.new(0.5, 0, 1, -24)
skip.Size = UDim2.fromOffset(260, 40)
skip.BackgroundTransparency = 1
skip.FontFace = FONT
skip.Text = "Tap to skip"
skip.TextSize = 26
skip.TextColor3 = Color3.fromHex("FFE066")
stroke(skip, 3)
skip.Parent = background

gui.Parent = playerGui

local function rescale()
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		stageScale.Scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 600), 0.4, 1.4)
	end
end
rescale()

-- the mallet slams onto the logo (and keeps tapping it)
task.spawn(function()
	while gui.Parent do
		TweenService:Create(mallet, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 60 }):Play()
		task.wait(0.5)
		TweenService:Create(mallet, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = -10 }):Play()
		task.wait(0.12)
		logoScale.Scale = 0.9
		TweenService:Create(logoScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		big.Rotation = math.random(-3, 3)
		TweenService:Create(big, TweenInfo.new(0.25), { Rotation = 0 }):Play()
		task.wait(0.9)
	end
end)

local TIPS = {
	"Getting the pans hot...",
	"Tenderizing the cutlets...",
	"Breading with love...",
	"Merge two ovens to get a better one!",
	"Rare schnitzels are worth way more!",
}

local started = os.clock()
local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

local function ready(): boolean
	return game:IsLoaded() and playerGui:FindFirstChild("GameUi") ~= nil
end

local shown = 0
local tipIndex = 1
local lastTip = os.clock()
local connection = RunService.RenderStepped:Connect(function(dt)
	rescale()
	-- progress: eases towards 90% while loading, then to 100% once the game UI is up
	local target = if ready() then 1 else 0.9 * (1 - math.exp(-(os.clock() - started) / 4))
	shown += (target - shown) * math.min(1, dt * 4)
	fill.Size = UDim2.fromScale(math.max(shown, 0.08), 1)
	fill.BackgroundColor3 = DOUGH:Lerp(GOLDEN, shown)
	cutlet.Position = UDim2.fromScale(shown, 0.5)
	cutlet.Rotation = math.sin(os.clock() * 6) * 8
	pattern.Position = UDim2.fromOffset(-120 + (os.clock() * 12) % 120, -120 + (os.clock() * 8) % 120)
	if os.clock() - lastTip > 2.2 then
		lastTip = os.clock()
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = TIPS[tipIndex]
	end
end)

while not skipped do
	local elapsed = os.clock() - started
	if (ready() and elapsed >= MIN_SHOW and shown > 0.97) or elapsed > MAX_WAIT then
		break
	end
	task.wait(0.05)
end

-- fade out
local info = TweenInfo.new(0.45)
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("ImageLabel") then
		TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
	if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
		TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.5)
connection:Disconnect()
gui:Destroy()
player:SetAttribute("LoadingDone", true)
