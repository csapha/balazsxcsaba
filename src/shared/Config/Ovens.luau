-- GDD 3.2 sütők, 4.1-4.2 képletek.
--
-- Bevételi modell (döntés 2026-11-12, "A" változat): minden sütő ugyanolyan tempóban süt,
-- de a magasabb szint TÖBB darabot ad, és minden darab TÖBBET is ér:
--   darab / sütés = UnitGrowth^(n-1)   → Lv1 = 1, Lv2 = 2, Lv3 = 4 ... Lv15 = 16 384
--   $ / darab     = ValueGrowth^(n-1)  → Lv1 = $1, Lv2 = $2, Lv3 = $4 ... Lv15 = $16 384
-- Együtt szintenként 4× bevétel, így a merge mindig duplázza a termelést.
return table.freeze({
	-- GDD 3.1: 10 slot. A bővítés 15 → 20 → 25-re rebirth-jutalom lesz (GDD 3.8, döntés 2026-11-12).
	StartSlots = 10,
	MaxSlots = 25,
	SlotStep = 5,

	BakeInterval = 2, -- mp / schnitzel → 0.5 schnitzel/mp (GDD 4.1)
	UnitGrowth = 2, -- darab / sütés szorzó szintenként
	ValueGrowth = 2, -- $ / darab szorzó szintenként ("B" változat: 1.5)

	BasePrice = 50, -- Gen1 alapár (GDD 4.1: 200 – a 4.3 hangolás után 50)
	-- ár(n) = Alapár_gen × PriceGrowth^n × (1 + n / PriceScale)^PricePower  (n = az aktuális generációban vett sütők)
	-- Döntés (2026-11-12, GDD 4.4 szimulátor alapján): a GDD 4.1 eredeti 1.001^n ára mellett a játék
	-- "elszáll" (a merge miatt a bevétel a vett sütők négyzetével nő), ezért polinomiális ár.
	-- 4.3 hangolás: 50 × (1 + n/10)² – az első sütők olcsók (max ~30 mp várakozás az első 10 percben),
	-- a 100. sütőtől ugyanannyiba kerül, mint a korábbi 200 × (1 + n/20)².
	PriceGrowth = 1,
	PriceScale = 10,
	PricePower = 2,

	-- GDD 3.7: sütő-generációk. Az összes valaha vett sütő száma alapján nyílik a következő;
	-- a váltás a tábla előtti gombbal történik (döntés 2026-11-12). Gen k-ban a gombok Lv k sütőt adnak,
	-- az alapár generációnként × GenerationPriceGrowth. Váltáskor az új alapszint alatti sütők felfejlődnek.
	-- Gen2..Gen6 (a szimulátor alapján: Gen2 ≈ 18 perc, GDD 4.3: 15–20 perc)
	GenerationThresholds = table.freeze({ 1_000, 10_000, 50_000, 200_000, 1_000_000 }),
	GenerationPriceGrowth = 1.8,

	-- FÉLKÉSZ (döntés 2026-11-12, a szimulátorban már így működik, a játékban még nem):
	-- Tele sornál a 100-as gomb a legalacsonyabb sütőbe "vásárol bele": Lv k-hoz 2^(k - alapszint) sütő kell,
	-- és annyit vegyen, amennyi kell, akkor is, ha 100-nál több (különben a sor elakad). A játékban
	-- (OvenService.buyIntoLowest) még a 100-as korlát él.

	-- FÉLKÉSZ – Csillagok (döntés 2026-11-12): ha a sor tele van és minden sütő Lv15, a 100-as gomb csillagot
	-- vesz a legkevesebb csillagú sütőre. Csillagonként +Bonus érték (5★ = 3.5×); a rebirth nullázza.
	-- Kész: képletek (Formulas.starPrice / starTarget / starMultiplier) + szimulátor.
	-- Hátravan: mentés (ovenStars), OvenService (gomb + sütés), RebirthService nullázás, ★ a sütők felett.
	-- A PriceSeconds még nincs véglegesítve (a szimulátor alapján 120 és PriceGrowth 3 a legjobb eddig).
	-- ár = egy Lv15 sütő bevételének (pénzszorzókkal) PriceSeconds mp-e × PriceGrowth^(a sütő csillagai)
	Stars = table.freeze({
		Max = 5,
		Bonus = 0.5,
		PriceSeconds = 600,
		PriceGrowth = 2,
	}),

	-- A gyűjtőtálcának nincs kapacitása: annyit gyűjt, amennyit a sütők sütnek (döntés 2026-11-12).

	-- GDD 3.2 szintnevek. A Color csak a placeholder dobozok színe.
	Levels = table.freeze({
		{ Name = "Rusty Pot", Color = Color3.fromRGB(168, 87, 42) },
		{ Name = "Camping Stove", Color = Color3.fromRGB(90, 160, 70) },
		{ Name = "Brick Oven", Color = Color3.fromRGB(178, 60, 45) },
		{ Name = "Steel Skillet", Color = Color3.fromRGB(162, 170, 180) },
		{ Name = "Grandma's Stove", Color = Color3.fromRGB(240, 225, 190) },
		{ Name = "Oil Fryer", Color = Color3.fromRGB(240, 200, 60) },
		{ Name = "Industrial Fryer", Color = Color3.fromRGB(90, 96, 104) },
		{ Name = "Copper Pan", Color = Color3.fromRGB(200, 110, 60) },
		{ Name = "Golden Fryer", Color = Color3.fromRGB(242, 194, 48) },
		{ Name = "Diamond Fryer", Color = Color3.fromRGB(127, 224, 255) },
		{ Name = "Volcano Fryer", Color = Color3.fromRGB(230, 80, 30) },
		{ Name = "Ice Dragon Oven", Color = Color3.fromRGB(150, 120, 255) },
		{ Name = "Space Fryer", Color = Color3.fromRGB(80, 255, 200) },
		{ Name = "Quantum Tenderizer", Color = Color3.fromRGB(220, 60, 220) },
		{ Name = "The Ultimate Schnitzel Machine", Color = Color3.fromRGB(255, 255, 255) },
	}),
})
