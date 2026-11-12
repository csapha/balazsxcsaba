-- GDD 3.5 eladás (pult).
-- A játékos a nála lévő schnitzeleket a pult gyűjtőjébe adja le,
-- az eladó onnan ad el másodpercenként Rate darabot (átlagáron, ha vegyes szintű a készlet).
return table.freeze({
	UnitPrice = 1, -- egy Lv1 darab ára $ (később × rebirth, pet, gamepass, event szorzók)
	TickInterval = 1, -- mp (GDD 12.2: szerver 1 mp-enként számol)

	-- eladás db/mp = max(BaseRate + szint, BaseRate × RateGrowth^szint), egész számra lefelé kerekítve
	-- → fejlesztésenként legalább +1 db/mp, később +25%
	BaseRate = 1,
	RateGrowth = 1.25,

	-- fejlesztés ára = UpgradeBasePrice × UpgradePriceGrowth^szint
	UpgradeBasePrice = 50,
	UpgradePriceGrowth = 1.35,

	-- Pult szint + XP (GDD 3.5, döntés 2026-11-12):
	-- 1 eladott darab = 1 XP; a következő szinthez XpBase × XpGrowth^(szint-1) XP kell (100, 200, 400 ...).
	Counter = table.freeze({
		XpBase = 100,
		XpGrowth = 2,
		LevelUpIncomeSeconds = 30, -- szintlépéskor ennyi mp-nyi bevétel jár egyszeri bónuszként
		PriceBonusPerLevel = 0.02, -- szintenként tartósan +2% eladási ár
		BaseCustomers = 3, -- vendégsor hossza: 3, majd 2 szintenként +1
		LevelsPerCustomer = 2,
		MaxCustomers = 8,
	}),

	-- Szűk keresztmetszet jelzés (GDD 3.5: piros "!" azon a rendszeren, ami épp a bottleneck)
	Bottleneck = table.freeze({
		CollectorSeconds = 20, -- ha a collectorban több vár, mint ennyi mp termelés → vidd el!
		CounterSeconds = 30, -- ha a pultban több vár, mint ennyi mp eladás → fejleszd az eladót!
	}),
})
