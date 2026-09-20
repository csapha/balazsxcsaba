-- Szorítható objektumok (a mapon egymás után, egyre nehezebbek)
-- weight: csak a kijelzett fantasy súly; a progressiont a powerRequired vezérli.
-- shape: Ball | Block | Cylinder
-- cashReward: alap jutalom, amit a kisebb cashMultiplier módosít.

local Objects = {}

Objects.list = {
	{ id = "watermelon", name = "Watermelon", weight = 5,          powerRequired = 2,          cashReward = 15,         size = 2.2, color = "#3FA34D", shape = "Ball" },
	{ id = "coconut",    name = "Coconut",    weight = 60,         powerRequired = 45,         cashReward = 180,        size = 2.0, color = "#7A5230", shape = "Ball" },
	{ id = "tire",       name = "Tire",       weight = 800,        powerRequired = 800,        cashReward = 2500,       size = 3.0, color = "#2B2F36", shape = "Cylinder" },
	{ id = "anvil",      name = "Anvil",      weight = 12000,      powerRequired = 14000,      cashReward = 35000,      size = 2.6, color = "#5A616A", shape = "Block" },
	{ id = "fridge",     name = "Fridge",     weight = 180000,     powerRequired = 240000,     cashReward = 500000,     size = 3.2, color = "#C8D0DA", shape = "Block" },
	{ id = "car",        name = "Car",        weight = 4500000,    powerRequired = 4000000,    cashReward = 7500000,    size = 5.2, color = "#C0392B", shape = "Block" },
	{ id = "tank",       name = "Tank",       weight = 120000000,  powerRequired = 70000000,   cashReward = 100000000,  size = 6.0, color = "#4B5D3A", shape = "Block" },
	{ id = "boulder",    name = "Boulder",    weight = 8000000000, powerRequired = 1200000000, cashReward = 1500000000, size = 7.0, color = "#8D8D8D", shape = "Ball" },
}

Objects.byId = {}
for index, object in ipairs(Objects.list) do
	object.index = index
	Objects.byId[object.id] = object
end

function Objects.getRequiredPower(object)
	return math.max(1, object.powerRequired or (object.weight * (object.gateRatio or 1)))
end

function Objects.getCashReward(object)
	return math.max(0, object.cashReward or object.weight)
end

-- A gate-nél még teljes a kihívás. Csak 3x túlerőnél lesz minimumos,
-- így az új tárgyak nem válnak automatikusan háromklikkessé.
function Objects.clicksNeeded(object, grip, config)
	local gate = Objects.getRequiredPower(object)
	local mastery = math.clamp((grip - gate) / (gate * 2), 0, 1)
	return math.floor(config.MaxClicks - (config.MaxClicks - config.BaseClicks) * mastery + 0.5)
end

-- A zóna ugyanazon a Power küszöbön nyílik, ahol a tárgy próbálható.
Objects.unlockCostMultiplier = 1
function Objects.getUnlockCost(object)
	if object.id == "watermelon" then
		return 0
	end
	return math.floor(Objects.getRequiredPower(object) * Objects.unlockCostMultiplier)
end

return Objects
