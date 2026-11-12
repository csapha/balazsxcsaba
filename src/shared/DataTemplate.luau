-- Játékos mentés sablon (ProfileStore). Új kulcs hozzáadásakor a Reconcile automatikusan kitölti.
-- Csak JSON-kompatibilis adat (nincs Vector3, CFrame stb.).
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Template = {
	version = 1,

	money = if RunService:IsStudio() then Config.Game.StudioStartMoney else Config.Game.StartMoney,

	-- Sütősor: slot → szint (0 = üres slot). Mindig MaxSlots hosszú, ebből `slots` darab van feloldva.
	slots = Config.Ovens.StartSlots,
	ovens = table.create(Config.Ovens.MaxSlots, 0),
	ovensBought = 0, -- az utolsó rebirth óta vett sütők (generáció küszöb)

	-- GDD 3.9: petek (megmaradnak rebirthkor)
	--   inventory: { { uid: number, id: string, golden: boolean } }, equipped: { uid }
	pets = {
		inventory = {},
		equipped = {},
		nextId = 1,
	},

	-- GDD 3.10: aurák (megmaradnak rebirthkor). owned: { [auraId] = szint }
	auras = {
		owned = {},
		equipped = "",
		tickets = 0,
		ticketProgress = 0, -- mp játékidő a következő ingyen ticketig
	},

	-- GDD 3.8: rebirth (megmarad rebirthkor) + rebirth-fa perk szintek
	rebirths = 0,
	rebirthTokens = 0,
	cycleEarned = 0, -- az utolsó rebirth óta keresett pénz (eladás + offline) – ez a rebirth követelménye
	rebirthPerks = {
		Money = 0,
		StartMoney = 0,
		StartChefs = 0,
		StartGeneration = 0,
		OfflineTime = 0,
		OfflineRate = 0,
	},

	-- GDD 3.13: offline kereset. lastOnline: os.time() (mp), pending: felvételre váró pénz
	lastOnline = 0,
	offline = {
		pending = 0,
		seconds = 0,
	},

	-- GDD 3.7: sütő-generáció (Gen k → a gombok Lv k sütőt adnak) és az ebben a generációban vett sütők (ár)
	generation = 1,
	generationBought = 0,

	-- Gyűjtőtálca (nincs korlátja): hány sütés van rajta, ez hány darab, és mennyit ér összesen ($)
	tray = {
		count = 0,
		units = 0,
		value = 0,
		-- ritkaságonként (Config.Rarities.List sorrendben): hány sütés és hány darab van a collectorban
		rarityCount = table.create(#Config.Rarities.List, 0),
		rarityUnits = table.create(#Config.Rarities.List, 0),
		rarityValue = table.create(#Config.Rarities.List, 0),
	},

	-- Chefek (GDD 3.6): darabszám + globális fejlesztési szintek
	chefs = {
		count = 0,
		stack = 0,
		speed = 0,
		stamina = 0,
		antiSleep = 0,
	},

	carried = 0, -- a játékosnál lévő darab (nincs felső korlát)
	carriedValue = 0, -- ezek összértéke ($, szorzók nélkül)
	counterStock = 0, -- a pult gyűjtőjében eladásra váró darab
	counterValue = 0, -- ezek összértéke ($, szorzók nélkül) → az eladó átlagáron adja el
	moneyPile = 0, -- a raklapon felvételre váró pénz

	upgrades = {
		sellSpeed = 0,
	},

	-- Pult szint + XP (GDD 3.5)
	counter = {
		level = 1,
		xp = 0,
	},

	stats = {
		totalSold = 0,
		totalEarned = 0,
		merges = 0,
		highestOven = 0,
	},
}

export type Template = typeof(Template)

return Template
