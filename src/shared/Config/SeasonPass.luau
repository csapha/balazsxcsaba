-- GDD 6.4: Schnitzel Pass (szezon bérlet, döntés 2026-11-16). 30 napos szezon, 30 szint, két sáv:
--   Free (mindenkinek) és Premium (dev product, szezononként egyszer: Config.Shop.Products.SeasonPremium).
-- Pass XP: játékidő, merge, napi jutalom, playtime ajándék, tojásnyitás, rebirth (Xp tábla lent).
-- A szint ára szintenként nő (Formulas.seasonTierStart); az 1. szint rögtön nyitva van (azonnali első jutalom).
-- Új szezonnál: új Id (a mentés ebből tudja, hogy nullázni kell), új StartsAt / EndsAt, új jutalmak.
--
-- Jutalom fajták (SeasonPassService.grant):
--   { Kind = "Money", Minutes = n }         → n perc bevétel (Formulas.rewardMoney, mint a napi jutalomnál)
--   { Kind = "Tickets", Amount = n }        → n aura ticket
--   { Kind = "Boost", Boost = k, Minutes = n } → időszakos boost (Config.Shop.BoostEffects kulcs)
--   { Kind = "Pet", Pet = id }              → pet (a leltár-limittől függetlenül)
--   { Kind = "Egg", Count = n }             → n Golden Egg nyitás (exkluzív petek)
--   { Kind = "Tokens", Amount = n }         → n rebirth token
--   { Kind = "Trail", Trail = id }          → trail (Config.Shop.Trails), rögtön fel is veszi
local DAY = 86400

local function money(minutes: number)
	return table.freeze({ Kind = "Money", Minutes = minutes })
end
local function tickets(amount: number)
	return table.freeze({ Kind = "Tickets", Amount = amount })
end
local function boost(key: string, minutes: number)
	return table.freeze({ Kind = "Boost", Boost = key, Minutes = minutes })
end
local function tokens(amount: number)
	return table.freeze({ Kind = "Tokens", Amount = amount })
end
local function egg(count: number)
	return table.freeze({ Kind = "Egg", Count = count })
end

return table.freeze({
	Season = table.freeze({
		Id = 1,
		Name = "Crispy Beginnings",
		StartsAt = 1794787200, -- 2026-11-16 00:00 UTC
		EndsAt = 1794787200 + 30 * DAY, -- 2026-12-16 00:00 UTC
	}),
	-- Studióban a lejárt / még el nem kezdődött szezon is fut (teszteléshez)
	StudioAlwaysActive = true,

	-- Szint ára: a t. szinthez (t ≥ 2) TierBase + TierStep × (t − 2) XP kell az előzőtől.
	-- 30 szint összesen 10 440 XP: napi ~30 perc játékkal ~3 hét, napi 1 órával ~1,5 hét.
	TierBase = 150,
	TierStep = 15,

	-- Pass XP források. DailyCap: naponta (UTC) legfeljebb ennyi XP ebből a forrásból.
	Xp = table.freeze({
		Play = 5, -- percenként (online)
		Merge = table.freeze({ Amount = 2, DailyCap = 150 }), -- merge-enként
		Daily = 60, -- napi jutalom felvétele
		Gift = 20, -- playtime ajándék felvétele
		Egg = table.freeze({ Amount = 5, DailyCap = 100 }), -- kikelt petenként
		Rebirth = 250,
	}),

	-- A két sáv jutalmai szintenként (1..30). A Premium a Free-nél jobb, a végén az exkluzív szezon pet.
	-- Rebirth token kevés (döntés 2026-11-16: ne legyen pay-to-win), a Premium inkább kényelem + flex.
	Free = table.freeze({
		money(5), tickets(1), boost("Money", 10), money(10), tickets(2),
		boost("Luck", 10), money(15), tickets(2), boost("Bake", 15), tokens(1),
		money(20), tickets(3), boost("Money", 15), money(25), egg(1),
		tickets(3), boost("Luck", 15), money(30), tickets(4), money(35),
		money(40), boost("Bake", 20), tickets(5), money(50), egg(1),
		boost("Money", 30), tickets(5), money(60), tokens(1),
		table.freeze({ Kind = "Pet", Pet = "SeasonHedgehog" }),
	}),
	Premium = table.freeze({
		boost("Money", 60), money(15), tickets(3), boost("Luck", 30), tokens(1),
		money(30), egg(1), tickets(4), boost("Bake", 30), money(40),
		money(45), tickets(5), boost("Money", 60), egg(1),
		table.freeze({ Kind = "Trail", Trail = "LemonZest" }),
		money(60), tickets(6), boost("ChefEnergy", 60), tokens(1), egg(2),
		money(90), tickets(8), boost("Luck", 60), tokens(2), egg(3),
		money(120), tickets(10), boost("Money", 120), money(150),
		table.freeze({ Kind = "Pet", Pet = "SeasonGriffin" }),
	}),
})
