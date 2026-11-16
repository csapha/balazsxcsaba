-- Shared UI assets; Schnitzel icons are mapped in assets/ui/icons-manifest.json.
local Ui = {}

Ui.Font = Font.fromEnum(Enum.Font.FredokaOne)

Ui.Icons = {
	EventLunchRush = "rbxassetid://82806216790833",
	EventGoldenOil = "rbxassetid://132702915273035",
	EventBreadcrumbStorm = "rbxassetid://77872438516889",
	EventFoodCritic = "rbxassetid://119592672316765",
	EventGrandma = "rbxassetid://94583228102412",
	EventBlackout = "rbxassetid://112459192301040",
	Baking = "rbxassetid://124137842813509",
	Luck = "rbxassetid://108179624058657",
	Chefs = "rbxassetid://88499542528911",
	Ovens = "rbxassetid://104194062098104",
	MergeOvens = "rbxassetid://81165098929205",
	RebirthToken = "rbxassetid://116751232774202",
	OvenSlots = "rbxassetid://107350951768351",
	Auras = "rbxassetid://98809238199668",
	Rarities = "rbxassetid://136119603869831",
	Close = "rbxassetid://71790271242133",
	Ticket = "rbxassetid://97723266944090",
	Schnitzel = "rbxassetid://98613698863535",
	Rocket = "rbxassetid://121204255802248",
	Coin = "rbxassetid://128954478415430",
	CoinBag = "rbxassetid://99590768986281",
	Star = "rbxassetid://96886395265576",
	SeasonPass = "rbxassetid://123967822702376", -- golden star with schnitzel emblem
	PassXp = "rbxassetid://135613592435419",
	GoldenEgg = "rbxassetid://103079801895752",
	LemonZestTrail = "rbxassetid://88256764839025",
	SeasonHedgehog = "rbxassetid://140393696072231",
	SeasonGriffin = "rbxassetid://110574327552854",
	Perfect = "rbxassetid://100359138171159",
	Crown = "rbxassetid://98010907624345",
	Clock = "rbxassetid://129056316950740",
	Dice = "rbxassetid://90559985843183",
	Clover = "rbxassetid://132181365383308",
	Check = "rbxassetid://109580000795959",
	Upgrade = "rbxassetid://117394169798939",
	Energy = "rbxassetid://107477880230933",
	Settings = "rbxassetid://137472960814779",
	Rebirth = "rbxassetid://96649927080974",
	RebirthCash = "rbxassetid://101971163933621",
	KeepRecord = "rbxassetid://78071540124290",
	Shop = "rbxassetid://81892568453108", -- red shopping basket
	DoubleCoins = "rbxassetid://133077600665893",
	Gift = "rbxassetid://111048535886079", -- red gift box (Daily Rewards, Playtime Gifts)
	Crystal = "rbxassetid://125727528067073",
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
	-- Additional navigation and collection icons
	Index = "rbxassetid://121622520607924",
	Pets = "rbxassetid://118576246638418",
	Egg = "rbxassetid://102597749948484",
	Home = "rbxassetid://75262146154870",
	Daily = "rbxassetid://111048535886079", -- same gift box as Gift
	Friends = "rbxassetid://111792408758191",
	Quests = "rbxassetid://99026244699085",
	LuckBoost = "rbxassetid://92439609695382", -- golden egg with a clover
	CoinChest = "rbxassetid://73564604224923",
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
	-- 3D particle textures instead of Roblox's default sparkles / fire / smoke (decision 2026-11-16,
	-- from ui-resources.com: "star" whiteglowingstar.png, Kek's flame 5 and smoke 1)
	ParticleStar = "rbxassetid://125113188801545",
	ParticleFlame = "rbxassetid://76881140970195",
	-- Kek's smoke 1 (rbxassetid://118842987946808) did not load yet (in moderation on 2026-11-16): until it does,
	-- the smoke aura uses our own soft puff (the same as Soft), so it is never empty or a Roblox default
	ParticleSmoke = "rbxassetid://139896213305360",
}

-- Twinkling 4-point star sparkles (the replacement of the old Roblox Sparkles object): small glowing stars that
-- pop up around the part, grow, turn a little and fade. rate: stars per second.
function Ui.sparkles(parent: Instance, color: Color3, rate: number?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = Ui.Textures.ParticleStar
	emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = rate or 5
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(-20, 20)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 1.4, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

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
