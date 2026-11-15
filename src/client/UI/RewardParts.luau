-- A jutalom-ablakok (Daily Rewards, Playtime Gifts) közös elemei: jutalom-matrica, idő, végtelen hullám- és
-- rúgás-animációk, és a jutalom-kártya (ugyanaz, mint az EggDrop játékban).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local create = Vide.create
local read = Vide.read
local C = Theme.Colors
local Parts = {}

export type TileState = "claimed" | "ready" | "locked"
type Value<T> = Kit.Value<T>

-- Végtelen tween, a hívó hatókörével együtt áll le.
local function loop(instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	Vide.cleanup(function()
		tween:Cancel()
	end)
end

-- A jutalom matricája (Config.Rewards: Money / Tickets / Pet).
function Parts.icon(reward: any): string
	if reward.Kind == "Pet" then
		return Ui.Icons.Pets
	elseif reward.Kind == "Tickets" then
		return Ui.Icons.Ticket
	end
	return if reward.Minutes >= 10 then Ui.Icons.CoinChest else Ui.Icons.CoinBag
end

-- A matrica sarkára írt mennyiség: itt mindig üres, a darabszám a kártya feliratában van ("3 Aura Tickets"),
-- mert a kis kártyákon a matrica sarka rácsúszna a feliratra.
function Parts.amount(_reward: any): string
	return ""
end

function Parts.clock(): () -> number
	local now = Vide.source(workspace:GetServerTimeNow())
	local alive = true
	Vide.cleanup(function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			now(workspace:GetServerTimeNow())
			task.wait(1)
		end
	end)
	return now
end

function Parts.time(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d:%02d", remaining // 3600, remaining // 60 % 60, remaining % 60)
end

-- Rövid idő (playtime ajándék): "4:07", egy óra felett "1:04:07".
function Parts.short(seconds: number): string
	local remaining = math.max(0, math.ceil(seconds))
	if remaining >= 3600 then
		return Parts.time(remaining)
	end
	return string.format("%d:%02d", remaining // 60, remaining % 60)
end

-- NumberValue-n futó tween Vide-forrásként; a hívó hatókörével együtt áll le.
local function holder(initial: number): (NumberValue, () -> number)
	local value = Instance.new("NumberValue")
	value.Value = initial
	local out = Vide.source(initial)
	local connection = value.Changed:Connect(out)
	Vide.cleanup(function()
		connection:Disconnect()
		value:Destroy()
	end)
	return value, out
end

-- 0 → 1 → 0 hullám (Sine), period mp alatt oda-vissza; delay: fáziseltolás (csak egyszer, az elején).
function Parts.wave(period: number, delay: number?): () -> number
	local value, out = holder(0)
	local tween = TweenService:Create(value, TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Value = 1 })
	local alive = true
	task.delay(delay or 0, function()
		if alive then
			tween:Play()
		end
	end)
	Vide.cleanup(function()
		alive = false
		tween:Cancel()
	end)
	return out
end

-- Egyszeri animáció: play(from, to, info) a from értékről (nil = ahonnan most áll) a célba tweenel.
function Parts.animated(initial: number): (() -> number, (from: number?, target: number, info: TweenInfo) -> ())
	local value, out = holder(initial)
	local tween: Tween? = nil
	Vide.cleanup(function()
		if tween then
			tween:Cancel()
		end
	end)
	return out, function(from: number?, target: number, info: TweenInfo)
		if tween then
			tween:Cancel()
		end
		if from then
			value.Value = from
		end
		tween = TweenService:Create(value, info, { Value = target })
		tween:Play()
	end
end

-- Felvillanó-elhalványuló négyágú csillogás.
function Parts.sparkle(position: UDim2, size: number, delay: number, color: Color3, z: number?): ImageLabel
	local scale = create "UIScale" { Scale = 0 } :: UIScale
	loop(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, delay), { Scale = 1 })
	local image = create "ImageLabel" {
		Name = "Sparkle", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1, Image = Ui.Textures.Sparkle, ImageColor3 = color, ZIndex = z or 5, scale,
	} :: ImageLabel
	loop(image, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 180 })
	return image
end

-- Lassan forgó napkitörés (a kártyák és a bannerek háttere).
function Parts.sunburst(position: UDim2, size: number, color: Value<Color3>, transparency: Value<number>, period: number?): ImageLabel
	local rays = create "ImageLabel" {
		Name = "Sunburst", AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
		Size = UDim2.fromScale(size, size), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1, Image = Ui.Textures.Sunburst, ImageColor3 = color, ImageTransparency = transparency,
		ZIndex = 2,
	} :: ImageLabel
	loop(rays, TweenInfo.new(period or 28, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	return rays
end
-- Cukorka-gradiens egy palettából (felül világos, középen a fő szín, alul a perem sötétje), mint a bolti kártyákon.
function Parts.gradient(palette: () -> Theme.Palette): UIGradient
	return create "UIGradient" {
		Rotation = 90,
		Color = function()
			local p = palette()
			return ColorSequence.new({
				ColorSequenceKeypoint.new(0, p.top),
				ColorSequenceKeypoint.new(0.5, p.bottom),
				ColorSequenceKeypoint.new(1, p.lip),
			})
		end,
	} :: UIGradient
end

-- Zöld pipa, ami a kártyára "csapódik": stamp 0 → 1 (nagyból a helyére, közben megjelenik).
function Parts.stamp(stamp: () -> number, position: UDim2, size: number, z: number): ImageLabel
	return create "ImageLabel" {
		Name = "Check", AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
		Size = UDim2.fromScale(size, size), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1, Image = Ui.Icons.Check, ScaleType = Enum.ScaleType.Fit, ZIndex = z,
		Rotation = -10,
		ImageTransparency = function()
			return 1 - math.clamp(stamp(), 0, 1)
		end,
		Visible = function()
			return stamp() > 0.01
		end,
		create "UIScale" {
			Scale = function()
				return 2.4 - 1.4 * stamp()
			end,
		},
	} :: ImageLabel
end

-- Jutalom-kártya. Felül a fejléc (DAY 3 / UP NEXT), középen a lebegő matrica a forgó napkitörés előtt, alul a jutalom
-- neve (és ha van, az ára). Állapotok (State):
--   ready   – lüktet, fehér-arany keret és dicsfény, átfut rajta a fénycsík, a matrica dobog;
--   claimed – sötét fátyol, rácsapódik a zöld pipa (átvételkor rúgással és szikrákkal);
--   locked  – a saját színében, nyugodtan lebeg.
-- Saját kulcsok: Color (paletta neve, reaktív), Header, Icon, Amount, Title, Price, PriceColor, TitleColor (reaktív),
-- State, Appear (0..1, Motion), Big (a nagy, kiemelt kártya), Phase (a lebegés fáziseltolása), Pop (reaktív szám:
-- ha változik, a kártya rúg és szikrázik), Highlight (fehér keret akkor is, ha nem átvehető: a sor következő eleme), Footer (a cím helyére kerülő elem, pl. a gomb), Children (további elemek).
function Parts.tile(props: { [string]: any }): Frame
	local state: () -> TileState = props.State
	local function ready()
		return state() == "ready"
	end
	local function palette(): Theme.Palette
		return Theme.Palettes[read(props.Color)]
	end
	local big = props.Big == true
	local appear = props.Appear or function()
		return 1
	end
	local bob = Parts.wave(2.4, props.Phase or 0)
	local beat = Parts.wave(0.9)
	local punch, kick = Parts.animated(1)
	local stamp, play = Parts.animated(if Vide.untrack(state) == "claimed" then 1 else 0)
	local hovered = Vide.source(false)
	local hover = Vide.spring(function()
		return if hovered() then 1 else 0
	end, 0.25, 0.6)
	local burstLayer = create "Frame" { Name = "Burst", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9 } :: Frame

	local function celebrate(color: Color3)
		kick(1.22, 1, TweenInfo.new(0.75, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
		Kit.burst(burstLayer, UDim2.fromScale(0.5, 0.45), color, 12, if big then 1.5 else 1.15)
	end
	local previous = Vide.untrack(state)
	Vide.effect(function()
		local current = state()
		if current == previous then
			return
		end
		if current == "claimed" and previous == "ready" then
			play(0, 1, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.08))
			celebrate(Theme.Palettes.Green.light)
		else
			play(nil, if current == "claimed" then 1 else 0, TweenInfo.new(0.2))
			if current == "ready" then
				kick(1.15, 1, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
			end
		end
		previous = current
	end)
	if props.Pop then
		local last = Vide.untrack(props.Pop)
		Vide.effect(function()
			local value = props.Pop()
			if value ~= last then
				last = value
				celebrate(Theme.Palettes.Yellow.light)
			end
		end)
	end

	local hasPrice = props.Price ~= nil
	-- kis kártyán az ikon kisebb és feljebb van, hogy a felirat (és az idő) ne lógjon rá
	local iconY = if big then 0.47 else 0.45
	local iconSize = if big then 0.45 else 0.48
	local card = Kit.darkBox {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return UDim2.new(0.5, 0, 0.5, (1 - appear()) * 40)
		end,
		Size = UDim2.fromScale(1, 1), Fill = C.White, Transparency = 0, Active = true,
		Line = function()
			return palette().light
		end,
		Outline = function()
			if ready() then
				return C.White:Lerp(Theme.Palettes.Yellow.light, beat())
			end
			return if read(props.Highlight) then C.White else C.Ink
		end,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear()) * punch() * (1 + hover() * 0.04 + (if ready() then beat() * 0.035 else 0))
			end,
		},
		Parts.gradient(palette),
		Kit.weld(function()
			return palette().light
		end, 0.88),
		-- napkitörés és fénycsík, a kártyára vágva
		create "Frame" {
			Name = "Effects", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2,
			Parts.sunburst(UDim2.fromScale(0.5, iconY), if big then 1.6 else 2.1, function()
				return palette().light
			end, function()
				return if ready() then 0.3 + beat() * 0.2 else 0.62
			end, if big then 22 else 30),
			create "Frame" {
				Name = "ShineHolder", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Visible = ready,
				Kit.shine(0.45),
			},
		},
		create "ImageLabel" {
			Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
			Size = UDim2.fromScale(iconSize * 1.6, iconSize * 1.6), SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1, Image = Ui.Textures.Soft, ZIndex = 3,
			ImageColor3 = function()
				return palette().light
			end,
			ImageTransparency = function()
				return if ready() then 0.15 + beat() * 0.2 else 0.5
			end,
		},
		create "ImageLabel" {
			Name = "Reward", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.fromScale(0.5, iconY - (bob() - 0.5) * 0.06)
			end,
			Size = UDim2.fromScale(iconSize, iconSize), SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1, Image = props.Icon, ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
			Rotation = function()
				return (bob() - 0.5) * 8
			end,
			create "UIScale" {
				Scale = function()
					return 1 + hover() * 0.12 + (if ready() then beat() * 0.08 else 0)
				end,
			},
			Kit.text {
				Name = "Amount", Text = props.Amount or "", TextSize = if big then 30 else 22,
				TextColor3 = Theme.Colors.Lemon, TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 8, 1, 4), Size = UDim2.fromOffset(60, 26),
				Rotation = 8, ZIndex = 5,
			},
		},
		Parts.sparkle(UDim2.fromScale(0.2, 0.3), if big then 24 else 16, (props.Phase or 0) * 0.6, C.White),
		Parts.sparkle(UDim2.fromScale(0.82, 0.58), if big then 18 else 13, 0.5 + (props.Phase or 0) * 0.4, C.White),
		Kit.text {
			Name = "Header", Text = props.Header, TextSize = if big then 30 else 20,
			Position = UDim2.fromOffset(0, if big then 6 else 4), Size = UDim2.new(1, 0, 0, if big then 32 else 22), ZIndex = 6,
		},
		Kit.text {
			Name = "Title", Text = props.Title, TextSize = if big then 21 else 15, TextWrapped = true,
			TextColor3 = props.TitleColor or C.White,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if hasPrice then -27 else -7),
			Size = UDim2.new(1, -10, 0, if big then 46 else 32), ZIndex = 6,
			Visible = props.TitleVisible,
		},
		if hasPrice
			then Kit.text {
				Name = "Price", Text = props.Price, TextSize = 19, TextColor3 = props.PriceColor or C.Money,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 22),
				ZIndex = 6, Visible = props.TitleVisible,
			}
			else nil,
		-- átvett: sötét fátyol és pipa
		create "Frame" {
			Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, ZIndex = 7,
			BackgroundTransparency = function()
				return 1 - math.clamp(stamp(), 0, 1) * 0.45
			end,
			create "UICorner" { CornerRadius = UDim.new(0, 4) },
		},
		Parts.stamp(stamp, UDim2.fromScale(0.5, iconY), if big then 0.34 else 0.42, 8),
		props.Footer,
		props.Children,
	}
	return create "Frame" {
		Name = props.Name or "Tile", Size = props.Size or UDim2.fromScale(1, 1), LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		-- dicsfény a kártya mögött, amíg átvehető
		create "ImageLabel" {
			Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 46, 1, 46), BackgroundTransparency = 1, Image = Ui.Textures.Soft,
			ImageColor3 = Theme.Palettes.Yellow.light, Visible = ready,
			ImageTransparency = function()
				return 0.2 + beat() * 0.35
			end,
			create "UIScale" {
				Scale = function()
					return math.max(0, appear())
				end,
			},
		},
		card,
		burstLayer,
	} :: Frame
end

return Parts
