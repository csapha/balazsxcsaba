-- GDD 1. fejezet: játék összefoglaló.
return table.freeze({
	Name = "Sell a Schnitzel",

	-- 6 játékos / szerver, mindenkinek saját telek (GDD 1, 15.2).
	-- A Roblox játékbeállításokban (Places > Max Players) is 6-ra kell állítani!
	MaxPlayers = 6,

	-- GDD 7.2: pontosan 2 sütőre elég (50 + 61 = 111), így a tutorialban rögtön jön az első merge (döntés 2026-11-15).
	StartMoney = 111,
	-- Teszteléshez: Studióban ennyi a kezdőpénz (élesben a StartMoney érvényes).
	StudioStartMoney = 1_000_000_000,

	DataStoreIndex = "Schnitzel_v1",

	-- Studióban ne mentsen valódi DataStore-ba (minden teszt tiszta lappal indul).
	-- Állítsd false-ra, ha Studióban a mentést akarod tesztelni.
	StudioMockData = true,

	-- GDD 8: Friend Boost – minden Roblox barát ugyanazon a szerveren +10% eladási ár, legfeljebb +50%.
	FriendBoostPerFriend = 0.10,
	FriendBoostMax = 0.50,

	-- GDD 13: Studióban az AnalyticsService kiírja az outputba a funnel lépéseket és a pénz eseményeket.
	AnalyticsDebug = true,
})
