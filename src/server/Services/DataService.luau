-- Mentés (ProfileStore a DataServiceTyped-en keresztül) + leaderstats (GDD 8: szerver ranglista).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ReplicatedStorage.Shared.Data)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Settings = require(ReplicatedStorage.Shared.Settings)

local DataService = {}

-- Betöltés után (a ProfileStore Reconcile-ja után), mielőtt a kliens megkapja: adat-migráció a régi
-- mentésekhez + offline kereset. Helyben módosít, és vissza is adja (a DevService teszteléséhez).
function DataService.migrate(data: any): any
	while #data.ovens < Config.Ovens.MaxSlots do
		table.insert(data.ovens, 0)
	end
	while #data.ovenStars < Config.Ovens.MaxSlots do
		table.insert(data.ovenStars, 0)
	end
	data.slots = math.clamp(
		math.max(data.slots, Formulas.rebirthSlots(data.rebirths)),
		Config.Ovens.StartSlots,
		Config.Ovens.MaxSlots
	)
	-- régi mentés (generációk előtt): az eddig vett sütők az 1. generációban számítanak az árba
	if data.generation == 1 and data.generationBought == 0 and data.ovensBought > 0 then
		data.generationBought = data.ovensBought
	end
	for _, key in { "rarityCount", "rarityUnits", "rarityValue" } do
		while #data.tray[key] < #Config.Rarities.List do
			table.insert(data.tray[key], 0)
		end
	end
	-- régi mentés: ritkaság-bontás nélküli collector tartalom → "Sima"
	local tray = data.tray
	local function sum(list: { number }): number
		local total = 0
		for _, v in list do
			total += v
		end
		return total
	end
	if tray.count > 0 and sum(tray.rarityCount) == 0 then
		tray.rarityCount[1] = tray.count
	end
	if tray.units > 0 and sum(tray.rarityUnits) == 0 then
		tray.rarityUnits[1] = tray.units
	end
	if tray.value > 0 and sum(tray.rarityValue) == 0 then
		tray.rarityValue[1] = tray.value
	end

	-- Régi mentés (érték nélküli darabok): Lv1 áron számoljuk őket.
	if data.tray.units > 0 and data.tray.value == 0 then
		data.tray.value = data.tray.units * Config.Sell.UnitPrice
	end
	if data.carried > 0 and data.carriedValue == 0 then
		data.carriedValue = data.carried * Config.Sell.UnitPrice
	end
	if data.counterStock > 0 and data.counterValue == 0 then
		data.counterValue = data.counterStock * Config.Sell.UnitPrice
	end

	-- GDD 13: analytics előtti mentés (funnel = 0, de már játszott): ami már megvolt, az ne menjen el
	-- késői funnel lépésként (sorrend: Services/AnalyticsService STEPS).
	if data.funnel == 0 and (data.ovensBought > 0 or data.rebirths > 0) then
		local done = {
			true, -- Loaded
			true, -- FirstOven
			data.stats.merges > 0 or data.rebirths > 0,
			data.stats.totalSold > 0 or data.rebirths > 0,
			data.stats.totalEarned > 0 or data.rebirths > 0, -- FirstCollect (közelítés)
			data.chefs.count > 0 or data.rebirths > 0,
			#data.pets.inventory > 0,
			data.rebirths > 0,
		}
		for index, passed in done do
			if passed then
				data.funnel = bit32.bor(data.funnel, 2 ^ (index - 1))
			end
		end
	end

	-- GDD 3.13: offline kereset a legutóbbi online idő óta (a Claim ablak a kliensen jön fel).
	-- Ha egy korábbi, fel nem vett összeg is van, hozzáadódik.
	local now = os.time()
	if data.lastOnline > 0 then
		local away = now - data.lastOnline
		if away >= Config.Offline.MinSeconds then
			local earned, counted = Formulas.offlineEarnings(data, away)
			if earned > 0 then
				data.offline.pending += earned
				data.offline.seconds = counted
			end
		end
	end
	data.lastOnline = now
	return data
end

function DataService.init()
	local service = Data.server.Service

	function service.onPlayerInit(_self, _player: Player, data: any)
		DataService.migrate(data)
	end

	-- kilépéskor az "utoljára online" idő (a profil mentése előtt)
	service:addPlayerRemovingCallback(function(_player: Player, data: any)
		data.lastOnline = os.time()
	end)

	service:init()
end

-- GDD 3.13: az offline kereset felvétele.
function DataService.claimOffline(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local raw = data()
	local pending = raw.offline.pending
	if pending <= 0 then
		return 0
	end
	data.money(raw.money + pending)
	AnalyticsService.source(player, pending, "TimedReward", "Offline")
	data.cycleEarned(raw.cycleEarned + pending) -- az offline kereset is számít a rebirthbe
	data.offline({ pending = 0, seconds = 0 })
	return pending
end

function DataService.start()
	local function setupLeaderstats(player: Player)
		local data = DataService.wait(player)
		if not data then
			return
		end

		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local money = Instance.new("NumberValue")
		money.Name = "Money"
		money.Value = data.money()
		money.Parent = leaderstats
		leaderstats.Parent = player

		data.money.Changed(function(value: number)
			money.Value = value
		end)
	end

	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in Players:GetPlayers() do
		task.spawn(setupLeaderstats, player)
	end

	-- GDD 3.13: offline kereset felvétele + "utoljára online" mentése percenként (szerver összeomlás esetére)
	Guard.connect(Remotes.ClaimOffline, function(player)
		DataService.claimOffline(player)
	end)
	-- GDD 11.1: beállítások mentése (a kliens küldi, a szerver csak az ismert, érvényes értékeket fogadja el)
	Guard.connect(Remotes.SaveSettings, function(player, settings: unknown)
		local data = DataService.get(player)
		if data and type(settings) == "table" then
			data.settings(Settings.normalize(settings), false) -- false: a kliensnek nem kell visszaküldeni
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Offline.HeartbeatInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.lastOnline(os.time(), false) -- false: nem kell a kliensnek replikálni
				end
			end
		end
	end)
end

-- A játékos adat Value-ja, vagy nil, ha még nem töltött be.
function DataService.get(player: Player): any
	return Data.server[player]
end

-- Megvárja, amíg a játékos adata betölt (nil, ha közben kilépett).
function DataService.wait(player: Player): any
	return Data.server.Service:waitForData(player)
end

return DataService
