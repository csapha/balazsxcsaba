-- Auras window (GDD 3.10), laid out like the Pets window:
--   left: the selected aura (what it gives, its level, how to level it) and EQUIP / UNEQUIP;
--   right: tickets + the two roll buttons on top, the collection (8 auras) below. Tap a card to select it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

local create = Vide.create
local source = Vide.source

local C = Theme.Colors
local AuraConfig = Config.Auras

local LEFT_W = 250
local GAP = 12
local TOP_H = 54

local AurasWindow = {}

local function percent(value: number): string
	return `+{math.floor(value * 100 + 0.5)}%`
end

local TOTAL_CHANCE = 0
for _, id in AuraConfig.Order do
	TOTAL_CHANCE += AuraConfig.List[id].Chance
end

local function chanceText(chance: number): string
	local value = chance / TOTAL_CHANCE * 100
	return if value >= 1 then `{math.floor(value + 0.5)}%` else `{math.floor(value * 10 + 0.5) / 10}%`
end

local function bonusText(id: string, level: number): string
	local aura = AuraConfig.List[id]
	return `{percent(Formulas.auraBonusValue(id, level))} {Config.Pets.Bonuses[aura.Bonus]}`
end

local function rarityOf(id: string)
	return AuraConfig.Rarities[AuraConfig.List[id].Rarity]
end

local function spinForever(instance: GuiObject, seconds: number): GuiObject
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = instance.Rotation + 360,
	})
	tween:Play()
	Vide.cleanup(function()
		tween:Cancel()
	end)
	return instance
end

-- A row of level pips (filled up to the level, in the rarity colour).
local function pips(size: number, gap: number, level: () -> number, color: () -> Color3, props: { [any]: any }): Frame
	local list = {}
	for i = 1, AuraConfig.MaxLevel do
		table.insert(list, create "Frame" {
			LayoutOrder = i,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = function()
				return if level() >= i then color() else C.Ink
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			Kit.outline(nil, 1.5),
		})
	end
	return create "Frame" {
		Name = "Level",
		Size = UDim2.fromOffset(AuraConfig.MaxLevel * (size + gap) - gap, size),
		BackgroundTransparency = 1,
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		list,
		props,
	} :: Frame
end

-- Collection card: sparkle in the rarity colour, name (??? until rolled), rarity + chance, level pips.
local function auraCard(order: number, id: string, view: () -> State.AurasData, selected: (string?) -> string?): Frame
	local aura = AuraConfig.List[id]
	local rarity = rarityOf(id)
	local function level(): number
		return view().owned[id] or 0
	end
	local function owned(): boolean
		return level() > 0
	end
	local function worn(): boolean
		return view().equipped == id
	end
	return Kit.darkBox {
		Name = id,
		LayoutOrder = order,
		Line = function()
			if selected() == id then
				return C.White
			end
			return if owned() then rarity.Color else C.CardLine
		end,
		Fill = function()
			return if worn() then C.CardSelected else C.Card
		end,
		create "ImageButton" {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Activated = function()
				Audio.play("Click")
				selected(id)
			end,
		},
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(1, 0.45),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ImageColor3 = rarity.Color,
			ImageTransparency = function()
				return if owned() then 0.5 else 0.88
			end,
		},
		create "ImageLabel" {
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.36, 0.36),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Image = Ui.Textures.Sparkle,
			ImageColor3 = function()
				return if owned() then rarity.Color else C.CardLine
			end,
			ZIndex = 2,
		},
		create "ImageLabel" {
			Name = "Worn",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = Ui.Icons.Check,
			ScaleType = Enum.ScaleType.Fit,
			Visible = worn,
			ZIndex = 4,
		},
		Kit.text {
			Name = "Name",
			Text = function()
				return if owned() then aura.Name else "???"
			end,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -38),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Rarity",
			Text = `{string.upper(rarity.Name)} {chanceText(aura.Chance)}`,
			TextSize = 12,
			TextColor3 = rarity.Color,
			Gradient = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -22),
			Size = UDim2.new(1, -8, 0, 14),
			ZIndex = 3,
		},
		pips(9, 3, level, function()
			return rarity.Color
		end, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -7),
			ZIndex = 3,
		}),
	} :: Frame
end

-- Left panel: everything about the selected aura, and the equip button.
local function detail(view: () -> State.AurasData, selected: () -> string?, appear: () -> number): Frame
	local burstLayer = create "Frame" {
		Name = "Burst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	} :: Frame
	local function level(): number
		local id = selected()
		return if id then view().owned[id] or 0 else 0
	end
	local function owned(): boolean
		return level() > 0
	end
	local function worn(): boolean
		local id = selected()
		return id ~= nil and view().equipped == id
	end
	local function color(): Color3
		local id = selected()
		return if id then rarityOf(id).Color else C.CardLine
	end
	local function shown(): Color3
		return if owned() then color() else C.CardLine
	end
	return Kit.darkBox {
		Name = "Detail",
		Size = UDim2.new(0, LEFT_W, 1, 0),
		Line = shown,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear())
			end,
		},
		burstLayer,
		create "Frame" {
			Name = "Stage",
			Size = UDim2.new(1, 0, 0, 130),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			spinForever(create "ImageLabel" {
				Name = "Sunburst",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(230, 230),
				BackgroundTransparency = 1,
				Image = Ui.Textures.Sunburst,
				ImageColor3 = shown,
				ImageTransparency = function()
					return if owned() then 0.65 else 0.88
				end,
			} :: ImageLabel, 26),
			create "ImageLabel" {
				Name = "Sparkle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(84, 84),
				BackgroundTransparency = 1,
				Image = Ui.Textures.Sparkle,
				ImageColor3 = shown,
				ZIndex = 2,
			},
			Kit.text {
				Name = "Locked",
				Text = "?",
				TextSize = 40,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(60, 50),
				Visible = function()
					return not owned()
				end,
				ZIndex = 3,
			},
		},
		create "Frame" {
			Name = "Info",
			Position = UDim2.fromOffset(0, 130),
			Size = UDim2.new(1, 0, 0, 130),
			BackgroundTransparency = 1,
			create "UIPadding" { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
			create "UIListLayout" { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder },
			Kit.text {
				Name = "Name",
				LayoutOrder = 1,
				Text = function()
					local id = selected()
					return if id and owned() then AuraConfig.List[id].Name else "???"
				end,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 26),
			},
			Kit.text {
				Name = "Rarity",
				LayoutOrder = 2,
				Text = function()
					local id = selected()
					if not id then
						return ""
					end
					return `{string.upper(rarityOf(id).Name)} ({chanceText(AuraConfig.List[id].Chance)} chance)`
				end,
				TextSize = 15,
				TextColor3 = color,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 18),
			},
			Kit.text {
				Name = "Bonus",
				LayoutOrder = 3,
				Text = function()
					local id = selected()
					if not id then
						return ""
					end
					-- the bonus stays a secret until the aura is found
					return if owned() then bonusText(id, level()) else "??? bonus"
				end,
				TextSize = 22,
				TextColor3 = function()
					return if owned() then C.Good else C.Muted
				end,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 26),
			},
			create "Frame" {
				Name = "LevelRow",
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Visible = owned,
				Kit.text {
					Text = function()
						return `Level {level()}/{AuraConfig.MaxLevel}`
					end,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(0, 90, 1, 0),
				},
				pips(13, 4, level, color, {
					Position = UDim2.fromOffset(92, 3),
				}),
			},
			Kit.text {
				Name = "Hint",
				LayoutOrder = 5,
				Text = function()
					local id = selected()
					if not id then
						return ""
					end
					if not owned() then
						return "Not found yet. Roll to find it!"
					end
					if level() >= AuraConfig.MaxLevel then
						return "Max level!"
					end
					return `Roll it again: Lv {level() + 1} gives {bonusText(id, level() + 1)}`
				end,
				TextSize = 14,
				TextColor3 = C.Muted,
				Gradient = false,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 34),
			},
		},
		Kit.button {
			Name = "Equip",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 46),
			TextSize = 22,
			Color = function()
				if not owned() then
					return "Gray"
				end
				return if worn() then "Blue" else "Green"
			end,
			Text = function()
				if not owned() then
					return "LOCKED"
				end
				return if worn() then "UNEQUIP" else "EQUIP"
			end,
			Activated = function()
				local id = selected()
				if not id or not owned() then
					Audio.play("Error")
					return
				end
				if worn() then
					Remotes.AuraAction:FireServer("unequip")
				else
					Audio.play("Chime")
					Kit.burst(burstLayer, UDim2.new(0.5, 0, 0, 72), color(), 12, 1)
					Remotes.AuraAction:FireServer("equip", id)
				end
			end,
		},
	} :: Frame
end

-- Hides the window, then rolls; the window returns when the reveal ends (Hud → Effects.auraRoll).
-- If the server refuses (cooldown, no money) no AuraRolled arrives, so the window comes back after a short wait.
local rollToken = 0
local function roll(mode: string)
	rollToken += 1
	local token = rollToken
	State.auraRolling(true)
	Remotes.AuraAction:FireServer("roll", mode)
	task.delay(2, function()
		if token == rollToken and not State.auraRevealing then
			State.auraRolling(false)
		end
	end)
end

function AurasWindow.render(anim: Motion.Anim)
	-- what the window shows: frozen while a roll is in progress, so the result never shows before the reveal
	local view = source(State.auras())
	Vide.effect(function()
		local auras = State.auras()
		if not State.auraRolling() then
			view(auras)
		end
	end)

	-- selected aura: the rolled one after a reveal, otherwise the worn one (or the first) on open
	local selected = source(nil :: string?)
	Vide.effect(function()
		if State.auraRolling() then
			return
		end
		local rolled = State.lastRolledAura
		if rolled then
			State.lastRolledAura = nil
			selected(rolled)
		end
	end)
	Vide.effect(function()
		if not anim.opened() then
			return
		end
		Vide.untrack(function()
			if selected() == nil then
				local worn = view().equipped
				selected(if worn ~= "" then worn else AuraConfig.Order[1])
			end
		end)
	end)

	-- countdown to the next free ticket (the server refreshes every 5 s, we count locally in between)
	local tick = source(os.clock())
	local lastProgressAt = os.clock()
	Vide.effect(function()
		State.auras()
		lastProgressAt = os.clock()
	end)
	local running = true
	task.spawn(function()
		while running do
			tick(os.clock())
			task.wait(1)
		end
	end)
	Vide.cleanup(function()
		running = false
	end)

	local function remaining(): number
		tick()
		local elapsed = os.clock() - lastProgressAt
		return math.max(0, AuraConfig.FreeTicketInterval - State.auras().ticketProgress - elapsed)
	end
	local function rollPrice(): number
		State.money()
		State.auras()
		return Formulas.auraRollPrice(State.data())
	end

	local cards = {}
	for order, id in AuraConfig.Order do
		table.insert(cards, auraCard(order, id, view, selected))
	end

	return Kit.window {
		Name = "Auras",
		Title = "Auras",
		Color = "Purple",
		Icon = Ui.Icons.Auras,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(470))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Body = {
			detail(view, selected, anim.appear(0.12, 0, Enum.EasingStyle.Back, 0.45)),
			create "Frame" {
				Name = "Right",
				Position = UDim2.fromOffset(LEFT_W + GAP, 0),
				Size = UDim2.new(1, -(LEFT_W + GAP), 1, 0),
				BackgroundTransparency = 1,
				-- tickets
				create "Frame" {
					Name = "Tickets",
					Size = UDim2.new(1, -330, 0, TOP_H),
					BackgroundTransparency = 1,
					create "ImageLabel" {
						Name = "TicketIcon",
						Size = UDim2.fromOffset(42, 42),
						Position = UDim2.fromOffset(0, 6),
						BackgroundTransparency = 1,
						Image = Ui.Icons.Ticket,
						ScaleType = Enum.ScaleType.Fit,
					},
					Kit.text {
						Text = function()
							local tickets = State.auras().tickets
							return `{tickets} ticket{if tickets == 1 then "" else "s"}`
						end,
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(48, 2),
						Size = UDim2.new(1, -48, 0, 26),
					},
					Kit.text {
						Text = function()
							local seconds = math.ceil(remaining())
							return `Free in {string.format("%d:%02d", seconds // 60, seconds % 60)}`
						end,
						TextSize = 14,
						TextColor3 = C.Muted,
						Gradient = false,
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(48, 28),
						Size = UDim2.new(1, -48, 0, 18),
					},
				},
				-- roll buttons
				create "Frame" {
					Name = "Rolls",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(326, TOP_H),
					BackgroundTransparency = 1,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					Kit.button {
						Name = "RollTicket",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(150, 48),
						TextSize = 22,
						Color = function()
							return if State.auras().tickets > 0 then "Purple" else "Gray"
						end,
						Text = "ROLL 1",
						InlineIcon = Ui.Icons.Ticket,
						Activated = function()
							if State.auras().tickets > 0 then
								roll("ticket")
							else
								Audio.play("Error")
							end
						end,
					},
					Kit.button {
						Name = "RollMoney",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(160, 48),
						TextSize = 22,
						Color = function()
							return if State.money() >= rollPrice() then "Yellow" else "Gray"
						end,
						Text = function()
							return `ROLL {NumberFormat.money(rollPrice())}`
						end,
						Activated = function()
							if State.money() >= rollPrice() then
								roll("money")
							else
								Audio.play("Error")
							end
						end,
					},
				},
				-- collection
				create "Frame" {
					Name = "Grid",
					Position = UDim2.fromOffset(0, TOP_H + 8),
					Size = UDim2.new(1, 0, 1, -(TOP_H + 8)),
					BackgroundTransparency = 1,
					create "UIGridLayout" {
						CellSize = UDim2.new(0.25, -8, 0.5, -8),
						CellPadding = UDim2.fromOffset(8, 8),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					create "UIPadding" { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) },
					cards,
				},
			},
		},
	}
end

return AurasWindow
