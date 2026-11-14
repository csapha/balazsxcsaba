-- GDD 3.5: a játékosnál lévő schnitzelek a feje felett tornyosulnak (vicces vizuál), mindenki látja.
-- A szerver a játékos "Carried" attribútumába írja a darabszámot.
-- A torony magassága: 10 darabig darabonként nő, utána logaritmikusan (max MAX_PIECES), tetején a szám.
-- Leadáskor (Remotes.Deposited) a torony darabjai ívben átrepülnek a leadó asztalra, "+n" felirattal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Palette = Config.Palette
local Layout = Config.Plot

local FLY_TIME = 0.45
local FLY_STAGGER = 0.035
local FLY_MAX = 16
local HIDE_AFTER_DEPOSIT = 0.6 -- ennyi ideig nem rajzoljuk a saját tornyot (amíg az attribútum frissül)

local MAX_PIECES = 24
local PIECE_SIZE = Vector3.new(1.6, 0.28, 1.2)
local GAP = 0.04
local HEAD_OFFSET = 1.1

type Tower = {
	pieces: { BasePart },
	label: BillboardGui,
	count: number,
}

local StackController = {}

local towers: { [Player]: Tower } = {}
local folder: Folder
local hiddenUntil = 0

local function pieceCount(carried: number): number
	if carried <= 0 then
		return 0
	end
	if carried <= 10 then
		return carried
	end
	return math.min(MAX_PIECES, 10 + math.floor(math.log(carried / 10, 2) * 2))
end

local function newPiece(index: number): BasePart
	local part = Instance.new("Part")
	part.Name = "StackSchnitzel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = PIECE_SIZE
	part.Material = Enum.Material.SmoothPlastic
	-- enyhe árnyalat-váltás, hogy rétegesnek tűnjön
	part.Color = if index % 2 == 0 then Palette.Schnitzel else Palette.Gold
	part.Parent = folder
	return part
end

local function getTower(player: Player): Tower
	local tower = towers[player]
	if tower then
		return tower
	end

	local anchor = Instance.new("Part")
	anchor.Name = `StackLabel_{player.UserId}`
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Parent = folder

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(5, 1.1)
	label.StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0)
	label.LightInfluence = 0
	label.MaxDistance = 80
	label.Adornee = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Count"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Palette.Gold
	Ui.worldText(text)
	text.Parent = label
	label.Parent = anchor

	tower = { pieces = {}, label = label, count = 0 }
	towers[player] = tower
	return tower
end

local function removeTower(player: Player)
	local tower = towers[player]
	if not tower then
		return
	end
	for _, piece in tower.pieces do
		piece:Destroy()
	end
	if tower.label.Adornee then
		tower.label.Adornee:Destroy()
	end
	towers[player] = nil
end

local function update()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local carried = player:GetAttribute("Carried") or 0
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local wanted = if head then pieceCount(carried) else 0
		if player == Players.LocalPlayer and now < hiddenUntil then
			wanted = 0
		end

		if wanted == 0 then
			removeTower(player)
			continue
		end

		local tower = getTower(player)
		while #tower.pieces < wanted do
			table.insert(tower.pieces, newPiece(#tower.pieces + 1))
		end
		while #tower.pieces > wanted do
			(table.remove(tower.pieces) :: BasePart):Destroy()
		end

		-- a torony a fej felett, kicsit imbolyogva (a felső darabok jobban)
		local base = (head :: BasePart).CFrame * CFrame.new(0, (head :: BasePart).Size.Y / 2 + HEAD_OFFSET, 0)
		local upright = CFrame.new(base.Position) * CFrame.fromOrientation(0, select(2, base:ToOrientation()), 0)
		local top = upright
		for index, piece in tower.pieces do
			local sway = math.sin(now * 3 + index * 0.4) * 0.02 * index
			top = upright
				* CFrame.new(sway, (index - 1) * (PIECE_SIZE.Y + GAP), 0)
				* CFrame.Angles(0, index * 0.35, sway * 0.3)
			piece.CFrame = top
		end

		local anchor = tower.label.Adornee :: BasePart
		anchor.CFrame = top
		local countLabel = tower.label:FindFirstChild("Count") :: TextLabel
		countLabel.Text = `🥩 {NumberFormat.short(carried)}`
		-- a saját számunkat a HUD mutatja, a fej felett csak másoknak írjuk ki
		tower.label.Enabled = player ~= Players.LocalPlayer
	end

	for player in towers do
		if player.Parent ~= Players then
			removeTower(player)
		end
	end
end

-- Egy darab ívben átrepül start → target, majd eltűnik.
local function fly(start: CFrame, target: CFrame, delay: number)
	local part = newPiece(math.random(1, 2))
	part.CFrame = start
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(a)
		local position = start.Position:Lerp(target.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
		part.CFrame = CFrame.new(position) * start.Rotation:Lerp(target.Rotation, a)
	end)
	task.delay(delay, function()
		local tween = TweenService:Create(alpha, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = 1,
		})
		tween.Completed:Once(function()
			part:Destroy()
			alpha:Destroy()
		end)
		tween:Play()
	end)
end

-- "+n" felirat az asztal felett, felfelé úszva.
local function popup(at: CFrame, text: string)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = at
	anchor.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Palette.Money
	Ui.worldText(label)
	label.Parent = gui
	gui.Parent = anchor

	local info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	Ui.fadeText(label, info)
	task.delay(1.3 + FLY_TIME, function()
		anchor:Destroy()
	end)
end

local function onDeposited(plotIndex: number, units: number)
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(`Plot{plotIndex}`)
	local origin = plot and plot:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end

	local pad = Layout.Pads.Deposit
	local tableTop = origin * CFrame.new(pad.Position.X, Layout.FloorTop + (pad.Height or 0.3) + 0.3, pad.Position.Y)

	-- kiinduló pontok: a saját torony darabjai (ha épp nincs torony, a fej felett)
	local starts = {}
	local tower = towers[Players.LocalPlayer]
	if tower then
		for _, piece in tower.pieces do
			table.insert(starts, piece.CFrame)
		end
	end
	if #starts == 0 then
		local character = Players.LocalPlayer.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if head then
			for i = 1, math.min(pieceCount(units), FLY_MAX) do
				table.insert(starts, head.CFrame * CFrame.new(0, 1.2 + i * 0.3, 0))
			end
		end
	end

	hiddenUntil = os.clock() + HIDE_AFTER_DEPOSIT
	removeTower(Players.LocalPlayer)

	for i = 1, math.min(#starts, FLY_MAX) do
		local offset = CFrame.new((math.random() - 0.5) * pad.Size.X * 0.6, 0, (math.random() - 0.5) * pad.Size.Y * 0.6)
		fly(starts[#starts - i + 1], tableTop * offset, (i - 1) * FLY_STAGGER)
	end
	popup(tableTop, `+{NumberFormat.grouped(units)}`)
end

function StackController.init()
	folder = Instance.new("Folder")
	folder.Name = "SchnitzelStacks"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(update)
	Players.PlayerRemoving:Connect(removeTower)
	Remotes.Deposited.OnClientEvent:Connect(onDeposited)
end

return StackController
