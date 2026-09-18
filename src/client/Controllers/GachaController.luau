-- GachaController: Ládák (Chests), kesztyű-anyagok és pity UI (éles sarkokkal)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared.Config.Gacha)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local GachaController = {}

-- Állapot
local isModalOpen = false
local currentData = {
	cash = 0,
	equippedMaterial = nil,
	materialMultiplier = 1.0,
	materials = {},
	pityCount = 0,
}

local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local equippedLabel = nil
local pityLabel = nil
local revealCard = nil
local revealScale = nil

-- Segédfüggvény éles fekete UIStroke beállításhoz
local function applyStroke(instance, color, thickness, mode)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	stroke.Parent = instance
	return stroke
end

-- Éles 3D gomb készítése
local function create3DButton(parent, size, position, anchorPoint, mainColor, shadowColor, text)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Button3D"
	shadowFrame.Size = size
	shadowFrame.Position = position
	shadowFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	shadowFrame.BackgroundColor3 = shadowColor or Color3.fromRGB(25, 125, 52)
	shadowFrame.BorderSizePixel = 0
	shadowFrame.Parent = parent
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
	topButton.TextSize = 20
	topButton.Parent = shadowFrame
	applyStroke(topButton, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

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

-- UI frissítése a legújabb adatokkal
local function refreshHeaderInfo()
	if equippedLabel then
		local mat = currentData.equippedMaterial and GachaConfig.materials[currentData.equippedMaterial]
		if mat then
			equippedLabel.Text = string.format("Glove: %s %s (x%.1f)", mat.emoji, mat.name, mat.multiplier)
			equippedLabel.TextColor3 = mat.color
		else
			equippedLabel.Text = "Glove: None (x1.0)"
			equippedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end

	if pityLabel then
		local pity = currentData.pityCount or 0
		pityLabel.Text = string.format("Pity: %d/%d (Epic+ at %d)", pity, GachaConfig.pityThreshold, GachaConfig.pityThreshold)
		if pity >= 15 then
			pityLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
		else
			pityLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		end
	end
end

-- Modal nyitás / zárás
function GachaController.open()
	if isModalOpen then
		return
	end
	isModalOpen = true
	refreshHeaderInfo()

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

function GachaController.close()
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

function GachaController.toggle()
	if isModalOpen then
		GachaController.close()
	else
		GachaController.open()
	end
end

-- Ládanyitás Eredmény Popup
local function showRevealPopup(result)
	local mat = result.material
	if not mat then
		return
	end

	local popupOverlay = Instance.new("TextButton")
	popupOverlay.Name = "RevealOverlay"
	popupOverlay.Size = UDim2.fromScale(1, 1)
	popupOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	popupOverlay.BackgroundTransparency = 0.35
	popupOverlay.BorderSizePixel = 0
	popupOverlay.Text = ""
	popupOverlay.AutoButtonColor = false
	popupOverlay.ZIndex = 30
	popupOverlay.Parent = modalOverlay

	local card = Instance.new("Frame")
	card.Name = "RevealCard"
	card.Size = UDim2.fromOffset(380, 360)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(24, 20, 18)
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = popupOverlay
	applyStroke(card, mat.color or Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)

	local cScale = Instance.new("UIScale")
	cScale.Scale = 0.6
	cScale.Parent = card

	-- Fejléc
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = mat.color or Color3.fromRGB(70, 140, 220)
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 32
	topBar.Parent = card

	local topText = Instance.new("TextLabel")
	topText.Size = UDim2.fromScale(1, 1)
	topText.BackgroundTransparency = 1
	topText.Font = Enum.Font.FredokaOne
	topText.Text = result.wasPity and "⭐ PITY GUARANTEE! ⭐" or "YOU UNBOXED!"
	topText.TextSize = 20
	topText.TextColor3 = Color3.fromRGB(255, 255, 255)
	topText.ZIndex = 33
	topText.Parent = topBar
	applyStroke(topText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Ikon doboz
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.fromOffset(100, 100)
	iconFrame.Position = UDim2.new(0.5, 0, 0.35, 0)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	iconFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
	iconFrame.BorderSizePixel = 0
	iconFrame.ZIndex = 32
	iconFrame.Parent = card
	applyStroke(iconFrame, mat.color or Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = mat.emoji or "🧤"
	iconLabel.TextSize = 58
	iconLabel.ZIndex = 33
	iconLabel.Parent = iconFrame

	-- Anyag név
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 32)
	nameLabel.Position = UDim2.new(0, 0, 0.56, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = mat.name
	nameLabel.TextSize = 28
	nameLabel.TextColor3 = mat.color
	nameLabel.ZIndex = 32
	nameLabel.Parent = card
	applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

	-- Szorzó és ritkaság
	local multiLabel = Instance.new("TextLabel")
	multiLabel.Size = UDim2.new(1, 0, 0, 26)
	multiLabel.Position = UDim2.new(0, 0, 0.68, 0)
	multiLabel.BackgroundTransparency = 1
	multiLabel.Font = Enum.Font.FredokaOne
	multiLabel.Text = string.format("[%s] x%.1f MULTIPLIER", mat.rarity:upper(), mat.multiplier)
	multiLabel.TextSize = 20
	multiLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	multiLabel.ZIndex = 32
	multiLabel.Parent = card
	applyStroke(multiLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Felszerelés / Bezárás gomb
	local equipBtn = create3DButton(
		card,
		UDim2.fromOffset(160, 48),
		UDim2.new(0.5, 0, 0.86, 0),
		Vector2.new(0.5, 0.5),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		"EQUIP"
	)
	equipBtn.container.ZIndex = 34
	equipBtn.button.ZIndex = 35

	local function closePopup()
		TweenService:Create(cScale, TweenInfo.new(0.12), { Scale = 0.6 }):Play()
		task.wait(0.12)
		popupOverlay:Destroy()
	end

	equipBtn.button.MouseButton1Click:Connect(function()
		local remote = Net.get("EquipMaterial")
		if remote then
			remote:FireServer(mat.id)
		end
		closePopup()
	end)

	popupOverlay.MouseButton1Click:Connect(closePopup)

	TweenService:Create(
		cScale,
		TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	):Play()
end

-- Egy Láda Kártya létrehozása
local function createChestCard(parent, chestDef, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = "ChestCard_" .. chestDef.id
	card.Size = UDim2.new(1, 0, 0, 96)
	card.BackgroundColor3 = chestDef.color
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	-- Éles vastag fekete keret
	applyStroke(card, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Border)

	-- Bal oldali láda doboz
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.fromOffset(72, 72)
	iconBox.Position = UDim2.new(0, 12, 0.5, 0)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
	iconBox.BackgroundTransparency = 0.35
	iconBox.BorderSizePixel = 0
	iconBox.Parent = card
	applyStroke(iconBox, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = chestDef.icon or "📦"
	iconLabel.TextSize = 42
	iconLabel.Parent = iconBox

	-- Középső információs rész
	local infoFrame = Instance.new("Frame")
	infoFrame.Position = UDim2.new(0, 98, 0, 8)
	infoFrame.Size = UDim2.new(1, -250, 1, -16)
	infoFrame.BackgroundTransparency = 1
	infoFrame.BorderSizePixel = 0
	infoFrame.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = chestDef.name
	nameLabel.TextSize = 24
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = infoFrame
	applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Esélyek leírása
	local oddsSummary = {}
	for _, entry in ipairs(chestDef.pool) do
		local mat = GachaConfig.materials[entry.material]
		if mat then
			table.insert(oddsSummary, mat.name)
		end
	end

	local descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.new(0, 0, 0, 36)
	descLabel.Size = UDim2.new(1, 0, 0, 24)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.FredokaOne
	descLabel.Text = "Drops: " .. table.concat(oddsSummary, " • ")
	descLabel.TextSize = 16
	descLabel.TextColor3 = Color3.fromRGB(255, 255, 210)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = infoFrame
	applyStroke(descLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Jobb oldali éles 3D OPEN gomb
	local openBtn = create3DButton(
		card,
		UDim2.fromOffset(130, 52),
		UDim2.new(1, -14, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		Format.money(chestDef.cost)
	)

	openBtn.button.MouseButton1Click:Connect(function()
		local remote = Net.get("OpenChest")
		if remote then
			remote:FireServer(chestDef.id)
		end
	end)
end

-- A teljes felület felépítése
local function buildUI(screenGui)
	-- 1. HUD Gomb (Képernyő bal oldalán, az Upgrades gomb alatt)
	local hudWrapper = Instance.new("Frame")
	hudWrapper.Name = "GachaHudWrapper"
	hudWrapper.Size = UDim2.fromOffset(148, 52)
	hudWrapper.Position = UDim2.new(0, 20, 0.5, -32)
	hudWrapper.AnchorPoint = Vector2.new(0, 0.5)
	hudWrapper.BackgroundTransparency = 1
	hudWrapper.BorderSizePixel = 0
	hudWrapper.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudWrapper,
		UDim2.fromScale(1, 1),
		UDim2.new(0, 0, 0, 0),
		Vector2.new(0, 0),
		Color3.fromRGB(235, 165, 35), -- Meleg aranysárga láda szín
		Color3.fromRGB(155, 100, 20),
		""
	)

	local chestIcon = Instance.new("TextLabel")
	chestIcon.Size = UDim2.fromOffset(36, 36)
	chestIcon.Position = UDim2.new(0, 8, 0.5, -18)
	chestIcon.BackgroundTransparency = 1
	chestIcon.BorderSizePixel = 0
	chestIcon.Font = Enum.Font.FredokaOne
	chestIcon.Text = "📦"
	chestIcon.TextSize = 28
	chestIcon.Parent = hudBtn3D.button

	local hudText = Instance.new("TextLabel")
	hudText.Name = "Label"
	hudText.Size = UDim2.new(1, -44, 1, 0)
	hudText.Position = UDim2.new(0, 40, 0, 0)
	hudText.BackgroundTransparency = 1
	hudText.BorderSizePixel = 0
	hudText.Font = Enum.Font.FredokaOne
	hudText.Text = "CHESTS"
	hudText.TextSize = 18
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	hudBtn3D.button.MouseButton1Click:Connect(function()
		GachaController.toggle()
	end)

	hudButton = hudWrapper

	-- 2. Modal felület (Sötétítő háttér + Éles Ablak)
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "GachaModalOverlay"
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Position = UDim2.new(0, 0, 0, 0)
	modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalOverlay.BackgroundTransparency = 1
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Text = ""
	modalOverlay.AutoButtonColor = false
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 12
	modalOverlay.Parent = screenGui

	modalOverlay.MouseButton1Click:Connect(function()
		GachaController.close()
	end)

	-- Fő Ablak (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "GachaWindow"
	windowFrame.Size = UDim2.fromOffset(530, 460)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 16)
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 13
	windowFrame.Parent = modalOverlay
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

	-- FEJLÉC (Meleg bronz-arany sáv)
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 68)
	headerBar.BackgroundColor3 = Color3.fromRGB(225, 155, 45)
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 14
	headerBar.Parent = windowFrame

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 175, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 125, 30)),
	})
	headerGradient.Rotation = 90
	headerGradient.Parent = headerBar

	-- Fekete alsó elválasztó vonal
	local headerDiv = Instance.new("Frame")
	headerDiv.Size = UDim2.new(1, 0, 0, 4)
	headerDiv.Position = UDim2.new(0, 0, 1, -4)
	headerDiv.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	headerDiv.BorderSizePixel = 0
	headerDiv.ZIndex = 15
	headerDiv.Parent = headerBar

	local headChestIcon = Instance.new("TextLabel")
	headChestIcon.Size = UDim2.fromOffset(48, 48)
	headChestIcon.Position = UDim2.new(0, 14, 0.5, -24)
	headChestIcon.BackgroundTransparency = 1
	headChestIcon.BorderSizePixel = 0
	headChestIcon.Font = Enum.Font.FredokaOne
	headChestIcon.Text = "📦"
	headChestIcon.TextSize = 40
	headChestIcon.ZIndex = 15
	headChestIcon.Parent = headerBar

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(0, 320, 1, 0)
	headerTitle.Position = UDim2.new(0, 68, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.BorderSizePixel = 0
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.Text = "CHESTS & GACHA"
	headerTitle.TextSize = 34
	headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 15
	headerTitle.Parent = headerBar
	applyStroke(headerTitle, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Contextual)

	-- Piros Éles Bezáró Gomb ("X")
	local closeBtn3D = create3DButton(
		headerBar,
		UDim2.fromOffset(46, 46),
		UDim2.new(1, -12, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(225, 45, 55),
		Color3.fromRGB(140, 20, 28),
		"X"
	)
	closeBtn3D.container.ZIndex = 15
	closeBtn3D.button.ZIndex = 16
	closeBtn3D.button.TextSize = 28
	closeBtn3D.button.MouseButton1Click:Connect(function()
		GachaController.close()
	end)

	-- SubHeader: Felszerelt kesztyű-anyag és Pity állapot
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -24, 0, 30)
	subHeader.Position = UDim2.new(0, 12, 0, 76)
	subHeader.BackgroundColor3 = Color3.fromRGB(18, 14, 12)
	subHeader.BorderSizePixel = 0
	subHeader.ZIndex = 14
	subHeader.Parent = windowFrame
	applyStroke(subHeader, Color3.fromRGB(130, 85, 40), 2, Enum.ApplyStrokeMode.Border)

	equippedLabel = Instance.new("TextLabel")
	equippedLabel.Name = "EquippedLabel"
	equippedLabel.Size = UDim2.new(0.6, 0, 1, 0)
	equippedLabel.Position = UDim2.new(0, 8, 0, 0)
	equippedLabel.BackgroundTransparency = 1
	equippedLabel.BorderSizePixel = 0
	equippedLabel.Font = Enum.Font.FredokaOne
	equippedLabel.Text = "Glove: None (x1.0)"
	equippedLabel.TextSize = 17
	equippedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
	equippedLabel.ZIndex = 15
	equippedLabel.Parent = subHeader
	applyStroke(equippedLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	pityLabel = Instance.new("TextLabel")
	pityLabel.Name = "PityLabel"
	pityLabel.Size = UDim2.new(0.4, -8, 1, 0)
	pityLabel.Position = UDim2.new(0.6, 0, 0, 0)
	pityLabel.BackgroundTransparency = 1
	pityLabel.BorderSizePixel = 0
	pityLabel.Font = Enum.Font.FredokaOne
	pityLabel.Text = "Pity: 0/20"
	pityLabel.TextSize = 17
	pityLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Right
	pityLabel.ZIndex = 15
	pityLabel.Parent = subHeader
	applyStroke(pityLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Ládák Görgethető Listája (ScrollingFrame)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ChestsList"
	scrollFrame.Size = UDim2.new(1, -24, 1, -120)
	scrollFrame.Position = UDim2.new(0, 12, 0, 114)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 7
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 68, 55)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ZIndex = 14
	scrollFrame.Parent = windowFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 2)
	listPadding.PaddingBottom = UDim.new(0, 10)
	listPadding.PaddingLeft = UDim.new(0, 2)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = scrollFrame

	-- Ládák generálása
	for index, chest in ipairs(GachaConfig.chests) do
		createChestCard(scrollFrame, chest, index)
	end

	refreshHeaderInfo()
end

-- Inicializálás
function GachaController.init(hud)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)

	-- Szinkronizálás a szerver adatokkal
	local dataRemote = Net.get("DataChanged")
	if dataRemote then
		dataRemote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				currentData.cash = snapshot.cash or currentData.cash
				currentData.equippedMaterial = snapshot.equippedMaterial or currentData.equippedMaterial
				currentData.materialMultiplier = snapshot.materialMultiplier or currentData.materialMultiplier
				currentData.materials = snapshot.materials or currentData.materials
				currentData.pityCount = snapshot.pityCount or currentData.pityCount
				refreshHeaderInfo()
			end
		end)
	end

	-- Ládanyitás eredményének fogadása
	local openedRemote = Net.get("ChestOpened")
	if openedRemote then
		openedRemote.OnClientEvent:Connect(function(result)
			if result then
				currentData.pityCount = result.pity or currentData.pityCount
				refreshHeaderInfo()
				showRevealPopup(result)
			end
		end)
	end
end

return GachaController

