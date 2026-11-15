-- GDD 5.1 ⑦: beváltható kódok (a Settings ablak Codes fülén). Döntés 2026-11-15.
-- A kulcs a kód NAGYBETŰVEL (a beírt kódot nagybetűsítjük és a szóközöket levágjuk), mindegyik egyszer váltható be.
-- Reward: ugyanaz a forma, mint a Config.Rewards jutalmainál ({ Kind = "Money", Minutes = n } / Tickets / Pet),
-- és itt még: { Kind = "Boost", Boost = kulcs, Minutes = n } – a Shop időszakos boostja (Config.Shop.BoostEffects).
-- Expires (nem kötelező): os.time() másodperc, ami után már nem váltható be.
-- Új kódhoz csak egy új sor kell (pl. like-célokhoz, GDD 8: "Új kód 5 600 like-nál!").
return table.freeze({
	SCHNITZEL = table.freeze({ Reward = table.freeze({ Kind = "Money", Minutes = 10 }) }),
	RELEASE = table.freeze({ Reward = table.freeze({ Kind = "Tickets", Amount = 3 }) }),
	NAGYI = table.freeze({ Reward = table.freeze({ Kind = "Tickets", Amount = 3 }) }),
	CRISPY = table.freeze({ Reward = table.freeze({ Kind = "Boost", Boost = "Money", Minutes = 10 }) }),
})
