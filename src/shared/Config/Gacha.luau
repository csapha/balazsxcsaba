-- Gacha konfiguráció: Ládák és Kesztyű-anyagok (Design Doc 4.5)
local Gacha = {}

-- Kesztyű-anyagok (szorzók x1.1 - x25)
Gacha.materials = {
	Rubber = {
		id = "Rubber",
		name = "Rubber",
		multiplier = 1.1,
		rarity = "Common",
		color = Color3.fromRGB(160, 168, 175),
		emoji = "🧤",
		tier = 1,
	},
	Iron = {
		id = "Iron",
		name = "Iron",
		multiplier = 1.5,
		rarity = "Uncommon",
		color = Color3.fromRGB(130, 170, 210),
		emoji = "🛡️",
		tier = 2,
	},
	Titanium = {
		id = "Titanium",
		name = "Titanium",
		multiplier = 2.5,
		rarity = "Rare",
		color = Color3.fromRGB(70, 145, 245),
		emoji = "⚔️",
		tier = 3,
	},
	Diamond = {
		id = "Diamond",
		name = "Diamond",
		multiplier = 5.0,
		rarity = "Epic",
		color = Color3.fromRGB(0, 230, 255),
		emoji = "💎",
		tier = 4,
	},
	Star = {
		id = "Star",
		name = "Star",
		multiplier = 10.0,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 215, 0),
		emoji = "⭐",
		tier = 5,
	},
	Secret = {
		id = "Secret",
		name = "Secret Matter",
		multiplier = 25.0,
		rarity = "Secret",
		color = Color3.fromRGB(255, 20, 147),
		emoji = "🌌",
		tier = 6,
	},
}

-- Pity küszöb (20 nyitás után garantált Epic+)
Gacha.pityThreshold = 20
Gacha.pityPool = {
	{ material = "Diamond", weight = 70 },
	{ material = "Star", weight = 25 },
	{ material = "Secret", weight = 5 },
}

-- Ládák konfigurációja
Gacha.chests = {
	{
		id = "Wooden",
		name = "Wooden Chest",
		cost = 1000,
		color = Color3.fromRGB(139, 90, 43),
		icon = "📦",
		pool = {
			{ material = "Rubber", weight = 7000 },
			{ material = "Iron", weight = 2500 },
			{ material = "Titanium", weight = 490 },
			{ material = "Diamond", weight = 10 },
		},
	},
	{
		id = "Silver",
		name = "Silver Chest",
		cost = 25000,
		color = Color3.fromRGB(170, 182, 192),
		icon = "🥈",
		pool = {
			{ material = "Iron", weight = 5500 },
			{ material = "Titanium", weight = 3500 },
			{ material = "Diamond", weight = 950 },
			{ material = "Star", weight = 50 },
		},
	},
	{
		id = "Golden",
		name = "Golden Chest",
		cost = 500000,
		color = Color3.fromRGB(230, 185, 0),
		icon = "🏆",
		pool = {
			{ material = "Titanium", weight = 4500 },
			{ material = "Diamond", weight = 4000 },
			{ material = "Star", weight = 1400 },
			{ material = "Secret", weight = 100 },
		},
	},
	{
		id = "Cosmic",
		name = "Cosmic Chest",
		cost = 10000000,
		color = Color3.fromRGB(142, 36, 170),
		icon = "🌌",
		pool = {
			{ material = "Diamond", weight = 5000 },
			{ material = "Star", weight = 4200 },
			{ material = "Secret", weight = 800 },
		},
	},
}

Gacha.chestsById = {}
for _, chest in ipairs(Gacha.chests) do
	Gacha.chestsById[chest.id] = chest
end

return Gacha

