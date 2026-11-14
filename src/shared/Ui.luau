-- Shared UI assets (font, icons, textures) – the same set as the Snowboard / EggDrop games.
local Ui = {}

Ui.Font = Font.fromEnum(Enum.Font.FredokaOne)

Ui.Icons = {
	Rocket = "rbxassetid://121204255802248",
	Coin = "rbxassetid://112296648588822",
	CoinBag = "rbxassetid://104576122861394",
	Star = "rbxassetid://93292654368812",
	Perfect = "rbxassetid://100359138171159",
	Crown = "rbxassetid://98010907624345",
	Clock = "rbxassetid://102171725944402",
	Dice = "rbxassetid://90559985843183",
	Clover = "rbxassetid://132181365383308",
	Check = "rbxassetid://109580000795959",
	Upgrade = "rbxassetid://121238272813200",
	Energy = "rbxassetid://132789735668197",
	Settings = "rbxassetid://87302285465220",
	Rebirth = "rbxassetid://107895867958209",
	RebirthCash = "rbxassetid://140253337509832",
	KeepRecord = "rbxassetid://78071540124290",
	Shop = "rbxassetid://86346701405723",
	DoubleCoins = "rbxassetid://133077600665893",
	Gift = "rbxassetid://105723053929618",
	Crystal = "rbxassetid://73523130116681",
	PotionLuck = "rbxassetid://130648621139817",
	PotionSpeed = "rbxassetid://135386557857245",
	PotionCoins = "rbxassetid://138457756699787",
	PotionSuper = "rbxassetid://113526442178829",
	AutoPotion = "rbxassetid://99674977212290",
	LuckyTime = "rbxassetid://75830772068168",
	Catapult = "rbxassetid://117118775982175",
	Engine = "rbxassetid://110044400794600",
	FuelTank = "rbxassetid://106805711958036",
	Aero = "rbxassetid://90815767719104",
	-- from the EggDrop set
	Index = "rbxassetid://137728724613874", -- book
	Pets = "rbxassetid://83033278034512", -- chick and penguin
	Egg = "rbxassetid://72513704446696", -- painted egg with a brush
	Home = "rbxassetid://79862103392613", -- map pin
	Daily = "rbxassetid://119448096104463", -- gift box
	Friends = "rbxassetid://111792408758191",
	Quests = "rbxassetid://99026244699085",
	LuckBoost = "rbxassetid://92439609695382", -- golden egg with a clover
	CoinChest = "rbxassetid://107526813691557",
	KeepPets = "rbxassetid://136611409860607",
	Strength = "rbxassetid://94788295391267",
}

Ui.Textures = {
	Weld = "rbxassetid://103583466007371",
	Rays = "rbxassetid://82821798093227",
	Shine = "rbxassetid://140082896278542",
	Sunburst = "rbxassetid://97314861460154",
	Sparkle = "rbxassetid://97572037624011",
	Soft = "rbxassetid://139896213305360",
	Ring = "rbxassetid://75832845756633",
	SlotFill = "rbxassetid://126346788026290",
	SlotOutline = "rbxassetid://87735383098707",
	SlotRing = "rbxassetid://134869482939495",
	Bullseye = "rbxassetid://120129419362980",
	HexFill = "rbxassetid://115044936108381",
	HexRing = "rbxassetid://81690748456645",
	HexGlow = "rbxassetid://70981472884256",
	TutorialArrow = "rbxassetid://71387266491638",
	SnowFlake = "rbxassetid://138089411214946",
	SnowCrystal = "rbxassetid://126552947346487",
}

Ui.Vfx = {
	Bolt1 = "rbxassetid://104997565351359",
	Bolt2 = "rbxassetid://91597413362818",
	Crackle = "rbxassetid://71208673147304",
	Streak = "rbxassetid://92572387296671",
	Ring = "rbxassetid://118429702237860",
	MagicCircle = "rbxassetid://84753627948307",
	Speedlines = "rbxassetid://123601808221768",
	Portal = "rbxassetid://74623681241327",
	Arc = "rbxassetid://121892542894061",
	Aura = "rbxassetid://134130398061673",
	Starlight = "rbxassetid://140515148620308",
	Shine = "rbxassetid://112694638267645",
	StarTall = "rbxassetid://80610105432609",
	Star4 = "rbxassetid://80808649417267",
}

local SOFT_IMAGE = "rbxassetid://139896213305360"
local SOFT_HALF = 32

function Ui.applySoftBackground(image: ImageLabel, transparency: number?, radius: number?)
	image.BackgroundTransparency = 1
	image.Image = SOFT_IMAGE
	image.ImageColor3 = Color3.new(0, 0, 0)
	image.ImageTransparency = transparency or 0.35
	image.ScaleType = Enum.ScaleType.Slice
	image.SliceCenter = Rect.new(SOFT_HALF - 1, SOFT_HALF - 1, SOFT_HALF + 1, SOFT_HALF + 1)
	image.SliceScale = (radius or 18) / SOFT_HALF
end

function Ui.softPanel(transparency: number?, radius: number?): ImageLabel
	local panel = Instance.new("ImageLabel")
	panel.Name = "Soft"
	panel.BorderSizePixel = 0
	Ui.applySoftBackground(panel, transparency, radius)
	return panel
end

function Ui.icon(image: string, size: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(size, size)
	icon.Image = image
	icon.ScaleType = Enum.ScaleType.Fit
	return icon
end

function Ui.text(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = Ui.Font
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	for k, v in props do
		(label :: any)[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("2B2340")
	stroke.Thickness = if label.TextSize >= 24 then 2.5 else 1.5
	stroke.Parent = label
	return label
end

function Ui.list(parent: Instance, gap: number, horizontal: boolean?)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
end

function Ui.padding(parent: Instance, x: number, y: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, x)
	pad.PaddingRight = UDim.new(0, x)
	pad.PaddingTop = UDim.new(0, y)
	pad.PaddingBottom = UDim.new(0, y)
	pad.Parent = parent
end

function Ui.pill(icon: string?, textProps: { [string]: any }, iconSize: number?): (ImageLabel, TextLabel, ImageLabel?)
	local panel = Ui.softPanel(0.35, 16)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.XY
	Ui.padding(panel, 14, 4)
	Ui.list(panel, 6, true)
	local iconLabel
	if icon then
		iconLabel = Ui.icon(icon, iconSize or 26)
		iconLabel.LayoutOrder = 1
		iconLabel.Parent = panel
	end
	textProps.Size = UDim2.fromOffset(0, 0)
	textProps.AutomaticSize = Enum.AutomaticSize.XY
	textProps.LayoutOrder = 2
	local label = Ui.text(textProps)
	label.Parent = panel
	return panel, label, iconLabel
end

-- World text (BillboardGui / SurfaceGui labels) in the UI Kit text style: Fredoka, thick dark round outline
-- and the soft white → grey shine. Works on the server and the client.
local INK = Color3.fromHex("0B0A12")
local SHINE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHex("ABABB6")),
})

function Ui.worldText(label: TextLabel, thickness: number?)
	label.FontFace = Ui.Font
	label.TextStrokeTransparency = 1
	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness or 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	local gradient = label:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = SHINE
	gradient.Parent = label
end

-- Fades a world text out (the text and its outline).
function Ui.fadeText(label: TextLabel, info: TweenInfo)
	local TweenService = game:GetService("TweenService")
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
end

return Ui
