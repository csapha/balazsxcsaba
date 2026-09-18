-- Edzés: a "Train" tool a hotbarban.
-- R6 rig: a guggolás PROCEDURÁLIS (RootJoint + Right/Left Hip C0 tween),
-- mert R6-nál a Motor6D.C0 írható. Ha később publikált animációt akarunk,
-- a Game.SquatAnimationId-be kell beírni az ID-t (akkor azt játssza).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Net = require(Shared.Net)

local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local TrainingController = {}

local lastSquat = 0
local tapGain = 0
local squatTrack = nil
local lastSquatRefresh = 0

-- ---------- publikált animáció (ha be van állítva) ----------

local function playAnimationSquat(character)
	if GameConfig.SquatAnimationId == "" then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
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
		squatTrack:Play(0.1)
	end
	lastSquatRefresh = os.clock()
	return true
end

-- ---------- fallback (ha nincs használható animáció) ----------

local function fallbackFeedback(character)
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
			TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CameraOffset = Vector3.new(0, -0.55, 0) })
		down:Play()
		down.Completed:Wait()
		local up = TweenService:Create(humanoid,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CameraOffset = Vector3.new(0, 0, 0) })
		up:Play()
	end)
end

local function playSquat(character)
	local now = os.clock()
	if now - lastSquat < 0.2 then
		return
	end
	lastSquat = now

	if playAnimationSquat(character) then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			EffectsController.dust(root.Position)
		end
		return
	end

	fallbackFeedback(character)
end

-- ---------- tool ----------

local function hookTool(tool)
	if tool.Name ~= "Train" or tool:GetAttribute("TrainHooked") then
		return
	end
	tool:SetAttribute("TrainHooked", true)

	tool.Activated:Connect(function()
		local character = player.Character
		if not character then
			return
		end

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

		playSquat(character)
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

	-- publikált animáció leállítása, ha abbahagyod a kattintást
	task.spawn(function()
		while true do
			task.wait(0.3)
			if squatTrack and squatTrack.IsPlaying
				and os.clock() - lastSquatRefresh > GameConfig.TrainAnimStopDelay then
				squatTrack:Stop(0.25)
			end
		end
	end)
end

return TrainingController
