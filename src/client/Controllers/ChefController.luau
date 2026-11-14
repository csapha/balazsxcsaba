-- Chef vizuál (GDD 3.6, 12.2): a szerver a plot.Chefs/Chef{i} attribútumaiba írja a körút fázisát,
-- a kliens ebből interpolálja a helyzetet és kirajzol egy egyszerű, blokkos chef figurát
-- (fehér ruha, szakácssapka – placeholder, később modell).
--   séta: lábak/karok lengenek; schnitzelt visz: a kezében halom
--   alvás: lefekszik, "Zzz", és a tulajdonosnak "Wake up!" prompt (E / koppintás) → Remotes.WakeChef
--   ébresztéskor "POF!" felirat (GDD 10: csillag + "pof!" képregényes felirat – a szép VFX később)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Palette = Config.Palette
local FLOOR = Config.Plot.FloorTop

local SKIN = Color3.fromRGB(240, 200, 160)
local PANTS = Color3.fromRGB(60, 60, 70)
local MAX_CARRIED_VISUAL = 6

type Rig = {
	model: Model,
	parts: { [string]: BasePart },
	carried: { BasePart },
	zzz: BillboardGui,
	prompt: ProximityPrompt,
	lastPosition: Vector3?,
	facing: number, -- Y forgatás (radián)
}

local ChefController = {}

local rigs: { [Configuration]: Rig } = {}
local folder: Folder

local function part(name: string, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function buildRig(chef: Configuration, plot: Model): Rig
	local model = Instance.new("Model")
	model.Name = `{plot.Name}_{chef.Name}`

	local parts = {
		Torso = part("Torso", Vector3.new(2, 2, 1), Palette.White, model),
		Head = part("Head", Vector3.new(1.2, 1.2, 1.2), SKIN, model),
		Hat = part("Hat", Vector3.new(1.3, 1.1, 1.1), Palette.White, model, Enum.PartType.Cylinder),
		LeftArm = part("LeftArm", Vector3.new(0.9, 2, 0.9), Palette.White, model),
		RightArm = part("RightArm", Vector3.new(0.9, 2, 0.9), Palette.White, model),
		LeftLeg = part("LeftLeg", Vector3.new(0.95, 2, 0.95), PANTS, model),
		RightLeg = part("RightLeg", Vector3.new(0.95, 2, 0.95), PANTS, model),
	}
	model.PrimaryPart = parts.Torso

	local carried = {}
	for i = 1, MAX_CARRIED_VISUAL do
		local piece = part(`Carried{i}`, Vector3.new(1.5, 0.25, 1.1), Palette.Schnitzel, model)
		piece.Transparency = 1
		carried[i] = piece
	end

	local zzz = Instance.new("BillboardGui")
	zzz.Name = "Zzz"
	zzz.Size = UDim2.fromScale(3, 1.5)
	zzz.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	zzz.LightInfluence = 0
	zzz.Enabled = false
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "Zzz"
	text.TextColor3 = Palette.White
	Ui.worldText(text)
	text.Parent = zzz
	zzz.Parent = parts.Head

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Wake up!"
	prompt.ObjectText = "Sleeping chef"
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (UI Kit card)
	prompt:SetAttribute("Color", "Blue")
	prompt:SetAttribute("Icon", Ui.Icons.Energy)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Chefs.WakeDistance - 2
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = parts.Torso
	prompt.Triggered:Connect(function()
		Remotes.WakeChef:FireServer(chef:GetAttribute("Index"))
	end)

	model.Parent = folder
	return {
		model = model,
		parts = parts,
		carried = carried,
		zzz = zzz,
		prompt = prompt,
		facing = 0,
	}
end

-- A figura kirajzolása: root = a csípő magassága, a chef nézési irányába forgatva.
local function pose(rig: Rig, root: CFrame, walking: boolean, sleeping: boolean, carrying: number, now: number)
	local p = rig.parts
	if sleeping then
		-- hanyatt fekszik
		root = root * CFrame.new(0, -1.7, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	end

	local swing = if walking then math.sin(now * 10) * 0.7 else 0
	local holding = carrying > 0 and not sleeping

	local torso = root * CFrame.new(0, 1, 0)
	p.Torso.CFrame = torso
	p.Head.CFrame = torso * CFrame.new(0, 1.6, 0)
	p.Hat.CFrame = torso * CFrame.new(0, 2.65, 0) * CFrame.Angles(0, 0, math.pi / 2)

	-- pozitív X-forgatás → a kar előre lendül (a schnitzeleket maga előtt viszi)
	local armAngle = if holding then math.pi / 2.4 else swing
	p.LeftArm.CFrame = torso * CFrame.new(-1.45, 0.9, 0) * CFrame.Angles(armAngle, 0, 0) * CFrame.new(0, -0.9, 0)
	p.RightArm.CFrame = torso * CFrame.new(1.45, 0.9, 0) * CFrame.Angles(if holding then armAngle else -swing, 0, 0)
		* CFrame.new(0, -0.9, 0)
	p.LeftLeg.CFrame = root * CFrame.new(-0.5, 0, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	p.RightLeg.CFrame = root * CFrame.new(0.5, 0, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)

	local visible = if holding then math.min(carrying, MAX_CARRIED_VISUAL) else 0
	for i, piece in rig.carried do
		if i <= visible then
			piece.Transparency = 0
			piece.CFrame = torso * CFrame.new(0, 0.2 + (i - 1) * 0.27, -1.6) * CFrame.Angles(0, i * 0.4, 0)
		else
			piece.Transparency = 1
		end
	end
end

local function update()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local seen = {}

	for _, plot in plots:GetChildren() do
		local origin = plot:GetAttribute("Origin")
		local chefs = plot:FindFirstChild("Chefs")
		if typeof(origin) ~= "CFrame" or not chefs then
			continue
		end
		local isOwner = plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId

		for _, chef in chefs:GetChildren() do
			if not chef:IsA("Configuration") then
				continue
			end
			local phase = chef:GetAttribute("Phase")
			local from = chef:GetAttribute("From")
			local to = chef:GetAttribute("To")
			if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
				continue
			end
			seen[chef] = true

			local rig = rigs[chef]
			if not rig then
				rig = buildRig(chef, plot :: Model)
				rigs[chef] = rig
			end

			local start = chef:GetAttribute("Start") or now
			local duration = chef:GetAttribute("Duration") or 0
			local alpha = if duration > 0 then math.clamp((now - start) / duration, 0, 1) else 1
			local position = from:Lerp(to, alpha)
			local walking = (phase == "toCollector" or phase == "toTable") and alpha < 1
			local sleeping = phase == "sleep"

			-- a menetirány felé fordul; álló helyzetben megtartja az irányt
			local delta = to - from
			if walking and delta.Magnitude > 0.01 then
				rig.facing = math.atan2(-delta.X, -delta.Z)
			end

			local root = origin * CFrame.new(position.X, FLOOR + 2, position.Z) * CFrame.Angles(0, rig.facing, 0)
			pose(rig, root, walking, sleeping, chef:GetAttribute("Carrying") or 0, clock)

			rig.zzz.Enabled = sleeping
			rig.prompt.Enabled = sleeping and isOwner
		end
	end

	-- eltűnt chefek (pl. kilépett a tulajdonos) figuráinak törlése
	for chef, rig in rigs do
		if not seen[chef] then
			rig.model:Destroy()
			rigs[chef] = nil
		end
	end
end

-- "POF!" felirat ébresztéskor
local function onChefWoke(plotIndex: number, chefIndex: number)
	for chef, rig in rigs do
		local plot = chef.Parent and chef.Parent.Parent
		if plot and plot.Name == `Plot{plotIndex}` and chef:GetAttribute("Index") == chefIndex then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(4, 2)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = "⭐ BONK! ⭐"
			label.TextColor3 = Palette.Lemon
			Ui.worldText(label)
			label.Parent = gui
			gui.Parent = rig.parts.Head

			local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
			Ui.fadeText(label, info)
			task.delay(1, function()
				gui:Destroy()
			end)
			return
		end
	end
end

function ChefController.init()
	folder = Instance.new("Folder")
	folder.Name = "ChefVisuals"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(update)
	Remotes.ChefWoke.OnClientEvent:Connect(onChefWoke)
end

return ChefController
