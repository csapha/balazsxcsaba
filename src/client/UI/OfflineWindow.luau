-- Offline earnings window (GDD 3.13): shown on join when your shop earned money while you were away.
-- "Welcome back!" + amount + details (time away, rate, max time) + "Collect!" (Remotes.ClaimOffline).
-- For now a plain claim; the x2 / x10 options come with monetisation (GDD 6).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
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
local C = Theme.Colors

local OfflineWindow = {}

local function duration(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

function OfflineWindow.render(anim: Motion.Anim)
	return Kit.window {
		Name = "Offline",
		Title = "Welcome back!",
		Color = "Orange",
		Icon = Ui.Icons.CoinChest,
		Size = UDim2.fromOffset(480, 330),
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = function()
			Remotes.ClaimOffline:FireServer()
		end,
		Body = {
			create "UIListLayout" {
				Padding = UDim.new(0, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Kit.text {
				LayoutOrder = 1,
				Text = "Your shop earned while you were away:",
				TextSize = 20,
				TextColor3 = C.Muted,
				Gradient = false,
				Size = UDim2.new(1, 0, 0, 24),
			},
			create "Frame" {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "ImageLabel" {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(60, 60),
					BackgroundTransparency = 1,
					Image = Ui.Icons.CoinBag,
					ScaleType = Enum.ScaleType.Fit,
				},
				Kit.text {
					LayoutOrder = 2,
					Text = function()
						return NumberFormat.money(State.offline().pending)
					end,
					TextSize = 56,
					StrokeThickness = 4,
					StrokeColor = C.MoneyStroke,
					Gradient = ColorSequence.new(C.MoneyTop, C.MoneyBottom),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 64),
				},
			},
			Kit.text {
				LayoutOrder = 3,
				Text = function()
					local raw = State.data()
					local rate = math.floor(Formulas.offlineRate(raw) * 100 + 0.5)
					local max = duration(Formulas.offlineMaxSeconds(raw))
					return `Away {duration(State.offline().seconds)}, {rate}% rate, max {max}`
				end,
				TextSize = 18,
				TextColor3 = C.Lemon,
				Gradient = false,
				Size = UDim2.new(1, 0, 0, 22),
			},
			create "Frame" {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
			},
			Kit.button {
				Name = "Collect",
				LayoutOrder = 5,
				Size = UDim2.fromOffset(260, 56),
				TextSize = 28,
				Color = "Green",
				Text = "COLLECT!",
				Activated = function()
					Audio.play("Coins")
					Remotes.ClaimOffline:FireServer()
				end,
			},
		},
	}
end

return OfflineWindow
