-- Rebirth ablak (GDD 3.8, 9.4) + rebirth effekt (GDD 10: fehér villanás, nagy "x3 PÉNZ!" felirat).
-- A gomb kétlépcsős: első kattintásra "Biztos?" – a második küldi a kérést (Remotes.RequestRebirth).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local Palette = Config.Palette

type Source<T> = vide.Source<T>

export type State = {
	earned: Source<number>, -- az utolsó rebirth óta keresett pénz
	rebirths: Source<number>,
	tokens: Source<number>,
	perks: Source<{ [string]: number }>,
}

local RebirthWindow = {}

-- Rebirth-fa (GDD 3.8): egy perk sora – név, leírás, szint, hatás most → következő, vásárlás tokenért.
local function perkValueText(perk: string, level: number): string
	local definition = Config.Rebirth.Tree.Perks[perk]
	if perk == "StartMoney" then
		return `×{NumberFormat.short(definition.Step ^ level)}`
	elseif perk == "Money" or perk == "OfflineRate" then
		return `+{math.floor(definition.Step * level * 100 + 0.5)}%`
	elseif perk == "OfflineTime" then
		return `+{math.floor(definition.Step * level / 3600)} óra`
	end
	return `+{definition.Step * level}`
end

local function perkRow(order: number, perk: string, state: State)
	local tree = Config.Rebirth.Tree
	local definition = tree.Perks[perk]
	local function level(): number
		return state.perks()[perk] or 0
	end
	local function maxed(): boolean
		return level() >= definition.Max
	end
	local function canBuy(): boolean
		return not maxed() and state.tokens() >= tree.TokenCost
	end

	return create "Frame" {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0.135),
		BackgroundColor3 = Palette.Stroke,
		BackgroundTransparency = 0.4,
		create "UICorner" { CornerRadius = UDim.new(0.2, 0) },

		create "TextLabel" {
			Position = UDim2.fromScale(0.03, 0.08),
			Size = UDim2.fromScale(0.42, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Gold,
			Text = function()
				return `{definition.Name}  Lv {level()}/{definition.Max}`
			end,
			create "UIStroke" { Color = Palette.Stroke, Thickness = 2 },
		},
		create "TextLabel" {
			Position = UDim2.fromScale(0.03, 0.56),
			Size = UDim2.fromScale(0.62, 0.36),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.White,
			Text = function()
				local now = perkValueText(perk, level())
				if maxed() then
					return `{definition.Description} · most: {now} (MAX)`
				end
				return `{definition.Description} · {now} → {perkValueText(perk, level() + 1)}`
			end,
			create "UIStroke" { Color = Palette.Stroke, Thickness = 2 },
		},
		create "TextButton" {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.98, 0.5),
			Size = UDim2.fromScale(0.28, 0.72),
			BackgroundColor3 = function()
				return if canBuy() then Palette.Money else Palette.Locked
			end,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Palette.White,
			Text = function()
				return if maxed() then "MAX" else `Vásárlás ({tree.TokenCost} token)`
			end,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			create "UIPadding" { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) },
			Activated = function()
				if canBuy() then
					Remotes.BuyPerk:FireServer(perk)
				end
			end,
		},
	}
end

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

-- Haladás a következő rebirth felé (0..1).
function RebirthWindow.progress(state: State): number
	return math.clamp(state.earned() / Formulas.rebirthRequirement(state.rebirths()), 0, 1)
end

-- A következő rebirth jutalmainak listája (szövegek).
local function rewards(rebirths: number): { string }
	local upcoming = rebirths + 1
	local list = {
		`x{Formulas.rebirthMultiplier(upcoming)} pénz (most x{Formulas.rebirthMultiplier(rebirths)})`,
		`+{Config.Rebirth.TokensPerRebirth} Rebirth Token`,
	}
	local slotsNow, slotsNext = Formulas.rebirthSlots(rebirths), Formulas.rebirthSlots(upcoming)
	if slotsNext > slotsNow then
		table.insert(list, `+{slotsNext - slotsNow} sütő slot ({slotsNow} → {slotsNext})`)
	end
	local chefsNow, chefsNext = Formulas.maxChefs(rebirths), Formulas.maxChefs(upcoming)
	if chefsNext > chefsNow then
		table.insert(list, `+{chefsNext - chefsNow} max chef`)
	end
	local soon = Config.Rebirth.ComingSoon[upcoming]
		or (if upcoming % Config.Rebirth.WorldEvery == 0 then "Új világ" else nil)
	if soon then
		table.insert(list, `{soon} (hamarosan)`)
	end
	return list
end

-- Az ablak. `open` vezérli a láthatóságot.
function RebirthWindow.create(open: Source<boolean>, state: State)
	local confirming = source(false)
	local scale = spring(function()
		return if open() then 1 else 0.6
	end, 0.25, 0.55)

	-- bezáráskor a megerősítés visszaáll
	effect(function()
		if not open() then
			confirming(false)
		end
	end)

	local blur = Instance.new("BlurEffect")
	blur.Name = "RebirthBlur"
	blur.Size = 0
	blur.Parent = Lighting
	effect(function()
		blur.Size = if open() then 12 else 0
	end)
	cleanup(blur)

	local function ready(): boolean
		return state.earned() >= Formulas.rebirthRequirement(state.rebirths())
	end

	-- fülek: 1 = Rebirth, 2 = Rebirth-fa
	local tab = source(1)
	local function tabButton(index: number, label: string | () -> string)
		return create "TextButton" {
			Size = UDim2.fromScale(0.42, 1),
			BackgroundColor3 = function()
				return if tab() == index then Palette.Gold else Palette.Locked
			end,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Palette.White,
			Text = label,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			create "UIPadding" { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) },
			Activated = function()
				tab(index)
			end,
		}
	end

	local perkRows = {}
	for order, perk in Config.Rebirth.Tree.Order do
		table.insert(perkRows, perkRow(order, perk, state))
	end

	local rewardLines = {}
	for i = 1, 5 do
		table.insert(
			rewardLines,
			text {
				LayoutOrder = i,
				Size = UDim2.fromScale(1, 0.17),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Money,
				Text = function()
					local line = rewards(state.rebirths())[i]
					return if line then `✔ {line}` else ""
				end,
			}
		)
	end

	return create "Frame" {
		Name = "RebirthWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.6, 0.78),
		BackgroundColor3 = Palette.Panel,
		BackgroundTransparency = 0.1,
		Visible = function()
			return open() or scale() > 0.65
		end,
		ZIndex = 10,

		create "UIScale" { Scale = scale },
		create "UIAspectRatioConstraint" { AspectRatio = 1.15 },
		create "UISizeConstraint" { MaxSize = Vector2.new(760, 660) },
		create "UICorner" { CornerRadius = UDim.new(0.04, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 4 },

		-- Fejléc
		create "Frame" {
			Size = UDim2.fromScale(1, 0.11),
			BackgroundColor3 = Palette.Merge,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },

			text {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1.5, 1.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = "🔄",
			},
			text {
				Position = UDim2.fromScale(0.1, 0.12),
				Size = UDim2.fromScale(0.6, 0.76),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return `Rebirth #{state.rebirths() + 1}`
				end,
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
				create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				Activated = function()
					open(false)
				end,
			},
		},

		-- Fülek: Rebirth | Rebirth-fa
		create "Frame" {
			Position = UDim2.fromScale(0.05, 0.125),
			Size = UDim2.fromScale(0.9, 0.07),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.03, 0),
			},
			tabButton(1, "Rebirth"),
			tabButton(2, function()
				return `Rebirth-fa ({state.tokens()} token)`
			end),
		},

		-- Rebirth-fa oldal
		create "Frame" {
			Position = UDim2.fromScale(0.05, 0.22),
			Size = UDim2.fromScale(0.9, 0.76),
			BackgroundTransparency = 1,
			Visible = function()
				return tab() == 2
			end,
			create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.02, 0),
			},
			perkRows,
		},

		-- Rebirth oldal
		create "Frame" {
			Position = UDim2.fromScale(0.05, 0.22),
			Size = UDim2.fromScale(0.9, 0.76),
			BackgroundTransparency = 1,
			Visible = function()
				return tab() == 1
			end,

			create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.015, 0),
			},

			-- Követelmény + progress
			text {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.08),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					local earned = NumberFormat.money(state.earned())
					local needed = NumberFormat.money(Formulas.rebirthRequirement(state.rebirths()))
					return `Keress ebben a körben: {earned} / {needed}`
				end,
			},
			create "Frame" {
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.05),
				BackgroundColor3 = Palette.Stroke,
				create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
				create "Frame" {
					Size = function()
						return UDim2.fromScale(RebirthWindow.progress(state), 1)
					end,
					BackgroundColor3 = Palette.Lemon,
					create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
				},
			},

			-- Jutalmak
			text {
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.07),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Gold,
				Text = "Jutalom:",
			},
			create "Frame" {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0.3),
				BackgroundTransparency = 1,
				create "UIListLayout" { SortOrder = Enum.SortOrder.LayoutOrder },
				rewardLines,
			},

			-- Mi nullázódik / mi marad
			text {
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0.06),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Danger,
				Text = "Elveszik: pénz, sütők, generáció, eladó, chefek, pult szint",
			},
			text {
				LayoutOrder = 6,
				Size = UDim2.fromScale(1, 0.06),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Lemon,
				Text = function()
					return `Megmarad: tokenek ({state.tokens()}), slotok, Index`
				end,
			},

			-- Gomb (GDD 9.4: a legjobb akció a legnagyobb és legfényesebb)
			create "TextButton" {
				LayoutOrder = 7,
				Size = UDim2.fromScale(0.7, 0.13),
				BackgroundColor3 = function()
					if not ready() then
						return Palette.Locked
					end
					return if confirming() then Palette.Danger else Palette.Money
				end,
				AutoButtonColor = true,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Palette.White,
				Text = function()
					if not ready() then
						local missing = Formulas.rebirthRequirement(state.rebirths()) - state.earned()
						return `Még {NumberFormat.money(missing)}`
					end
					return if confirming() then "Biztos? Kattints újra!" else "REBIRTH!"
				end,
				create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
				create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				create "UIPadding" {
					PaddingTop = UDim.new(0.12, 0),
					PaddingBottom = UDim.new(0.12, 0),
				},
				Activated = function()
					if not ready() then
						return
					end
					if confirming() then
						confirming(false)
						open(false)
						Remotes.RequestRebirth:FireServer()
					else
						confirming(true)
						task.delay(3, function()
							confirming(false)
						end)
					end
				end,
			},
		},
	}
end

-- Rebirth effekt: fehér villanás + nagy felirat (GDD 10). Egy külön ScreenGui-t használ.
function RebirthWindow.playEffect(playerGui: Instance, rebirths: number, multiplier: number)
	local TweenService = game:GetService("TweenService")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthEffect"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.45)
	title.Size = UDim2.fromScale(0.8, 0.16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = `REBIRTH #{rebirths}!  x{multiplier} PÉNZ!`
	title.TextColor3 = Palette.Lemon
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Stroke
	stroke.Thickness = 4
	stroke.Parent = title
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = title
	title.Parent = gui

	gui.Parent = playerGui

	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.2, function()
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		task.delay(0.7, function()
			gui:Destroy()
		end)
	end)
end

return RebirthWindow
