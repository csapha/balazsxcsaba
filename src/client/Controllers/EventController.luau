-- Random event vizuál (GDD 3.12, 10): induláskor felülről lecsúszó banner, színes vignetta a
-- képernyő szélén, Áramszünetnél sötétebb kép; event jutalmak (+$, Ételkritikus) felirata a fej felett.
-- (A "Következő esemény" időzítő a HUD-on van.)
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Palette = Config.Palette

local EventController = {}

local gui: ScreenGui
local vignettes: { Frame } = {}
local darkness: ColorCorrectionEffect

local function label(parent: Instance, textValue: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = position
	text.Size = size
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = textValue
	text.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Stroke
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = parent
	return text
end

-- Felülről lecsúszó banner: ikon + név + leírás, majd visszacsúszik.
local function showBanner(config: any)
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.fromScale(0.5, 0)
	banner.Size = UDim2.fromScale(0.5, 0.14)
	banner.BackgroundColor3 = config.Color
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Stroke
	stroke.Thickness = 4
	stroke.Parent = banner
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(720, 130)
	constraint.Parent = banner

	label(banner, `{config.Icon} {string.upper(config.Name)}!`, Palette.White, UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.92, 0.5))
	label(banner, config.Description, Palette.White, UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.92, 0.32))
	banner.Parent = gui

	local info = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(banner, info, { Position = UDim2.new(0.5, 0, 0, 150) }):Play()
	task.delay(3.2, function()
		local out = TweenService:Create(banner, TweenInfo.new(0.35), { Position = UDim2.fromScale(0.5, 0) })
		out.Completed:Once(function()
			banner:Destroy()
		end)
		out:Play()
	end)
end

local function onActiveChanged()
	local config = EventState.config()
	for _, vignette in vignettes do
		if config then
			vignette.BackgroundColor3 = config.Color
		end
		TweenService:Create(vignette, TweenInfo.new(if config then 0.5 else 0.8), {
			BackgroundTransparency = if config then 0.25 else 1,
		}):Play()
	end
	if config then
		showBanner(config)
	end

	local blackout = EventState.is("Blackout")
	TweenService:Create(darkness, TweenInfo.new(0.6), {
		Brightness = if blackout then -0.3 else 0,
		Saturation = if blackout then -0.4 else 0,
	}):Play()
end

-- Jutalom felirat a fej felett, felfelé úszva.
local function onReward(message: string, color: Color3?)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 1.4)
	billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = head
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Text = message
	textLabel.TextColor3 = color or Palette.Money
	textLabel.TextStrokeColor3 = Palette.Stroke
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = billboard
	billboard.Parent = head

	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(textLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.6, function()
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
	gui.Parent = playerGui

	-- vignetta: a képernyő szélein színes, középen átlátszó (vízszintes + függőleges réteg)
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
