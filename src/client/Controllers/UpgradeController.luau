-- UpgradeController: Megnyitható Upgrades UI és HUD gomb a megadott éles, NEM LEKEREKÍTETT design szerint.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradesConfig = require(Shared.Config.Upgrades)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local UpgradeController = {}

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
local cashLabel = nil
local notifBadge = nil

-- Segédfüggvény UIStroke beállításhoz (vastag éles keretekhez és betűkontúrhoz)
local function applyStroke(instance, color, thickness, mode)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	stroke.Parent = instance
	return stroke
end

-- Dupla zöld chevron (felfelé mutató éles nyilak) ikon
local function createChevronIcon(parent, size)
	local container = Instance.new("Frame")
	container.Name = "ChevronIcon"
	container.Size = UDim2.fromOffset(size, size)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = parent

	-- Két egymásra helyezett stílusos zöld nyíl
	local function createArrow(offsetY, isTop)
		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.new(1, 0, 0.72, 0)
		arrow.Position = UDim2.fromOffset(0, offsetY)
		arrow.BackgroundTransparency = 1
		arrow.BorderSizePixel = 0
		arrow.Font = Enum.Font.FredokaOne
		arrow.Text = "▲"
		arrow.TextSize = math.floor(size * 0.82)
		arrow.TextColor3 = isTop and Color3.fromRGB(155, 255, 60) or Color3.fromRGB(48, 215, 75)
		applyStroke(arrow, Color3.fromRGB(0, 0, 0), math.max(2, math.floor(size * 0.08)), Enum.ApplyStrokeMode.Contextual)
		arrow.ZIndex = isTop and 4 or 3
		arrow.Parent = container
		return arrow
	end

	createArrow(math.floor(size * 0.28), false)
	createArrow(0, true)

	return container
end

-- ÉLES 3D gomb készítése (zöld felület + sötét árnyék alul, nulla lekerekítés, vastag fekete keret)
local function create3DButton(parent, size, position, anchorPoint, mainColor, shadowColor, text)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Button3D"
	shadowFrame.Size = size
	shadowFrame.Position = position
	shadowFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	shadowFrame.BackgroundColor3 = shadowColor or Color3.fromRGB(25, 125, 52)
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
	topButton.Font = Enum.Font.FredokaOne
	topButton.Text = text or ""
	topButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	topButton.TextSize = 22
	topButton.Parent = shadowFrame
	applyStroke(topButton, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Nyomás animáció
	local defaultTopPos = UDim2.new(0, 0, 0, 0)
	local pressedTopPos = UDim2.new(0, 0, 0, 4)

	topButton.MouseButton1Down:Connect(function()
		TweenService:Create(topButton, TweenInfo.new(0.05), { Position = pressedTopPos }):Play()
	end)

	topButton.MouseButton1Up:Connect(function()
		TweenService:Create(topButton, TweenInfo.new(0.06), { Position = defaultTopPos }):Play()
	end)

	topButton.MouseLeave:Connect(function()
		TweenService:Create(topButton, TweenInfo.new(0.06), { Position = defaultTopPos }):Play()
	end)

	return {
		container = shadowFrame,
		button = topButton,
		setText = function(newText)
			topButton.Text = newText
		end,
		setColor = function(newMain, newShadow)
			topButton.BackgroundColor3 = newMain
			shadowFrame.BackgroundColor3 = newShadow
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
			elements.actionBtn.setColor(Color3.fromRGB(40, 160, 90), Color3.fromRGB(20, 100, 45))
		end
	end
end

-- Összes kártya és jelvény frissítése
local function refreshAll()
	if cashLabel then
		cashLabel.Text = "Cash: " .. Format.money(currentData.cash)
	end

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
	isModalOpen = true
	refreshAll()

	modalOverlay.Visible = true
	modalOverlay.BackgroundTransparency = 1
	windowScale.Scale = 0.8

	TweenService:Create(modalOverlay, TweenInfo.new(0.18), { BackgroundTransparency = 0.5 }):Play()
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

	TweenService:Create(modalOverlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	local closeTween = TweenService:Create(
		windowScale,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.8 }
	)
	closeTween:Play()
	closeTween.Completed:Wait()

	if not isModalOpen then
		modalOverlay.Visible = false
	end
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
	card.BackgroundColor3 = category.cardColor or Color3.fromRGB(94, 68, 48)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = container

	-- Éles, vastag fekete keret (NEM lekerekített)
	applyStroke(card, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Border)

	-- Bal oldali éles ikon doboz
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.fromOffset(70, 70)
	iconBox.Position = UDim2.new(0, 12, 0.5, 0)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.BackgroundColor3 = Color3.fromRGB(20, 15, 12)
	iconBox.BackgroundTransparency = 0.4
	iconBox.BorderSizePixel = 0
	iconBox.Parent = card
	applyStroke(iconBox, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.BorderSizePixel = 0
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = category.emoji or "⚡"
	iconLabel.TextSize = 40
	iconLabel.Parent = iconBox

	-- Középső információs rész
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "Info"
	infoFrame.Position = UDim2.new(0, 96, 0, 8)
	infoFrame.Size = UDim2.new(1, -245, 1, -16)
	infoFrame.BackgroundTransparency = 1
	infoFrame.BorderSizePixel = 0
	infoFrame.Parent = card

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
		card,
		UDim2.fromOffset(130, 54),
		UDim2.new(1, -14, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		"MAX"
	)

	actionBtn.button.MouseButton1Click:Connect(function()
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
	hudContainer.Size = UDim2.fromOffset(148, 52)
	hudContainer.Position = UDim2.new(0, 20, 0.5, -96)
	hudContainer.AnchorPoint = Vector2.new(0, 0.5)
	hudContainer.BackgroundTransparency = 1
	hudContainer.BorderSizePixel = 0
	hudContainer.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudContainer,
		UDim2.fromScale(1, 1),
		UDim2.new(0, 0, 0, 0),
		Vector2.new(0, 0),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		""
	)

	local hudChevron = createChevronIcon(hudBtn3D.button, 28)
	hudChevron.Position = UDim2.new(0, 8, 0.5, -14)

	local hudText = Instance.new("TextLabel")
	hudText.Name = "Label"
	hudText.Size = UDim2.new(1, -44, 1, 0)
	hudText.Position = UDim2.new(0, 40, 0, 0)
	hudText.BackgroundTransparency = 1
	hudText.BorderSizePixel = 0
	hudText.Font = Enum.Font.FredokaOne
	hudText.Text = "UPGRADES"
	hudText.TextSize = 18
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Értesítési badge (szintén éles téglalap)
	notifBadge = Instance.new("Frame")
	notifBadge.Name = "NotifBadge"
	notifBadge.Size = UDim2.fromOffset(22, 22)
	notifBadge.Position = UDim2.new(1, -4, 0, -4)
	notifBadge.BackgroundColor3 = Color3.fromRGB(240, 50, 50)
	notifBadge.BorderSizePixel = 0
	notifBadge.Visible = false
	notifBadge.ZIndex = 6
	notifBadge.Parent = hudContainer
	applyStroke(notifBadge, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local notifText = Instance.new("TextLabel")
	notifText.Size = UDim2.fromScale(1, 1)
	notifText.BackgroundTransparency = 1
	notifText.BorderSizePixel = 0
	notifText.Font = Enum.Font.FredokaOne
	notifText.Text = "!"
	notifText.TextSize = 15
	notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifText.Parent = notifBadge

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
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 10
	modalOverlay.Parent = screenGui

	modalOverlay.MouseButton1Click:Connect(function()
		UpgradeController.close()
	end)

	-- Fő Ablak Doboz (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "UpgradeWindow"
	windowFrame.Size = UDim2.fromOffset(500, 450)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(28, 22, 18) -- sötét háttér
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

	-- Fejléc chevron ikon
	local headerChevron = createChevronIcon(headerBar, 50)
	headerChevron.Position = UDim2.new(0, 14, 0.5, -25)
	headerChevron.ZIndex = 13

	-- Fejléc Cím: "UPGRADES"
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(0, 250, 1, 0)
	headerTitle.Position = UDim2.new(0, 72, 0, 0)
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
	closeBtn3D.button.TextSize = 28
	closeBtn3D.button.MouseButton1Click:Connect(function()
		UpgradeController.close()
	end)

	-- Aktuális Cash kijelzés
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -24, 0, 26)
	subHeader.Position = UDim2.new(0, 12, 0, 76)
	subHeader.BackgroundTransparency = 1
	subHeader.BorderSizePixel = 0
	subHeader.ZIndex = 12
	subHeader.Parent = windowFrame

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Size = UDim2.fromScale(1, 1)
	cashLabel.BackgroundTransparency = 1
	cashLabel.BorderSizePixel = 0
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.Text = "Cash: $0"
	cashLabel.TextSize = 20
	cashLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.ZIndex = 12
	cashLabel.Parent = subHeader
	applyStroke(cashLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Kártyák Görgethető Listája (ScrollingFrame, éles sarkokkal)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "CardsList"
	scrollFrame.Size = UDim2.new(1, -24, 1, -114)
	scrollFrame.Position = UDim2.new(0, 12, 0, 106)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 7
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(75, 62, 52)
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
	listPadding.PaddingLeft = UDim.new(0, 2)
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
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)

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
