-- DailyRewardController: Napi jutalom rendszer és UI (éles sarkokkal, 7 napos elrendezéssel)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewardsConfig = require(Shared.Config.DailyRewards)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local DailyRewardController = {}

-- Állapot
local isModalOpen = false
local dailyData = {
	streak = 0,
	lastClaim = 0,
	canClaim = true,
}

local dayCards = {}
local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local timerConnection = nil
local notifBadge = nil

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

-- Idő formázása (pl. "In 23h 45m" vagy "In 15m")
local function formatRemainingTime(seconds)
	if seconds <= 0 then
		return "READY!"
	end
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("In %dh", hours)
	else
		return string.format("In %dm", math.max(1, mins))
	end
end

-- Napi jutalom kártyák állapotának frissítése
local function refreshCards()
	local now = os.time()
	local timeSince = now - dailyData.lastClaim
	local canClaim = (dailyData.lastClaim == 0) or (timeSince >= DailyRewardsConfig.cooldown)
	dailyData.canClaim = canClaim
	local remaining = math.max(0, DailyRewardsConfig.cooldown - timeSince)

	if notifBadge then
		notifBadge.Visible = canClaim
	end

	local claimedCount = dailyData.streak or 0
	if claimedCount >= 7 and canClaim then
		claimedCount = 0
	end

	local nextClaimDay = math.min(7, claimedCount + 1)

	for dayNum, elements in pairs(dayCards) do
		local def = DailyRewardsConfig.days[dayNum]
		local isClaimed = (dayNum <= claimedCount)
		local isCurrent = (dayNum == nextClaimDay)

		if isClaimed then
			elements.checkMark.Visible = true
			elements.dimOverlay.Visible = true
			elements.claimBtn.container.Visible = false
			elements.titleLabel.Text = def.title
			if elements.statusLabel then
				elements.statusLabel.Visible = false
			end
		elseif isCurrent and canClaim then
			elements.checkMark.Visible = false
			elements.dimOverlay.Visible = false
			elements.claimBtn.container.Visible = true
			elements.titleLabel.Text = def.title
			if elements.statusLabel then
				elements.statusLabel.Visible = false
			end
		elseif isCurrent and not canClaim then
			elements.checkMark.Visible = false
			elements.dimOverlay.Visible = false
			elements.claimBtn.container.Visible = false
			elements.titleLabel.Text = formatRemainingTime(remaining)
			if elements.statusLabel then
				elements.statusLabel.Visible = false
			end
		else
			elements.checkMark.Visible = false
			elements.dimOverlay.Visible = false
			elements.claimBtn.container.Visible = false
			elements.titleLabel.Text = def.title
			if elements.statusLabel then
				elements.statusLabel.Visible = false
			end
		end
	end
end

-- Modal nyitás / zárás
function DailyRewardController.open()
	if isModalOpen then
		return
	end
	isModalOpen = true
	refreshCards()

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

function DailyRewardController.close()
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

function DailyRewardController.toggle()
	if isModalOpen then
		DailyRewardController.close()
	else
		DailyRewardController.open()
	end
end

-- Egy kártya létrehozása a rácsban (ÉLES SAROK, VASTAG FEKETE KERET)
local function createDayCard(parent, def, size, pos)
	local card = Instance.new("Frame")
	card.Name = "DayCard_" .. def.day
	card.Size = size
	card.Position = pos
	card.BackgroundColor3 = def.color or Color3.fromRGB(40, 35, 30)
	card.BorderSizePixel = 0
	card.Parent = parent

	-- Éles, vastag fekete keret
	applyStroke(card, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	-- Kártya Cím (pl. "Day 1" vagy "Day 7")
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "DayTitle"
	titleLabel.Size = UDim2.new(1, 0, 0, def.isBig and 34 or 26)
	titleLabel.Position = UDim2.fromOffset(0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.BorderSizePixel = 0
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = def.title
	titleLabel.TextSize = def.isBig and 26 or 20
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Parent = card
	applyStroke(titleLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Kártya Ikon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = def.isBig and UDim2.fromOffset(84, 84) or UDim2.fromOffset(54, 54)
	iconLabel.Position = def.isBig and UDim2.new(0.5, 0, 0.46, 0) or UDim2.new(0.5, 0, 0.5, 0)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.BorderSizePixel = 0
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.Text = def.emoji or "🎁"
	iconLabel.TextSize = def.isBig and 56 or 36
	iconLabel.Parent = card

	-- Jutalom Szöveg alul (pl. "$5K" vagy "OP Pet")
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "RewardText"
	rewardLabel.Size = UDim2.new(1, 0, 0, def.isBig and 32 or 24)
	rewardLabel.Position = UDim2.new(0, 0, 1, def.isBig and -36 or -26)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.BorderSizePixel = 0
	rewardLabel.Font = Enum.Font.FredokaOne
	rewardLabel.Text = def.displayReward
	rewardLabel.TextSize = def.isBig and 24 or 17
	rewardLabel.TextColor3 = def.isBig and Color3.fromRGB(50, 255, 60) or Color3.fromRGB(255, 255, 255)
	rewardLabel.Parent = card
	applyStroke(rewardLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Státusz címke (pl. "In 23h")
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.Position = UDim2.fromOffset(0, 4)
	statusLabel.BackgroundTransparency = 1
	statusLabel.BorderSizePixel = 0
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.Text = "In 24h"
	statusLabel.TextSize = 18
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.Visible = false
	statusLabel.ZIndex = 5
	statusLabel.Parent = card
	applyStroke(statusLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Sötétítő réteg (Claimed állapotban)
	local dimOverlay = Instance.new("Frame")
	dimOverlay.Name = "Dim"
	dimOverlay.Size = UDim2.fromScale(1, 1)
	dimOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimOverlay.BackgroundTransparency = 0.45
	dimOverlay.BorderSizePixel = 0
	dimOverlay.Visible = false
	dimOverlay.ZIndex = 3
	dimOverlay.Parent = card

	-- ÓRIÁSI ZÖLD PIPA (✔) ha már átvéve (pontosan mint a referenciaképen!)
	local checkMark = Instance.new("TextLabel")
	checkMark.Name = "CheckMark"
	checkMark.Size = UDim2.fromScale(1, 1)
	checkMark.Position = UDim2.new(0, 0, 0, 0)
	checkMark.BackgroundTransparency = 1
	checkMark.BorderSizePixel = 0
	checkMark.Font = Enum.Font.FredokaOne
	checkMark.Text = "✔"
	checkMark.TextSize = def.isBig and 86 or 64
	checkMark.TextColor3 = Color3.fromRGB(50, 255, 60)
	checkMark.Visible = false
	checkMark.ZIndex = 4
	checkMark.Parent = card
	applyStroke(checkMark, Color3.fromRGB(0, 0, 0), 4, Enum.ApplyStrokeMode.Contextual)

	-- CLAIM gomb ha átvehető
	local claimBtn = create3DButton(
		card,
		def.isBig and UDim2.fromOffset(130, 46) or UDim2.fromOffset(92, 36),
		UDim2.new(0.5, 0, 0.5, 0),
		Vector2.new(0.5, 0.5),
		Color3.fromRGB(50, 220, 80),
		Color3.fromRGB(25, 130, 50),
		"CLAIM"
	)
	claimBtn.container.ZIndex = 6
	claimBtn.button.ZIndex = 7
	claimBtn.container.Visible = false

	claimBtn.button.MouseButton1Click:Connect(function()
		local remote = Net.get("ClaimDailyReward")
		if remote then
			remote:FireServer()
		end
	end)

	dayCards[def.day] = {
		card = card,
		titleLabel = titleLabel,
		rewardLabel = rewardLabel,
		statusLabel = statusLabel,
		checkMark = checkMark,
		dimOverlay = dimOverlay,
		claimBtn = claimBtn,
	}
end

-- A teljes felület felépítése
local function buildUI(screenGui)
	-- 1. HUD Gomb a JOBB FELSŐ SAROKBAN ("Daily Reward" ajándékdoboz)
	local hudWrapper = Instance.new("Frame")
	hudWrapper.Name = "DailyRewardHudWrapper"
	hudWrapper.Size = UDim2.fromOffset(164, 56)
	hudWrapper.Position = UDim2.new(1, -20, 0, 20)
	hudWrapper.AnchorPoint = Vector2.new(1, 0)
	hudWrapper.BackgroundTransparency = 1
	hudWrapper.BorderSizePixel = 0
	hudWrapper.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudWrapper,
		UDim2.fromScale(1, 1),
		UDim2.new(0, 0, 0, 0),
		Vector2.new(0, 0),
		Color3.fromRGB(230, 55, 60), -- Piros ajándékdoboz szín
		Color3.fromRGB(150, 25, 30),
		""
	)

	-- Ajándékdoboz ikon
	local giftIcon = Instance.new("TextLabel")
	giftIcon.Name = "GiftIcon"
	giftIcon.Size = UDim2.fromOffset(36, 36)
	giftIcon.Position = UDim2.new(0, 8, 0.5, -18)
	giftIcon.BackgroundTransparency = 1
	giftIcon.BorderSizePixel = 0
	giftIcon.Font = Enum.Font.FredokaOne
	giftIcon.Text = "🎁"
	giftIcon.TextSize = 30
	giftIcon.Parent = hudBtn3D.button

	-- Szöveg a gombon
	local hudText = Instance.new("TextLabel")
	hudText.Name = "Label"
	hudText.Size = UDim2.new(1, -48, 1, 0)
	hudText.Position = UDim2.new(0, 44, 0, 0)
	hudText.BackgroundTransparency = 1
	hudText.BorderSizePixel = 0
	hudText.Font = Enum.Font.FredokaOne
	hudText.Text = "DAILY REWARD"
	hudText.TextSize = 16
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Értesítő badge (zöld vagy sárga felkiáltójel)
	notifBadge = Instance.new("Frame")
	notifBadge.Name = "NotifBadge"
	notifBadge.Size = UDim2.fromOffset(22, 22)
	notifBadge.Position = UDim2.new(0, -4, 0, -4)
	notifBadge.BackgroundColor3 = Color3.fromRGB(50, 255, 60)
	notifBadge.BorderSizePixel = 0
	notifBadge.Visible = false
	notifBadge.ZIndex = 6
	notifBadge.Parent = hudWrapper
	applyStroke(notifBadge, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	local notifText = Instance.new("TextLabel")
	notifText.Size = UDim2.fromScale(1, 1)
	notifText.BackgroundTransparency = 1
	notifText.BorderSizePixel = 0
	notifText.Font = Enum.Font.FredokaOne
	notifText.Text = "!"
	notifText.TextSize = 15
	notifText.TextColor3 = Color3.fromRGB(0, 0, 0)
	notifText.Parent = notifBadge

	hudBtn3D.button.MouseButton1Click:Connect(function()
		DailyRewardController.toggle()
	end)

	hudButton = hudWrapper

	-- 2. Modal felület (Sötétítő háttér + Éles Ablak)
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "DailyRewardModalOverlay"
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Position = UDim2.new(0, 0, 0, 0)
	modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalOverlay.BackgroundTransparency = 1
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Text = ""
	modalOverlay.AutoButtonColor = false
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 15
	modalOverlay.Parent = screenGui

	modalOverlay.MouseButton1Click:Connect(function()
		DailyRewardController.close()
	end)

	-- Fő Ablak (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "DailyRewardWindow"
	windowFrame.Size = UDim2.fromOffset(560, 390)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 16
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

	-- FEJLÉC (Meleg arany/barna árnyalat, pontosan mint a képen)
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 68)
	headerBar.BackgroundColor3 = Color3.fromRGB(220, 165, 95)
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 17
	headerBar.Parent = windowFrame

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 185, 115)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 140, 75)),
	})
	headerGradient.Rotation = 90
	headerGradient.Parent = headerBar

	-- Fekete vonal a fejléc alatt
	local headerDiv = Instance.new("Frame")
	headerDiv.Size = UDim2.new(1, 0, 0, 4)
	headerDiv.Position = UDim2.new(0, 0, 1, -4)
	headerDiv.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	headerDiv.BorderSizePixel = 0
	headerDiv.ZIndex = 18
	headerDiv.Parent = headerBar

	-- Ajándékdoboz ikon a fejlécben
	local headGiftIcon = Instance.new("TextLabel")
	headGiftIcon.Size = UDim2.fromOffset(48, 48)
	headGiftIcon.Position = UDim2.new(0, 14, 0.5, -24)
	headGiftIcon.BackgroundTransparency = 1
	headGiftIcon.BorderSizePixel = 0
	headGiftIcon.Font = Enum.Font.FredokaOne
	headGiftIcon.Text = "🎁"
	headGiftIcon.TextSize = 42
	headGiftIcon.ZIndex = 18
	headGiftIcon.Parent = headerBar

	-- Fejléc Cím: "DAILY REWARD"
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(0, 320, 1, 0)
	headerTitle.Position = UDim2.new(0, 68, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.BorderSizePixel = 0
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.Text = "DAILY REWARD"
	headerTitle.TextSize = 34
	headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 18
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
	closeBtn3D.container.ZIndex = 18
	closeBtn3D.button.ZIndex = 19
	closeBtn3D.button.TextSize = 28
	closeBtn3D.button.MouseButton1Click:Connect(function()
		DailyRewardController.close()
	end)

	-- Alsáv: "Login every day to keep your streak!" (Pontosan mint a képen)
	local subBanner = Instance.new("Frame")
	subBanner.Name = "SubBanner"
	subBanner.Size = UDim2.new(1, -24, 0, 32)
	subBanner.Position = UDim2.new(0, 12, 0, 76)
	subBanner.BackgroundColor3 = Color3.fromRGB(16, 12, 10)
	subBanner.BorderSizePixel = 0
	subBanner.ZIndex = 17
	subBanner.Parent = windowFrame
	applyStroke(subBanner, Color3.fromRGB(120, 75, 40), 2, Enum.ApplyStrokeMode.Border)

	local bannerText = Instance.new("TextLabel")
	bannerText.Size = UDim2.fromScale(1, 1)
	bannerText.BackgroundTransparency = 1
	bannerText.BorderSizePixel = 0
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.Text = "Login every day to keep your streak!"
	bannerText.TextSize = 20
	bannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bannerText.ZIndex = 18
	bannerText.Parent = subBanner
	applyStroke(bannerText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- JUTALMAK RÁCSA (Bal oldal: 3 oszlop x 2 sor, Jobb oldal: Day 7 Nagy Kártya)
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(1, -24, 1, -122)
	gridContainer.Position = UDim2.new(0, 12, 0, 114)
	gridContainer.BackgroundTransparency = 1
	gridContainer.BorderSizePixel = 0
	gridContainer.ZIndex = 17
	gridContainer.Parent = windowFrame

	-- Bal oldali 6 kártya (Day 1 - Day 6)
	-- Oszlop szélesség: ~118px, Magasság: ~124px, Hézag: 8px
	local colWidth = 120
	local rowHeight = 120
	local gapX = 8
	local gapY = 8

	local dayPositions = {
		[1] = UDim2.new(0, 0 * (colWidth + gapX), 0, 0),
		[2] = UDim2.new(0, 1 * (colWidth + gapX), 0, 0),
		[3] = UDim2.new(0, 2 * (colWidth + gapX), 0, 0),
		[4] = UDim2.new(0, 0 * (colWidth + gapX), 0, rowHeight + gapY),
		[5] = UDim2.new(0, 1 * (colWidth + gapX), 0, rowHeight + gapY),
		[6] = UDim2.new(0, 2 * (colWidth + gapX), 0, rowHeight + gapY),
	}

	for i = 1, 6 do
		local def = DailyRewardsConfig.days[i]
		createDayCard(gridContainer, def, UDim2.fromOffset(colWidth, rowHeight), dayPositions[i])
	end

	-- Jobb oldali Day 7 Nagy Kártya (Teljes magasságot átfogó)
	local bigWidth = 146
	local bigHeight = rowHeight * 2 + gapY
	local bigPos = UDim2.new(0, 3 * (colWidth + gapX), 0, 0)
	local day7Def = DailyRewardsConfig.days[7]
	createDayCard(gridContainer, day7Def, UDim2.fromOffset(bigWidth, bigHeight), bigPos)

	refreshCards()
end

-- Inicializálás
function DailyRewardController.init(hud)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)

	-- Szerver adatok figyelése
	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				dailyData.streak = snapshot.dailyStreak or dailyData.streak
				dailyData.lastClaim = snapshot.lastDailyClaim or dailyData.lastClaim
				dailyData.canClaim = snapshot.canClaimDaily ~= nil and snapshot.canClaimDaily or dailyData.canClaim
				refreshCards()
			end
		end)
	end

	-- Időzítő másodpercenként (ha lejár a 24h cooldown a menü nyitva léte alatt, azonnal feloldódik)
	task.spawn(function()
		while true do
			task.wait(1)
			if isModalOpen then
				refreshCards()
			end
		end
	end)
end

return DailyRewardController

