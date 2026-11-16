-- GDD 3.9: petek ("Panírtojás"). Döntések (2026-11-12):
--   közös "Tojás tér" az utca közepén, 4 fix árú tojás; mind a 4 bónusztípus;
--   leltár + felszerelés + törlés + arany pet (5 azonos → 1 arany) most készül.
-- A Robux tojás a 6. fejezetben jön, a szép tojásnyitás VFX a 10.-ben.
local Palette = require(script.Parent.Palette)

local Pets = {}

-- Pet ritkaságok (a tojás esélyeitől független "címke" + szín)
Pets.Rarities = table.freeze({
	Common = table.freeze({ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Order = 1 }),
	Uncommon = table.freeze({ Name = "Uncommon", Color = Color3.fromRGB(110, 220, 110), Order = 2 }),
	Rare = table.freeze({ Name = "Rare", Color = Color3.fromRGB(80, 160, 255), Order = 3 }),
	Epic = table.freeze({ Name = "Epic", Color = Color3.fromRGB(190, 100, 255), Order = 4 }),
	Legendary = table.freeze({ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Order = 5, Announce = true }),
	-- csak Robuxból (Golden Egg) vagy a VIP gamepassból szerezhető petek (GDD 6.2–6.3)
	Exclusive = table.freeze({ Name = "Exclusive", Color = Color3.fromRGB(255, 90, 200), Order = 6, Announce = true }),
})

-- Bónusztípusok (GDD 3.9): az aktív petek bónuszai típusonként összeadódnak, a szorzó = 1 + összeg.
Pets.Bonuses = table.freeze({
	Money = "Money", -- eladási ár
	BakeSpeed = "Baking", -- sütési sebesség (rövidebb sütési idő)
	Luck = "Luck", -- ritkaság-esélyek (a "Sima" kivételével)
	ChefSpeed = "Chef Speed", -- chefek mozgási sebessége
})

-- A petek (placeholder színek; később modellek). Value: +bónusz (0.10 = +10%).
Pets.List = table.freeze({
	-- 1. tojás
	Kutyus = table.freeze({ Name = "Mallet Pup", Rarity = "Common", Bonus = "Money", Value = 0.10, Color = Color3.fromRGB(205, 160, 110) }),
	Macska = table.freeze({ Name = "Crumb Cat", Rarity = "Common", Bonus = "BakeSpeed", Value = 0.10, Color = Color3.fromRGB(240, 200, 120) }),
	Csibe = table.freeze({ Name = "Egg Chick", Rarity = "Uncommon", Bonus = "Luck", Value = 0.20, Color = Color3.fromRGB(255, 230, 90) }),
	Cica = table.freeze({ Name = "Lemon Kitty", Rarity = "Rare", Bonus = "ChefSpeed", Value = 0.25, Color = Color3.fromRGB(255, 240, 120) }),
	-- 2. tojás
	Tacsko = table.freeze({ Name = "Sausage Dachshund", Rarity = "Uncommon", Bonus = "Money", Value = 0.25, Color = Color3.fromRGB(170, 70, 50) }),
	Beka = table.freeze({ Name = "Pickle Frog", Rarity = "Uncommon", Bonus = "ChefSpeed", Value = 0.30, Color = Color3.fromRGB(120, 200, 90) }),
	Nyuszi = table.freeze({ Name = "Parsley Bunny", Rarity = "Rare", Bonus = "Luck", Value = 0.40, Color = Color3.fromRGB(80, 170, 70) }),
	Bagoly = table.freeze({ Name = "Wooden Spoon Owl", Rarity = "Epic", Bonus = "BakeSpeed", Value = 0.40, Color = Color3.fromRGB(160, 110, 60) }),
	-- 3. tojás
	Malac = table.freeze({ Name = "Potato Salad Piggy", Rarity = "Rare", Bonus = "Money", Value = 0.60, Color = Color3.fromRGB(255, 180, 190) }),
	Mehecske = table.freeze({ Name = "Mustard Bee", Rarity = "Rare", Bonus = "BakeSpeed", Value = 0.60, Color = Color3.fromRGB(240, 190, 40) }),
	Roka = table.freeze({ Name = "Fried Onion Fox", Rarity = "Epic", Bonus = "ChefSpeed", Value = 0.80, Color = Color3.fromRGB(230, 130, 50) }),
	Sarkany = table.freeze({ Name = "Paprika Dragon", Rarity = "Legendary", Bonus = "Money", Value = 1.50, Color = Color3.fromRGB(230, 50, 40) }),
	-- 4. tojás
	Borju = table.freeze({ Name = "Viennese Calf", Rarity = "Epic", Bonus = "BakeSpeed", Value = 1.20, Color = Color3.fromRGB(235, 210, 170) }),
	Ponty = table.freeze({ Name = "Breaded Carp", Rarity = "Epic", Bonus = "Luck", Value = 1.50, Color = Color3.fromRGB(210, 150, 70) }),
	NagyiMacska = table.freeze({ Name = "Grandma's Cat", Rarity = "Legendary", Bonus = "Money", Value = 3.00, Color = Color3.fromRGB(150, 150, 160) }),
	Fonix = table.freeze({ Name = "Golden Mallet Phoenix", Rarity = "Legendary", Bonus = "BakeSpeed", Value = 2.50, Color = Color3.fromRGB(255, 120, 30) }),
	-- Exkluzív petek (döntés 2026-11-15): kicsit erősebbek a 4. tojás petjeinél, csak Robuxból / VIP-ből.
	-- Nem számítanak az Indexbe (különben az Index teljesítése Robuxba kerülne).
	GoldPig = table.freeze({ Name = "Golden Crackling Pig", Rarity = "Epic", Bonus = "Money", Value = 2.00, Color = Color3.fromRGB(255, 205, 80), Exclusive = true }),
	LemonDragon = table.freeze({ Name = "Lemon Zest Dragon", Rarity = "Legendary", Bonus = "Luck", Value = 2.50, Color = Color3.fromRGB(250, 240, 90), Exclusive = true }),
	ChefBear = table.freeze({ Name = "Head Chef Bear", Rarity = "Legendary", Bonus = "ChefSpeed", Value = 3.00, Color = Color3.fromRGB(250, 250, 245), Exclusive = true }),
	SchnitzelKing = table.freeze({ Name = "Schnitzel King", Rarity = "Exclusive", Bonus = "Money", Value = 4.00, Color = Color3.fromRGB(255, 170, 40), Exclusive = true }),
	VipPoodle = table.freeze({ Name = "VIP Golden Poodle", Rarity = "Exclusive", Bonus = "BakeSpeed", Value = 2.00, Color = Color3.fromRGB(255, 215, 0), Exclusive = true }),
	-- Schnitzel Pass 1. szezon (Config.SeasonPass): a Free sáv 30. szintje és a Premium sáv 30. szintje.
	-- Csak a szezonban szerezhetők, ezért ezek sem számítanak az Indexbe.
	SeasonHedgehog = table.freeze({ Name = "Crispy Hedgehog", Rarity = "Epic", Bonus = "Luck", Value = 1.50, Color = Color3.fromRGB(196, 132, 60), Exclusive = true }),
	SeasonGriffin = table.freeze({ Name = "Golden Schnitzel Griffin", Rarity = "Exclusive", Bonus = "Money", Value = 3.50, Color = Color3.fromRGB(255, 196, 60), Exclusive = true }),
})

-- Megjelenítési sorrend (UI, Index)
Pets.Order = table.freeze({
	"Kutyus", "Macska", "Csibe", "Cica",
	"Tacsko", "Beka", "Nyuszi", "Bagoly",
	"Malac", "Mehecske", "Roka", "Sarkany",
	"Borju", "Ponty", "NagyiMacska", "Fonix",
})

-- Tojások: fix ár, súlyozott esélyek (%)
Pets.Eggs = table.freeze({
	table.freeze({
		Name = "Breadcrumb Egg",
		Price = 100_000, -- 4.3 hangolás: első tojás ~7–8 perc
		Color = Palette.Gold,
		Pets = table.freeze({ { "Kutyus", 55 }, { "Macska", 30 }, { "Csibe", 12 }, { "Cica", 3 } }),
	}),
	table.freeze({
		Name = "Spicy Egg",
		Price = 1_000_000,
		Color = Color3.fromRGB(220, 90, 50),
		Pets = table.freeze({ { "Tacsko", 50 }, { "Beka", 30 }, { "Nyuszi", 15 }, { "Bagoly", 5 } }),
	}),
	table.freeze({
		Name = "Garden Egg",
		Price = 100_000_000,
		Color = Color3.fromRGB(110, 200, 90),
		Pets = table.freeze({ { "Malac", 50 }, { "Mehecske", 30 }, { "Roka", 15 }, { "Sarkany", 5 } }),
	}),
	table.freeze({
		Name = "Grandma's Golden Egg",
		Price = 10_000_000_000,
		Color = Palette.RarityGold,
		Pets = table.freeze({ { "Borju", 50 }, { "Ponty", 30 }, { "NagyiMacska", 15 }, { "Fonix", 5 } }),
	}),
})

-- Golden Egg (GDD 6.3 Robux tojás, 1x / 3x / 10x): csak Robuxért, exkluzív petek. Nincs a Tojás téren.
Pets.RobuxEgg = table.freeze({
	Name = "Golden Egg",
	Color = Color3.fromRGB(255, 200, 40),
	Pets = table.freeze({ { "GoldPig", 55 }, { "LemonDragon", 25 }, { "ChefBear", 15 }, { "SchnitzelKing", 5 } }),
})
Pets.VipPet = "VipPoodle" -- a VIP gamepass ajándék petje (egyszer)
Pets.ExclusiveOrder = table.freeze({ "GoldPig", "LemonDragon", "ChefBear", "SchnitzelKing", "VipPoodle", "SeasonHedgehog", "SeasonGriffin" })

Pets.ActiveSlots = 3 -- egyszerre aktív petek (gamepass: +1, GDD 6.2)
Pets.FastEggCooldown = 0.4 -- Fast Open gamepass: ennyi mp két nyitás között (alap: lásd PetService)
Pets.MultiOpenCount = 3 -- Open 3 Eggs gamepass: egyszerre ennyi tojás (külön "Open 3" prompt a tojásnál)
Pets.MaxInventory = 50
Pets.GoldenCount = 5 -- ennyi azonos pet → 1 arany
Pets.GoldenMultiplier = 3 -- az arany pet bónusza ennyiszeres

-- Tojás tér az utca közepén (világ koordináták)
Pets.Plaza = table.freeze({
	Center = Vector3.new(0, 0, 0),
	Spacing = 14, -- a tojások közötti távolság (X)
	OpenDistance = 10, -- "Nyisd ki" prompt távolsága
})

return table.freeze(Pets)
