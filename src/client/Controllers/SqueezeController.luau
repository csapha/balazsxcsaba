-- Szorítás minigame: cinematic kamera + bar + rapid kattintás.
-- A kliens csak jelzést küld (SqueezeTick), a szerver dönt a sikerességről.
--
-- Jelenet: a karakter az asztal elé áll és felé fordul, a kamera felülről
-- mutatja, a karakter pedig procedurálisan szorítja az objektumot
-- (R6: váll C0 forgatás előre + befelé, a kéz a tárgy oldalára kerül).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)

local EffectsController = require(script.Parent.EffectsController)
local TrainingController = require(script.Parent.TrainingController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local COLORS = GameConfig.Colors

local SqueezeController = {}

local session = nil -- { objectId, name, needed, progress, lastTick }
local bar, fill, fillGradient, titleLabel, titleOutline, hintLabel

-- cinematic állapot
local cinematicActive = false
local savedCameraType = nil
local savedFOV = nil
local savedWalkSpeed = nil
local cineBaseCFrame = nil
local squeezeTrack = nil

-- procedurális póz
local poseMotors = nil
local pulsing = false

local function setVisible(visible)
	if bar then
		bar.Visible = visible
	end
end

local function setFillColor(color)
	fill.BackgroundColor3 = color
	fillGradient.Color = ColorSequence.new(
		color:Lerp(Color3.new(1, 1, 1), 0.25),
		color:Lerp(Color3.new(0, 0, 0), 0.25)
	)
end

local function buildBar(gui)
	bar = Instance.new("Frame")
	bar.Name = "SqueezeBar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 205, 0.5, 0)
	bar.Size = UDim2.fromOffset(126, 340)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	-- Bal oldali, függőleges panel; a menügombok mellett marad, nem takarja a játékot.
	local backgroundGradient = Ui.applyFadeBackground(bar, 0.12)
	backgroundGradient.Rotation = 90

	-- cím: fehér gradiens + fekete outline (mint a prompt/hotbar szövegek)
	titleOutline = Instance.new("TextLabel")
	titleOutline.Size = UDim2.new(1, -12, 0, 42)
	titleOutline.Position = UDim2.fromOffset(6, 8)
	titleOutline.BackgroundTransparency = 1
	titleOutline.Font = Enum.Font.GothamBold
	titleOutline.TextSize = 16
	titleOutline.TextColor3 = Color3.fromRGB(0, 0, 0)
	titleOutline.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleOutline.TextStrokeTransparency = 0
	titleOutline.TextXAlignment = Enum.TextXAlignment.Center
	titleOutline.TextWrapped = true
	titleOutline.Text = ""
	titleOutline.Parent = bar
	Ui.applyDisplay(titleOutline)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 0, 42)
	titleLabel.Position = UDim2.fromOffset(6, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextWrapped = true
	titleLabel.Text = ""
	titleLabel.Parent = bar
	Ui.applyDisplay(titleLabel)
	local titleGradient = Ui.applyTextGradient(titleLabel)
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	titleGradient.Rotation = 90

	hintLabel = Instance.new("TextLabel")
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -9)
	hintLabel.Size = UDim2.new(1, -12, 0, 34)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 14
	hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hintLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hintLabel.TextStrokeTransparency = 0
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.TextWrapped = true
	hintLabel.Text = "CLICK / TAP!"
	hintLabel.Parent = bar
	Ui.applyDisplay(hintLabel)
	local hintGradient = Ui.applyTextGradient(hintLabel)
	hintGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	hintGradient.Rotation = 90

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 58)
	track.Size = UDim2.fromOffset(24, 236)
	track.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	track.BackgroundTransparency = 0.45
	track.BorderSizePixel = 0
	track.Parent = bar

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BorderSizePixel = 0
	fill.Parent = track

	fillGradient = Instance.new("UIGradient")
	fillGradient.Rotation = 0
	fillGradient.Parent = fill
	setFillColor(COLORS.Accent)

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = bar
	button.MouseButton1Click:Connect(function()
		SqueezeController.tap()
	end)
end

-- ---------- publikált animáció (ha van ID) ----------

-- betöltjük az animációt és megfagyasztjuk a 0. frame-en
local function loadSqueezeTrack(character)
	if GameConfig.SqueezeAnimationId == "" then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = GameConfig.SqueezeAnimationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	squeezeTrack = track
	track:Play(0.12)

	task.spawn(function()
		local waited = 0
		while track.Length <= 0 and waited < 3 do
			task.wait(0.05)
			waited += 0.05
		end
		if squeezeTrack ~= track then
			return
		end
		track:AdjustSpeed(0)
		track.TimePosition = 0
	end)
end

-- kattintásonként egy kicsit tekerünk előre: folytonos, simított követés
local scrubTarget = 0 -- 0..1 közötti cél-pozíció az animációban
local scrubActive = false

local function startScrubLoop()
	task.spawn(function()
		while scrubActive and cinematicActive do
			local track = squeezeTrack
			if track and track.Length > 0 then
				local target = scrubTarget * track.Length
				local current = track.TimePosition
				local dt = task.wait()
				local alpha = math.clamp(dt * GameConfig.SqueezeAnim.ScrubSpeed, 0, 1)
				track.TimePosition = current + (target - current) * alpha
			else
				task.wait()
			end
		end
	end)
end

-- ---------- procedurális R6 szorítás póz ----------

local function findMotor(character, name)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function buildProceduralPose(character, objectPosition)
	local rootJoint = findMotor(character, "RootJoint")
	local rightShoulder = findMotor(character, "Right Shoulder")
	local leftShoulder = findMotor(character, "Left Shoulder")
	local neck = findMotor(character, "Neck")
	if not (rootJoint and rightShoulder and leftShoulder) then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local cfg = GameConfig.SqueezeAnim

	-- a tárgy magasságához igazítjuk az emelést
	local shoulderY = (root and root.Position.Y or 0) + 0.5
	local deltaY = math.clamp(objectPosition.Y - shoulderY, -1.3, 1.3)
	local lift = math.clamp(
		math.deg(math.asin(deltaY / cfg.ArmReach)),
		-cfg.ArmLiftMax,
		cfg.ArmLiftMax
	)

	local pose = {
		rootJoint = rootJoint,
		rightShoulder = rightShoulder,
		leftShoulder = leftShoulder,
		neck = neck,
		base = {
			root = rootJoint.C0,
			right = rightShoulder.C0,
			left = leftShoulder.C0,
			neck = neck and neck.C0 or nil,
		},
	}

	-- yaw: karok befelé (jobb +, bal -), pitch: előre + emelés
	local function arms(yaw, extraPitch, lean)
		local pitch = 90 + lift + extraPitch
		return {
			root = pose.base.root * CFrame.Angles(math.rad(lean), 0, 0),
			right = pose.base.right
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.Angles(math.rad(pitch), 0, 0),
			left = pose.base.left
				* CFrame.Angles(0, math.rad(-yaw), 0)
				* CFrame.Angles(math.rad(pitch), 0, 0),
			neck = pose.base.neck
				and pose.base.neck * CFrame.Angles(math.rad(math.max(lean * 0.5, 0)), 0, 0)
				or nil,
		}
	end

	pose.reach = arms(cfg.ArmYaw, 0, cfg.Lean)
	pose.squeeze = arms(cfg.SqueezeYaw, cfg.SqueezePitch, cfg.Lean + 5)

	-- pop: a karok szétnyílnak oldalra, mellszinten (abszolút póz)
	pose.burst = {
		root = pose.base.root * CFrame.Angles(math.rad(cfg.BurstLean), 0, 0),
		right = pose.base.right
			* CFrame.Angles(0, math.rad(cfg.BurstYaw), 0)
			* CFrame.Angles(math.rad(cfg.BurstPitch), 0, 0),
		left = pose.base.left
			* CFrame.Angles(0, math.rad(-cfg.BurstYaw), 0)
			* CFrame.Angles(math.rad(cfg.BurstPitch), 0, 0),
		neck = pose.base.neck,
	}

	return pose
end

local function tweenPose(pose, target, time, waitFor)
	if not pose then
		return
	end

	local tweens = {}
	local function tw(motor, goal)
		if motor and goal then
			local tween = TweenService:Create(
				motor,
				TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = goal }
			)
			tween:Play()
			table.insert(tweens, tween)
		end
	end

	tw(pose.rootJoint, target.root)
	tw(pose.rightShoulder, target.right)
	tw(pose.leftShoulder, target.left)
	tw(pose.neck, target.neck)

	if waitFor then
		for _, tween in ipairs(tweens) do
			tween.Completed:Wait()
		end
	end
end

local function proceduralPulse()
	if not poseMotors or pulsing then
		return
	end
	pulsing = true

	task.spawn(function()
		tweenPose(poseMotors, poseMotors.squeeze, GameConfig.SqueezeAnim.PulseIn, true)
		tweenPose(poseMotors, poseMotors.reach, GameConfig.SqueezeAnim.PulseOut, true)
		pulsing = false
	end)
end

local function proceduralBurst()
	if not poseMotors then
		return
	end
	task.spawn(function()
		tweenPose(poseMotors, poseMotors.burst, 0.08, true)
		tweenPose(poseMotors, poseMotors.base, 0.22, true)
	end)
end

-- ---------- cinematic ----------

local function enterCinematic(payload)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local objectPosition = payload.position
	if not root or not humanoid or cinematicActive or not objectPosition then
		return
	end

	local object = Objects.byId[payload.objectId]
	local objectSize = object and object.size or 3

	cinematicActive = true
	savedCameraType = camera.CameraType
	savedFOV = camera.FieldOfView

	-- a karakter az asztal elé áll (a tárgy méretéhez igazítva) és felé fordul
	local flat = Vector3.new(objectPosition.X - root.Position.X, 0, objectPosition.Z - root.Position.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, 1)
	local standDistance = objectSize * 0.5 + GameConfig.Cinematic.StandDistance
	local stand = objectPosition - dir * standDistance
	root.CFrame = CFrame.lookAt(
		Vector3.new(stand.X, root.Position.Y, stand.Z),
		Vector3.new(objectPosition.X, root.Position.Y, objectPosition.Z)
	)

	-- mozgás tiltása a jelenet alatt
	savedWalkSpeed = (humanoid.WalkSpeed > 0) and humanoid.WalkSpeed or (savedWalkSpeed or 16)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- kamera felülről, a karakter és az asztal közepére nézve
	local mid = (root.Position + objectPosition) * 0.5
	local angle = math.rad(GameConfig.Cinematic.SideAngle)
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local camOffset = dir * (GameConfig.Cinematic.CameraDistance * math.cos(angle))
		+ side * (GameConfig.Cinematic.CameraDistance * math.sin(angle))
	local camPos = mid + camOffset + Vector3.new(0, GameConfig.Cinematic.CameraHeight, 0)
	cineBaseCFrame = CFrame.lookAt(camPos,
		mid + Vector3.new(0, GameConfig.Cinematic.LookHeight, 0))

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cineBaseCFrame
	camera.FieldOfView = 70
	TweenService:Create(camera, TweenInfo.new(0.35), { FieldOfView = GameConfig.Cinematic.FOV }):Play()

	-- animáció: publikált, vagy procedurális R6 póz
	if GameConfig.SqueezeAnimationId ~= "" then
		loadSqueezeTrack(character)
		scrubTarget = GameConfig.SqueezeAnim.ScrubStart
		scrubActive = true
		startScrubLoop()
	else
		poseMotors = buildProceduralPose(character, objectPosition)
		if poseMotors then
			tweenPose(poseMotors, poseMotors.reach, 0.18, false)
		end
	end
end

local function exitCinematic()
	TrainingController.setBlocked(false)
	if not cinematicActive then
		return
	end
	cinematicActive = false

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed or 16
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end

	if squeezeTrack then
		squeezeTrack:Stop(0.15)
		squeezeTrack = nil
	end

	if poseMotors then
		tweenPose(poseMotors, poseMotors.base, 0.15, false)
		poseMotors = nil
		pulsing = false
	end

	camera.CameraType = savedCameraType or Enum.CameraType.Custom
	camera.FieldOfView = savedFOV or 70
end

local function tapPunch()
	if not cinematicActive then
		return
	end
	camera.FieldOfView = GameConfig.Cinematic.TapFOV
	TweenService:Create(camera, TweenInfo.new(0.16), { FieldOfView = GameConfig.Cinematic.FOV }):Play()
end

local function popPunch()
	if not cinematicActive then
		return
	end

	TweenService:Create(camera, TweenInfo.new(0.08), { FieldOfView = 44 }):Play()

	task.spawn(function()
		for _ = 1, 8 do
			if cineBaseCFrame and camera.CameraType == Enum.CameraType.Scriptable then
				camera.CFrame = cineBaseCFrame * CFrame.Angles(
					math.rad(math.random(-18, 18) / 10),
					math.rad(math.random(-18, 18) / 10),
					0
				)
			end
			task.wait(0.03)
		end
		if cineBaseCFrame and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CFrame = cineBaseCFrame
		end
		if savedFOV then
			TweenService:Create(camera, TweenInfo.new(0.4), { FieldOfView = savedFOV }):Play()
		end
	end)
end

-- ---------- minigame ----------

function SqueezeController.tap()
	if not session then
		return
	end

	local now = os.clock()
	if now - session.lastTick < GameConfig.MinTapInterval then
		return
	end
	session.lastTick = now

	local wasFull = session.progress >= session.needed
	session.progress = math.min(session.progress + 1, session.needed)

	if not wasFull then
		tapPunch()
		proceduralPulse()

		-- Minden kattintás ugyanakkora, jól látható lépéssel zárja a kezeket.
		-- Nagyobb erőnél a szerver kisebb `needed` értéket küld, ezért ugyanazt
		-- a teljes kézzárást kevesebb kattintással éri el a játékos.
		local cfg = GameConfig.SqueezeAnim
		local squeezeRatio = math.clamp(session.progress / session.needed, 0, 1)
		scrubTarget = cfg.ScrubStart + (cfg.ScrubEnd - cfg.ScrubStart) * squeezeRatio

		if fill then
			fill.Size = UDim2.fromScale(1, squeezeRatio)
			setFillColor(squeezeRatio > 0.66 and COLORS.Good or COLORS.Accent)
		end
	end

	-- A tele csík után is tovább küldjük a tappeket: a szerver progressze
	-- lassabban gyűlik (rate limit + fail decay), és a POP csak ott dől el.
	local remote = Net.get("SqueezeTick")
	if remote then
		remote:FireServer()
	end
end

local function onState(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.state == "start" then
		TrainingController.setBlocked(true)
		local newSession = {
			objectId = payload.objectId,
			name = payload.name,
			needed = math.max(payload.needed, 1),
			progress = 0,
			lastTick = 0,
		}
		session = newSession
		titleLabel.Text = payload.name
		titleOutline.Text = payload.name
		fill.Size = UDim2.fromScale(1, 0)
		setFillColor(COLORS.Accent)
		setVisible(true)
		enterCinematic(payload)

		-- Vészfék: ha a csík megtelt és 3 mp-ig sem jön pop/fail, lépjünk ki,
		-- ne ragadjon bent a játékos a cinematicben.
		task.spawn(function()
			while session == newSession and newSession.progress < newSession.needed do
				task.wait(0.1)
			end
			if session ~= newSession then
				return
			end

			local fullAt = os.clock()
			while session == newSession and os.clock() - fullAt < 3 do
				task.wait(0.1)
			end
			if session == newSession then
				session = nil
				scrubTarget = 0
				exitCinematic()
				setVisible(false)
			end
		end)
	elseif payload.state == "pop" then
		local object = Objects.byId[payload.objectId]
		local color = object and Color3.fromHex(object.color) or COLORS.Good
		if payload.position then
			EffectsController.burst(payload.position, color, 34)
			if object then
				EffectsController.shatter(payload.position, object)
			end
			EffectsController.floatingText(payload.position, "+" .. Format.money(payload.reward), COLORS.Gold)
		end
		popPunch()
		proceduralBurst()

		-- pop után az animáció hátralévő része gyorsan lefut
		scrubActive = false
		if squeezeTrack then
			squeezeTrack:AdjustSpeed(1.6)
		end

		session = nil
		task.delay(0.45, function()
			exitCinematic()
			setVisible(false)
		end)
	elseif payload.state == "fail" then
		session = nil
		scrubTarget = 0
		exitCinematic()
		if bar and bar.Visible then
			hintLabel.Text = "FAILED!"
			hintLabel.TextColor3 = COLORS.Bad
			task.delay(0.6, function()
				hintLabel.Text = "CLICK / TAP!"
				hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end)
		end
		task.delay(0.35, function()
			setVisible(false)
		end)
	end
end

function SqueezeController.init(hud)
	buildBar(hud.gui)

	local remote = Net.get("SqueezeState")
	if remote then
		remote.OnClientEvent:Connect(onState)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			SqueezeController.tap()
		end
	end)

	player.CharacterAdded:Connect(function()
		exitCinematic()
		session = nil
		setVisible(false)
	end)
end

return SqueezeController
