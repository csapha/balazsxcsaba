-- Alap Vide HUD, hogy látszódjon, működik a Vide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)

local create = vide.create

local Hud = {}

function Hud.mount()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	vide.mount(function()
		return create "ScreenGui" {
			Name = "Hud",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,

			create "TextLabel" {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(260, 44),
				BackgroundColor3 = Color3.fromRGB(40, 28, 20),
				BackgroundTransparency = 0.2,
				Font = Enum.Font.FredokaOne,
				TextColor3 = Color3.fromRGB(255, 214, 120),
				TextScaled = true,
				Text = Config.GameName,

				create "UICorner" { CornerRadius = UDim.new(0, 12) },
				create "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				},
			},
		}
	end, playerGui)
end

return Hud
