-- Index ablak (GDD 3.11 + 9.4 ablak stílus):
--   fejléc színes sávval, ikon balra kilógva, cím, piros X jobbra; sötét panel; pop nyitás (0.6 → 1.05 → 1.0).
-- Fülek: Sütők, Ritkaságok, Petek, Aurák – mindegyiknél haladás és a teljesítésért járó bónusz.
-- (A chefek a chef-ritkaságokkal együtt kerülnek ide, GDD 3.6.)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)

local create = vide.create
local source = vide.source
local spring = vide.spring
local effect = vide.effect
local cleanup = vide.cleanup

local Palette = Config.Palette

type Source<T> = vide.Source<T>

type Entry = { color: Color3, title: string, subtitle: string }
type Category = {
	tab: string,
	title: string,
	attribute: string,
	bonus: number,
	columns: number,
	rows: number,
	entries: { Entry },
}

local IndexWindow = {}

local function text(props: { [any]: any })
	return create "TextLabel" {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,
		create "UIStroke" { Color = Palette.Stroke, Thickness = 2 },
		props,
	}
end

local function attributeSource(player: Player, attribute: string): Source<number>
	local value = source((player:GetAttribute(attribute) or 0) :: number)
	local connection = player:GetAttributeChangedSignal(attribute):Connect(function()
		value(player:GetAttribute(attribute) or 0)
	end)
	cleanup(function()
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

-- A kategóriák tartalma a Configból (így új sütő / pet / aura automatikusan megjelenik).
local function categories(): { Category }
	local ovens = {}
	for level, info in Config.Ovens.Levels do
		table.insert(ovens, { color = info.Color, title = `Lv {level}`, subtitle = info.Name })
	end

	local rarities = {}
	for index, rarity in Config.Rarities.List do
		table.insert(rarities, {
			color = rarity.Color,
			title = rarity.Name,
			subtitle = if index == 1 then "x1" else `x{rarity.UnitMult} · x{rarity.ValueMult}`,
		})
	end

	local pets = {}
	for _, id in Config.Pets.Order do
		local pet = Config.Pets.List[id]
		table.insert(pets, { color = pet.Color, title = pet.Name, subtitle = Config.Pets.Rarities[pet.Rarity].Name })
	end

	local auras = {}
	for _, id in Config.Auras.Order do
		local aura = Config.Auras.List[id]
		local rarity = Config.Auras.Rarities[aura.Rarity]
		table.insert(auras, { color = rarity.Color, title = aura.Name, subtitle = rarity.Name })
	end

	local bonuses = Config.Index.Bonuses
	return {
		{ tab = "Sütők", title = "Sütők", attribute = "IndexOvens", bonus = bonuses.Ovens, columns = 5, rows = 3, entries = ovens },
		{ tab = "Ritkaságok", title = "Schnitzel ritkaságok", attribute = "IndexRarities", bonus = bonuses.Rarities, columns = 5, rows = 2, entries = rarities },
		{ tab = "Petek", title = "Petek", attribute = "IndexPets", bonus = bonuses.Pets, columns = 4, rows = 4, entries = pets },
		{ tab = "Aurák", title = "Aurák", attribute = "IndexAuras", bonus = bonuses.Auras, columns = 4, rows = 2, entries = auras },
	}
end

-- Egy gyűjtemény-kártya: felfedezve színes, egyébként sötét "?".
local function card(order: number, discovered: () -> boolean, entry: Entry)
	return create "Frame" {
		LayoutOrder = order,
		BackgroundColor3 = function()
			return if discovered() then entry.color else Palette.Locked
		end,

		create "UICorner" { CornerRadius = UDim.new(0.15, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 2 },

		text {
			Position = UDim2.fromScale(0.05, 0.06),
			Size = UDim2.fromScale(0.9, 0.46),
			Text = function()
				return if discovered() then entry.title else "?"
			end,
		},
		text {
			Position = UDim2.fromScale(0.05, 0.56),
			Size = UDim2.fromScale(0.9, 0.36),
			TextColor3 = Palette.Lemon,
			Text = function()
				return if discovered() then entry.subtitle else "???"
			end,
		},
	}
end

local function page(category: Category, mask: () -> number, visible: () -> boolean)
	local total = #category.entries
	local function done(): boolean
		return countBits(mask(), total) == total
	end

	local cards = {}
	for index, entry in category.entries do
		local bit = 2 ^ (index - 1)
		table.insert(
			cards,
			card(index, function()
				return bit32.btest(mask(), bit)
			end, entry)
		)
	end

	return create "Frame" {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,

		text {
			Size = UDim2.fromScale(0.65, 0.09),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				return `{category.title}  {countBits(mask(), total)}/{total}`
			end,
		},
		text {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.35, 0.09),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = function()
				return if done() then Palette.Money else Palette.White
			end,
			Text = function()
				return `{if done() then "✔" else "🔒"} +{math.floor(category.bonus * 100 + 0.5)}% pénz`
			end,
		},

		create "Frame" {
			Position = UDim2.fromScale(0, 0.12),
			Size = UDim2.fromScale(1, 0.88),
			BackgroundTransparency = 1,

			create "UIGridLayout" {
				CellSize = UDim2.new(1 / category.columns, -8, 1 / category.rows, -8),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			cards,
		},
	}
end

-- Létrehozza az ablakot. `open` source vezérli a láthatóságot.
function IndexWindow.create(open: Source<boolean>)
	local player = Players.LocalPlayer
	local list = categories()
	local tab = source(1)

	local scale = spring(function()
		return if open() then 1 else 0.6
	end, 0.25, 0.55)

	-- GDD 9.4: elmosott háttér nyitott ablaknál
	local blur = Instance.new("BlurEffect")
	blur.Name = "IndexBlur"
	blur.Size = 0
	blur.Parent = Lighting
	effect(function()
		blur.Size = if open() then 12 else 0
	end)
	cleanup(blur)

	local masks = {}
	local pages = {}
	local tabs = {}
	for index, category in list do
		local mask = attributeSource(player, category.attribute)
		masks[index] = mask
		table.insert(
			pages,
			page(category, mask, function()
				return tab() == index
			end)
		)
		table.insert(
			tabs,
			create "TextButton" {
				LayoutOrder = index,
				Size = UDim2.fromScale(0.24, 1),
				BackgroundColor3 = function()
					return if tab() == index then Palette.Gold else Palette.Locked
				end,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Palette.White,
				Text = function()
					local total = #category.entries
					return `{category.tab} {countBits(mask(), total)}/{total}`
				end,
				create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
				create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				create "UIPadding" { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) },
				Activated = function()
					tab(index)
				end,
			}
		)
	end

	return create "Frame" {
		Name = "IndexWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.7, 0.8),
		BackgroundColor3 = Palette.Panel,
		BackgroundTransparency = 0.1,
		Visible = function()
			return open() or scale() > 0.65
		end,
		ZIndex = 10,

		create "UIScale" { Scale = scale },
		create "UIAspectRatioConstraint" { AspectRatio = 1.35 },
		create "UISizeConstraint" { MaxSize = Vector2.new(900, 670) },
		create "UICorner" { CornerRadius = UDim.new(0.04, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 4 },

		-- Fejléc: színes sáv, ikon balra kilógva, cím, piros X
		create "Frame" {
			Name = "Header",
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Palette.Gold,

			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },

			text {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1.5, 1.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = "📖",
			},
			text {
				Position = UDim2.fromScale(0.08, 0.12),
				Size = UDim2.fromScale(0.6, 0.76),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Index",
			},
			create "TextButton" {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundColor3 = Palette.Danger,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Palette.White,
				Text = "X",

				create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
				create "UIStroke" {
					Color = Palette.Stroke,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},

				Activated = function()
					open(false)
				end,
			},
		},

		-- Fülek
		create "Frame" {
			Position = UDim2.fromScale(0.03, 0.12),
			Size = UDim2.fromScale(0.94, 0.08),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.013, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			tabs,
		},

		-- Tartalom (az aktív fül oldala)
		create "Frame" {
			Name = "Body",
			Position = UDim2.fromScale(0.04, 0.23),
			Size = UDim2.fromScale(0.92, 0.74),
			BackgroundTransparency = 1,
			pages,
		},
	}
end

return IndexWindow
