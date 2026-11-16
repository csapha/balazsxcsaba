-- GDD 7.1 Loading screen (ReplicatedFirst: it shows before anything else loads). New look 2026-11-16, in the
-- game's candy UI Kit style (the Kit itself is not loaded yet here, so it is rebuilt from plain Instances):
--   a warm orange gradient with a slowly turning sunburst and a soft vignette, schnitzels drifting down behind;
--   the logo ("SELL A" + a big gold "SCHNITZEL" with the thick ink outline, a schnitzel sticker on top) drops in
--   with a bounce, a shake and a crumb burst;
--   a Kit-style loading bar (dark pill, gold candy fill, "LOADING... 64%" inside, a schnitzel riding the edge);
--   a tip line under it and a candy SKIP button (never hold the player up).
-- It closes when the game UI is up (data loaded) – or on SKIP. Then it sets the local player's "LoadingDone"
-- attribute, so the tutorial intro (camera flight) starts after it.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SCHNITZEL_ICON = "rbxassetid://98613698863535"
local SUNBURST = "rbxassetid://97314861460154"
local SOFT = "rbxassetid://139896213305360"
local SPARKLE = "rbxassetid://97572037624011"
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local INK = Color3.fromHex("0B0A12")
local WHITE = Color3.new(1, 1, 1)
local LEMON = Color3.fromHex("FFE066")
local PANEL = Color3.fromHex("0E1017")
-- the Kit palettes (UI/Theme): Yellow for the bar fill, Green for the skip button
local YELLOW = { light = Color3.fromHex("FFF38A"), top = Color3.fromHex("FFE23A"), bottom = Color3.fromHex("F48E1C") }
local GREEN = { light = Color3.fromHex("C2FF8A"), top = Color3.fromHex("8CF54E"), bottom = Color3.fromHex("2DB82A"), lip = Color3.fromHex("185212") }
-- the Kit's text gradient: white on top, a soft grey at the bottom of the letters
local TEXT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, WHITE),
	ColorSequenceKeypoint.new(0.35, WHITE),
	ColorSequenceKeypoint.new(1, Color3.fromHex("ABABB6")),
})

local MIN_SHOW = 2.5 -- seconds (the logo drop)
local MAX_WAIT = 30
local STAGE = Vector2.new(1000, 600)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local function new(class: string, props: { [string]: any }): any
	local instance = Instance.new(class)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function corner(parent: Instance, radius: UDim)
	new("UICorner", { CornerRadius = radius, Parent = parent })
end

local function stroke(parent: Instance, thickness: number, color: Color3?, mode: Enum.ApplyStrokeMode?, transparency: number?)
	return new("UIStroke", {
		Color = color or INK,
		Thickness = thickness,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual,
		Parent = parent,
	})
end

-- Kit-style text: Fredoka, thick ink outline, vertical gradient over the letters only (the label is as tall as
-- the text, so the gradient is not squeezed into a band)
local function label(props: { [string]: any }): TextLabel
	local size = props.TextSize or 24
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = props.Text or "",
		RichText = props.RichText or false,
		TextSize = size,
		TextColor3 = WHITE,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(900, size),
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	stroke(l, props.Stroke or math.clamp(size / 9, 1.5, 7))
	if props.Gradient ~= false then
		new("UIGradient", { Rotation = 90, Color = props.Gradient or TEXT_GRADIENT, Parent = l })
	end
	return l
end

local gui = new("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Background --------------------------------------------------------------------------------------------------

local background = new("Frame", {
	Name = "Background",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Active = true, -- swallows clicks, nothing behind reacts
	Parent = gui,
})
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFC15A")),
		ColorSequenceKeypoint.new(0.55, Color3.fromHex("F28A22")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("C9501A")),
	}),
	Parent = background,
})

-- the turning sunburst behind the logo
local rays = new("ImageLabel", {
	Name = "Sunburst",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.fromScale(2.2, 2.2),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
	Image = SUNBURST,
	ImageColor3 = Color3.fromHex("FFF0A8"),
	ImageTransparency = 0.6,
	Parent = background,
})
TweenService:Create(rays, TweenInfo.new(40, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()

-- schnitzels drifting down (slow, soft, they never cover the logo much)
local drifters = {}
local random = Random.new()
for index = 1, 12 do
	local size = random:NextInteger(54, 110)
	local image = new("ImageLabel", {
		Name = "Drifter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = SCHNITZEL_ICON,
		ImageTransparency = 0.45 + random:NextNumber() * 0.25,
		ScaleType = Enum.ScaleType.Fit,
		Parent = background,
	})
	table.insert(drifters, {
		image = image,
		x = (index - 0.5) / 12 + random:NextNumber(-0.03, 0.03),
		speed = random:NextNumber(0.045, 0.09), -- screen heights per second
		offset = random:NextNumber(),
		spin = random:NextNumber(-25, 25),
		sway = random:NextNumber(0.01, 0.025),
	})
end

-- soft dark edges (top and bottom), so the middle glows
local vignette = new("Frame", {
	Name = "Vignette",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromHex("3A1206"),
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = background,
})
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	}),
	Parent = vignette,
})

-- Stage (scaled to the screen) ----------------------------------------------------------------------------------

local stage = new("Frame", {
	Name = "Stage",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(STAGE.X, STAGE.Y),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = background,
})
local stageScale = new("UIScale", { Parent = stage })

-- the logo
local logo = new("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(760, 300),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = stage,
})
local logoScale = new("UIScale", { Scale = 0, Parent = logo })

new("ImageLabel", {
	Name = "Glow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(820, 420),
	BackgroundTransparency = 1,
	Image = SOFT,
	ImageColor3 = Color3.fromHex("FFF4C0"),
	ImageTransparency = 0.35,
	ZIndex = 3,
	Parent = logo,
})
local sticker = new("ImageLabel", {
	Name = "Schnitzel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromOffset(150, 150),
	BackgroundTransparency = 1,
	Image = SCHNITZEL_ICON,
	ScaleType = Enum.ScaleType.Fit,
	Rotation = -10,
	ZIndex = 4,
	Parent = logo,
})
local small = label({
	Text = "SELL A",
	TextSize = 54,
	Stroke = 5,
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(700, 54),
	ZIndex = 5,
	Parent = logo,
})
small.Rotation = -3
local big = label({
	Text = "SCHNITZEL",
	TextSize = 128,
	Stroke = 8,
	Gradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFF7B0")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFD23A")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("F07E18")),
	}),
	Position = UDim2.fromScale(0.5, 0.74),
	Size = UDim2.fromOffset(760, 128),
	ZIndex = 5,
	Parent = logo,
})
big.Rotation = -3
local burstLayer = new("Frame", {
	Name = "Burst",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 6,
	Parent = logo,
})

-- the loading bar (Kit.bar look: dark pill, gold candy fill with a light inner ring, labels inside)
local BAR_W, BAR_H = 560, 42
local bar = new("Frame", {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.74),
	Size = UDim2.fromOffset(BAR_W, BAR_H),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	ZIndex = 3,
	Parent = stage,
})
corner(bar, UDim.new(0.5, 0))
stroke(bar, 3, INK, Enum.ApplyStrokeMode.Border)
local fill = new("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 4,
	Parent = bar,
})
corner(fill, UDim.new(0.5, 0))
new("UISizeConstraint", { MinSize = Vector2.new(BAR_H, 0), Parent = fill })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(YELLOW.top, YELLOW.bottom), Parent = fill })
local ring = new("Frame", {
	Name = "Inner",
	Position = UDim2.fromOffset(1.5, 1.5),
	Size = UDim2.new(1, -3, 1, -3),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = fill,
})
corner(ring, UDim.new(0.5, 0))
stroke(ring, 1.5, YELLOW.light, Enum.ApplyStrokeMode.Border, 0.15)
local loadingText = label({
	Text = "LOADING",
	TextSize = 20,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(300, 20),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
	Parent = bar,
})
local rider = new("ImageLabel", {
	Name = "Rider",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(62, 62),
	BackgroundTransparency = 1,
	Image = SCHNITZEL_ICON,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 7,
	Parent = bar,
})

-- the tip line
local TIPS = {
	"Merge two ovens to get a better one!",
	"Rare schnitzels sell for way more!",
	"Chefs carry your schnitzels for you.",
	"Wake up sleepy chefs for a speed boost!",
	"Claim your Daily Reward every day!",
	"Rebirth to earn money faster!",
}
local tip = label({
	RichText = true,
	Text = "",
	TextSize = 24,
	Stroke = 3,
	Gradient = false,
	Position = UDim2.fromScale(0.5, 0.86),
	Size = UDim2.fromOffset(900, 24),
	ZIndex = 3,
	Parent = stage,
})
local function setTip(index: number)
	tip.Text = `<font color="#{LEMON:ToHex()}">TIP:</font> {TIPS[index]}`
end

-- the SKIP button (a Kit candy button: dark lip, green face, light inner ring, ink outline)
local SKIP_H = 52
local skip = new("TextButton", {
	Name = "Skip",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -28, 1, -24),
	Size = UDim2.fromOffset(150, SKIP_H),
	BackgroundColor3 = GREEN.lip,
	AutoButtonColor = false,
	Text = "",
	ZIndex = 8,
	Parent = background,
})
corner(skip, UDim.new(0, 12))
stroke(skip, 3, INK, Enum.ApplyStrokeMode.Border)
-- one UIScale: fits the screen like the stage (around the bottom-right anchor) × the hover bounce
local skipScale = new("UIScale", { Parent = skip })
local skipHover = new("NumberValue", { Value = 1 })
local face = new("Frame", {
	Name = "Face",
	Size = UDim2.new(1, 0, 1, -4),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 9,
	Parent = skip,
})
corner(face, UDim.new(0, 12))
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GREEN.top, GREEN.bottom), Parent = face })
local faceRing = new("Frame", {
	Name = "Ring",
	Position = UDim2.fromOffset(1.5, 1.5),
	Size = UDim2.new(1, -3, 1, -3),
	BackgroundTransparency = 1,
	ZIndex = 10,
	Parent = face,
})
corner(faceRing, UDim.new(0, 10))
stroke(faceRing, 1.5, GREEN.light, Enum.ApplyStrokeMode.Border, 0.45)
label({
	Text = "SKIP",
	TextSize = 26,
	Size = UDim2.fromOffset(150, 26),
	ZIndex = 11,
	Parent = face,
})
skip.MouseEnter:Connect(function()
	TweenService:Create(skipHover, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1.06 }):Play()
end)
skip.MouseLeave:Connect(function()
	TweenService:Create(skipHover, TweenInfo.new(0.15), { Value = 1 }):Play()
end)

gui.Parent = playerGui

local leaving = false -- the exit tween owns the stage scale
local function rescale()
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		local fit = math.clamp(math.min(viewport.X / STAGE.X, viewport.Y / STAGE.Y), 0.4, 1.4)
		if not leaving then
			stageScale.Scale = fit
		end
		skipScale.Scale = fit * skipHover.Value
	end
end
rescale()

-- The logo drop: from big and tilted down onto the stage, a squash, a little shake and a crumb burst
local function crumbBurst()
	for _ = 1, 14 do
		local angle = random:NextNumber(0, math.pi * 2)
		local reach = random:NextNumber(200, 380)
		local sparkle = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromOffset(random:NextInteger(18, 34), random:NextInteger(18, 34)),
			BackgroundTransparency = 1,
			Image = if random:NextNumber() < 0.5 then SPARKLE else SCHNITZEL_ICON,
			ImageColor3 = if random:NextNumber() < 0.5 then Color3.fromHex("FFF38A") else WHITE,
			ZIndex = 6,
			Parent = burstLayer,
		})
		local target = UDim2.new(0.5, math.cos(angle) * reach, 0.62, math.sin(angle) * reach * 0.6)
		TweenService:Create(sparkle, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Rotation = random:NextNumber(-180, 180),
		}):Play()
		TweenService:Create(sparkle, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4), {
			ImageTransparency = 1,
		}):Play()
		task.delay(0.8, sparkle.Destroy, sparkle)
	end
end

task.spawn(function()
	logo.Rotation = -8
	logoScale.Scale = 1.8
	TweenService:Create(logoScale, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
	TweenService:Create(logo, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = 0 }):Play()
	task.wait(0.32)
	-- impact: squash, shake, burst
	logoScale.Scale = 0.9
	TweenService:Create(logoScale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	crumbBurst()
	for i = 1, 6 do
		stage.Position = UDim2.new(0.5, random:NextInteger(-8, 8) * (1 - i / 7), 0.5, random:NextInteger(-6, 6) * (1 - i / 7))
		task.wait(0.03)
	end
	stage.Position = UDim2.fromScale(0.5, 0.5)
end)

-- Loop --------------------------------------------------------------------------------------------------------------

local started = os.clock()
local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

local function ready(): boolean
	return game:IsLoaded() and playerGui:FindFirstChild("GameUi") ~= nil
end

local shown = 0
local tipIndex = random:NextInteger(1, #TIPS)
setTip(tipIndex)
local lastTip = os.clock()
local connection = RunService.RenderStepped:Connect(function(dt)
	rescale()
	local now = os.clock()
	-- progress: eases towards 90% while loading, then to 100% once the game UI is up
	local target = if ready() then 1 else 0.9 * (1 - math.exp(-(now - started) / 4))
	shown += (target - shown) * math.min(1, dt * 4)
	fill.Size = UDim2.fromScale(shown, 1)
	rider.Position = UDim2.new(math.clamp(shown, 0.04, 1), -6, 0.5, -2)
	rider.Rotation = math.sin(now * 5) * 10
	-- "LOADING... 64%" on the left: the schnitzel riding the fill's edge would cover anything on the right
	local text = `LOADING{string.rep(".", math.floor(now * 2.5) % 4)}  {math.floor(shown * 100 + 0.5)}%`
	if text ~= loadingText.Text then
		loadingText.Text = text
	end

	-- the schnitzel sticker on the logo floats a little
	sticker.Position = UDim2.new(0.5, 0, 0.2, math.sin(now * 2) * 6)
	sticker.Rotation = -10 + math.sin(now * 1.4) * 5

	for _, d in drifters do
		local y = (now * d.speed + d.offset) % 1.3 - 0.15
		d.image.Position = UDim2.fromScale(d.x + math.sin(now * 0.8 + d.offset * 6) * d.sway, y)
		d.image.Rotation = now * d.spin + d.offset * 360
	end

	if now - lastTip > 3 then
		lastTip = now
		tipIndex = tipIndex % #TIPS + 1
		setTip(tipIndex)
	end
end)

while not skipped do
	local elapsed = os.clock() - started
	if (ready() and elapsed >= MIN_SHOW and shown > 0.97) or elapsed > MAX_WAIT then
		break
	end
	task.wait(0.05)
end

-- out: the stage grows a little while everything fades
leaving = true
TweenService:Create(stageScale, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = stageScale.Scale * 1.12 }):Play()
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
