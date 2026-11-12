--[[
	Balance szimulátor (GDD 4.4) – a játék saját Config + Formulas moduljaival számol.

	Egy "okos", aktív játékost futtat mp-ről mp-re, és kiírja, mikor éri el a GDD 4.3 mérföldköveit,
	mennyi a bevétele, és mennyit kellett várnia két vásárlás között (GDD 4.3 szabály).

	Futtatás a projekt mappájából:
		lune run tools/sim/simulate.luau -- [órák=8] [futások=5] [kapcsolók] [Config.útvonal=érték ...]
	Példa:
		lune run tools/sim/simulate.luau -- 8 5 Ovens.PriceGrowth=1.01 Rarities.List.5.UnitMult=100
	Kapcsolók:
		--no-rarity   ritkaságok nélkül (csak "Sima")
		--no-rebirth  nem rebirth-öl
		--no-pets     nem vesz tojást
		--verbose     futásonként is kiír mindent
		--gaps        az 1. futás leghosszabb várakozásai (mikor, mire várt)

	Az "okos játékos" szabályai:
	- a termelt schnitzel azonnal a pultra kerül (aktív játékos, a hordás ideje nincs számolva),
	  a pénzt azonnal felveszi;
	- mindig merge-el, ha van pár (az "A" modellben a merge mindig duplázza a termelést);
	- mindig a legjobb megtérülésű (ár / bevétel-növekedés) vásárlást választja: sütő, 100-as
	  "belevásárlás" (ha tele és nincs pár), eladó fejlesztés – és ha nincs rá pénze, kivár;
	- generációt vált, amint lehet; rebirth-öl, amint lehet, és a tokent rögtön perkre költi;
	- az első chefet megveszi, ha ≤ 60 mp bevétel (a chef az aktív szimulációban nem gyorsít);
	- tojást vesz, ha ≤ 120 mp bevétel (tojásonként max 6), és a 3 legjobb petet szereli fel.
	Nincs benne: eventek, aurák, Index bónusz, offline kereset (ezek csak gyorsítanak).
]]
local process = require("@lune/process")

local Loader = require("./loader")
local Config = Loader.require("src/shared/Config")
local Formulas = Loader.require("src/shared/Formulas")

-- argumentumok (a lune a "--" elválasztót is átadja – kihagyjuk)
-- "Útvonal=érték" alakban a Config bármely száma felülírható, pl. Ovens.PriceGrowth=1.01
-- vagy Rarities.List.5.UnitMult=100 (csak erre a futtatásra, a játék configja nem változik).
local numbers, flags, overrides = {}, {}, {}
for _, arg in process.args do
	if string.sub(arg, 1, 2) == "--" then
		if arg ~= "--" then
			flags[arg] = true
		end
	elseif string.find(arg, "=", 1, true) then
		local path, value = string.match(arg, "^([^=]+)=(.+)$")
		local target = Config
		local keys = string.split(path, ".")
		for i = 1, #keys - 1 do
			local key = tonumber(keys[i]) or keys[i]
			target = target[key]
			assert(target, `Ismeretlen Config útvonal: {path}`)
		end
		local last = tonumber(keys[#keys]) or keys[#keys]
		assert(target[last] ~= nil, `Ismeretlen Config kulcs: {path}`)
		local list = string.split(value, ",")
		if #list > 1 then
			local numbersList = {}
			for _, item in list do
				table.insert(numbersList, (assert(tonumber(item), `Nem szám: {item}`)))
			end
			target[last] = numbersList
		else
			target[last] = assert(tonumber(value), `Nem szám: {value}`)
		end
		table.insert(overrides, arg)
	elseif tonumber(arg) then
		table.insert(numbers, tonumber(arg))
	end
end
local hours = numbers[1] or 8
local runs = numbers[2] or 5

-- Seedelhető véletlengenerátor a Roblox Random helyett (a Formulas csak NextNumber-t használ).
-- xorshift32: futásonként ugyanaz a seed ugyanazt az eredményt adja.
local function newRandom(seed: number)
	local state = bit32.bor(seed, 1)
	local rng = {}
	function rng.NextNumber(_self, min: number?, max: number?): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		local value = state / 4294967296
		if min and max then
			return min + value * (max - min)
		end
		return value
	end
	return rng
end
local NO_RARITY = flags["--no-rarity"]
local NO_REBIRTH = flags["--no-rebirth"]
local NO_PETS = flags["--no-pets"]
local VERBOSE = flags["--verbose"]
local GAPS = flags["--gaps"]

local DURATION = math.floor(hours * 3600)
local MAX_SLOTS = Config.Ovens.MaxSlots

-- GDD 4.3 mérföldkövek és célidők (mp)
local MILESTONES = {
	{ key = "firstOven", name = "Első sütő", target = "0–10 mp" },
	{ key = "firstMerge", name = "Első merge", target = "30–45 mp" },
	{ key = "firstChef", name = "Első chef", target = "3–4 perc" },
	{ key = "lv5", name = "Lv5 sütő", target = "6–8 perc" },
	{ key = "firstEgg", name = "Első tojás", target = "8–10 perc" },
	{ key = "gen2", name = "Gen2 sütők", target = "15–20 perc" },
	{ key = "lv10", name = "Lv10 sütő", target = "–" },
	{ key = "rebirth1", name = "Rebirth 1", target = "40–60 perc" },
	{ key = "rebirth2", name = "Rebirth 2", target = "100–140 perc" },
	{ key = "rebirth5", name = "Rebirth 5", target = "6–8 óra" },
	{ key = "lv15", name = "Lv15 sütő", target = "–" },
	{ key = "firstStar", name = "Első csillag", target = "–" },
}
local SNAPSHOTS = { 60, 300, 600, 1800, 3600, 7200, 14400, 28800 }

local function fmtTime(seconds: number?): string
	if not seconds then
		return "–"
	end
	if seconds < 60 then
		return `{math.floor(seconds)} mp`
	elseif seconds < 3600 then
		return string.format("%d:%02d p", seconds // 60, seconds % 60)
	end
	return string.format("%d:%02d ó", seconds // 3600, (seconds % 3600) // 60)
end

local function money(n: number): string
	if n < 1000 then
		return "$" .. math.floor(n)
	end
	local suffixes = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
	local tier = math.min(math.floor(math.log10(n) / 3), #suffixes)
	return string.format("$%.2f%s", n / 10 ^ (3 * tier), suffixes[tier])
end

------------------------------------------------------------------------------------------------
-- Állapot (ugyanazok a mezőnevek, mint a mentésben, hogy a Formulas függvények működjenek)
------------------------------------------------------------------------------------------------
local function newState(rng)
	return {
		rng = rng,
		t = 0,
		money = Config.Game.StartMoney,
		ovens = table.create(MAX_SLOTS, 0),
		ovenStars = table.create(MAX_SLOTS, 0),
		bakeTimer = table.create(MAX_SLOTS, 0),
		slots = Config.Ovens.StartSlots,
		ovensBought = 0,
		generation = 1,
		generationBought = 0,
		upgrades = { sellSpeed = 0 },
		counter = { level = 1, xp = 0 },
		rebirths = 0,
		rebirthTokens = 0,
		rebirthPerks = { Money = 0, StartMoney = 0, StartChefs = 0, StartGeneration = 0, OfflineTime = 0, OfflineRate = 0 },
		chefs = { count = 0 },
		pets = { inventory = {}, equipped = {}, nextId = 1 },
		eggsBought = {},
		auras = { owned = {}, equipped = "", tickets = 0, ticketProgress = 0 },
		stock = 0,
		stockValue = 0,
		sellRemainder = 0,
		cycleEarned = 0,
		-- mérés
		milestones = {},
		snapshots = {},
		lastPurchase = 0,
		maxGapEarly = 0, -- leghosszabb várakozás vásárlások között az első 10 percben
		maxGapMid = 0, -- 10 perc után
		gaps = {}, -- { start, length, label } a --gaps riporthoz
		highest = 0,
		earned = 0,
		rareBakes = {},
	}
end

local function mark(s, key: string)
	if not s.milestones[key] then
		s.milestones[key] = s.t
	end
end

local function purchased(s, label: string?)
	local gap = s.t - s.lastPurchase
	if GAPS and gap >= 20 then
		table.insert(s.gaps, { start = s.lastPurchase, length = gap, label = label or "?" })
	end
	if s.t <= 600 then
		s.maxGapEarly = math.max(s.maxGapEarly, gap)
	else
		s.maxGapMid = math.max(s.maxGapMid, gap)
	end
	s.lastPurchase = s.t
end

local function income(s): number
	return Formulas.incomePerSecond(s)
end

local function updateHighest(s)
	for _, level in s.ovens do
		if level > s.highest then
			s.highest = level
		end
	end
	if s.highest >= 5 then
		mark(s, "lv5")
	end
	if s.highest >= 10 then
		mark(s, "lv10")
	end
	if s.highest >= 15 then
		mark(s, "lv15")
	end
end

local function mergeAll(s)
	local levels, count = Formulas.merge(s.ovens)
	if count > 0 then
		s.ovens = levels
		mark(s, "firstMerge")
		updateHighest(s)
	end
end

-- Bevétel-növekedés egy változtatás után (a változtatást visszaállítjuk).
local function gainOf(s, apply: () -> (), revert: () -> ()): number
	local before = income(s)
	apply()
	local after = income(s)
	revert()
	return after - before
end

------------------------------------------------------------------------------------------------
-- Vásárlási döntés: a legjobb megtérülésű opció, ha van rá pénz; különben kivár
------------------------------------------------------------------------------------------------
-- A termelés értéke ($/mp, szorzók nélkül, a pult korlátja nélkül) – a sütő-vásárlás haszna ezen mérve.
local function productionValue(s): number
	local _, value = Formulas.production(s.ovens, Formulas.bakeInterval(s), s.ovenStars)
	return value
end

-- Szűk keresztmetszet szerinti döntés (GDD 3.5, 4.4): ha a pult a lassabb (a termelés eléri az eladási
-- sebességet, vagy feltorlódott a készlet), az eladót fejleszti; különben a legjobb sütő-opciót veszi.
local function bestOption(s)
	local options = {}
	local base = Formulas.generationLevel(s.generation)
	local free = Formulas.firstFreeSlot(s.ovens, s.slots)
	local sellLevel = s.upgrades.sellSpeed
	local sellOption = { kind = "sell", price = Formulas.sellUpgradePrice(sellLevel), gain = 1 }

	local units = Formulas.production(s.ovens, Formulas.bakeInterval(s))
	local rate = Formulas.sellRate(sellLevel)
	if units >= rate or s.stock > rate * 15 then
		return sellOption
	end

	local function sutoGain(change: () -> ()): number
		local saved = table.clone(s.ovens)
		local before = productionValue(s)
		change()
		local after = productionValue(s)
		s.ovens = saved
		return after - before
	end

	if free then
		local price = Formulas.ovenPrice(s.generation, s.generationBought)
		local gain = sutoGain(function()
			s.ovens[free] = base
			s.ovens = (Formulas.merge(s.ovens))
		end)
		table.insert(options, { kind = "oven", price = price, gain = gain, slot = free })
	else
		-- tele, nincs pár: a 100-as gomb "belevásárlás" a legalacsonyabb sütőbe (annyit vesz, amennyi kell)
		local lowestSlot, lowest = Formulas.lowestOven(s.ovens, s.slots)
		if lowestSlot and lowest < Formulas.maxLevel() and lowest >= base then
			local needed = 2 ^ (lowest - base)
			local price = Formulas.ovenPriceSum(s.generation, s.generationBought, needed)
			local gain = sutoGain(function()
				s.ovens[lowestSlot] = lowest + 1
				s.ovens = (Formulas.merge(s.ovens))
			end)
			table.insert(options, { kind = "into", price = price, gain = gain, slot = lowestSlot, needed = needed, level = lowest })
		end

		-- minden sütő Lv15: csillag a legkevesebb csillagú sütőre
		local starSlot, stars = Formulas.starTarget(s.ovens, s.ovenStars, s.slots)
		if starSlot then
			local before = productionValue(s)
			s.ovenStars[starSlot] = stars + 1
			local gain = productionValue(s) - before
			s.ovenStars[starSlot] = stars
			table.insert(options, { kind = "star", price = Formulas.starPrice(s, stars), gain = gain, slot = starSlot, stars = stars })
		end
	end

	local best, bestPayback = nil, math.huge
	for _, option in options do
		if option.gain > 0 then
			local payback = option.price / option.gain
			if payback < bestPayback then
				best, bestPayback = option, payback
			end
		end
	end
	return best or sellOption
end

local function apply(s, option)
	s.money -= option.price
	local base = Formulas.generationLevel(s.generation)
	if option.kind == "oven" then
		s.ovens[option.slot] = base
		s.bakeTimer[option.slot] = s.rng:NextNumber() * Formulas.bakeInterval(s)
		s.ovensBought += 1
		s.generationBought += 1
		mark(s, "firstOven")
	elseif option.kind == "into" then
		s.ovens[option.slot] = option.level + 1
		s.ovensBought += option.needed
		s.generationBought += option.needed
		mark(s, "firstMerge")
	elseif option.kind == "star" then
		s.ovenStars[option.slot] = option.stars + 1
		mark(s, "firstStar")
	elseif option.kind == "sell" then
		s.upgrades.sellSpeed += 1
	end
	mergeAll(s)
	updateHighest(s)
	local label = if option.kind == "sell"
		then `eladó Lv{s.upgrades.sellSpeed} ({money(option.price)})`
		elseif option.kind == "into" then `100-as belevásárlás Lv{option.level}→{option.level + 1} ({money(option.price)})`
		elseif option.kind == "star" then `csillag {option.stars + 1}★ ({money(option.price)})`
		else `sütő Gen{s.generation} #{s.generationBought} ({money(option.price)})`
	purchased(s, `{label}, bevétel {money(income(s))}/mp, sütők: {table.concat(s.ovens, " ", 1, s.slots)} ★ {table.concat(s.ovenStars, "", 1, s.slots)}`)
end

local function spend(s)
	for _ = 1, 500 do
		local option = bestOption(s)
		if not option or s.money < option.price then
			return
		end
		apply(s, option)
	end
end

------------------------------------------------------------------------------------------------
-- Petek (egyszerűsítve): tojás ha ≤ 120 mp bevétel, tojásonként max 6; a 3 legjobb pet aktív
------------------------------------------------------------------------------------------------
local PET_WEIGHT = { Money = 1, BakeSpeed = 1, Luck = 0.3, ChefSpeed = 0 }

local function equipBest(s)
	local list = table.clone(s.pets.inventory)
	table.sort(list, function(a, b)
		local da, db = Config.Pets.List[a.id], Config.Pets.List[b.id]
		return da.Value * PET_WEIGHT[da.Bonus] > db.Value * PET_WEIGHT[db.Bonus]
	end)
	s.pets.equipped = {}
	for i = 1, math.min(Config.Pets.ActiveSlots, #list) do
		table.insert(s.pets.equipped, list[i].uid)
	end
end

local function buyEggs(s)
	if NO_PETS then
		return
	end
	local perSecond = income(s)
	for index = #Config.Pets.Eggs, 1, -1 do
		local egg = Config.Pets.Eggs[index]
		local bought = s.eggsBought[index] or 0
		if bought < 6 and egg.Price <= perSecond * 120 and s.money >= egg.Price then
			s.money -= egg.Price
			s.eggsBought[index] = bought + 1
			local id = Formulas.rollEgg(s.rng, index)
			table.insert(s.pets.inventory, { uid = s.pets.nextId, id = id, golden = false })
			s.pets.nextId += 1
			equipBest(s)
			mark(s, "firstEgg")
			purchased(s, `tojás {index} ({money(egg.Price)})`)
			return
		end
	end
end

------------------------------------------------------------------------------------------------
-- Generáció, rebirth, chef
------------------------------------------------------------------------------------------------
local PERK_PRIORITY = { "Money", "StartMoney", "StartGeneration", "StartChefs", "OfflineRate", "OfflineTime" }

local function progression(s)
	local threshold = Formulas.nextGenerationThreshold(s.generation)
	if threshold and s.ovensBought >= threshold then
		s.generation += 1
		s.generationBought = 0
		local base = Formulas.generationLevel(s.generation)
		for slot, level in s.ovens do
			if level > 0 and level < base then
				s.ovens[slot] = base
			end
		end
		if s.generation >= 2 then
			mark(s, "gen2")
		end
		mergeAll(s)
		updateHighest(s)
	end

	if not NO_REBIRTH and s.cycleEarned >= Formulas.rebirthRequirement(s.rebirths) then
		s.rebirths += 1
		s.rebirthTokens += Config.Rebirth.TokensPerRebirth
		mark(s, `rebirth{s.rebirths}`)
		-- tokenek perkre
		for _ = 1, 20 do
			local spent = false
			for _, perk in PERK_PRIORITY do
				local level = s.rebirthPerks[perk]
				if s.rebirthTokens >= Config.Rebirth.Tree.TokenCost and level < Config.Rebirth.Tree.Perks[perk].Max then
					s.rebirthPerks[perk] = level + 1
					s.rebirthTokens -= Config.Rebirth.Tree.TokenCost
					spent = true
					break
				end
			end
			if not spent then
				break
			end
		end
		-- nullázás (RebirthService szerint)
		s.slots = math.max(s.slots, Formulas.rebirthSlots(s.rebirths))
		s.money = Config.Game.StartMoney * Formulas.perkValue(s, "StartMoney")
		s.ovens = table.create(MAX_SLOTS, 0)
		s.ovenStars = table.create(MAX_SLOTS, 0)
		s.ovensBought = 0
		s.generation = math.min(1 + Formulas.perkValue(s, "StartGeneration"), Formulas.maxGeneration())
		s.generationBought = 0
		s.upgrades.sellSpeed = 0
		s.counter = { level = 1, xp = 0 }
		s.chefs = { count = math.min(Formulas.perkValue(s, "StartChefs"), Formulas.maxChefs(s.rebirths)) }
		s.stock, s.stockValue, s.sellRemainder = 0, 0, 0
		s.cycleEarned = 0
		s.highest = 0
	end

	if s.chefs.count == 0 then
		local price = Formulas.chefHirePrice(0)
		if s.money >= price and price <= income(s) * 60 then
			s.money -= price
			s.chefs.count = 1
			mark(s, "firstChef")
			purchased(s, `első chef ({money(price)})`)
		end
	elseif s.chefs.count > 0 then
		mark(s, "firstChef")
	end
end

------------------------------------------------------------------------------------------------
-- Egy másodperc: sütés → pult → eladás → pult XP
------------------------------------------------------------------------------------------------
local function bake(s)
	local interval = Formulas.bakeInterval(s)
	local luck = 1 + Formulas.boosts(s).Luck
	for slot = 1, MAX_SLOTS do
		local level = s.ovens[slot]
		if level > 0 then
			s.bakeTimer[slot] += 1
			while s.bakeTimer[slot] >= interval do
				s.bakeTimer[slot] -= interval
				local rarity = if NO_RARITY then 1 else Formulas.rollRarity(s.rng, luck)
				local units, value = Formulas.bakeResult(level, rarity)
				value *= Formulas.starMultiplier(level, s.ovenStars[slot])
				s.stock += units
				s.stockValue += value
				if rarity > 1 then
					s.rareBakes[rarity] = (s.rareBakes[rarity] or 0) + 1
				end
			end
		end
	end
end

local function sell(s)
	if s.stock <= 0 then
		s.sellRemainder = 0
		return
	end
	local budget = Formulas.sellRate(s.upgrades.sellSpeed) + s.sellRemainder
	local amount = math.min(s.stock, math.floor(budget))
	if amount <= 0 then
		s.sellRemainder = budget
		return
	end
	s.sellRemainder = if amount < s.stock then budget - amount else 0
	local baseValue = if amount >= s.stock then s.stockValue else s.stockValue * amount / s.stock
	local earned = baseValue * Formulas.moneyMultiplier(s)
	s.stock -= amount
	s.stockValue = math.max(0, s.stockValue - baseValue)
	s.money += earned
	s.earned += earned
	s.cycleEarned += earned

	-- pult XP (SellService.addCounterXp)
	local level = s.counter.level
	local xp = s.counter.xp + amount
	local oldLevel = level
	while xp >= Formulas.counterXpNeeded(level) do
		xp -= Formulas.counterXpNeeded(level)
		level += 1
	end
	s.counter.xp = xp
	if level ~= oldLevel then
		s.counter.level = level
		local bonus = income(s) * Config.Sell.Counter.LevelUpIncomeSeconds * (level - oldLevel)
		s.money += math.max(math.floor(bonus), Config.Sell.UnitPrice * 10)
	end
end

local function simulate(seed: number)
	local s = newState(newRandom(seed))
	local nextSnapshot = 1
	while s.t < DURATION do
		s.t += 1
		bake(s)
		sell(s)
		progression(s)
		buyEggs(s)
		spend(s)
		if SNAPSHOTS[nextSnapshot] and s.t >= SNAPSHOTS[nextSnapshot] then
			table.insert(s.snapshots, {
				t = s.t,
				income = income(s),
				money = s.money,
				highest = s.highest,
				generation = s.generation,
				rebirths = s.rebirths,
				counter = s.counter.level,
				sell = Formulas.sellRate(s.upgrades.sellSpeed),
				earned = s.earned,
			})
			nextSnapshot += 1
		end
	end
	return s
end

------------------------------------------------------------------------------------------------
-- Futtatás + riport
------------------------------------------------------------------------------------------------
local function median(list: { number }): number?
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

local function pad(text: string, width: number): string
	local length = utf8.len(text) or #text
	return text .. string.rep(" ", math.max(0, width - length))
end

print(`\n=== Sell a Schnitzel – balance szimuláció ({hours} óra, {runs} futás) ===`)
local active = {}
for flag in flags do
	table.insert(active, flag)
end
if #active > 0 then
	print("Kapcsolók: " .. table.concat(active, " "))
end
if #overrides > 0 then
	print("Felülírt Config értékek: " .. table.concat(overrides, "  "))
end

local results = {}
for run = 1, runs do
	local s = simulate(run * 7919)
	table.insert(results, s)
	if VERBOSE then
		print(`\n-- {run}. futás --`)
		for _, milestone in MILESTONES do
			print(`  {pad(milestone.name, 14)} {fmtTime(s.milestones[milestone.key])}`)
		end
	end
end

print("\nMérföldkövek (GDD 4.3) – medián, [min – max]:")
print(`  {pad("Mérföldkő", 14)} {pad("Medián", 10)} {pad("Tartomány", 22)} Cél`)
for _, milestone in MILESTONES do
	local times = {}
	for _, s in results do
		local t = s.milestones[milestone.key]
		if t then
			table.insert(times, t)
		end
	end
	local reached = `{#times}/{#results}`
	local range = if #times > 0
		then `{fmtTime(math.min(table.unpack(times)))} – {fmtTime(math.max(table.unpack(times)))}`
		else "nem érte el"
	print(`  {pad(milestone.name, 14)} {pad(fmtTime(median(times)), 10)} {pad(range .. " (" .. reached .. ")", 22)} {milestone.target}`)
end

print("\nBevétel / állapot (medián):")
print(`  {pad("Idő", 8)} {pad("Bevétel/mp", 12)} {pad("Össz. kereset", 14)} {pad("Pénz", 11)} {pad("Max sütő", 9)} {pad("Gen", 4)} {pad("Rebirth", 8)} {pad("Pult Lv", 8)} Eladás db/mp`)
for index, t in SNAPSHOTS do
	if t > DURATION then
		break
	end
	local function med(field: string): number
		local values = {}
		for _, s in results do
			local snap = s.snapshots[index]
			if snap then
				table.insert(values, snap[field])
			end
		end
		return median(values) or 0
	end
	print(
		`  {pad(fmtTime(t), 8)} {pad(money(med("income")), 12)} {pad(money(med("earned")), 14)} {pad(money(med("money")), 11)} {pad("Lv" .. med("highest"), 9)} {pad(tostring(med("generation")), 4)} {pad(tostring(med("rebirths")), 8)} {pad(tostring(med("counter")), 8)} {med("sell")}`
	)
end

local early, mid = {}, {}
for _, s in results do
	table.insert(early, s.maxGapEarly)
	table.insert(mid, s.maxGapMid)
end
print("\nLeghosszabb várakozás két vásárlás között (GDD 4.3 szabály):")
print(`  első 10 perc: {fmtTime(median(early))}   (cél: ~30 mp)`)
print(`  10 perc után: {fmtTime(median(mid))}   (cél: 2–3 perc, max ~5 perc)`)

if GAPS then
	local s = results[1]
	local starPrices = {}
	for k = 0, Config.Ovens.Stars.Max - 1 do
		table.insert(starPrices, money(Formulas.starPrice(s, k)))
	end
	print(
		`\nA futás végén: bevétel {money(income(s))}/mp, pénzszorzó {string.format("%.1f", Formulas.moneyMultiplier(s))}×,`
			.. ` ritkaság-átlag {string.format("%.2f", Formulas.rarityValueMultiplier(1 + Formulas.boosts(s).Luck))}×,`
			.. ` csillagárak: {table.concat(starPrices, " / ")}`
	)
	print("\nAz 1. futás várakozásai az első 10 percben (≥ 20 mp; kezdete → hossz: amit utána vett):")
	for _, gap in s.gaps do
		if gap.start < 600 then
			print(`  {pad(fmtTime(gap.start), 8)} → {pad(fmtTime(gap.length), 8)} {gap.label}`)
		end
	end
	local sorted = table.clone(s.gaps)
	table.sort(sorted, function(a, b)
		return a.length > b.length
	end)
	print("Leghosszabb várakozások:")
	for i = 1, math.min(10, #sorted) do
		local gap = sorted[i]
		print(`  {pad(fmtTime(gap.start), 8)} → {pad(fmtTime(gap.length), 8)} {gap.label}`)
	end
end

if not NO_RARITY then
	local names = {}
	for index, rarity in Config.Rarities.List do
		if index > 1 then
			local counts = {}
			for _, s in results do
				table.insert(counts, s.rareBakes[index] or 0)
			end
			table.insert(names, `{rarity.Name}: {median(counts)}`)
		end
	end
	print("\nRitka sütések futásonként (medián): " .. table.concat(names, " · "))
end
print("")
