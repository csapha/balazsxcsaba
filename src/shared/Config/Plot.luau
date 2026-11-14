-- GDD 3.1: telek elrendezés, telek-lokális koordinátákban.
-- X: balról jobbra, Z: hátul (-) → elöl (+, utca felé). A telek közepe (0, 0, 0).
--
-- Elrendezés (hátulról előre):
--   emelt platform (sütők két sorban, köztük futószalag, ami középre szállít)
--   → csúszda le a fal tövébe → Collector (itt veszi fel a játékos)
--   → MERGE pad, mellette balra 3, jobbra 3 vásárló gomb (a 6. hely a Robux gombnak marad, GDD 6. fejezet)
--   → jóval előrébb, középen az eladás (eladó fejlesztés | leadás + pult | pénz raklap)
-- Minden szimmetrikus a középvonalra (X = 0).
local Palette = require(script.Parent.Palette)

return table.freeze({
	Size = Vector2.new(120, 100), -- X × Z
	FloorTop = 0.2,

	-- 6 telek: 2 sor × 3, középen utca (lásd Formulas.plotOrigin)
	Columns = 3,
	SpacingX = 130,
	RowOffsetZ = 70,

	Spawn = Vector3.new(0, 0, 19),
	SpawnLookAt = Vector3.new(0, 0, -8),

	-- Emelt platform a sütőknek (a játékos szintje fölött); az eleje a "fal" a collector mögött.
	Platform = table.freeze({
		Height = 4,
		FrontZ = -12,
	}),

	-- 1. Sütősor: két sor a futószalag két oldalán, egymással szemben, szimmetrikusan.
	-- A slotok középről kifelé, felváltva bal–jobb párokban töltődnek:
	--   1–12: hátsó sor (6 bal + 6 jobb), 13–24: első sor (6 + 6, középen a csúszda),
	--   25: a hátsó sor közepe.
	Ovens = table.freeze({
		BackZ = -29,
		FrontZ = -15,
		PerSide = 6,
		Spacing = 6.5,
		Size = Vector3.new(5, 4, 5),
	}),

	-- 2. Futószalag: mindkét oldalról középre (X = 0), onnan a csúszdán le a collectorba.
	Conveyor = table.freeze({
		Z = -22,
		HalfLength = 45,
		Width = 4,
		Height = 1,
		Speed = 14, -- stud/mp (a szerver is ezzel számolja, mikor ér a collectorba)
	}),

	-- 6. Eladópult (a vendégek a pult utca felőli oldalán állnak sorba)
	Counter = table.freeze({
		Position = Vector2.new(0, 38),
		Size = Vector3.new(16, 4, 3),
	}),

	-- Vendégsor: a telek tulajdonosának Roblox barátai a saját avatarjukkal (CustomerService).
	-- Az utcáról (Entry) sétálnak be a sor végére; ha a pult elad, az első kiszolgálva
	-- a kijárati sávon (ExitLaneX) át az utca másik irányába (Exit) távozik.
	-- A sor hossza a pult szintjétől függ (Config.Sell.Counter); LineLength után balra fordul (L alak).
	Customers = table.freeze({
		FirstOffset = 3.5, -- a sor eleje a pulttól (Z)
		Spacing = 3,
		LineLength = 3, -- ennyi vendég áll egyenesen a pult előtt, a többi balra sorakozik
		WalkSpeed = 10,
		StreetZ = 56, -- az utcán ezen a vonalon sétálnak (a telek eleje 50-nél van)
		EntryX = -50,
		ExitX = 50,
		ExitLaneX = 6, -- a kiszolgált vendég ezen a sávon megy ki, a sor mellett
		ServeTime = 1.2, -- legalább ennyit áll a pultnál
		ServeInterval = 2.5, -- max ennyi mp-enként szolgálnak ki egy vendéget (csak vizuál)
		SaleWindow = 2, -- akkor szolgálnak ki, ha az utolsó eladás ennél frissebb (mp)
	}),

	-- Ritkaság-esély tábla a falon, a collector mellett
	RarityBoard = table.freeze({
		X = 15,
		Size = Vector2.new(18, 3.4),
	}),

	-- Tulajdonos tábla
	Sign = Vector2.new(56, 46), -- jobb első sarok (a bal oldalt a chef-részleg foglalja)

	-- Rálépős padek. Position = (X, Z) közép, Size = (X, Z) méret.
	-- BuyCount: sütővásárló gomb (annyit rak le, amennyi hely és pénz van).
	-- AutoMerge: ha megtelik a sor, merge-el és folytatja (csak a 100-as gomb, döntés 2026-11-12);
	-- ha nincs pár sem, a legalacsonyabb sütőbe vesz bele (soha nem akad el).
	-- Height / Flat: nem neon, magasabb pad (pl. a collector). LabelHeight: a felirat magassága a pad felett.
	-- Table: asztal (lap + lábak), Reach: ennyi studon belül a padtól már aktiválódik (rálépés nélkül).
	-- LabelWidth: a felirat szélessége studban (alapból a pad szélessége, min. 7).
	Pads = table.freeze({
		-- Collector: ide érkeznek a schnitzelek, rálépve felveszed (GDD 3.5)
		Pickup = table.freeze({
			Position = Vector2.new(0, -8.5),
			Size = Vector2.new(10, 7),
			Height = 0.6,
			Flat = true,
			Color = Palette.Tray,
			Title = "Collector",
		}),

		-- 4. Merge-pad a collector előtt
		Merge = table.freeze({
			Position = Vector2.new(0, 8),
			Size = Vector2.new(9, 9),
			Color = Palette.Merge,
			Title = "MERGE",
		}),

		-- 3. Vásárló gombok: balra 3, jobbra 2 (+ a 25.5-ös hely a Robux gombnak)
		BuyOne = table.freeze({
			Position = Vector2.new(-25.5, 8),
			Size = Vector2.new(6, 6),
			Color = Palette.Gold,
			Title = "Buy 1",
			BuyCount = 1,
		}),
		BuyThree = table.freeze({
			Position = Vector2.new(-17.5, 8),
			Size = Vector2.new(6, 6),
			Color = Palette.Gold,
			Title = "Buy 3",
			BuyCount = 3,
		}),
		BuyFive = table.freeze({
			Position = Vector2.new(-9.5, 8),
			Size = Vector2.new(6, 6),
			Color = Palette.Gold,
			Title = "Buy 5",
			BuyCount = 5,
		}),
		BuyFifteen = table.freeze({
			Position = Vector2.new(9.5, 8),
			Size = Vector2.new(6, 6),
			Color = Palette.Gold,
			Title = "Buy 15",
			BuyCount = 15,
		}),
		BuyHundred = table.freeze({
			Position = Vector2.new(17.5, 8),
			Size = Vector2.new(6, 6),
			Color = Palette.Lemon,
			Title = "Buy 100 (Auto Merge)",
			BuyCount = 100,
			AutoMerge = true,
		}),

		-- Eladás: középen, jóval a merge előtt (balra fejlesztés, középen leadás a pult előtt, jobbra pénz)
		SellUpgrade = table.freeze({
			Position = Vector2.new(-15, 29),
			Size = Vector2.new(7, 7),
			Color = Palette.Gold,
			Title = "Sell Speed",
		}),
		-- Leadó asztal közvetlenül a pult előtt: odasétálsz, és a fejeden lévő schnitzelek rárepülnek.
		-- Az asztalon látszik a pultban eladásra váró készlet.
		Deposit = table.freeze({
			Position = Vector2.new(0, 33),
			Size = Vector2.new(10, 4),
			Height = 3, -- asztallap magassága
			Table = true,
			Reach = 3, -- ennyi studon belül az asztaltól már lead (nem kell ráállni)
			Color = Palette.Wood,
			Title = "Drop Off",
			LabelHeight = 2.2,
		}),
		Collect = table.freeze({
			Position = Vector2.new(15, 29),
			Size = Vector2.new(7, 7),
			Color = Palette.Wood,
			Title = "Cash",
		}),

		-- 8. Generáció váltás a tábla előtt (GDD 3.7): akkor világít, ha elérted a küszöböt
		GenUpgrade = table.freeze({
			Position = Vector2.new(48, 31),
			Size = Vector2.new(8, 8),
			Color = Palette.Locked,
			Title = "Next Generation",
			LabelWidth = 10,
		}),

		-- 5. Chef-részleg (GDD 3.1, 3.6): a telek bal első részén egy "U" alakú négyzet,
		-- aminek a pult felé eső (jobb) oldala nyitott:
		--   bal oldal közepén: +1 Chef
		--   felső oldal (a vásárló sor felé): Stack, Gyorsaság
		--   alsó oldal (az utca felé): Kitartás, Ébresztő
		--   a négyzet belsejében: chef pihenő
		ChefHire = table.freeze({
			Position = Vector2.new(-54, 31),
			Size = Vector2.new(8, 8),
			Color = Palette.White,
			Title = "+1 Chef",
			LabelWidth = 9,
		}),
		ChefStack = table.freeze({
			Position = Vector2.new(-48, 18),
			Size = Vector2.new(6, 6),
			Color = Palette.ChefPad,
			Title = "Stack",
			ChefStat = "Stack",
			LabelWidth = 8.5,
		}),
		ChefSpeed = table.freeze({
			Position = Vector2.new(-37, 18),
			Size = Vector2.new(6, 6),
			Color = Palette.ChefPad,
			Title = "Speed",
			ChefStat = "Speed",
			LabelWidth = 8.5,
		}),
		ChefStamina = table.freeze({
			Position = Vector2.new(-48, 44),
			Size = Vector2.new(6, 6),
			Color = Palette.ChefPad,
			Title = "Stamina",
			ChefStat = "Stamina",
			LabelWidth = 8.5,
		}),
		ChefAntiSleep = table.freeze({
			Position = Vector2.new(-37, 44),
			Size = Vector2.new(6, 6),
			Color = Palette.ChefPad,
			Title = "Wake Boost",
			ChefStat = "AntiSleep",
			LabelWidth = 8.5,
		}),
	}),

	-- 8. Sütő-generáció tábla (GDD 3.1, 3.7): a telek jobb szélén, a chef-részleg tükörképeként,
	-- a középre néz; előtte a "Generáció váltás" gomb (Pads.GenUpgrade).
	GenerationBoard = table.freeze({
		Position = Vector2.new(57.5, 31),
		Size = Vector2.new(14, 8), -- szélesség (Z mentén) × magasság
	}),

	-- Chef pihenőhely a chef-négyzet közepén (ide érkeznek az új chefek)
	ChefRest = table.freeze({
		Position = Vector2.new(-40, 31),
		Size = Vector2.new(12, 12),
	}),
})
