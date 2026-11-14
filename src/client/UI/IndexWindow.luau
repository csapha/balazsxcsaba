-- Index window (GDD 3.11): Ovens, Rarities, Pets, Auras – progress per tab and the money bonus for completing it.
-- Discoveries come from player attributes (bit masks) set by the server's IndexService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Ui = require(Shared.Ui)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source

local C = Theme.Colors

type Entry = { color: Color3, title: string, subtitle: string }
type Category = {
	id: string,
	title: string,
	icon: string,
	color: string,
	attribute: string,
	bonus: number,
	columns: number,
	entries: { Entry },
}

local IndexWindow = {}

local function attributeSource(player: Player, attribute: string): () -> number
	local value = source((player:GetAttribute(attribute) or 0) :: number)
	local connection = player:GetAttributeChangedSignal(attribute):Connect(function()
		value(player:GetAttribute(attribute) or 0)
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)
	return value
end

local function countBits(mask: number, total: number): number
	local count = 0
	for i = 1, total do
		if bit32.btest(mask, 2 ^ (i - 1)) then
			count += 1
		end
	end
	return count
end

-- The categories come from Config, so a new oven / pet / aura shows up automatically.
local function categories(): { Category }
	local ovens = {}
	for level, info in Config.Ovens.Levels do
		table.insert(ovens, { color = info.Color, title = info.Name, subtitle = `Lv {level}` })
	end

	local rarities = {}
	for index, rarity in Config.Rarities.List do
		table.insert(rarities, {
			color = rarity.Color,
			title = rarity.Name,
			subtitle = if index == 1 then "x1" else `x{rarity.UnitMult} pieces, x{rarity.ValueMult} price`,
		})
	end

	local pets = {}
	for _, id in Config.Pets.Order do
		local pet = Config.Pets.List[id]
		local rarity = Config.Pets.Rarities[pet.Rarity]
		table.insert(pets, { color = rarity.Color, title = pet.Name, subtitle = rarity.Name })
	end

	local auras = {}
	for _, id in Config.Auras.Order do
		local aura = Config.Auras.List[id]
		local rarity = Config.Auras.Rarities[aura.Rarity]
		table.insert(auras, { color = rarity.Color, title = aura.Name, subtitle = rarity.Name })
	end

	local bonuses = Config.Index.Bonuses
	return {
		{ id = "Ovens", title = "Ovens", icon = Ui.Icons.Energy, color = "Orange", attribute = "IndexOvens", bonus = bonuses.Ovens, columns = 5, entries = ovens },
		{ id = "Rarities", title = "Schnitzel Rarities", icon = Ui.Icons.Star, color = "Yellow", attribute = "IndexRarities", bonus = bonuses.Rarities, columns = 5, entries = rarities },
		{ id = "Pets", title = "Pets", icon = Ui.Icons.Pets, color = "Blue", attribute = "IndexPets", bonus = bonuses.Pets, columns = 4, entries = pets },
		{ id = "Auras", title = "Auras", icon = Ui.Icons.Crystal, color = "Purple", attribute = "IndexAuras", bonus = bonuses.Auras, columns = 4, entries = auras },
	}
end

-- A collection card: coloured when discovered, a dark "?" otherwise.
local function card(order: number, discovered: () -> boolean, entry: Entry): Frame
	return Kit.darkBox {
		Name = "Card" .. order,
		LayoutOrder = order,
		Line = function()
			return if discovered() then entry.color else C.CardLine
		end,
		Fill = function()
			return if discovered() then entry.color:Lerp(C.Card, 0.7) else C.Card
		end,
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			Size = UDim2.fromScale(0.9, 0.7),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ImageColor3 = entry.color,
			ImageTransparency = 0.6,
			Visible = discovered,
		},
		Kit.text {
			Name = "Mark",
			Text = "?",
			TextSize = 40,
			TextColor3 = C.Muted,
			Gradient = false,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 0.7),
			Visible = function()
				return not discovered()
			end,
			ZIndex = 3,
		},
		Kit.text {
			Name = "Title",
			Text = function()
				return if discovered() then entry.title else ""
			end,
			TextSize = 17,
			TextWrapped = true,
			Position = UDim2.new(0, 6, 0, 8),
			Size = UDim2.new(1, -12, 0.55, -8),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Subtitle",
			Text = function()
				return if discovered() then entry.subtitle else "Not found yet"
			end,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = function()
				return if discovered() then C.Lemon else C.Muted
			end,
			Gradient = false,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 6, 1, -6),
			Size = UDim2.new(1, -12, 0.4, -6),
			ZIndex = 3,
		},
	} :: Frame
end

local function page(category: Category, mask: () -> number, visible: () -> boolean): Frame
	local total = #category.entries
	local function found(): number
		return countBits(mask(), total)
	end
	local function done(): boolean
		return found() == total
	end
	local cards = {}
	for index, entry in category.entries do
		local bit = 2 ^ (index - 1)
		table.insert(cards, card(index, function()
			return bit32.btest(mask(), bit)
		end, entry))
	end
	local rows = math.ceil(total / category.columns)
	return create "Frame" {
		Name = category.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		Kit.bar {
			Name = "Progress",
			Size = UDim2.new(0.55, 0, 0, 30),
			Palette = function()
				return if done() then "Green" else category.color
			end,
			Label = category.title,
			Right = function()
				return `{found()}/{total}`
			end,
			Value = function()
				return found() / total
			end,
		},
		Kit.text {
			Name = "Bonus",
			Text = function()
				local percent = math.floor(category.bonus * 100 + 0.5)
				return if done() then `+{percent}% money  ✔` else `Complete for +{percent}% money`
			end,
			TextSize = 20,
			TextColor3 = function()
				return if done() then C.Good else C.Muted
			end,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.43, 0, 0, 30),
		},
		create "Frame" {
			Name = "Grid",
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 1, -42),
			BackgroundTransparency = 1,
			create "UIGridLayout" {
				CellSize = UDim2.new(1 / category.columns, -8, 1 / rows, -8),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			create "UIPadding" { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3) },
			cards,
		},
	} :: Frame
end

function IndexWindow.render(anim: Motion.Anim)
	local player = Players.LocalPlayer
	local list = categories()
	local tab = source(1)
	local pages, tabs = {}, {}
	for index, category in list do
		local mask = attributeSource(player, category.attribute)
		table.insert(pages, page(category, mask, function()
			return tab() == index
		end))
		table.insert(tabs, Kit.button {
			Name = category.id,
			LayoutOrder = index,
			Icon = category.icon,
			IconSize = 0.85,
			Color = category.color,
			Shine = false,
			Size = UDim2.fromOffset(60, 60),
			Selected = function()
				return tab() == index
			end,
			Activated = function()
				tab(index)
			end,
		})
	end
	return Kit.window {
		Name = "Index",
		Title = "Index",
		Color = "Yellow",
		Icon = Ui.Icons.Index,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(480))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = tabs,
		Body = pages,
	}
end

return IndexWindow
