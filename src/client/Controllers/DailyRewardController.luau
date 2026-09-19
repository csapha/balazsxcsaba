-- DailyRewardController: Napi jutalom rendszer és UI (éles sarkokkal, 7 napos elrendezéssel)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewardsConfig = require(Shared.Config.DailyRewards)
local Net = require(Shared.Net)
local MenuCoordinator = require(script.Parent.MenuCoordinator)

local player = Players.LocalPlayer

local DailyRewardController = {}
local MENU_NAME = "dailyReward"

-- Állapot
local isModalOpen = false
local dailyData = {
	streak = 0,
	lastClaim = 0,
	canClaim = true,
}

local dayCards = {}
local dailyIcon = nil
local noticeShown = false
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local timerConnection = nil
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

-- Éles 3D gomb készítése
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

	if dailyIcon then
		if canClaim and not noticeShown then
			noticeShown = true
			dailyIcon:notify()
		elseif not canClaim and noticeShown then
			noticeShown = false
			dailyIcon:clearNotices()
		end
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
	MenuCoordinator.opening(MENU_NAME)
	isModalOpen = true
	refreshCards()

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

function DailyRewardController.close()
	if not isModalOpen then
		return
	end
	isModalOpen = false

	if dailyIcon then
		dailyIcon:deselect()
	end

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

function DailyRewardController.destroy()
	isModalOpen = false
	MenuCoordinator.closed(MENU_NAME)
	noticeShown = false

	if dailyIcon then
		pcall(function()
			dailyIcon:destroy()
		end)
		dailyIcon = nil
	end

	if modalOverlay then
		modalOverlay:Destroy()
		modalOverlay = nil
	end

	windowFrame = nil
	windowScale = nil
	dayCards = {}
	MenuCoordinator.unregister(MENU_NAME, DailyRewardController.close)
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
	iconLabel.Text = "?"
	iconLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
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
		if isPreview then
			return
		end

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
	-- Modal felület (Sötétítő háttér + Éles Ablak)
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "DailyRewardModalOverlay"
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
	modalOverlay.ZIndex = 15
	modalOverlay.Parent = screenGui

	-- Fő Ablak (ÉLES SAROK, VASTAG FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "DailyRewardWindow"
	windowFrame.Size = UDim2.fromOffset(560, 390)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
	windowFrame.BackgroundTransparency = 0.1
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
	windowBlocker.Active = false
	windowBlocker.InputSink = Enum.InputSink.None
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

	-- Fejléc Cím: "DAILY REWARD"
	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -84, 1, 0)
	headerTitle.Position = UDim2.fromOffset(18, 0)
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
	closeBtn3D.container.ZIndex = 18
	closeBtn3D.button.ZIndex = 19
	closeBtn3D.setTextSize(28)
	closeBtn3D.button.MouseButton1Click:Connect(function()
		DailyRewardController.close()
	end)

	-- Alsó szöveg: "Login every day to keep your streak!"
	local bannerText = Instance.new("TextLabel")
	bannerText.Name = "SubBanner"
	bannerText.Size = UDim2.new(1, -24, 0, 32)
	bannerText.Position = UDim2.new(0, 12, 0, 76)
	bannerText.BackgroundTransparency = 1
	bannerText.BorderSizePixel = 0
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.Text = "Login every day to keep your streak!"
	bannerText.TextSize = 20
	bannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bannerText.ZIndex = 18
	bannerText.Parent = windowFrame
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
	isPreview = hud ~= nil and hud.preview == true
	MenuCoordinator.register(MENU_NAME, DailyRewardController.close)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local isLivePlayerGui = RunService:IsRunning()
		and playerGui ~= nil
		and screenGui:IsDescendantOf(playerGui)

	-- TopbarPlus must never start in Studio Edit/UI Labs: it needs a live viewport.
	if not isPreview and isLivePlayerGui then
		local TopbarPlus = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("TopbarPlus"))
		dailyIcon = TopbarPlus.new()
		dailyIcon:setName("DailyReward")
		dailyIcon:setLabel("DAILY")
		dailyIcon:setOrder(1)
		dailyIcon:bindEvent("selected", function()
			DailyRewardController.open()
		end)
		dailyIcon:bindEvent("deselected", function()
			DailyRewardController.close()
		end)
	end

	buildUI(screenGui)
	if isPreview then
		return
	end

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

