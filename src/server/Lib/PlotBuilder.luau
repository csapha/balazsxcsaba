-- Szürke dobozos telek felépítése kódból (GDD 3.1, 14. fejezet: 0. fázis prototípus).
-- A geometria később lecserélhető modellekre; a kód a part neveket és a Config.Plot pozíciókat használja.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Billboard = require(script.Parent.Billboard)

local Palette = Config.Palette
local Layout = Config.Plot

export type PlotRefs = {
	index: number,
	origin: CFrame,
	model: Model,
	ovens: Folder,
	customers: Folder,
	chefs: Folder,
	generationBoard: { [string]: GuiObject },
	slotMarkers: { BasePart },
	pads: { [string]: BasePart },
	labels: { [string]: { [string]: TextLabel } },
	alerts: { [string]: BillboardGui },
	counterXpFill: Frame,
	sign: TextLabel,
}

local PlotBuilder = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function titleInfo(adornee: BasePart, height: number, width: number): { [string]: TextLabel }
	return Billboard.new(adornee, {
		offset = Vector3.new(0, height, 0),
		size = Vector2.new(width, width * 0.4),
		lines = {
			{ name = "Title", height = 0.55 },
			{ name = "Info", color = Palette.Money, height = 0.45 },
		},
	})
end

function PlotBuilder.build(index: number, parent: Instance): PlotRefs
	local origin = Formulas.plotOrigin(index)
	local floorTop = Layout.FloorTop

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Index", index)
	model:SetAttribute("Origin", origin)

	local refs = {
		index = index,
		origin = origin,
		model = model,
		pads = {},
		labels = {},
		alerts = {},
	} :: any

	-- Padló
	local floor = makePart(
		"Floor",
		Vector3.new(Layout.Size.X, 1, Layout.Size.Y),
		at(0, floorTop - 0.5, 0),
		Palette.Floor,
		model
	)
	model.PrimaryPart = floor

	-- Emelt platform a sütőknek; az eleje a fal a collector mögött
	local platform = Layout.Platform
	local platformTop = Formulas.platformTop()
	local backEdge = -Layout.Size.Y / 2
	makePart(
		"Platform",
		Vector3.new(Layout.Size.X, platform.Height, platform.FrontZ - backEdge),
		at(0, floorTop + platform.Height / 2, (platform.FrontZ + backEdge) / 2),
		Palette.Platform,
		model
	)

	-- 1. Sütősor: slot jelölők (a zárolt slotok rejtve) + mappa a sütőknek
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	refs.slotMarkers = {}
	for slot = 1, Config.Ovens.MaxSlots do
		local marker = makePart(
			`Slot{slot}`,
			Vector3.new(5.8, 0.1, 5.8),
			origin * Formulas.slotCFrame(slot) * CFrame.new(0, 0.05, 0),
			Palette.SlotMarker,
			slots
		)
		marker.CanCollide = false
		marker.Transparency = if slot <= Config.Ovens.StartSlots then 0 else 1
		refs.slotMarkers[slot] = marker
	end

	local ovens = Instance.new("Folder")
	ovens.Name = "Ovens"
	ovens.Parent = model
	refs.ovens = ovens

	-- 2. Futószalag (két oldalról középre) + csúszda a fal széléig
	local conveyor = Layout.Conveyor
	local collector = Layout.Pads.Pickup
	makePart(
		"Conveyor",
		Vector3.new(conveyor.HalfLength * 2, conveyor.Height, conveyor.Width),
		at(collector.Position.X, platformTop + conveyor.Height / 2, conveyor.Z),
		Palette.Conveyor,
		model
	)
	local chuteLength = platform.FrontZ - conveyor.Z
	makePart(
		"Chute",
		Vector3.new(conveyor.Width, conveyor.Height, chuteLength),
		at(collector.Position.X, platformTop + conveyor.Height / 2, conveyor.Z + chuteLength / 2),
		Palette.Conveyor,
		model
	)

	-- Ritkaság-esély tábla a falon, a collector mellett (GDD 3.4)
	local board = Layout.RarityBoard
	local boardPart = makePart(
		"RarityBoard",
		Vector3.new(board.Size.X, board.Size.Y, 0.2),
		at(board.X, floorTop + platform.Height / 2, platform.FrontZ + 0.1),
		Palette.Panel,
		model
	)
	PlotBuilder.buildRarityBoard(boardPart)

	-- 6. Eladópult + placeholder vendégsor
	local counterConfig = Layout.Counter
	local counter = makePart(
		"Counter",
		counterConfig.Size,
		at(counterConfig.Position.X, floorTop + counterConfig.Size.Y / 2, counterConfig.Position.Y),
		Palette.Wood,
		model
	)
	-- Pult felirat: szint + sebesség, készlet, XP sáv (GDD 3.1: "pult szint + XP bar")
	refs.labels.Counter = Billboard.new(counter, {
		offset = Vector3.new(0, 6, 0),
		size = Vector2.new(12, 5.4),
		lines = {
			{ name = "Title", height = 0.36 },
			{ name = "Info", color = Palette.Money, height = 0.3 },
			{ name = "Xp", color = Palette.Lemon, height = 0.2 },
		},
	})
	local xpBar = Instance.new("Frame")
	xpBar.Name = "XpBar"
	xpBar.LayoutOrder = 4
	xpBar.Size = UDim2.fromScale(0.7, 0.1)
	xpBar.BackgroundColor3 = Palette.Panel
	xpBar.BorderSizePixel = 0
	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Palette.Lemon
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBar
	xpBar.Parent = refs.labels.Counter.Title.Parent
	refs.counterXpFill = xpFill

	-- Sütő-generáció tábla (GDD 3.7): a GenerationService írja ki az állást
	local boardConfig = Layout.GenerationBoard
	local genBoard = makePart(
		"GenerationBoard",
		Vector3.new(0.5, boardConfig.Size.Y, boardConfig.Size.X),
		at(boardConfig.Position.X, floorTop + boardConfig.Size.Y / 2, boardConfig.Position.Y),
		Palette.Panel,
		model
	)
	refs.generationBoard = PlotBuilder.buildGenerationBoard(genBoard)

	-- Chef pihenőhely + a chefek állapota (a ChefService írja, a kliens rajzolja ki)
	local rest = Layout.ChefRest
	local restPart = makePart(
		"ChefRest",
		Vector3.new(rest.Size.X, 0.2, rest.Size.Y),
		at(rest.Position.X, floorTop + 0.1, rest.Position.Y),
		Palette.ChefRest,
		model
	)
	restPart.CanCollide = false
	local restLabel = Billboard.new(restPart, {
		offset = Vector3.new(0, 3, 0),
		size = Vector2.new(10, 1.4),
		lines = { { name = "Title", color = Palette.White, height = 1 } },
	})
	restLabel.Title.Text = "Chef pihenő"

	local chefs = Instance.new("Folder")
	chefs.Name = "Chefs"
	chefs.Parent = model
	refs.chefs = chefs

	-- Vendégek mappája (a CustomerService tölti fel a tulajdonos barátaival)
	local customers = Instance.new("Folder")
	customers.Name = "Customers"
	customers.Parent = model
	refs.customers = customers

	-- 3–8. Rálépős padek
	for key, pad in Layout.Pads do
		local height = pad.Height or 0.3
		local part
		if pad.Table then
			-- asztal: lap a megadott magasságban + 4 láb
			local thickness = 0.5
			part = makePart(
				key,
				Vector3.new(pad.Size.X, thickness, pad.Size.Y),
				at(pad.Position.X, floorTop + height - thickness / 2, pad.Position.Y),
				pad.Color,
				model
			)
			local legHeight = height - thickness
			for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
				makePart(
					`{key}Leg`,
					Vector3.new(0.6, legHeight, 0.6),
					at(
						pad.Position.X + corner.X * (pad.Size.X / 2 - 0.5),
						floorTop + legHeight / 2,
						pad.Position.Y + corner.Y * (pad.Size.Y / 2 - 0.5)
					),
					Palette.Wood,
					model
				)
			end
		else
			part = makePart(
				key,
				Vector3.new(pad.Size.X, height, pad.Size.Y),
				at(pad.Position.X, floorTop + height / 2, pad.Position.Y),
				pad.Color,
				model
			)
			if not pad.Flat then
				part.Material = Enum.Material.Neon
			end
		end
		refs.pads[key] = part

		local labelHeight = pad.LabelHeight or 4.5
		local labels = titleInfo(part, labelHeight, pad.LabelWidth or math.max(pad.Size.X, 7))
		labels.Title.Text = pad.Title
		refs.labels[key] = labels

		-- Szűk keresztmetszet jelzés: nagy piros "!" a felirat felett (alapból rejtve)
		local alert = Billboard.new(part, {
			offset = Vector3.new(0, labelHeight + 3.2, 0),
			size = Vector2.new(2.6, 2.6),
			maxDistance = 200,
			lines = { { name = "Mark", color = Palette.Danger, height = 1 } },
		})
		alert.Mark.Text = "!"
		local alertGui = alert.Mark.Parent :: BillboardGui
		alertGui.Name = "Alert"
		alertGui.AlwaysOnTop = true
		alertGui.Enabled = false
		refs.alerts[key] = alertGui
	end

	-- Tulajdonos tábla
	local post = makePart(
		"SignPost",
		Vector3.new(1, 10, 1),
		at(Layout.Sign.X, floorTop + 5, Layout.Sign.Y),
		Palette.Wood,
		model
	)
	refs.sign = Billboard.new(post, {
		offset = Vector3.new(0, 7, 0),
		size = Vector2.new(16, 3),
		maxDistance = 300,
		lines = { { name = "Owner", color = Palette.Lemon, height = 1 } },
	}).Owner
	refs.sign.Text = "Szabad telek"

	model.Parent = parent
	return refs
end

-- A ritkaság-esélyek kiírása a falra (a Config.Rarities alapján, így mindig naprakész).
local function formatChance(chance: number): string
	local percent = chance * 100
	local text = string.format("%.3f", percent)
	text = (text:gsub("0+$", ""))
	text = (text:gsub("%.$", ""))
	return text .. "%"
end

function PlotBuilder.buildRarityBoard(boardPart: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Chances"
	gui.Face = Enum.NormalId.Back -- +Z: a játékos felé
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Adornee = boardPart

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.01, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local rarities = Config.Rarities.List
	local normalChance = 1
	for i = 2, #rarities do
		normalChance -= rarities[i].Chance
	end

	local entries = { { "Esély", "ritkaság", Palette.White } }
	for i, rarity in rarities do
		local chance = if i == 1 then normalChance else rarity.Chance
		table.insert(entries, { rarity.Name, formatChance(chance), rarity.Color })
	end

	for order, entry in entries do
		local column = Instance.new("Frame")
		column.LayoutOrder = order
		column.BackgroundTransparency = 1
		column.Size = UDim2.fromScale(0.95 / #entries, 0.9)
		column.Parent = gui

		for row, line in { { entry[1], 0, 0.5 }, { entry[2], 0.5, 0.5 } } do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0, line[2])
			label.Size = UDim2.fromScale(1, line[3])
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextWrapped = true
			label.Text = line[1]
			label.TextColor3 = if row == 1 then entry[3] else Palette.White
			label.TextStrokeColor3 = Palette.Stroke
			label.TextStrokeTransparency = 0
			label.Parent = column
		end
	end

	gui.Parent = boardPart
end

-- Sütő-generáció tábla: cím, jelenlegi generáció, következő generáció + progress sáv.
-- A tábla a telek közepe felé (-X) néz.
function PlotBuilder.buildGenerationBoard(board: BasePart): { [string]: GuiObject }
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Generation"
	gui.Face = Enum.NormalId.Left -- -X: a telek közepe felé
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Adornee = board

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local refs = {}
	for order, line in {
		{ "Title", 0.2, Palette.Gold },
		{ "Current", 0.2, Palette.White },
		{ "Next", 0.17, Palette.Lemon },
	} do
		local label = Instance.new("TextLabel")
		label.Name = line[1]
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.92, line[2])
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line[3]
		label.TextStrokeColor3 = Palette.Stroke
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
		refs[line[1]] = label
	end
	refs.Title.Text = "SÜTŐ-GENERÁCIÓ"

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.LayoutOrder = 4
	bar.Size = UDim2.fromScale(0.85, 0.1)
	bar.BackgroundColor3 = Palette.Stroke
	bar.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Palette.Lemon
	fill.BorderSizePixel = 0
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	fill.Parent = bar
	bar.Parent = gui
	refs.Fill = fill

	gui.Parent = board
	return refs
end

-- Közös talaj + utca + spawn (csak ha a place-ben még nincs).
function PlotBuilder.buildWorld(parent: Instance)
	if not workspace:FindFirstChild("Baseplate") and not workspace:FindFirstChild("Ground") then
		local ground = makePart("Ground", Vector3.new(460, 1, 260), CFrame.new(0, -0.5, 0), Palette.Ground, parent)
		ground.Material = Enum.Material.Grass
	end

	local street = makePart("Street", Vector3.new(400, 0.1, 36), CFrame.new(0, 0.05, 0), Palette.Street, parent)
	street.CanCollide = false

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "StreetSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(0, 0.2, 0)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = parent
	end
end

return PlotBuilder
