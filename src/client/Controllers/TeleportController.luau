-- TeleportController: Teleport UI and HUD button (sharp retro-arcade corners)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectsConfig = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UiIcons = require(Shared.UiIcons)
local MenuCoordinator = require(script.Parent.MenuCoordinator)

local player = Players.LocalPlayer

local TeleportController = {}
local MENU_NAME = "teleport"

-- State
local isModalOpen = false
local currentPower = 0
local unlockedTeleports = { watermelon = true }
local squeezedObjects = {}

local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local userPowerLabel = nil

local cardRefs = {}
local isPreview = false

-- Helper to apply sharp black retro stroke
local function applyStroke(instance, color, thickness, mode)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	stroke.Parent = instance
	return stroke
end

-- Szín világosítása/sötétítése (factor > 1 világosít, < 1 sötétít)
local function shadeColor(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- Sharp 3D Button component
local function create3DButton(parent, size, position, anchorPoint, mainColor, shadowColor, text)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Button3D"
	shadowFrame.Size = size
	shadowFrame.Position = position
	shadowFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	shadowFrame.BackgroundColor3 = shadeColor(shadowColor or Color3.fromRGB(0, 115, 160), 0.7)
	shadowFrame.BorderSizePixel = 0
	shadowFrame.Parent = parent
	applyStroke(shadowFrame, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local topButton = Instance.new("TextButton")
	topButton.Name = "TopFace"
	topButton.Size = UDim2.new(1, 0, 1, -5)
	topButton.Position = UDim2.new(0, 0, 0, 0)
	topButton.BackgroundColor3 = mainColor or Color3.fromRGB(0, 185, 235)
	topButton.BorderSizePixel = 0
	topButton.AutoButtonColor = false
	topButton.Text = ""
	topButton.Parent = shadowFrame
	applyStroke(topButton, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Position = UDim2.fromScale(0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Text = text or ""
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 18
	textLabel.Parent = topButton
	applyStroke(textLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	local textGradient = Instance.new("UIGradient")
	textGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	textGradient.Rotation = 90
	textGradient.Parent = textLabel

	local buttonGradient = Instance.new("UIGradient")
	buttonGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, shadeColor(topButton.BackgroundColor3, 1.22)),
		ColorSequenceKeypoint.new(1, topButton.BackgroundColor3),
	})
	buttonGradient.Rotation = 90
	buttonGradient.Parent = topButton

	local pressScale = Instance.new("UIScale")
	pressScale.Parent = shadowFrame

	local pressDown = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local pressRelease = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	topButton.MouseButton1Down:Connect(function()
		TweenService:Create(pressScale, pressDown, { Scale = 0.9 }):Play()
	end)

	topButton.MouseButton1Up:Connect(function()
		TweenService:Create(pressScale, pressRelease, { Scale = 1 }):Play()
	end)

	topButton.MouseLeave:Connect(function()
		TweenService:Create(pressScale, pressRelease, { Scale = 1 }):Play()
	end)

	return {
		container = shadowFrame,
		button = topButton,
		setText = function(newText)
			textLabel.Text = newText
		end,
		setTextSize = function(newSize)
			textLabel.TextSize = newSize
		end,
		setColor = function(newMain, newShadow)
			topButton.BackgroundColor3 = newMain
			shadowFrame.BackgroundColor3 = shadeColor(newShadow, 0.7)
			buttonGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, shadeColor(newMain, 1.22)),
				ColorSequenceKeypoint.new(1, newMain),
			})
		end,
		setLabelColor = function(color)
			textLabel.TextColor3 = color
		end,
	}
end

-- Refresh card status and action buttons based on unlocked state and power
local function refreshStatus()
	if userPowerLabel then
		userPowerLabel.Text = string.format("Your Power: %s", Format.number(currentPower))
	end

	for objectId, refs in pairs(cardRefs) do
		local object = refs.object
		local statusLabel = refs.statusLabel
		local tpBtn = refs.tpBtn
		local cost = ObjectsConfig.getUnlockCost(object)
		local isUnlocked = (unlockedTeleports and unlockedTeleports[objectId] == true) or objectId == "watermelon"
		local canAfford = currentPower >= cost
		local previousObject = ObjectsConfig.list[object.index - 1]
		local hasRequiredSqueeze = not previousObject or squeezedObjects[previousObject.id] == true

		if isUnlocked then
			statusLabel.Text = "Status: UNLOCKED"
			statusLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
			tpBtn.setText("TELEPORT")
			tpBtn.setColor(Color3.fromRGB(0, 185, 235), Color3.fromRGB(0, 115, 160))
			tpBtn.setLabelColor(Color3.fromRGB(255, 255, 255))
		elseif canAfford and hasRequiredSqueeze then
			statusLabel.Text = string.format("Price: %s Power | UNLOCK READY", Format.number(cost))
			statusLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
			tpBtn.setText("UNLOCK")
			tpBtn.setColor(Color3.fromRGB(46, 204, 113), Color3.fromRGB(25, 125, 52))
			tpBtn.setLabelColor(Color3.fromRGB(255, 255, 255))
		elseif not hasRequiredSqueeze then
			statusLabel.Text = string.format("Squeeze %s first | LOCKED", previousObject.name)
			statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
			tpBtn.setText("LOCKED")
			tpBtn.setColor(Color3.fromRGB(60, 48, 55), Color3.fromRGB(36, 28, 32))
			tpBtn.setLabelColor(Color3.fromRGB(180, 150, 155))
		else
			statusLabel.Text = string.format("Req: %s Power | LOCKED", Format.number(cost))
			statusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
			tpBtn.setText("LOCKED")
			tpBtn.setColor(Color3.fromRGB(60, 48, 55), Color3.fromRGB(36, 28, 32))
			tpBtn.setLabelColor(Color3.fromRGB(180, 150, 155))
		end
	end
end

-- Modal Open / Close
function TeleportController.open()
	if isModalOpen then
		return
	end
	MenuCoordinator.opening(MENU_NAME)
	isModalOpen = true
	refreshStatus()

	modalOverlay.Visible = true
	modalOverlay.BackgroundTransparency = 1
	windowScale.Scale = 0.8

	local popTween = TweenService:Create(
		windowScale,
		TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	)
	popTween:Play()
end

function TeleportController.close()
	if not isModalOpen then
		return
	end
	isModalOpen = false
	MenuCoordinator.closed(MENU_NAME)

	local closeTween = TweenService:Create(
		windowScale,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.8 }
	)
	closeTween:Play()
	closeTween.Completed:Connect(function()
		if not isModalOpen then
			modalOverlay.Visible = false
		end
	end)
end

function TeleportController.toggle()
	if isModalOpen then
		TeleportController.close()
	else
		TeleportController.open()
	end
end

-- Build single object teleport card
local function buildObjectCard(object, parent, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. object.id
	card.Size = UDim2.new(1, 0, 0, 82)
	card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 22
	card.Parent = parent

	-- A fekete keret a külső frame maga; a színes kártya beljebb van,
	-- így a scrollframe széle nem tudja levágni a keretet.
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.new(1, -7, 1, -7)
	inner.Position = UDim2.fromOffset(3.5, 3.5)
	inner.BackgroundColor3 = Color3.fromRGB(26, 36, 48)
	inner.BorderSizePixel = 0
	inner.ZIndex = 22
	inner.Parent = card

	-- Object icon frame
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = UDim2.fromOffset(60, 60)
	iconFrame.Position = UDim2.new(0, 10, 0.5, 0)
	iconFrame.AnchorPoint = Vector2.new(0, 0.5)
	local objColor = Color3.fromHex(object.color or "#00AAFF")
	iconFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 23
	iconFrame.Parent = inner
	applyStroke(iconFrame, objColor, 2.5, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = "?"
	iconLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	iconLabel.TextSize = 34
	iconLabel.ZIndex = 24
	iconLabel.Parent = iconFrame

	-- Info Container
	local infoContainer = Instance.new("Frame")
	infoContainer.Name = "Info"
	infoContainer.Size = UDim2.new(1, -200, 1, -12)
	infoContainer.Position = UDim2.new(0, 80, 0, 6)
	infoContainer.BackgroundTransparency = 1
	infoContainer.BorderSizePixel = 0
	infoContainer.ZIndex = 23
	infoContainer.Parent = inner

	-- Object Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = string.format("%d. %s", layoutOrder, object.name)
	nameLabel.TextSize = 21
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 24
	nameLabel.Parent = infoContainer
	applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Weight Label
	local weightLabel = Instance.new("TextLabel")
	weightLabel.Name = "Weight"
	weightLabel.Size = UDim2.new(1, 0, 0, 20)
	weightLabel.Position = UDim2.new(0, 0, 0, 26)
	weightLabel.BackgroundTransparency = 1
	weightLabel.Font = Enum.Font.FredokaOne
	weightLabel.Text = string.format("Weight: %s", Format.weight(object.weight))
	weightLabel.TextSize = 14
	weightLabel.TextColor3 = Color3.fromRGB(190, 220, 240)
	weightLabel.TextXAlignment = Enum.TextXAlignment.Left
	weightLabel.ZIndex = 24
	weightLabel.Parent = infoContainer
	applyStroke(weightLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Required Power & Unlock Status Label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.Position = UDim2.new(0, 0, 0, 46)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.Text = "Status: ..."
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.fromRGB(255, 205, 80)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.ZIndex = 24
	statusLabel.Parent = infoContainer
	applyStroke(statusLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- 3D Action Button (TELEPORT / UNLOCK / LOCKED)
	local tpBtn = create3DButton(
		inner,
		UDim2.fromOffset(116, 48),
		UDim2.new(1, -12, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(0, 185, 235),
		Color3.fromRGB(0, 115, 160),
		"TELEPORT"
	)
	tpBtn.container.ZIndex = 23
	tpBtn.button.ZIndex = 24
	tpBtn.setTextSize(16)

	cardRefs[object.id] = {
		object = object,
		statusLabel = statusLabel,
		tpBtn = tpBtn,
	}

	tpBtn.button.MouseButton1Click:Connect(function()
		if isPreview then
			return
		end

		local isUnlocked = (unlockedTeleports and unlockedTeleports[object.id] == true) or object.id == "watermelon"
		if isUnlocked then
			local remote = Net.get("TeleportToObject")
			if remote then
				remote:FireServer(object.id)
			end
			TeleportController.close()
		else
			local cost = ObjectsConfig.getUnlockCost(object)
			local remote = Net.get("UnlockTeleport")
			if remote then
				remote:FireServer(object.id)
			end
		end
	end)
end

-- Build Entire Teleport UI
local function buildUI(screenGui)
	-- 1. Left HUD Teleport Button (Stacked cleanly under REBIRTH)
	local hudWrapper = Instance.new("Frame")
	hudWrapper.Name = "TeleportHudWrapper"
	hudWrapper.Size = UDim2.fromOffset(76, 76)
	hudWrapper.Position = UDim2.new(0, 106, 0.5, 43)
	hudWrapper.AnchorPoint = Vector2.new(0, 0.5)
	hudWrapper.BackgroundTransparency = 1
	hudWrapper.BorderSizePixel = 0
	hudWrapper.ZIndex = 100
	hudWrapper.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudWrapper,
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		Color3.fromRGB(24, 24, 28),
		Color3.fromRGB(4, 4, 6),
		""
	)

	local hudText = Instance.new("TextLabel")
	hudText.Name = "Label"
	hudText.Size = UDim2.fromScale(1, 1)
	hudText.Position = UDim2.fromScale(0, 0)
	hudText.BackgroundTransparency = 1
	hudText.BorderSizePixel = 0
	hudText.Font = Enum.Font.FredokaOne
	hudText.Text = "TELEPORT"
	hudText.TextSize = 16
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 3.2, Enum.ApplyStrokeMode.Contextual)
	UiIcons.decorateMenuButton(hudBtn3D.button, hudText, "teleport")

	hudBtn3D.button.MouseButton1Click:Connect(function()
		TeleportController.toggle()
	end)

	hudButton = hudWrapper

	-- 2. Modal Overlay & Window
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "TeleportModalOverlay"
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Position = UDim2.new(0, 0, 0, 0)
	modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalOverlay.BackgroundTransparency = 1
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Text = ""
	modalOverlay.AutoButtonColor = false
	modalOverlay.Active = false
	modalOverlay.InputSink = Enum.InputSink.None
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 20
	modalOverlay.Parent = screenGui

	-- Main Window Frame (Sharp retro corners, thick black border)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "TeleportWindow"
	windowFrame.Size = UDim2.fromOffset(530, 480)
	windowFrame.Position = UDim2.fromScale(0.5, 0.5)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
	windowFrame.BackgroundTransparency = 0.1
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 21
	windowFrame.Parent = modalOverlay
	applyStroke(windowFrame, Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)

	windowScale = Instance.new("UIScale")
	windowScale.Scale = 1.0
	windowScale.Parent = windowFrame

	-- Header Bar (Cyan arcade header)
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 52)
	headerBar.Position = UDim2.new(0, 0, 0, 0)
	headerBar.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 22
	headerBar.Parent = windowFrame
	applyStroke(headerBar, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 185, 235)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 115, 160)),
	})
	headerGradient.Rotation = 90
	headerGradient.Parent = headerBar

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -84, 1, 0)
	headerTitle.Position = UDim2.fromOffset(18, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.Text = "TELEPORT TO OBJECTS"
	headerTitle.TextSize = 24
	headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 23
	headerTitle.Parent = headerBar
	applyStroke(headerTitle, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	local headerTitleGradient = Instance.new("UIGradient")
	headerTitleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	headerTitleGradient.Rotation = 90
	headerTitleGradient.Parent = headerTitle

	-- Red 3D Close Button
	local closeBtn = create3DButton(
		headerBar,
		UDim2.fromOffset(38, 38),
		UDim2.new(1, -10, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(235, 60, 60),
		Color3.fromRGB(150, 25, 25),
		"X"
	)
	closeBtn.container.ZIndex = 23
	closeBtn.button.ZIndex = 24
	closeBtn.setTextSize(22)
	closeBtn.button.MouseButton1Click:Connect(function()
		TeleportController.close()
	end)

	-- Sub Header Bar (Instructions & Live Power)
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -24, 0, 32)
	subHeader.Position = UDim2.new(0, 12, 0, 60)
	subHeader.BackgroundColor3 = Color3.fromRGB(14, 20, 28)
	subHeader.BorderSizePixel = 0
	subHeader.ZIndex = 22
	subHeader.Parent = windowFrame
	applyStroke(subHeader, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Border)

	local subHintLabel = Instance.new("TextLabel")
	subHintLabel.Size = UDim2.new(0.6, -10, 1, 0)
	subHintLabel.Position = UDim2.new(0, 10, 0, 0)
	subHintLabel.BackgroundTransparency = 1
	subHintLabel.Font = Enum.Font.FredokaOne
	subHintLabel.Text = "Unlock areas with Power to teleport:"
	subHintLabel.TextSize = 14
	subHintLabel.TextColor3 = Color3.fromRGB(210, 230, 250)
	subHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	subHintLabel.ZIndex = 23
	subHintLabel.Parent = subHeader
	applyStroke(subHintLabel, Color3.fromRGB(0, 0, 0), 1.5, Enum.ApplyStrokeMode.Contextual)

	userPowerLabel = Instance.new("TextLabel")
	userPowerLabel.Size = UDim2.new(0.4, -10, 1, 0)
	userPowerLabel.Position = UDim2.new(0.6, 0, 0, 0)
	userPowerLabel.BackgroundTransparency = 1
	userPowerLabel.Font = Enum.Font.FredokaOne
	userPowerLabel.Text = "Your Power: 0"
	userPowerLabel.TextSize = 14
	userPowerLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	userPowerLabel.TextXAlignment = Enum.TextXAlignment.Right
	userPowerLabel.ZIndex = 23
	userPowerLabel.Parent = subHeader
	applyStroke(userPowerLabel, Color3.fromRGB(0, 0, 0), 1.5, Enum.ApplyStrokeMode.Contextual)

	-- Scrollable List of Objects
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ObjectsList"
	scrollFrame.Size = UDim2.new(1, -24, 1, -108)
	scrollFrame.Position = UDim2.new(0, 12, 0, 98)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 7
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 140, 190)
	scrollFrame.ScrollBarImageTransparency = 1
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ZIndex = 22
	scrollFrame.Parent = windowFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingBottom = UDim.new(0, 10)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = scrollFrame

	-- Build each object card
	for index, object in ipairs(ObjectsConfig.list) do
		buildObjectCard(object, scrollFrame, index)
	end

	refreshStatus()
end

-- Initialize Controller
function TeleportController.init(hud)
	isPreview = hud ~= nil and hud.preview == true
	MenuCoordinator.register(MENU_NAME, TeleportController.close)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)
	if isPreview then
		return
	end

	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				if snapshot.power ~= nil then
					currentPower = snapshot.power
				end
				if snapshot.unlockedTeleports ~= nil then
					unlockedTeleports = snapshot.unlockedTeleports
				end
				if snapshot.squeezedObjects ~= nil then
					squeezedObjects = snapshot.squeezedObjects
				end
				refreshStatus()
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.T then
			TeleportController.toggle()
		end
	end)
end

return TeleportController
