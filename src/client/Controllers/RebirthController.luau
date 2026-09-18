-- RebirthController: Rebirth ("New Hands") UI és HUD gomb (éles sarkokkal)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.Rebirth)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local RebirthController = {}

-- Állapot
local isModalOpen = false
local currentData = {
	power = 0,
	rebirths = 0,
	rebirthMultiplier = 1.0,
	nextRebirthPower = RebirthConfig.getPowerRequired(0),
	activeSkin = "Skin_Default",
	canRebirth = false,
}

local hudButton = nil
local modalOverlay = nil
local windowFrame = nil
local windowScale = nil
local notifBadge = nil

-- UI elemek a modálban
local currentMultiLabel = nil
local nextMultiLabel = nil
local rebirthCountLabel = nil
local skinRewardLabel = nil
local powerProgressFill = nil
local powerProgressText = nil
local actionBtn = nil

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
	shadowFrame.BackgroundColor3 = shadowColor or Color3.fromRGB(80, 20, 140)
	shadowFrame.BorderSizePixel = 0
	shadowFrame.Parent = parent
	applyStroke(shadowFrame, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local topButton = Instance.new("TextButton")
	topButton.Name = "TopFace"
	topButton.Size = UDim2.new(1, 0, 1, -5)
	topButton.Position = UDim2.new(0, 0, 0, 0)
	topButton.BackgroundColor3 = mainColor or Color3.fromRGB(145, 45, 235)
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

-- Adatok és felület frissítése
local function refreshUI()
	local rebirths = currentData.rebirths or 0
	local curMulti = RebirthConfig.getMultiplier(rebirths)
	local nextMulti = RebirthConfig.getMultiplier(rebirths + 1)
	local reqPower = RebirthConfig.getPowerRequired(rebirths)
	local curPower = currentData.power or 0
	local canRebirth = curPower >= reqPower
	currentData.canRebirth = canRebirth

	if notifBadge then
		notifBadge.Visible = canRebirth
	end

	if currentMultiLabel then
		currentMultiLabel.Text = string.format("%.1fx", curMulti)
	end
	if nextMultiLabel then
		nextMultiLabel.Text = string.format("%.1fx", nextMulti)
	end
	if rebirthCountLabel then
		rebirthCountLabel.Text = string.format("Rebirths: %d", rebirths)
	end

	-- Következő kesztyű skin
	if skinRewardLabel then
		local nextSkin = RebirthConfig.getSkin(rebirths + 1)
		skinRewardLabel.Text = string.format("Skin: %s %s", nextSkin.emoji, nextSkin.name)
		skinRewardLabel.TextColor3 = nextSkin.color
	end

	-- Erő progressz sáv
	if powerProgressFill and powerProgressText then
		local ratio = math.clamp(curPower / math.max(reqPower, 1), 0, 1)
		powerProgressFill.Size = UDim2.fromScale(ratio, 1)
		powerProgressFill.BackgroundColor3 = canRebirth and Color3.fromRGB(50, 255, 60) or Color3.fromRGB(0, 210, 255)
		powerProgressText.Text = string.format("%s / %s Power (%d%%)", Format.number(curPower), Format.number(reqPower), math.floor(ratio * 100))
	end

	-- Akció gomb állapota
	if actionBtn then
		if canRebirth then
			actionBtn.setText("REBIRTH NOW!")
			actionBtn.setColor(Color3.fromRGB(46, 204, 113), Color3.fromRGB(25, 125, 52))
		else
			local needed = reqPower - curPower
			actionBtn.setText("NEED " .. Format.number(needed) .. " POWER")
			actionBtn.setColor(Color3.fromRGB(150, 70, 60), Color3.fromRGB(90, 35, 30))
		end
	end
end

-- Modal megnyitása / bezárása
function RebirthController.open()
	if isModalOpen then
		return
	end
	isModalOpen = true
	refreshUI()

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

function RebirthController.close()
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

function RebirthController.toggle()
	if isModalOpen then
		RebirthController.close()
	else
		RebirthController.open()
	end
end

-- A teljes felület felépítése (ÉLES SAROK, VASTAG FEKETE KERETEK)
local function buildUI(screenGui)
	-- 1. HUD Rebirth Gomb (a CHESTS alatt a bal oldalon)
	local hudWrapper = Instance.new("Frame")
	hudWrapper.Name = "RebirthHudWrapper"
	hudWrapper.Size = UDim2.fromOffset(148, 52)
	hudWrapper.Position = UDim2.new(0, 20, 0.5, 32)
	hudWrapper.AnchorPoint = Vector2.new(0, 0.5)
	hudWrapper.BackgroundTransparency = 1
	hudWrapper.BorderSizePixel = 0
	hudWrapper.Parent = screenGui

	local hudBtn3D = create3DButton(
		hudWrapper,
		UDim2.fromScale(1, 1),
		UDim2.new(0, 0, 0, 0),
		Vector2.new(0, 0),
		Color3.fromRGB(155, 45, 235), -- Rebirth lila
		Color3.fromRGB(90, 20, 145),
		""
	)

	local rebirthIcon = Instance.new("TextLabel")
	rebirthIcon.Size = UDim2.fromOffset(36, 36)
	rebirthIcon.Position = UDim2.new(0, 8, 0.5, -18)
	rebirthIcon.BackgroundTransparency = 1
	rebirthIcon.BorderSizePixel = 0
	rebirthIcon.Font = Enum.Font.FredokaOne
	rebirthIcon.Text = "🔄"
	rebirthIcon.TextSize = 26
	rebirthIcon.Parent = hudBtn3D.button

	local hudText = Instance.new("TextLabel")
	hudText.Name = "Label"
	hudText.Size = UDim2.new(1, -44, 1, 0)
	hudText.Position = UDim2.new(0, 40, 0, 0)
	hudText.BackgroundTransparency = 1
	hudText.BorderSizePixel = 0
	hudText.Font = Enum.Font.FredokaOne
	hudText.Text = "REBIRTH"
	hudText.TextSize = 18
	hudText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudText.TextXAlignment = Enum.TextXAlignment.Center
	hudText.Parent = hudBtn3D.button
	applyStroke(hudText, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- Értesítő badge ha a játékos elérte a rebirthhez szükséges erőt
	notifBadge = Instance.new("Frame")
	notifBadge.Name = "NotifBadge"
	notifBadge.Size = UDim2.fromOffset(22, 22)
	notifBadge.Position = UDim2.new(1, -4, 0, -4)
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
		RebirthController.toggle()
	end)

	hudButton = hudWrapper

	-- 2. Modal felület
	modalOverlay = Instance.new("TextButton")
	modalOverlay.Name = "RebirthModalOverlay"
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Position = UDim2.new(0, 0, 0, 0)
	modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalOverlay.BackgroundTransparency = 1
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Text = ""
	modalOverlay.AutoButtonColor = false
	modalOverlay.Visible = false
	modalOverlay.ZIndex = 20
	modalOverlay.Parent = screenGui

	modalOverlay.MouseButton1Click:Connect(function()
		RebirthController.close()
	end)

	-- Fő Ablak (ÉLES SAROK, 4px FEKETE KERET)
	windowFrame = Instance.new("Frame")
	windowFrame.Name = "RebirthWindow"
	windowFrame.Size = UDim2.fromOffset(520, 440)
	windowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	windowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	windowFrame.BackgroundColor3 = Color3.fromRGB(24, 18, 28)
	windowFrame.BorderSizePixel = 0
	windowFrame.ZIndex = 21
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

	-- FEJLÉC (Mélylila / cián sáv)
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 68)
	headerBar.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 22
	headerBar.Parent = windowFrame

	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(165, 55, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 25, 175)),
	})
	headerGradient.Rotation = 90
	headerGradient.Parent = headerBar

	local headerDiv = Instance.new("Frame")
	headerDiv.Size = UDim2.new(1, 0, 0, 4)
	headerDiv.Position = UDim2.new(0, 0, 1, -4)
	headerDiv.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	headerDiv.BorderSizePixel = 0
	headerDiv.ZIndex = 23
	headerDiv.Parent = headerBar

	local headIcon = Instance.new("TextLabel")
	headIcon.Size = UDim2.fromOffset(48, 48)
	headIcon.Position = UDim2.new(0, 14, 0.5, -24)
	headIcon.BackgroundTransparency = 1
	headIcon.BorderSizePixel = 0
	headIcon.Font = Enum.Font.FredokaOne
	headIcon.Text = "🔄"
	headIcon.TextSize = 36
	headIcon.ZIndex = 23
	headIcon.Parent = headerBar

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(0, 340, 1, 0)
	headerTitle.Position = UDim2.new(0, 68, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.BorderSizePixel = 0
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.Text = "REBIRTH (NEW HANDS)"
	headerTitle.TextSize = 30
	headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 23
	headerTitle.Parent = headerBar
	applyStroke(headerTitle, Color3.fromRGB(0, 0, 0), 3.5, Enum.ApplyStrokeMode.Contextual)

	local closeBtn3D = create3DButton(
		headerBar,
		UDim2.fromOffset(46, 46),
		UDim2.new(1, -12, 0.5, 0),
		Vector2.new(1, 0.5),
		Color3.fromRGB(225, 45, 55),
		Color3.fromRGB(140, 20, 28),
		"X"
	)
	closeBtn3D.container.ZIndex = 23
	closeBtn3D.button.ZIndex = 24
	closeBtn3D.button.TextSize = 28
	closeBtn3D.button.MouseButton1Click:Connect(function()
		RebirthController.close()
	end)

	-- Tartalom doboz
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -24, 1, -84)
	content.Position = UDim2.new(0, 12, 0, 76)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ZIndex = 22
	content.Parent = windowFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- 1. Kártya: Multiplier Haladás (Current ▶ Next)
	local multiCard = Instance.new("Frame")
	multiCard.Name = "MultiCard"
	multiCard.Size = UDim2.new(1, 0, 0, 84)
	multiCard.BackgroundColor3 = Color3.fromRGB(48, 28, 68)
	multiCard.BorderSizePixel = 0
	multiCard.LayoutOrder = 1
	multiCard.ZIndex = 22
	multiCard.Parent = content
	applyStroke(multiCard, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	rebirthCountLabel = Instance.new("TextLabel")
	rebirthCountLabel.Size = UDim2.new(1, -20, 0, 24)
	rebirthCountLabel.Position = UDim2.fromOffset(12, 6)
	rebirthCountLabel.BackgroundTransparency = 1
	rebirthCountLabel.BorderSizePixel = 0
	rebirthCountLabel.Font = Enum.Font.FredokaOne
	rebirthCountLabel.Text = "Rebirths: 0"
	rebirthCountLabel.TextSize = 18
	rebirthCountLabel.TextColor3 = Color3.fromRGB(235, 200, 255)
	rebirthCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthCountLabel.ZIndex = 23
	rebirthCountLabel.Parent = multiCard
	applyStroke(rebirthCountLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	local multiRow = Instance.new("Frame")
	multiRow.Size = UDim2.new(1, -24, 0, 36)
	multiRow.Position = UDim2.fromOffset(12, 34)
	multiRow.BackgroundTransparency = 1
	multiRow.BorderSizePixel = 0
	multiRow.ZIndex = 23
	multiRow.Parent = multiCard

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.Parent = multiRow

	local multiTitle = Instance.new("TextLabel")
	multiTitle.Size = UDim2.fromOffset(130, 32)
	multiTitle.BackgroundTransparency = 1
	multiTitle.Font = Enum.Font.FredokaOne
	multiTitle.Text = "Permanent Multi:"
	multiTitle.TextSize = 18
	multiTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	multiTitle.TextXAlignment = Enum.TextXAlignment.Left
	multiTitle.ZIndex = 23
	multiTitle.Parent = multiRow
	applyStroke(multiTitle, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	currentMultiLabel = Instance.new("TextLabel")
	currentMultiLabel.AutomaticSize = Enum.AutomaticSize.X
	currentMultiLabel.Size = UDim2.fromOffset(0, 32)
	currentMultiLabel.BackgroundTransparency = 1
	currentMultiLabel.Font = Enum.Font.FredokaOne
	currentMultiLabel.Text = "1.0x"
	currentMultiLabel.TextSize = 26
	currentMultiLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	currentMultiLabel.ZIndex = 23
	currentMultiLabel.Parent = multiRow
	applyStroke(currentMultiLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.AutomaticSize = Enum.AutomaticSize.X
	arrowLabel.Size = UDim2.fromOffset(0, 32)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.Text = "▶"
	arrowLabel.TextSize = 22
	arrowLabel.TextColor3 = Color3.fromRGB(120, 215, 255)
	arrowLabel.ZIndex = 23
	arrowLabel.Parent = multiRow
	applyStroke(arrowLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	nextMultiLabel = Instance.new("TextLabel")
	nextMultiLabel.AutomaticSize = Enum.AutomaticSize.X
	nextMultiLabel.Size = UDim2.fromOffset(0, 32)
	nextMultiLabel.BackgroundTransparency = 1
	nextMultiLabel.Font = Enum.Font.FredokaOne
	nextMultiLabel.Text = "2.5x"
	nextMultiLabel.TextSize = 26
	nextMultiLabel.TextColor3 = Color3.fromRGB(50, 255, 60)
	nextMultiLabel.ZIndex = 23
	nextMultiLabel.Parent = multiRow
	applyStroke(nextMultiLabel, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Contextual)

	-- 2. Kártya: Következő Rebirth Jutalmai & Szükséges Erő Sáv
	local reqCard = Instance.new("Frame")
	reqCard.Name = "ReqCard"
	reqCard.Size = UDim2.new(1, 0, 0, 110)
	reqCard.BackgroundColor3 = Color3.fromRGB(36, 24, 48)
	reqCard.BorderSizePixel = 0
	reqCard.LayoutOrder = 2
	reqCard.ZIndex = 22
	reqCard.Parent = content
	applyStroke(reqCard, Color3.fromRGB(0, 0, 0), 3, Enum.ApplyStrokeMode.Border)

	local reqTitle = Instance.new("TextLabel")
	reqTitle.Size = UDim2.new(1, -24, 0, 24)
	reqTitle.Position = UDim2.fromOffset(12, 6)
	reqTitle.BackgroundTransparency = 1
	reqTitle.Font = Enum.Font.FredokaOne
	reqTitle.Text = "REBIRTH REQUIREMENT"
	reqTitle.TextSize = 17
	reqTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	reqTitle.TextXAlignment = Enum.TextXAlignment.Left
	reqTitle.ZIndex = 23
	reqTitle.Parent = reqCard
	applyStroke(reqTitle, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Erő progressz sáv
	local barTrack = Instance.new("Frame")
	barTrack.Name = "BarTrack"
	barTrack.Size = UDim2.new(1, -24, 0, 28)
	barTrack.Position = UDim2.fromOffset(12, 34)
	barTrack.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
	barTrack.BorderSizePixel = 0
	barTrack.ZIndex = 23
	barTrack.Parent = reqCard
	applyStroke(barTrack, Color3.fromRGB(0, 0, 0), 2.5, Enum.ApplyStrokeMode.Border)

	powerProgressFill = Instance.new("Frame")
	powerProgressFill.Name = "Fill"
	powerProgressFill.Size = UDim2.fromScale(0.3, 1)
	powerProgressFill.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
	powerProgressFill.BorderSizePixel = 0
	powerProgressFill.ZIndex = 24
	powerProgressFill.Parent = barTrack

	powerProgressText = Instance.new("TextLabel")
	powerProgressText.Size = UDim2.fromScale(1, 1)
	powerProgressText.BackgroundTransparency = 1
	powerProgressText.Font = Enum.Font.FredokaOne
	powerProgressText.Text = "0 / 50K Power (0%)"
	powerProgressText.TextSize = 16
	powerProgressText.TextColor3 = Color3.fromRGB(255, 255, 255)
	powerProgressText.ZIndex = 25
	powerProgressText.Parent = barTrack
	applyStroke(powerProgressText, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- Jutalom skin felirat
	skinRewardLabel = Instance.new("TextLabel")
	skinRewardLabel.Size = UDim2.new(1, -24, 0, 26)
	skinRewardLabel.Position = UDim2.fromOffset(12, 72)
	skinRewardLabel.BackgroundTransparency = 1
	skinRewardLabel.Font = Enum.Font.FredokaOne
	skinRewardLabel.Text = "Skin: ✨ Golden Touch"
	skinRewardLabel.TextSize = 17
	skinRewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	skinRewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	skinRewardLabel.ZIndex = 23
	skinRewardLabel.Parent = reqCard
	applyStroke(skinRewardLabel, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- 3. Kártya: Figyelmeztetés (Mit resetel és mit tart meg)
	local warnCard = Instance.new("Frame")
	warnCard.Name = "WarnCard"
	warnCard.Size = UDim2.new(1, 0, 0, 48)
	warnCard.BackgroundColor3 = Color3.fromRGB(30, 16, 16)
	warnCard.BorderSizePixel = 0
	warnCard.LayoutOrder = 3
	warnCard.ZIndex = 22
	warnCard.Parent = content
	applyStroke(warnCard, Color3.fromRGB(180, 50, 50), 2, Enum.ApplyStrokeMode.Border)

	local warnText = Instance.new("TextLabel")
	warnText.Size = UDim2.fromScale(1, 1)
	warnText.BackgroundTransparency = 1
	warnText.Font = Enum.Font.FredokaOne
	warnText.Text = "⚠️ Resets: Power, Cash & Upgrades • Keeps: Gacha Materials & Multiplier"
	warnText.TextSize = 14
	warnText.TextColor3 = Color3.fromRGB(255, 210, 210)
	warnText.ZIndex = 23
	warnText.Parent = warnCard
	applyStroke(warnText, Color3.fromRGB(0, 0, 0), 2, Enum.ApplyStrokeMode.Contextual)

	-- 4. Akció Gomb (REBIRTH NOW!)
	local btnHolder = Instance.new("Frame")
	btnHolder.Size = UDim2.new(1, 0, 0, 56)
	btnHolder.BackgroundTransparency = 1
	btnHolder.LayoutOrder = 4
	btnHolder.ZIndex = 22
	btnHolder.Parent = content

	actionBtn = create3DButton(
		btnHolder,
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		Vector2.new(0, 0),
		Color3.fromRGB(46, 204, 113),
		Color3.fromRGB(25, 125, 52),
		"REBIRTH NOW!"
	)
	actionBtn.container.ZIndex = 23
	actionBtn.button.ZIndex = 24
	actionBtn.button.TextSize = 24

	actionBtn.button.MouseButton1Click:Connect(function()
		local remote = Net.get("DoRebirth")
		if remote then
			remote:FireServer()
		end
	end)

	refreshUI()
end

-- Inicializálás
function RebirthController.init(hud)
	local screenGui = hud and hud.gui or player:WaitForChild("PlayerGui"):WaitForChild("SqueezeHud")
	buildUI(screenGui)

	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				currentData.power = snapshot.power or currentData.power
				currentData.rebirths = snapshot.rebirths or currentData.rebirths
				currentData.rebirthMultiplier = snapshot.rebirthMultiplier or currentData.rebirthMultiplier
				currentData.nextRebirthPower = snapshot.nextRebirthPower or currentData.nextRebirthPower
				currentData.activeSkin = snapshot.activeSkin or currentData.activeSkin
				currentData.canRebirth = snapshot.canRebirth ~= nil and snapshot.canRebirth or currentData.canRebirth
				refreshUI()
			end
		end)
	end
end

return RebirthController

