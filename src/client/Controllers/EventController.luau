-- Random event visuals (GDD 3.12, 10): a candy banner (UI Kit style) slides down when an event starts,
-- a coloured vignette on the screen edges, a darker picture during the Blackout; event rewards
-- (+$, Food Critic) float above your head. (The "Next event" timer is on the HUD.)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = script.Parent.Parent.UI
local Audio = require(UI.Audio)
local Kit = require(UI.Kit)
local Theme = require(UI.Theme)

local create = Vide.create
local C = Theme.Colors

local EventController = {}

local gui: ScreenGui
local vignettes: { Frame } = {}
local darkness: ColorCorrectionEffect

local BANNER_W = 620
local BANNER_H = 100
local BANNER_TOP = 104 -- below the HUD's top bar

-- Each event gets a candy palette from its colour (Kit plates look palettes up by name).
for id, event in Config.Events.List do
	Theme.Palettes["Event" .. id] = Theme.paletteFrom(event.Color)
end

-- Banner sliding down from the top: icon + name + description, then it slides back up.
local function showBanner(id: string, config: any)
	local holder: Frame
	local destroy = Vide.root(function()
		holder = create "Frame" {
			Name = "EventBanner",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(BANNER_W, BANNER_H),
			BackgroundTransparency = 1,
			Parent = gui,
			Kit.scale(),
			Kit.plate {
				Name = "Plate",
				Color = "Event" .. id,
				Text = "",
				Size = UDim2.fromOffset(BANNER_W, BANNER_H),
				create "TextLabel" {
					Name = "Icon",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 14, 0.5, -4),
					Size = UDim2.fromOffset(64, 64),
					BackgroundTransparency = 1,
					Text = config.Icon,
					TextScaled = true,
					Rotation = -8,
					ZIndex = 6,
				},
				Kit.text {
					Name = "Title",
					Text = `{string.upper(config.Name)}!`,
					TextSize = 40,
					StrokeThickness = 4,
					Position = UDim2.fromOffset(84, 8),
					Size = UDim2.new(1, -100, 0, 46),
					ZIndex = 6,
				},
				Kit.text {
					Name = "Description",
					Text = config.Description,
					TextSize = 19,
					Gradient = false,
					TextWrapped = true,
					Position = UDim2.fromOffset(84, 54),
					Size = UDim2.new(1, -100, 0, 34),
					ZIndex = 6,
				},
			},
		} :: Frame
	end)

	Audio.play("Stinger")
	TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BANNER_TOP),
	}):Play()
	task.delay(0.35, function()
		if holder.Parent then
			Kit.burst(holder, UDim2.fromOffset(46, BANNER_H / 2), Theme.Palettes["Event" .. id].light, 12, 1.2)
		end
	end)
	task.delay(3.6, function()
		local out = TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 0),
		})
		out.Completed:Once(function()
			destroy()
			holder:Destroy()
		end)
		out:Play()
	end)
end

local function onActiveChanged()
	local id = EventState.active()
	local config = EventState.config()
	for _, vignette in vignettes do
		if config then
			vignette.BackgroundColor3 = config.Color
		end
		TweenService:Create(vignette, TweenInfo.new(if config then 0.5 else 0.8), {
			BackgroundTransparency = if config then 0.25 else 1,
		}):Play()
	end
	if id and config then
		showBanner(id, config)
	end

	local blackout = EventState.is("Blackout")
	TweenService:Create(darkness, TweenInfo.new(0.6), {
		Brightness = if blackout then -0.3 else 0,
		Saturation = if blackout then -0.4 else 0,
	}):Play()
end

-- Reward text above your head, floating up (fixed pixel size, like the HUD).
local function onReward(message: string, color: Color3?)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local billboard: BillboardGui, label: TextLabel
	local destroy = Vide.root(function()
		label = Kit.text {
			Text = message,
			TextSize = 32,
			StrokeThickness = 3.5,
			TextColor3 = color or C.Money,
			Size = UDim2.fromScale(1, 1),
		}
		billboard = create "BillboardGui" {
			Name = "EventReward",
			Size = UDim2.fromOffset(460, 44),
			StudsOffset = Vector3.new(math.random(-10, 10) / 10, 3, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Adornee = head,
			label,
		} :: BillboardGui
	end)
	billboard.Parent = head
	Audio.play("Coins")

	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	Ui.fadeText(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1))
	task.delay(1.6, function()
		destroy()
		billboard:Destroy()
	end)
end

function EventController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "Events"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- vignette: coloured on the screen edges, clear in the middle (a horizontal and a vertical layer)
	for _, rotation in { 0, 90 } do
		local vignette = Instance.new("Frame")
		vignette.Size = UDim2.fromScale(1, 1)
		vignette.BackgroundTransparency = 1
		vignette.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.12, 1),
			NumberSequenceKeypoint.new(0.88, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		gradient.Parent = vignette
		vignette.Parent = gui
		table.insert(vignettes, vignette)
	end

	darkness = Instance.new("ColorCorrectionEffect")
	darkness.Name = "EventDarkness"
	darkness.Parent = Lighting

	EventState.instance:GetAttributeChangedSignal("Active"):Connect(onActiveChanged)
	Remotes.EventReward.OnClientEvent:Connect(onReward)
	if EventState.active() then
		onActiveChanged()
	end
end

return EventController
