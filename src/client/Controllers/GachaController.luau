-- GachaController: Ládák (Chests), kesztyű-anyagok, pity UI és autentikus Case Opening Roulette
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared.Config.Gacha)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UiIcons = require(Shared.UiIcons)
local MenuCoordinator = require(script.Parent.MenuCoordinator)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local GachaController = {}
local MENU_NAME = "chests"

-- Állapot
local isModalOpen = false
local isSpinning = false
local currentData = {
	cash = 0,
	equippedMaterial = nil,
	materialMultiplier = 1.0,
	materials = {},
	pityCount = 0,
}

local activeScreenGui = nil
local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local equippedLabel = nil
local pityLabel = nil
local isPreview = false

-- Segédfüggvény éles fekete UIStroke beállításhoz
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

-- Hang lejátszása védett módon (nem dob hibát, ha asset nem elérhető)
local function playSound(soundId, volume, pitch)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = volume or 0.5
		sound.PlaybackSpeed = pitch or 1.0
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

-- Éles 3D gomb készítése (Retro Arcade stílus, 0 UICorner)
local function create3DButton(parent, size, position, anchorPoint, mainColor, shadowColor, text)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Button3D"
	shadowFrame.Size = size
	shadowFrame.Position = position
	shadowFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	shadowFrame.BackgroundColor3 = shadeColor(shadowColor or Color3.fromRGB(25, 125, 52), 0.7)
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
	topButton.Text = ""
	topButton.Active = true
	topButton.Selectable = true
	topButton.Parent = shadowFrame
	applyStroke(topButton, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Position = UDim2.fromScale(0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.BorderSizePixel = 0
	textLabel.Active = false
	textLabel.Selectable = false
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Text = text or ""
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 20
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

	local function bindClick(fn)
		local lastClickTime = 0
		local function handler()
			local now = os.clock()
			if now - lastClickTime < 0.25 then
				return
			end
			lastClickTime = now
			fn()
		end
		topButton.Activated:Connect(handler)
		topButton.MouseButton1Click:Connect(handler)
	end

	return {
		container = shadowFrame,
		button = topButton,
		onClick = bindClick,
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

-- UI frissítése a legújabb adatokkal
local function refreshHeaderInfo()
	if equippedLabel then
		local mat = currentData.equippedMaterial and GachaConfig.materials[currentData.equippedMaterial]
		if mat then
			equippedLabel.Text = string.format("Glove: %s (x%.1f)", mat.name, mat.multiplier)
			equippedLabel.TextColor3 = mat.color
		else
			equippedLabel.Text = "Glove: None (x1.0)"
			equippedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end

	if pityLabel then
		local pity = currentData.pityCount or 0
		pityLabel.Text = string.format("Pity: %d/%d (Epic+ at %d)", pity, GachaConfig.pityThreshold, GachaConfig.pityThreshold)
		if pity >= math.ceil(GachaConfig.pityThreshold * 0.75) then
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
	isSpinning = false
	MenuCoordinator.opening(MENU_NAME)
	isModalOpen = true
	refreshHeaderInfo()

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

function GachaController.close()
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

function GachaController.toggle()
	if isModalOpen then
		GachaController.close()
	else
		GachaController.open()
	end
end

-- Véletlenszerű anyag kiválasztása súlyozott láda poolból
local function pickRandomMaterial(chestDef, isPity)
	local pool = (isPity and GachaConfig.pityPool) or (chestDef and chestDef.pool)
	if not pool or #pool == 0 then
		return GachaConfig.materials.Rubber
	end
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.weight
	end
	local rand = math.random() * totalWeight
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.weight
		if rand <= cumulative then
			return GachaConfig.materials[entry.material] or GachaConfig.materials.Rubber
		end
	end
	return GachaConfig.materials[pool[#pool].material] or GachaConfig.materials.Rubber
end

-- Egy kártya létrehozása a forgó rulett szalagon
local function buildRouletteCard(parent, matDef)
	local card = Instance.new("Frame")
	card.Name = "ReelCard_" .. (matDef.id or "Item")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
	card.BorderSizePixel = 0
	card.ZIndex = 53
	card.Parent = parent

	local matColor = matDef.color or Color3.fromRGB(180, 180, 180)
	local stroke = applyStroke(card, matColor, 3, Enum.ApplyStrokeMode.Border)

	-- Felső ritkaság sáv
	local topStripe = Instance.new("Frame")
	topStripe.Name = "TopStripe"
	topStripe.Size = UDim2.new(1, 0, 0, 20)
	topStripe.BackgroundColor3 = matColor
	topStripe.BorderSizePixel = 0
	topStripe.ZIndex = 54
	topStripe.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.fromScale(1, 1)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.Text = (matDef.rarity or "COMMON"):upper()
	rarityLabel.TextSize = 11
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.ZIndex = 55
	rarityLabel.Parent = topStripe
	applyStroke(rarityLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Ikon / Emoji
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 0, 56)
	iconLabel.Position = UDim2.new(0, 0, 0, 22)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = matDef.emoji or "?"
	iconLabel.TextSize = 40
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.ZIndex = 54
	iconLabel.Parent = card

	-- Anyagnév
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -8, 0, 20)
	nameLabel.Position = UDim2.new(0, 4, 0, 80)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = matDef.name or "Material"
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = matColor
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 54
	nameLabel.Parent = card
	applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Szorzó
	local multiLabel = Instance.new("TextLabel")
	multiLabel.Name = "Multiplier"
	multiLabel.Size = UDim2.new(1, 0, 0, 18)
	multiLabel.Position = UDim2.new(0, 0, 0, 102)
	multiLabel.BackgroundTransparency = 1
	multiLabel.Font = Enum.Font.FredokaOne
	multiLabel.Text = string.format("x%.1f", matDef.multiplier or 1.0)
	multiLabel.TextSize = 14
	multiLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
	multiLabel.ZIndex = 54
	multiLabel.Parent = card
	applyStroke(multiLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Alsó színes díszsáv
	local bottomStripe = Instance.new("Frame")
	bottomStripe.Name = "BottomStripe"
	bottomStripe.Size = UDim2.new(1, 0, 0, 4)
	bottomStripe.Position = UDim2.new(0, 0, 1, -4)
	bottomStripe.BackgroundColor3 = matColor
	bottomStripe.BorderSizePixel = 0
	bottomStripe.ZIndex = 54
	bottomStripe.Parent = card

	return card, stroke
end

-- Autentikus CS:GO / Pet Simulator stílusú Ládanyitás (Case Opening Roulette)
local function startCaseOpening(result)
	if isSpinning then
		return
	end
	isSpinning = true

	local mat = result.material or GachaConfig.materials.Rubber
	local chestDef = result.chest or GachaConfig.chests[1]
	local wasPity = result.wasPity == true

	print(string.format("[GACHA] %s opened %s -> %s (x%.1f)", player.DisplayName, chestDef.name, mat.name, mat.multiplier or 1.0))

	local targetGui = activeScreenGui or (modalOverlay and modalOverlay.Parent)

	-- Eltüntetjük a háttérben a ládanyitó ablakot a forgás alatt
	if modalOverlay then
		modalOverlay.Visible = false
	end

	-- 1. Fullscreen Sötétítő Stage Overlay
	local stageOverlay = Instance.new("TextButton")
	stageOverlay.Name = "CaseOpeningStage"
	stageOverlay.Size = UDim2.fromScale(1, 1)
	stageOverlay.Position = UDim2.fromScale(0, 0)
	stageOverlay.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
	stageOverlay.BackgroundTransparency = 0.15
	stageOverlay.BorderSizePixel = 0
	stageOverlay.Text = ""
	stageOverlay.AutoButtonColor = false
	stageOverlay.ZIndex = 100
	stageOverlay.Parent = targetGui

	-- 2. Fejléc: Nyitott láda neve és Pity infó
	local headerContainer = Instance.new("Frame")
	headerContainer.Name = "OpeningHeader"
	headerContainer.Size = UDim2.new(0.85, 0, 0, 75)
	headerContainer.Position = UDim2.new(0.5, 0, 0.16, 0)
	headerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	headerContainer.BackgroundTransparency = 1
	headerContainer.BorderSizePixel = 0
	headerContainer.ZIndex = 52
	headerContainer.Parent = stageOverlay

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 38)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = string.format("OPENING %s...", (chestDef.name or "CHEST"):upper())
	titleLabel.TextSize = 32
	titleLabel.TextColor3 = chestDef.color or Color3.fromRGB(255, 215, 60)
	titleLabel.ZIndex = 53
	titleLabel.Parent = headerContainer
	applyStroke(titleLabel, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Contextual)

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0, 24)
	subLabel.Position = UDim2.new(0, 0, 0, 40)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.FredokaOne
	if wasPity then
		subLabel.Text = "★ PITY GUARANTEE ACTIVATED! (GUARANTEED EPIC+) ★"
		subLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	else
		subLabel.Text = "GOOD LUCK!"
		subLabel.TextColor3 = Color3.fromRGB(210, 215, 225)
	end
	subLabel.TextSize = 18
	subLabel.ZIndex = 53
	subLabel.Parent = headerContainer
	applyStroke(subLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- 3. SKIP gomb a jobb felső sarokban
	local skipBtn = create3DButton(
		stageOverlay,
		UDim2.fromOffset(115, 42),
		UDim2.new(1, -24, 0, 24),
		Vector2.new(1, 0),
		Color3.fromRGB(240, 140, 30),
		Color3.fromRGB(150, 75, 10),
		"SKIP >>"
	)
	skipBtn.container.ZIndex = 55
	skipBtn.button.ZIndex = 56
	skipBtn.setTextSize(18)

	-- 4. Rulett Keret & Viewport
	local rouletteContainer = Instance.new("Frame")
	rouletteContainer.Name = "RouletteContainer"
	rouletteContainer.Size = UDim2.fromOffset(660, 172)
	rouletteContainer.Position = UDim2.new(0.5, 0, 0.45, 0)
	rouletteContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	rouletteContainer.BackgroundColor3 = Color3.fromRGB(18, 15, 22)
	rouletteContainer.BorderSizePixel = 0
	rouletteContainer.ZIndex = 51
	rouletteContainer.Parent = stageOverlay
	applyStroke(rouletteContainer, Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)

	-- Díszítő arany keretsávok (fent és lent)
	local topBarAccent = Instance.new("Frame")
	topBarAccent.Size = UDim2.new(1, 0, 0, 4)
	topBarAccent.Position = UDim2.new(0, 0, 0, 0)
	topBarAccent.BackgroundColor3 = Color3.fromRGB(255, 205, 45)
	topBarAccent.BorderSizePixel = 0
	topBarAccent.ZIndex = 52
	topBarAccent.Parent = rouletteContainer

	local btmBarAccent = Instance.new("Frame")
	btmBarAccent.Size = UDim2.new(1, 0, 0, 4)
	btmBarAccent.Position = UDim2.new(0, 0, 1, -4)
	btmBarAccent.BackgroundColor3 = Color3.fromRGB(255, 205, 45)
	btmBarAccent.BorderSizePixel = 0
	btmBarAccent.ZIndex = 52
	btmBarAccent.Parent = rouletteContainer

	-- Belső Viewport (kivágja a kilógó kártyákat)
	local viewportFrame = Instance.new("Frame")
	viewportFrame.Name = "Viewport"
	viewportFrame.Size = UDim2.new(1, -16, 1, -16)
	viewportFrame.Position = UDim2.fromScale(0.5, 0.5)
	viewportFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 15)
	viewportFrame.BorderSizePixel = 0
	viewportFrame.ClipsDescendants = true
	viewportFrame.ZIndex = 52
	viewportFrame.Parent = rouletteContainer

	-- Középső aranyszínű vonal (Center Line)
	local centerLine = Instance.new("Frame")
	centerLine.Name = "CenterLine"
	centerLine.Size = UDim2.new(0, 3, 1, 0)
	centerLine.Position = UDim2.new(0.5, -1, 0, 0)
	centerLine.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	centerLine.BorderSizePixel = 0
	centerLine.ZIndex = 56
	centerLine.Parent = viewportFrame

	-- Felső arany nyíl (▼)
	local topNeedle = Instance.new("TextLabel")
	topNeedle.Name = "TopNeedle"
	topNeedle.Size = UDim2.fromOffset(26, 22)
	topNeedle.Position = UDim2.new(0.5, 0, 0, -2)
	topNeedle.AnchorPoint = Vector2.new(0.5, 0)
	topNeedle.BackgroundTransparency = 1
	topNeedle.Font = Enum.Font.FredokaOne
	topNeedle.Text = "▼"
	topNeedle.TextSize = 24
	topNeedle.TextColor3 = Color3.fromRGB(255, 215, 0)
	topNeedle.ZIndex = 57
	topNeedle.Parent = viewportFrame
	applyStroke(topNeedle, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Alsó arany nyíl (▲)
	local bottomNeedle = Instance.new("TextLabel")
	bottomNeedle.Name = "BottomNeedle"
	bottomNeedle.Size = UDim2.fromOffset(26, 22)
	bottomNeedle.Position = UDim2.new(0.5, 0, 1, 2)
	bottomNeedle.AnchorPoint = Vector2.new(0.5, 1)
	bottomNeedle.BackgroundTransparency = 1
	bottomNeedle.Font = Enum.Font.FredokaOne
	bottomNeedle.Text = "▲"
	bottomNeedle.TextSize = 24
	bottomNeedle.TextColor3 = Color3.fromRGB(255, 215, 0)
	bottomNeedle.ZIndex = 57
	bottomNeedle.Parent = viewportFrame
	applyStroke(bottomNeedle, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- 5. Kártyaszalag és elemek generálása
	local CARD_WIDTH = 110
	local CARD_HEIGHT = 136
	local CARD_SPACING = 10
	local PITCH = CARD_WIDTH + CARD_SPACING -- 120px
	local TOTAL_CARDS = 46
	local WIN_INDEX = 36
	local viewportWidth = 644
	local viewportCenter = viewportWidth / 2 -- 322px

	local canvas = Instance.new("Frame")
	canvas.Name = "ReelCanvas"
	canvas.Size = UDim2.new(0, TOTAL_CARDS * PITCH + 20, 0, CARD_HEIGHT)
	canvas.Position = UDim2.fromOffset(viewportCenter - (CARD_WIDTH / 2), 10)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ZIndex = 53
	canvas.Parent = viewportFrame

	local winningCardFrame = nil
	local winningCardStroke = nil

	for i = 1, TOTAL_CARDS do
		local cardMat = nil
		if i == WIN_INDEX then
			cardMat = mat
		elseif i == WIN_INDEX - 1 and math.random() <= 0.45 then
			-- Izgalomfokozó "near-miss": közvetlenül a nyertes előtt egy ritka tárgy (Epic/Legendary/Secret)
			local teasers = { GachaConfig.materials.Diamond, GachaConfig.materials.Star, GachaConfig.materials.Secret }
			cardMat = teasers[math.random(1, #teasers)]
		else
			cardMat = pickRandomMaterial(chestDef, wasPity)
		end

		local itemHolder = Instance.new("Frame")
		itemHolder.Name = "ItemHolder_" .. i
		itemHolder.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
		itemHolder.Position = UDim2.fromOffset((i - 1) * PITCH, 0)
		itemHolder.BackgroundTransparency = 1
		itemHolder.BorderSizePixel = 0
		itemHolder.ZIndex = 53
		itemHolder.Parent = canvas

		local _, stroke = buildRouletteCard(itemHolder, cardMat)
		if i == WIN_INDEX then
			winningCardFrame = itemHolder
			winningCardStroke = stroke
		end
	end

	-- Célkoordináták kiszámítása természetes jitterrel (-28px .. +28px)
	local jitter = math.random(-26, 26)
	local winningCardCenter = (WIN_INDEX - 1) * PITCH + (CARD_WIDTH / 2)
	local targetX = viewportCenter - winningCardCenter - jitter

	-- 6. Animáció & Eseménykezelés
	local isSkipped = false
	local hasRevealed = false
	local spinTween = nil
	local tickConnection = nil

	-- Reveal Popup (Kinyitott tárgy részletes ablaka)
	local function triggerReveal()
		if hasRevealed then
			return
		end
		hasRevealed = true

		if tickConnection then
			tickConnection:Disconnect()
			tickConnection = nil
		end

		-- Győzelmi fanfare hang
		playSound("rbxassetid://9114222045", 0.7, 1.0)

		-- Nyertes kártya felvillantása a szalagon
		if winningCardStroke then
			local origColor = winningCardStroke.Color
			task.spawn(function()
				for _ = 1, 3 do
					winningCardStroke.Color = Color3.fromRGB(255, 255, 255)
					winningCardStroke.Thickness = 5
					task.wait(0.08)
					winningCardStroke.Color = Color3.fromRGB(255, 220, 40)
					task.wait(0.08)
				end
				winningCardStroke.Color = origColor
				winningCardStroke.Thickness = 3
			end)
		end

		-- Részecske effekt (ha van játékos karakter)
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			EffectsController.burst(root.Position + Vector3.new(0, 1.5, 0), mat.color, 35)
		end

		if not isSkipped then
			task.wait(0.45)
		end

		-- 7. Részletes Reveal Modal Felépítése
		local card = Instance.new("Frame")
		card.Name = "RevealCard"
		card.Size = UDim2.fromOffset(400, 420)
		card.Position = UDim2.new(0.5, 0, 0.5, 0)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = Color3.fromRGB(22, 18, 26)
		card.BorderSizePixel = 0
		card.ZIndex = 65
		card.Parent = stageOverlay
		applyStroke(card, mat.color or Color3.fromRGB(255, 215, 60), 4.5, Enum.ApplyStrokeMode.Border)

		local cScale = Instance.new("UIScale")
		cScale.Scale = 0.6
		cScale.Parent = card

		-- Felső Fejléc Sáv
		local topBar = Instance.new("Frame")
		topBar.Size = UDim2.new(1, 0, 0, 52)
		topBar.BackgroundColor3 = mat.color or Color3.fromRGB(70, 140, 220)
		topBar.BorderSizePixel = 0
		topBar.ZIndex = 66
		topBar.Parent = card

		local topText = Instance.new("TextLabel")
		topText.Size = UDim2.fromScale(1, 1)
		topText.BackgroundTransparency = 1
		topText.Font = Enum.Font.FredokaOne
		topText.Text = wasPity and "★ PITY GUARANTEE! ★" or "★ YOU UNBOXED! ★"
		topText.TextSize = 22
		topText.TextColor3 = Color3.fromRGB(255, 255, 255)
		topText.ZIndex = 67
		topText.Parent = topBar
		applyStroke(topText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

		-- Ritkaság jelvény
		local rarityBadge = Instance.new("TextLabel")
		rarityBadge.Size = UDim2.new(1, 0, 0, 26)
		rarityBadge.Position = UDim2.new(0, 0, 0, 60)
		rarityBadge.BackgroundTransparency = 1
		rarityBadge.Font = Enum.Font.FredokaOne
		rarityBadge.Text = string.format("★ %s MATERIAL ★", (mat.rarity or "COMMON"):upper())
		rarityBadge.TextSize = 16
		rarityBadge.TextColor3 = mat.color or Color3.fromRGB(255, 215, 60)
		rarityBadge.ZIndex = 66
		rarityBadge.Parent = card
		applyStroke(rarityBadge, Color3.fromRGB(0, 0, 0), 2.2, Enum.ApplyStrokeMode.Contextual)

		-- Nagy Ikon Keret
		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.fromOffset(116, 116)
		iconFrame.Position = UDim2.new(0.5, 0, 0, 150)
		iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		iconFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
		iconFrame.BorderSizePixel = 0
		iconFrame.ZIndex = 66
		iconFrame.Parent = card
		applyStroke(iconFrame, mat.color or Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Border)

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.fromScale(1, 1)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.FredokaOne
		iconLabel.Text = mat.emoji or "?"
		iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		iconLabel.TextSize = 64
		iconLabel.ZIndex = 67
		iconLabel.Parent = iconFrame

		-- Anyag Neve
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 34)
		nameLabel.Position = UDim2.new(0, 0, 0, 222)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.Text = mat.name
		nameLabel.TextSize = 30
		nameLabel.TextColor3 = mat.color
		nameLabel.ZIndex = 66
		nameLabel.Parent = card
		applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Contextual)

		-- Statisztika Doboz (Szorzó)
		local statBox = Instance.new("Frame")
		statBox.Size = UDim2.new(0.85, 0, 0, 42)
		statBox.Position = UDim2.new(0.5, 0, 0, 268)
		statBox.AnchorPoint = Vector2.new(0.5, 0)
		statBox.BackgroundColor3 = Color3.fromRGB(30, 24, 36)
		statBox.BorderSizePixel = 0
		statBox.ZIndex = 66
		statBox.Parent = card
		applyStroke(statBox, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

		local statLabel = Instance.new("TextLabel")
		statLabel.Size = UDim2.fromScale(1, 1)
		statLabel.BackgroundTransparency = 1
		statLabel.Font = Enum.Font.FredokaOne
		statLabel.Text = string.format("GLOVE MULTIPLIER: x%.1f", mat.multiplier)
		statLabel.TextSize = 19
		statLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
		statLabel.ZIndex = 67
		statLabel.Parent = statBox
		applyStroke(statLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

		-- Alsó Gombok Tárolója (EQUIP + CLAIM)
		local btnRow = Instance.new("Frame")
		btnRow.Size = UDim2.new(1, -36, 0, 50)
		btnRow.Position = UDim2.new(0.5, 0, 0.88, 0)
		btnRow.AnchorPoint = Vector2.new(0.5, 0.5)
		btnRow.BackgroundTransparency = 1
		btnRow.BorderSizePixel = 0
		btnRow.ZIndex = 66
		btnRow.Parent = card

		local equipBtn = create3DButton(
			btnRow,
			UDim2.new(0.5, -6, 1, 0),
			UDim2.new(0, 0, 0, 0),
			Vector2.new(0, 0),
			Color3.fromRGB(46, 204, 113),
			Color3.fromRGB(25, 125, 52),
			"EQUIP"
		)
		equipBtn.container.ZIndex = 68
		equipBtn.button.ZIndex = 69
		equipBtn.setTextSize(20)

		local claimBtn = create3DButton(
			btnRow,
			UDim2.new(0.5, -6, 1, 0),
			UDim2.new(0.5, 6, 0, 0),
			Vector2.new(0, 0),
			Color3.fromRGB(70, 140, 220),
			Color3.fromRGB(35, 75, 125),
			"CLAIM"
		)
		claimBtn.container.ZIndex = 68
		claimBtn.button.ZIndex = 69
		claimBtn.setTextSize(20)

		local function closeStage()
			TweenService:Create(cScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.5 }):Play()
			local fade = TweenService:Create(stageOverlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Connect(function()
				stageOverlay:Destroy()
				isSpinning = false
				refreshHeaderInfo()
				-- Chest menü automatikus újranyitása
				GachaController.open()
			end)
		end

		equipBtn.onClick(function()
			if not isPreview then
				local remote = Net.get("EquipMaterial")
				if remote then
					remote:FireServer(mat.id)
				end
			end
			currentData.equippedMaterial = mat.id
			currentData.materialMultiplier = mat.multiplier
			closeStage()
		end)

		claimBtn.onClick(function()
			closeStage()
		end)

		stageOverlay.MouseButton1Click:Connect(function()
			closeStage()
		end)

		TweenService:Create(
			cScale,
			TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.0 }
		):Play()
	end

	-- SKIP gomb kattintása: azonnal leállítja a pörgést és felfedi az eredményt
	skipBtn.onClick(function()
		if isSkipped or hasRevealed then
			return
		end
		isSkipped = true
		if spinTween then
			spinTween:Cancel()
		end
		if tickConnection then
			tickConnection:Disconnect()
			tickConnection = nil
		end
		canvas.Position = UDim2.fromOffset(targetX, 10)
		playSound("rbxassetid://9114223170", 0.5, 1.2)
		triggerReveal()
	end)

	-- Tikkelő hang és mutató mozgás követése (RunService.RenderStepped)
	local lastTickIndex = 1
	tickConnection = RunService.RenderStepped:Connect(function()
		if not canvas or not canvas.Parent then
			if tickConnection then
				tickConnection:Disconnect()
			end
			return
		end
		local currentOffset = viewportCenter - canvas.Position.X.Offset
		local currentIndex = math.clamp(math.floor(currentOffset / PITCH) + 1, 1, TOTAL_CARDS)
		if currentIndex ~= lastTickIndex then
			lastTickIndex = currentIndex
			playSound("rbxassetid://9114223170", 0.45, 0.95 + math.random() * 0.1)
			if topNeedle and bottomNeedle then
				topNeedle.Position = UDim2.new(0.5, 0, 0, -4)
				bottomNeedle.Position = UDim2.new(0.5, 0, 1, 4)
				TweenService:Create(topNeedle, TweenInfo.new(0.08), { Position = UDim2.new(0.5, 0, 0, -2) }):Play()
				TweenService:Create(bottomNeedle, TweenInfo.new(0.08), { Position = UDim2.new(0.5, 0, 1, 2) }):Play()
			end
		end
	end)

	-- 4.3 másodperces sima exponenciális lassulás (CS:GO stílus)
	spinTween = TweenService:Create(
		canvas,
		TweenInfo.new(4.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(targetX, 10) }
	)

	spinTween.Completed:Connect(function()
		if not isSkipped then
			triggerReveal()
		end
	end)

	spinTween:Play()
end

-- Egy Láda Kártya létrehozása
local function createChestCard(parent, chestDef, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = "ChestCard_" .. chestDef.id
	card.Size = UDim2.new(1, 0, 0, 96)
	card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 15
	card.Parent = parent

	-- A fekete keret a külső frame maga; a színes kártya beljebb van,
	-- így a scrollframe széle nem tudja levágni a keretet.
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.new(1, -7, 1, -7)
	inner.Position = UDim2.fromOffset(3.5, 3.5)
	inner.BackgroundColor3 = chestDef.color
	inner.BorderSizePixel = 0
	inner.ZIndex = 16
	inner.Parent = card

	-- Bal oldali láda doboz
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.fromOffset(72, 72)
	iconBox.Position = UDim2.new(0, 12, 0.5, 0)
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
	iconBox.BackgroundTransparency = 0.35
	iconBox.BorderSizePixel = 0
	iconBox.ZIndex = 17
	iconBox.Parent = inner
	applyStroke(iconBox, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = chestDef.icon or "?"
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextSize = 38
	iconLabel.ZIndex = 18
	iconLabel.Parent = iconBox

	-- Középső információs rész
	local infoFrame = Instance.new("Frame")
	infoFrame.Position = UDim2.new(0, 98, 0, 8)
	infoFrame.Size = UDim2.new(1, -250, 1, -16)
	infoFrame.BackgroundTransparency = 1
	infoFrame.BorderSizePixel = 0
	infoFrame.ZIndex = 17
	infoFrame.Parent = inner

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = chestDef.name
	nameLabel.TextSize = 24
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 18
	nameLabel.Parent = infoFrame
	applyStroke(nameLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Esélyek leírása
	local oddsSummary = {}
	for _, entry in ipairs(chestDef.pool) do
		local m = GachaConfig.materials[entry.material]
		if m then
			table.insert(oddsSummary, m.name)
		end
	end

	local descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.new(0, 0, 0, 36)
	descLabel.Size = UDim2.new(1, 0, 0, 24)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.FredokaOne
	descLabel.Text = "Drops: " .. table.concat(oddsSummary, ", ")
	descLabel.TextSize = 16
	descLabel.TextColor3 = Color3.fromRGB(255, 255, 210)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.ZIndex = 18
	descLabel.Parent = infoFrame
	applyStroke(descLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Jobb oldali éles 3D OPEN gomb
	local costLabelText = (chestDef.cost == 0 and "FREE") or Format.money(chestDef.cost)
	local openBtn = create3DButton(
		inner,
		UDim2.fromOffset(130, 52),
		UDim2.new(1, -12, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		costLabelText
	)
	openBtn.container.ZIndex = 18
	openBtn.button.ZIndex = 19

	local lastOpenClick = 0
	local function triggerChestOpen()
		local now = os.clock()
		if now - lastOpenClick < 0.3 then
			return
		end
		lastOpenClick = now

		if isSpinning then
			return
		end

		-- Kliens-oldali cash ellenőrzés
		if chestDef.cost > 0 and currentData.cash < chestDef.cost then
			return
		end

		-- Szerver értesítése (adatmentés, pity, stb.) — háttérben fut
		local remote = Net.get("OpenChest")
		if remote then
			remote:FireServer(chestDef.id)
		end

		-- Kliens-oldali cash levonás az azonnali UI frissítéshez
		currentData.cash = math.max(0, currentData.cash - chestDef.cost)

		-- Chest UI bezárása
		GachaController.close()

		-- Kliens-oldali roll (vizuális animációhoz)
		local rolledMat = pickRandomMaterial(chestDef, false)

		-- Case opening animáció azonnali indítása!
		local ok, err = pcall(startCaseOpening, {
			material = rolledMat,
			wasPity = false,
			pity = currentData.pityCount or 0,
			chest = chestDef,
		})
		if not ok then
			warn("[GACHA-CLIENT] startCaseOpening ERROR:", tostring(err))
			isSpinning = false
		end
	end

	openBtn.onClick(triggerChestOpen)
end

-- A teljes felület felépítése
local function buildUI(screenGui)
	activeScreenGui = screenGui

	-- 1. HUD Gomb (Képernyő bal oldalán, az Upgrades gomb alatt)
	local hudWrapper = Instance.new("Frame")
	hudWrapper.Name = "GachaHudWrapper"
	hudWrapper.Size = UDim2.fromOffset(76, 76)
	hudWrapper.Position = UDim2.new(0, 106, 0.5, -43)
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
	hudText.Text = "CHESTS"
	hudText.TextSize = 16
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 3.2, Enum.ApplyStrokeMode.Contextual)
	UiIcons.decorateMenuButton(hudBtn3D.button, hudText, "chests")

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
	modalOverlay.Active = false
	modalOverlay.InputSink = Enum.InputSink.None
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 12
	modalOverlay.Parent = screenGui

	-- Fő Ablak (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "GachaWindow"
	windowFrame.Size = UDim2.fromOffset(530, 460)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 16)
	windowFrame.BackgroundTransparency = 0.1
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 13
	windowFrame.Parent = modalOverlay
	applyStroke(windowFrame, Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Border)

	windowScale = Instance.new("UIScale")
	windowScale.Scale = 1
	windowScale.Parent = windowFrame

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

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -84, 1, 0)
	headerTitle.Position = UDim2.fromOffset(18, 0)
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

	local headerTitleGradient = Instance.new("UIGradient")
	headerTitleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	headerTitleGradient.Rotation = 90
	headerTitleGradient.Parent = headerTitle

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
	closeBtn3D.setTextSize(28)
	closeBtn3D.button.MouseButton1Click:Connect(function()
		GachaController.close()
	end)

	-- SubHeader: Felszerelt kesztyű-anyag és Pity állapot
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -24, 0, 30)
	subHeader.Position = UDim2.new(0, 12, 0, 76)
	subHeader.BackgroundTransparency = 1
	subHeader.BorderSizePixel = 0
	subHeader.ZIndex = 14
	subHeader.Parent = windowFrame

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
	pityLabel.Text = string.format("Pity: 0/%d", GachaConfig.pityThreshold)
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
	scrollFrame.ScrollBarImageTransparency = 1
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
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
	listPadding.PaddingLeft = UDim.new(0, 8)
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
	isPreview = hud ~= nil and hud.preview == true
	MenuCoordinator.register(MENU_NAME, GachaController.close)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)
	if isPreview then
		return
	end

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

	-- Ládanyitás eredményének fogadása — csak adat-szinkron (animáció kliens-oldalon már lefutott)
	local openedRemote = Net.get("ChestOpened")
	if openedRemote then
		openedRemote.OnClientEvent:Connect(function(result)
			if result then
				currentData.pityCount = result.pity or currentData.pityCount
				refreshHeaderInfo()
			end
		end)
	end
end

return GachaController
