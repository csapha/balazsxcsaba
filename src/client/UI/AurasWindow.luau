-- Auras window (GDD 3.10): tickets + the free-ticket timer, roll with a ticket / for money,
-- the collection (8 auras: chance, bonus, level); tap an owned aura to equip / unequip it.
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

local create = Vide.create
local source = Vide.source

local C = Theme.Colors
local AuraConfig = Config.Auras

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

local function auraCard(order: number, id: string): Frame
	local aura = AuraConfig.List[id]
	local rarity = AuraConfig.Rarities[aura.Rarity]
	local function level(): number?
		return State.auras().owned[id]
	end
	local function active(): boolean
		return State.auras().equipped == id
	end
	local pips = {}
	for i = 1, AuraConfig.MaxLevel do
		table.insert(pips, create "Frame" {
			LayoutOrder = i,
			Size = UDim2.fromOffset(11, 11),
			BackgroundColor3 = function()
				return if (level() or 0) >= i then rarity.Color else C.Ink
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			Kit.outline(nil, 1.5),
		})
	end
	return Kit.darkBox {
		Name = id,
		LayoutOrder = order,
		Line = function()
			if active() then
				return C.White
			end
			return if level() then rarity.Color else C.CardLine
		end,
		Fill = function()
			return if active() then C.CardSelected else C.Card
		end,
		create "ImageButton" {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Activated = function()
				if not level() then
					Audio.play("Error")
					return
				end
				Audio.play("Click")
				if active() then
					Remotes.AuraAction:FireServer("unequip")
				else
					Remotes.AuraAction:FireServer("equip", id)
				end
			end,
		},
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.fromOffset(130, 70),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ImageColor3 = rarity.Color,
			ImageTransparency = function()
				return if level() then 0.55 else 0.9
			end,
		},
		create "ImageLabel" {
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(46, 46),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Sparkle,
			ImageColor3 = function()
				return if level() then rarity.Color else C.CardLine
			end,
			ZIndex = 2,
		},
		create "ImageLabel" {
			Name = "Active",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = Ui.Icons.Check,
			ScaleType = Enum.ScaleType.Fit,
			Visible = active,
			ZIndex = 4,
		},
		Kit.text {
			Name = "Name",
			Text = function()
				return if level() then aura.Name else "???"
			end,
			TextSize = 17,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(4, 58),
			Size = UDim2.new(1, -8, 0, 20),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Rarity",
			Text = `{string.upper(rarity.Name)} ({chanceText(aura.Chance)})`,
			TextSize = 13,
			TextColor3 = rarity.Color,
			Gradient = false,
			Position = UDim2.fromOffset(4, 78),
			Size = UDim2.new(1, -8, 0, 16),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Bonus",
			Text = function()
				return `{percent(Formulas.auraBonusValue(id, level() or 1))} {Config.Pets.Bonuses[aura.Bonus]}`
			end,
			TextSize = 15,
			TextColor3 = function()
				return if level() then C.Good else C.Muted
			end,
			Gradient = false,
			Position = UDim2.fromOffset(4, 96),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 3,
		},
		create "Frame" {
			Name = "Level",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(AuraConfig.MaxLevel * 15, 11),
			BackgroundTransparency = 1,
			ZIndex = 3,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			pips,
		},
	} :: Frame
end

function AurasWindow.render(anim: Motion.Anim)
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
		table.insert(cards, auraCard(order, id))
	end

	return Kit.window {
		Name = "Auras",
		Title = "Auras",
		Color = "Purple",
		Icon = Ui.Icons.Crystal,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(470))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Body = {
			create "Frame" {
				Name = "Tickets",
				Size = UDim2.new(0.4, 0, 0, 54),
				BackgroundTransparency = 1,
				create "ImageLabel" {
					Size = UDim2.fromOffset(46, 46),
					Position = UDim2.fromOffset(0, 2),
					BackgroundTransparency = 1,
					Image = Ui.Icons.Daily,
					ScaleType = Enum.ScaleType.Fit,
				},
				Kit.text {
					Text = function()
						local tickets = State.auras().tickets
						return `{tickets} ticket{if tickets == 1 then "" else "s"}`
					end,
					TextSize = 26,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(54, 0),
					Size = UDim2.new(1, -54, 0, 30),
				},
				Kit.text {
					Text = function()
						local seconds = math.ceil(remaining())
						return `Free ticket in {string.format("%d:%02d", seconds // 60, seconds % 60)}`
					end,
					TextSize = 16,
					TextColor3 = C.Muted,
					Gradient = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(54, 30),
					Size = UDim2.new(1, -54, 0, 20),
				},
			},
			create "Frame" {
				Name = "Rolls",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.6, 0, 0, 54),
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Kit.button {
					Name = "RollTicket",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(190, 48),
					TextSize = 22,
					Color = function()
						return if State.auras().tickets > 0 then "Purple" else "Gray"
					end,
					Text = "ROLL (1 ticket)",
					Activated = function()
						if State.auras().tickets > 0 then
							Remotes.AuraAction:FireServer("roll", "ticket")
						else
							Audio.play("Error")
						end
					end,
				},
				Kit.button {
					Name = "RollMoney",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(190, 48),
					TextSize = 22,
					Color = function()
						return if State.money() >= rollPrice() then "Yellow" else "Gray"
					end,
					Text = function()
						return `ROLL {NumberFormat.money(rollPrice())}`
					end,
					Activated = function()
						if State.money() >= rollPrice() then
							Remotes.AuraAction:FireServer("roll", "money")
						else
							Audio.play("Error")
						end
					end,
				},
			},
			create "Frame" {
				Name = "Grid",
				Position = UDim2.fromOffset(0, 66),
				Size = UDim2.new(1, 0, 1, -66),
				BackgroundTransparency = 1,
				create "UIGridLayout" {
					CellSize = UDim2.new(0.25, -10, 0.5, -10),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "UIPadding" { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3) },
				cards,
			},
		},
	}
end

return AurasWindow
