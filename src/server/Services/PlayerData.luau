-- Játékos adatok (session-only egyelőre, de DataStore-ra kész szerkezettel)
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Signal = require(Shared.Signal)

local PlayerData = {}
PlayerData.Changed = Signal.new()

local cache = {} -- [Player] = data

local function defaultData()
	return {
		version = 1,
		power = 0,
		cash = 0,
		hands = Upgrades.defaultHands,
		training = Upgrades.defaultTraining,
		stats = { taps = 0, pops = 0, bestWeight = 0 },
	}
end

local function handsEntry(data)
	return Upgrades.handsById[data.hands] or Upgrades.handsById[Upgrades.defaultHands]
end

local function trainingEntry(data)
	return Upgrades.trainingById[data.training] or Upgrades.trainingById[Upgrades.defaultTraining]
end

function PlayerData.isLoaded(player)
	return cache[player] ~= nil
end

function PlayerData.get(player)
	return cache[player]
end

function PlayerData.getHands(player)
	local data = cache[player]
	return data and handsEntry(data) or nil
end

function PlayerData.getTraining(player)
	local data = cache[player]
	return data and trainingEntry(data) or nil
end

-- másodpercenkénti passzív Erő (kéz szorzóval)
function PlayerData.getPassivePerSecond(player)
	local data = cache[player]
	if not data then
		return 0
	end
	return trainingEntry(data).passive * handsEntry(data).multiplier
end

-- egy kattintásért járó Erő
function PlayerData.getTapGain(player)
	local data = cache[player]
	if not data then
		return 0
	end
	return 1.5 * handsEntry(data).multiplier * trainingEntry(data).tapBonus
end

function PlayerData.snapshot(player)
	local data = cache[player]
	if not data then
		return nil
	end
	return {
		power = data.power,
		cash = data.cash,
		hands = data.hands,
		training = data.training,
		handsMultiplier = handsEntry(data).multiplier,
		passive = PlayerData.getPassivePerSecond(player),
		tapGain = PlayerData.getTapGain(player),
		stats = {
			taps = data.stats.taps,
			pops = data.stats.pops,
			bestWeight = data.stats.bestWeight,
		},
	}
end

function PlayerData.sync(player)
	local data = cache[player]
	if data then
		PlayerData.Changed:Fire(player, data)
	end
end

function PlayerData.load(player)
	if cache[player] then
		return
	end
	cache[player] = defaultData()
	PlayerData.sync(player)
end

function PlayerData.release(player)
	cache[player] = nil
end

-- ---------- mutációk ----------

function PlayerData.addPower(player, amount)
	local data = cache[player]
	if not data then
		return 0
	end
	amount = tonumber(amount) or 0
	data.power += amount
	return amount
end

function PlayerData.addCash(player, amount)
	local data = cache[player]
	if not data then
		return 0
	end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	data.cash += amount
	return amount
end

function PlayerData.trySpend(player, amount)
	local data = cache[player]
	if not data then
		return false
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= amount
	return true
end

function PlayerData.registerTap(player)
	local data = cache[player]
	if data then
		data.stats.taps += 1
	end
end

function PlayerData.registerPop(player, weight)
	local data = cache[player]
	if not data then
		return
	end
	data.stats.pops += 1
	if weight > data.stats.bestWeight then
		data.stats.bestWeight = weight
	end
end

function PlayerData.setHands(player, id)
	local data = cache[player]
	if not data then
		return
	end
	data.hands = id
	PlayerData.sync(player)
end

function PlayerData.setTraining(player, id)
	local data = cache[player]
	if not data then
		return
	end
	data.training = id
	PlayerData.sync(player)
end

-- játékos életciklus
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerData.load(player)
end

return PlayerData
