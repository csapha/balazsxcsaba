-- Effektek: lebegő szövegek és színes részecske-robbanás.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local EffectsController = {}

local INNER_COLORS = {
	watermelon = Color3.fromRGB(236, 55, 71),
	coconut = Color3.fromRGB(245, 239, 218),
	tire = Color3.fromRGB(24, 27, 31),
	anvil = Color3.fromRGB(165, 177, 181),
	fridge = Color3.fromRGB(224, 239, 240),
	car = Color3.fromRGB(128, 33, 29),
	tank = Color3.fromRGB(92, 105, 64),
	boulder = Color3.fromRGB(118, 118, 118),
}

local FRAGMENT_MATERIALS = {
	tire = Enum.Material.Rubber,
	anvil = Enum.Material.Metal,
	fridge = Enum.Material.Metal,
	car = Enum.Material.Metal,
	tank = Enum.Material.Metal,
	boulder = Enum.Material.Slate,
}

function EffectsController.shatter(position, object)
	local random = Random.new()
	local objectSize = math.max(tonumber(object.size) or 2, 1)
	local count = math.clamp(9 + math.floor(objectSize * 1.5), 10, 18)
	local shellColor = Color3.fromHex(object.color)
	local innerColor = INNER_COLORS[object.id] or shellColor:Lerp(Color3.new(1, 1, 1), 0.18)
	local material = FRAGMENT_MATERIALS[object.id] or Enum.Material.SmoothPlastic

	for index = 1, count do
		local fragment = index % 3 == 0 and Instance.new("WedgePart") or Instance.new("Part")
		fragment.Name = "SqueezeFragment"
		local scale = objectSize * random:NextNumber(0.075, 0.16)
		fragment.Size = Vector3.new(
			scale * random:NextNumber(0.65, 1.35),
			scale * random:NextNumber(0.45, 1.05),
			scale * random:NextNumber(0.65, 1.35)
		)
		if fragment:IsA("Part") and index % 4 == 0 then
			fragment.Shape = Enum.PartType.Ball
		end
		fragment.Color = index % 3 == 0 and shellColor or innerColor
		fragment.Material = material
		fragment.Anchored = false
		fragment.CanCollide = false
		fragment.CanTouch = false
		fragment.CanQuery = false
		fragment.CastShadow = true
		fragment.CFrame = CFrame.new(position + Vector3.new(
			random:NextNumber(-0.18, 0.18) * objectSize,
			random:NextNumber(-0.08, 0.18) * objectSize,
			random:NextNumber(-0.18, 0.18) * objectSize
		)) * CFrame.Angles(
			random:NextNumber(-math.pi, math.pi),
			random:NextNumber(-math.pi, math.pi),
			random:NextNumber(-math.pi, math.pi)
		)
		fragment.Parent = Workspace

		local outward = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(0.45, 1.15),
			random:NextNumber(-1, 1)
		).Unit
		fragment.AssemblyLinearVelocity = outward * random:NextNumber(7, 12 + objectSize)
		fragment.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-12, 12),
			random:NextNumber(-12, 12),
			random:NextNumber(-12, 12)
		)

		task.delay(0.65, function()
			if fragment.Parent then
				TweenService:Create(
					fragment,
					TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Transparency = 1, Size = fragment.Size * 0.55 }
				):Play()
			end
		end)
		task.delay(1.3, function()
			fragment:Destroy()
		end)
	end
end

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
	local textGradient = Ui.applyTextGradient(label)
	if color then
		textGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.4)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.25)),
		})
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
