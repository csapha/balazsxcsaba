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

local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local COLORS = GameConfig.Colors

local SqueezeController = {}

local session = nil -- { objectId, name, needed, progress, lastTick }
local bar, fill, titleLabel, hintLabel

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

local function buildBar(gui)
	bar = Instance.new("Frame")
	bar.Name = "SqueezeBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -90)
	bar.Size = UDim2.fromOffset(420, 74)
	bar.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	bar.BackgroundTransparency = 0.08
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(60, 66, 82)
	barStroke.Thickness = 1
	barStroke.Parent = bar

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 24)
	titleLabel.Position = UDim2.fromOffset(12, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 17
	titleLabel.TextColor3 = COLORS.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = ""
	titleLabel.Parent = bar

	hintLabel = Instance.new("TextLabel")
	hintLabel.AnchorPoint = Vector2.new(1, 0)
	hintLabel.Position = UDim2.new(1, -12, 0, 6)
	hintLabel.Size = UDim2.fromOffset(150, 24)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 15
	hintLabel.TextColor3 = COLORS.Gold
	hintLabel.TextXAlignment = Enum.TextXAlignment.Right
	hintLabel.Text = "CLICK / TAP!"
	hintLabel.Parent = bar

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(12, 38)
	track.Size = UDim2.new(1, -24, 0, 22)
	track.BackgroundColor3 = Color3.fromRGB(8, 9, 13)
	track.BorderSizePixel = 0
	track.Parent = bar

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track

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

-- kattintásonként egy kicsit tekerünk előre az animáción
local function scrubSqueezeTrack(target)
	local track = squeezeTrack
	if not track or track.Length <= 0 then
		return
	end

	local clamped = math.clamp(target, 0, 0.99) * track.Length
	local start = track.TimePosition
	local duration = GameConfig.SqueezeAnim.ScrubTime

	task.spawn(function()
		local t0 = os.clock()
		while true do
			if squeezeTrack ~= track then
				return
			end
			local t = math.clamp((os.clock() - t0) / duration, 0, 1)
			track.TimePosition = start + (clamped - start) * t
			if t >= 1 then
				break
			end
			task.wait()
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
	local standDistance = objectSize * 0.5 + 1.2
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
	else
		poseMotors = buildProceduralPose(character, objectPosition)
		if poseMotors then
			tweenPose(poseMotors, poseMotors.reach, 0.18, false)
		end
	end
end

local function exitCinematic()
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
	session.progress += 1
	tapPunch()
	proceduralPulse()

	-- kattintásonként egy kicsit zár össze (a haladás szerint)
	local cfg = GameConfig.SqueezeAnim
	local squeezeRatio = math.clamp(session.progress / session.needed, 0, 1)
	scrubSqueezeTrack(cfg.ScrubStart + (cfg.ScrubEnd - cfg.ScrubStart) * squeezeRatio)

	if fill then
		local ratio = math.clamp(session.progress / session.needed, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = ratio > 0.66 and COLORS.Good or COLORS.Accent
	end

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
		session = {
			objectId = payload.objectId,
			name = payload.name,
			needed = math.max(payload.needed, 1),
			progress = 0,
			lastTick = 0,
		}
		titleLabel.Text = payload.name
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = COLORS.Accent
		setVisible(true)
		enterCinematic(payload)
	elseif payload.state == "pop" then
		local object = Objects.byId[payload.objectId]
		local color = object and Color3.fromHex(object.color) or COLORS.Good
		if payload.position then
			EffectsController.burst(payload.position, color, 34)
			EffectsController.floatingText(payload.position, "+" .. Format.money(payload.reward), COLORS.Gold)
		end
		popPunch()
		proceduralBurst()

		-- pop után az animáció hátralévő része gyorsan lefut
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
		scrubSqueezeTrack(0)
		exitCinematic()
		if bar and bar.Visible then
			hintLabel.Text = "FAILED!"
			hintLabel.TextColor3 = COLORS.Bad
			task.delay(0.6, function()
				hintLabel.Text = "CLICK / TAP!"
				hintLabel.TextColor3 = COLORS.Gold
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
