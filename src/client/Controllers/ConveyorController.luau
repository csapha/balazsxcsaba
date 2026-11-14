-- Kliens-oldali vizuálok (GDD 12.2): sütő progress bar + a szalagon guruló schnitzelek.
-- A szerverrel ugyanazt a sütési ciklust számolja (Formulas.bakeCycle), így hálózati forgalom nélkül szinkronban van.
-- A darabok poolozva vannak, telkenként max ~30 látható.
-- Ritka sütés (GDD 3.4): a szerver szól (RareBake), a darab kiszíneződik, felirat ugrik fel a sütő felett,
-- Nagyi Titkos Receptjénél chat üzenet megy az egész szerverre.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Chat = require(script.Parent.Parent.Util.Chat)

local Layout = Config.Plot
local Conveyor = Layout.Conveyor
local Palette = Config.Palette

local MAX_PER_PLOT = 30
local SCHNITZEL_SIZE = Vector3.new(1.8, 0.3, 1.3)
local RARE_POP_TIME = 2.2

type Visual = {
	part: BasePart,
	plot: Model,
	slot: number,
	origin: CFrame,
	path: { Vector3 },
	segment: number, -- az aktuális szakasz kezdőpontja a path-ban
	along: number, -- megtett távolság az aktuális szakaszon
	rare: boolean?,
}

local ConveyorController = {}

local plotsFolder: Folder?
local visualsFolder: Folder
local pool: { BasePart } = {}
local active: { Visual } = {}
local activeCount: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastCycle: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local function takePart(): BasePart
	local part = table.remove(pool)
	if part then
		return part
	end
	part = Instance.new("Part")
	part.Name = "Schnitzel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = SCHNITZEL_SIZE
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Config.Palette.Schnitzel
	return part
end

local function spawnSchnitzel(plot: Model, origin: CFrame, slot: number, level: number)
	if (activeCount[plot] or 0) >= MAX_PER_PLOT then
		return
	end
	local part = takePart()
	-- magasabb szint → kicsit nagyobb, aranyabb darab (placeholder)
	local t = math.clamp((level - 1) / (Formulas.maxLevel() - 1), 0, 1)
	part.Size = SCHNITZEL_SIZE * (1 + t * 0.6)
	part.Color = Palette.Schnitzel:Lerp(Palette.RarityGold, t)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = visualsFolder

	table.insert(active, {
		part = part,
		plot = plot,
		slot = slot,
		origin = origin,
		path = Formulas.conveyorPath(slot),
		segment = 1,
		along = 0,
	})
	activeCount[plot] = (activeCount[plot] or 0) + 1
end

local function updateOvens(plots: Folder, now: number)
	for _, plot in plots:GetChildren() do
		local origin = plot:GetAttribute("Origin")
		local ovens = plot:FindFirstChild("Ovens")
		if typeof(origin) ~= "CFrame" or not ovens then
			continue
		end
		local interval = plot:GetAttribute("BakeInterval")
		local blackout = EventState.is("Blackout") -- GDD 3.12: áramszünetben nem sütnek
		for _, oven in ovens:GetChildren() do
			local slot = oven:GetAttribute("Slot")
			local level = oven:GetAttribute("Level")
			if not slot or not level then
				continue
			end

			local cycle, progress = Formulas.bakeCycle(now, slot, interval)
			local fill = oven:FindFirstChild("Fill", true) :: Frame?
			if fill then
				fill.Size = UDim2.fromScale(if blackout then 0 else progress, 1)
			end

			local last = lastCycle[oven]
			lastCycle[oven] = cycle
			if last and cycle > last and not blackout then
				spawnSchnitzel(plot :: Model, origin, slot, level)
			end
		end
	end
end

-- A darabok a Formulas.conveyorPath útvonalon haladnak (ugyanazzal a sebességgel, mint amivel a szerver számol).
-- Ha a collectorba értek, eltűnnek – ott már a halom (CollectorController) mutatja őket.
local function updateVisuals(dt: number)
	for i = #active, 1, -1 do
		local visual = active[i]
		local path = visual.path
		visual.along += Conveyor.Speed * dt

		local finished = not visual.plot.Parent
		while not finished do
			local from, to = path[visual.segment], path[visual.segment + 1]
			if not to then
				finished = true
				break
			end
			local length = (to - from).Magnitude
			if visual.along < length then
				local position = from:Lerp(to, if length > 0 then visual.along / length else 1)
				visual.part.CFrame = visual.origin * CFrame.new(position)
				break
			end
			visual.along -= length
			visual.segment += 1
		end

		if finished then
			visual.part.Parent = nil
			table.insert(pool, visual.part)
			activeCount[visual.plot] = math.max(0, (activeCount[visual.plot] or 1) - 1)
			table.remove(active, i)
		end
	end
end

-- Felugró, felfelé úszó felirat egy sütő felett (a szép VFX a 10. fejezetben jön).
local function popLabel(oven: BasePart, title: string, subtitle: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RarePop"
	gui.Size = UDim2.fromScale(10, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Layout.Ovens.Size.Y / 2 + 4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = oven

	for index, line in { { title, 0.6, color }, { subtitle, 0.4, Palette.White } } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, if index == 1 then 0 else 0.6)
		label.Size = UDim2.fromScale(1, line[2])
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = line[1]
		label.TextColor3 = line[3]
		Ui.worldText(label)
		label.Parent = gui
	end

	gui.Parent = oven
	TweenService:Create(gui, TweenInfo.new(RARE_POP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3, 0),
	}):Play()
	Debris:AddItem(gui, RARE_POP_TIME)
end


local function onRareBake(plotIndex: number, slot: number, rarityIndex: number, ownerName: string)
	local rarity = Config.Rarities.List[rarityIndex]
	if not rarity then
		return
	end

	local plot = plotsFolder and plotsFolder:FindFirstChild(`Plot{plotIndex}`)
	if plot then
		-- a legfrissebb darab ebből a sütőből kapja a ritkaság színét
		for i = #active, 1, -1 do
			local visual = active[i]
			if visual.plot == plot and visual.slot == slot and not visual.rare then
				visual.rare = true
				visual.part.Color = rarity.Color
				visual.part.Material = Enum.Material.Neon
				break
			end
		end

		local ovens = plot:FindFirstChild("Ovens")
		local oven = ovens and ovens:FindFirstChild(`Oven{slot}`)
		if oven and oven:IsA("BasePart") then
			popLabel(oven, `{rarity.Name}!`, `x{rarity.UnitMult} pieces, x{rarity.ValueMult} price`, rarity.Color)
		end
	end

	if rarity.Announce then
		Chat.announce(`🎉 {ownerName} fried a {string.upper(rarity.Name)}!`, rarity.Color)
	end
end

function ConveyorController.init()
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "SchnitzelVisuals"
	visualsFolder.Parent = workspace

	Remotes.RareBake.OnClientEvent:Connect(onRareBake)

	task.spawn(function()
		local plots = workspace:WaitForChild("Plots") :: Folder
		plotsFolder = plots
		RunService.RenderStepped:Connect(function(dt)
			updateOvens(plots, workspace:GetServerTimeNow())
			updateVisuals(dt)
		end)
	end)
end

return ConveyorController
