-- Csákány szintek
-- order: a fejlődési sorrend (1 = alap)
-- cost: ár cash-ben
-- luck: ritkaság-szerencse szorzó (lásd Ores.roll)
-- speed: ütési cooldown szorzó (nagyobb = gyorsabb)
-- color: a HUD-ban megjelenő szín

local Pickaxes = {}

Pickaxes.defaultId = "Default"

Pickaxes.list = {
	{ id = "Default", name = "Basic Pickaxe",   order = 1, cost = 0,     luck = 0.0, speed = 1.00, color = "#74D2FA" },
	{ id = "Stone",   name = "Stone Pickaxe",   order = 2, cost = 100,   luck = 0.25, speed = 1.15, color = "#9AA0A6" },
	{ id = "Iron",    name = "Iron Pickaxe",    order = 3, cost = 500,   luck = 0.6, speed = 1.30, color = "#C2C8CF" },
	{ id = "Gold",    name = "Gold Pickaxe",    order = 4, cost = 2000,  luck = 1.2, speed = 1.50, color = "#FFD447" },
	{ id = "Diamond", name = "Diamond Pickaxe", order = 5, cost = 8000,  luck = 2.5, speed = 1.75, color = "#BFF3FF" },
	{ id = "Star",    name = "Star Pickaxe",    order = 6, cost = 40000, luck = 5.0, speed = 2.00, color = "#FF9AE0" },
}

Pickaxes.byId = {}
Pickaxes.byOrder = {}
for _, tier in ipairs(Pickaxes.list) do
	Pickaxes.byId[tier.id] = tier
	Pickaxes.byOrder[tier.order] = tier
end

return Pickaxes
