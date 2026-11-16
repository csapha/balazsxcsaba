-- Schnitzel Pass window (GDD 6.4, decision 2026-11-16), opened from the TopbarPlus "Pass" icon
-- (Controllers/SeasonPassController). Two tabs:
--   Pass: tier badge + XP bar + season clock on top; a horizontal track of 30 tiers (a candy "TIER n" plate on
--     top: yellow = your tier, orange = reached, grey = not yet; the Free reward above, the Premium reward below, Premium rewards wear a crown and stay dimmed until
--     Premium is unlocked); at the bottom UNLOCK PREMIUM / +1 TIER / CLAIM ALL. Opens scrolled to the first
--     reward to claim (or the current tier).
--   Earn XP: how Pass XP is earned, with today's progress for the capped sources.
-- The reward cards look like the Daily Rewards cards (UI/RewardParts) but calmer and lighter: they do not pulse
-- (decision 2026-11-16), the claimable ones share one turning sunburst, and the columns come in a few per frame after the window opened (Motion.reveal).
-- Numbers: Config.SeasonPass, rules: Formulas.seasonTier / seasonClaimable, server: Services/SeasonPassService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local Parts = require(script.Parent.RewardParts)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local C = Theme.Colors

local PassConfig = Config.SeasonPass
local MAX_TIER = #PassConfig.Free
local IS_STUDIO = RunService:IsStudio()

local COL = 118 -- one tier column
local PILL_Y = 21 -- the tier plates' centre
local LABELS_W = 96 -- the FREE / PREMIUM column on the left
local SHOWN_AT_OPEN = 7
local REVEAL_DELAY = 0.45
local REVEAL_BATCH = 3

local SeasonPassWindow = {}

type Pass = { season: number, xp: number, premium: boolean, free: number, paid: number, day: number, merges: number, eggs: number }

local EMPTY: Pass = { season = PassConfig.Season.Id, xp = 0, premium = false, free = 0, paid = 0, day = 0, merges = 0, eggs = 0 }

-- This season's pass (the server resets an older season's data on its next tick; until then it reads as empty).
function SeasonPassWindow.pass(): Pass
	local pass = State.seasonPass()
	return if pass.season == PassConfig.Season.Id then pass else EMPTY
end

function SeasonPassWindow.active(): boolean
	return Formulas.seasonActive(State.now(), IS_STUDIO)
end

function SeasonPassWindow.tier(): number
	return (Formulas.seasonTier(SeasonPassWindow.pass().xp))
end

-- How many rewards can be claimed now (the TopbarPlus icon's notice and label).
function SeasonPassWindow.readyCount(): number
	if not SeasonPassWindow.active() then
		return 0
	end
	return Formulas.seasonReadyCount(SeasonPassWindow.pass())
end

local function robux(price: number): string
	return `\u{E002} {price}` -- the Robux sign (Roblox renders it in every font)
end

-- A product's price label: its Robux price, or SOON online while it has no Roblox id yet.
local function productLabel(key: string, prefix: string): string
	local item = Config.Shop.Products[key]
	if item.ProductId <= 0 and not IS_STUDIO then
		return prefix .. "SOON"
	end
	return prefix .. robux(item.Price)
end

-- "12d 4h", "5h 12m", "4:07"
local function timeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then
		return `{seconds // 86400}d {(seconds % 86400) // 3600}h`
	elseif seconds >= 3600 then
		return `{seconds // 3600}h {(seconds % 3600) // 60}m`
	end
	return Parts.short(seconds)
end

-- Rewards ---------------------------------------------------------------------------------------------------

local BOOST_ICONS = { Money = "PotionCoins", Luck = "PotionLuck", Bake = "PotionSpeed", ChefEnergy = "Energy" }
local PET_ICONS = { SeasonHedgehog = Ui.Icons.SeasonHedgehog, SeasonGriffin = Ui.Icons.SeasonGriffin }
local TRAIL_ICONS = { LemonZest = Ui.Icons.LemonZestTrail }

local function rewardIcon(reward: any): string
	local kind = reward.Kind
	if kind == "Money" then
		return if reward.Minutes >= 30 then Ui.Icons.CoinChest else Ui.Icons.CoinBag
	elseif kind == "Tickets" then
		return Ui.Icons.Ticket
	elseif kind == "Boost" then
		return Ui.Icons[BOOST_ICONS[reward.Boost] or "PotionSuper"]
	elseif kind == "Tokens" then
		return Ui.Icons.RebirthToken
	elseif kind == "Egg" then
		return Ui.Icons.GoldenEgg
	elseif kind == "Trail" then
		return TRAIL_ICONS[reward.Trail] or Ui.Icons.Star
	elseif kind == "Pet" then
		return PET_ICONS[reward.Pet] or Ui.Icons.Pets
	end
	return Ui.Icons.Pets
end

local function rewardHeader(reward: any): string
	local kind = reward.Kind
	if kind == "Money" then
		return "CASH"
	elseif kind == "Tickets" then
		return `x{reward.Amount}`
	elseif kind == "Boost" then
		return if reward.Minutes >= 60 then `{reward.Minutes // 60}H` else `{reward.Minutes} MIN`
	elseif kind == "Tokens" then
		return `x{reward.Amount}`
	elseif kind == "Egg" then
		return `x{reward.Count}`
	elseif kind == "Trail" then
		return "TRAIL"
	end
	return "PET"
end

-- The name under the sticker: money follows your current income.
local function rewardTitle(reward: any): string | () -> string
	local kind = reward.Kind
	if kind == "Money" then
		return function()
			State.money() -- refresh as income changes
			return NumberFormat.money(Formulas.rewardMoney(State.data(), reward.Minutes))
		end
	elseif kind == "Tickets" then
		return if reward.Amount == 1 then "Aura Ticket" else "Aura Tickets"
	elseif kind == "Boost" then
		return Config.Shop.BoostNames[reward.Boost]
	elseif kind == "Tokens" then
		return if reward.Amount == 1 then "Rebirth Token" else "Rebirth Tokens"
	elseif kind == "Egg" then
		return if reward.Count == 1 then "Golden Egg" else "Golden Eggs"
	elseif kind == "Trail" then
		return Config.Shop.Trails[reward.Trail].Name
	end
	return Config.Pets.List[reward.Pet].Name
end

local function rewardColor(reward: any): Color3
	local kind = reward.Kind
	if kind == "Pet" then
		return Config.Pets.Rarities[Config.Pets.List[reward.Pet].Rarity].Color:Lerp(C.White, 0.35)
	elseif kind == "Money" then
		return C.Money
	elseif kind == "Tokens" or kind == "Egg" or kind == "Trail" then
		return C.Vanilla
	end
	return C.Lemon
end

-- One reward card. state: "claimed" | "ready" | "locked"; dimmed: a Premium reward without Premium.
-- spin: the window's single turning value (0..360) for the claimable cards' sunburst. No pulsing (decision 2026-11-16).
local function rewardCard(props: {
	reward: any,
	premium: boolean,
	state: () -> Parts.TileState,
	dimmed: () -> boolean,
	next: () -> boolean,
	spin: () -> number,
	onClaim: () -> (),
	big: boolean,
}): Frame
	local state = props.state
	local function ready(): boolean
		return state() == "ready"
	end
	local palette = Theme.Palettes[if props.premium then "Yellow" elseif props.big then "Purple" else "Blue"]
	local function face(): Theme.Palette
		return if ready() and not props.premium then Theme.Palettes.Yellow else palette
	end
	local hovered = source(false)
	local hover = spring(function()
		return if hovered() then 1 else 0
	end, 0.25, 0.6)
	local punch, kick = Parts.animated(1)
	local stamp, play = Parts.animated(if Vide.untrack(state) == "claimed" then 1 else 0)
	local burstLayer = create "Frame" { Name = "Burst", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9 } :: Frame
	local previous = Vide.untrack(state)
	Vide.effect(function()
		local current = state()
		if current == previous then
			return
		end
		if current == "claimed" and previous == "ready" then
			play(0, 1, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.08))
			kick(1.22, 1, TweenInfo.new(0.75, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
			Kit.burst(burstLayer, UDim2.fromScale(0.5, 0.45), Theme.Palettes.Green.light, 10, 1.1)
		else
			play(nil, if current == "claimed" then 1 else 0, TweenInfo.new(0.2))
			if current == "ready" then
				kick(1.15, 1, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out))
			end
		end
		previous = current
	end)

	local iconY = 0.47
	return create "Frame" {
		Name = if props.premium then "Premium" else "Free",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		-- halo while it can be claimed
		create "ImageLabel" {
			Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 34, 1, 34), BackgroundTransparency = 1, Image = Ui.Textures.Soft,
			ImageColor3 = Theme.Palettes.Yellow.light, Visible = ready,
			ImageTransparency = function()
				return if ready() then 0.4 else 1
			end,
		},
		Kit.darkBox {
			Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1), Fill = C.White, Transparency = 0, Active = true,
			Line = function()
				return face().light
			end,
			Outline = function()
				if ready() then
					return Theme.Palettes.Yellow.light
				end
				return if props.next() then C.White else C.Ink
			end,
			MouseEnter = function()
				hovered(true)
			end,
			MouseLeave = function()
				hovered(false)
			end,
			create "UIScale" {
				Scale = function()
					return punch() * (1 + hover() * 0.04)
				end,
			},
			Parts.gradient(face),
			Kit.weld(function()
				return face().light
			end, 0.88),
			create "Frame" {
				Name = "Effects", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2,
				create "ImageLabel" {
					Name = "Sunburst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
					Size = UDim2.fromScale(2.1, 2.1), SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundTransparency = 1, Image = Ui.Textures.Sunburst, ZIndex = 2,
					ImageColor3 = function()
						return face().light
					end,
					ImageTransparency = function()
						return if ready() then 0.38 else 0.66
					end,
					-- only the claimable cards turn (one shared spin), the others stand still
					Rotation = function()
						return if ready() then props.spin() else 12
					end,
				},
			},
			create "ImageLabel" {
				Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
				Size = UDim2.fromScale(0.75, 0.75), SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1, Image = Ui.Textures.Soft, ZIndex = 3,
				ImageColor3 = function()
					return face().light
				end,
				ImageTransparency = function()
					return if ready() then 0.22 else 0.5
				end,
			},
			create "ImageLabel" {
				Name = "Reward", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
				Size = UDim2.fromScale(0.46, 0.46), SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1, Image = rewardIcon(props.reward), ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
				Rotation = -6,
				create "UIScale" {
					Scale = function()
						return 1 + hover() * 0.12
					end,
				},
			},
			if props.big
				then Parts.sparkle(UDim2.fromScale(0.22, 0.32), 16, 0.2, C.White)
				else nil,
			Kit.text {
				Name = "Header", Text = rewardHeader(props.reward), TextSize = 18,
				Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 20), ZIndex = 6,
			},
			Kit.text {
				Name = "Title", Text = rewardTitle(props.reward), TextSize = 14, TextWrapped = true,
				TextColor3 = rewardColor(props.reward), AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -8, 0, 30), ZIndex = 6,
				Visible = function()
					return not ready()
				end,
			},
			-- a Premium reward without Premium: dimmed, with the crown badge
			create "Frame" {
				Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, ZIndex = 7,
				BackgroundTransparency = function()
					return if props.dimmed() then 0.45 else 1
				end,
				create "UICorner" { CornerRadius = UDim.new(0, 4) },
			},
			-- claimed: dark veil and the check
			create "Frame" {
				Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, ZIndex = 7,
				BackgroundTransparency = function()
					return 1 - math.clamp(stamp(), 0, 1) * 0.45
				end,
				create "UICorner" { CornerRadius = UDim.new(0, 4) },
			},
			Parts.stamp(stamp, UDim2.fromScale(0.5, iconY), 0.42, 8),
			Kit.button {
				Name = "Claim", Text = "CLAIM!", Color = "Green", TextSize = 15,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -30, 0, 26),
				ZIndex = 8, Visible = ready, Interactable = State.loaded, Activated = props.onClaim,
			},
		},
		if props.premium
			then create "ImageLabel" {
				Name = "Crown", Image = Ui.Icons.Crown, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(34, 34),
				Rotation = 18, ZIndex = 10,
			}
			else nil,
		burstLayer,
	} :: Frame
end

-- The Pass tab ------------------------------------------------------------------------------------------------

local function stateOf(track: string, tier: number): Parts.TileState
	local pass = SeasonPassWindow.pass()
	local bit = 2 ^ (tier - 1)
	if bit32.btest(if track == "Free" then pass.free else pass.paid, bit) then
		return "claimed"
	end
	if SeasonPassWindow.active() and Formulas.seasonClaimable(pass, track, tier) then
		return "ready"
	end
	return "locked"
end

local function column(tier: number, spin: () -> number): Frame
	local function reached(): boolean
		return SeasonPassWindow.tier() >= tier
	end
	local function current(): boolean
		return SeasonPassWindow.tier() == tier
	end
	-- the tier plate: your tier is yellow and a bit bigger, reached tiers orange, the rest grey (decision 2026-11-16)
	local plateScale = spring(function()
		return if current() then 1.12 else 1
	end, 0.3, 0.5)
	local big = tier == MAX_TIER
	local function card(track: string, premium: boolean): Frame
		return rewardCard {
			reward = PassConfig[track][tier],
			premium = premium,
			big = big,
			spin = spin,
			state = function()
				return stateOf(track, tier)
			end,
			dimmed = function()
				return premium and not SeasonPassWindow.pass().premium
			end,
			next = function()
				return SeasonPassWindow.tier() + 1 == tier
			end,
			onClaim = function()
				Remotes.SeasonClaim:FireServer(track, tier)
			end,
		}
	end
	local free = card("Free", false)
	free.AnchorPoint = Vector2.new(0.5, 0)
	free.Position = UDim2.new(0.5, 0, 0, 44)
	free.Size = UDim2.new(1, -12, 0.5, -30)
	local premium = card("Premium", true)
	premium.AnchorPoint = Vector2.new(0.5, 0)
	premium.Position = UDim2.new(0.5, 0, 0.5, 22)
	premium.Size = UDim2.new(1, -12, 0.5, -30)

	return create "Frame" {
		Name = "Tier" .. tier,
		LayoutOrder = tier,
		Size = UDim2.new(0, COL, 1, 0),
		BackgroundTransparency = 1,
		Kit.plate {
			Name = "Plate",
			Color = function()
				return if current() then "Yellow" elseif reached() then "Orange" else "Gray"
			end,
			Text = `TIER {tier}`,
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(COL / 2, PILL_Y),
			Size = UDim2.new(1, -16, 0, 30),
			ZIndex = 4,
			create "UIScale" { Scale = plateScale },
		},
		free,
		premium,
	} :: Frame
end

-- The left labels: FREE (blue) and PREMIUM (gold, with a crown), lined up with the two rows.
local function trackLabel(text: string, palette: string, position: UDim2, icon: string?): Frame
	return create "Frame" {
		Name = text,
		Position = position,
		Size = UDim2.new(1, 0, 0.5, -30),
		BackgroundTransparency = 1,
		Kit.plate {
			Name = "Plate", Color = palette, Text = text, TextSize = if #text > 5 then 15 else 18,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.new(1, -10, 0, 34),
		},
		if icon
			then create "ImageLabel" {
				Name = "Icon", Image = icon, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28),
				Size = UDim2.fromOffset(50, 50), Rotation = -8,
			}
			else create "ImageLabel" {
				Name = "Icon", Image = Ui.Icons.Gift, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28),
				Size = UDim2.fromOffset(46, 46), Rotation = -8,
			},
	} :: Frame
end

local function topRow(scrollToTier: () -> ()): Frame
	local function info(): (number, number, number)
		return Formulas.seasonTier(SeasonPassWindow.pass().xp)
	end
	local badgePop = spring(function()
		return SeasonPassWindow.tier()
	end, 0.4, 0.35)
	return create "Frame" {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		-- the tier badge: a star with the tier number (tap: back to your tier on the track)
		create "ImageButton" {
			Name = "Badge", AutoButtonColor = false, BackgroundTransparency = 1, Image = Ui.Icons.Star,
			ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(-2, -3),
			Activated = scrollToTier,
			create "UIScale" {
				-- bounces when the tier goes up (the spring lags behind the new tier for a moment)
				Scale = function()
					local value = badgePop()
					return 1 + math.clamp(Vide.untrack(SeasonPassWindow.tier) - value, 0, 1) * 0.25
				end,
			},
			Kit.text {
				Name = "Tier", Text = function()
					return tostring(SeasonPassWindow.tier())
				end,
				TextSize = 26, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1), ZIndex = 2,
			},
		},
		Kit.text {
			Name = "Title",
			Text = function()
				local tier = SeasonPassWindow.tier()
				return if tier >= MAX_TIER then "MAX TIER!" else `TIER {tier}`
			end,
			TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(76, 0), Size = UDim2.new(1, -76 - 236, 0, 26),
		},
		Kit.bar {
			Label = function()
				local tier = info()
				return if tier >= MAX_TIER then "ALL REWARDS UNLOCKED" else `NEXT: TIER {tier + 1}`
			end,
			Right = function()
				local tier, into, need = info()
				return if tier >= MAX_TIER then "MAX" else `{into}/{need} XP`
			end,
			Value = function()
				local tier, into, need = info()
				return if tier >= MAX_TIER then 1 else into / need
			end,
			Palette = "Orange",
			Position = UDim2.fromOffset(76, 32),
			Size = UDim2.new(1, -76 - 236, 0, 30),
		},
		-- the season clock
		Kit.darkBox {
			Name = "Season",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(224, 64),
			Fill = C.Panel,
			Transparency = 0.15,
			Corner = 14,
			Kit.text {
				Name = "Name", Text = `SEASON {PassConfig.Season.Id}: {string.upper(PassConfig.Season.Name)}`,
				TextSize = 14, TextColor3 = C.Lemon, Gradient = false, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 18), ZIndex = 3,
			},
			create "ImageLabel" {
				Name = "Clock", Image = Ui.Icons.Clock, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(30, 43), Size = UDim2.fromOffset(34, 34), ZIndex = 3,
			},
			Kit.text {
				Name = "Time",
				Text = function()
					local now = State.now()
					if not SeasonPassWindow.active() then
						return if now < PassConfig.Season.StartsAt then "SOON" else "SEASON OVER"
					end
					return timeLeft(PassConfig.Season.EndsAt - now) .. " LEFT"
				end,
				TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 30), ZIndex = 3,
			},
		},
	} :: Frame
end

local function bottomRow(): Frame
	local function premium(): boolean
		return SeasonPassWindow.pass().premium
	end
	local function maxed(): boolean
		return SeasonPassWindow.tier() >= MAX_TIER
	end
	return create "Frame" {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		-- left: unlock Premium (or the Premium badge when you have it)
		Kit.button {
			Name = "Premium",
			Text = function()
				return productLabel("SeasonPremium", "PREMIUM  ")
			end,
			TextSize = 23,
			TextNudge = 22,
			Color = "Yellow",
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromOffset(250, 50),
			Visible = function()
				return not premium() and SeasonPassWindow.active()
			end,
			Activated = function()
				Remotes.ShopBuy:FireServer("Product", "SeasonPremium")
			end,
			create "ImageLabel" {
				Name = "NavIcon", Image = Ui.Icons.Crown, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 28, 0.5, -4), Size = UDim2.fromOffset(50, 50),
				Rotation = -10, ZIndex = 6,
			},
		},
		Kit.text {
			Name = "PremiumPitch",
			Text = "30 extra rewards and the\nGolden Schnitzel Griffin!",
			TextSize = 15, TextColor3 = C.Vanilla, Gradient = false, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(262, 4), Size = UDim2.new(0, 230, 1, -8),
			-- only while CLAIM ALL is hidden: the row is too narrow for all four
			Visible = function()
				return not premium() and SeasonPassWindow.active() and SeasonPassWindow.readyCount() <= 1
			end,
		},
		Kit.plate {
			Name = "PremiumActive",
			Color = "Yellow",
			Text = "PREMIUM ACTIVE",
			TextSize = 20,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromOffset(230, 38),
			Visible = premium,
		},
		-- right: +1 tier and claim all
		create "Frame" {
			Name = "Actions",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 400, 1, 0),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Kit.button {
				Name = "Skip",
				LayoutOrder = 1,
				Text = function()
					return productLabel("SeasonSkip", "+1 TIER  ")
				end,
				TextSize = 20,
				Color = "Blue",
				Size = UDim2.fromOffset(170, 50),
				Visible = function()
					return not maxed() and SeasonPassWindow.active()
				end,
				Activated = function()
					Remotes.ShopBuy:FireServer("Product", "SeasonSkip")
				end,
			},
			Kit.button {
				Name = "ClaimAll",
				LayoutOrder = 2,
				Text = function()
					return `CLAIM ALL ({SeasonPassWindow.readyCount()})`
				end,
				TextSize = 20,
				Color = "Green",
				Size = UDim2.fromOffset(190, 50),
				Visible = function()
					return SeasonPassWindow.readyCount() > 1
				end,
				Interactable = State.loaded,
				Activated = function()
					Remotes.SeasonClaim:FireServer("All")
				end,
			},
		},
	} :: Frame
end

local function passPage(anim: Motion.Anim): Frame
	-- one turning value for every claimable card's sunburst
	local spin = source(0)
	local spinValue = Instance.new("NumberValue")
	local spinTween = TweenService:Create(spinValue, TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Value = 360 })
	local spinConnection = spinValue.Changed:Connect(spin)
	Vide.effect(function()
		if anim.opened() then
			spinTween:Play()
		else
			spinTween:Pause()
		end
	end)
	Vide.cleanup(function()
		spinConnection:Disconnect()
		spinTween:Cancel()
		spinValue:Destroy()
	end)

	local scroller = create "ScrollingFrame" {
		Name = "Track",
		Position = UDim2.fromOffset(LABELS_W, 0),
		Size = UDim2.new(1, -LABELS_W, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Lemon,
		ScrollBarImageTransparency = 0.3,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		ClipsDescendants = true,
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		create "UIPadding" {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 8),
		},
	} :: ScrollingFrame

	-- the columns come in a few per frame after the window opened (Motion.reveal)
	local shownUpTo = Motion.reveal(anim.opened, SHOWN_AT_OPEN, MAX_TIER, REVEAL_DELAY, REVEAL_BATCH)
	for tier = 1, MAX_TIER do
		Kit.attach(scroller, column(tier, spin), function()
			return tier <= shownUpTo()
		end)
	end

	-- scroll to a tier (it becomes the second visible column)
	local scrollTween: Tween? = nil
	local function scrollTo(tier: number, instant: boolean?)
		local target = Vector2.new(math.max(0, (tier - 2) * COL), 0)
		if scrollTween then
			scrollTween:Cancel()
		end
		if instant then
			scroller.CanvasPosition = target
			return
		end
		scrollTween = TweenService:Create(scroller, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CanvasPosition = target })
		scrollTween:Play()
	end
	-- the tier to show: the first reward to claim, else your tier
	local function focusTier(): number
		local pass = SeasonPassWindow.pass()
		local tier = Formulas.seasonTier(pass.xp)
		if SeasonPassWindow.active() then
			for t = 1, tier do
				if Formulas.seasonClaimable(pass, "Free", t) or Formulas.seasonClaimable(pass, "Premium", t) then
					return t
				end
			end
		end
		return tier
	end
	Vide.effect(function()
		if anim.opened() then
			scroller.CanvasPosition = Vector2.zero
			task.delay(REVEAL_DELAY + 0.3, function()
				if Vide.untrack(anim.opened) then
					scrollTo(Vide.untrack(focusTier))
				end
			end)
		end
	end)

	return create "Frame" {
		Name = "PassPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		topRow(function()
			scrollTo(Vide.untrack(SeasonPassWindow.tier))
		end),
		Kit.darkBox {
			Name = "TrackBox",
			Position = UDim2.fromOffset(0, 76),
			Size = UDim2.new(1, 0, 1, -76 - 64),
			Corner = 12,
			create "Frame" {
				Name = "Content",
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 1, -12),
				BackgroundTransparency = 1,
				create "Frame" {
					Name = "Labels",
					Size = UDim2.new(0, LABELS_W, 1, 0),
					BackgroundTransparency = 1,
					trackLabel("FREE", "Blue", UDim2.fromOffset(0, 44)),
					trackLabel("PREMIUM", "Yellow", UDim2.new(0, 0, 0.5, 22), Ui.Icons.Crown),
				},
				scroller,
			},
		},
		bottomRow(),
	} :: Frame
end

-- The Earn XP tab ---------------------------------------------------------------------------------------------

-- One XP source as a candy card (the Daily Rewards / Shop look, decision 2026-11-16): the palette's gradient,
-- a still sunburst, the big sticker, "+5 XP" on top, the name and what earns it below; a capped source shows
-- today's progress in place of the description.
local function xpCard(spec: {
	order: number,
	icon: string,
	color: string,
	title: string,
	sub: string,
	amount: string,
	today: (() -> (number, number))?,
	appear: () -> number,
}): Frame
	local palette = Theme.Palettes[spec.color]
	local hovered = source(false)
	local hover = spring(function()
		return if hovered() then 1 else 0
	end, 0.25, 0.6)
	local iconY = 0.44
	return create "Frame" {
		Name = spec.title,
		LayoutOrder = spec.order,
		BackgroundTransparency = 1,
		Kit.darkBox {
			Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(0.5, 0, 0.5, (1 - spec.appear()) * 40)
			end,
			Size = UDim2.fromScale(1, 1), Fill = C.White, Transparency = 0, Active = true, Line = palette.light,
			MouseEnter = function()
				hovered(true)
			end,
			MouseLeave = function()
				hovered(false)
			end,
			create "UIScale" {
				Scale = function()
					return math.max(0, spec.appear()) * (1 + hover() * 0.04)
				end,
			},
			Parts.gradient(function()
				return palette
			end),
			Kit.weld(palette.light, 0.88),
			create "Frame" {
				Name = "Effects", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2,
				create "ImageLabel" {
					Name = "Sunburst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
					Size = UDim2.fromScale(2, 2), SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundTransparency = 1, Image = Ui.Textures.Sunburst, ImageColor3 = palette.light,
					ImageTransparency = 0.6, Rotation = 12, ZIndex = 2,
				},
			},
			create "ImageLabel" {
				Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
				Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1, Image = Ui.Textures.Soft, ImageColor3 = palette.light, ImageTransparency = 0.45,
				ZIndex = 3,
			},
			create "ImageLabel" {
				Name = "Sticker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, iconY),
				Size = UDim2.fromScale(0.42, 0.42), SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1, Image = spec.icon, ScaleType = Enum.ScaleType.Fit, Rotation = -6, ZIndex = 4,
				create "UIScale" {
					Scale = function()
						return 1 + hover() * 0.12
					end,
				},
			},
			Kit.text {
				Name = "Amount", Text = spec.amount, TextSize = 26, TextColor3 = C.Lemon,
				Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), ZIndex = 6,
			},
			Kit.text {
				Name = "Title", Text = spec.title, TextSize = 20,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32), Size = UDim2.new(1, -10, 0, 24),
				ZIndex = 6,
			},
			if spec.today
				then Kit.bar {
					Label = "TODAY",
					Right = function()
						local value, cap = (spec.today :: () -> (number, number))()
						return `{value}/{cap}`
					end,
					Value = function()
						local value, cap = (spec.today :: () -> (number, number))()
						return value / cap
					end,
					Palette = "Green",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -7),
					Size = UDim2.new(1, -16, 0, 24),
					ZIndex = 6,
				}
				else Kit.text {
					Name = "Sub", Text = spec.sub, TextSize = 15, TextColor3 = C.Vanilla, Gradient = false,
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -10, 0, 20),
					ZIndex = 6,
				},
		},
	} :: Frame
end

local function xpPage(anim: Motion.Anim): Frame
	local Xp = PassConfig.Xp
	-- today's XP from a capped source (it restarts every UTC day)
	local function capped(key: string, cap: number): () -> (number, number)
		return function()
			local pass = SeasonPassWindow.pass()
			local today = Formulas.rewardDay(State.now())
			return if pass.day == today then math.min(pass[key], cap) else 0, cap
		end
	end
	local specs = {
		{ icon = Ui.Icons.Schnitzel, color = "Orange", title = "Play", sub = "Every minute", amount = `+{Xp.Play} XP` },
		{ icon = Ui.Icons.MergeOvens, color = "Green", title = "Merge Ovens", sub = "Every merge", amount = `+{Xp.Merge.Amount} XP`, today = capped("merges", Xp.Merge.DailyCap) },
		{ icon = Ui.Icons.Gift, color = "Blue", title = "Daily Reward", sub = "Once a day", amount = `+{Xp.Daily} XP` },
		{ icon = Ui.Icons.Clock, color = "Pink", title = "Playtime Gifts", sub = "Every gift", amount = `+{Xp.Gift} XP` },
		{ icon = Ui.Icons.Egg, color = "Purple", title = "Hatch Pets", sub = "Every pet", amount = `+{Xp.Egg.Amount} XP`, today = capped("eggs", Xp.Egg.DailyCap) },
		{ icon = Ui.Icons.Rebirth, color = "Yellow", title = "Rebirth", sub = "Every rebirth", amount = `+{Xp.Rebirth} XP` },
	}
	local cards = {}
	for index, spec in specs do
		spec.order = index
		spec.appear = anim.stagger(index, #specs)
		table.insert(cards, xpCard(spec :: any))
	end
	return create "Frame" {
		Name = "XpPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		create "Frame" {
			Name = "Cards",
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 1, -4 - 30),
			BackgroundTransparency = 1,
			create "UIGridLayout" {
				CellSize = UDim2.new(1 / 3, -9, 0.5, -7),
				CellPadding = UDim2.fromOffset(13, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			cards,
		},
		Kit.text {
			Text = "Daily limits restart every day. Claim your rewards before the season ends!",
			TextSize = 14,
			TextColor3 = C.Muted,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 22),
		},
	} :: Frame
end

-- The window ------------------------------------------------------------------------------------------------

function SeasonPassWindow.render(anim: Motion.Anim)
	local tab = source("Pass")
	local wasOpen = false
	Vide.effect(function()
		local open = State.window() == "SeasonPass"
		if open and not wasOpen then
			tab("Pass")
		end
		wasOpen = open
	end)

	local function tabButton(order: number, name: string, icon: string, color: string, notice: (() -> boolean)?)
		return Kit.button {
			Name = name,
			LayoutOrder = order,
			Icon = icon,
			IconSize = 0.85,
			Color = color,
			Shine = false,
			Size = UDim2.fromOffset(60, 60),
			Selected = function()
				return tab() == name
			end,
			Activated = function()
				tab(name)
			end,
			if notice
				then create "Frame" {
					Name = "Notice",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = C.Bad,
					Visible = notice,
					ZIndex = 9,
					create "UICorner" { CornerRadius = UDim.new(1, 0) },
					create "UIStroke" { Color = C.Ink, Thickness = 2 },
					Kit.text { Text = "!", TextSize = 18, Size = UDim2.fromScale(1, 1), ZIndex = 10 },
				}
				else nil,
		}
	end

	return Kit.window {
		Name = "SeasonPass",
		Title = function()
			return if tab() == "Xp" then "Earn Pass XP" else "Schnitzel Pass"
		end,
		Icon = function()
			return if tab() == "Xp" then Ui.Icons.PassXp else Ui.Icons.SeasonPass
		end,
		Color = function()
			return if tab() == "Xp" then "Blue" else "Orange"
		end,
		Anim = anim,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(520))
		end,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = {
			tabButton(1, "Pass", Ui.Icons.SeasonPass, "Orange", function()
				return SeasonPassWindow.readyCount() > 0
			end),
			tabButton(2, "Xp", Ui.Icons.PassXp, "Blue"),
		},
		Body = {
			Kit.tabPage(passPage(anim), function()
				return tab() == "Pass"
			end),
			Kit.tabPage(xpPage(anim), function()
				return tab() == "Xp"
			end),
		},
	}
end

return SeasonPassWindow
