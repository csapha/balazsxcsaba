-- Fejlesztések: kezek (szorzó) és edzés (passzív + tap bónusz)
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

Upgrades.defaultHands = "Bare"
Upgrades.defaultTraining = "Couch"

return Upgrades
