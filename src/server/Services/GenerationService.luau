-- Sütő-generációk (GDD 3.7): az összes valaha vett sütő száma alapján nyílik a következő generáció.
-- A váltás a tábla előtti gombbal történik (döntés 2026-11-12); utána a "Vegyél" gombok eggyel
-- magasabb szintű sütőt adnak, drágábban (× GenerationPriceGrowth), és a generáción belüli ár újraindul.
-- Váltáskor minden, az új alapszint alatti sütő ingyen felfejlődik az új alapszintre (nem ragad be semmi).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Billboard = require(script.Parent.Parent.Lib.Billboard)
local PlotService = require(script.Parent.PlotService)

local Palette = Config.Palette

local GenerationService = {}

function GenerationService.isReady(raw: any): boolean
	local threshold = Formulas.nextGenerationThreshold(raw.generation)
	return threshold ~= nil and raw.ovensBought >= threshold
end

function GenerationService.upgrade(state: PlotService.PlotState): boolean
	local data = state.data
	local raw = data()
	if not GenerationService.isReady(raw) then
		return false
	end

	local generation = raw.generation + 1
	local base = Formulas.generationLevel(generation)

	-- az új alapszint alatti sütők felfejlődnek ("Lv 2 – Kempingfőző!" felirat a sütők felett)
	local levels = table.clone(raw.ovens)
	state.mergePops = state.mergePops or {}
	for slot, level in levels do
		if level > 0 and level < base then
			levels[slot] = base
			state.mergePops[slot] = base
		end
	end

	data.generation(generation)
	data.generationBought(0)
	data.ovens(levels)
	if raw.stats.highestOven < base then
		data.stats.highestOven(base)
	end

	state.generationPop = generation
	return true
end

local function showPop(state: PlotService.PlotState)
	local generation = state.generationPop
	if not generation then
		return
	end
	state.generationPop = nil

	local pad = state.plot.pads.GenUpgrade
	local labels = Billboard.new(pad, {
		offset = Vector3.new(0, 10, 0),
		size = Vector2.new(16, 3.6),
		maxDistance = 200,
		lines = {
			{ name = "Title", color = Palette.Lemon, height = 0.55 },
			{ name = "Info", color = Palette.White, height = 0.45 },
		},
	})
	local base = Formulas.generationLevel(generation)
	labels.Title.Text = `GEN {generation}!`
	labels.Info.Text = `Now buying Lv{base} ovens: {Formulas.levelInfo(base).Name}`
	local gui = labels.Title.Parent :: BillboardGui
	gui.Name = "GenerationPop"
	gui.AlwaysOnTop = true
	Debris:AddItem(gui, 3.5)
end

local function render(state: PlotService.PlotState, raw: any)
	local board = state.plot.generationBoard
	local pad = state.plot.pads.GenUpgrade
	local label = state.plot.labels.GenUpgrade

	local currentText = board.Current :: TextLabel
	local nextText = board.Next :: TextLabel

	local generation = raw.generation
	local base = Formulas.generationLevel(generation)
	local price = Formulas.ovenPrice(generation, raw.generationBought)
	currentText.Text = `Gen {generation}: Lv{base} ovens for {NumberFormat.money(price)}`

	local threshold = Formulas.nextGenerationThreshold(generation)
	local ready = GenerationService.isReady(raw)
	if threshold then
		local nextBase = Formulas.generationLevel(generation + 1)
		nextText.Text =
			`Next: Gen {generation + 1} (Lv{nextBase}), {NumberFormat.short(raw.ovensBought)} / {NumberFormat.short(threshold)} ovens`
		board.Fill.Size = UDim2.fromScale(math.clamp(raw.ovensBought / threshold, 0, 1), 1)

		label.Title.Text = if ready then "NEXT GENERATION!" else "Next Generation"
		label.Title.TextColor3 = if ready then Palette.Lemon else Palette.White
		label.Info.Text = if ready
			then `Step here → Lv{nextBase} ovens!`
			else `{NumberFormat.short(raw.ovensBought)} / {NumberFormat.short(threshold)} ovens`
		label.Info.TextColor3 = if ready then Palette.Money else Palette.White
	else
		nextText.Text = "Max generation reached!"
		board.Fill.Size = UDim2.fromScale(1, 1)
		label.Title.Text = `Gen {generation} (MAX)`
		label.Title.TextColor3 = Palette.Lemon
		label.Info.Text = ""
	end

	-- a gomb csak akkor világít, ha váltani lehet
	pad.Color = if ready then Palette.Lemon else Palette.Locked
	pad.Material = if ready then Enum.Material.Neon else Enum.Material.SmoothPlastic

	showPop(state)
end

function GenerationService.init()
	PlotService.registerPad("GenUpgrade", {
		enter = function(_player, state)
			GenerationService.upgrade(state)
		end,
	})
	PlotService.addRenderer(render)
end

return GenerationService
