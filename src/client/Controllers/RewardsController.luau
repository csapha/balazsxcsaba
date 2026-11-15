-- TopbarPlus "Rewards" ikon (GDD 8): a napi jutalom és a playtime ajándékok közös ablakát (UI/RewardsWindow,
-- két fül) nyitja / zárja; ha az ablak máshonnan zárul, az ikon is kiold.
-- Piros értesítés, amíg bármelyik fülön van felvehető jutalom (kioldásra nem tűnik el, csak felvételkor).
-- Felirat: "Claim!", ha van felvehető; különben a következő playtime ajándékig hátralévő idő; ha mára minden
-- ajándék nyitva van: "Rewards".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local Ui = require(ReplicatedStorage.Shared.Ui)
local UI = script.Parent.Parent.UI
local RewardsWindow = require(UI.RewardsWindow)
local State = require(UI.State)

local WINDOW = "Rewards"

local RewardsController = {}

function RewardsController.init()
	local Icon = require(ReplicatedStorage.Packages.TopbarPlus)
	Vide.root(function()
		local icon = Icon.new()
		icon:setName(WINDOW)
		icon:setImage(Ui.Icons.Gift)
		icon:setCaption("Daily Rewards and Playtime Gifts")
		icon:align("Left")
		icon:setOrder(1) -- a Settings ikon elé
		icon.selected:Connect(function()
			State.window(WINDOW)
		end)
		icon.deselected:Connect(function()
			if State.window() == WINDOW then
				State.window(nil)
			end
		end)
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

		-- saját törlő esemény: a TopbarPlus alapból kioldáskor törölné az értesítést, de az addig marad,
		-- amíg a jutalmat fel nem vette (az anyReady() hamisra vált)
		local never = Instance.new("BindableEvent")
		local noticed = false
		Vide.effect(function()
			local want = State.loaded() and RewardsWindow.anyReady()
			if want ~= noticed then
				noticed = want
				if want then
					icon:notify(never.Event)
				else
					icon:clearNotices()
				end
			end
		end)

		local label = ""
		Vide.effect(function()
			local text = "Rewards"
			if State.loaded() then
				local _, remaining = RewardsWindow.giftStatus()
				if RewardsWindow.anyReady() then
					text = "Claim!"
				elseif remaining then
					text = RewardsWindow.duration(remaining)
				end
			end
			if text ~= label then
				label = text
				icon:setLabel(text)
			end
		end)
	end)
end

return RewardsController
