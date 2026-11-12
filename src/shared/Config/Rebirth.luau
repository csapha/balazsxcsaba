-- GDD 3.8: Rebirth. Követelmény: ennyi pénzt kell keresni az utolsó rebirth óta (Data.cycleEarned).
-- (A GDD eredetileg "X sütő megvásárlása" – a balance szimulátor szerint az elakad, ha minden slot Lv15,
--  ezért keresett pénz lett; döntés 2026-11-12. A generációk továbbra is vett sütőhöz kötöttek.)
-- Döntések (2026-11-12):
--   teljes újrakezdés (pénz, sütők, generáció, eladó, chefek, pult, készletek);
--   megmarad: rebirth szám, tokenek, slotok, Index, statisztikák;
--   az 1–3. rebirth +4 slotot ad (10 → 14 → 18 → 22, szimmetrikusan);
--   a tokenek most gyűlnek, a rebirth-fa később jön (3.13 után); skinek / világok később.
return table.freeze({
	-- az 1., 2., 3., 4. rebirth követelménye ($ keresett pénz); utána mindig az előző × RequirementGrowth
	-- (a balance szimulátorral hangolva: tools/sim/simulate.luau)
	-- szimuláció (5 futás, aktív játékos): Rebirth 1 ≈ 40 perc, Rebirth 2 ≈ 2 óra, Rebirth 5 ≈ 8 óra (GDD 4.3)
	Requirements = table.freeze({ 1e12, 3e14, 1.2e15, 2.8e15 }),
	RequirementGrowth = 1.6,

	-- pénzszorzó: x(1 + rebirthek száma) → 1. = x2, 2. = x3, 3. = x4, 4. = x5, utána +1 / rebirth

	SlotsPerRebirth = 4,
	SlotRebirths = 3, -- az első ennyi rebirth ad slotot

	-- extra max chef rebirth-ök után (GDD 3.8: 3. rebirth +1 max chef)
	ChefBonus = table.freeze({ [3] = 1 }),

	TokensPerRebirth = 1,

	-- Rebirth-fa (GDD 3.8): állandó perkek Rebirth Tokenért, szintenként TokenCost token.
	-- Döntés (2026-11-12): mind a négy csoport; a fa a Rebirth ablak külön fülén.
	Tree = table.freeze({
		TokenCost = 1,
		Order = table.freeze({ "Money", "StartMoney", "StartChefs", "StartGeneration", "OfflineTime", "OfflineRate" }),
		Perks = table.freeze({
			Money = table.freeze({ Name = "Pénz", Description = "+10% pénz szintenként", Step = 0.10, Max = 5 }),
			StartMoney = table.freeze({ Name = "Kezdőpénz", Description = "×10 kezdőpénz rebirth után", Step = 10, Max = 3 }),
			StartChefs = table.freeze({ Name = "Kezdő chefek", Description = "+1 chef rebirth után", Step = 1, Max = 3 }),
			StartGeneration = table.freeze({ Name = "Kezdő generáció", Description = "+1 sütő-generáció rebirth után", Step = 1, Max = 2 }),
			OfflineTime = table.freeze({ Name = "Offline idő", Description = "+2 óra offline kereset", Step = 2 * 60 * 60, Max = 5 }),
			OfflineRate = table.freeze({ Name = "Offline arány", Description = "+10% offline kereset", Step = 0.10, Max = 3 }),
		}),
	}),

	-- A rebirth ablakban "hamarosan"-ként jelennek meg (a tényleges tartalom később jön)
	ComingSoon = table.freeze({
		[2] = "Új telek-skin",
		[4] = "Új világ: Bécsi Kávéház",
	}),
	WorldEvery = 5, -- minden 5. rebirth-nél új világ (hamarosan)
})
