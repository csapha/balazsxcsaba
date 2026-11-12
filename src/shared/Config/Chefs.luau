-- GDD 3.6: chefek (botok). A collectorból a leadó asztalra hordják a schnitzelt.
-- Döntések (2026-11-12): 0 chef az elején, az első olcsó; a fejlesztések globálisak (minden chefre);
-- a Stack sütésben értendő (egy sütés a teljes darabszámával és értékével együtt).
return table.freeze({
	-- +1 Chef: az első FirstPrice, utána HireBase × HireGrowth^(chefek_száma - 1) (GDD 4.1)
	FirstPrice = 1_500, -- 4.3 hangolás: első chef ~3 perc
	HireBase = 7_500,
	HireGrowth = 2.6,
	MaxChefs = 10, -- (rebirth-ökkel 15, GDD 3.8)

	-- Fejleszthető statok: érték = Start + Step × szint (Max-nál megáll), ár = PriceBase × PriceGrowth^szint
	Stats = table.freeze({
		Stack = table.freeze({ Start = 3, Step = 1, Max = 25, PriceBase = 600, PriceGrowth = 1.45 }), -- sütés / kör
		Speed = table.freeze({ Start = 0, Step = 0.03, Max = 1.5, PriceBase = 1_200, PriceGrowth = 1.40 }), -- +% mozgás
		Stamina = table.freeze({ Start = 40, Step = 10, Max = 600, PriceBase = 300, PriceGrowth = 1.35 }), -- mp munka alvás előtt
		AntiSleep = table.freeze({ Start = 10, Step = 5, Max = 60, PriceBase = 1_000, PriceGrowth = 1.50 }), -- mp boost ébresztés után
	}),

	BaseSpeed = 10, -- stud/mp (a játékos alapból 16)
	BoostSpeedMultiplier = 1.5, -- ébresztés utáni Anti-Sleep boost alatt
	SleepTime = 20, -- ennyi mp után magától felkel (GDD 3.6)
	WakeDistance = 12, -- ennyi studon belül tudja a játékos felébreszteni
	PickupTime = 0.4, -- ennyi ideig áll a collectornál / asztalnál (vizuál)

	-- Útvonal pontok (telek-lokális X, Z)
	CollectorPoint = Vector2.new(0, -3.5),
	TablePoint = Vector2.new(0, 29.8),
	RestPoint = Vector2.new(-40, 31), -- a chef-négyzet közepe (Config.Plot.ChefRest)
	LaneSpacing = 1.4, -- a chefek egymás mellett, külön sávban mennek
})
