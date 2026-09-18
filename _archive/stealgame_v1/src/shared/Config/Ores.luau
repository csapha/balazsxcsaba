-- Ércek (drágakövek) konfigurációja
-- odds: alap esély súly (a ritkaságok aránya, összegük tetszőleges)
-- value: eladási ár darabonként
-- size: placeholder Part méret (stud) - később a mesh váltja
-- color: hex szín (a HUD és a Part is ezt használja)
-- glow: Neon anyag + világítás a ritkáknál

local Ores = {}

Ores.list = {
	{ id = "common",    name = "Kavics",    rarity = "Common",    tier = 1, odds = 60.0, value = 2,     size = 0.5,  color = "#9AA0A6", glow = false, template = "Gem_Common" },
	{ id = "amethyst",  name = "Ametiszt",  rarity = "Uncommon",  tier = 2, odds = 25.0, value = 8,     size = 0.55, color = "#B36FE8", glow = false, template = "Gem_Amethyst" },
	{ id = "sapphire",  name = "Zafír",     rarity = "Rare",      tier = 3, odds = 10.0, value = 30,    size = 0.6,  color = "#4A90E2", glow = false, template = "Gem_Sapphire" },
	{ id = "emerald",   name = "Smaragd",   rarity = "Epic",      tier = 4, odds = 3.5,  value = 150,   size = 0.65, color = "#35C77A", glow = false, template = "Gem_Emerald" },
	{ id = "ruby",      name = "Rubin",     rarity = "Legendary", tier = 5, odds = 1.0,  value = 800,   size = 0.72, color = "#E84A5F", glow = false, template = "Gem_Ruby" },
	{ id = "diamond",   name = "Gyémánt",   rarity = "Mythic",    tier = 6, odds = 0.4,  value = 4000,  size = 0.8,  color = "#BFF3FF", glow = true,  template = "Gem_Diamond" },
	{ id = "starstone", name = "Csillagkő", rarity = "Secret",    tier = 7, odds = 0.1,  value = 25000, size = 0.9,  color = "#FFD447", glow = true,  template = "Gem_Starstone" },
}

Ores.byId = {}
for _, ore in ipairs(Ores.list) do
	Ores.byId[ore.id] = ore
end

-- Súlyozott roll, a csákány luck szorzóval:
-- magasabb tierű ércek súlyát jobban megnöveli a luck.
-- A list paraméterrel csak a létező (van modelljük) ércek közül sorsol.
function Ores.roll(luck, list)
	luck = luck or 0
	list = list or Ores.list
	if #list == 0 then
		return nil
	end

	local total = 0
	local weights = {}
	for i, ore in ipairs(list) do
		local w = ore.odds * (1 + luck * (ore.tier - 1))
		weights[i] = w
		total += w
	end

	local roll = math.random() * total
	local acc = 0
	for i, ore in ipairs(list) do
		acc += weights[i]
		if roll <= acc then
			return ore
		end
	end

	return list[1]
end

return Ores
