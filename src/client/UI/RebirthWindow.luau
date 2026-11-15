-- Rebirth window (GDD 3.8, 9.4). Two tabs: Rebirth (requirement, rewards, what resets / stays, the button)
-- and the Rebirth Tree (permanent perks for Rebirth Tokens).
-- The button is two-step: the first tap asks "Sure?", the second sends Remotes.RequestRebirth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local ShopWindow = require(script.Parent.ShopWindow)

local create = Vide.create
local source = Vide.source

local C = Theme.Colors
local Tree = Config.Rebirth.Tree

local RebirthWindow = {}

-- Progress towards the next rebirth (0..1).
function RebirthWindow.progress(): number
	return math.clamp(State.earned() / Formulas.rebirthRequirement(State.rebirths()), 0, 1)
end

local function ready(): boolean
	return State.earned() >= Formulas.rebirthRequirement(State.rebirths())
end

local function perkValueText(perk: string, level: number): string
	local definition = Tree.Perks[perk]
	if perk == "StartMoney" then
		return `x{NumberFormat.short(definition.Step ^ level)}`
	elseif perk == "Money" or perk == "OfflineRate" then
		return `+{math.floor(definition.Step * level * 100 + 0.5)}%`
	elseif perk == "OfflineTime" then
		return `+{math.floor(definition.Step * level / 3600)}h`
	end
	return `+{definition.Step * level}`
end

type Reward = { icon: string, value: string, label: string, sub: string, color: Color3 }

-- The rewards of the next rebirth, one tile each.
local function rewards(rebirths: number, tokens: number): { Reward }
	local upcoming = rebirths + 1
	local list: { Reward } = {
		{
			icon = Ui.Icons.RebirthCash,
			value = `x{Formulas.rebirthMultiplier(upcoming)}`,
			label = "Money",
			sub = `now x{Formulas.rebirthMultiplier(rebirths)}`,
			color = C.Money,
		},
		{
			icon = Ui.Icons.RebirthToken,
			value = `+{Config.Rebirth.TokensPerRebirth}`,
			label = `Rebirth Token{if Config.Rebirth.TokensPerRebirth == 1 then "" else "s"}`,
			sub = `you have {tokens}`,
			color = Theme.Palettes.Purple.light,
		},
	}
	local slotsNow, slotsNext = Formulas.rebirthSlots(rebirths), Formulas.rebirthSlots(upcoming)
	if slotsNext > slotsNow then
		table.insert(list, {
			icon = Ui.Icons.OvenSlots,
			value = `+{slotsNext - slotsNow}`,
			label = "Oven Slots",
			sub = `{slotsNow} → {slotsNext}`,
			color = C.Lemon,
		})
	end
	local chefsNow, chefsNext = Formulas.maxChefs(rebirths), Formulas.maxChefs(upcoming)
	if chefsNext > chefsNow then
		table.insert(list, {
			icon = Ui.Icons.Friends,
			value = `+{chefsNext - chefsNow}`,
			label = "Max Chefs",
			sub = `{chefsNow} → {chefsNext}`,
			color = Theme.Palettes.Blue.light,
		})
	end
	local soon = Config.Rebirth.ComingSoon[upcoming]
		or (if upcoming % Config.Rebirth.WorldEvery == 0 then "New world" else nil)
	if soon then
		table.insert(list, { icon = Ui.Icons.Crown, value = "NEW", label = soon, sub = "coming soon", color = C.Vanilla })
	end
	return list
end

local MAX_REWARDS = 5

-- A reward tile: glowing icon, big value, what it is, and the before → after line.
local function rewardTile(index: number): Frame
	local function entry(): Reward?
		return rewards(State.rebirths(), State.tokens())[index]
	end
	local function color(): Color3
		local e = entry()
		return if e then e.color else C.CardLine
	end
	local function field(key: string): () -> string
		return function()
			local e = entry()
			return if e then (e :: any)[key] else ""
		end
	end
	return Kit.darkBox {
		Name = "Reward" .. index,
		LayoutOrder = index,
		-- the visible tiles share the full width
		Size = function()
			local count = math.max(1, #rewards(State.rebirths(), State.tokens()))
			return UDim2.new(1 / count, -10 * (count - 1) / count, 1, 0)
		end,
		Line = color,
		Visible = function()
			return entry() ~= nil
		end,
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.new(1, 10, 0.55, 0),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ImageColor3 = color,
			ImageTransparency = 0.6,
		},
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.42, 0.42),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Image = field("icon"),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		},
		Kit.text {
			Name = "Value",
			Text = field("value"),
			TextSize = 30,
			StrokeThickness = 3,
			TextColor3 = color,
			Gradient = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -42),
			Size = UDim2.new(1, -8, 0, 32),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Label",
			Text = field("label"),
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Sub",
			Text = field("sub"),
			TextSize = 14,
			TextColor3 = C.Muted,
			Gradient = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -7),
			Size = UDim2.new(1, -8, 0, 16),
			ZIndex = 3,
		},
	} :: Frame
end

-- "Resets" / "Keeps" box: coloured title and a wrapped list.
local function rulesBox(order: number, title: string, color: Color3, text: string | () -> string): Frame
	return Kit.darkBox {
		Name = title,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -5, 1, 0),
		Line = color,
		create "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
			create "UIPadding" {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 6),
			},
			Kit.text {
				Name = "Title",
				Text = title,
				TextSize = 18,
				TextColor3 = color,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 22),
				ZIndex = 3,
			},
			Kit.text {
				Name = "List",
				Text = text,
				TextSize = 14,
				TextWrapped = true,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 1, -28),
				ZIndex = 3,
			},
		},
	} :: Frame
end

local RULES_H = 70
local BUTTON_H = 70
local SKIP_W = 190 -- the Rebirth Skip button next to REBIRTH

local function rebirthPage(visible: () -> boolean, anim: Motion.Anim): Frame
	local confirming = source(false)
	Vide.effect(function()
		if not anim.opened() then
			confirming(false)
		end
	end)
	local tiles = {}
	for i = 1, MAX_REWARDS do
		table.insert(tiles, rewardTile(i))
	end
	local function skipReady(): boolean
		return Formulas.rebirthSkipReady({ cycleEarned = State.earned(), rebirths = State.rebirths() })
	end
	local skipTipEvents, skipTip = Kit.tooltip {
		Title = "Rebirth Skip",
		Color = Theme.Palettes.Purple.light,
		Text = function()
			local min = math.floor(Config.Shop.RebirthSkip.MinProgress * 100 + 0.5)
			return `Get the rebirth reward now and KEEP your ovens and money.\nFrom {min}% progress.`
		end,
		AlignX = 1,
	}
	return create "Frame" {
		Name = "RebirthPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		-- requirement
		Kit.text {
			Name = "Requirement",
			Text = "Earn money this run",
			TextSize = 20,
			TextColor3 = C.Muted,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 22),
		},
		Kit.bar {
			Name = "Progress",
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 30),
			Palette = function()
				return if ready() then "Green" else "Yellow"
			end,
			Label = function()
				return `{NumberFormat.money(State.earned())} / {NumberFormat.money(Formulas.rebirthRequirement(State.rebirths()))}`
			end,
			Right = function()
				return `{math.floor(RebirthWindow.progress() * 100)}%`
			end,
			Value = RebirthWindow.progress,
		},
		-- rewards
		Kit.text {
			Name = "RewardsTitle",
			Text = "REWARDS",
			TextSize = 22,
			TextColor3 = C.Lemon,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 0, 24),
		},
		create "Frame" {
			Name = "Rewards",
			Position = UDim2.fromOffset(0, 92),
			Size = UDim2.new(1, 0, 1, -92 - RULES_H - BUTTON_H - 10),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			tiles,
		},
		-- what resets / what stays
		create "Frame" {
			Name = "Rules",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -BUTTON_H),
			Size = UDim2.new(1, 0, 0, RULES_H),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			rulesBox(1, "RESETS", C.Bad, "Money, ovens, stars, chefs, generation, sell speed, counter"),
			rulesBox(2, "KEEPS", C.Good, function()
				return `Tokens ({State.tokens()}), slots, pets, auras, Index, perks`
			end),
		},
		-- GDD 6.3 Rebirth Skip (Robux, decision 2026-11-15): the rebirth reward WITHOUT the reset (ovens, money and
		-- generation stay), from MinProgress of the requirement; the price follows the next rebirth's number.
		create "Frame" {
			Name = "Skip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, -4),
			Size = UDim2.fromOffset(SKIP_W, 56),
			BackgroundTransparency = 1,
			skipTipEvents,
			skipTip,
			Kit.button {
				Name = "SkipButton",
				Size = UDim2.fromScale(1, 1),
				TextSize = 20,
				Bounce = 0.4,
				Color = function()
					return if skipReady() then "Purple" else "Gray"
				end,
				Text = function()
					return `SKIP · R$ {ShopWindow.productPrice(Formulas.rebirthSkipProduct(State.rebirths()))}`
				end,
				Activated = function()
					if skipReady() then
						Remotes.ShopBuy:FireServer("Product", Formulas.rebirthSkipProduct(State.rebirths()))
					else
						Audio.play("Error")
					end
				end,
			},
		},
		Kit.button {
			Name = "RebirthButton",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -4),
			Size = UDim2.new(1, -SKIP_W - 10, 0, 56), -- the rest of the width, next to the Skip button
			TextSize = 32,
			Bounce = 0.25, -- a full-width button only bounces a little, so it stays inside the window
			Color = function()
				if not ready() then
					return "Gray"
				end
				return if confirming() then "Red" else "Green"
			end,
			Text = function()
				if not ready() then
					local missing = Formulas.rebirthRequirement(State.rebirths()) - State.earned()
					return `{NumberFormat.money(missing)} more`
				end
				return if confirming() then "Sure? Tap again!" else "REBIRTH!"
			end,
			Activated = function()
				if not ready() then
					Audio.play("Error")
					return
				end
				if confirming() then
					confirming(false)
					State.close()
					Remotes.RequestRebirth:FireServer()
				else
					confirming(true)
					task.delay(3, function()
						confirming(false)
					end)
				end
			end,
		},
	} :: Frame
end

local function perkRow(order: number, perk: string): Frame
	local definition = Tree.Perks[perk]
	local function level(): number
		return State.perks()[perk] or 0
	end
	local function maxed(): boolean
		return level() >= definition.Max
	end
	local function canBuy(): boolean
		return not maxed() and State.tokens() >= Tree.TokenCost
	end
	local pips = {}
	for i = 1, definition.Max do
		table.insert(pips, create "Frame" {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = function()
				return if level() >= i then C.Lemon else C.Ink
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			Kit.outline(nil, 2),
		})
	end
	return Kit.darkBox {
		Name = perk,
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 62),
		Line = function()
			return if canBuy() then C.CardSelectedLine else C.CardLine
		end,
		Kit.text {
			Name = "Title",
			Text = definition.Name,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.4, 0, 0, 26),
		},
		create "Frame" {
			Name = "Pips",
			Position = UDim2.new(0.4, 0, 0, 12),
			Size = UDim2.fromOffset(120, 14),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			pips,
		},
		Kit.text {
			Name = "Effect",
			RichText = true,
			Text = function()
				local now = perkValueText(perk, level())
				if maxed() then
					return `{definition.Description}  <font color="#5EEB5B">{now} (MAX)</font>`
				end
				return `{definition.Description}  <font color="#5EEB5B">{now} » {perkValueText(perk, level() + 1)}</font>`
			end,
			TextSize = 16,
			TextColor3 = C.Muted,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -190, 0, 20),
		},
		Kit.button {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -1),
			Size = UDim2.fromOffset(150, 42),
			TextSize = 19,
			Color = function()
				if maxed() then
					return "Gray"
				end
				return if canBuy() then "Yellow" else "Gray"
			end,
			Text = function()
				if maxed() then
					return "MAX"
				end
				return tostring(Tree.TokenCost)
			end,
			InlineIcon = function()
				return if maxed() then "" else Ui.Icons.RebirthToken
			end,
			Activated = function()
				if canBuy() then
					Audio.play("Chime")
					Remotes.BuyPerk:FireServer(perk)
				else
					Audio.play("Error")
				end
			end,
		},
	} :: Frame
end

local TOKENS_H = 36

local function treePage(visible: () -> boolean): Frame
	local rows = {}
	for order, perk in Tree.Order do
		table.insert(rows, perkRow(order, perk))
	end
	return create "Frame" {
		Name = "TreePage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		-- token balance: the token icon and the count
		create "Frame" {
			Name = "Tokens",
			Size = UDim2.new(1, 0, 0, TOKENS_H),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			create "ImageLabel" {
				Name = "TokenIcon",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(TOKENS_H, TOKENS_H),
				BackgroundTransparency = 1,
				Image = Ui.Icons.RebirthToken,
				ScaleType = Enum.ScaleType.Fit,
			},
			Kit.text {
				Name = "Count",
				LayoutOrder = 2,
				Text = function()
					return tostring(State.tokens())
				end,
				TextSize = 30,
				StrokeThickness = 3,
				Gradient = ColorSequence.new(Theme.Palettes.Yellow.light, Theme.Palettes.Yellow.bottom),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, TOKENS_H),
			},
			Kit.text {
				Name = "Label",
				LayoutOrder = 3,
				Text = function()
					return `Rebirth Token{if State.tokens() == 1 then "" else "s"}`
				end,
				TextSize = 18,
				TextColor3 = C.Muted,
				Gradient = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, TOKENS_H),
			},
		},
		create "ScrollingFrame" {
			Name = "Perks",
			Position = UDim2.fromOffset(0, TOKENS_H + 6),
			Size = UDim2.new(1, 0, 1, -(TOKENS_H + 6)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0, -- scrolls by drag / wheel, the bar itself is not drawn
			ScrollBarImageTransparency = 1,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			create "UIListLayout" {
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			create "UIPadding" { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6) },
			rows,
		},
	} :: Frame
end

function RebirthWindow.render(anim: Motion.Anim)
	local tab = source("Rebirth")
	local function tabButton(order: number, name: string, icon: string)
		return Kit.button {
			Name = name,
			LayoutOrder = order,
			Icon = icon,
			IconSize = 0.85,
			Color = "Green",
			Shine = false,
			Size = UDim2.fromOffset(60, 60),
			Selected = function()
				return tab() == name
			end,
			Activated = function()
				tab(name)
			end,
		}
	end
	return Kit.window {
		Name = "Rebirth",
		Title = function()
			return if tab() == "Tree" then "Rebirth Tree" else `Rebirth #{State.rebirths() + 1}`
		end,
		Color = "Green",
		Icon = Ui.Icons.Rebirth,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(480))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = {
			tabButton(1, "Rebirth", Ui.Icons.Rebirth),
			tabButton(2, "Tree", Ui.Icons.Upgrade),
		},
		Body = {
			rebirthPage(function()
				return tab() == "Rebirth"
			end, anim),
			treePage(function()
				return tab() == "Tree"
			end),
		},
	}
end

return RebirthWindow
