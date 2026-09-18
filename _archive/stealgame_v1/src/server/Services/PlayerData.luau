-- Játékos adatok: betöltés, mentés, autosave, mutációk.
-- A játék minden más része ezen keresztül éri el az adatot.
-- Változásnál a PlayerData.Changed signal elsül -> ClientSync kiküldi a kliensre.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Signal = require(Shared.Signal)

local PlayerData = {}
PlayerData.Changed = Signal.new()

local cache = {} -- [Player] = data

local store = nil
if Game.Persistence then
	pcall(function()
		store = DataStoreService:GetDataStore(Game.DataStoreName)
	end)
end

local function defaultData()
	return {
		version = 1,
		cash = Game.StartCash,
		pickaxe = "Default",
		inventory = {}, -- [oreId] = darabszám
		stats = { hits = 0, mined = {} },
	}
end

-- betöltött adat tisztítása / hiányzó mezők pótlása
local function sanitize(raw)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end

	data.version = tonumber(raw.version) or 1
	data.cash = math.max(0, tonumber(raw.cash) or 0)
	if type(raw.pickaxe) == "string" then
		data.pickaxe = raw.pickaxe
	end

	if type(raw.inventory) == "table" then
		for id, count in pairs(raw.inventory) do
			count = tonumber(count)
			if count and count > 0 then
				data.inventory[id] = math.floor(count)
			end
		end
	end

	if type(raw.stats) == "table" then
		data.stats.hits = tonumber(raw.stats.hits) or 0
		if type(raw.stats.mined) == "table" then
			for id, count in pairs(raw.stats.mined) do
				data.stats.mined[id] = tonumber(count) or 0
			end
		end
	end

	return data
end

function PlayerData.isLoaded(player)
	return cache[player] ~= nil
end

function PlayerData.get(player)
	return cache[player]
end

-- másolat a kliensre (nem a belső táblát küldjük ki)
function PlayerData.snapshot(player)
	local data = cache[player]
	if not data then
		return nil
	end
	local inventory = table.clone(data.inventory)
	return {
		cash = data.cash,
		pickaxe = data.pickaxe,
		inventory = inventory,
		stats = { hits = data.stats.hits },
	}
end

function PlayerData.sync(player)
	local data = cache[player]
	if data then
		PlayerData.Changed:Fire(player, data)
	end
end

local function save(player)
	local data = cache[player]
	if not data or not store then
		return
	end
	local key = "u_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	if not ok then
		warn("[PlayerData] mentés hiba: " .. tostring(err))
	end
end

function PlayerData.load(player)
	if cache[player] then
		return
	end

	local raw = nil
	if store then
		local key = "u_" .. player.UserId
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key)
			end)
			if ok then
				raw = result
				break
			end
			warn(("[PlayerData] betöltés hiba (%d. próba): %s"):format(attempt, tostring(result)))
			task.wait(1)
		end
	end

	cache[player] = sanitize(raw)
	PlayerData.sync(player)
end

function PlayerData.release(player)
	save(player)
	cache[player] = nil
end

-- ---------- mutációk (mindegyik szinkronizál) ----------

function PlayerData.registerHit(player)
	local data = cache[player]
	if not data then
		return
	end
	data.stats.hits += 1
	PlayerData.sync(player)
end

function PlayerData.addOre(player, oreId, amount)
	local data = cache[player]
	if not data then
		return
	end
	amount = math.max(1, math.floor(amount or 1))
	data.inventory[oreId] = (data.inventory[oreId] or 0) + amount
	data.stats.mined[oreId] = (data.stats.mined[oreId] or 0) + amount
	PlayerData.sync(player)
end

function PlayerData.addCash(player, amount)
	local data = cache[player]
	if not data then
		return
	end
	data.cash = math.max(0, data.cash + math.floor(amount or 0))
	PlayerData.sync(player)
end

function PlayerData.trySpend(player, amount)
	local data = cache[player]
	if not data then
		return false
	end
	amount = math.floor(amount or 0)
	if amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= amount
	PlayerData.sync(player)
	return true
end

function PlayerData.setPickaxe(player, tierId)
	local data = cache[player]
	if not data then
		return
	end
	data.pickaxe = tierId
	PlayerData.sync(player)
end

-- ---------- automata mentés ----------

if Game.Persistence then
	task.spawn(function()
		while true do
			task.wait(Game.SaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				save(player)
			end
		end
	end)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

return PlayerData
