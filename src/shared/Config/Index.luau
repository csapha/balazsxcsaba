-- GDD 3.11: Index (gyűjtemény). Kategória teljesítéséért állandó pénzbónusz.
-- A felfedezések mentése később jön (döntés 2026-11-12), addig csak a menet végéig élnek.
-- (Petek, aurák, chefek a saját rendszerükkel együtt kerülnek ide.)
return table.freeze({
	Bonuses = table.freeze({
		Ovens = 0.10, -- összes sütő felfedezve: +10% pénz
		Rarities = 0.10, -- összes schnitzel ritkaság felfedezve: +10% pénz
		Pets = 0.15, -- összes pet felfedezve: +15% pénz
		Auras = 0.15, -- összes aura felfedezve: +15% pénz
	}),
})
