-- Per-player zone gates. Locked gates are visible/collidable locally; gates
-- disappear as soon as the server snapshot marks their target zone unlocked.
-- The unlock sign is a per-player SurfaceGui painted on the gate wall: big
-- Montserrat text with a black outline and a square power progress bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local EffectsController = require(script.Parent.EffectsController)

local ZoneController = {}

local COLOR_TRACK = Color3.fromRGB(20, 20, 24)
local COLOR_BORDER = Color3.fromRGB(8, 8, 10)
local COLOR_GOOD = Color3.fromRGB(96, 230, 130)
local COLOR_GOOD_LIGHT = Color3.fromRGB(160, 250, 180)
local COLOR_GOOD_DARK = Color3.fromRGB(52, 196, 96)
local COLOR_FILL = Color3.fromRGB(255, 255, 255)
local COLOR_FILL_DARK = Color3.fromRGB(198, 198, 206)

local montserratExtraBold = Font.new(
	"rbxasset://fonts/families/Montserrat.json",
	Enum.FontWeight.ExtraBold,
	Enum.FontStyle.Normal
)

local unlockedZones = { watermelon = true }
local squeezedObjects = {}
local playerPower = 0
local gates = {}
local gatesByTargetId = {}
local firstSnapshot = true

local function addText(parent, name, position, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = montserratExtraBold
	label.Text = ""
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function addTextGradient(label)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 145, 155)),
	})
	gradient.Rotation = 90
	gradient.Parent = label
	return gradient
end

local function createGateSign(entry)
	if entry.localInfo and entry.localInfo.Parent then
		return entry.localInfo
	end

	local signAnchor = entry.model:FindFirstChild("GateSign")
	if not signAnchor or not signAnchor:IsA("BasePart") then
		return nil
	end

	local previousObjectId = entry.model:GetAttribute("PreviousObjectId")
	local previousObject = Objects.byId[previousObjectId]
	local requiredPower = entry.model:GetAttribute("RequiredPower") or 0
	if not previousObject then
		return nil
	end

	local info = Instance.new("SurfaceGui")
	info.Name = "UnlockSign"
	info.Face = Enum.NormalId.Left
	info.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	info.CanvasSize = Vector2.new(2400, 880)
	info.LightInfluence = 0
	info.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	info.Parent = signAnchor

	-- Small translucent backdrop behind the text and the bar.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.fromScale(0.5, 0.5)
	backdrop.Size = UDim2.fromScale(0.5, 0.56)
	backdrop.BackgroundColor3 = COLOR_TRACK
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.Parent = info
	local backdropCorner = Instance.new("UICorner")
	backdropCorner.CornerRadius = UDim.new(0, 24)
	backdropCorner.Parent = backdrop

	-- TextSize caps at 100px, so the small canvas is what makes the text big.
	local powerLabel = addText(
		info,
		"PowerRequirement",
		UDim2.fromScale(0.5, 0.3),
		UDim2.fromScale(0.96, 0.14),
		Color3.new(1, 1, 1)
	)
	addTextGradient(powerLabel)

	local track = Instance.new("Frame")
	track.Name = "PowerTrack"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromScale(0.42, 0.09)
	track.BackgroundColor3 = COLOR_TRACK
	track.BackgroundTransparency = 0.05
	track.BorderSizePixel = 0
	track.Parent = info

	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = COLOR_BORDER
	trackStroke.Thickness = 3
	trackStroke.Transparency = 0.05
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "PowerFill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLOR_FILL
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(COLOR_FILL, COLOR_FILL_DARK)
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local squeezeLabel = addText(
		info,
		"SqueezeRequirement",
		UDim2.fromScale(0.5, 0.7),
		UDim2.fromScale(0.6, 0.14),
		Color3.new(1, 1, 1)
	)
	addTextGradient(squeezeLabel)

	entry.signAnchor = signAnchor
	entry.localInfo = info
	entry.updateSign = function()
		local complete = requiredPower > 0 and playerPower >= requiredPower
		local fraction = requiredPower > 0 and math.clamp(playerPower / requiredPower, 0, 1) or 1
		fill.Size = UDim2.fromScale(fraction, 1)
		if complete then
			fillGradient.Color = ColorSequence.new(COLOR_GOOD_LIGHT, COLOR_GOOD_DARK)
			powerLabel.TextColor3 = COLOR_GOOD
		else
			fillGradient.Color = ColorSequence.new(COLOR_FILL, COLOR_FILL_DARK)
			powerLabel.TextColor3 = Color3.new(1, 1, 1)
		end
		powerLabel.Text = string.format(
			"%s / %s POWER",
			Format.number(math.floor(playerPower)),
			Format.number(requiredPower)
		)
		local squeezed = squeezedObjects[previousObjectId] and 1 or 0
		squeezeLabel.Text = string.upper(string.format("%d / 1 %s", squeezed, previousObject.name))
		squeezeLabel.TextColor3 = squeezed > 0 and COLOR_GOOD or Color3.new(1, 1, 1)
	end
	entry.updateSign()

	return info
end

local function applyGate(entry)
	local unlocked = unlockedZones[entry.targetObjectId] == true
	local keepVisible = entry.animating == true
	local localInfo = createGateSign(entry)
	if localInfo then
		localInfo.Enabled = (not unlocked) or keepVisible
	end
	for _, descendant in ipairs(entry.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = unlocked and 1 or 0
			if descendant.Name == "ZoneBlocker" then
				descendant.CanCollide = not unlocked
			end
		elseif descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
			or descendant:IsA("ProximityPrompt") then
			descendant.Enabled = (not unlocked) or keepVisible
		end
	end
end

local function fadeSignOut(signGui, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweens = {}
	for _, descendant in ipairs(signGui:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			table.insert(tweens, TweenService:Create(descendant, tweenInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}))
		elseif descendant:IsA("Frame") then
			table.insert(tweens, TweenService:Create(descendant, tweenInfo, {
				BackgroundTransparency = 1,
			}))
		elseif descendant:IsA("UIStroke") then
			table.insert(tweens, TweenService:Create(descendant, tweenInfo, {
				Transparency = 1,
			}))
		end
	end
	for _, tween in ipairs(tweens) do
		tween:Play()
	end
end

-- Feloldás: a tábla felpattan, arany szikrák + a zóna neve felszáll, majd
-- az egész tábla kifakul, és a kapu eltűnik.
local function playUnlockAnimation(entry)
	local info = entry.localInfo
	local signAnchor = entry.signAnchor
	if not info or not info.Parent or not signAnchor then
		return
	end

	entry.animating = true
	applyGate(entry)

	local zoneName = string.upper(entry.model:GetAttribute("TargetZoneName") or "ZONE")
	local signPosition = signAnchor.Position
	EffectsController.burst(signPosition, COLOR_GOOD, 46)
	EffectsController.burst(signPosition + Vector3.new(0, 0, -24), COLOR_GOOD, 20)
	EffectsController.burst(signPosition + Vector3.new(0, 0, 24), COLOR_GOOD, 20)
	EffectsController.floatingText(signPosition, zoneName, COLOR_GOOD)

	task.spawn(function()
		local backdrop = info:FindFirstChild("Backdrop")
		if backdrop then
			local pop = TweenService:Create(
				backdrop,
				TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(0.62, 0.7) }
			)
			pop:Play()
			pop.Completed:Wait()
		end

		task.wait(0.2)
		fadeSignOut(info, 0.45)
		task.wait(0.5)

		entry.animating = false
		applyGate(entry)
	end)
end

local function registerGate(candidate)
	if not candidate:IsA("Model") or gates[candidate] then
		return
	end
	local targetObjectId = candidate:GetAttribute("TargetObjectId")
	if type(targetObjectId) ~= "string" then
		return
	end
	local entry = {
		model = candidate,
		targetObjectId = targetObjectId,
	}
	gates[candidate] = entry
	gatesByTargetId[targetObjectId] = entry
	applyGate(entry)
	candidate.DescendantAdded:Connect(function()
		task.defer(function()
			if candidate.Parent then
				applyGate(entry)
			end
		end)
	end)
end

local function refreshGates()
	for model, entry in pairs(gates) do
		if model.Parent then
			applyGate(entry)
			if entry.updateSign then
				entry.updateSign()
			end
		else
			if entry.localInfo then
				entry.localInfo:Destroy()
			end
			if gatesByTargetId[entry.targetObjectId] == entry then
				gatesByTargetId[entry.targetObjectId] = nil
			end
			gates[model] = nil
		end
	end
end

function ZoneController.init()
	task.spawn(function()
		local map = workspace:WaitForChild(GameConfig.MapName)
		local scenery = map:WaitForChild("Scenery")
		local folder = scenery:WaitForChild("ZoneGates")
		for _, gate in ipairs(folder:GetChildren()) do
			registerGate(gate)
		end
		folder.ChildAdded:Connect(function(gate)
			task.defer(registerGate, gate)
		end)
	end)

	local dataChanged = Net.get("DataChanged")
	if dataChanged then
		dataChanged.OnClientEvent:Connect(function(snapshot)
			if type(snapshot) ~= "table" or type(snapshot.unlockedTeleports) ~= "table" then
				return
			end
			local previousZones = unlockedZones
			unlockedZones = snapshot.unlockedTeleports
			unlockedZones.watermelon = true
			squeezedObjects = type(snapshot.squeezedObjects) == "table" and snapshot.squeezedObjects or {}
			playerPower = tonumber(snapshot.power) or 0

			if not firstSnapshot then
				for objectId, unlocked in pairs(unlockedZones) do
					if unlocked and objectId ~= "watermelon" and not previousZones[objectId] then
						local entry = gatesByTargetId[objectId]
						if entry then
							task.spawn(playUnlockAnimation, entry)
						end
					end
				end
			end
			firstSnapshot = false

			refreshGates()
		end)
	end
end

return ZoneController
