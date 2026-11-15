-- GDD 12.2: anti-exploit. A kliens → szerver remote-ok sebességkorlátja (Lib/Guard) és a távolság-ellenőrzések.
-- Rate: ennyi kérés / mp jön vissza folyamatosan, Burst: ennyi mehet egyszerre (token bucket).
-- A felhasználói tempónál jóval bőkezűbb, csak a spammelést (exploit, makró) vágja le.
return table.freeze({
	DefaultLimit = table.freeze({ Rate = 5, Burst = 10 }),
	RemoteLimits = table.freeze({
		WakeChef = table.freeze({ Rate = 4, Burst = 8 }),
		RequestRebirth = table.freeze({ Rate = 0.5, Burst = 2 }),
		PetAction = table.freeze({ Rate = 8, Burst = 20 }), -- több pet törlése gyorsan egymás után
		AuraAction = table.freeze({ Rate = 4, Burst = 8 }),
		ClaimOffline = table.freeze({ Rate = 0.5, Burst = 2 }),
		BuyPerk = table.freeze({ Rate = 4, Burst = 10 }),
		ClaimDaily = table.freeze({ Rate = 1, Burst = 3 }),
		ClaimPlaytime = table.freeze({ Rate = 2, Burst = 6 }),
		RedeemCode = table.freeze({ Rate = 0.5, Burst = 3 }),
		SaveSettings = table.freeze({ Rate = 2, Burst = 6 }),
		ShopBuy = table.freeze({ Rate = 2, Burst = 5 }),
		ToastSeen = table.freeze({ Rate = 2, Burst = 5 }),
		CosmeticAction = table.freeze({ Rate = 4, Burst = 8 }),
		TutorialIntroDone = table.freeze({ Rate = 0.5, Burst = 2 }),
		TutorialSkip = table.freeze({ Rate = 0.5, Burst = 2 }),
	}),

	-- Távolság-ellenőrzés (stud): a ProximityPrompt / Touched mellé a szerver is megnézi, hol áll a játékos.
	EggOpenSlack = 6, -- a tojás prompt MaxActivationDistance-a (Config.Pets.Plaza.OpenDistance) + ennyi
	StormPickupDistance = 12, -- Panírvihar: a lehulló schnitzel ennyire lehet a karaktertől felvételkor
})
