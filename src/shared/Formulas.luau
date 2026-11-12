-- GDD 4.1: ár / termelés képletek. A kliens is látja (megjelenítéshez).
local Config = require(script.Parent.Config)

local Ovens = Config.Ovens
local Sell = Config.Sell
local PlotConfig = Config.Plot

local Formulas = {}

-- Sütő ára, ha eddig `bought` darabot vettél (az aktuális generációban).
-- Sütő ára a `generation`-ben, ha abban a generációban eddig `bought` darabot vettél (GDD 4.1).
-- ár = alapár_gen × PriceGrowth^n × (1 + n / PriceScale)^PricePower
-- (PricePower = 0 → csak az exponenciális rész, a GDD 4.1 eredeti képlete)
function Formulas.ovenPrice(generation: number, bought: number): number
	local base = Ovens.BasePrice * Ovens.GenerationPriceGrowth ^ (generation - 1)
	local polynomial = (1 + bought / Ovens.PriceScale) ^ Ovens.PricePower
	return math.floor(base * Ovens.PriceGrowth ^ bought * polynomial + 0.5)
end

-- `count` darab sütő összára egymás után (GDD 4.1: "Vegyél 15/100" összeg = Σ ár).
function Formulas.ovenPriceSum(generation: number, bought: number, count: number): number
	local total = 0
	for i = 0, count - 1 do
		total += Formulas.ovenPrice(generation, bought + i)
	end
	return total
end

-- GDD 3.7: a generáció alapszintje (a "Vegyél" gombok ilyen szintű sütőt adnak).
function Formulas.generationLevel(generation: number): number
	return generation
end

function Formulas.maxGeneration(): number
	return #Ovens.GenerationThresholds + 1
end

-- A következő generációhoz szükséges összes vett sütő (nil, ha már a maximumon vagy).
function Formulas.nextGenerationThreshold(generation: number): number?
	return Ovens.GenerationThresholds[generation]
end

-- Egy Lv(level) sütés ennyi darab schnitzelt ad.
function Formulas.schnitzelUnits(level: number): number
	return math.max(1, math.floor(Ovens.UnitGrowth ^ (level - 1) + 0.5))
end

-- Egy Lv(level) darab alapértéke $-ban (szorzók nélkül).
function Formulas.unitValue(level: number): number
	return Sell.UnitPrice * Ovens.ValueGrowth ^ (level - 1)
end

-- Egy Lv(level) sütés teljes értéke $-ban (darab × ár).
function Formulas.batchValue(level: number): number
	return Formulas.schnitzelUnits(level) * Formulas.unitValue(level)
end

-- Ritkaság-dobás egy sütésre (GDD 3.4). luck: esély-szorzó (gamepass, pet, boost – később),
-- a "Sima" kivételével minden esélyt szoroz. Visszaad: a ritkaság indexe a Config.Rarities.List-ben.
-- chanceMultipliers: ritkaságonkénti extra szorzó (pl. Arany Olaj event: { [3] = 5 }).
function Formulas.rollRarity(rng: Random, luck: number?, chanceMultipliers: { [number]: number }?): number
	local list = Config.Rarities.List
	local roll = rng:NextNumber()
	local accumulated = 0
	for index = #list, 2, -1 do
		local extra = if chanceMultipliers then chanceMultipliers[index] or 1 else 1
		accumulated += list[index].Chance * (luck or 1) * extra
		if roll < accumulated then
			return index
		end
	end
	return 1
end

-- A ritkaság-dobás várható érték-szorzója egy sütésre (Sima = 1×) az adott szerencsével.
function Formulas.rarityValueMultiplier(luck: number?): number
	local list = Config.Rarities.List
	local expected, rareChance = 0, 0
	for index = 2, #list do
		local chance = list[index].Chance * (luck or 1)
		rareChance += chance
		expected += chance * list[index].UnitMult * list[index].ValueMult
	end
	return expected + math.max(0, 1 - rareChance)
end

-- Egy sütés darabszáma és értéke ritkasággal együtt.
function Formulas.bakeResult(level: number, rarityIndex: number): (number, number)
	local rarity = Config.Rarities.List[rarityIndex]
	local units = Formulas.schnitzelUnits(level) * rarity.UnitMult
	local value = units * Formulas.unitValue(level) * rarity.ValueMult
	return units, value
end

function Formulas.levelInfo(level: number)
	return Ovens.Levels[level]
end

function Formulas.maxLevel(): number
	return #Ovens.Levels
end

-- Sütési ciklus egy slotra a szerveridő alapján. A szerver és a kliens
-- ugyanezt számolja, így a progress bar és a szalag vizuál hálózat nélkül szinkronban van.
-- Visszaad: ciklus sorszáma, progress (0..1).
-- interval: sütési idő (mp), alapból Ovens.BakeInterval (pet bónusszal rövidebb, lásd bakeInterval).
function Formulas.bakeCycle(serverTime: number, slot: number, interval: number?): (number, number)
	local t = serverTime / (interval or Ovens.BakeInterval) + (slot - 1) / Ovens.MaxSlots
	local cycle = math.floor(t)
	return cycle, t - cycle
end

-- Eladás (db/mp) az eladási fejlesztés szintjén, mindig egész szám.
-- Szintenként legalább +1 db/mp, később +25% (amelyik a nagyobb): 1, 2, 3 ... 12, 14, 18, 22, 28 ...
function Formulas.sellRate(upgradeLevel: number): number
	return math.max(Sell.BaseRate + upgradeLevel, math.floor(Sell.BaseRate * Sell.RateGrowth ^ upgradeLevel))
end

function Formulas.sellUpgradePrice(upgradeLevel: number): number
	return math.floor(Sell.UpgradeBasePrice * Sell.UpgradePriceGrowth ^ upgradeLevel + 0.5)
end

-- Chef: a következő (+1) chef ára, ha már `count` chefed van (GDD 4.1).
function Formulas.chefHirePrice(count: number): number
	local chefs = Config.Chefs
	if count <= 0 then
		return chefs.FirstPrice
	end
	return math.floor(chefs.HireBase * chefs.HireGrowth ^ (count - 1) + 0.5)
end

-- Chef stat értéke a fejlesztési szinten (Stack / Speed / Stamina / AntiSleep).
function Formulas.chefStat(stat: string, level: number): number
	local s = Config.Chefs.Stats[stat]
	return math.min(s.Max, s.Start + s.Step * level)
end

-- Elérte-e a stat a maximumot (tovább nem fejleszthető).
function Formulas.chefStatMaxed(stat: string, level: number): boolean
	local s = Config.Chefs.Stats[stat]
	return s.Start + s.Step * level >= s.Max - 1e-9
end

function Formulas.chefStatPrice(stat: string, level: number): number
	local s = Config.Chefs.Stats[stat]
	return math.floor(s.PriceBase * s.PriceGrowth ^ level + 0.5)
end

-- GDD 3.9: tojás dobás – súlyozott véletlen pet a tojás listájából. Visszaad: pet id.
function Formulas.rollEgg(rng: Random, eggIndex: number): string?
	local egg = Config.Pets.Eggs[eggIndex]
	if not egg then
		return nil
	end
	local total = 0
	for _, entry in egg.Pets do
		total += entry[2]
	end
	local roll = rng:NextNumber() * total
	for _, entry in egg.Pets do
		roll -= entry[2]
		if roll < 0 then
			return entry[1]
		end
	end
	return egg.Pets[#egg.Pets][1]
end

-- Pult: ennyi XP kell a `level` → `level + 1` szintlépéshez.
function Formulas.counterXpNeeded(level: number): number
	local counter = Sell.Counter
	return math.floor(counter.XpBase * counter.XpGrowth ^ (level - 1) + 0.5)
end

-- Pult: tartós árbónusz a szintből (Lv1 = x1, Lv2 = x1.02 ...).
function Formulas.counterPriceMultiplier(level: number): number
	return 1 + Sell.Counter.PriceBonusPerLevel * (level - 1)
end

-- Pult: vendégsor hossza a szintből.
function Formulas.customerCount(level: number): number
	local counter = Sell.Counter
	return math.min(counter.MaxCustomers, counter.BaseCustomers + (level - 1) // counter.LevelsPerCustomer)
end

-- GDD 3.8: a következő (rebirths + 1.) rebirth követelménye: ennyi pénzt kell keresni az utolsó rebirth óta.
function Formulas.rebirthRequirement(rebirths: number): number
	local list = Config.Rebirth.Requirements
	local index = rebirths + 1
	if index <= #list then
		return list[index]
	end
	return list[#list] * Config.Rebirth.RequirementGrowth ^ (index - #list)
end

-- Rebirth pénzszorzó: x(1 + rebirthek száma).
function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths
end

-- Feloldott sütő slotok a rebirthek számából.
function Formulas.rebirthSlots(rebirths: number): number
	local rebirth = Config.Rebirth
	return math.min(
		Ovens.MaxSlots,
		Ovens.StartSlots + rebirth.SlotsPerRebirth * math.min(rebirths, rebirth.SlotRebirths)
	)
end

-- Max chefek száma (alap + rebirth bónuszok).
function Formulas.maxChefs(rebirths: number): number
	local max = Config.Chefs.MaxChefs
	for required, bonus in Config.Rebirth.ChefBonus do
		if rebirths >= required then
			max += bonus
		end
	end
	return max
end

-- Eladáskori pénzszorzó: pult szint × rebirth. Később: pet, gamepass, event (GDD 4.1).
function Formulas.moneyMultiplier(data: any): number
	return Formulas.counterPriceMultiplier(data.counter.level)
		* Formulas.rebirthMultiplier(data.rebirths)
		* (1 + Formulas.boosts(data).Money)
		* (1 + Formulas.perkValue(data, "Money"))
end

-- Rebirth-fa: egy perk teljes hatása (szint × lépés). A "StartMoney" szorzó: 10^szint.
function Formulas.perkLevel(data: any, perk: string): number
	local perks = data.rebirthPerks
	return if perks then perks[perk] or 0 else 0
end

function Formulas.perkValue(data: any, perk: string): number
	local definition = Config.Rebirth.Tree.Perks[perk]
	local level = Formulas.perkLevel(data, perk)
	if perk == "StartMoney" then
		return definition.Step ^ level
	end
	return definition.Step * level
end

-- GDD 3.13: offline arány és max idő (a rebirth-fával nő).
function Formulas.offlineRate(data: any): number
	return Config.Offline.BaseRate + Formulas.perkValue(data, "OfflineRate")
end

function Formulas.offlineMaxSeconds(data: any): number
	return Config.Offline.BaseMaxSeconds + Formulas.perkValue(data, "OfflineTime")
end

-- Offline kereset `seconds` távollét után: becsült bevétel × arány × min(idő, max). Visszaad: pénz, számolt mp.
function Formulas.offlineEarnings(data: any, seconds: number): (number, number)
	local counted = math.clamp(seconds, 0, Formulas.offlineMaxSeconds(data))
	return math.floor(Formulas.incomePerSecond(data) * Formulas.offlineRate(data) * counted), counted
end

-- GDD 3.9: az aktív petek bónuszai típusonként összeadva (0.25 = +25%). Az arany pet GoldenMultiplier-szeres.
function Formulas.petBonuses(data: any): { Money: number, BakeSpeed: number, Luck: number, ChefSpeed: number }
	local totals = { Money = 0, BakeSpeed = 0, Luck = 0, ChefSpeed = 0 }
	local pets = data.pets
	if not pets then
		return totals
	end
	local byUid = {}
	for _, pet in pets.inventory do
		byUid[pet.uid] = pet
	end
	for _, uid in pets.equipped do
		local pet = byUid[uid]
		local definition = pet and Config.Pets.List[pet.id]
		if definition then
			local multiplier = if pet.golden then Config.Pets.GoldenMultiplier else 1
			totals[definition.Bonus] += definition.Value * multiplier
		end
	end
	return totals
end

-- GDD 3.10: az aktív aura bónusza (típus, érték); szintenként × szint.
function Formulas.auraBonusValue(id: string, level: number): number
	local aura = Config.Auras.List[id]
	if not aura then
		return 0
	end
	return aura.Value * math.clamp(level, 1, Config.Auras.MaxLevel)
end

-- Az összes aktív bónusz (petek + aura) típusonként – ezt használja a játékmenet.
function Formulas.boosts(data: any): { Money: number, BakeSpeed: number, Luck: number, ChefSpeed: number }
	local totals = Formulas.petBonuses(data)
	local auras = data.auras
	if auras and auras.equipped ~= "" then
		local aura = Config.Auras.List[auras.equipped]
		local level = auras.owned[auras.equipped]
		if aura and level then
			totals[aura.Bonus] += Formulas.auraBonusValue(auras.equipped, level)
		end
	end
	return totals
end

-- GDD 3.10: súlyozott aura dobás. Visszaad: aura id.
function Formulas.rollAura(rng: Random): string
	local list = Config.Auras.List
	local total = 0
	for _, id in Config.Auras.Order do
		total += list[id].Chance
	end
	local roll = rng:NextNumber() * total
	for _, id in Config.Auras.Order do
		roll -= list[id].Chance
		if roll < 0 then
			return id
		end
	end
	return Config.Auras.Order[1]
end

-- Pénzes aura dobás ára: ennyi mp-nyi bevétel, de legalább MinRollPrice.
function Formulas.auraRollPrice(data: any): number
	local auras = Config.Auras
	return math.max(auras.MinRollPrice, math.floor(Formulas.incomePerSecond(data) * auras.RollIncomeSeconds))
end

-- Egy pet bónusza (UI-hoz).
function Formulas.petBonusValue(id: string, golden: boolean): number
	local definition = Config.Pets.List[id]
	if not definition then
		return 0
	end
	return definition.Value * (if golden then Config.Pets.GoldenMultiplier else 1)
end

-- Sütési idő (mp) a pet "Sütés" bónuszával: BakeInterval / (1 + bónusz).
function Formulas.bakeInterval(data: any): number
	return Ovens.BakeInterval / (1 + Formulas.boosts(data).BakeSpeed)
end

-- Csillagok (döntés 2026-11-12): a Lv15 sütő csillagonként +Bonus értéket ad (csak a max szinten számít).
function Formulas.starMultiplier(level: number, stars: number?): number
	if level < Formulas.maxLevel() or not stars or stars <= 0 then
		return 1
	end
	return 1 + Ovens.Stars.Bonus * math.min(stars, Ovens.Stars.Max)
end

-- A következő (stars + 1.) csillag ára egy sütőre: egy csillag nélküli Lv15 sütő várható bevételének
-- (pénzszorzókkal, pet sütési sebességgel és a ritkaságok átlagával) PriceSeconds mp-e, csillagonként × PriceGrowth.
-- A szorzók benne vannak, így minden rebirth után ugyanannyi ideig tart a csillagozás.
function Formulas.starPrice(data: any, stars: number): number
	local settings = Ovens.Stars
	local rarity = Formulas.rarityValueMultiplier(1 + Formulas.boosts(data).Luck)
	local perSecond = Formulas.batchValue(Formulas.maxLevel()) / Formulas.bakeInterval(data)
		* Formulas.moneyMultiplier(data)
		* rarity
	return math.floor(perSecond * settings.PriceSeconds * settings.PriceGrowth ^ stars + 0.5)
end

-- A tele sor legalacsonyabb sütője (a 100-as gomb ebbe "vásárol bele"). Visszaad: slot, szint (nil, ha üres).
function Formulas.lowestOven(levels: { number }, slots: number): (number?, number)
	local lowestSlot, lowest = nil, math.huge
	for slot = 1, slots do
		local level = levels[slot] or 0
		if level > 0 and level < lowest then
			lowestSlot, lowest = slot, level
		end
	end
	return lowestSlot, lowest
end

-- Csillag-vásárlás célpontja: ha a sor tele van és minden sütő Lv15, a legkevesebb csillagú sütő.
-- Visszaad: slot, jelenlegi csillagszám (nil, ha még nem lehet / minden sütő max csillagos).
function Formulas.starTarget(levels: { number }, stars: { number }?, slots: number): (number?, number)
	local maxLevel = Formulas.maxLevel()
	local target, fewest = nil, math.huge
	for slot = 1, slots do
		if (levels[slot] or 0) < maxLevel then
			return nil, 0
		end
		local count = if stars then stars[slot] or 0 else 0
		if count < Ovens.Stars.Max and count < fewest then
			target, fewest = slot, count
		end
	end
	return target, if target then fewest else 0
end

-- A sütők átlagos termelése (ritkaság nélkül): darab/mp és $/mp (szorzók nélkül).
-- stars: slotonkénti csillagszám (opcionális) – csak az értéket növeli, a darabszámot nem.
function Formulas.production(levels: { number }, interval: number?, stars: { number }?): (number, number)
	local bakeInterval = interval or Ovens.BakeInterval
	local units, value = 0, 0
	for slot, level in levels do
		if level > 0 then
			units += Formulas.schnitzelUnits(level) / bakeInterval
			local multiplier = Formulas.starMultiplier(level, if stars then stars[slot] else nil)
			value += Formulas.batchValue(level) * multiplier / bakeInterval
		end
	end
	return units, value
end

-- Becsült bevétel $/mp: a termelés, de legfeljebb amennyit a pult el tud adni, szorzókkal.
-- (Pénzbónuszokhoz, később offline kereset és bevétel-skálázott pénzcsomagok – GDD 3.13, 5.)
function Formulas.incomePerSecond(data: any): number
	local units, value = Formulas.production(data.ovens, Formulas.bakeInterval(data), data.ovenStars)
	if units <= 0 then
		return 0
	end
	local sellCap = Formulas.sellRate(data.upgrades.sellSpeed) * (value / units)
	return math.min(value, sellCap) * Formulas.moneyMultiplier(data)
end

-- Merge szimuláció (GDD 3.3): 2 azonos szintű sütő → 1 eggyel magasabb, kaszkádban alulról felfelé.
-- Az eredmény az alacsonyabb sorszámú slotba kerül, a másik slot felszabadul.
-- Visszaad: új szint-lista, összevonások száma, összevonások listája.
function Formulas.merge(levels: { number }): ({ number }, number, { { slot: number, level: number } })
	local result = table.clone(levels)
	local merges = {}
	local maxLevel = Formulas.maxLevel()

	for level = 1, maxLevel - 1 do
		local slots = {}
		for slot, l in result do
			if l == level then
				table.insert(slots, slot)
			end
		end
		for i = 1, #slots - 1, 2 do
			result[slots[i]] = level + 1
			result[slots[i + 1]] = 0
			table.insert(merges, { slot = slots[i], level = level + 1 })
		end
	end

	return result, #merges, merges
end

-- A legalacsonyabb szabad slot a feloldott `slots` darabon belül.
function Formulas.firstFreeSlot(levels: { number }, slots: number): number?
	for slot = 1, slots do
		if (levels[slot] or 0) == 0 then
			return slot
		end
	end
	return nil
end

-- A platform teteje (itt állnak a sütők és a szalag).
function Formulas.platformTop(): number
	return PlotConfig.FloorTop + PlotConfig.Platform.Height
end

-- Egy sütő slot telek-lokális helye. Visszaad: X, Z, és hogy az első sorban van-e
-- (az első sor sütői hátrafelé, a szalag felé néznek).
-- Szimmetrikus kiosztás: a slotok középről kifelé, felváltva bal–jobb párokban:
--   1–12 hátsó sor, 13–24 első sor (középen a csúszda), 25 a hátsó sor közepe.
function Formulas.slotPosition(slot: number): (number, number, boolean)
	local ovens = PlotConfig.Ovens
	local perRow = ovens.PerSide * 2
	local index, z, front
	if slot <= perRow then
		index, z, front = slot, ovens.BackZ, false
	elseif slot <= perRow * 2 then
		index, z, front = slot - perRow, ovens.FrontZ, true
	else
		return 0, ovens.BackZ, false
	end
	local distance = (index + 1) // 2 -- 1, 1, 2, 2, 3, 3 ...
	local side = if index % 2 == 1 then -1 else 1 -- bal, jobb, bal, jobb ...
	return side * distance * ovens.Spacing, z, front
end

-- Egy sütő slot telek-lokális CFrame-je a platform tetején, a szalag felé fordítva.
function Formulas.slotCFrame(slot: number): CFrame
	local x, z, front = Formulas.slotPosition(slot)
	local cframe = CFrame.new(x, Formulas.platformTop(), z)
	if front then
		cframe *= CFrame.Angles(0, math.pi, 0)
	end
	return cframe
end

-- A schnitzel útja a sütőtől a collectorig (telek-lokális pontok):
-- a szalagon középre → csúszdán előre a fal széléig → le a collectorra.
function Formulas.conveyorPath(slot: number): { Vector3 }
	local conveyor = PlotConfig.Conveyor
	local collector = PlotConfig.Pads.Pickup
	local x = Formulas.slotPosition(slot)
	local top = Formulas.platformTop() + conveyor.Height + 0.2
	local collectorTop = PlotConfig.FloorTop + (collector.Height or 0.3) + 0.2
	return {
		Vector3.new(x, top, conveyor.Z),
		Vector3.new(collector.Position.X, top, conveyor.Z),
		Vector3.new(collector.Position.X, top, PlotConfig.Platform.FrontZ - 0.5),
		Vector3.new(collector.Position.X, collectorTop, collector.Position.Y),
	}
end

-- Mennyi idő alatt ér a schnitzel a sütőtől a collectorig (mp).
function Formulas.travelTime(slot: number): number
	local path = Formulas.conveyorPath(slot)
	local length = 0
	for i = 2, #path do
		length += (path[i] - path[i - 1]).Magnitude
	end
	return length / PlotConfig.Conveyor.Speed
end

-- A telek világbeli origója (6 telek: 2 sor × 3, középen utca).
-- A telek eleje (+Z lokális) mindig az utca felé néz.
function Formulas.plotOrigin(index: number): CFrame
	local column = (index - 1) % PlotConfig.Columns
	local row = (index - 1) // PlotConfig.Columns
	local x = (column - (PlotConfig.Columns - 1) / 2) * PlotConfig.SpacingX
	if row == 0 then
		return CFrame.new(x, 0, -PlotConfig.RowOffsetZ)
	end
	return CFrame.new(-x, 0, PlotConfig.RowOffsetZ) * CFrame.Angles(0, math.pi, 0)
end

return Formulas
