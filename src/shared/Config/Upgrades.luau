-- Fejlesztések: kezek (szorzó) és edzés (passzív + tap bónusz)
local Format = require(script.Parent.Parent.Format)
local Upgrades = {}

Upgrades.hands = {
	{ id = "Bare",   name = "Bare Hands",     cost = 0,     multiplier = 1.0 },
	{ id = "Gloves", name = "Grip Gloves",    cost = 100,   multiplier = 1.5 },
	{ id = "Iron",   name = "Iron Grip",      cost = 600,   multiplier = 2.5 },
	{ id = "Titan",  name = "Titan Hands",    cost = 3500,  multiplier = 4.0 },
	{ id = "Diamond",name = "Diamond Grip",   cost = 20000, multiplier = 7.0 },
	{ id = "Star",   name = "Star Squeeze",   cost = 120000,multiplier = 15.0 },
}

Upgrades.training = {
	{ id = "Couch",    name = "Couch Potato", cost = 0,     passive = 0,    tapBonus = 1.0 },
	{ id = "Jogger",   name = "Jogger",       cost = 150,   passive = 3,    tapBonus = 1.5 },
	{ id = "GymRat",   name = "Gym Rat",      cost = 900,   passive = 20,   tapBonus = 2.5 },
	{ id = "Athlete",  name = "Athlete",      cost = 5000,  passive = 150,  tapBonus = 4.0 },
	{ id = "Champion", name = "Champion",     cost = 30000, passive = 1200, tapBonus = 7.0 },
}

Upgrades.petSlots = {
	{ id = "Slots3", name = "3 Pet Slots", cost = 0,      slots = 3 },
	{ id = "Slots4", name = "4 Pet Slots", cost = 400,    slots = 4 },
	{ id = "Slots5", name = "5 Pet Slots", cost = 2000,   slots = 5 },
	{ id = "Slots6", name = "6 Pet Slots", cost = 10000,  slots = 6 },
	{ id = "Slots7", name = "7 Pet Slots", cost = 50000,  slots = 7 },
	{ id = "Slots8", name = "8 Pet Slots", cost = 250000, slots = 8 },
}

Upgrades.speed = {
	{ id = "Speed1", name = "Normal (16)",    cost = 0,     speed = 16 },
	{ id = "Speed2", name = "Fast (20)",      cost = 120,   speed = 20 },
	{ id = "Speed3", name = "Jogger (24)",    cost = 500,   speed = 24 },
	{ id = "Speed4", name = "Runner (28)",    cost = 2200,  speed = 28 },
	{ id = "Speed5", name = "Sprint (34)",    cost = 9000,  speed = 34 },
	{ id = "Speed6", name = "Lightning (42)", cost = 40000, speed = 42 },
}

local function indexBy(list)
	local byId, byOrder = {}, {}
	for order, entry in ipairs(list) do
		entry.order = order
		byId[entry.id] = entry
		byOrder[order] = entry
	end
	return byId, byOrder
end

Upgrades.handsById, Upgrades.handsByOrder = indexBy(Upgrades.hands)
Upgrades.trainingById, Upgrades.trainingByOrder = indexBy(Upgrades.training)
Upgrades.petSlotsById, Upgrades.petSlotsByOrder = indexBy(Upgrades.petSlots)
Upgrades.speedById, Upgrades.speedByOrder = indexBy(Upgrades.speed)

Upgrades.defaultHands = "Bare"
Upgrades.defaultTraining = "Couch"
Upgrades.defaultPetSlots = "Slots3"
Upgrades.defaultSpeed = "Speed1"

-- UI konfiguráció a kategóriákhoz (színek, címek, ikonok)
Upgrades.categories = {
	{
		id = "hands",
		title = "Grip Strength",
		cardColor = Color3.fromRGB(115, 80, 56), -- meleg barna (mint a referenciaképen az 1. kártya)
		icon = "rbxassetid://10709791437",
		emoji = "🥊",
		levels = Upgrades.hands,
		byOrder = Upgrades.handsByOrder,
		byId = Upgrades.handsById,
		getValueString = function(entry)
			return string.format("%.1fx", entry.multiplier)
		end,
	},
	{
		id = "training",
		title = "Workout Training",
		cardColor = Color3.fromRGB(182, 70, 48), -- rozsda/narancs-vörös (mint a 2. kártya)
		icon = "rbxassetid://10709791133",
		emoji = "🏋️",
		levels = Upgrades.training,
		byOrder = Upgrades.trainingByOrder,
		byId = Upgrades.trainingById,
		getValueString = function(entry)
			return "+" .. Format.number(entry.passive) .. "/s"
		end,
	},
	{
		id = "petSlots",
		title = "Pet Slots",
		cardColor = Color3.fromRGB(118, 42, 155), -- mélylila (mint a referenciaképen a 3. kártya)
		icon = "rbxassetid://10709791133",
		emoji = "🐾",
		levels = Upgrades.petSlots,
		byOrder = Upgrades.petSlotsByOrder,
		byId = Upgrades.petSlotsById,
		getValueString = function(entry)
			return tostring(entry.slots)
		end,
	},
	{
		id = "speed",
		title = "Player Speed",
		cardColor = Color3.fromRGB(32, 130, 180), -- óceánkék / villám
		icon = "rbxassetid://10709791133",
		emoji = "⚡",
		levels = Upgrades.speed,
		byOrder = Upgrades.speedByOrder,
		byId = Upgrades.speedById,
		getValueString = function(entry)
			return tostring(entry.speed)
		end,
	},
}

return Upgrades
