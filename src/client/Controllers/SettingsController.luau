-- TopbarPlus "Settings" ikon: nyitja / zárja a beállítások ablakát (UI/SettingsWindow, Settings + Codes fül).
-- Ha az ablak máshonnan zárul (X, másik ablak), az ikon is kiold. A Rewards ikon után áll (setOrder).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local Ui = require(ReplicatedStorage.Shared.Ui)
local State = require(script.Parent.Parent.UI.State)

local WINDOW = "Settings"

local SettingsController = {}

function SettingsController.init()
	local Icon = require(ReplicatedStorage.Packages.TopbarPlus)
	local icon = Icon.new()
	icon:setName(WINDOW)
	icon:setImage(Ui.Icons.Settings)
	icon:setCaption("Settings and Codes")
	icon:align("Left")
	icon:setOrder(2)
	icon.selected:Connect(function()
		State.window(WINDOW)
	end)
	icon.deselected:Connect(function()
		if State.window() == WINDOW then
			State.window(nil)
		end
	end)
	Vide.root(function()
		Vide.effect(function()
			local open = State.window() == WINDOW
			if open ~= icon.isSelected then
				if open then
					icon:select()
				else
					icon:deselect()
				end
			end
		end)
	end)
end

return SettingsController
