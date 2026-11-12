-- Sütők: vásárlás, merge, sütés tick (GDD 3.2, 3.3, 4.1, 12.1 OvenService).
-- A schnitzelek a szerveren csak számok (GDD 12.2); a szalagon guruló darabok kliens vizuálok.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Billboard = require(script.Parent.Parent.Lib.Billboard)
local PlotService = require(script.Parent.PlotService)
local IndexService = require(script.Parent.IndexService)

local Palette = Config.Palette
local Layout = Config.Plot

local BAKE_POLL = 0.1
local MERGE_POP_TIME = 1.8

local rng = Random.new()

local OvenService = {}

-- Megvett sütők könyvelése: az összes (generáció küszöb) és az aktuális generációban vett (ár).
local function countBought(state: PlotService.PlotState, amount: number)
	local data = state.data
	local raw = data()
	data.ovensBought(raw.ovensBought + amount)
	data.generationBought(raw.generationBought + amount)
end

-- Sütő vásárlás: a legalacsonyabb szabad slotra, a generáció alapszintjén (GDD 3.2, 3.7).
-- Annyit vesz, amennyi hely és pénz van (döntés 2026-11-12).
-- autoMerge: ha megtelik a sor, merge-el és folytatja (csak a 100-as gomb). Ha tele van és pár
-- sincs (minden sütő más szintű), a legalacsonyabb sütőbe "vesz bele" – így sosem akad el a játék.
function OvenService.buy(state: PlotService.PlotState, count: number, autoMerge: boolean?): number
	local data = state.data
	local raw = data()
	local bought = 0
	local level = Formulas.generationLevel(raw.generation)

	while bought < count do
		local slot = Formulas.firstFreeSlot(raw.ovens, raw.slots)
		if not slot and autoMerge and OvenService.mergeAll(state) > 0 then
			slot = Formulas.firstFreeSlot(raw.ovens, raw.slots)
		end

		if slot then
			local price = Formulas.ovenPrice(raw.generation, raw.generationBought)
			if raw.money < price then
				break
			end
			data.money(raw.money - price)
			data.ovens[slot](level)
			countBought(state, 1)
			if raw.stats.highestOven < level then
				data.stats.highestOven(level)
			end
			bought += 1
		elseif autoMerge then
			local used = OvenService.buyIntoLowest(state, count - bought)
			if used == 0 then
				break
			end
			bought += used
		else
			break
		end
	end

	return bought
end

-- Tele sor, nincs pár: egyszerre annyi alapszintű sütőt vesz, amennyiből összeáll a legalacsonyabb
-- sütő szintje (Lv k-hoz 2^(k - alapszint) darab), és rögtön összevonja vele (szabad slot nélkül),
-- majd kaszkád merge. Csak akkor vásárol, ha belefér a keretbe (`budget` darab) és van rá pénz.
-- Visszaad: megvett darab.
function OvenService.buyIntoLowest(state: PlotService.PlotState, budget: number): number
	local data = state.data
	local raw = data()
	local base = Formulas.generationLevel(raw.generation)

	local lowestSlot, lowest = nil, math.huge
	for slot = 1, raw.slots do
		local level = raw.ovens[slot] or 0
		if level > 0 and level < lowest then
			lowestSlot, lowest = slot, level
		end
	end
	if not lowestSlot or lowest >= Formulas.maxLevel() or lowest < base then
		return 0
	end

	local needed = 2 ^ (lowest - base)
	if needed > budget then
		return 0
	end
	local price = Formulas.ovenPriceSum(raw.generation, raw.generationBought, needed)
	if raw.money < price then
		return 0
	end

	data.money(raw.money - price)
	countBought(state, needed)
	data.ovens[lowestSlot](lowest + 1)
	data.stats.merges(raw.stats.merges + 1)
	data.stats.highestOven(math.max(raw.stats.highestOven, lowest + 1))
	state.mergePops = state.mergePops or {}
	state.mergePops[lowestSlot] = lowest + 1

	OvenService.mergeAll(state) -- kaszkád: ha így pár keletkezett, tovább görget
	return needed
end

-- Merge: minden lehetséges pár összevonódik, alulról felfelé kaszkádban (GDD 3.3).
function OvenService.mergeAll(state: PlotService.PlotState): number
	local data = state.data
	local raw = data()
	local levels, count, merges = Formulas.merge(raw.ovens)
	if count == 0 then
		return 0
	end

	-- "Lv 7 – Ipari Fritőz!" felirat a végső szinttel minden érintett slotnál (a teljes anim a 10. fejezetben)
	state.mergePops = state.mergePops or {}
	for _, merge in merges do
		if levels[merge.slot] == merge.level then
			state.mergePops[merge.slot] = merge.level
		end
	end

	local highest = raw.stats.highestOven
	for _, level in levels do
		highest = math.max(highest, level)
	end

	data.ovens(levels)
	data.stats.merges(raw.stats.merges + count)
	data.stats.highestOven(highest)
	return count
end

local function buildOven(state: PlotService.PlotState, slot: number, level: number): BasePart
	local info = Formulas.levelInfo(level)
	local size = Layout.Ovens.Size

	local oven = Instance.new("Part")
	oven.Name = `Oven{slot}`
	oven.Anchored = true
	oven.Size = size
	oven.CFrame = state.plot.origin * Formulas.slotCFrame(slot) * CFrame.new(0, size.Y / 2, 0)
	oven.Color = info.Color
	oven.Material = if level >= 13 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	oven.TopSurface = Enum.SurfaceType.Smooth
	oven:SetAttribute("Slot", slot)
	oven:SetAttribute("Level", level)

	-- Sütőajtó (az eleje jól látszódjon)
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Anchored = true
	door.CanCollide = false
	door.Size = Vector3.new(size.X * 0.7, size.Y * 0.45, 0.2)
	door.CFrame = oven.CFrame * CFrame.new(0, -size.Y * 0.1, size.Z / 2 + 0.1)
	door.Color = Color3.fromRGB(40, 30, 25)
	door.Material = Enum.Material.Glass
	door.Parent = oven

	-- GDD 3.1 / 9.5: név + szint + progress bar a sütő felett
	local labels = Billboard.new(oven, {
		offset = Vector3.new(0, size.Y / 2 + 2.2, 0),
		size = Vector2.new(5.6, 2.4),
		maxDistance = 90,
		lines = {
			{ name = "Name", height = 0.45 },
			{ name = "Level", color = Palette.Lemon, height = 0.35 },
		},
	})
	labels.Name.Text = info.Name
	labels.Level.Text = `Lv {level}`

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.LayoutOrder = 3
	bar.Size = UDim2.fromScale(0.8, 0.12)
	bar.BackgroundColor3 = Palette.Panel
	bar.BorderSizePixel = 0
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Palette.Gold
	fill.BorderSizePixel = 0
	fill.Parent = bar
	bar.Parent = labels.Name.Parent

	oven.Parent = state.plot.ovens
	return oven
end

local function syncOvens(state: PlotService.PlotState, raw: any)
	state.ovenParts = state.ovenParts or {}
	for slot = 1, Config.Ovens.MaxSlots do
		local level = raw.ovens[slot] or 0
		local existing = state.ovenParts[slot]
		if existing and existing:GetAttribute("Level") == level then
			continue
		end
		if existing then
			existing:Destroy()
			state.ovenParts[slot] = nil
		end
		if level > 0 then
			state.ovenParts[slot] = buildOven(state, slot, level)
		end
	end
end

local function showMergePops(state: PlotService.PlotState)
	local pops = state.mergePops
	if not pops then
		return
	end
	state.mergePops = nil
	for slot, level in pops do
		local oven = state.ovenParts and state.ovenParts[slot]
		if not oven then
			continue
		end
		local labels = Billboard.new(oven, {
			offset = Vector3.new(0, Layout.Ovens.Size.Y / 2 + 5.5, 0),
			size = Vector2.new(9, 1.6),
			maxDistance = 120,
			lines = { { name = "Text", color = Palette.Lemon, height = 1 } },
		})
		labels.Text.Text = `Lv {level} – {Formulas.levelInfo(level).Name}!`
		local gui = labels.Text.Parent :: BillboardGui
		gui.Name = "MergePop"
		gui.AlwaysOnTop = true
		Debris:AddItem(gui, MERGE_POP_TIME)
	end
end

local function render(state: PlotService.PlotState, raw: any)
	syncOvens(state, raw)
	showMergePops(state)

	-- a kliens ebből számolja a progress bart és a szalag vizuált (pet "Sütés" bónusszal rövidebb)
	state.plot.model:SetAttribute("BakeInterval", Formulas.bakeInterval(raw))

	for slot, marker in state.plot.slotMarkers do
		marker.Transparency = if slot <= raw.slots then 0 else 1
	end

	local labels = state.plot.labels
	local hasFree = Formulas.firstFreeSlot(raw.ovens, raw.slots) ~= nil
	local _, merges = Formulas.merge(raw.ovens)

	-- Vásárló gombok: teljes ár; piros, ha nincs rá elég pénz (GDD 9.5)
	for key, pad in Layout.Pads do
		local count = pad.BuyCount
		if not count then
			continue
		end
		local label = labels[key]
		local price = Formulas.ovenPriceSum(raw.generation, raw.generationBought, count)
		-- GDD 3.2: ha tele a sor, a gomb piros → "Merge-elj!" (az Auto Merge gomb sosem akad el)
		local full = not hasFree and not pad.AutoMerge
		label.Title.Text = if full then "TELE! Merge-elj!" else pad.Title
		label.Title.TextColor3 = if full then Palette.Danger else Palette.White
		label.Info.Text = NumberFormat.money(price)
		label.Info.TextColor3 = if not full and raw.money >= price then Palette.Money else Palette.Danger
	end

	labels.Merge.Info.Text = if merges > 0 then `{merges} összevonás` else "nincs pár"
	labels.Merge.Info.TextColor3 = if merges > 0 then Palette.Lemon else Palette.White
end

-- A szalagon lévő sütések akkor kerülnek a collectorba, amikor odaérnek
-- (ugyanakkor, amikor a kliens vizuálja), így a halom és a felvétel szinkronban van.
local function deliverArrived(state: PlotService.PlotState, now: number)
	local pending = state.pending
	if not pending or #pending == 0 then
		return
	end

	local raw = state.data()
	local tray = raw.tray
	local count, units, value = 0, 0, 0
	local rarityCount = table.clone(tray.rarityCount)
	local rarityUnits = table.clone(tray.rarityUnits)
	local rarityValue = table.clone(tray.rarityValue)

	for i = #pending, 1, -1 do
		local bake = pending[i]
		if bake.arriveAt <= now then
			count += 1
			units += bake.units
			value += bake.value
			rarityCount[bake.rarity] += 1
			rarityUnits[bake.rarity] += bake.units
			rarityValue[bake.rarity] += bake.value
			table.remove(pending, i)
		end
	end

	if count > 0 then
		local trayValue = state.data.tray
		trayValue.count(tray.count + count)
		trayValue.units(tray.units + units)
		trayValue.value(tray.value + value)
		trayValue.rarityCount(rarityCount)
		trayValue.rarityUnits(rarityUnits)
		trayValue.rarityValue(rarityValue)
	end
end

-- Sütés: minden sütő BakeInterval mp-enként süt; a sütés a szalagon a collectorba gurul (nincs korlát).
local function bakeTick()
	local now = workspace:GetServerTimeNow()

	-- GDD 3.12 eventek: Áramszünet (nem süt), Arany Olaj (arany esély x5), Nagyi Látogatás (+1 szint)
	local event = EventState.config()
	local blackout = EventState.is("Blackout")
	local chanceMultipliers = if event then event.RarityChanceMultipliers else nil
	local levelBonus = if event then event.OvenLevelBonus or 0 else 0

	for player, state in PlotService.all() do
		local raw = state.data()
		state.lastCycle = state.lastCycle or {}
		state.pending = state.pending or {}

		-- GDD 3.9: pet bónuszok (sütési sebesség, szerencse)
		local interval = Formulas.bakeInterval(raw)
		local luck = 1 + Formulas.boosts(raw).Luck

		for slot = 1, Config.Ovens.MaxSlots do
			local level = raw.ovens[slot] or 0
			if level <= 0 then
				state.lastCycle[slot] = nil
				continue
			end
			local cycle = Formulas.bakeCycle(now, slot, interval)
			local last = state.lastCycle[slot]
			state.lastCycle[slot] = cycle
			-- (ha a sütési idő változik, a ciklus-sorszám ugrik: csak előre ugrásnál süt egyet)
			if last and cycle > last and not blackout then
				-- GDD 3.4: minden sütés kap egy ritkaság-dobást
				local rarityIndex = Formulas.rollRarity(rng, luck, chanceMultipliers)
				local bakeLevel = math.min(level + levelBonus, Formulas.maxLevel())
				local units, value = Formulas.bakeResult(bakeLevel, rarityIndex)
				table.insert(state.pending, {
					arriveAt = now + Formulas.travelTime(slot),
					units = units,
					value = value,
					rarity = rarityIndex,
				})

				IndexService.discoverRarity(player, rarityIndex)
				if rarityIndex > 1 then
					Remotes.RareBake:FireAllClients(state.plot.index, slot, rarityIndex, player.DisplayName)
				end
			end
		end

		deliverArrived(state, now)
	end
end

function OvenService.init()
	for key, pad in Layout.Pads do
		local count = pad.BuyCount
		if count then
			local autoMerge = pad.AutoMerge == true
			PlotService.registerPad(key, {
				enter = function(_player, state)
					OvenService.buy(state, count, autoMerge)
				end,
			})
		end
	end
	PlotService.registerPad("Merge", {
		enter = function(_player, state)
			OvenService.mergeAll(state)
		end,
	})
	PlotService.addRenderer(render)
end

function OvenService.start()
	task.spawn(function()
		while true do
			task.wait(BAKE_POLL)
			bakeTick()
		end
	end)
end

return OvenService
