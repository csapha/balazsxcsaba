-- TopbarPlus "Pass" ikon (GDD 6.4 Schnitzel Pass): a Rewards és a Settings ikon között, a Pass ablakot
-- (UI/SeasonPassWindow) nyitja / zárja; ha az ablak máshonnan zárul, az ikon is kiold.
-- Felirat: "Claim!", ha van felvehető jutalom, különben "Tier 7". Piros értesítés, amíg van felvehető jutalom.
-- A tutorial fő lépései alatt nem látszik (mint a bal oldali menü gombjai, UI/Tutorial.revealed), és ha a szezon
-- nem fut (élesben), sem. Új szintnél csilingel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Ui = require(ReplicatedStorage.Shared.Ui)
local UI = script.Parent.Parent.UI
local Audio = require(UI.Audio)
local SeasonPassWindow = require(UI.SeasonPassWindow)
local State = require(UI.State)
local Tutorial = require(UI.Tutorial)

local WINDOW = "SeasonPass"

local SeasonPassController = {}

function SeasonPassController.init()
	local Icon = require(ReplicatedStorage.Packages.TopbarPlus)
	Vide.root(function()
		local icon = Icon.new()
		icon:setName("Pass")
		icon:setImage(Ui.Icons.SeasonPass)
		icon:setCaption("Schnitzel Pass")
		icon:align("Left")
		icon:setOrder(2) -- a Rewards után, a Settings előtt
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

		local shown = true
		Vide.effect(function()
			local want = State.loaded() and SeasonPassWindow.active() and Tutorial.revealed("Pass")
			if want ~= shown then
				shown = want
				icon:setEnabled(want)
			end
		end)

		-- saját törlő esemény: az értesítés addig marad, amíg a jutalmat fel nem vette
		local never = Instance.new("BindableEvent")
		local noticed = false
		Vide.effect(function()
			local want = State.loaded() and SeasonPassWindow.readyCount() > 0
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
			local text = "Pass"
			if State.loaded() then
				text = if SeasonPassWindow.readyCount() > 0 then "Claim!" else `Tier {SeasonPassWindow.tier()}`
			end
			if text ~= label then
				label = text
				icon:setLabel(text)
			end
		end)
	end)

	Remotes.SeasonTier.OnClientEvent:Connect(function()
		Audio.play("Chime")
	end)
end

return SeasonPassController
