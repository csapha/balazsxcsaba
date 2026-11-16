-- Shop window (GDD 5, 6.2–6.3), in the same UI Kit style as the other windows.
-- Three tabs (decision 2026-11-15, uncluttered): Featured (VIP, Starter Pack, daily deal, event offer), Gamepasses,
-- Items (Cash, Boosts, Fun). Codes moved out (Settings window later); Golden Egg, Aura Roll and trails are not sold here.
-- A buy button sends Remotes.ShopBuy; the server opens the Roblox purchase prompt (in Studio a product without
-- an ID is granted for free) and answers with Remotes.ShopPurchased → Effects.purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EventState = require(Shared.EventState)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local C = Theme.Colors
local ShopConfig = Config.Shop

local ShopWindow = {}

local TAB_TITLES = {
	Featured = "Featured",
	Passes = "Gamepasses",
	Items = "Items",
}
local TAB_ICONS = {
	Featured = Ui.Icons.Gift,
	Passes = Ui.Icons.Star,
	Items = Ui.Icons.CoinBag,
}

local CARD_H = 214
local GAP = 10

local function robux(price: number): string
	return `\u{E002} {price}` -- the Robux sign (Roblox renders it in every font)
end

-- Prices shown are always true (decision 2026-11-15, no fake "was" prices):
--   an item with a Roblox ID shows its live Roblox price (GetProductInfo);
--   the normal price is only struck through when the price really is lower (launch sale, daily deal).
local livePrices = source({} :: { [string]: number })
task.spawn(function()
	local MarketplaceService = game:GetService("MarketplaceService")
	local function fetch(cacheKey: string, id: number, infoType: Enum.InfoType)
		if id <= 0 then
			return
		end
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
			if ok and info and type(info.PriceInRobux) == "number" then
				local prices = table.clone(Vide.untrack(livePrices))
				prices[cacheKey] = info.PriceInRobux
				livePrices(prices)
			end
		end)
	end
	for key, item in ShopConfig.Passes do
		fetch("Pass:" .. key, item.GamePassId, Enum.InfoType.GamePass)
	end
	for key, item in ShopConfig.Products do
		fetch("Product:" .. key, item.ProductId, Enum.InfoType.Product)
	end
	for id, offer in ShopConfig.EventOffers do
		fetch("Event:" .. id, offer.ProductId, Enum.InfoType.Product)
	end
	for _, list in { ShopConfig.Trails, ShopConfig.Themes } do
		for id, entry in list do
			fetch("Cosmetic:" .. id, entry.ProductId or 0, Enum.InfoType.Product)
		end
	end
	for index, deal in ShopConfig.Deals do
		fetch("Deal:" .. index, deal.ProductId, Enum.InfoType.Product)
	end
end)

local IS_STUDIO = game:GetService("RunService"):IsStudio()

-- Seconds left of the gamepass launch sale (0 = no sale). In Studio without an end date it is previewed
-- for StudioPreviewDays from the first join, so the look can be tested.
local function saleRemaining(now: number): number
	local sale = ShopConfig.LaunchSale
	if sale.EndsAt > 0 then
		return math.max(0, sale.EndsAt - now)
	end
	local firstJoin = State.shop().firstJoin
	if IS_STUDIO and firstJoin > 0 then
		return math.max(0, firstJoin + sale.StudioPreviewDays * 86400 - now)
	end
	return 0
end

-- A gamepass's price now, and its normal price when the current one is really lower.
local function passPrice(key: string, now: number): (number, number?)
	local item = ShopConfig.Passes[key]
	local live = livePrices()["Pass:" .. key]
	if live then
		return live, if live < item.Price then item.Price else nil
	end
	-- no Roblox ID yet: the sale price the Creator Hub price has to be set to during the sale
	if saleRemaining(now) > 0 then
		local discount = ShopConfig.LaunchSale.Discounts[key] or 0
		if discount > 0 then
			return math.floor(item.Price * (1 - discount) + 0.5), item.Price
		end
	end
	return item.Price, nil
end

local function productPrice(key: string): number
	return livePrices()["Product:" .. key] or ShopConfig.Products[key].Price
end

-- The daily deal's price, and the product's normal price when the deal really is cheaper.
local function dealPrice(index: number): (number, number?)
	local deal = ShopConfig.Deals[index]
	local price = livePrices()["Deal:" .. index] or deal.Price
	local normal = productPrice(deal.Product)
	return price, if price < normal then normal else nil
end

-- The biggest launch sale discount (the strip says "up to -40%").
local function maxSaleDiscount(): number
	local best = 0
	for _, discount in ShopConfig.LaunchSale.Discounts do
		best = math.max(best, discount)
	end
	return best
end

local function percentOff(price: number, normal: number): string
	return `-{math.floor((1 - price / normal) * 100 + 0.5)}%`
end

-- Value tag (decision 2026-11-15: only computed, true values): amount per Robux compared with the smallest item
-- of the same ValueGroup, e.g. "x4.6 VALUE"; the BestValue item says "BEST VALUE".
local function valueTag(key: string): string?
	local item = ShopConfig.Products[key]
	local group = item.ValueGroup
	if not group then
		return nil
	end
	if item.BestValue then
		return "BEST VALUE"
	end
	local function amount(entry: any): number
		return entry.Seconds or entry.Duration or entry.Count or 1
	end
	for _, other in ShopConfig.ProductOrder do
		local base = ShopConfig.Products[other]
		-- compared with the smallest item shown in the same place (hidden items are not a fair base)
		if base.ValueGroup == group and base.Tab == item.Tab then
			if other == key then
				return nil -- the smallest one is the base
			end
			local ratio = (amount(item) / productPrice(key)) / (amount(base) / productPrice(other))
			return if ratio >= 1.1 then string.format("x%.1f VALUE", ratio) else nil
		end
	end
	return nil
end

local function duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	if hours >= 24 then
		return `{hours // 24}d {hours % 24}h`
	elseif hours > 0 then
		return string.format("%d:%02d:%02d", hours, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- os.time() as a Vide source, ticking every second (boost / offer timers).
local function clock(): () -> number
	local now = source(os.time())
	local running = true
	task.spawn(function()
		while running do
			task.wait(1)
			now(os.time())
		end
	end)
	Vide.cleanup(function()
		running = false
	end)
	return now
end

-- The data the shared formulas need (passes, boosts, shop), built from the reactive State.
local function shopData(): any
	return { passes = State.passes(), timedBoosts = State.timedBoosts(), shop = State.shop() }
end

-- Pops the page in (from slightly smaller) whenever its tab is selected.
local function tabPop(visible: () -> boolean): () -> number
	return spring(function()
		return if visible() then 1 else 0.86
	end, 0.22, 0.55)
end

type Card = {
	order: number,
	name: string,
	description: () -> string,
	icon: string,
	color: string,
	button: () -> string, -- label
	buttonColor: () -> string,
	onBuy: () -> (),
	ribbon: (() -> string?)?,
	ribbonColor: (string | () -> string)?,
	status: (() -> string?)?, -- small green line (e.g. "Active 12:31")
	oldPrice: (() -> string?)?, -- the normal price, struck through (only when the real price is lower)
}

-- endless tweens only run while the page is in the game (Motion.loop)
local loop = Motion.loop

-- The candy surface of every shop card (decision 2026-11-16, the Egg Drop store look): the palette's vertical
-- gradient, the welded rim, and a slowly turning sunburst clipped to the card (rays: centre and size).
-- The card itself is a Kit.darkBox with Fill = C.White and Transparency = 0.
local function candySurface(palette: Theme.Palette, rays: UDim2, raysSize: UDim2): { Instance }
	local burst = create "ImageLabel" {
		Name = "Sunburst",
		Image = Ui.Textures.Sunburst,
		ImageColor3 = palette.light,
		ImageTransparency = 0.65,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = rays,
		Size = raysSize,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	}
	loop(burst, TweenInfo.new(36, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	return {
		create "UIGradient" {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, palette.top),
				ColorSequenceKeypoint.new(0.42, palette.bottom),
				ColorSequenceKeypoint.new(1, palette.lip),
			}),
		},
		Kit.weld(palette.light, 0.9),
		create "Frame" {
			Name = "Effects",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
			create "UICorner" { CornerRadius = UDim.new(0, 4) },
			burst,
		},
	}
end

-- A product card: candy surface, a big icon (grows on hover), name, description, optional ribbon / status line,
-- and the buy button.
local function card(spec: Card, appear: () -> number, pop: () -> number): Frame
	local palette = Theme.Palettes[spec.color] or Theme.Palettes.Blue
	local hasRibbon = spec.ribbon ~= nil
	local hovered = source(false)
	local hover = spring(function()
		return if hovered() then 1 else 0
	end, 0.3, 0.7)
	return Kit.darkBox {
		Name = spec.name,
		LayoutOrder = spec.order,
		Fill = C.White,
		Transparency = 0,
		Line = palette.light,
		Active = true,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear()) * pop()
			end,
		},
		candySurface(palette, UDim2.fromScale(0.5, 50 / CARD_H), UDim2.fromScale(2, 2)),
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 50),
			Size = UDim2.new(1, 0, 0, 110),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ZIndex = 2,
		},
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 50),
			Size = UDim2.fromOffset(86, 86),
			BackgroundTransparency = 1,
			Image = spec.icon,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = -6,
			ZIndex = 3,
			create "UIScale" {
				Scale = function()
					return 1 + hover() * 0.08
				end,
			},
		},
		if hasRibbon
			then Kit.plate {
				Name = "Ribbon",
				Color = spec.ribbonColor or "Red",
				Text = function()
					return (spec.ribbon :: () -> string?)() or ""
				end,
				Visible = function()
					return (spec.ribbon :: () -> string?)() ~= nil
				end,
				TextSize = 15,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, -8), -- inside the card on the right: the page clips anything past its edge
				Size = UDim2.fromOffset(92, 26),
				-- no rotation: a rotated frame does not clip the plate's shine streak (it leaked out as a "/")
				ZIndex = 6,
			}
			else nil,
		if spec.oldPrice
			then Kit.text {
				Name = "OldPrice",
				RichText = true,
				Text = function()
					local old = (spec.oldPrice :: () -> string?)()
					return if old then `<s>{old}</s>` else ""
				end,
				TextSize = 18,
				TextColor3 = C.Bad,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.fromOffset(110, 22),
				Rotation = -4,
				ZIndex = 6,
			}
			else nil,
		Kit.text {
			Name = "Title",
			Text = spec.name,
			TextSize = 19,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 94),
			Size = UDim2.new(1, -16, 0, 22),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Description",
			Text = spec.description,
			TextSize = 14,
			Gradient = false,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(8, 118),
			Size = UDim2.new(1, -16, 0, 30),
			ZIndex = 3,
		},
		if spec.status
			then Kit.text {
				Name = "Status",
				Text = function()
					return (spec.status :: () -> string?)() or ""
				end,
				TextSize = 14,
				TextColor3 = C.Money,
				Gradient = false,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -50),
				Size = UDim2.new(1, -16, 0, 16),
				ZIndex = 3,
			}
			else nil,
		Kit.button {
			Name = "Buy",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 38),
			TextSize = 20,
			Bounce = 0.4,
			Color = spec.buttonColor,
			Text = spec.button,
			Activated = spec.onBuy,
			ZIndex = 4,
		},
	} :: Frame
end

local function grid(name: string, columns: number, cards: { Frame }, order: number?): Frame
	return create "Frame" {
		Name = name,
		LayoutOrder = order or 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		create "UIGridLayout" {
			-- 1 px slack: three cells of exactly a third rounded up past the width and wrapped to two columns
			CellSize = UDim2.new(1 / columns, -GAP * (columns - 1) / columns - 1, 0, CARD_H),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		cards,
	} :: Frame
end

local function page(name: string, visible: () -> boolean, children: { any }): ScrollingFrame
	return create "ScrollingFrame" {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = visible,
		ScrollBarThickness = 0, -- scrolls by drag / wheel, like the other windows
		ScrollBarImageTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		create "UIListLayout" {
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		},
		-- room for the ribbons and the hover bounce
		create "UIPadding" {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		},
		children,
	} :: ScrollingFrame
end

local function denied()
	Audio.play("Error")
end

-- A card for a dev product (Cash / Boosts / Eggs / Featured).
local function productCard(order: number, key: string, appear: () -> number, pop: () -> number, now: () -> number): Frame
	local item = ShopConfig.Products[key]
	local function availableNow(): boolean
		if item.Soon or not item.Effect then
			return false
		end
		if item.Effect == "OfflineX10" then
			return State.offline().pending > 0
		elseif item.Effect == "Starter" then
			return Formulas.starterRemaining(shopData(), now()) > 0
		end
		return true
	end
	local status = nil
	if item.Effect == "Boost" then
		status = function(): string?
			local left = Formulas.boostRemaining(shopData(), item.Boost, now())
			return if left > 0 then `Active {duration(left)}` else nil
		end
	elseif item.Effect == "OfflineX10" then
		status = function(): string?
			return if State.offline().pending > 0 then nil else "No offline earnings now"
		end
	end
	return card({
		order = order,
		name = item.Name,
		description = function()
			return item.Description
		end,
		icon = Ui.Icons[item.Icon] or Ui.Icons.Shop,
		color = item.Color,
		button = function()
			return if item.Soon then "SOON" else robux(productPrice(key))
		end,
		buttonColor = function()
			return if availableNow() then "Green" else "Gray"
		end,
		onBuy = function()
			if availableNow() then
				Remotes.ShopBuy:FireServer("Product", key)
			else
				denied()
			end
		end,
		-- "SOON", or the computed value tag ("x4.6 VALUE" / "BEST VALUE")
		ribbon = if item.Soon or item.ValueGroup
			then function(): string?
				return if item.Soon then "SOON" else valueTag(key)
			end
			else nil,
		ribbonColor = function(): string
			if item.Soon then
				return "Gray"
			end
			return if item.BestValue then "Red" else "Yellow"
		end,
		status = status,
	}, appear, pop)
end

------------------------------------------------------------------------------------------------
-- Gamepasses tab (decision 2026-11-16, the same layout as the Egg Drop store): a wide featured card on top,
-- then a two-column grid of candy cards (palette gradient, slowly turning sunburst, a big bouncing sticker icon,
-- a twinkling sparkle, tag line, title, the perk in green, two lines of details and the price button).
------------------------------------------------------------------------------------------------
local FEATURED_H = 226
local PASS_H = 296
local PASS_GAP = 14

local function picture(name: string, asset: string, position: UDim2, size: UDim2, z: number?): ImageLabel
	return create "ImageLabel" {
		Name = name,
		Image = asset,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z or 3,
	} :: ImageLabel
end

-- A section header: icon, title and a thin rule to the right edge.
local function passSection(order: number, title: string, icon: string, pop: () -> number): Frame
	return create "Frame" {
		Name = title,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		create "UIScale" { Scale = pop },
		picture("Icon", icon, UDim2.fromOffset(18, 18), UDim2.fromOffset(34, 34)),
		Kit.text {
			Name = "Title",
			Text = title,
			TextSize = 25,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(45, 0),
			Size = UDim2.fromOffset(255, 36),
		},
		create "Frame" {
			Name = "Rule",
			Position = UDim2.new(0, 302, 0.5, -1),
			Size = UDim2.new(1, -310, 0, 2),
			BackgroundColor3 = C.PanelLine,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
		},
	} :: Frame
end

local function passCard(
	key: string,
	featured: boolean,
	index: number,
	count: number,
	anim: Motion.Anim,
	pop: () -> number,
	now: () -> number
): Frame
	local item = ShopConfig.Passes[key]
	local palette = Theme.Palettes[item.Color] or Theme.Palettes.Blue
	local appear = anim.stagger(index, count)
	local iconAppear = anim.appear(0.2 + (index - 1) * 0.07, 0, Enum.EasingStyle.Elastic, 0.85)
	local hovered = source(false)
	local hover = spring(function()
		return if hovered() then 1 else 0
	end, 0.3, 0.7)

	local function owned(): boolean
		return State.passes()[key] == true
	end
	-- the price now, and the normal price when it really is lower (launch sale)
	local function prices(): (number, number?)
		if owned() or item.Soon then
			return item.Price, nil
		end
		return passPrice(key, now())
	end
	local function ribbon(): string?
		if owned() then
			return "OWNED"
		elseif item.Soon then
			return "SOON"
		end
		local price, normal = prices()
		return if normal then percentOff(price, normal) else nil
	end

	local fill = if featured then 0.82 else 0.94
	local sticker = picture("Sticker", Ui.Icons[item.Icon] or Ui.Icons.Shop, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(fill, fill))
	create "UIScale" {
		Parent = sticker,
		Scale = function()
			return math.max(0, iconAppear()) * (1 + hover() * 0.07)
		end,
	}
	local sparkle = picture("Sparkle", Ui.Textures.Sparkle, UDim2.fromScale(0.85, 0.28), UDim2.fromOffset(22, 22), 4)
	local twinkle = create "UIScale" { Parent = sparkle, Scale = 0.5 }
	loop(twinkle, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, index * 0.2), { Scale = 1.1 })

	local tag = item.Tag or "GAMEPASS"
	local body = Kit.darkBox {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return UDim2.new(0.5, 0, 0.5, (1 - appear()) * 38)
		end,
		Size = UDim2.fromScale(1, 1),
		Fill = C.White,
		Transparency = 0,
		Line = palette.light,
		Active = true,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear()) * pop()
			end,
		},
		-- the rays belong to the whole card, so there is no smaller clipped edge behind the icon
		candySurface(
			palette,
			if featured then UDim2.fromScale(0.79, 0.5) else UDim2.fromScale(0.5, 65 / PASS_H),
			UDim2.fromScale(2.3, 2.3)
		),
		create "Frame" {
			Name = "Artwork",
			BackgroundTransparency = 1,
			ZIndex = 3,
			AnchorPoint = if featured then Vector2.new(1, 0.5) else Vector2.new(0.5, 0),
			Position = if featured then UDim2.new(1, -14, 0.5, -2) else UDim2.fromScale(0.5, 0),
			Size = if featured then UDim2.new(0.39, 0, 1, -14) else UDim2.new(1, 0, 0, 130),
			picture("Glow", Ui.Textures.Soft, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.95, 0.95), 2),
			sticker,
			sparkle,
		},
		Kit.text {
			Name = "Tag",
			Text = if featured then `{tag}  /  PERMANENT` else "PERMANENT",
			TextSize = 13,
			TextColor3 = palette.light,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 21),
			ZIndex = 4,
		},
		-- OWNED / SOON / "-33%" in the top right corner (inside the card: the page clips anything past its edge)
		Kit.plate {
			Name = "Ribbon",
			Color = function()
				if owned() then
					return "Green"
				end
				return if item.Soon then "Gray" else "Red"
			end,
			Text = function()
				return ribbon() or ""
			end,
			Visible = function()
				return ribbon() ~= nil
			end,
			TextSize = 15,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(84, 26),
			ZIndex = 6,
		},
		Kit.text {
			Name = "Title",
			Text = if featured then item.Headline or item.Name else item.Name,
			TextSize = if featured then 37 else 27,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = if featured then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Position = if featured then UDim2.fromOffset(20, 37) else UDim2.fromOffset(8, 123),
			Size = if featured then UDim2.new(0.6, -20, 0, 43) else UDim2.new(1, -16, 0, 33),
			ZIndex = 4,
		},
		Kit.text {
			Name = "Perk",
			Text = item.Perk or "",
			TextSize = if featured then 23 else 19,
			TextColor3 = C.Money,
			Gradient = false,
			TextXAlignment = if featured then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Position = if featured then UDim2.fromOffset(22, 80) else UDim2.fromOffset(8, 159),
			Size = if featured then UDim2.new(0.6, -22, 0, 29) else UDim2.new(1, -16, 0, 26),
			ZIndex = 4,
		},
		Kit.text {
			Name = "Details",
			Text = item.Details or item.Description,
			TextSize = if featured then 17 else 15,
			Gradient = false,
			TextXAlignment = if featured then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Position = if featured then UDim2.fromOffset(22, 111) else UDim2.fromOffset(8, 188),
			Size = if featured then UDim2.new(0.59, -22, 0, 44) else UDim2.new(1, -16, 0, 40),
			ZIndex = 4,
		},
		-- the normal price, struck through, only while the real price is lower (next to the ribbon)
		Kit.text {
			Name = "OldPrice",
			RichText = true,
			Text = function()
				local _, normal = prices()
				return if normal then `<s>{robux(normal)}</s>` else ""
			end,
			TextSize = 18,
			TextColor3 = C.Bad,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -98, 0, 10), -- left of the "-33%" ribbon
			Size = UDim2.fromOffset(90, 22),
			Rotation = -4,
			ZIndex = 6,
		},
		Kit.button {
			Name = "Buy",
			TextSize = 25,
			Bounce = 0.4,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = if featured then UDim2.new(0.28, 0, 1, -16) else UDim2.new(0.5, 0, 1, -13),
			Size = if featured then UDim2.new(0.5, 0, 0, 49) else UDim2.new(1, -26, 0, 47),
			Color = function()
				if owned() then
					return "Blue"
				end
				return if item.Soon then "Gray" else "Green"
			end,
			Text = function()
				if owned() then
					return "OWNED"
				end
				return if item.Soon then "COMING SOON" else robux((prices()))
			end,
			Activated = function()
				if owned() or item.Soon then
					denied()
				else
					Remotes.ShopBuy:FireServer("Pass", key)
				end
			end,
			ZIndex = 5,
		},
	}
	return create "Frame" {
		Name = key,
		LayoutOrder = index,
		Size = if featured then UDim2.new(1, 0, 0, FEATURED_H) else UDim2.new(0.5, -PASS_GAP / 2, 0, PASS_H),
		BackgroundTransparency = 1,
		body,
	} :: Frame
end

local function passesPage(visible: () -> boolean, anim: Motion.Anim, now: () -> number): ScrollingFrame
	local pop = tabPop(visible)
	local order = ShopConfig.PassOrder
	local count = #order

	-- two cards per row; a card left alone at the end becomes a wide one (no empty space next to it)
	local rows = {}
	for index = 2, count, 2 do
		local alone = order[index + 1] == nil
		local cards = { passCard(order[index], alone, index, count, anim, pop, now) }
		if not alone then
			table.insert(cards, passCard(order[index + 1], false, index + 1, count, anim, pop, now))
		end
		table.insert(rows, create "Frame" {
			Name = "Row",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, if alone then FEATURED_H else PASS_H),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, PASS_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			cards,
		})
	end

	-- launch sale strip: only while the sale really runs
	local saleIn = anim.appear(0.08, 0, Enum.EasingStyle.Back)
	local sale = Kit.darkBox {
		Name = "LaunchSale",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 46),
		Line = Theme.Palettes.Red.light,
		Visible = function()
			return saleRemaining(now()) > 0
		end,
		create "UIScale" {
			Scale = function()
				return math.max(0, saleIn()) * pop()
			end,
		},
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(30, 23),
			Size = UDim2.fromOffset(46, 46),
			BackgroundTransparency = 1,
			Image = Ui.Icons.LuckyTime,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = -8,
			ZIndex = 3,
		},
		Kit.text {
			Name = "Title",
			Text = `LAUNCH SALE  up to -{math.floor(maxSaleDiscount() * 100 + 0.5)}% on gamepasses`,
			TextSize = 22,
			Gradient = ColorSequence.new(Theme.Palettes.Red.light, Theme.Palettes.Yellow.top),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(60, 0),
			Size = UDim2.new(1, -260, 1, 0),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Timer",
			Text = function()
				return `Ends in {duration(saleRemaining(now()))}`
			end,
			TextSize = 18,
			TextColor3 = C.Lemon,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 0),
			Size = UDim2.new(0, 200, 1, 0),
			ZIndex = 3,
		},
	}

	local scroller = page("PassesPage", visible, {
		sale,
		passSection(1, "FEATURED", Ui.Icons.Crown, pop),
		passCard(order[1], true, 1, count, anim, pop, now),
		passSection(3, "GAMEPASSES", Ui.Icons.Star, pop),
		create "Frame" {
			Name = "Passes",
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create "UIListLayout" {
				Padding = UDim.new(0, PASS_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			rows,
		},
		Kit.text {
			Name = "Footer",
			LayoutOrder = 5,
			Text = "GAMEPASSES ARE FOREVER.",
			TextSize = 14,
			TextColor3 = C.Muted,
			Gradient = false,
			Size = UDim2.new(1, 0, 0, 24),
		},
	})
	-- the wider gaps of this layout
	local layout = scroller:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, PASS_GAP)
	end
	return scroller
end

type Banner = {
	name: string,
	order: number,
	title: string,
	palette: string,
	icon: string,
	contents: () -> string,
	sub: () -> string,
	oldPrice: (() -> string?)?,
	ribbon: () -> string?,
	ribbonColor: string,
	button: () -> string,
	buttonColor: () -> string,
	onBuy: () -> (),
	visible: (() -> boolean)?,
}

-- A big offer banner on the Featured page (VIP, Starter Pack): sunburst + icon on the left, title, what you get,
-- a yellow line, the buy button on the right and a ribbon in the corner.
local function bigBanner(spec: Banner, appear: () -> number, pop: () -> number): Frame
	local palette = Theme.Palettes[spec.palette]
	return Kit.darkBox {
		Name = spec.name,
		LayoutOrder = spec.order,
		Size = UDim2.new(1, 0, 0, 132),
		Fill = C.White,
		Transparency = 0,
		Line = palette.light,
		Visible = spec.visible,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear()) * pop()
			end,
		},
		candySurface(palette, UDim2.new(0, 70, 0.5, 0), UDim2.fromScale(2.3, 2.3)),
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(70, 66),
			Size = UDim2.fromOffset(150, 150),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ZIndex = 2,
		},
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(70, 66),
			Size = UDim2.fromOffset(96, 96),
			BackgroundTransparency = 1,
			Image = spec.icon,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = -8,
			ZIndex = 3,
		},
		Kit.text {
			Name = "Title",
			Text = spec.title,
			TextSize = 30,
			StrokeThickness = 3,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(140, 10),
			Size = UDim2.new(1, -330, 0, 34),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Contents",
			Text = spec.contents,
			TextSize = 16,
			TextColor3 = C.Vanilla,
			Gradient = false,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(140, 48),
			Size = UDim2.new(1, -330, 0, 42),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Sub",
			Text = spec.sub,
			TextSize = 15,
			TextColor3 = C.Lemon,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(140, 98),
			Size = UDim2.new(1, -330, 0, 20),
			ZIndex = 3,
		},
		Kit.plate {
			Name = "Ribbon",
			Color = spec.ribbonColor,
			Text = function()
				return spec.ribbon() or ""
			end,
			Visible = function()
				return spec.ribbon() ~= nil
			end,
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, -8), -- inside the banner: the page clips anything past its edge
			Size = UDim2.fromOffset(110, 28),
			ZIndex = 6,
		},
		if spec.oldPrice
			then Kit.text {
				Name = "OldPrice",
				RichText = true,
				Text = function()
					local old = (spec.oldPrice :: () -> string?)()
					return if old then `<s>{old}</s>` else ""
				end,
				TextSize = 18,
				TextColor3 = C.Bad,
				Gradient = false,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(1, -99, 0.5, -23), -- between the ribbon and the button
				Size = UDim2.fromOffset(170, 22),
				ZIndex = 4,
			}
			else nil,
		Kit.button {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 6),
			Size = UDim2.fromOffset(170, 56),
			TextSize = 26,
			Color = spec.buttonColor,
			Text = spec.button,
			Activated = spec.onBuy,
			ZIndex = 4,
		},
	} :: Frame
end

-- Featured: the VIP banner, the starter pack banner (first 3 days), and two small cards: the daily deal and the
-- limited event offer (decision 2026-11-15: an uncluttered front page).
local function featuredPage(visible: () -> boolean, anim: Motion.Anim, now: () -> number): ScrollingFrame
	local pop = tabPop(visible)

	local function vipOwned(): boolean
		return State.passes().VIP == true
	end
	local function vipPrice(): (number, number?)
		return passPrice("VIP", now())
	end
	local vipBanner = bigBanner({
		name = "Vip",
		order = 1,
		title = "VIP",
		palette = "Yellow",
		icon = Ui.Icons.Crown,
		contents = function()
			return "x1.5 money forever, gold [VIP] tag, VIP area with better egg luck, VIP Golden Poodle pet and a daily gift"
		end,
		sub = function()
			return if vipOwned() then "You are VIP, enjoy!" else "The best way to support the game!"
		end,
		oldPrice = function(): string?
			if vipOwned() then
				return nil
			end
			local _, normal = vipPrice()
			return if normal then robux(normal) else nil
		end,
		ribbon = function(): string?
			if vipOwned() then
				return "OWNED"
			end
			local price, normal = vipPrice()
			return if normal then percentOff(price, normal) else nil
		end,
		ribbonColor = "Red",
		button = function()
			return if vipOwned() then "OWNED" else robux((vipPrice()))
		end,
		buttonColor = function()
			return if vipOwned() then "Gray" else "Green"
		end,
		onBuy = function()
			if vipOwned() then
				denied()
			else
				Remotes.ShopBuy:FireServer("Pass", "VIP")
			end
		end,
	}, anim.appear(0.08, 0, Enum.EasingStyle.Back), pop)

	local starter = ShopConfig.Products.Starter
	local function starterShown(): boolean
		return Formulas.starterRemaining(shopData(), now()) > 0
	end
	local starterBanner = bigBanner({
		name = "StarterPack",
		order = 2,
		title = "STARTER PACK",
		palette = "Pink",
		icon = Ui.Icons.Gift,
		contents = function()
			return starter.Description
		end,
		-- a true value line: the same 1 h x2 Money boost costs this much on its own
		sub = function()
			local alone = robux(productPrice("BoostMoney60"))
			return `The 1h x2 Money alone is {alone}! Ends in {duration(Formulas.starterRemaining(shopData(), now()))}`
		end,
		ribbon = function(): string?
			return "ONLY ONCE"
		end,
		ribbonColor = "Red",
		button = function()
			return robux(productPrice("Starter"))
		end,
		buttonColor = function()
			return "Green"
		end,
		onBuy = function()
			if starterShown() then
				Remotes.ShopBuy:FireServer("Product", "Starter")
			else
				denied()
			end
		end,
		visible = starterShown,
	}, anim.appear(0.16, 0, Enum.EasingStyle.Back), pop)

	-- daily deal: today's product at a discount, with the time left until tomorrow's deal
	local function deal(): (number, any, any)
		local index = Formulas.dailyDeal(now())
		local entry = ShopConfig.Deals[index]
		return index, entry, ShopConfig.Products[entry.Product]
	end
	local function dealItem(): any
		local _, _, item = deal()
		return item
	end
	local cards = {}
	local dealIn = anim.stagger(3, 4)
	-- the card's static parts (icon, colour) follow the deal of the day the window was built; the text follows `now`
	table.insert(cards, card({
		order = 1,
		name = "Daily Deal",
		description = function()
			local item = dealItem()
			return `{item.Name}: {item.Description}`
		end,
		icon = Ui.Icons[dealItem().Icon] or Ui.Icons.Shop,
		color = "Red",
		-- the normal price is struck through only because it really is the item's everyday price
		oldPrice = function(): string?
			local _, normal = dealPrice((deal()))
			return if normal then robux(normal) else nil
		end,
		button = function()
			return robux((dealPrice((deal()))))
		end,
		buttonColor = function()
			return "Green"
		end,
		onBuy = function()
			local index = deal()
			Remotes.ShopBuy:FireServer("Deal", index)
		end,
		ribbon = function(): string?
			local price, normal = dealPrice((deal()))
			return if normal then percentOff(price, normal) else nil
		end,
		ribbonColor = "Red",
		status = function(): string?
			local _, left = Formulas.dailyDeal(now())
			return `New deal in {duration(left)}`
		end,
	}, dealIn, pop))

	-- limited event offer: during a random event, a matching item cheaper (GDD 5.1 ①)
	local function activeOffer(): (string?, any?, any?)
		now() -- re-evaluate every second (the event state is not a Vide source)
		local id = EventState.active()
		local offer = id and ShopConfig.EventOffers[id]
		if not id or not offer then
			return nil, nil, nil
		end
		return id, offer, ShopConfig.Products[offer.Product]
	end
	local function offerPrice(): (number, number?)
		local id, offer = activeOffer()
		if not id or not offer then
			return 0, nil
		end
		local price = livePrices()["Event:" .. id] or offer.Price
		local normal = productPrice(offer.Product)
		return price, if price < normal then normal else nil
	end
	table.insert(cards, card({
		order = 2,
		name = "Event Offer",
		description = function()
			local id, _, item = activeOffer()
			if id and item then
				return `{Config.Events.List[id].Name}: {item.Name} ({item.Description})`
			end
			return "A special deal during every random event"
		end,
		icon = Ui.Icons.LuckyTime,
		color = "Red",
		oldPrice = function(): string?
			local _, normal = offerPrice()
			return if normal then robux(normal) else nil
		end,
		button = function()
			if activeOffer() then
				return robux((offerPrice()))
			end
			local seconds = math.max(0, math.ceil(EventState.nextAt() - workspace:GetServerTimeNow()))
			return `Next event {duration(seconds)}`
		end,
		buttonColor = function()
			return if activeOffer() then "Green" else "Gray"
		end,
		onBuy = function()
			local id = activeOffer()
			if id then
				Remotes.ShopBuy:FireServer("EventOffer", id)
			else
				denied()
			end
		end,
		ribbon = function(): string?
			local price, normal = offerPrice()
			return if normal then percentOff(price, normal) else nil
		end,
		ribbonColor = "Red",
		status = function(): string?
			if not activeOffer() then
				return nil
			end
			return `Ends in {duration(EventState.endsAt() - workspace:GetServerTimeNow())}`
		end,
	}, anim.stagger(4, 4), pop))

	return page("FeaturedPage", visible, {
		vipBanner,
		starterBanner,
		grid("Offers", 2, cards, 3),
	})
end

local function sectionTitle(order: number, text: string): TextLabel
	return Kit.text {
		Name = text,
		LayoutOrder = order,
		Text = text,
		TextSize = 22,
		TextColor3 = C.Lemon,
		Gradient = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}
end

-- Items: Cash, Boosts and Fun in one tab, each with its section title (decision 2026-11-15: fewer tabs).
local SECTION_TITLES = { Cash = "CASH", Boosts = "BOOSTS", Fun = "FUN" }

local function itemsPage(visible: () -> boolean, anim: Motion.Anim, now: () -> number): ScrollingFrame
	local pop = tabPop(visible)
	local children = {}
	local count = 0
	for _, key in ShopConfig.ProductOrder do
		if ShopConfig.Products[key].Tab == "Items" then
			count += 1
		end
	end
	local index, order = 0, 0
	for _, section in ShopConfig.ItemSections do
		local cards = {}
		for _, key in ShopConfig.ProductOrder do
			local item = ShopConfig.Products[key]
			if item.Tab == "Items" and item.Section == section then
				index += 1
				table.insert(cards, productCard(#cards + 1, key, anim.stagger(index, count), pop, now))
			end
		end
		order += 1
		table.insert(children, sectionTitle(order, SECTION_TITLES[section] or section))
		order += 1
		table.insert(children, grid(section, 3, cards, order))
	end
	return page("ItemsPage", visible, children)
end

function ShopWindow.render(anim: Motion.Anim)
	local tab = source("Featured")
	local now = clock()
	local function shown(name: string): () -> boolean
		return function()
			return tab() == name
		end
	end
	local tabs = {}
	for order, name in ShopConfig.Tabs do
		table.insert(tabs, Kit.button {
			Name = name,
			LayoutOrder = order,
			Icon = TAB_ICONS[name],
			IconSize = 0.85,
			Color = "Orange",
			Shine = false,
			Size = UDim2.fromOffset(56, 56),
			Selected = shown(name),
			Activated = function()
				tab(name)
			end,
		})
	end
	return Kit.window {
		Name = "Shop",
		Title = function()
			return TAB_TITLES[tab()] or "Shop"
		end,
		Color = "Orange",
		Icon = Ui.Icons.Shop,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(500))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = tabs,
		-- only the selected tab's page is in the GUI tree (Kit.tabPage)
		Body = {
			Kit.tabPage(featuredPage(shown("Featured"), anim, now), shown("Featured")),
			Kit.tabPage(passesPage(shown("Passes"), anim, now), shown("Passes")),
			Kit.tabPage(itemsPage(shown("Items"), anim, now), shown("Items")),
		},
	}
end

-- shared with the offer toasts (the same true prices)
ShopWindow.passPrice = passPrice
ShopWindow.productPrice = productPrice

return ShopWindow
