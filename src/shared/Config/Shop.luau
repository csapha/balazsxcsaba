-- GDD 5 (Shop) + 6.2 (gamepassok) + 6.3 (dev productok) + 6.4 (Premium, group). Döntések (2026-11-15):
--   fülek: Ajánlatok, Gamepassok, Pénz, Boostok, Tojások / Aura, Kozmetikumok, Kódok;
--   a Roblox ID-k még nincsenek: 0 = nincs beállítva. Studióban a 0-s ID-jű termék ingyen teljesül (teszt),
--   élesben a 0-s ID-jű termék gombja "SOON". Az ID-t a Creator Hubon létrehozott termékből kell beírni.
--
-- Effect típusok (ShopService.grantProduct):
--   Cash          – Seconds mp-nyi bevétel (legalább Min $)
--   Boost         – időszakos boost: Boost kulcs (Money / Luck / Bake / ChefEnergy), Duration mp; halmozódik
--   AuraRoll      – azonnali aura dobás
--   OfflineX10    – a függő offline kereset ×10-e (csak ha van függő offline kereset)
--   Starter       – Kezdőcsomag: Boost + Pet + Cash, egyszer, az első StarterDays napban
--   RobuxEgg      – Golden Egg: Count db exkluzív pet (Config.Pets.RobuxEgg)
--   RebirthSkip   – rebirth jutalom NULLÁZÁS NÉLKÜL (döntés 2026-11-15), lépcsős ár (Shop.RebirthSkip)
--   SuperJump / SchnitzelRain / Tenderize – troll / fun termékek (GDD 6.3)
--   Cosmetic      – kozmetikum (trail / telek téma), egyszeri: data.cosmetics.owned
local Shop = {}

local HOUR = 60 * 60

-- Döntés 2026-11-15 (átrendezés): 3 fül, a VIP és a Kezdőcsomag a kezdőlapon; a Rebirth Skip a Rebirth ablakban;
-- a Golden Egg, az Aura Roll és a kozmetikumok (trail-ek) kikerültek a Shopból (a rendszerük kész, később máshol jöhetnek);
-- a kódok kikerültek a Shopból (később a Beállítások ablakba kerülnek – a szerver oldal kész, Remotes.RedeemCode).
Shop.Tabs = table.freeze({ "Featured", "Passes", "Items" })
-- az Items fül szekciói (a termék Section mezője)
Shop.ItemSections = table.freeze({ "Cash", "Boosts", "Fun" })

-- GDD 6.2: gamepassok (egyszeri vásárlás). Price: R$ (csak kijelzés, a valódi árat a Roblox adja).
-- A Gamepasses fülön ezek látszanak (döntés 2026-11-15: kevesebb dolog a Shopban). A többi gamepass ott jelenik meg,
-- ahol értelme van: VIP – kezdőlap; Tireless Chefs – chef-pad + toast, ha elalszik a chef; Offline x2 – az Offline
-- ablakban; Open 3 Eggs és Fast Open – a tojásoknál (külön prompt).
Shop.PassOrder = table.freeze({
	"DoubleMoney", "DoubleBake", "AutoCollect", "Lucky", "ChefSlots", "PetSlot",
})
Shop.Passes = table.freeze({
	DoubleMoney = table.freeze({ Name = "x2 Money", Description = "All money x2, forever", Price = 149, Icon = "DoubleCoins", Color = "Green", GamePassId = 0 }),
	DoubleBake = table.freeze({ Name = "x2 Baking Speed", Description = "Ovens bake 2x faster", Price = 99, Icon = "Baking", Color = "Orange", GamePassId = 0 }),
	AutoCollect = table.freeze({ Name = "Auto Collect", Description = "Sale money goes straight to you", Price = 49, Icon = "CoinBag", Color = "Yellow", GamePassId = 0 }),
	Lucky = table.freeze({ Name = "Lucky Schnitzel x2", Description = "Rare schnitzel chances x2", Price = 99, Icon = "Clover", Color = "Green", GamePassId = 0 }),
	TirelessChefs = table.freeze({ Name = "Tireless Chefs", Description = "Chefs never fall asleep", Price = 129, Icon = "Energy", Color = "Yellow", GamePassId = 0 }),
	ChefSlots = table.freeze({ Name = "+2 Chef Slots", Description = "+2 max chefs", Price = 99, Icon = "Chefs", Color = "Blue", GamePassId = 0 }),
	PetSlot = table.freeze({ Name = "+1 Pet Slot", Description = "Equip 4 pets at once", Price = 79, Icon = "Pets", Color = "Pink", GamePassId = 0 }),
	OfflineBoost = table.freeze({ Name = "Offline x2 + 12h", Description = "x2 offline earnings, up to 12 hours", Price = 79, Icon = "Clock", Color = "Purple", GamePassId = 0 }),
	VIP = table.freeze({ Name = "VIP", Description = "x1.5 money, [VIP] tag, VIP area, VIP Golden Poodle, daily gift", Price = 299, Icon = "Crown", Color = "Yellow", GamePassId = 0 }),
	TripleEgg = table.freeze({ Name = "Open 3 Eggs", Description = "Open 3 eggs at once, forever", Price = 99, Icon = "Egg", Color = "Pink", GamePassId = 0 }),
	FastEgg = table.freeze({ Name = "Fast Open", Description = "Eggs open instantly, forever", Price = 49, Icon = "Egg", Color = "Pink", GamePassId = 0 }),
})

-- Gamepass hatások (Formulas olvassa)
Shop.PassEffects = table.freeze({
	DoubleMoney = 2, -- pénzszorzó
	VIP = 1.5, -- pénzszorzó
	DoubleBake = 2, -- sütési sebesség szorzó
	Lucky = 2, -- szerencse szorzó
	ChefSlots = 2, -- +max chef
	PetSlot = 1, -- +aktív pet
	OfflineRate = 2, -- offline arány szorzó (OfflineBoost)
	OfflineExtraSeconds = 10 * HOUR, -- +offline idő (alap 2 óra → 12 óra)
})

-- GDD 6.3: időszakos boostok. A boost kulcs → hatás (Formulas.timedBoost).
Shop.BoostEffects = table.freeze({
	Money = 2, -- pénzszorzó
	Luck = 2, -- szerencse szorzó
	Bake = 2, -- sütési sebesség szorzó
	ChefEnergy = true, -- a chefek nem alszanak el
})
Shop.BoostNames = table.freeze({
	Money = "x2 Money",
	Luck = "x2 Luck",
	Bake = "x2 Baking",
	ChefEnergy = "Chef Energy",
})

-- GDD 6.3: dev productok (ismételhetők). Tab: melyik fülön jelenik meg ("Hidden": nincs a Shop rácsban, de a napi
-- akció / event ajánlat kínálhatja; "Offline": csak az Offline ablakban; "Rebirth": a Rebirth ablakban).
Shop.ProductOrder = table.freeze({
	"CashS", "CashM", "CashL", "CashXL", "OfflineX10",
	"BoostMoney15", "BoostMoney60", "BoostLuck15", "BoostBake15", "ChefEnergy",
	"RobuxEgg1", "RobuxEgg3", "RobuxEgg10", "AuraRoll",
	"Starter", "RebirthSkip1", "RebirthSkip2", "RebirthSkip3", "RebirthSkip4", "SuperJump", "SchnitzelRain", "Tenderize",
})
Shop.Products = table.freeze({
	-- Pénz: az aktuális bevételhez skálázva (GDD 5.1 ③)
	CashS = table.freeze({ Tab = "Hidden", Name = "Pocket Cash", Description = "15 minutes of income", Price = 19, Icon = "Coin", Color = "Green", ProductId = 0, ValueGroup = "Cash", Effect = "Cash", Seconds = 15 * 60, Min = 1_000 }),
	CashM = table.freeze({ Tab = "Items", Section = "Cash", Name = "Cash Bag", Description = "1 hour of income", Price = 49, Icon = "CoinBag", Color = "Green", ProductId = 0, ValueGroup = "Cash", Effect = "Cash", Seconds = HOUR, Min = 5_000 }),
	CashL = table.freeze({ Tab = "Items", Section = "Cash", Name = "Cash Chest", Description = "6 hours of income", Price = 99, Icon = "CoinChest", Color = "Yellow", ProductId = 0, ValueGroup = "Cash", Effect = "Cash", Seconds = 6 * HOUR, Min = 25_000 }),
	CashXL = table.freeze({ Tab = "Items", Section = "Cash", Name = "Cash Vault", Description = "24 hours of income", Price = 249, Icon = "RebirthCash", Color = "Orange", ProductId = 0, ValueGroup = "Cash", BestValue = true, Effect = "Cash", Seconds = 24 * HOUR, Min = 100_000 }),
	OfflineX10 = table.freeze({ Tab = "Offline", Name = "Offline Claim x10", Description = "Claim your offline earnings x10", Price = 25, Icon = "Clock", Color = "Purple", ProductId = 0, Effect = "OfflineX10" }),

	-- Boostok (GDD 5.1 ④)
	BoostMoney15 = table.freeze({ Tab = "Items", Section = "Boosts", Name = "x2 Money", Description = "15 minutes", Price = 15, Icon = "PotionCoins", Color = "Green", ProductId = 0, ValueGroup = "BoostMoney", Effect = "Boost", Boost = "Money", Duration = 15 * 60 }),
	BoostMoney60 = table.freeze({ Tab = "Items", Section = "Boosts", Name = "x2 Money", Description = "1 hour", Price = 39, Icon = "PotionCoins", Color = "Green", ProductId = 0, ValueGroup = "BoostMoney", Effect = "Boost", Boost = "Money", Duration = HOUR }),
	BoostLuck15 = table.freeze({ Tab = "Items", Section = "Boosts", Name = "x2 Luck", Description = "15 minutes", Price = 19, Icon = "PotionLuck", Color = "Purple", ProductId = 0, Effect = "Boost", Boost = "Luck", Duration = 15 * 60 }),
	BoostBake15 = table.freeze({ Tab = "Hidden", Name = "x2 Baking Speed", Description = "15 minutes", Price = 19, Icon = "PotionSpeed", Color = "Orange", ProductId = 0, Effect = "Boost", Boost = "Bake", Duration = 15 * 60 }),
	ChefEnergy = table.freeze({ Tab = "Hidden", Name = "Chef Energy Drink", Description = "Chefs don't sleep for 30 minutes", Price = 15, Icon = "Energy", Color = "Yellow", ProductId = 0, Effect = "Boost", Boost = "ChefEnergy", Duration = 30 * 60 }),

	-- Tojások / Aura (GDD 5.1 ⑤, 6.3). Golden Egg: exkluzív petek (Config.Pets.RobuxEgg).
	RobuxEgg1 = table.freeze({ Tab = "Hidden", Name = "Golden Egg", Description = "Exclusive pets – open 1", Price = 39, Icon = "LuckBoost", Color = "Yellow", ProductId = 0, ValueGroup = "RobuxEgg", Effect = "RobuxEgg", Count = 1 }),
	RobuxEgg3 = table.freeze({ Tab = "Hidden", Name = "Golden Egg x3", Description = "Exclusive pets – open 3", Price = 99, Icon = "LuckBoost", Color = "Yellow", ProductId = 0, ValueGroup = "RobuxEgg", Effect = "RobuxEgg", Count = 3 }),
	RobuxEgg10 = table.freeze({ Tab = "Hidden", Name = "Golden Egg x10", Description = "Exclusive pets – open 10", Price = 299, Icon = "LuckBoost", Color = "Orange", ProductId = 0, ValueGroup = "RobuxEgg", Effect = "RobuxEgg", Count = 10 }),
	AuraRoll = table.freeze({ Tab = "Hidden", Name = "Aura Roll", Description = "Roll an aura right now", Price = 19, Icon = "Auras", Color = "Purple", ProductId = 0, Effect = "AuraRoll" }),

	-- Ajánlatok (GDD 5.1 ①, 6.3)
	Starter = table.freeze({ Tab = "Featured", Name = "Starter Pack", Description = "x2 Money for 1 hour + Wooden Spoon Owl (Epic pet) + $100K", Price = 49, Icon = "Gift", Color = "Pink", ProductId = 0, Effect = "Starter", Boost = "Money", Duration = HOUR, Pet = "Bagoly", Cash = 100_000 }),
	-- Rebirth Skip: lépcsőnként külön termék (a Roblox ár fix); a Rebirth ablakban, mindig az aktuális lépcső (Shop.RebirthSkip)
	RebirthSkip1 = table.freeze({ Tab = "Rebirth", Name = "Rebirth Skip", Description = "Rebirth now and keep your ovens + money", Price = 49, Icon = "Rebirth", Color = "Green", ProductId = 0, Effect = "RebirthSkip", SkipTier = 1 }),
	RebirthSkip2 = table.freeze({ Tab = "Rebirth", Name = "Rebirth Skip", Description = "Rebirth now and keep your ovens + money", Price = 99, Icon = "Rebirth", Color = "Green", ProductId = 0, Effect = "RebirthSkip", SkipTier = 2 }),
	RebirthSkip3 = table.freeze({ Tab = "Rebirth", Name = "Rebirth Skip", Description = "Rebirth now and keep your ovens + money", Price = 199, Icon = "Rebirth", Color = "Green", ProductId = 0, Effect = "RebirthSkip", SkipTier = 3 }),
	RebirthSkip4 = table.freeze({ Tab = "Rebirth", Name = "Rebirth Skip", Description = "Rebirth now and keep your ovens + money", Price = 399, Icon = "Rebirth", Color = "Green", ProductId = 0, Effect = "RebirthSkip", SkipTier = 4 }),
	SuperJump = table.freeze({ Tab = "Items", Section = "Fun", Name = "Super Jump", Description = "Jump sky high for 30 seconds", Price = 5, Icon = "Rocket", Color = "Blue", ProductId = 0, Effect = "SuperJump", Duration = 30, JumpHeight = 60 }),
	SchnitzelRain = table.freeze({ Tab = "Items", Section = "Fun", Name = "Schnitzel Rain", Description = "Golden schnitzels rain on the street for everyone", Price = 15, Icon = "Schnitzel", Color = "Orange", ProductId = 0, Effect = "SchnitzelRain", Duration = 20, DropCount = 40, DropIncomeSeconds = 5, DropMinValue = 100 }),
	Tenderize = table.freeze({ Tab = "Items", Section = "Fun", Name = "Tenderize the Server", Description = "Everyone's screen shakes for 3 seconds", Price = 10, Icon = "Strength", Color = "Red", ProductId = 0, Effect = "Tenderize", Duration = 3 }),
})

-- Kezdőcsomag: csak egyszer, az első ennyi napban (időzítővel, GDD 5.1 ①)
Shop.StarterDays = 3

-- Bevezető akció a gamepassokra (döntés 2026-11-15: VALÓDI akció, nem kamu áthúzott ár).
--   EndsAt: az akció vége (os.time, UTC mp); 0 = nincs akció.
--   FONTOS: az akció idejére a Creator Hubon a gamepassok árát tényleg le kell venni (Price × (1 - Discount)),
--   lejártakor vissza kell állítani. A Shop a valódi Roblox árat mutatja (GetProductInfo), és csak akkor
--   húzza át a normál árat, ha a valódi ár tényleg alacsonyabb – így a kiírás mindig igaz.
--   StudioPreviewDays: Studióban (ID nélkül) teszteléshez az első belépéstől ennyi napig látszik az akció.
-- Discounts: gamepassonként eltérő kedvezmény (döntés 2026-11-15: ne mindenhol ugyanannyi legyen).
-- Fix értékek, nem véletlenek: a Creator Hubon pontosan ezekre az árakra kell állítani a gamepassokat
-- (akciós ár = Price × (1 - kedvezmény), kerekítve) – zárójelben az akciós ár.
Shop.LaunchSale = table.freeze({
	EndsAt = 0,
	StudioPreviewDays = 7,
	Discounts = table.freeze({
		DoubleMoney = 0.33, -- 149 → 100
		DoubleBake = 0.25, -- 99 → 74
		AutoCollect = 0.40, -- 49 → 29
		Lucky = 0.20, -- 99 → 79
		TirelessChefs = 0.30, -- 129 → 90
		ChefSlots = 0.35, -- 99 → 64
		PetSlot = 0.25, -- 79 → 59
		OfflineBoost = 0.40, -- 79 → 47
		VIP = 0.27, -- 299 → 218
		TripleEgg = 0.20, -- 99 → 79
		FastEgg = 0.25, -- 49 → 37
	}),
})

-- Értékcímkék (döntés 2026-11-15: csak kiszámolt, igaz érték): az azonos ValueGroup-ba tartozó termékeket
-- a legkisebbhez mérjük (mennyiség / Robux): "x4.6 VALUE"; a BestValue = true termék "BEST VALUE".
-- Mennyiség: Cash → Seconds, Boost → Duration, tojás → Count.

-- Napi akció (GDD 5.1 ①): naponta (UTC) egy másik termék, kedvezményes áron.
-- A Robloxon a dev product ára fix, ezért minden akciónak saját ProductId kell (a kedvezményes árral).
-- A kedvezmény termékenként eltér (20–40%, döntés 2026-11-15); a kártyán kiírt % a valódi árakból számolódik.
Shop.Deals = table.freeze({
	table.freeze({ Product = "BoostMoney60", Price = 25, ProductId = 0 }),
	table.freeze({ Product = "CashL", Price = 59, ProductId = 0 }),
	table.freeze({ Product = "BoostLuck15", Price = 15, ProductId = 0 }),
	table.freeze({ Product = "CashM", Price = 39, ProductId = 0 }),
})

-- Limitált event ajánlat (GDD 5.1 ①): random event alatt egy hozzá illő termék kedvezményesen
-- (saját, olcsóbb ProductId kell hozzá, mint a napi akciónál). Kulcs: Config.Events.List kulcsa.
Shop.EventOffers = table.freeze({
	LunchRush = table.freeze({ Product = "BoostMoney15", Price = 9, ProductId = 0 }), -- 15 → 9
	GoldenOil = table.freeze({ Product = "BoostLuck15", Price = 11, ProductId = 0 }), -- 19 → 11
	PanirStorm = table.freeze({ Product = "CashM", Price = 29, ProductId = 0 }), -- 49 → 29
	Critic = table.freeze({ Product = "BoostMoney60", Price = 24, ProductId = 0 }), -- 39 → 24
	Grandma = table.freeze({ Product = "BoostBake15", Price = 12, ProductId = 0 }), -- 19 → 12
	Blackout = table.freeze({ Product = "ChefEnergy", Price = 8, ProductId = 0 }), -- 15 → 8
})

-- Rebirth Skip (döntés 2026-11-15): a rebirth jutalma nullázás nélkül; csak ha a követelmény legalább
-- MinProgress részét elérted. Az ár a következő rebirth sorszámától függ (lépcsőnként külön termék):
--   1–2. rebirth R$ 49, 3–5. R$ 99, 6–10. R$ 199, utána R$ 399.
Shop.RebirthSkip = table.freeze({
	MinProgress = 0.25,
	Tiers = table.freeze({
		table.freeze({ UpTo = 2, Product = "RebirthSkip1" }),
		table.freeze({ UpTo = 5, Product = "RebirthSkip2" }),
		table.freeze({ UpTo = 10, Product = "RebirthSkip3" }),
		table.freeze({ UpTo = math.huge, Product = "RebirthSkip4" }),
	}),
})

-- VIP gamepass extrák (döntés 2026-11-15): [VIP] címke (chat + név felett), VIP terület a Tojás téren
-- (csak VIP léphet be, bent +EggLuck szerencse a tojásnyitáshoz), VIP pet (Config.Pets.VipPet), napi ajándék.
Shop.Vip = table.freeze({
	TagColor = Color3.fromRGB(255, 205, 50),
	EggLuck = 0.10, -- a VIP területen: a ritkább petek esélye ×(1 + EggLuck)
	DailyGift = table.freeze({ IncomeSeconds = 30 * 60, Min = 5_000, Tickets = 1 }),
	-- a tojások mögötti sáv (a Tojás tér közepéhez képest; a talapzatok Z = -3..3), bentről is elérhetők a tojások
	Area = table.freeze({ Offset = Vector3.new(0, 0, -6.5), Size = Vector2.new(50, 6) }),
})

-- GDD 6.4: Roblox Premium tagoknak napi ajándék; csoporttagoknak +10% pénz (GroupId = 0: nincs csoport).
Shop.Premium = table.freeze({ IncomeSeconds = 15 * 60, Min = 2_000, Tickets = 1 })
Shop.Group = table.freeze({ GroupId = 0, MoneyBonus = 0.10 })

-- Kozmetikumok (GDD 5.1 ⑥, döntés 2026-11-15: most csak trail-ek és telek-színek, a modellek később).
-- Price: R$ (egyszeri dev product, ProductId); MoneyPrice: játékpénzért vehető (F2P).
Shop.TrailOrder = table.freeze({ "Crumbs", "GoldenSparkle", "PaprikaFire", "Rainbow" })
Shop.Trails = table.freeze({
	Crumbs = table.freeze({ Name = "Breadcrumb Trail", Description = "Golden breadcrumbs behind you", MoneyPrice = 1_000_000, Colors = { Color3.fromRGB(240, 190, 90), Color3.fromRGB(190, 120, 50) } }),
	GoldenSparkle = table.freeze({ Name = "Golden Sparkle", Description = "A shining gold trail", Price = 49, ProductId = 0, Colors = { Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 180, 20) }, Glow = true }),
	PaprikaFire = table.freeze({ Name = "Paprika Fire", Description = "Spicy red flames", Price = 79, ProductId = 0, Colors = { Color3.fromRGB(255, 220, 80), Color3.fromRGB(230, 40, 20) }, Glow = true }),
	Rainbow = table.freeze({ Name = "Rainbow Schnitzel", Description = "Every colour at once", Price = 99, ProductId = 0, Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 160, 255) }, Rainbow = true, Glow = true }),
})

-- Telek témák: a telek padlója, platformja, pultja és tábla-oszlopa más színű. Classic: az alap (ingyen).
-- Döntés 2026-11-15: NEM a Shopban – később feloldhatók lesznek (pl. rebirth jutalom); a rendszer kész (CosmeticService).
Shop.ThemeOrder = table.freeze({ "Classic", "ViennaCafe", "VillageWedding", "SpaceBase", "Halloween" })
Shop.Themes = table.freeze({
	Classic = table.freeze({ Name = "Classic Kitchen", Description = "The original look", Free = true }),
	ViennaCafe = table.freeze({ Name = "Vienna Café", Description = "Marble, cream and dark wood", Price = 99, ProductId = 0, Floor = Color3.fromRGB(236, 228, 214), Platform = Color3.fromRGB(92, 60, 40), Counter = Color3.fromRGB(70, 44, 30), Accent = Color3.fromRGB(196, 160, 90), FloorMaterial = Enum.Material.Marble }),
	VillageWedding = table.freeze({ Name = "Village Wedding", Description = "Red, white and festive", Price = 99, ProductId = 0, Floor = Color3.fromRGB(245, 240, 232), Platform = Color3.fromRGB(196, 40, 40), Counter = Color3.fromRGB(150, 30, 30), Accent = Color3.fromRGB(60, 140, 60), FloorMaterial = Enum.Material.WoodPlanks }),
	SpaceBase = table.freeze({ Name = "Space Base", Description = "Steel and neon blue", Price = 149, ProductId = 0, Floor = Color3.fromRGB(60, 66, 80), Platform = Color3.fromRGB(30, 34, 46), Counter = Color3.fromRGB(40, 120, 220), Accent = Color3.fromRGB(80, 255, 220), FloorMaterial = Enum.Material.DiamondPlate }),
	Halloween = table.freeze({ Name = "Halloween", Description = "Pumpkin orange and spooky purple", Price = 149, ProductId = 0, Floor = Color3.fromRGB(60, 40, 70), Platform = Color3.fromRGB(230, 120, 30), Counter = Color3.fromRGB(110, 50, 150), Accent = Color3.fromRGB(255, 160, 40), FloorMaterial = Enum.Material.Slate }),
})

-- GDD 6.1: Robux gombok a telken, ahol a vágy keletkezik (a pad helye: Config.Plot.Pads, RobuxPass kulcs).
-- Ha a játékosnak már megvan a gamepass, a pad "OWNED".

-- GDD 6.5: időzített ajánlat-toastok. Mindegyik csak egyszer jön (data.shop.toasts), és 10 percen belül max 1;
-- az első MinSessionSeconds mp-ben semmi ("2. perc: semmi! Csak élvezze").
Shop.Toasts = table.freeze({
	MinSessionSeconds = 300,
	Gap = 600,
	ShowSeconds = 9,
	List = table.freeze({
		TirelessChefs = table.freeze({ Kind = "Pass", Key = "TirelessChefs", Text = "Your chef fell asleep! Chefs never sleep with" }),
		Lucky = table.freeze({ Kind = "Pass", Key = "Lucky", Text = "Rare schnitzel! Get twice as many with" }),
		RebirthSkip = table.freeze({ Kind = "Skip", Text = "Almost there! Rebirth now and keep everything:" }),
		Starter = table.freeze({ Kind = "Product", Key = "Starter", Text = "Welcome back! One-time offer:" }),
	}),
})

-- GDD 5.1 ⑦: a kódok a Config.Codes-ban vannak (Settings ablak, RewardService).

return table.freeze(Shop)
