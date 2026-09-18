-- Effektek: színes sparkle ütésnél, neon "pop" + sparkle felvételnél,
-- és lebegő "+1 Név" szöveg.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ores = require(Shared.Config.Ores)
local Net = require(Shared.Net)

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local EffectsController = {}

-- színes szikra-burst
local function sparkleBurst(position, color, count, speed, size)
	local part = Instance.new("Part")
	part.Name = "FxSparkle"
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
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(speed, speed + 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new(size)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	emitter:Emit(count)

	task.delay(1.4, function()
		part:Destroy()
	end)
end

-- neon gömb, ami gyorsan kitágul és eltűnik (felvétel)
local function popGlow(position, color)
	local glow = Instance.new("Part")
	glow.Name = "FxPop"
	glow.Shape = Enum.PartType.Ball
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Size = Vector3.new(0.5, 0.5, 0.5)
	glow.Transparency = 0.15
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	glow.CFrame = CFrame.new(position)
	glow.Parent = Workspace

	local tween = TweenService:Create(
		glow,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		glow:Destroy()
	end)
end

local function floatingText(position, text, color)
	local anchor = Instance.new("Part")
	anchor.Name = "FxText"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 32)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	task.spawn(function()
		local riseTween = TweenService:Create(
			anchor,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }
		)
		riseTween:Play()

		task.wait(0.45)

		local fadeTween = TweenService:Create(
			label,
			TweenInfo.new(0.4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		fadeTween:Play()
		fadeTween.Completed:Wait()

		anchor:Destroy()
	end)
end

function EffectsController.init()
	local minedRemote = Net.get("OreMined")
	if minedRemote then
		minedRemote.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			local ore = Ores.byId[payload.oreId]
			if not ore or not payload.position then
				return
			end
			local color = Color3.fromHex(ore.color)
			sparkleBurst(payload.position, color, 18, 5, 0.3)
			floatingText(payload.position, "+1 " .. ore.name, color)
		end)
	end

	local pickedRemote = Net.get("OrePicked")
	if pickedRemote then
		pickedRemote.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			local ore = Ores.byId[payload.oreId]
			if not ore or not payload.position then
				return
			end
			local color = Color3.fromHex(ore.color)
			popGlow(payload.position, color)
			sparkleBurst(payload.position, color, 14, 3, 0.24)
		end)
	end
end

return EffectsController
