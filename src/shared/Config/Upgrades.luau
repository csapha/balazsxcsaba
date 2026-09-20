-- Fejlesztések: kezek (szorzó) és edzés (passzív + tap bónusz)
local Format = require(script.Parent.Parent.Format)
local Upgrades = {}

Upgrades.hands = {
	{ id = "Bare",    name = "Bare Hands",   cost = 0,       multiplier = 1.0,  cashMultiplier = 1.0 },
	{ id = "Gloves",  name = "Grip Gloves",  cost = 300,     multiplier = 1.25, cashMultiplier = 1.08 },
	{ id = "Iron",    name = "Iron Grip",    cost = 4000,    multiplier = 1.6,  cashMultiplier = 1.18 },
	{ id = "Titan",   name = "Titan Hands",  cost = 45000,   multiplier = 2.1,  cashMultiplier = 1.32 },
	{ id = "Diamond", name = "Diamond Grip", cost = 500000,  multiplier = 2.8,  cashMultiplier = 1.5 },
	{ id = "Star",    name = "Star Squeeze", cost = 5000000, multiplier = 4.0,  cashMultiplier = 1.75 },
}

Upgrades.training = {
	{ id = "Couch",    name = "Couch Potato", cost = 0,      passive = 0,   tapBonus = 1.0 },
	{ id = "Jogger",   name = "Jogger",       cost = 500,    passive = 0.5, tapBonus = 1.2 },
	{ id = "GymRat",   name = "Gym Rat",      cost = 6000,   passive = 3,   tapBonus = 1.5 },
	{ id = "Athlete",  name = "Athlete",      cost = 70000,  passive = 15,  tapBonus = 1.9 },
	{ id = "Champion", name = "Champion",     cost = 800000, passive = 60,  tapBonus = 2.4 },
}

-- Edzés-mozdulatok: a guggolástól a handstand pushupig. Mindegyik saját
-- animációt és nagyobb Erő-bónuszt ad edzés közben.
Upgrades.moves = {
	{ id = "Squat",     name = "Squat",     cost = 0,       animationId = "rbxassetid://140689504024158", tapBonus = 1.0 },
	{ id = "Situp",     name = "Situp",     cost = 750,     animationId = "rbxassetid://111720251209023", tapBonus = 1.15 },
	{ id = "Pushup",    name = "Pushup",    cost = 9000,    animationId = "rbxassetid://101165503163457", tapBonus = 1.4 },
	{ id = "OneArm",    name = "1-Arm",     cost = 100000,  animationId = "rbxassetid://98177146527941",  tapBonus = 1.75 },
	{ id = "Handstand", name = "Handstand", cost = 1200000, animationId = "rbxassetid://75146374626778",  tapBonus = 2.2 },
}

Upgrades.speed = {
	{ id = "Speed1", name = "Normal (16)",    cost = 0,      speed = 16 },
	{ id = "Speed2", name = "Fast (20)",      cost = 350,    speed = 20 },
	{ id = "Speed3", name = "Jogger (24)",    cost = 1500,   speed = 24 },
	{ id = "Speed4", name = "Runner (28)",    cost = 6500,   speed = 28 },
	{ id = "Speed5", name = "Sprint (34)",    cost = 27000,  speed = 34 },
	{ id = "Speed6", name = "Lightning (42)", cost = 120000, speed = 42 },
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
Upgrades.movesById, Upgrades.movesByOrder = indexBy(Upgrades.moves)
Upgrades.speedById, Upgrades.speedByOrder = indexBy(Upgrades.speed)

Upgrades.defaultHands = "Bare"
Upgrades.defaultTraining = "Couch"
Upgrades.defaultMove = "Squat"
Upgrades.defaultSpeed = "Speed1"

-- UI konfiguráció a kategóriákhoz (színek, címek, ikonok)
Upgrades.categories = {
	{
		id = "hands",
		title = "Grip Strength",
		cardColor = Color3.fromRGB(115, 80, 56), -- meleg barna (mint a referenciaképen az 1. kártya)
		icon = "rbxassetid://10709791437",
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
		levels = Upgrades.training,
		byOrder = Upgrades.trainingByOrder,
		byId = Upgrades.trainingById,
		getValueString = function(entry)
			return "+" .. Format.number(entry.passive) .. "/s"
		end,
	},
	{
		id = "move",
		title = "Muscle",
		cardColor = Color3.fromRGB(118, 42, 155), -- mélylila
		icon = "rbxassetid://10709791133",
		levels = Upgrades.moves,
		byOrder = Upgrades.movesByOrder,
		byId = Upgrades.movesById,
		getValueString = function(entry)
			-- Ne a mozdulat nevét írjuk ki (hosszú), hanem az Erő-szorzót.
			local text = string.format("%.2f", entry.tapBonus)
			text = text:gsub("0+$", ""):gsub("%.$", "")
			return "x" .. text
		end,
	},
	{
		id = "speed",
		title = "Player Speed",
		cardColor = Color3.fromRGB(32, 130, 180), -- óceánkék / villám
		icon = "rbxassetid://10709791133",
		levels = Upgrades.speed,
		byOrder = Upgrades.speedByOrder,
		byId = Upgrades.speedById,
		getValueString = function(entry)
			return tostring(entry.speed)
		end,
	},
}

return Upgrades
