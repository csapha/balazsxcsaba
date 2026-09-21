-- Minimál HUD: ScreenGui + átmeneti üzenetek (toast) + felső középső cash kijelző.
-- Szándékosan NINCS számláló panel: minden játék-elem a világban van
-- (hotbar Train tool, tárgyak, később világ-beli upgrade pad).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)
local UiIcons = require(Shared.UiIcons)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local HudController = {}

local toasts = {}

local function layoutNotifications()
	for index, toast in ipairs(toasts) do
		toast.Position = UDim2.fromOffset(0, (index - 1) * 30)
	end
end

local function notify(container, text)
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, 28)
	toast.BorderSizePixel = 0
	toast.ZIndex = 201
	toast.Parent = container
	Ui.applyFadeBackground(toast, 0.2)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextSize = 17
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.ZIndex = 202
	label.Parent = toast
	Ui.applyDisplay(label)

	local textGradient = Ui.applyTextGradient(label)
	textGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})

	table.insert(toasts, toast)
	layoutNotifications()

	task.spawn(function()
		task.wait(2.6)
		local index = table.find(toasts, toast)
		if index then
			table.remove(toasts, index)
			layoutNotifications()
		end
		toast:Destroy()
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
	notifications.Position = UDim2.new(0.5, 0, 0, 74)
	notifications.Size = UDim2.fromOffset(460, 200)
	notifications.BackgroundTransparency = 1
	notifications.ZIndex = 200
	notifications.Parent = gui

	-- Felső középső cash kijelző: kis, lágy (középen fekete, szélein áttűnő) háttér.
	local cashBar = Instance.new("Frame")
	cashBar.Name = "CashBar"
	cashBar.AnchorPoint = Vector2.new(0.5, 0)
	cashBar.Position = UDim2.new(0.5, 0, 0, 8)
	cashBar.Size = UDim2.fromOffset(0, 0)
	cashBar.AutomaticSize = Enum.AutomaticSize.XY
	cashBar.BorderSizePixel = 0
	cashBar.Parent = gui
	Ui.applyFadeBackground(cashBar, 0.4)

	local cashPadding = Instance.new("UIPadding")
	cashPadding.PaddingLeft = UDim.new(0, 24)
	cashPadding.PaddingRight = UDim.new(0, 24)
	cashPadding.PaddingTop = UDim.new(0, 6)
	cashPadding.PaddingBottom = UDim.new(0, 6)
	cashPadding.Parent = cashBar

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromOffset(0, 34)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.BackgroundTransparency = 1
	content.Parent = cashBar

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.Parent = content

	local coin = UiIcons.create(content, "coin", UDim2.fromOffset(34, 34), UDim2.fromOffset(0, 0), 2)
	coin.LayoutOrder = 1

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.LayoutOrder = 2
	cashLabel.BackgroundTransparency = 1
	cashLabel.Size = UDim2.fromOffset(0, 34)
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextSize = 26
	cashLabel.Text = Format.money(0)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	cashLabel.TextStrokeTransparency = 0
	cashLabel.Parent = content
	local cashGradient = Ui.applyTextGradient(cashLabel)
	cashGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 145, 155)),
	})
	cashGradient.Rotation = 90

	local notifyRemote = Net.get("Notify")
	if notifyRemote then
		notifyRemote.OnClientEvent:Connect(function(text)
			notify(notifications, text)
		end)
	end

	local dataChanged = Net.get("DataChanged")
	if dataChanged then
		dataChanged.OnClientEvent:Connect(function(snapshot)
			if type(snapshot) == "table" and snapshot.cash then
				cashLabel.Text = Format.money(snapshot.cash)
			end
		end)
	end

	return {
		gui = gui,
		notify = function(text)
			notify(notifications, text)
		end,
	}
end

return HudController
