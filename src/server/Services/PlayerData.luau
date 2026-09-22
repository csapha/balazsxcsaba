-- Játékos adatok (session-only egyelőre, de DataStore-ra kész szerkezettel)
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Upgrades = require(Shared.Config.Upgrades)
local DailyRewards = require(Shared.Config.DailyRewards)
local Gacha = require(Shared.Config.Gacha)
local Rebirth = require(Shared.Config.Rebirth)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Signal = require(Shared.Signal)

local PlayerData = {}
PlayerData.Changed = Signal.new()

local cache = {} -- [Player] = data

local function defaultData()
	return {
		version = 1,
		-- Teszteléshez feltöltött kezdő készpénz (Persistence = false, session-only).
		power = 0,
		cash = 1000000000000,
		hands = Upgrades.defaultHands,
		training = Upgrades.defaultTraining,
		trainingSpeed = Upgrades.defaultTrainingSpeed,
		move = Upgrades.defaultMove,
		speed = Upgrades.defaultSpeed,
		dailyStreak = 0, -- eddig átvett napok száma (0..7)
		lastDailyClaim = 0,
		materials = {}, -- [id] = count
		equippedMaterial = nil,
		pityCount = 0,
		rebirths = 0,
		activeSkin = "Skin_Default",
		unlockedTeleports = { watermelon = true },
		squeezedObjects = {},
		stats = { taps = 0, pops = 0, bestWeight = 0 },
	}
end

local function handsEntry(data)
	return Upgrades.handsById[data.hands] or Upgrades.handsById[Upgrades.defaultHands]
end

local function trainingEntry(data)
	return Upgrades.trainingById[data.training] or Upgrades.trainingById[Upgrades.defaultTraining]
end

local function trainingSpeedEntry(data)
	return Upgrades.trainingSpeedById[data.trainingSpeed]
		or Upgrades.trainingSpeedById[Upgrades.defaultTrainingSpeed]
end

local function moveEntry(data)
	return Upgrades.movesById[data.move] or Upgrades.movesById[Upgrades.defaultMove]
end

local function speedEntry(data)
	return Upgrades.speedById[data.speed] or Upgrades.speedById[Upgrades.defaultSpeed]
end

local function applyWalkSpeed(player)
	local data = cache[player]
	if not data then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speedEntry(data).speed
	end
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

function PlayerData.getMove(player)
	local data = cache[player]
	return data and moveEntry(data) or nil
end

function PlayerData.getSpeed(player)
	local data = cache[player]
	return data and speedEntry(data) or nil
end

local function materialMultiplier(data)
	if not data or not data.equippedMaterial then
		return 1.0
	end
	local mat = Gacha.materials[data.equippedMaterial]
	return mat and mat.multiplier or 1.0
end

function PlayerData.getMaterialMultiplier(player)
	local data = cache[player]
	return data and materialMultiplier(data) or 1.0
end

function PlayerData.getEquippedMaterial(player)
	local data = cache[player]
	return data and data.equippedMaterial or nil
end

function PlayerData.getMaterials(player)
	local data = cache[player]
	return data and data.materials or {}
end

function PlayerData.setEquippedMaterial(player, materialId)
	local data = cache[player]
	if not data then
		return
	end
	if materialId ~= nil and not Gacha.materials[materialId] then
		return
	end
	data.equippedMaterial = materialId
	PlayerData.sync(player)
end

function PlayerData.addMaterial(player, materialId)
	local data = cache[player]
	if not data then
		return
	end
	data.materials[materialId] = (data.materials[materialId] or 0) + 1
	if not data.equippedMaterial then
		data.equippedMaterial = materialId
	else
		local currentMat = Gacha.materials[data.equippedMaterial]
		local newMat = Gacha.materials[materialId]
		if newMat and currentMat and newMat.multiplier > currentMat.multiplier then
			data.equippedMaterial = materialId
		end
	end
	PlayerData.sync(player)
end

function PlayerData.getPity(player)
	local data = cache[player]
	return data and (data.pityCount or 0) or 0
end

function PlayerData.setPity(player, count)
	local data = cache[player]
	if not data then
		return
	end
	data.pityCount = count
	PlayerData.sync(player)
end

local function rebirthMultiplier(data)
	if not data then
		return 1.0
	end
	return Rebirth.getMultiplier(data.rebirths or 0)
end

function PlayerData.getRebirths(player)
	local data = cache[player]
	return data and (data.rebirths or 0) or 0
end

function PlayerData.getRebirthMultiplier(player)
	local data = cache[player]
	return data and rebirthMultiplier(data) or 1.0
end

function PlayerData.isTeleportUnlocked(player, objectId)
	if objectId == "watermelon" then
		return true
	end
	local data = cache[player]
	if not data or not data.unlockedTeleports then
		return false
	end
	return data.unlockedTeleports[objectId] == true
end

function PlayerData.unlockTeleport(player, objectId)
	local data = cache[player]
	if not data then
		return false, "No player data"
	end
	if objectId == "watermelon" or (data.unlockedTeleports and data.unlockedTeleports[objectId]) then
		return false, "Already unlocked"
	end
	local object = Objects.byId[objectId]
	if not object then
		return false, "Invalid object"
	end
	local previousObject = Objects.list[object.index - 1]
	if previousObject and not (data.squeezedObjects and data.squeezedObjects[previousObject.id]) then
		return false, string.format("Squeeze %s first!", previousObject.name)
	end
	local cost = Objects.getUnlockCost(object)
	if data.power < cost then
		return false, string.format("Need %s Power to unlock %s!", Format.number(cost), object.name)
	end

	-- Unlocking does not spend Power: the requirement is just a threshold.
	data.unlockedTeleports = data.unlockedTeleports or { watermelon = true }
	data.unlockedTeleports[objectId] = true

	PlayerData.sync(player)
	return true, cost, object
end

function PlayerData.doRebirth(player)
	local data = cache[player]
	if not data then
		return false, "No data"
	end

	local reqPower = Rebirth.getPowerRequired(data.rebirths or 0)
	if data.power < reqPower then
		return false, "Need more Power"
	end

	-- Reset according to Design Doc 4.7: Power, Cash, Upgrades; keeps Gacha materials
	data.power = 0
	data.cash = 0
	data.hands = Upgrades.defaultHands
	data.training = Upgrades.defaultTraining
	data.trainingSpeed = Upgrades.defaultTrainingSpeed
	data.move = Upgrades.defaultMove
	data.speed = Upgrades.defaultSpeed
	data.unlockedTeleports = { watermelon = true }
	data.squeezedObjects = {}
	applyWalkSpeed(player)

	data.rebirths = (data.rebirths or 0) + 1
	local newSkin = Rebirth.getSkin(data.rebirths)
	data.activeSkin = newSkin.id

	PlayerData.sync(player)
	return true, data.rebirths, newSkin
end

-- másodpercenkénti passzív Erő (kéz, kesztyű-anyag és rebirth szorzóval)
function PlayerData.getPassivePerSecond(player)
	local data = cache[player]
	if not data then
		return 0
	end
	return trainingEntry(data).passive * handsEntry(data).multiplier * materialMultiplier(data) * rebirthMultiplier(data)
end

function PlayerData.getTrainCycle(player)
	local data = cache[player]
	if not data then
		return GameConfig.TrainCycle
	end
	return math.max(tonumber(trainingSpeedEntry(data).trainCycle) or GameConfig.TrainCycle, 0.1)
end

-- egy kattintásért járó Erő (kesztyű-anyag és rebirth szorzóval)
function PlayerData.getTapGain(player)
	local data = cache[player]
	if not data then
		return 0
	end
	local multiplier = handsEntry(data).multiplier
		* trainingEntry(data).tapBonus
		* moveEntry(data).tapBonus
		* materialMultiplier(data)
		* rebirthMultiplier(data)
	return GameConfig.TrainTapGain * multiplier
end

function PlayerData.snapshot(player)
	local data = cache[player]
	if not data then
		return nil
	end
	local reqPower = Rebirth.getPowerRequired(data.rebirths or 0)
	return {
		power = data.power,
		cash = data.cash,
		hands = data.hands,
		training = data.training,
		trainingSpeed = data.trainingSpeed,
		move = data.move,
		speed = data.speed,
		walkSpeed = speedEntry(data).speed,
		moveTapBonus = moveEntry(data).tapBonus,
		handsMultiplier = handsEntry(data).multiplier,
		equippedMaterial = data.equippedMaterial,
		materialMultiplier = materialMultiplier(data),
		materials = data.materials or {},
		pityCount = data.pityCount or 0,
		rebirths = data.rebirths or 0,
		rebirthMultiplier = rebirthMultiplier(data),
		nextRebirthPower = reqPower,
		activeSkin = data.activeSkin or "Skin_Default",
		canRebirth = data.power >= reqPower,
		passive = PlayerData.getPassivePerSecond(player),
		tapGain = PlayerData.getTapGain(player),
		trainCycle = PlayerData.getTrainCycle(player),
		dailyStreak = data.dailyStreak or 1,
		lastDailyClaim = data.lastDailyClaim or 0,
		canClaimDaily = os.time() - (data.lastDailyClaim or 0) >= DailyRewards.cooldown,
		unlockedTeleports = data.unlockedTeleports or { watermelon = true },
		squeezedObjects = data.squeezedObjects or {},
		stats = {
			taps = data.stats.taps,
			pops = data.stats.pops,
			bestWeight = data.stats.bestWeight,
		},
	}
end

function PlayerData.canClaimDaily(player)
	local data = cache[player]
	if not data then
		return false
	end
	if (data.lastDailyClaim or 0) == 0 then
		return true
	end
	return os.time() - data.lastDailyClaim >= DailyRewards.cooldown
end

function PlayerData.claimDaily(player)
	local data = cache[player]
	if not data then
		return false, "No data"
	end
	if not PlayerData.canClaimDaily(player) then
		return false, "Not ready yet"
	end

	local currentClaimed = data.dailyStreak or 0
	if currentClaimed >= 7 then
		currentClaimed = 0
	end

	local nextDay = currentClaimed + 1
	local rewardDef = DailyRewards.days[nextDay] or DailyRewards.days[1]

	if rewardDef.rewardType == "cash" then
		PlayerData.addCash(player, rewardDef.amount)
	elseif rewardDef.rewardType == "power" then
		PlayerData.addPower(player, rewardDef.amount)
	elseif rewardDef.rewardType == "speed_cash" then
		PlayerData.addCash(player, rewardDef.amount)
		local currentSpeedEntry = speedEntry(data)
		local currentOrder = currentSpeedEntry and currentSpeedEntry.order or 1
		local nextSpeed = Upgrades.speedByOrder[currentOrder + 1]
		if nextSpeed then
			PlayerData.setSpeed(player, nextSpeed.id)
		end
	elseif rewardDef.rewardType == "jackpot" then
		PlayerData.addCash(player, rewardDef.amount)
		local currentMoveEntry = moveEntry(data)
		local currentOrder = currentMoveEntry and currentMoveEntry.order or 1
		local nextMove = Upgrades.movesByOrder[currentOrder + 1]
		if nextMove then
			PlayerData.setMove(player, nextMove.id)
		end
	end

	data.lastDailyClaim = os.time()
	data.dailyStreak = nextDay

	PlayerData.sync(player)
	return true, rewardDef
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

function PlayerData.registerPop(player, objectId, weight)
	local data = cache[player]
	if not data then
		return
	end
	data.squeezedObjects = data.squeezedObjects or {}
	data.squeezedObjects[objectId] = true
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

function PlayerData.setTrainingSpeed(player, id)
	local data = cache[player]
	if not data then
		return
	end
	data.trainingSpeed = id
	PlayerData.sync(player)
end

function PlayerData.setMove(player, id)
	local data = cache[player]
	if not data then
		return
	end
	data.move = id
	PlayerData.sync(player)
end

function PlayerData.setSpeed(player, id)
	local data = cache[player]
	if not data then
		return
	end
	data.speed = id
	PlayerData.sync(player)
	applyWalkSpeed(player)
end

-- játékos életciklus
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		applyWalkSpeed(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerData.load(player)
	if player.Character then
		applyWalkSpeed(player)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		applyWalkSpeed(player)
	end)
end

return PlayerData
