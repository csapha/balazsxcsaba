-- Full-screen reveal effects in the UI Kit style (GDD 10):
--   rebirth (white flash + big "x3 MONEY!"), egg reveal (shaking egg → burst → pet card), aura roll (spinning names).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local PetsWindow = require(script.Parent.PetsWindow)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local C = Theme.Colors

local Effects = {}

-- Builds Kit elements inside a Vide root; the root is destroyed together with the overlay.
local roots: { [ScreenGui]: { () -> () } } = {}
local function build(gui: ScreenGui, fn: () -> ())
	table.insert(roots[gui], (Vide.root(fn)))
end

local function overlay(playerGui: Instance, name: string, dim: number?): (ScreenGui, Frame, () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	roots[gui] = {}
	local stage: Frame
	build(gui, function()
		create "Frame" {
			Name = "Dim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = dim or 1,
			BorderSizePixel = 0,
			Parent = gui,
		}
		-- a fixed 1000×700 stage in the middle, scaled with the screen like the HUD
		stage = create "Frame" {
			Name = "Stage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1000, 700),
			BackgroundTransparency = 1,
			Parent = gui,
			Kit.scale(),
		} :: Frame
	end)
	gui.Parent = playerGui
	return gui, stage, function()
		for _, destroy in roots[gui] do
			destroy()
		end
		roots[gui] = nil
		gui:Destroy()
	end
end

local function spin(instance: GuiObject, seconds: number)
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = 360,
	}):Play()
end

local function sunburst(parent: Instance, color: Color3, size: number): ImageLabel
	local rays = Instance.new("ImageLabel")
	rays.Name = "Sunburst"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.46)
	rays.Size = UDim2.fromOffset(size, size)
	rays.BackgroundTransparency = 1
	rays.Image = Ui.Textures.Sunburst
	rays.ImageColor3 = color
	rays.ImageTransparency = 0.45
	rays.Parent = parent
	spin(rays, 14)
	return rays
end

local function popIn(instance: GuiObject, from: number?, to: number?, time: number?): UIScale
	local scale = Instance.new("UIScale")
	scale.Scale = from or 0.3
	scale.Parent = instance
	TweenService:Create(scale, TweenInfo.new(time or 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = to or 1 }):Play()
	return scale
end

local function fadeOut(root: Instance, time: number)
	local info = TweenInfo.new(time)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
	end
end

-- Rebirth: white flash + "REBIRTH #n!" + "xN MONEY!".
function Effects.rebirth(playerGui: Instance, rebirths: number, multiplier: number)
	local gui, stage, destroy = overlay(playerGui, "RebirthEffect")
	Audio.play("Victory")
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = C.White
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()

	sunburst(stage, Theme.Palettes.Green.top, 620)
	local title, subtitle
	build(gui, function()
		title = Kit.text {
			Text = `REBIRTH #{rebirths}!`,
			TextSize = 72,
			StrokeThickness = 5,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(800, 84),
			ZIndex = 3,
			Parent = stage,
		}
		subtitle = Kit.text {
			Text = `x{multiplier} MONEY!`,
			TextSize = 60,
			StrokeThickness = 5,
			StrokeColor = C.MoneyStroke,
			Gradient = ColorSequence.new(C.MoneyTop, C.MoneyBottom),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromOffset(800, 70),
			ZIndex = 3,
			Parent = stage,
		}
	end)
	popIn(title, 0.3, 1, 0.5)
	task.delay(0.15, function()
		popIn(subtitle, 0.3, 1, 0.5)
		Audio.play("Coins")
		Kit.burst(stage, UDim2.fromScale(0.5, 0.5), C.Lemon, 16, 2.2)
	end)
	task.delay(2.4, function()
		fadeOut(gui, 0.5)
		task.delay(0.55, destroy)
	end)
end

-- Egg reveal: the egg shakes, bursts open, the pet card pops out in its rarity colour.
function Effects.eggReveal(playerGui: Instance, eggIndex: number, petId: string)
	local egg = Config.Pets.Eggs[eggIndex]
	local pet = Config.Pets.List[petId]
	if not egg or not pet then
		return
	end
	local rarity = Config.Pets.Rarities[pet.Rarity]
	local gui, stage, destroy = overlay(playerGui, "EggReveal")

	local eggFrame = Instance.new("Frame")
	eggFrame.Name = "Egg"
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.Position = UDim2.fromScale(0.5, 0.48)
	eggFrame.Size = UDim2.fromOffset(150, 190)
	eggFrame.BackgroundColor3 = egg.Color
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = eggFrame
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Ink
	stroke.Thickness = 4
	stroke.Parent = eggFrame
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	shade.Parent = eggFrame
	eggFrame.Parent = stage
	popIn(eggFrame, 0.4, 1, 0.35)

	task.spawn(function()
		for i = 1, 14 do
			eggFrame.Rotation = (if i % 2 == 0 then 1 else -1) * (4 + i)
			if i % 3 == 0 then
				Audio.play("Tick")
			end
			task.wait(0.06)
		end
		eggFrame:Destroy()
		Audio.play(if rarity.Announce then "Golden" else "Chime")

		sunburst(stage, rarity.Color, 520)
		Kit.burst(stage, UDim2.fromScale(0.5, 0.46), rarity.Color, 18, 2)
		local card
		build(gui, function()
			card = create "Frame" {
				Name = "PetCard",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.fromOffset(300, 300),
				BackgroundTransparency = 1,
				ZIndex = 2,
				Parent = stage,
				PetsWindow.avatar(pet.Color, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 22),
					Size = UDim2.fromOffset(140, 140),
					ZIndex = 3,
				}),
				Kit.text {
					Text = pet.Name,
					TextSize = 32,
					Position = UDim2.fromOffset(10, 172),
					Size = UDim2.new(1, -20, 0, 36),
					ZIndex = 3,
				},
				Kit.text {
					Text = string.upper(rarity.Name),
					TextSize = 22,
					TextColor3 = rarity.Color,
					Gradient = false,
					Position = UDim2.fromOffset(10, 210),
					Size = UDim2.new(1, -20, 0, 26),
					ZIndex = 3,
				},
				Kit.text {
					Text = PetsWindow.bonusText(petId, false),
					TextSize = 24,
					TextColor3 = C.Good,
					Gradient = false,
					Position = UDim2.fromOffset(10, 244),
					Size = UDim2.new(1, -20, 0, 28),
					ZIndex = 3,
				},
			}
		end)
		popIn(card, 0.3, 1, 0.45)
		task.wait(2.2)
		fadeOut(gui, 0.35)
		task.wait(0.4)
		destroy()
	end)
end

-- Aura roll: names flicker faster → slower, then the result pops in its rarity colour with "NEW!" / "Lv n!".
function Effects.auraRoll(playerGui: Instance, id: string, level: number, isNew: boolean)
	local aura = Config.Auras.List[id]
	if not aura then
		return
	end
	local rarity = Config.Auras.Rarities[aura.Rarity]
	local gui, stage, destroy = overlay(playerGui, "AuraRoll")
	local label, sub
	build(gui, function()
		label = Kit.text {
			Text = "",
			TextSize = 64,
			StrokeThickness = 5,
			Gradient = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromOffset(800, 76),
			ZIndex = 3,
			Parent = stage,
		}
		sub = Kit.text {
			Text = "",
			TextSize = 32,
			Gradient = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(600, 40),
			ZIndex = 3,
			Parent = stage,
		}
	end)
	task.spawn(function()
		for i = 1, 14 do
			local other = Config.Auras.List[Config.Auras.Order[math.random(1, #Config.Auras.Order)]]
			label.Text = other.Name
			label.TextColor3 = Config.Auras.Rarities[other.Rarity].Color
			Audio.play("Tick")
			task.wait(0.04 + i * 0.012)
		end
		label.Text = aura.Name
		label.TextColor3 = rarity.Color
		sub.Text = if isNew then `NEW! ({rarity.Name})` else `Lv {level}! ({rarity.Name})`
		sub.TextColor3 = if isNew then C.Lemon else C.Good
		Audio.play(if rarity.Announce then "Golden" else "Ding")
		sunburst(stage, rarity.Color, 480)
		Kit.burst(stage, UDim2.fromScale(0.5, 0.46), rarity.Color, 16, 2)
		popIn(label, 0.6, 1.1, 0.4)
		popIn(sub, 0.4, 1, 0.4)
		task.wait(1.8)
		fadeOut(gui, 0.35)
		task.wait(0.4)
		destroy()
	end)
end

return Effects
