-- GDD 9.3: active multipliers, bottom right. One chip per kind (money, bake speed, luck, chef speed, event);
-- hover / tap shows where the value comes from. Money is always shown, the others only while they are active.
-- The money total is the same product the server uses when the counter sells (SellService.sellTick):
-- counter level × rebirth × (1 + pets & aura) × (1 + rebirth tree) × Index × Friend Boost.
-- On touch the row sits above Roblox's jump button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local EventState = require(Shared.EventState)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Ui = require(Shared.Ui)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source

local C = Theme.Colors

local CHIP = 60
local GAP = 10

local Multipliers = {}

-- x1.25, x12.5, x150, x1.2K
local function times(value: number): string
	if value >= 1000 then
		return "x" .. NumberFormat.short(value)
	end
	local decimals = if value >= 100 then 0 elseif value >= 10 then 1 else 2
	local text = string.format(`%.{decimals}f`, math.floor(value * 10 ^ decimals + 1e-6) / 10 ^ decimals)
	if decimals > 0 then
		text = (text:gsub("0+$", ""):gsub("%.$", ""))
	end
	return "x" .. text
end

local function percent(value: number): string
	return `+{math.round(value * 100)}%`
end

-- A Vide source that follows a player attribute.
local function attribute(name: string): () -> number
	local player = Players.LocalPlayer
	local value = source((player:GetAttribute(name) or 0) :: number)
	local connection = player:GetAttributeChangedSignal(name):Connect(function()
		value(player:GetAttribute(name) or 0)
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)
	return value
end

-- The pet and aura bonuses separately (Formulas.boosts adds them up).
local function petAndAura(): ({ [string]: number }, { [string]: number }, string?)
	local pets = Formulas.petBonuses({ pets = State.pets() })
	local aura = { Money = 0, BakeSpeed = 0, Luck = 0, ChefSpeed = 0 }
	local auras = State.auras()
	local definition = auras.equipped ~= "" and Config.Auras.List[auras.equipped]
	local level = auras.owned[auras.equipped]
	if definition and level then
		aura[definition.Bonus] = Formulas.auraBonusValue(auras.equipped, level)
	end
	return pets, aura, if definition then definition.Name else nil
end

type Line = { label: string, value: string }

local function joinLines(lines: { Line }, empty: string): string
	if #lines == 0 then
		return empty
	end
	local out = {}
	for _, line in lines do
		table.insert(out, `{line.label}: {line.value}`)
	end
	return table.concat(out, "\n")
end

type ChipProps = {
	Order: number,
	Name: string,
	Icon: string | () -> string,
	Value: () -> string,
	Color: Color3 | () -> Color3,
	Shown: (() -> boolean)?,
	Title: () -> string,
	Text: () -> string,
}

local function chip(props: ChipProps): Frame
	local events, bubble = Kit.tooltip {
		Title = props.Title,
		Color = props.Color,
		Text = props.Text,
		AlignX = 1, -- the row is at the right edge: the bubble opens to the left
	}
	-- no box behind it: just the icon with the value under it
	return create "Frame" {
		Name = props.Name,
		LayoutOrder = props.Order,
		Size = UDim2.fromOffset(CHIP, CHIP),
		BackgroundTransparency = 1,
		Active = true,
		Visible = props.Shown,
		events,
		bubble,
		create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(52, 52),
			BackgroundTransparency = 1,
			Image = props.Icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		},
		Kit.text {
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.new(1, 16, 0, 24),
			Text = props.Value,
			TextSize = 21,
			TextColor3 = props.Color,
			Gradient = false,
			ZIndex = 4,
		},
	} :: Frame
end

-- How high the row has to sit to clear the touch jump button (0 with mouse / gamepad).
local function touchLift(): () -> number
	local touch = source(UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	local connection = UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType == Enum.UserInputType.Touch then
			touch(true)
		elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Keyboard
			or inputType.Name:find("Gamepad")
		then
			touch(false)
		end
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)
	return function()
		if not touch() then
			return 0
		end
		-- Roblox's jump button: 120 px on larger screens (bottom 140 px), 70 px on small ones (bottom 90 px)
		local viewport = Kit.viewportSize()
		return if math.min(viewport.X, viewport.Y) > 500 then 150 else 100
	end
end

-- The short effect of the running event, or nil when it has no multiplier (Food Critic, Breadcrumb Storm).
local function eventBadge(config: any): string?
	if config.SellMultiplier then
		return times(config.SellMultiplier)
	elseif config.RarityChanceMultipliers then
		local best = 1
		for _, value in config.RarityChanceMultipliers do
			best = math.max(best, value)
		end
		return times(best)
	elseif config.OvenLevelBonus then
		return `+{config.OvenLevelBonus} Lv`
	elseif config.ChefSpeedMultiplier then
		return times(config.ChefSpeedMultiplier)
	end
	return nil
end

function Multipliers.render(clock: () -> number): Frame
	local indexOvens = attribute("IndexOvens")
	local indexRarities = attribute("IndexRarities")
	local indexPets = attribute("IndexPets")
	local indexAuras = attribute("IndexAuras")
	local lift = touchLift()

	-- money: every factor of the sale, as lines for the tooltip and their product
	local function money(): (number, { Line })
		local lines = {}
		local total = 1

		local rebirth = Formulas.rebirthMultiplier(State.rebirths())
		total *= rebirth
		if rebirth > 1 then
			table.insert(lines, { label = "Rebirth", value = times(rebirth) })
		end

		local level = State.counterLevel()
		local counter = Formulas.counterPriceMultiplier(level)
		total *= counter
		if counter > 1 then
			table.insert(lines, { label = `Counter Lv {level}`, value = percent(counter - 1) })
		end

		local pets, aura, auraName = petAndAura()
		total *= 1 + pets.Money + aura.Money
		if pets.Money > 0 then
			table.insert(lines, { label = "Pets", value = percent(pets.Money) })
		end
		if aura.Money > 0 then
			table.insert(lines, { label = auraName or "Aura", value = percent(aura.Money) })
		end

		local tree = Formulas.perkValue({ rebirthPerks = State.perks() }, "Money")
		total *= 1 + tree
		if tree > 0 then
			table.insert(lines, { label = "Rebirth tree", value = percent(tree) })
		end

		local index = Formulas.indexMoneyBonus({
			Ovens = indexOvens(),
			Rarities = indexRarities(),
			Pets = indexPets(),
			Auras = indexAuras(),
		})
		total *= index
		if index > 1 then
			table.insert(lines, { label = "Index", value = percent(index - 1) })
		end

		local friends = Formulas.friendMoneyBonus(State.friends())
		total *= friends
		if friends > 1 then
			table.insert(lines, { label = "Friend Boost", value = percent(friends - 1) })
		end
		return total, lines
	end

	-- bake speed / luck / chef speed: pets + aura
	local function boost(kind: string): (number, { Line })
		local pets, aura, auraName = petAndAura()
		local lines = {}
		if pets[kind] > 0 then
			table.insert(lines, { label = "Pets", value = percent(pets[kind]) })
		end
		if aura[kind] > 0 then
			table.insert(lines, { label = auraName or "Aura", value = percent(aura[kind]) })
		end
		return 1 + pets[kind] + aura[kind], lines
	end

	local function event(): any?
		clock()
		local config = EventState.config()
		return if config and eventBadge(config) then config else nil
	end

	local function boostChip(order: number, kind: string, name: string, title: string, icon: string, color: Color3)
		return chip {
			Order = order,
			Name = name,
			Icon = icon,
			Color = color,
			Shown = function()
				return (boost(kind)) > 1
			end,
			Value = function()
				return times((boost(kind)))
			end,
			Title = function()
				return `{title} {times((boost(kind)))}`
			end,
			Text = function()
				local _, lines = boost(kind)
				return joinLines(lines, "")
			end,
		}
	end

	return create "Frame" {
		Name = "Multipliers",
		AnchorPoint = Vector2.new(1, 1),
		Position = function()
			return UDim2.new(1, -(16 - Kit.sideSlack("Right")), 1, -14 - lift())
		end,
		Size = UDim2.fromOffset(0, CHIP),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Kit.scale(),
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		-- the running event first: it is the one that changes
		chip {
			Order = 1,
			Name = "Event",
			Icon = function()
				local config = event()
				return if config then config.Icon else ""
			end,
			Color = function()
				local config = event()
				return if config then config.Color else C.White
			end,
			Shown = function()
				return event() ~= nil
			end,
			Value = function()
				local config = event()
				return if config then eventBadge(config) or "" else ""
			end,
			Title = function()
				local config = event()
				return if config then config.Name else ""
			end,
			Text = function()
				local config = event()
				if not config then
					return ""
				end
				local seconds = math.max(0, math.ceil(EventState.endsAt() - clock()))
				return `{config.Description}\nEnds in {string.format("%d:%02d", seconds // 60, seconds % 60)}`
			end,
		},
		boostChip(2, "ChefSpeed", "ChefSpeed", "Chef Speed", Ui.Icons.Chefs, C.Mint),
		boostChip(3, "Luck", "Luck", "Luck", Ui.Icons.Clover, C.Good),
		boostChip(4, "BakeSpeed", "BakeSpeed", "Bake Speed", Ui.Icons.Baking, C.Lemon),
		chip {
			Order = 5,
			Name = "Money",
			Icon = Ui.Icons.CoinBag,
			Color = C.Money,
			Value = function()
				return times((money()))
			end,
			Title = function()
				return `Money {times((money()))}`
			end,
			Text = function()
				local _, lines = money()
				return joinLines(lines, "Rebirth, pets, auras, the Index\nand friends raise it.")
			end,
		},
	} :: Frame
end

return Multipliers
