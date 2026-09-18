-- Edzés: a "Train" tool egy KI/BE kapcsoló.
-- Bekapcsolva a karakter automatikusan, szépen lassan guggol (loopoló animáció),
-- és minden ciklusban Erőt kap. NEM kell kattintgatni.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Net = require(Shared.Net)

local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local TrainingController = {}

local training = false
local squatTrack = nil
local tapGain = 0

local function getAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function startSquatAnimation(character)
	if GameConfig.SquatAnimationId == "" then
		return false
	end

	local animator = getAnimator(character)
	if not animator then
		return false
	end

	if not squatTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = GameConfig.SquatAnimationId
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			return false
		end
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		squatTrack = track
	end

	if not squatTrack.IsPlaying then
		squatTrack:Play(0.15)
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

local function trainLoop(character)
	while training and character.Parent do
		local remote = Net.get("TrainTap")
		if remote then
			remote:FireServer()
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if root and tapGain > 0 then
			EffectsController.floatingText(root.Position,
				"+" .. tostring(math.floor(tapGain * 10) / 10),
				Color3.fromRGB(116, 210, 250))
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
		humanoid.WalkSpeed = 16
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

	if value then
		setMovement(character, false) -- edzés közben nem lehet mozogni
		if not startSquatAnimation(character) then
			fallbackPulse(character)
		end
		task.spawn(trainLoop, character)
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
		training = false
		hookContainer(character)
	end)

	if player.Character then
		hookContainer(player.Character)
	end

	local remote = Net.get("DataChanged")
	if remote then
		remote.OnClientEvent:Connect(function(snapshot)
			if snapshot then
				tapGain = snapshot.tapGain or 0
			end
		end)
	end
end

return TrainingController
