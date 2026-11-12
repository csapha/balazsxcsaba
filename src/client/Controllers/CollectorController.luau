-- Collector vizuál (GDD 3.5):
--   1. halom a collectoron: sütésenként egy darab (max PILE_MAX), a ritkák elöl, ritkaság színben.
--      A szerver a telek attribútumaiba írja: TrayCount, TrayRarity1..N.
--   2. felvételkor "+n" feliratok a játékos feje felett, minőségenként (Remotes.PickedUp).
-- A placeholder darabok később modellekre cserélhetők.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Layout = Config.Plot
local Palette = Config.Palette
local Rarities = Config.Rarities.List

local PILE_MAX = 36
local PER_ROW = 4
local PER_LAYER = 12 -- 4 × 3
local PIECE_SIZE = Vector3.new(1.8, 0.3, 1.3)
local POPUP_TIME = 1.3

local CollectorController = {}

local piles: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function makePiece(): BasePart
	local part = Instance.new("Part")
	part.Name = "PileSchnitzel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = PIECE_SIZE
	return part
end

-- A halom újrarajzolása egy telek attribútumaiból.
local function renderPile(plot: Model)
	local origin = plot:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end

	-- színek: ritkák elöl (legritkább először), utána a simák
	local colors = {}
	for rarity = #Rarities, 2, -1 do
		local count = plot:GetAttribute(`TrayRarity{rarity}`) or 0
		for _ = 1, math.min(count, PILE_MAX - #colors) do
			table.insert(colors, rarity)
		end
	end
	local total = math.min(plot:GetAttribute("TrayCount") or 0, PILE_MAX)
	while #colors < total do
		table.insert(colors, 1)
	end

	local pieces = piles[plot]
	if not pieces then
		pieces = {}
		piles[plot] = pieces
	end

	local collector = Layout.Pads.Pickup
	local baseY = Layout.FloorTop + (collector.Height or 0.3) + PIECE_SIZE.Y / 2
	for i = 1, PILE_MAX do
		local rarity = colors[i]
		local piece = pieces[i]
		if not rarity then
			if piece then
				piece.Parent = nil
			end
			continue
		end
		if not piece then
			piece = makePiece()
			pieces[i] = piece
		end

		local index = i - 1
		local layer = index // PER_LAYER
		local inLayer = index % PER_LAYER
		local column = inLayer % PER_ROW
		local row = inLayer // PER_ROW
		-- determinisztikus kis elforgatás és eltolás, hogy halomnak tűnjön
		local jitter = math.sin(i * 12.9898) * 0.3
		local position = Vector3.new(
			collector.Position.X + (column - (PER_ROW - 1) / 2) * 2.1 + jitter,
			baseY + layer * PIECE_SIZE.Y,
			collector.Position.Y + (row - 1) * 1.8 - jitter
		)
		piece.CFrame = origin * CFrame.new(position) * CFrame.Angles(0, jitter * 2, 0)
		piece.Color = Rarities[rarity].Color
		piece.Material = if rarity > 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		piece.Parent = plot
	end
end

-- Halom a leadó asztalon: a pultban eladásra váró készlet (CounterStock attribútum).
-- 10 darabig darabonként, utána logaritmikusan nő (max TABLE_MAX), ahogy a pult elad, fogy.
local TABLE_MAX = 24
local tablePiles: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function tablePieceCount(stock: number): number
	if stock <= 0 then
		return 0
	end
	if stock <= 10 then
		return math.ceil(stock)
	end
	return math.min(TABLE_MAX, 10 + math.floor(math.log(stock / 10, 2) * 2))
end

local function renderTablePile(plot: Model)
	local origin = plot:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	local wanted = tablePieceCount(plot:GetAttribute("CounterStock") or 0)

	local pieces = tablePiles[plot]
	if not pieces then
		pieces = {}
		tablePiles[plot] = pieces
	end

	local pad = Layout.Pads.Deposit
	local baseY = Layout.FloorTop + (pad.Height or 0.3) + PIECE_SIZE.Y / 2
	local perRow, perLayer = 4, 8 -- 4 × 2 rétegenként
	for i = 1, TABLE_MAX do
		local piece = pieces[i]
		if i > wanted then
			if piece then
				piece.Parent = nil
			end
			continue
		end
		if not piece then
			piece = makePiece()
			piece.Color = if i % 2 == 0 then Palette.Schnitzel else Palette.Gold
			piece.Material = Enum.Material.SmoothPlastic
			pieces[i] = piece
		end
		local index = i - 1
		local layer = index // perLayer
		local inLayer = index % perLayer
		local jitter = math.sin(i * 7.31) * 0.25
		local position = Vector3.new(
			pad.Position.X + (inLayer % perRow - (perRow - 1) / 2) * 2.1 + jitter,
			baseY + layer * PIECE_SIZE.Y,
			pad.Position.Y + (inLayer // perRow - 0.5) * 1.6 - jitter
		)
		piece.CFrame = origin * CFrame.new(position) * CFrame.Angles(0, jitter * 2, 0)
		piece.Parent = plot
	end
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	plot.AttributeChanged:Connect(function(name)
		if name == "TrayCount" or string.sub(name, 1, 10) == "TrayRarity" then
			renderPile(plot)
		elseif name == "CounterStock" then
			renderTablePile(plot)
		end
	end)
	renderPile(plot)
	renderTablePile(plot)
end

-- "+47", "+20 Ezüst Schnitzel" feliratok a játékos feje felett, felfelé úszva.
local function showPickup(picked: { { rarity: number, units: number } })
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head or #picked == 0 then
		return
	end

	table.sort(picked, function(a, b)
		return a.rarity > b.rarity
	end)

	local gui = Instance.new("BillboardGui")
	gui.Name = "PickupPopup"
	gui.Size = UDim2.fromScale(8, 1.1 * #picked)
	gui.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = head

	local labels = {}
	for i, entry in picked do
		local rarity = Rarities[entry.rarity]
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (i - 1) / #picked)
		label.Size = UDim2.fromScale(1, 1 / #picked)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = if entry.rarity == 1
			then `+{NumberFormat.grouped(entry.units)}`
			else `+{NumberFormat.grouped(entry.units)} {rarity.Name}`
		label.TextColor3 = if entry.rarity == 1 then Palette.Gold else rarity.Color
		label.TextStrokeColor3 = Palette.Stroke
		label.TextStrokeTransparency = 0
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = head

	local info = TweenInfo.new(POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	for _, label in labels do
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	task.delay(POPUP_TIME, function()
		gui:Destroy()
	end)
end

function CollectorController.init()
	Remotes.PickedUp.OnClientEvent:Connect(showPickup)

	task.spawn(function()
		local plots = workspace:WaitForChild("Plots")
		plots.ChildAdded:Connect(watchPlot)
		for _, plot in plots:GetChildren() do
			watchPlot(plot)
		end
	end)
end

return CollectorController
