-- Custom ProximityPrompt UI a hotbar stílusában: sötét panel, fekete külső
-- keret, bal/jobb oldalon izzó belső border (középen eltűnik), fehér gradiens
-- szöveg.
--
-- A prompt a tárgyra van illesztve (BillboardGui), megjelenéskor pop-in
-- animáció fut, eltávolodáskor finoman kiúszik.
--
-- A szerveren minden prompt Style = Custom, ezért a default UI nem jelenik
-- meg: ezt a modult használjuk helyette (ProximityPromptService eseményeire).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local player = Players.LocalPlayer

local PromptController = {}

local COLOR_PANEL_TOP = Color3.fromRGB(38, 41, 50)
local COLOR_PANEL_BOTTOM = Color3.fromRGB(18, 20, 26)
local COLOR_TITLE = Color3.fromRGB(184, 188, 200)
local MONTSERRAT_BOLD = Font.new(
	"rbxasset://fonts/families/Montserrat.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

local billboard, scaleFrame, scale, panel, badgeLabel, keyScale, titleLabel, actionLabel, actionOutline
local fadeEntries = {}
local alphaTweens = {}
local currentPrompt = nil
local isShown = false
local scaleTween, fadeToken, keyPressTween = nil, nil, nil
local infoBillboards = {}

local function setKeyPressed(pressed)
	if not keyScale then
		return
	end
	if keyPressTween then
		keyPressTween:Cancel()
	end

	local tweenInfo
	if pressed then
		tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	else
		tweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end
	keyPressTween = TweenService:Create(keyScale, tweenInfo, {
		Scale = pressed and 0.9 or 1,
	})
	keyPressTween:Play()
end

local function setInfoShown(entry, shown)
	if entry.shown == shown then
		return
	end
	entry.shown = shown

	if entry.scaleTween then
		entry.scaleTween:Cancel()
	end
	if entry.fadeTween then
		entry.fadeTween:Cancel()
	end

	if shown then
		entry.billboard.Enabled = true
		entry.scale.Scale = 0.7
		entry.group.GroupTransparency = 1
		entry.scaleTween = TweenService:Create(
			entry.scale,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		entry.fadeTween = TweenService:Create(
			entry.group,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0 }
		)
		entry.scaleTween:Play()
		entry.fadeTween:Play()
	else
		entry.scaleTween = TweenService:Create(
			entry.scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0.85 }
		)
		entry.fadeTween = TweenService:Create(
			entry.group,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 1 }
		)
		entry.scaleTween:Play()
		entry.fadeTween:Play()
		local infoBillboard = entry.billboard
		task.delay(0.2, function()
			if infoBillboard.Parent and not entry.shown then
				infoBillboard.Enabled = false
			end
		end)
	end
end

local function registerInfoBillboard(candidate)
	if not candidate:IsA("BillboardGui")
		or candidate:GetAttribute("AnimatedObjectInfo") ~= true
		or infoBillboards[candidate] then
		return
	end

	local group = candidate:FindFirstChild("ScaleFrame")
	local infoScale = group and group:FindFirstChild("PopScale")
	if not group or not group:IsA("CanvasGroup") or not infoScale or not infoScale:IsA("UIScale") then
		return
	end

	candidate.Enabled = false
	group.GroupTransparency = 1
	local entry = {
		billboard = candidate,
		group = group,
		scale = infoScale,
		shown = false,
	}
	infoBillboards[candidate] = entry
end

local function registerInfoFromDescendant(candidate)
	if candidate:IsA("BillboardGui") then
		registerInfoBillboard(candidate)
		return
	end
	local ancestor = candidate:FindFirstAncestorWhichIsA("BillboardGui")
	if ancestor then
		registerInfoBillboard(ancestor)
	end
end

local function billboardWorldPosition(infoGui)
	local adornee = infoGui.Adornee or infoGui.Parent
	if adornee and adornee:IsA("Attachment") then
		return adornee.WorldPosition
	elseif adornee and adornee:IsA("BasePart") then
		return adornee.Position
	end
	return nil
end

-- fehér gradiens szöveg fekete külső outline-nal (két label egymáson)
local function makeStyledText(parent, textSize)
	local outline = Instance.new("TextLabel")
	outline.BackgroundTransparency = 1
	outline.FontFace = MONTSERRAT_BOLD
	outline.TextSize = textSize
	outline.TextColor3 = Color3.fromRGB(0, 0, 0)
	outline.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	outline.TextStrokeTransparency = 0
	outline.Text = ""
	outline.Parent = parent
	Ui.applyDisplay(outline)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = MONTSERRAT_BOLD
	label.TextSize = textSize
	label.Text = ""
	label.Parent = parent
	Ui.applyDisplay(label)

	local gradient = Ui.applyTextGradient(label)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	gradient.Rotation = 90

	return outline, label
end

-- minden elem eredeti átlátszóságát elmentjük, hogy csoportosan tudjunk fade-elni
local function collectFadeEntries(root)
	fadeEntries = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(fadeEntries, {
				obj = descendant,
				props = {
					TextTransparency = descendant.TextTransparency,
					TextStrokeTransparency = descendant.TextStrokeTransparency,
				},
			})
		elseif descendant:IsA("Frame") then
			table.insert(fadeEntries, {
				obj = descendant,
				props = { BackgroundTransparency = descendant.BackgroundTransparency },
			})
		elseif descendant:IsA("UIStroke") then
			table.insert(fadeEntries, {
				obj = descendant,
				props = { Transparency = descendant.Transparency },
			})
		end
	end
end

-- alpha: 0 = teljesen látható (alap), 1 = teljesen eltűnt
local function tweenAlpha(target, duration, easingStyle)
	for _, tween in ipairs(alphaTweens) do
		tween:Cancel()
	end
	alphaTweens = {}

	for _, entry in ipairs(fadeEntries) do
		local goals = {}
		local changed = false
		for prop, base in pairs(entry.props) do
			local value = base + (1 - base) * target
			if math.abs(entry.obj[prop] - value) > 0.001 then
				goals[prop] = value
				changed = true
			end
		end
		if changed then
			local tween = TweenService:Create(
				entry.obj,
				TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out),
				goals
			)
			tween:Play()
			table.insert(alphaTweens, tween)
		end
	end
end

local function setAlphaInstant(target)
	for _, entry in ipairs(fadeEntries) do
		for prop, base in pairs(entry.props) do
			entry.obj[prop] = base + (1 - base) * target
		end
	end
end

local function build()
	billboard = Instance.new("BillboardGui")
	billboard.Name = "SqueezePrompt"
	billboard.Size = UDim2.fromOffset(222, 62)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 60
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.Enabled = false

	scaleFrame = Instance.new("Frame")
	scaleFrame.Size = UDim2.fromScale(1, 1)
	scaleFrame.BackgroundTransparency = 1
	scaleFrame.Parent = billboard

	scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = scaleFrame

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(210, 50)
	panel.BackgroundColor3 = COLOR_PANEL_TOP
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Parent = scaleFrame

	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new(COLOR_PANEL_TOP, COLOR_PANEL_BOTTOM)
	panelGradient.Rotation = 90
	panelGradient.Parent = panel

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromRGB(0, 0, 0)
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.08
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = panel

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 255, 255)
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.82
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Parent = panel

	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(25, 25)
	badge.Size = UDim2.fromOffset(38, 38)
	badge.BackgroundColor3 = Color3.fromRGB(43, 47, 58)
	badge.BorderSizePixel = 0
	badge.Parent = panel

	local badgeGradient = Instance.new("UIGradient")
	badgeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 63, 76)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 31, 39)),
	})
	badgeGradient.Rotation = 90
	badgeGradient.Parent = badge

	badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.FontFace = MONTSERRAT_BOLD
	badgeLabel.TextSize = 21
	badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	badgeLabel.TextStrokeTransparency = 0.35
	badgeLabel.Text = "E"
	badgeLabel.Parent = badge
	Ui.applyDisplay(badgeLabel)

	keyScale = Instance.new("UIScale")
	keyScale.Scale = 1
	keyScale.Parent = badge

	titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(54, 5)
	titleLabel.Size = UDim2.new(1, -62, 0, 16)
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = MONTSERRAT_BOLD
	titleLabel.TextSize = 11
	titleLabel.TextColor3 = COLOR_TITLE
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0.62
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Text = ""
	titleLabel.Parent = panel
	Ui.applyDisplay(titleLabel)

	actionOutline, actionLabel = makeStyledText(panel, 17)
	for _, label in ipairs({ actionOutline, actionLabel }) do
		label.Position = UDim2.fromOffset(54, 20)
		label.Size = UDim2.new(1, -62, 0, 24)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = panel
	button.MouseButton1Click:Connect(function()
		local prompt = currentPrompt
		if not prompt then
			return
		end
		prompt:InputHoldBegin()
		task.defer(function()
			prompt:InputHoldEnd()
		end)
	end)

	collectFadeEntries(billboard)
end

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local function popIn()
	if scaleTween then
		scaleTween:Cancel()
	end
	fadeToken = nil
	isShown = true

	billboard.Enabled = true
	scale.Scale = 0.7
	setAlphaInstant(1)

	scaleTween = TweenService:Create(
		scale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	scaleTween:Play()
	tweenAlpha(0, 0.16, Enum.EasingStyle.Quad)
end

local function popOut()
	if not billboard.Enabled then
		return
	end
	if scaleTween then
		scaleTween:Cancel()
	end
	isShown = false

	scaleTween = TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 0.85 }
	)
	scaleTween:Play()
	tweenAlpha(1, 0.18, Enum.EasingStyle.Quad)

	local token = {}
	fadeToken = token
	task.delay(0.2, function()
		if fadeToken == token then
			billboard.Enabled = false
		end
	end)
end

local function applyPrompt(prompt, inputType)
	titleLabel.Text = prompt.ObjectText
	actionOutline.Text = prompt.ActionText
	actionLabel.Text = prompt.ActionText
	local key = keyText(prompt, inputType)
	badgeLabel.Text = key
	badgeLabel.TextSize = #key > 1 and 11 or 21
end

function PromptController.init()
	build()

	for _, descendant in ipairs(workspace:GetDescendants()) do
		registerInfoBillboard(descendant)
	end
	workspace.DescendantAdded:Connect(registerInfoFromDescendant)

	local infoUpdateElapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		infoUpdateElapsed += dt
		if infoUpdateElapsed < 0.1 then
			return
		end
		infoUpdateElapsed = 0

		local currentCamera = workspace.CurrentCamera
		if not currentCamera then
			return
		end
		for infoGui, entry in pairs(infoBillboards) do
			local worldPosition = billboardWorldPosition(infoGui)
			if not infoGui.Parent or not worldPosition then
				infoBillboards[infoGui] = nil
			else
				local distance = (currentCamera.CFrame.Position - worldPosition).Magnitude
				local displayDistance = infoGui:GetAttribute("DisplayDistance") or 55
				setInfoShown(entry, distance <= displayDistance)
			end
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if not prompt.Parent then
			return
		end
		local same = currentPrompt == prompt and isShown
		currentPrompt = prompt
		applyPrompt(prompt, inputType)
		billboard.Parent = prompt.Parent
		if not same then
			popIn()
		end
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt ~= currentPrompt then
			return
		end
		currentPrompt = nil
		setKeyPressed(false)
		popOut()
	end)

	UserInputService.InputBegan:Connect(function(input)
		local prompt = currentPrompt
		if prompt and input.KeyCode == prompt.KeyboardKeyCode then
			setKeyPressed(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local prompt = currentPrompt
		if prompt and input.KeyCode == prompt.KeyboardKeyCode then
			setKeyPressed(false)
		end
	end)

	player.CharacterAdded:Connect(function()
		currentPrompt = nil
		setKeyPressed(false)
		popOut()
	end)
end

return PromptController
