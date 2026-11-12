-- Aurák (GDD 3.10): dobás tickettel vagy pénzért, duplikátum → szintlépés (max 5), 1 aktív aura.
-- Ingyen ticket: FreeTicketInterval mp játékidőnként (a 8. fejezetben a playtime-ajándék része lesz).
-- A többi kliens a "Aura" játékos-attribútumból rajzolja ki az effektet (AuraController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local AuraConfig = Config.Auras

local PLAYTIME_STEP = 5 -- mp-enként írjuk a játékidőt (ritkább replikáció)

local AuraService = {}

local rng = Random.new()
local lastRoll: { [Player]: number } = {}

local function writeAuras(player: Player, auras: any)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.auras(auras)
	player:SetAttribute("Aura", if auras.equipped ~= "" then auras.equipped else nil)
end

local function cloneAuras(raw: any)
	return {
		owned = table.clone(raw.auras.owned),
		equipped = raw.auras.equipped,
		tickets = raw.auras.tickets,
		ticketProgress = raw.auras.ticketProgress,
	}
end

function AuraService.roll(player: Player, mode: unknown): string?
	local data = DataService.get(player)
	if not data or (mode ~= "ticket" and mode ~= "money") then
		return nil
	end
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < AuraConfig.RollCooldown then
		return nil
	end

	local raw = data()
	local auras = cloneAuras(raw)
	if mode == "ticket" then
		if auras.tickets <= 0 then
			return nil
		end
		auras.tickets -= 1
	else
		local price = Formulas.auraRollPrice(raw)
		if raw.money < price then
			return nil
		end
		data.money(raw.money - price)
	end
	lastRoll[player] = now

	local id = Formulas.rollAura(rng)
	local previous = auras.owned[id]
	local isNew = previous == nil
	local level = if isNew then 1 else math.min(previous + 1, AuraConfig.MaxLevel)
	auras.owned[id] = level
	if auras.equipped == "" then
		auras.equipped = id -- az első aura rögtön aktív
	end
	writeAuras(player, auras)

	Remotes.AuraRolled:FireClient(player, id, level, isNew)
	local rarity = AuraConfig.Rarities[AuraConfig.List[id].Rarity]
	if rarity.Announce and isNew then
		Remotes.AuraAnnounce:FireAllClients(player.DisplayName, id)
	end
	return id
end

local function equip(player: Player, id: unknown)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return
	end
	local raw = data()
	if not raw.auras.owned[id] then
		return
	end
	local auras = cloneAuras(raw)
	auras.equipped = id
	writeAuras(player, auras)
end

local function unequip(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local auras = cloneAuras(data())
	auras.equipped = ""
	writeAuras(player, auras)
end

-- Játékidő → ingyen ticket
local function playtimeTick()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end
		local raw = data()
		local progress = raw.auras.ticketProgress + PLAYTIME_STEP
		local tickets = raw.auras.tickets
		while progress >= AuraConfig.FreeTicketInterval do
			progress -= AuraConfig.FreeTicketInterval
			tickets += 1
		end
		if tickets ~= raw.auras.tickets then
			data.auras.tickets(tickets)
		end
		data.auras.ticketProgress(progress)
	end
end

function AuraService.start()
	Remotes.AuraAction.OnServerEvent:Connect(function(player, action: unknown, arg: unknown)
		if action == "roll" then
			AuraService.roll(player, arg)
		elseif action == "equip" then
			equip(player, arg)
		elseif action == "unequip" then
			unequip(player)
		end
	end)

	local function setup(player: Player)
		local data = DataService.wait(player)
		if data then
			local equipped = data().auras.equipped
			player:SetAttribute("Aura", if equipped ~= "" then equipped else nil)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(PLAYTIME_STEP)
			playtimeTick()
		end
	end)
end

return AuraService
