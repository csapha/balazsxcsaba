-- Szorítható objektumok (a mapon egymás után, egyre nehezebbek)
-- weight: "súly" kg-ban (abszurd számok jönnek később)
-- shape: Ball | Block | Cylinder
-- gateRatio: a grip legalább ennyi része kell a súlynak a szorításhoz

local Objects = {}

Objects.list = {
	{ id = "watermelon", name = "Watermelon", weight = 5,          size = 2.2, color = "#3FA34D", shape = "Ball",     gateRatio = 0.4 },
	{ id = "coconut",    name = "Coconut",    weight = 60,         size = 2.0, color = "#7A5230", shape = "Ball",     gateRatio = 0.4 },
	{ id = "tire",       name = "Tire",       weight = 800,        size = 3.0, color = "#2B2F36", shape = "Cylinder", gateRatio = 0.45 },
	{ id = "anvil",      name = "Anvil",      weight = 12000,      size = 2.6, color = "#5A616A", shape = "Block",    gateRatio = 0.5 },
	{ id = "fridge",     name = "Fridge",     weight = 180000,    size = 3.2, color = "#C8D0DA", shape = "Block",    gateRatio = 0.5 },
	{ id = "car",        name = "Car",        weight = 4500000,   size = 5.2, color = "#C0392B", shape = "Block",    gateRatio = 0.55 },
	{ id = "tank",       name = "Tank",       weight = 120000000, size = 6.0, color = "#4B5D3A", shape = "Block",    gateRatio = 0.6 },
	{ id = "boulder",    name = "Boulder",    weight = 8000000000, size = 7.0, color = "#8D8D8D", shape = "Ball",     gateRatio = 0.65 },
}

Objects.byId = {}
for index, object in ipairs(Objects.list) do
	object.index = index
	Objects.byId[object.id] = object
end

-- hány kattintás kell a szorításhoz (a grip és a súly arányából)
function Objects.clicksNeeded(object, grip, config)
	local ratio = grip / math.max(object.weight, 1)
	local t = math.clamp(1 - ratio, 0, 1)
	return math.floor(config.BaseClicks + (config.MaxClicks - config.BaseClicks) * t + 0.5)
end

return Objects
