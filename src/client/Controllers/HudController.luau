-- Minimál HUD: csak a ScreenGui + átmeneti üzenetek (toast).
-- Szándékosan NINCS számláló, shop panel vagy kártya: minden játék-elem
-- a világban van (hotbar Train tool, tárgyak, később világ-beli upgrade pad).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

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
	notifications.Position = UDim2.new(0.5, 0, 0, 16)
	notifications.Size = UDim2.fromOffset(460, 200)
	notifications.BackgroundTransparency = 1
	notifications.Parent = gui

	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
	local notifyRemote = Net.get("Notify")
	if notifyRemote then
		notifyRemote.OnClientEvent:Connect(function(text)
			notify(notifications, text)
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
