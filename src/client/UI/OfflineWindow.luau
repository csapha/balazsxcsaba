-- Offline kereset ablak (GDD 3.13, 9.4): belépéskor, ha távollétedben keresett a büféd.
-- "Üdv újra!" + összeg + részletek (idő, arány, max idő) + "Felveszem!" gomb (Remotes.ClaimOffline).
-- Döntés (2026-11-12): most csak sima Claim; az x2 / x10 a monetizációval (GDD 6) jön.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local create = vide.create
local spring = vide.spring

local Palette = Config.Palette

type Source<T> = vide.Source<T>

local OfflineWindow = {}

local function duration(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours} óra {minutes} perc`
	end
	return `{minutes} perc`
end

local function text(props: { [any]: any })
	return create "TextLabel" {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,
		create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },
		props,
	}
end

function OfflineWindow.create(offline: Source<{ pending: number, seconds: number }>, data: any)
	local open = function()
		return offline().pending > 0
	end
	local scale = spring(function()
		return if open() then 1 else 0.6
	end, 0.25, 0.55)

	return create "Frame" {
		Name = "OfflineWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.5),
		BackgroundColor3 = Palette.Panel,
		BackgroundTransparency = 0.05,
		Visible = function()
			return open() or scale() > 0.65
		end,
		ZIndex = 20,

		create "UIScale" { Scale = scale },
		create "UIAspectRatioConstraint" { AspectRatio = 1.3 },
		create "UISizeConstraint" { MaxSize = Vector2.new(560, 430) },
		create "UICorner" { CornerRadius = UDim.new(0.06, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 4 },

		-- Fejléc
		create "Frame" {
			Size = UDim2.fromScale(1, 0.16),
			BackgroundColor3 = Palette.Gold,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },
			text {
				Position = UDim2.fromScale(0.05, 0.12),
				Size = UDim2.fromScale(0.9, 0.76),
				Text = "👋 Üdv újra!",
			},
		},

		text {
			Position = UDim2.fromScale(0.05, 0.22),
			Size = UDim2.fromScale(0.9, 0.1),
			Text = "Távollétedben a büféd keresett:",
		},
		text {
			Position = UDim2.fromScale(0.05, 0.34),
			Size = UDim2.fromScale(0.9, 0.22),
			TextColor3 = Palette.Money,
			Text = function()
				return NumberFormat.money(offline().pending)
			end,
		},
		text {
			Position = UDim2.fromScale(0.05, 0.58),
			Size = UDim2.fromScale(0.9, 0.09),
			TextColor3 = Palette.Lemon,
			Text = function()
				local raw = data()
				local rate = math.floor(Formulas.offlineRate(raw) * 100 + 0.5)
				local max = duration(Formulas.offlineMaxSeconds(raw))
				return `{duration(offline().seconds)} · {rate}%-on · max {max}`
			end,
		},

		create "TextButton" {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromScale(0.6, 0.18),
			BackgroundColor3 = Palette.Money,
			AutoButtonColor = true,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Palette.White,
			Text = "Felveszem!",
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
			create "UIPadding" { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) },
			Activated = function()
				Remotes.ClaimOffline:FireServer()
			end,
		},
	}
end

return OfflineWindow
