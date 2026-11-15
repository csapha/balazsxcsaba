-- GDD 8: napi bejelentkezési jutalom + playtime ajándékok (döntés 2026-11-15).
-- A "nap" UTC naptári nap (os.time() // 86400), mindenkinek egyszerre vált.
--
-- Jutalom fajták:
--   { Kind = "Money", Minutes = n }   → n perc bevétel (a jelenlegi becsült $/mp-ből), legalább n × MinMoneyPerMinute
--   { Kind = "Tickets", Amount = n }  → n aura ticket
--   { Kind = "Pet", Pet = id }        → egy pet a leltárba (ha tele a leltár: PetFallbackMinutes perc bevétel)
-- A jutalom pénz nem számít bele a rebirth követelménybe (az csak az eladásból / offline keresetből jön).
return table.freeze({
	MinMoneyPerMinute = 100, -- az elején (nincs még bevétel) is érjen valamit: 5 perc = legalább $500
	PetFallbackMinutes = 30,

	-- 7 napos sorozat: naponta egyszer vehető fel. Ha kimarad egy nap, újra az 1. naptól; a 7. után is.
	Daily = table.freeze({
		table.freeze({ Kind = "Money", Minutes = 5 }),
		table.freeze({ Kind = "Tickets", Amount = 2 }),
		table.freeze({ Kind = "Money", Minutes = 10 }),
		table.freeze({ Kind = "Tickets", Amount = 3 }),
		table.freeze({ Kind = "Money", Minutes = 20 }),
		table.freeze({ Kind = "Tickets", Amount = 5 }),
		table.freeze({ Kind = "Pet", Pet = "Bagoly" }), -- 7. nap: ritka pet (GDD 8), Epic, +40% sütési sebesség
	}),

	-- Playtime ajándékok: az aznapi (UTC) játékidő alapján nyílnak, mindegyik naponta egyszer vehető fel.
	-- Napi játékidő és nem munkamenet, így kilépés-belépéssel nem lehet újra felvenni.
	Playtime = table.freeze({
		table.freeze({ Minutes = 5, Reward = table.freeze({ Kind = "Money", Minutes = 2 }) }),
		table.freeze({ Minutes = 10, Reward = table.freeze({ Kind = "Tickets", Amount = 1 }) }),
		table.freeze({ Minutes = 15, Reward = table.freeze({ Kind = "Money", Minutes = 5 }) }),
		table.freeze({ Minutes = 25, Reward = table.freeze({ Kind = "Tickets", Amount = 2 }) }),
		table.freeze({ Minutes = 40, Reward = table.freeze({ Kind = "Money", Minutes = 10 }) }),
		table.freeze({ Minutes = 60, Reward = table.freeze({ Kind = "Tickets", Amount = 3 }) }),
	}),
})
