-- Eladás: tálca → játékos → pult gyűjtő → eladó → pénzkupac → játékos (GDD 3.5, 12.1 SellService).
-- Minden lépésnél a darabszám és az összérték ($) együtt mozog; az eladó átlagáron ad el.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Billboard = require(script.Parent.Parent.Lib.Billboard)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local PlotService = require(script.Parent.PlotService)
local IndexService = require(script.Parent.IndexService)

local Palette = Config.Palette

local SellService = {}

-- A collectorban lévő összes schnitzel a játékoshoz kerül (nincs felső korlát).
-- A kliens minőségenként kiírja: "+47", "+20 Ezüst Schnitzel" ...
function SellService.pickup(state: PlotService.PlotState)
	local data = state.data
	local raw = data()
	local tray = raw.tray
	if tray.units <= 0 then
		return
	end

	local picked = {}
	for rarity, units in tray.rarityUnits do
		if units > 0 then
			table.insert(picked, { rarity = rarity, units = units })
		end
	end
	Remotes.PickedUp:FireClient(state.player, picked)

	local rarityCount = #Config.Rarities.List
	data.carried(raw.carried + tray.units)
	data.carriedValue(raw.carriedValue + tray.value)
	data.tray.count(0)
	data.tray.units(0)
	data.tray.value(0)
	data.tray.rarityCount(table.create(rarityCount, 0))
	data.tray.rarityUnits(table.create(rarityCount, 0))
	data.tray.rarityValue(table.create(rarityCount, 0))
end

-- Egy chef legfeljebb `maxBatches` sütést vesz ki a collectorból (a simáktól a ritkák felé),
-- a hozzájuk tartozó darabszámmal és értékkel együtt. Visszaad: sütés, darab, érték.
function SellService.takeFromTray(state: PlotService.PlotState, maxBatches: number): (number, number, number)
	local data = state.data
	local tray = data().tray
	if tray.count <= 0 or maxBatches <= 0 then
		return 0, 0, 0
	end

	local rarityCount = table.clone(tray.rarityCount)
	local rarityUnits = table.clone(tray.rarityUnits)
	local rarityValue = table.clone(tray.rarityValue)
	local takenCount, takenUnits, takenValue = 0, 0, 0

	for rarity = 1, #rarityCount do
		local available = rarityCount[rarity]
		if available <= 0 then
			continue
		end
		local take = math.min(available, maxBatches - takenCount)
		if take <= 0 then
			break
		end
		-- arányosan; ha mindet viszi, a teljes maradékot (ne maradjon lebegőpontos morzsa)
		local units = if take == available then rarityUnits[rarity] else math.floor(rarityUnits[rarity] * take / available)
		local value = if take == available then rarityValue[rarity] else rarityValue[rarity] * take / available
		rarityCount[rarity] -= take
		rarityUnits[rarity] -= units
		rarityValue[rarity] -= value
		takenCount += take
		takenUnits += units
		takenValue += value
	end

	local remaining = tray.count - takenCount
	data.tray.count(remaining)
	data.tray.units(if remaining > 0 then math.max(0, tray.units - takenUnits) else 0)
	data.tray.value(if remaining > 0 then math.max(0, tray.value - takenValue) else 0)
	data.tray.rarityCount(rarityCount)
	data.tray.rarityUnits(rarityUnits)
	data.tray.rarityValue(rarityValue)
	return takenCount, takenUnits, takenValue
end

-- A chef a leadó asztalra teszi, amit hozott (ugyanoda, ahova a játékos lead).
function SellService.depositFromChef(state: PlotService.PlotState, units: number, value: number)
	if units <= 0 then
		return
	end
	local data = state.data
	local raw = data()
	data.counterStock(raw.counterStock + units)
	data.counterValue(raw.counterValue + value)
end

-- A játékosnál lévő schnitzelek a pult gyűjtőjébe kerülnek.
function SellService.deposit(state: PlotService.PlotState)
	local data = state.data
	local raw = data()
	if raw.carried <= 0 then
		return
	end
	Remotes.Deposited:FireClient(state.player, state.plot.index, raw.carried)
	data.counterStock(raw.counterStock + raw.carried)
	data.counterValue(raw.counterValue + raw.carriedValue)
	data.carried(0)
	data.carriedValue(0)
end

-- A raklapon lévő pénz a játékoshoz kerül.
function SellService.collect(state: PlotService.PlotState)
	local data = state.data
	local raw = data()
	if raw.moneyPile <= 0 then
		return
	end
	data.money(raw.money + raw.moneyPile)
	data.moneyPile(0)
end

function SellService.upgradeSellSpeed(state: PlotService.PlotState): boolean
	local data = state.data
	local raw = data()
	local level = raw.upgrades.sellSpeed
	local price = Formulas.sellUpgradePrice(level)
	if raw.money < price then
		return false
	end
	data.money(raw.money - price)
	data.upgrades.sellSpeed(level + 1)
	return true
end

-- Az eladó Rate darabot ad el másodpercenként a pult gyűjtőjéből, átlagáron.
-- A tört sebesség (pl. 1.25 db/mp) gyűlik: a maradék a következő tickben eladódik.
local function sellTick()
	for _, state in PlotService.all() do
		local data = state.data
		local raw = data()
		if raw.counterStock <= 0 then
			state.sellRemainder = 0
			continue
		end

		-- GDD 3.12 Ebédcsúcs: dupla eladási sebesség
		local event = EventState.config()
		local rate = Formulas.sellRate(raw.upgrades.sellSpeed) * (if event then event.SellMultiplier or 1 else 1)
		local budget = rate + (state.sellRemainder or 0)
		local amount = math.min(raw.counterStock, math.floor(budget))
		if amount <= 0 then
			state.sellRemainder = budget
			continue
		end
		state.sellRemainder = if amount < raw.counterStock then budget - amount else 0

		-- az utolsó adag a teljes maradék értéket viszi (ne maradjon lebegőpontos morzsa)
		local baseValue = if amount >= raw.counterStock
			then raw.counterValue
			else raw.counterValue * amount / raw.counterStock
		local earned = baseValue * Formulas.moneyMultiplier(raw) * IndexService.moneyBonus(state.player)

		state.lastSaleAt = os.clock() -- a vendégsor (CustomerService) ebből tudja, hogy kiszolgálhat
		data.counterStock(raw.counterStock - amount)
		data.counterValue(math.max(0, raw.counterValue - baseValue))
		data.moneyPile(raw.moneyPile + earned)
		data.cycleEarned(raw.cycleEarned + earned) -- rebirth követelmény (GDD 3.8)
		data.stats.totalSold(raw.stats.totalSold + amount)
		data.stats.totalEarned(raw.stats.totalEarned + earned)

		SellService.addCounterXp(state, amount)
	end
end

-- Pult XP: 1 eladott darab = 1 XP. Szintlépéskor egyszeri pénzbónusz (≈ 30 mp bevétel),
-- tartós +2% ár és 2 szintenként hosszabb vendégsor (GDD 3.5, döntés 2026-11-12).
function SellService.addCounterXp(state: PlotService.PlotState, xp: number)
	local data = state.data
	local raw = data()
	local oldLevel = raw.counter.level
	local level = oldLevel
	local total = raw.counter.xp + xp

	while total >= Formulas.counterXpNeeded(level) do
		total -= Formulas.counterXpNeeded(level)
		level += 1
	end
	data.counter.xp(total)

	if level ~= oldLevel then
		data.counter.level(level)
		-- szintenként ≈ 30 mp bevétel, már az új szint árszorzójával
		local perLevel = Formulas.incomePerSecond(raw) * Config.Sell.Counter.LevelUpIncomeSeconds
		local bonus = math.max(math.floor(perLevel * (level - oldLevel)), Config.Sell.UnitPrice * 10)
		data.money(raw.money + bonus)
		state.counterLevelPop = { level = level, bonus = bonus }
	end
end

-- A felugró "PULT Lv 5! +$1.2K" felirat a pult felett.
local function showCounterPop(state: PlotService.PlotState)
	local pop = state.counterLevelPop
	if not pop then
		return
	end
	state.counterLevelPop = nil

	local counter = state.plot.model:FindFirstChild("Counter")
	if not counter or not counter:IsA("BasePart") then
		return
	end
	local labels = Billboard.new(counter, {
		offset = Vector3.new(0, 11, 0),
		size = Vector2.new(14, 3.2),
		maxDistance = 150,
		lines = {
			{ name = "Title", color = Palette.Lemon, height = 0.55 },
			{ name = "Bonus", color = Palette.Money, height = 0.45 },
		},
	})
	labels.Title.Text = `COUNTER Lv {pop.level}!`
	labels.Bonus.Text = `+{NumberFormat.money(pop.bonus)}`
	local gui = labels.Title.Parent :: BillboardGui
	gui.Name = "LevelPop"
	gui.AlwaysOnTop = true
	Debris:AddItem(gui, 2.5)
end

-- Szűk keresztmetszet (GDD 3.5): a piros "!" azon a rendszeren, ami épp a bottleneck.
--   1. a collectorban sok vár → vidd el (Pickup)
--   2. a pultban sok vár → fejleszd az eladót (SellUpgrade)
--   3. a pult gyorsabban adna el, mint amit a sütők termelnek → több / jobb sütő (Merge vagy vásárlás)
local function bottleneck(raw: any): string?
	local unitsPerSecond = Formulas.production(raw.ovens, Formulas.bakeInterval(raw))
	if unitsPerSecond <= 0 then
		return nil
	end
	local settings = Config.Sell.Bottleneck
	local rate = Formulas.sellRate(raw.upgrades.sellSpeed)

	if raw.tray.units >= unitsPerSecond * settings.CollectorSeconds then
		return "Pickup"
	end
	if raw.counterStock >= rate * settings.CounterSeconds then
		return "SellUpgrade"
	end
	if unitsPerSecond < rate and raw.carried <= 0 and raw.counterStock < rate * 5 then
		local _, merges = Formulas.merge(raw.ovens)
		return if merges > 0 then "Merge" else "BuyOne"
	end
	return nil
end

local function render(state: PlotService.PlotState, raw: any)
	local labels = state.plot.labels
	local model = state.plot.model

	-- a többi játékos is lássa a fej feletti tornyot (StackController)
	state.player:SetAttribute("Carried", raw.carried)

	local alertKey = bottleneck(raw)
	for key, alert in state.plot.alerts do
		alert.Enabled = key == alertKey
	end

	-- pult szint + XP
	local counter = raw.counter
	local needed = Formulas.counterXpNeeded(counter.level)
	labels.Counter.Xp.Text = `Lv {counter.level}, XP {NumberFormat.short(counter.xp)}/{NumberFormat.short(needed)}`
	state.plot.counterXpFill.Size = UDim2.fromScale(math.clamp(counter.xp / needed, 0, 1), 1)
	showCounterPop(state)

	-- A kliens ebből rajzolja a halmot a collectoron (sütésenként egy darab, ritkák elöl)
	model:SetAttribute("TrayCount", raw.tray.count)
	model:SetAttribute("CounterStock", raw.counterStock) -- a halom a leadó asztalon
	for rarity, count in raw.tray.rarityCount do
		model:SetAttribute(`TrayRarity{rarity}`, count)
	end

	labels.Pickup.Info.Text = if raw.tray.units > 0
		then `🥩 {NumberFormat.grouped(raw.tray.units)} ({NumberFormat.money(raw.tray.value)})`
		else "empty"

	local level = raw.upgrades.sellSpeed
	local rate = Formulas.sellRate(level)
	local bonusPercent = math.floor((Formulas.counterPriceMultiplier(counter.level) - 1) * 100 + 0.5)
	labels.Counter.Title.Text = if bonusPercent > 0
		then `Counter {NumberFormat.short(rate)}/s, +{bonusPercent}% price`
		else `Counter {NumberFormat.short(rate)}/s`
	labels.Counter.Info.Text = if raw.counterStock > 0
		then `🥩 {NumberFormat.grouped(raw.counterStock)} ({NumberFormat.money(raw.counterValue)})`
		else "Empty! Bring schnitzel"
	labels.Deposit.Info.Text = if raw.carried > 0
		then `🥩 {NumberFormat.grouped(raw.carried)} ({NumberFormat.money(raw.carriedValue)})`
		else ""

	labels.Collect.Info.Text = NumberFormat.money(raw.moneyPile)

	local upgradePrice = Formulas.sellUpgradePrice(level)
	labels.SellUpgrade.Title.Text =
		`Sell {NumberFormat.short(rate)} → {NumberFormat.short(Formulas.sellRate(level + 1))}/s`
	labels.SellUpgrade.Info.Text = NumberFormat.money(upgradePrice)
	labels.SellUpgrade.Info.TextColor3 = if raw.money >= upgradePrice then Palette.Money else Palette.Danger
end

function SellService.init()
	PlotService.registerPad("Pickup", {
		stay = function(_player, state)
			SellService.pickup(state)
		end,
	})
	PlotService.registerPad("Deposit", {
		stay = function(_player, state)
			SellService.deposit(state)
		end,
	})
	PlotService.registerPad("Collect", {
		stay = function(_player, state)
			SellService.collect(state)
		end,
	})
	PlotService.registerPad("SellUpgrade", {
		enter = function(_player, state)
			SellService.upgradeSellSpeed(state)
		end,
	})
	PlotService.addRenderer(render)
end

function SellService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Sell.TickInterval)
			sellTick()
		end
	end)
end

return SellService
