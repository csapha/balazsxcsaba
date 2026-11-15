-- GDD 7.2: a bought oven "falls from the sky" – BUMM, a puff of dust. The server marks it with the "Drop" attribute
-- (not for merges or the first build on join); the fall is local (the parts are anchored, the server never moves
-- them again), so it costs no network.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))
local Audio = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Audio"))

local DROP_HEIGHT = 16
local DROP_TIME = 0.32

local player = Players.LocalPlayer

local OvenDropController = {}

local function puff(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "OvenDust"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Ui.Textures.Soft
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Size = NumberSequence.new(1.5, 4)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Drag = 4
	emitter.Enabled = false
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(18)
	task.delay(1.2, part.Destroy, part)
end

local function drop(oven: BasePart)
	local parts = { oven }
	for _, d in oven:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local finals = {}
	for i, part in parts do
		finals[i] = part.CFrame
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / DROP_TIME, 0, 1)
		local offset = DROP_HEIGHT * (1 - t * t) -- falls faster and faster
		for i, part in parts do
			if part.Parent then
				part.CFrame = finals[i] + Vector3.new(0, offset, 0)
			end
		end
		if t >= 1 then
			connection:Disconnect()
			puff(finals[1].Position - Vector3.new(0, oven.Size.Y / 2, 0))
			-- only your own plot makes the sound (the others' ovens land quietly)
			local plot = oven:FindFirstAncestorWhichIsA("Model")
			if plot and plot:GetAttribute("OwnerId") == player.UserId then
				Audio.play("Impact")
			end
		end
	end)
end

local function watchOvens(folder: Instance)
	folder.ChildAdded:Connect(function(child)
		task.defer(function() -- the attribute arrives in the same replication batch
			if child:IsA("BasePart") and child:GetAttribute("Drop") then
				drop(child)
			end
		end)
	end)
end

local function watchPlot(plot: Instance)
	local ovens = plot:FindFirstChild("Ovens")
	if ovens then
		watchOvens(ovens)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Ovens" then
			watchOvens(child)
		end
	end)
end

function OvenDropController.init()
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots")
		plots.ChildAdded:Connect(watchPlot)
		for _, plot in plots:GetChildren() do
			watchPlot(plot)
		end
	end)
end

return OvenDropController
