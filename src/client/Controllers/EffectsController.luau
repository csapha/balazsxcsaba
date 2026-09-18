-- Effektek: lebegő szövegek és színes részecske-robbanás.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local EffectsController = {}

function EffectsController.burst(position, color, count)
	local part = Instance.new("Part")
	part.Name = "FxBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new(0.35)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	emitter:Emit(count or 22)

	task.delay(1.5, function()
		part:Destroy()
	end)
end

function EffectsController.floatingText(position, text, color)
	local anchor = Instance.new("Part")
	anchor.Name = "FxText"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0))
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(280, 62)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	-- csak a szöveg, háttér nélkül
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 34
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
	Ui.applyDisplay(label)
	Ui.applyTextGradient(label)
	if color then
		label.TextColor3 = color
	end

	task.spawn(function()
		local rise = TweenService:Create(
			anchor,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = anchor.CFrame + Vector3.new(0, 2.6, 0) }
		)
		rise:Play()

		task.wait(0.4)

		local textFade = TweenService:Create(label, TweenInfo.new(0.4), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		textFade:Play()
		textFade.Completed:Wait()
		anchor:Destroy()
	end)
end

function EffectsController.dust(position)
	local part = Instance.new("Part")
	part.Name = "FxDust"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position - Vector3.new(0, 2.2, 0))
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	emitter.Lifetime = NumberRange.new(0.3, 0.5)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	emitter:Emit(8)

	task.delay(1, function()
		part:Destroy()
	end)
end

function EffectsController.init()
	-- egyelőre minden effekt kliens-oldali (a kontrollerek hívják)
end

return EffectsController
