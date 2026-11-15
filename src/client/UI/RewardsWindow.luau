-- Rewards window (GDD 8): daily rewards and playtime gifts as two tabs of one window, opened from the
-- TopbarPlus "Rewards" icon (Controllers/RewardsController). It opens on the tab that has something to claim.
-- Same layout as the EggDrop game's Daily Rewards window (UI/RewardParts.tile cards):
--   Daily: streak bar + clock on top, Days 1 to 6 in a 3 × 2 grid on the left, the big purple Day 7 (crown) on the right.
--     Today's card pulses and glows with the CLAIM button; the check stamps on when claimed; tomorrow's card counts down.
--   Gifts: today's playtime bar + the next gift's timer on top, the 6 gifts in a 3 × 2 grid (CLAIM when open).
-- The numbers live in Config.Rewards, the state rules in Formulas.dailyStatus / playtimeStatus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local C = Theme.Colors

local Rewards = Config.Rewards
local DAYS = #Rewards.Daily
local GIFTS = #Rewards.Playtime
local MEGA_WIDTH = 226
local TIMER_WIDTH = 226

local RewardsWindow = {}

-- "5h 12m" for long waits, "4:07" for short ones (TopbarPlus label)
function RewardsWindow.duration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return `{seconds // 3600}h {(seconds % 3600) // 60}m`
	end
	return Parts.short(seconds)
end

function RewardsWindow.today(): number
	return Formulas.rewardDay(State.now())
end

-- Can you claim now, and which day (1..7) is next.
function RewardsWindow.dailyStatus(): (boolean, number)
	return Formulas.dailyStatus(State.daily(), RewardsWindow.today())
end

-- How many gifts are ready, and seconds until the next one opens (nil when all are open today).
function RewardsWindow.giftStatus(): (number, number?)
	local ready, nextIndex, remaining = Formulas.playtimeStatus(State.playtime(), RewardsWindow.today())
	return ready, if nextIndex then remaining else nil
end

-- The reward's name under the sticker: money follows your current income.
local function title(reward: any): string | () -> string
	if reward.Kind == "Pet" then
		return Config.Pets.List[reward.Pet].Name
	elseif reward.Kind == "Tickets" then
		return if reward.Amount == 1 then "1 Aura Ticket" else `{reward.Amount} Aura Tickets`
	end
	return function()
		State.money() -- refresh as income changes
		return NumberFormat.money(Formulas.rewardMoney(State.data(), reward.Minutes))
	end
end

local function titleColor(reward: any): Color3
	if reward.Kind == "Pet" then
		return Config.Pets.Rarities[Config.Pets.List[reward.Pet].Rarity].Color:Lerp(C.White, 0.4)
	end
	return if reward.Kind == "Tickets" then C.Lemon else C.Money
end

local function claimButton(big: boolean, visible: () -> boolean, activated: () -> ()): ImageButton
	return Kit.button {
		Name = "Claim",
		Text = "CLAIM!",
		Color = "Green",
		TextSize = if big then 26 else 20,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, if big then 44 else 34),
		ZIndex = 8,
		Visible = visible,
		Interactable = State.loaded,
		Activated = activated,
	}
end

-- Top row: a progress bar on the left, a clock box on the right.
local function topRow(
	bar: { [string]: any },
	time: () -> string,
	timeColor: () -> Color3,
	ringing: () -> boolean
): Frame
	local beat = Parts.wave(1)
	bar.Position = UDim2.fromOffset(0, 3)
	bar.Size = UDim2.new(1, -TIMER_WIDTH - 14, 0, 30)
	return create "Frame" {
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Kit.bar(bar :: any),
		Kit.darkBox {
			Name = "Timer",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(TIMER_WIDTH, 36),
			Fill = C.Panel,
			Transparency = 0.15,
			Corner = 18,
			create "ImageLabel" {
				Name = "Clock",
				Image = Ui.Icons.Clock,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(20, 18),
				Size = UDim2.fromOffset(40, 40),
				ZIndex = 3,
				Rotation = function()
					return if ringing() then (beat() - 0.5) * 30 else 0
				end,
			},
			Kit.text {
				Name = "Time",
				TextSize = 21,
				Position = UDim2.fromOffset(40, 0),
				Size = UDim2.new(1, -48, 1, 0),
				ZIndex = 3,
				Text = time,
				TextColor3 = timeColor,
			},
		},
	} :: Frame
end

local function footnote(text: string): TextLabel
	return Kit.text {
		Text = text,
		TextSize = 14,
		TextColor3 = C.Muted,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
	}
end

local function grid(): UIGridLayout
	return create "UIGridLayout" {
		CellSize = UDim2.new(1 / 3, -9, 0.5, -7),
		CellPadding = UDim2.fromOffset(13, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	} :: UIGridLayout
end

-- Daily ---------------------------------------------------------------------------------------------------

local function dailyPage(anim: Motion.Anim, visible: () -> boolean): Frame
	local function stateOf(day: number): Parts.TileState
		local canClaim, nextDay = RewardsWindow.dailyStatus()
		if canClaim then
			return if day == nextDay then "ready" elseif day < nextDay then "claimed" else "locked"
		end
		return if day <= State.daily().streak then "claimed" else "locked"
	end
	-- days claimed in a row
	local function streak(): number
		local canClaim, nextDay = RewardsWindow.dailyStatus()
		return if canClaim then nextDay - 1 else State.daily().streak
	end
	-- tomorrow's day (already claimed today): its card counts down
	local function tomorrow(): number?
		local canClaim, nextDay = RewardsWindow.dailyStatus()
		return if canClaim then nil else nextDay
	end
	local function ready(): boolean
		return (RewardsWindow.dailyStatus())
	end
	local function untilTomorrow(): number
		return Formulas.secondsToNextDay(State.now())
	end
	local beat = Parts.wave(1)

	local function tile(day: number)
		local reward = Rewards.Daily[day]
		local big = day == DAYS
		local function state()
			return stateOf(day)
		end
		local base = if big then "Purple" else "Blue"
		return Parts.tile {
			Name = "Day" .. day,
			LayoutOrder = day,
			Big = big,
			Phase = day * 0.31,
			Color = function()
				return if state() == "ready" then "Yellow" else base
			end,
			Header = "DAY " .. day,
			Icon = Parts.icon(reward),
			Amount = Parts.amount(reward),
			Title = title(reward),
			TitleColor = titleColor(reward),
			Price = function()
				return if tomorrow() == day then "IN " .. Parts.time(untilTomorrow()) else ""
			end,
			PriceColor = C.Lemon,
			TitleVisible = function()
				return state() ~= "ready"
			end,
			State = state,
			Appear = anim.stagger(day, DAYS),
			Footer = claimButton(big, function()
				return state() == "ready"
			end, function()
				Remotes.ClaimDaily:FireServer()
			end),
			Children = if big
				then {
					Kit.text {
						Name = "Mega",
						Text = "MEGA REWARD!",
						TextSize = 17,
						TextColor3 = C.Lemon,
						Position = UDim2.fromOffset(0, 38),
						Size = UDim2.new(1, 0, 0, 20),
						ZIndex = 6,
					},
					create "ImageLabel" {
						Name = "Crown",
						Image = Ui.Icons.Crown,
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(14, 6),
						Size = UDim2.fromOffset(54, 54),
						ZIndex = 9,
						Rotation = function()
							return -22 + beat() * 10
						end,
					},
				}
				else nil,
		}
	end

	local week = {}
	for day = 1, DAYS - 1 do
		table.insert(week, tile(day))
	end

	return create "Frame" {
		Name = "DailyPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		topRow({
			Label = "STREAK",
			Right = function()
				return `{streak()}/{DAYS}`
			end,
			Value = function()
				return streak() / DAYS
			end,
			Palette = "Yellow",
		}, function()
			return if ready() then "READY!" else Parts.time(untilTomorrow())
		end, function()
			return if ready() then C.Money else C.White
		end, ready),
		create "Frame" {
			Name = "Days",
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 1, -50 - 28),
			BackgroundTransparency = 1,
			create "Frame" {
				Name = "Week",
				Size = UDim2.new(1, -MEGA_WIDTH - 14, 1, 0),
				BackgroundTransparency = 1,
				grid(),
				week,
			},
			create "Frame" {
				Name = "Mega",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, MEGA_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				tile(DAYS),
			},
		},
		footnote("Come back every day! Miss a day and the streak restarts."),
	} :: Frame
end

-- Playtime gifts ------------------------------------------------------------------------------------------

local function playtimeToday(): (number, number)
	local playtime = State.playtime()
	if playtime.day ~= RewardsWindow.today() then
		return 0, 0
	end
	return playtime.seconds, playtime.claimed
end

local function giftsPage(anim: Motion.Anim, visible: () -> boolean): Frame
	local lastMinutes = Rewards.Playtime[GIFTS].Minutes
	local function anyReady(): boolean
		return (RewardsWindow.giftStatus()) > 0
	end

	local tiles = {}
	for index, gift in Rewards.Playtime do
		local needed = gift.Minutes * 60
		local bit = 2 ^ (index - 1)
		local function state(): Parts.TileState
			local seconds, claimed = playtimeToday()
			if bit32.btest(claimed, bit) then
				return "claimed"
			end
			return if seconds >= needed then "ready" else "locked"
		end
		table.insert(
			tiles,
			Parts.tile {
				Name = "Gift" .. index,
				LayoutOrder = index,
				Phase = index * 0.31,
				Color = function()
					return if state() == "ready" then "Yellow" else "Pink"
				end,
				Header = `{gift.Minutes} MIN`,
				Icon = Parts.icon(gift.Reward),
				Amount = Parts.amount(gift.Reward),
				Title = title(gift.Reward),
				TitleColor = titleColor(gift.Reward),
				Price = function()
					if state() ~= "locked" then
						return ""
					end
					local seconds = playtimeToday()
					return "IN " .. Parts.short(needed - seconds)
				end,
				PriceColor = C.Lemon,
				TitleVisible = function()
					return state() ~= "ready"
				end,
				State = state,
				Appear = anim.stagger(index, GIFTS),
				Footer = claimButton(false, function()
					return state() == "ready"
				end, function()
					Remotes.ClaimPlaytime:FireServer(index)
				end),
			}
		)
	end

	return create "Frame" {
		Name = "GiftsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		topRow({
			Label = "PLAYED TODAY",
			Right = function()
				local seconds = playtimeToday()
				return `{math.min(seconds // 60, lastMinutes)}/{lastMinutes} MIN`
			end,
			Value = function()
				local seconds = playtimeToday()
				return math.min(seconds / (lastMinutes * 60), 1)
			end,
			Palette = "Pink",
		}, function()
			local ready, remaining = RewardsWindow.giftStatus()
			if ready > 0 then
				return "READY!"
			end
			return if remaining then Parts.short(remaining) else "ALL DONE!"
		end, function()
			return if anyReady() then C.Money else C.White
		end, anyReady),
		create "Frame" {
			Name = "Gifts",
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 1, -50 - 28),
			BackgroundTransparency = 1,
			grid(),
			tiles,
		},
		footnote("Gifts open as you play and reset every day."),
	} :: Frame
end

-- The window -----------------------------------------------------------------------------------------------

-- Is there anything to claim (the TopbarPlus icon's notice)?
function RewardsWindow.anyReady(): boolean
	return (RewardsWindow.dailyStatus()) or (RewardsWindow.giftStatus()) > 0
end

-- The tab to open on: the one with something to claim (daily first).
local function bestTab(): string
	if RewardsWindow.dailyStatus() then
		return "Daily"
	end
	return if (RewardsWindow.giftStatus()) > 0 then "Gifts" else "Daily"
end

function RewardsWindow.render(anim: Motion.Anim)
	local tab = Vide.source(Vide.untrack(bestTab))
	-- every time the window opens, jump to the tab that has something to claim
	local wasOpen = false
	Vide.effect(function()
		local open = State.window() == "Rewards"
		if open and not wasOpen then
			tab(Vide.untrack(bestTab))
		end
		wasOpen = open
	end)

	local function tabButton(order: number, name: string, icon: string, color: string, ready: () -> boolean)
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
			-- red "!" while this tab has something to claim
			create "Frame" {
				Name = "Notice",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = C.Bad,
				Visible = ready,
				ZIndex = 9,
				create "UICorner" { CornerRadius = UDim.new(1, 0) },
				create "UIStroke" { Color = C.Ink, Thickness = 2 },
				Kit.text {
					Text = "!",
					TextSize = 18,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 10,
				},
			},
		}
	end

	return Kit.window {
		Name = "Rewards",
		Title = function()
			return if tab() == "Gifts" then "Playtime Gifts" else "Daily Rewards"
		end,
		-- the header follows the tab, like the tab buttons: blue + gift for Daily, pink + clock for Gifts
		Icon = function()
			return if tab() == "Gifts" then Ui.Icons.Clock else Ui.Icons.Gift
		end,
		Color = function()
			return if tab() == "Gifts" then "Pink" else "Blue"
		end,
		Anim = anim,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(500))
		end,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = {
			tabButton(1, "Daily", Ui.Icons.Gift, "Blue", function()
				return (RewardsWindow.dailyStatus())
			end),
			tabButton(2, "Gifts", Ui.Icons.Clock, "Pink", function()
				return (RewardsWindow.giftStatus()) > 0
			end),
		},
		Body = {
			dailyPage(anim, function()
				return tab() == "Daily"
			end),
			giftsPage(anim, function()
				return tab() == "Gifts"
			end),
		},
	}
end

return RewardsWindow
