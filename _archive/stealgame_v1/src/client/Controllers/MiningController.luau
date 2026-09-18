-- Bányászás (kliens): swing + MineRequest a szervernek.
-- Ha be van állítva publikált swing animáció (Game.SwingAnimationId), azt játssza,
-- különben beépített procedurális swing (váll + derék).
-- A szerver raycasttal validálja, hogy a penge a bányakövet találja.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local MiningController = {}
local swingTrack = nil

-- swing állapot (gyors kattintásnál ne csússzanak egymásra a tweenek)
local baseGrips = setmetatable({}, { __mode = "k" }) -- [tool] = eredeti Grip
local swinging = setmetatable({}, { __mode = "k" }) -- [tool] = true/false

local function getAnimator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- publikált animáció betöltése (ha van beállítva)
local function playAnimationSwing(character)
	if GameConfig.SwingAnimationId == "" then
		return false
	end

	local animator = getAnimator(character)
	if not animator then
		return false
	end

	if not swingTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = GameConfig.SwingAnimationId

		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			return false
		end

		track.Priority = Enum.AnimationPriority.Action
		swingTrack = track
	end

	swingTrack:Play(0.05)
	return true
end

-- beépített swing: a csákányt magát forgatjuk a fogás körül.
-- (A Motor6D.C0 zárolt, ezért nem a vállat tweeneljük.)
-- Swing közben új ütés nem indít új animációt (nincs összecsúszás),
-- és a végén mindig pontosan az eredeti Grip-re áll vissza.
local function playToolSwing(tool)
	if swinging[tool] then
		return
	end

	local base = baseGrips[tool]
	if not base then
		base = tool.Grip
		baseGrips[tool] = base
	end

	swinging[tool] = true

	local keys = {
		{ time = 0.09, grip = base * CFrame.Angles(math.rad(-60), 0, 0) }, -- felkészülés
		{ time = 0.12, grip = base * CFrame.Angles(math.rad(35), 0, 0) }, -- csapás
		{ time = 0.14, grip = base }, -- visszatérés
	}

	task.spawn(function()
		for _, key in ipairs(keys) do
			if not tool.Parent then
				break
			end
			local tween = TweenService:Create(
				tool,
				TweenInfo.new(key.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Grip = key.grip }
			)
			tween:Play()
			tween.Completed:Wait()
		end

		if tool.Parent then
			tool.Grip = base
		end
		swinging[tool] = false
	end)
end

-- NEM kell a kőre célozni: elég közel lenni hozzá.
-- A kliens csak jelzi az ütést (swinggel együtt), a szerver ellenőrzi
-- a távolságot és a cooldownt.
local function hookTool(tool)
	if tool.Name ~= "Pickaxe" or tool:GetAttribute("ClientHooked") then
		return
	end
	tool:SetAttribute("ClientHooked", true)

	tool.Activated:Connect(function()
		local character = player.Character
		if not character then
			return
		end

		if not playAnimationSwing(character) then
			playToolSwing(tool)
		end

		local remote = Net.get("MineRequest")
		if remote then
			remote:FireServer()
		end
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

function MiningController.init()
	local backpack = player:WaitForChild("Backpack")
	hookContainer(backpack)

	player.CharacterAdded:Connect(function(character)
		swingTrack = nil -- új karakter = új Animator
		hookContainer(character)
	end)

	if player.Character then
		hookContainer(player.Character)
	end
end

return MiningController
