-- Aurák ablak (GDD 3.10, 9.4): ticketek + következő ingyen ticket időzítő, dobás tickettel / pénzért,
-- gyűjtemény (8 aura: esély, bónusz, szint), kattintásra felszerel / levesz.
-- + Dobás animáció ("pörgő" nevek → az eredmény ritkaság színnel, ÚJ! / Lv n!).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local create = vide.create
local source = vide.source
local spring = vide.spring
local effect = vide.effect
local cleanup = vide.cleanup

local AuraConfig = Config.Auras
local Palette = Config.Palette

type Source<T> = vide.Source<T>
type AurasData = { owned: { [string]: number }, equipped: string, tickets: number, ticketProgress: number }

local AurasWindow = {}

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

local function button(props: { [any]: any })
	return create "TextButton" {
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,
		AutoButtonColor = true,
		create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		create "UIPadding" { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) },
		props,
	}
end

local function percent(value: number): string
	return `+{math.floor(value * 100 + 0.5)}%`
end

local function chanceText(chance: number): string
	local total = 0
	for _, id in AuraConfig.Order do
		total += AuraConfig.List[id].Chance
	end
	local value = chance / total * 100
	return if value >= 1 then `{math.floor(value + 0.5)}%` else `{math.floor(value * 10 + 0.5) / 10}%`
end

-- auras: az aura adatok; money: a pénz (a pénzes dobás árához); data: a teljes adat (bevétel becsléshez)
function AurasWindow.create(open: Source<boolean>, auras: Source<AurasData>, money: Source<number>, data: any)
	local scale = spring(function()
		return if open() then 1 else 0.6
	end, 0.25, 0.55)

	local blur = Instance.new("BlurEffect")
	blur.Name = "AurasBlur"
	blur.Size = 0
	blur.Parent = Lighting
	effect(function()
		blur.Size = if open() then 12 else 0
	end)
	cleanup(blur)

	-- a következő ingyen ticket visszaszámlálója (a szerver 5 mp-enként frissít, közte helyben számolunk)
	local tick = source(os.clock())
	local lastProgressAt = os.clock()
	effect(function()
		auras() -- újraszámolás, ha frissült
		lastProgressAt = os.clock()
	end)
	local running = true
	task.spawn(function()
		while running do
			tick(os.clock())
			task.wait(1)
		end
	end)
	cleanup(function()
		running = false
	end)

	local function remaining(): number
		tick()
		local elapsed = os.clock() - lastProgressAt
		return math.max(0, AuraConfig.FreeTicketInterval - auras().ticketProgress - elapsed)
	end

	local function rollPrice(): number
		money()
		auras()
		return Formulas.auraRollPrice(data())
	end

	local cards = {}
	for order, id in AuraConfig.Order do
		local aura = AuraConfig.List[id]
		local rarity = AuraConfig.Rarities[aura.Rarity]
		local function level(): number?
			return auras().owned[id]
		end
		table.insert(
			cards,
			create "TextButton" {
				LayoutOrder = order,
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = function()
					return if level() then Palette.Panel else Palette.Locked
				end,
				create "UICorner" { CornerRadius = UDim.new(0.12, 0) },
				create "UIStroke" {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = function()
						return if auras().equipped == id then Palette.White else rarity.Color
					end,
					Thickness = function()
						return if auras().equipped == id then 5 else 3
					end,
				},
				text {
					Position = UDim2.fromScale(0.05, 0.04),
					Size = UDim2.fromScale(0.9, 0.3),
					TextColor3 = rarity.Color,
					Text = function()
						return if level() then aura.Name else "???"
					end,
				},
				text {
					Position = UDim2.fromScale(0.05, 0.36),
					Size = UDim2.fromScale(0.9, 0.2),
					Text = `{rarity.Name} · {chanceText(aura.Chance)}`,
				},
				text {
					Position = UDim2.fromScale(0.05, 0.58),
					Size = UDim2.fromScale(0.9, 0.18),
					TextColor3 = Palette.Money,
					Text = function()
						local lv = level() or 1
						return `{Config.Pets.Bonuses[aura.Bonus]} {percent(Formulas.auraBonusValue(id, lv))}`
					end,
				},
				text {
					Position = UDim2.fromScale(0.05, 0.78),
					Size = UDim2.fromScale(0.9, 0.18),
					TextColor3 = Palette.Lemon,
					Text = function()
						local lv = level()
						if not lv then
							return "nincs meg"
						end
						local mark = if auras().equipped == id then "✔ aktív · " else ""
						return `{mark}Lv {lv}/{AuraConfig.MaxLevel}`
					end,
				},
				Activated = function()
					if not level() then
						return
					end
					if auras().equipped == id then
						Remotes.AuraAction:FireServer("unequip")
					else
						Remotes.AuraAction:FireServer("equip", id)
					end
				end,
			}
		)
	end

	return create "Frame" {
		Name = "AurasWindow",
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

		-- Fejléc
		create "Frame" {
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Palette.RarityNagyi,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },
			text {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1.5, 1.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = "✨",
			},
			text {
				Position = UDim2.fromScale(0.08, 0.12),
				Size = UDim2.fromScale(0.5, 0.76),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Aurák",
			},
			button {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundColor3 = Palette.Danger,
				Text = "X",
				Activated = function()
					open(false)
				end,
			},
		},

		-- Ticketek + időzítő
		text {
			Position = UDim2.fromScale(0.03, 0.12),
			Size = UDim2.fromScale(0.94, 0.07),
			TextColor3 = Palette.Lemon,
			Text = function()
				local seconds = math.ceil(remaining())
				local timer = string.format("%d:%02d", seconds // 60, seconds % 60)
				return `🎟️ {auras().tickets} ticket · következő ingyen ticket: {timer}`
			end,
		},

		-- Dobás gombok
		create "Frame" {
			Position = UDim2.fromScale(0.1, 0.21),
			Size = UDim2.fromScale(0.8, 0.1),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.04, 0),
			},
			button {
				Size = UDim2.fromScale(0.48, 1),
				BackgroundColor3 = function()
					return if auras().tickets > 0 then Palette.Money else Palette.Locked
				end,
				Text = "Dobás (1 🎟️)",
				Activated = function()
					if auras().tickets > 0 then
						Remotes.AuraAction:FireServer("roll", "ticket")
					end
				end,
			},
			button {
				Size = UDim2.fromScale(0.48, 1),
				BackgroundColor3 = function()
					return if money() >= rollPrice() then Palette.Gold else Palette.Locked
				end,
				Text = function()
					return `Dobás {NumberFormat.money(rollPrice())}`
				end,
				Activated = function()
					if money() >= rollPrice() then
						Remotes.AuraAction:FireServer("roll", "money")
					end
				end,
			},
		},

		-- Gyűjtemény
		create "Frame" {
			Position = UDim2.fromScale(0.03, 0.34),
			Size = UDim2.fromScale(0.94, 0.63),
			BackgroundTransparency = 1,
			create "UIGridLayout" {
				CellSize = UDim2.new(0.25, -8, 0.5, -8),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			cards,
		},
	}
end

-- Dobás animáció: pörgő aura nevek → az eredmény ritkaság színnel, "ÚJ!" vagy "Lv n!".
function AurasWindow.playRoll(playerGui: Instance, id: string, level: number, isNew: boolean)
	local aura = AuraConfig.List[id]
	if not aura then
		return
	end
	local rarity = AuraConfig.Rarities[aura.Rarity]

	local gui = Instance.new("ScreenGui")
	gui.Name = "AuraRoll"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromScale(0.7, 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Palette.White
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Stroke
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = gui

	local sub = label:Clone()
	sub.Position = UDim2.fromScale(0.5, 0.57)
	sub.Size = UDim2.fromScale(0.5, 0.07)
	sub.Text = ""
	sub.Parent = gui

	gui.Parent = playerGui

	task.spawn(function()
		-- pörgés: egyre lassuló váltások
		for i = 1, 14 do
			local other = AuraConfig.List[AuraConfig.Order[math.random(1, #AuraConfig.Order)]]
			label.Text = other.Name
			label.TextColor3 = AuraConfig.Rarities[other.Rarity].Color
			task.wait(0.04 + i * 0.012)
		end

		label.Text = aura.Name
		label.TextColor3 = rarity.Color
		sub.Text = if isNew then `ÚJ! ({rarity.Name})` else `Lv {level}! ({rarity.Name})`
		sub.TextColor3 = if isNew then Palette.Lemon else Palette.Money

		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.6
		uiScale.Parent = label
		TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 })
			:Play()

		task.wait(1.8)
		gui:Destroy()
	end)
end

return AurasWindow
