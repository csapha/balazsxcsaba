-- Minimál HUD: csak a ScreenGui + átmeneti üzenetek (toast).
-- Szándékosan NINCS számláló, shop panel vagy kártya: minden játék-elem
-- a világban van (hotbar Train tool, tárgyak, később világ-beli upgrade pad).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local HudController = {}

local notifyLabels = {}

local function layoutNotifications()
	for index, label in ipairs(notifyLabels) do
		label.Position = UDim2.fromOffset(0, (index - 1) * 30)
	end
end

local function notify(container, text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = container
	Ui.applyBody(label)

	table.insert(notifyLabels, label)
	layoutNotifications()

	task.spawn(function()
		task.wait(2.6)
		local index = table.find(notifyLabels, label)
		if index then
			table.remove(notifyLabels, index)
			layoutNotifications()
		end
		label:Destroy()
	end)
end

function HudController.init()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "SqueezeHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local notifications = Instance.new("Frame")
	notifications.Name = "Notifications"
	notifications.AnchorPoint = Vector2.new(0.5, 0)
	notifications.Position = UDim2.new(0.5, 0, 0, 16)
	notifications.Size = UDim2.fromOffset(460, 200)
	notifications.BackgroundTransparency = 1
	notifications.Parent = gui

	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
	local notifyRemote = Net.get("Notify")
	if notifyRemote then
		notifyRemote.OnClientEvent:Connect(function(text, color)
			notify(notifications, text, typeof(color) == "Color3" and color or nil)
		end)
	end

	return {
		gui = gui,
		notify = function(text, color)
			notify(notifications, text, color)
		end,
	}
end

return HudController
