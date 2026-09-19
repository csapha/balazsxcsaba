-- UpgradeController: Megnyitható Upgrades UI és HUD gomb a megadott éles, NEM LEKEREKÍTETT design szerint.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradesConfig = require(Shared.Config.Upgrades)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UiIcons = require(Shared.UiIcons)
local MenuCoordinator = require(script.Parent.MenuCoordinator)

local player = Players.LocalPlayer

local UpgradeController = {}
local MENU_NAME = "upgrades"

-- Állapot
local isModalOpen = false
local currentData = {
	cash = 0,
	hands = UpgradesConfig.defaultHands,
	training = UpgradesConfig.defaultTraining,
	petSlots = UpgradesConfig.defaultPetSlots,
	speed = UpgradesConfig.defaultSpeed,
}

local cardElements = {}
local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local notifBadge = nil
local isPreview = false

-- Segédfüggvény UIStroke beállításhoz (vastag éles keretekhez és betűkontúrhoz)
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

-- ÉLES 3D gomb készítése (zöld felület + sötét árnyék alul, nulla lekerekítés, vastag fekete keret)
local function create3DButton(parent, size, position, anchorPoint, mainColor, shadowColor, text)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Button3D"
	shadowFrame.Size = size
	shadowFrame.Position = position
	shadowFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	shadowFrame.BackgroundColor3 = shadeColor(shadowColor or Color3.fromRGB(25, 125, 52), 0.7)
	shadowFrame.BorderSizePixel = 0
	shadowFrame.Parent = parent
	-- NEM LEKEREKÍTETT: éles vastag fekete keret
	applyStroke(shadowFrame, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local topButton = Instance.new("TextButton")
	topButton.Name = "TopFace"
	topButton.Size = UDim2.new(1, 0, 1, -5)
	topButton.Position = UDim2.new(0, 0, 0, 0)
	topButton.BackgroundColor3 = mainColor or Color3.fromRGB(46, 204, 113)
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
	textLabel.TextSize = 22
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

	-- Nyomás animáció
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
	}
end

-- Kártya adatainak frissítése
local function updateCard(category)
	local elements = cardElements[category.id]
	if not elements then
		return
	end

	local currentId = currentData[category.id]
	local currentEntry = category.byId[currentId] or category.byOrder[1]
	local currentOrder = currentEntry and currentEntry.order or 1
	local nextEntry = category.byOrder[currentOrder + 1]

	local isMax = (nextEntry == nil)

	-- Jelenlegi érték
	local currentStr = category.getValueString(currentEntry)
	elements.curValLabel.Text = currentStr

	if isMax then
		elements.nextValLabel.Text = currentStr
		elements.arrowLabel.Visible = true
		elements.actionBtn.setText("MAX")
		elements.actionBtn.setColor(Color3.fromRGB(46, 204, 113), Color3.fromRGB(25, 125, 52))
	else
		local nextStr = category.getValueString(nextEntry)
		elements.nextValLabel.Text = nextStr
		elements.arrowLabel.Visible = true

		local costStr = Format.money(nextEntry.cost)
		elements.actionBtn.setText(costStr)

		if currentData.cash >= nextEntry.cost then
			elements.actionBtn.setColor(Color3.fromRGB(46, 204, 113), Color3.fromRGB(25, 125, 52))
		else
			elements.actionBtn.setColor(Color3.fromRGB(64, 185, 110), Color3.fromRGB(36, 135, 68))
		end
	end
end

-- Összes kártya és jelvény frissítése
local function refreshAll()
	local canAffordAny = false

	for _, category in ipairs(UpgradesConfig.categories) do
		updateCard(category)

		local currentId = currentData[category.id]
		local currentEntry = category.byId[currentId] or category.byOrder[1]
		local currentOrder = currentEntry and currentEntry.order or 1
		local nextEntry = category.byOrder[currentOrder + 1]
		if nextEntry and currentData.cash >= nextEntry.cost then
			canAffordAny = true
		end
	end

	if notifBadge then
		notifBadge.Visible = canAffordAny
	end
end

-- Modal megnyitása / bezárása
function UpgradeController.open()
	if isModalOpen then
		return
	end
	MenuCoordinator.opening(MENU_NAME)
	isModalOpen = true
	refreshAll()

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

function UpgradeController.close()
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

function UpgradeController.toggle()
	if isModalOpen then
		UpgradeController.close()
	else
		UpgradeController.open()
	end
end

-- Egy kártya UI felépítése (ÉLES SAROK, VASTAG FEKETE KERET)
local function buildCard(category, container, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = "Card_" .. category.id
	card.Size = UDim2.new(1, 0, 0, 94)
	card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = container

	-- A fekete keret a külső frame maga; a színes kártya beljebb van,
	-- így a scrollframe széle nem tudja levágni a keretet.
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.new(1, -7, 1, -7)
	inner.Position = UDim2.fromOffset(3.5, 3.5)
	inner.BackgroundColor3 = category.cardColor or Color3.fromRGB(94, 68, 48)
	inner.BorderSizePixel = 0
	inner.Parent = card

	-- Bal oldali éles ikon doboz
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.fromOffset(70, 70)
	iconBox.Position = UDim2.new(0, 12, 0.5, 0)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.BackgroundColor3 = Color3.fromRGB(20, 15, 12)
	iconBox.BackgroundTransparency = 0.4
	iconBox.BorderSizePixel = 0
	iconBox.Parent = inner
	applyStroke(iconBox, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.BorderSizePixel = 0
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = "?"
	iconLabel.TextSize = 40
	iconLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	iconLabel.Parent = iconBox

	-- Középső információs rész
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "Info"
	infoFrame.Position = UDim2.new(0, 96, 0, 8)
	infoFrame.Size = UDim2.new(1, -245, 1, -16)
	infoFrame.BackgroundTransparency = 1
	infoFrame.BorderSizePixel = 0
	infoFrame.Parent = inner

	-- Cím
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.fromOffset(0, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.BorderSizePixel = 0
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = category.title
	titleLabel.TextSize = 25
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = infoFrame
	applyStroke(titleLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	-- Érték sor: [20] [▶] [20]
	local statLine = Instance.new("Frame")
	statLine.Name = "StatLine"
	statLine.Position = UDim2.new(0, 0, 0, 38)
	statLine.Size = UDim2.new(1, 0, 0, 34)
	statLine.BackgroundTransparency = 1
	statLine.BorderSizePixel = 0
	statLine.Parent = infoFrame

	local lineLayout = Instance.new("UIListLayout")
	lineLayout.FillDirection = Enum.FillDirection.Horizontal
	lineLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	lineLayout.Padding = UDim.new(0, 10)
	lineLayout.Parent = statLine

	-- Bal érték (fehér)
	local curValLabel = Instance.new("TextLabel")
	curValLabel.Name = "CurVal"
	curValLabel.BackgroundTransparency = 1
	curValLabel.BorderSizePixel = 0
	curValLabel.Font = Enum.Font.FredokaOne
	curValLabel.Text = "20"
	curValLabel.TextSize = 30
	curValLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	curValLabel.AutomaticSize = Enum.AutomaticSize.X
	curValLabel.Size = UDim2.fromOffset(0, 32)
	curValLabel.Parent = statLine
	applyStroke(curValLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	-- Kék háromszög nyíl (▶)
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "Arrow"
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.BorderSizePixel = 0
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.Text = "▶"
	arrowLabel.TextSize = 24
	arrowLabel.TextColor3 = Color3.fromRGB(135, 215, 255)
	arrowLabel.AutomaticSize = Enum.AutomaticSize.X
	arrowLabel.Size = UDim2.fromOffset(0, 32)
	arrowLabel.Parent = statLine
	applyStroke(arrowLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	-- Jobb érték (világító zöld)
	local nextValLabel = Instance.new("TextLabel")
	nextValLabel.Name = "NextVal"
	nextValLabel.BackgroundTransparency = 1
	nextValLabel.BorderSizePixel = 0
	nextValLabel.Font = Enum.Font.FredokaOne
	nextValLabel.Text = "20"
	nextValLabel.TextSize = 30
	nextValLabel.TextColor3 = Color3.fromRGB(50, 255, 60)
	nextValLabel.AutomaticSize = Enum.AutomaticSize.X
	nextValLabel.Size = UDim2.fromOffset(0, 32)
	nextValLabel.Parent = statLine
	applyStroke(nextValLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	-- Jobb oldali éles 3D gomb (MAX vagy ár)
	local actionBtn = create3DButton(
		inner,
		UDim2.fromOffset(130, 54),
		UDim2.new(1, -12, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		"MAX"
	)

	actionBtn.button.MouseButton1Click:Connect(function()
		if isPreview then
			return
		end

		local currentId = currentData[category.id]
		local currentEntry = category.byId[currentId] or category.byOrder[1]
		local currentOrder = currentEntry and currentEntry.order or 1
		local nextEntry = category.byOrder[currentOrder + 1]

		if not nextEntry then
			return
		end

		local remote = Net.get("BuyUpgrade")
		if remote then
			remote:FireServer(category.id, nextEntry.id)
		end
	end)

	cardElements[category.id] = {
		card = card,
		curValLabel = curValLabel,
		arrowLabel = arrowLabel,
		nextValLabel = nextValLabel,
		actionBtn = actionBtn,
	}
end

-- A teljes felület felépítése
local function buildUI(screenGui)
	-- 1. HUD Upgrade Gomb (képernyő bal oldalán, éles sarkokkal)
	local hudContainer = Instance.new("Frame")
	hudContainer.Name = "HudUpgradeWrapper"
	hudContainer.Size = UDim2.fromOffset(76, 76)
	hudContainer.Position = UDim2.new(0, 20, 0.5, -43)
	hudContainer.AnchorPoint = Vector2.new(0, 0.5)
	hudContainer.BackgroundTransparency = 1
	hudContainer.BorderSizePixel = 0
	hudContainer.ZIndex = 100
	hudContainer.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudContainer,
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
	hudText.Text = "UPGRADES"
	hudText.TextSize = 16
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 3.2, Enum.ApplyStrokeMode.Contextual)
	UiIcons.decorateMenuButton(hudBtn3D.button, hudText, "upgrade")

	-- Értesítési badge (szintén éles téglalap)
	notifBadge = Instance.new("Frame")
	notifBadge.Name = "NotifBadge"
	notifBadge.Size = UDim2.fromOffset(16, 16)
	notifBadge.Position = UDim2.new(1, -3, 0, 3)
	notifBadge.AnchorPoint = Vector2.new(1, 0)
	notifBadge.BackgroundColor3 = Color3.fromRGB(240, 50, 50)
	notifBadge.BorderSizePixel = 0
	notifBadge.Visible = false
	notifBadge.ZIndex = 6
	notifBadge.Parent = hudBtn3D.container
	applyStroke(notifBadge, Color3.fromRGB(0, 0, 0), 1.75, Enum.ApplyStrokeMode.Border)

	local notifBadgeGradient = Instance.new("UIGradient")
	notifBadgeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 18, 30)),
	})
	notifBadgeGradient.Rotation = 90
	notifBadgeGradient.Parent = notifBadge

	local notifText = Instance.new("TextLabel")
	notifText.Size = UDim2.fromScale(1, 1)
	notifText.BackgroundTransparency = 1
	notifText.BorderSizePixel = 0
	notifText.FontFace = Font.new(
		"rbxasset://fonts/families/Montserrat.json",
		Enum.FontWeight.ExtraBold,
		Enum.FontStyle.Normal
	)
	notifText.Text = "!"
	notifText.TextSize = 14
	notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	notifText.TextStrokeTransparency = 0
	notifText.TextXAlignment = Enum.TextXAlignment.Center
	notifText.TextYAlignment = Enum.TextYAlignment.Center
	notifText.Parent = notifBadge

	local notifTextGradient = Instance.new("UIGradient")
	notifTextGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 145, 155)),
	})
	notifTextGradient.Rotation = 90
	notifTextGradient.Parent = notifText

	hudBtn3D.button.MouseButton1Click:Connect(function()
		UpgradeController.toggle()
	end)

	hudButton = hudContainer

	-- 2. Modal felület (Sötétítő háttér + Éles Ablak)
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "UpgradeModalOverlay"
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
	modalOverlay.ZIndex = 10
	modalOverlay.Parent = screenGui

	-- Fő Ablak Doboz (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "UpgradeWindow"
	windowFrame.Size = UDim2.fromOffset(500, 450)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(28, 22, 18) -- sötét háttér
	windowFrame.BackgroundTransparency = 0.1
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 11
	windowFrame.Parent = modalOverlay

	-- Vastag fekete keret
	applyStroke(windowFrame, Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)

	windowScale = Instance.new("UIScale")
	windowScale.Scale = 1
	windowScale.Parent = windowFrame

	local windowBlocker = Instance.new("TextButton")
	windowBlocker.Size = UDim2.fromScale(1, 1)
	windowBlocker.BackgroundTransparency = 1
	windowBlocker.BorderSizePixel = 0
	windowBlocker.Text = ""
	windowBlocker.Active = false
	windowBlocker.InputSink = Enum.InputSink.None
	windowBlocker.Parent = windowFrame

	-- ZÖLD FEJLÉC (Éles sarkok, vastag fekete alsó él és keret)
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 70)
	headerBar.BackgroundColor3 = Color3.fromRGB(68, 195, 45)
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 12
	headerBar.Parent = windowFrame

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(95, 225, 55)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 172, 38)),
	})
	headerGradient.Rotation = 90
	headerGradient.Parent = headerBar

	-- Fekete elválasztó vonal a fejléc alatt
	local headerDivider = Instance.new("Frame")
	headerDivider.Name = "Divider"
	headerDivider.Size = UDim2.new(1, 0, 0, 4)
	headerDivider.Position = UDim2.new(0, 0, 1, -4)
	headerDivider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	headerDivider.BorderSizePixel = 0
	headerDivider.ZIndex = 15
	headerDivider.Parent = headerBar

	-- Fejléc Cím: "UPGRADES"
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -84, 1, 0)
	headerTitle.Position = UDim2.fromOffset(18, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.BorderSizePixel = 0
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.Text = "UPGRADES"
	headerTitle.TextSize = 36
	headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 13
	headerTitle.Parent = headerBar
	applyStroke(headerTitle, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Contextual)

	local headerTitleGradient = Instance.new("UIGradient")
	headerTitleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	headerTitleGradient.Rotation = 90
	headerTitleGradient.Parent = headerTitle

	-- Piros Éles Bezáró Gomb ("X") a jobb oldalon
	local closeBtn3D = create3DButton(
		headerBar,
		UDim2.fromOffset(48, 48),
		UDim2.new(1, -14, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(225, 45, 55),
		Color3.fromRGB(140, 20, 28),
		"X"
	)
	closeBtn3D.container.ZIndex = 13
	closeBtn3D.button.ZIndex = 14
	closeBtn3D.setTextSize(28)
	closeBtn3D.button.MouseButton1Click:Connect(function()
		UpgradeController.close()
	end)

	-- Kártyák Görgethető Listája (ScrollingFrame, éles sarkokkal)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "CardsList"
	scrollFrame.Size = UDim2.new(1, -24, 1, -92)
	scrollFrame.Position = UDim2.new(0, 12, 0, 84)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 7
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(75, 62, 52)
	scrollFrame.ScrollBarImageTransparency = 1
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ZIndex = 12
	scrollFrame.Parent = windowFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingBottom = UDim.new(0, 10)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = scrollFrame

	-- Kártyák generálása
	for index, category in ipairs(UpgradesConfig.categories) do
		buildCard(category, scrollFrame, index)
	end

	refreshAll()
end

-- Inicializálás
function UpgradeController.init(hud)
	isPreview = hud ~= nil and hud.preview == true
	MenuCoordinator.register(MENU_NAME, UpgradeController.close)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)
	if isPreview then
		return
	end

	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				currentData.cash = snapshot.cash or currentData.cash
				currentData.hands = snapshot.hands or currentData.hands
				currentData.training = snapshot.training or currentData.training
				currentData.petSlots = snapshot.petSlots or currentData.petSlots
				currentData.speed = snapshot.speed or currentData.speed
				refreshAll()
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.U then
			UpgradeController.toggle()
		end
	end)
end

return UpgradeController
