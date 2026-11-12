-- Index (GDD 3.11): felfedezett sütő szintek, schnitzel ritkaságok, petek és aurák + kategória bónuszok.
-- A felfedezések egyelőre nincsenek mentve (döntés 2026-11-12: a mentés a végére marad), csak a menet
-- végéig élnek – de ami megvan (sütők a sorban, petek a leltárban, aurák), az mindig felfedezettnek számít.
-- A kliens a játékos attribútumaiból olvassa (bitmaszk): IndexOvens, IndexRarities, IndexPets, IndexAuras.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotService = require(script.Parent.PlotService)

local Bonuses = Config.Index.Bonuses

-- kategória → attribútum, elemszám, bónusz
local CATEGORIES = {
	{ attribute = "IndexOvens", count = #Config.Ovens.Levels, bonus = Bonuses.Ovens },
	{ attribute = "IndexRarities", count = #Config.Rarities.List, bonus = Bonuses.Rarities },
	{ attribute = "IndexPets", count = #Config.Pets.Order, bonus = Bonuses.Pets },
	{ attribute = "IndexAuras", count = #Config.Auras.Order, bonus = Bonuses.Auras },
}

local PET_INDEX = {}
for index, id in Config.Pets.Order do
	PET_INDEX[id] = index
end
local AURA_INDEX = {}
for index, id in Config.Auras.Order do
	AURA_INDEX[id] = index
end

local IndexService = {}

local function getMask(player: Player, attribute: string): number
	return player:GetAttribute(attribute) or 0
end

local function discover(player: Player, attribute: string, index: number?): boolean
	if not index then
		return false
	end
	local mask = getMask(player, attribute)
	local bit = 2 ^ (index - 1)
	if bit32.btest(mask, bit) then
		return false
	end
	player:SetAttribute(attribute, bit32.bor(mask, bit))
	return true
end

-- Igaz, ha most fedezte fel először.
function IndexService.discoverOven(player: Player, level: number): boolean
	return discover(player, "IndexOvens", level)
end

function IndexService.discoverRarity(player: Player, rarityIndex: number): boolean
	return discover(player, "IndexRarities", rarityIndex)
end

function IndexService.discoverPet(player: Player, petId: string): boolean
	return discover(player, "IndexPets", PET_INDEX[petId])
end

function IndexService.discoverAura(player: Player, auraId: string): boolean
	return discover(player, "IndexAuras", AURA_INDEX[auraId])
end

-- Pénzszorzó a teljesített kategóriákból (1 = nincs bónusz).
function IndexService.moneyBonus(player: Player): number
	local bonus = 1
	for _, category in CATEGORIES do
		if getMask(player, category.attribute) == 2 ^ category.count - 1 then
			bonus += category.bonus
		end
	end
	return bonus
end

function IndexService.init()
	-- ami megvan (sütők a sorban, petek, aurák), az felfedezett – vásárlás, merge, tojás, dobás, belépés
	PlotService.addRenderer(function(state, raw)
		local player = state.player
		for _, level in raw.ovens do
			if level > 0 then
				IndexService.discoverOven(player, level)
			end
		end
		for _, pet in raw.pets.inventory do
			IndexService.discoverPet(player, pet.id)
		end
		for auraId in raw.auras.owned do
			IndexService.discoverAura(player, auraId)
		end
	end)
end

function IndexService.start()
	local function setup(player: Player)
		for _, category in CATEGORIES do
			if player:GetAttribute(category.attribute) == nil then
				player:SetAttribute(category.attribute, 0)
			end
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return IndexService
