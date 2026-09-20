-- Edzés: a "Train" tool egy KI/BE kapcsoló.
-- Bekapcsolva a karakter automatikusan, szépen lassan guggol (loopoló animáció),
-- és minden ciklusban Erőt kap. NEM kell kattintgatni.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Net = require(Shared.Net)

local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local TrainingController = {}

local training = false
local trainSession = 0
local squatTrack = nil
local squatTrackAnimator = nil
local squatAnimation = nil
local squatAnimationId = nil
local tapGain = 0
local currentMoveId = UpgradesConfig.defaultMove
local currentWalkSpeed = UpgradesConfig.speedById[UpgradesConfig.defaultSpeed].speed

local function getAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- Az edzés-animáció mindig a felszerelt mozdulatból jön (Squat -> Situp -> ...).
local function moveAnimationId()
	local move = UpgradesConfig.movesById[currentMoveId]
	return move and move.animationId or GameConfig.SquatAnimationId
end

local function getSquatAnimation()
	local animationId = moveAnimationId()
	if squatAnimation and squatAnimationId ~= animationId then
		squatAnimation = nil
		squatTrack = nil
		squatTrackAnimator = nil
	end
	if not squatAnimation and animationId ~= "" then
		squatAnimation = Instance.new("Animation")
		squatAnimation.AnimationId = animationId
		squatAnimationId = animationId
	end
	return squatAnimation
end

local function loadSquatTrack(character)
	local animator = getAnimator(character)
	local animation = getSquatAnimation()
	if not animator or not animation then
		return nil
	end

	if squatTrack and squatTrackAnimator == animator then
		return squatTrack
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	squatTrack = track
	squatTrackAnimator = animator
	return track
end

local function warmSquatAnimation(character)
	local animation = getSquatAnimation()
	if not animation then
		return
	end

	pcall(function()
		ContentProvider:PreloadAsync({ animation })
	end)

	if character ~= player.Character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	if not animator or character ~= player.Character then
		return
	end

	loadSquatTrack(character)
end

local function startSquatAnimation(character)
	if moveAnimationId() == "" then
		return false
	end

	local track = loadSquatTrack(character)
	if not track then
		return false
	end

	if not track.IsPlaying then
		track:Play(0.15)
	end
	return true
end

local function stopSquatAnimation()
	if squatTrack then
		squatTrack:Stop(0.25)
	end
end

-- ha nincs animáció: por + kamera-dip
local function fallbackPulse(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		EffectsController.dust(root.Position)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	task.spawn(function()
		local down = TweenService:Create(humanoid,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CameraOffset = Vector3.new(0, -0.55, 0) })
		down:Play()
		down.Completed:Wait()
		local up = TweenService:Create(humanoid,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CameraOffset = Vector3.new(0, 0, 0) })
		up:Play()
	end)
end

local function trainLoop(character, session)
	while training and trainSession == session and character.Parent do
		local remote = Net.get("TrainTap")
		if remote then
			remote:FireServer()
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if root and tapGain > 0 then
			EffectsController.floatingText(root.Position,
				"+" .. tostring(math.floor(tapGain * 10) / 10),
				Color3.fromRGB(255, 212, 71))
		end

		task.wait(GameConfig.TrainCycle)
	end
end

local function setMovement(character, enabled)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if enabled then
		humanoid.WalkSpeed = currentWalkSpeed
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function setTraining(character, value)
	if training == value then
		return
	end
	training = value
	trainSession += 1

	if value then
		setMovement(character, false) -- edzés közben nem lehet mozogni
		if not startSquatAnimation(character) then
			fallbackPulse(character)
		end
		task.spawn(trainLoop, character, trainSession)
	else
		setMovement(character, true)
		stopSquatAnimation()
	end
end

local function hookTool(tool)
	if tool.Name ~= "Train" or tool:GetAttribute("TrainHooked") then
		return
	end
	tool:SetAttribute("TrainHooked", true)

	-- elővételre (1-es gomb / hotbar) automatikusan indul, nem kell kattintani
	tool.Equipped:Connect(function()
		local character = player.Character
		if character then
			setTraining(character, true)
		end
	end)

	tool.Unequipped:Connect(function()
		setTraining(player.Character, false)
	end)
end

local function hookContainer(container)
	container.ChildAdded:Connect(function(child)
		task.wait(0.1)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
end

function TrainingController.init()
	local backpack = player:WaitForChild("Backpack")
	hookContainer(backpack)

	player.CharacterAdded:Connect(function(character)
		squatTrack = nil
		squatTrackAnimator = nil
		training = false
		hookContainer(character)
		task.spawn(warmSquatAnimation, character)
	end)

	if player.Character then
		hookContainer(player.Character)
		task.spawn(warmSquatAnimation, player.Character)
	end

	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if not snapshot then
				return
			end
			tapGain = snapshot.tapGain or 0
			currentWalkSpeed = tonumber(snapshot.walkSpeed) or currentWalkSpeed

			-- Ha új edzés-mozdulatot vettél, azonnal cseréljük az animációt.
			if type(snapshot.move) == "string" and snapshot.move ~= currentMoveId then
				currentMoveId = snapshot.move
				if training then
					local character = player.Character
					stopSquatAnimation()
					squatAnimation = nil
					squatTrack = nil
					squatTrackAnimator = nil
					if character and not startSquatAnimation(character) then
						fallbackPulse(character)
					end
				end
			end
		end)
	end
end

return TrainingController
