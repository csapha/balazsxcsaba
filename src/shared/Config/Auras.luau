-- GDD 3.10: aurák – ritka, gacha-szerű kozmetikum + kis bónusz. Döntések (2026-11-12):
--   ticket: 10 perc játékidőnként 1 ingyen (később a playtime-ajándék része, GDD 8) + pénzért is dobható;
--   duplikátum → az aura szintet lép (max 5), a bónusz × szint; 1 aktív aura.
-- Bónusztípusok ugyanazok, mint a peteknél (Config.Pets.Bonuses). A Robux aura dobás a 6. fejezetben jön.
local Auras = {}

Auras.Rarities = table.freeze({
	Common = table.freeze({ Name = "Gyakori", Color = Color3.fromRGB(200, 200, 200), Order = 1 }),
	Uncommon = table.freeze({ Name = "Ritkább", Color = Color3.fromRGB(110, 220, 110), Order = 2 }),
	Rare = table.freeze({ Name = "Ritka", Color = Color3.fromRGB(80, 160, 255), Order = 3 }),
	Epic = table.freeze({ Name = "Epikus", Color = Color3.fromRGB(190, 100, 255), Order = 4 }),
	Legendary = table.freeze({ Name = "Legendás", Color = Color3.fromRGB(255, 190, 40), Order = 5, Announce = true }),
	Mythic = table.freeze({ Name = "Mitikus", Color = Color3.fromRGB(255, 90, 200), Order = 6, Announce = true }),
})

-- Chance: súly (%), Value: bónusz 1. szinten (szintenként × szint).
-- Particle: a kliens részecske-effektje (beépített Roblox textúrák, placeholder).
Auras.List = table.freeze({
	Morzsa = table.freeze({
		Name = "Morzsaeső",
		Rarity = "Common",
		Chance = 40,
		Bonus = "Money",
		Value = 0.02,
		Particle = table.freeze({ Texture = "sparkles", Color = Color3.fromRGB(210, 150, 70), Rate = 18, Speed = -4, Size = 0.35, Spread = 2.5 }),
	}),
	Buborek = table.freeze({
		Name = "Olajbuborék",
		Rarity = "Common",
		Chance = 25,
		Bonus = "BakeSpeed",
		Value = 0.02,
		Particle = table.freeze({ Texture = "sparkles", Color = Color3.fromRGB(255, 220, 90), Rate = 14, Speed = 3, Size = 0.45, Spread = 2 }),
	}),
	Goz = table.freeze({
		Name = "Gőzfelhő",
		Rarity = "Uncommon",
		Chance = 15,
		Bonus = "ChefSpeed",
		Value = 0.04,
		Particle = table.freeze({ Texture = "smoke", Color = Color3.fromRGB(240, 240, 240), Rate = 10, Speed = 2, Size = 1.4, Spread = 1.5 }),
	}),
	Lang = table.freeze({
		Name = "Paprikaláng",
		Rarity = "Rare",
		Chance = 10,
		Bonus = "Money",
		Value = 0.05,
		Particle = table.freeze({ Texture = "fire", Color = Color3.fromRGB(255, 80, 30), Rate = 30, Speed = 4, Size = 1.1, Spread = 1.6, Light = true }),
	}),
	Citrom = table.freeze({
		Name = "Citromszikra",
		Rarity = "Rare",
		Chance = 5,
		Bonus = "Luck",
		Value = 0.06,
		Particle = table.freeze({ Texture = "sparkles", Color = Color3.fromRGB(255, 240, 80), Rate = 30, Speed = 2, Size = 0.6, Spread = 2.2, Light = true }),
	}),
	Jeg = table.freeze({
		Name = "Jégvihar",
		Rarity = "Epic",
		Chance = 3,
		Bonus = "BakeSpeed",
		Value = 0.08,
		Particle = table.freeze({ Texture = "sparkles", Color = Color3.fromRGB(120, 210, 255), Rate = 45, Speed = 5, Size = 0.7, Spread = 2.6, Light = true }),
	}),
	Villam = table.freeze({
		Name = "Villámklopfoló",
		Rarity = "Legendary",
		Chance = 1.5,
		Bonus = "Money",
		Value = 0.12,
		Particle = table.freeze({ Texture = "sparkles", Color = Color3.fromRGB(200, 160, 255), Rate = 60, Speed = 8, Size = 0.9, Spread = 2.8, Light = true }),
	}),
	Szivarvany = table.freeze({
		Name = "Nagyi Szivárványa",
		Rarity = "Mythic",
		Chance = 0.5,
		Bonus = "Money",
		Value = 0.20,
		Particle = table.freeze({ Texture = "sparkles", Rainbow = true, Rate = 70, Speed = 5, Size = 1, Spread = 3, Light = true }),
	}),
})

Auras.Order = table.freeze({ "Morzsa", "Buborek", "Goz", "Lang", "Citrom", "Jeg", "Villam", "Szivarvany" })

Auras.MaxLevel = 5
Auras.FreeTicketInterval = 600 -- mp játékidő → 1 ingyen ticket
Auras.RollIncomeSeconds = 300 -- pénzes dobás ára: ennyi mp-nyi bevétel...
Auras.MinRollPrice = 5_000 -- ...de legalább ennyi
Auras.RollCooldown = 1.5 -- mp (a dobás animáció alatt)

return table.freeze(Auras)
