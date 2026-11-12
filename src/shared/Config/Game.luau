-- GDD 1. fejezet: játék összefoglaló.
return table.freeze({
	Name = "Sell a Schnitzel",

	-- 6 játékos / szerver, mindenkinek saját telek (GDD 1, 15.2).
	-- A Roblox játékbeállításokban (Places > Max Players) is 6-ra kell állítani!
	MaxPlayers = 6,

	-- GDD 7.2 szerint 2 sütőre elég; a 4.3 hangolás (2026-11-12) után 1 sütőre + a második nagy részére,
	-- így az első merge ~20 mp múlva jön (cél: 30–45 mp, de a 30 mp-es szabály fontosabb).
	StartMoney = 100,
	-- Teszteléshez: Studióban ennyi a kezdőpénz (élesben a StartMoney érvényes).
	StudioStartMoney = 1_000_000_000,

	DataStoreIndex = "Schnitzel_v1",

	-- Studióban ne mentsen valódi DataStore-ba (minden teszt tiszta lappal indul).
	-- Állítsd false-ra, ha Studióban a mentést akarod tesztelni.
	StudioMockData = true,
})
