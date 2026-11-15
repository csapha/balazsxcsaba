-- GDD 8: napi bejelentkezési jutalom (7 napos sorozat) + playtime ajándékok (aznapi játékidő alapján),
-- GDD 5.1 ⑦: kódok beváltása (Config.Codes, a Settings ablak Codes fülén).
-- A kliens a TopbarPlus ikonokról nyíló ablakokból kéri (Remotes.ClaimDaily / ClaimPlaytime / RedeemCode),
-- a szerver ellenőrzi.
-- A számok: Config.Rewards, az állapot képletei: Formulas.dailyStatus / playtimeStatus / rewardMoney.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local Rewards = Config.Rewards
local Palette = Config.Palette
local COOLDOWN = 0.5 -- mp (dupla kattintás ellen)

local RewardService = {}

local lastClaim: { [Player]: number } = {}

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < COOLDOWN then
		return true
	end
	lastClaim[player] = now
	return false
end

-- Egy jutalom kiosztása. Visszaad: fajta ("Money" | "Tickets" | "Pet"), mennyiség, pet id.
local function grant(player: Player, reward: any, sku: string): (string, number, string?)
	local data = DataService.get(player)
	local raw = data()
	if reward.Kind == "Pet" then
		if PetService.grant(player, reward.Pet) then
			return "Pet", 1, reward.Pet
		end
		-- tele a leltár: helyette pénz
		reward = { Kind = "Money", Minutes = Rewards.PetFallbackMinutes }
	end
	if reward.Kind == "Tickets" then
		data.auras.tickets(raw.auras.tickets + reward.Amount)
		return "Tickets", reward.Amount, nil
	end
	local amount = Formulas.rewardMoney(raw, reward.Minutes)
	data.money(raw.money + amount)
	AnalyticsService.source(player, amount, "TimedReward", sku)
	return "Money", amount, nil
end

-- Visszajelzés a kliensnek: pénz / ticket → felugró felirat a feje felett, pet → tojásnyitás animáció
-- (annak a tojásnak a színével, amelyikből a pet amúgy kikelne).
local function announce(player: Player, kind: string, amount: number, petId: string?)
	if kind == "Pet" and petId then
		for eggIndex, egg in Config.Pets.Eggs do
			for _, entry in egg.Pets do
				if entry[1] == petId then
					Remotes.EggOpened:FireClient(player, eggIndex, petId)
					return
				end
			end
		end
	elseif kind == "Tickets" then
		Remotes.EventReward:FireClient(player, `+{amount} Aura Ticket{if amount == 1 then "" else "s"}`, Palette.Lemon)
	else
		Remotes.EventReward:FireClient(player, `+{NumberFormat.money(amount)}`, Palette.Money)
	end
end

-- Napi jutalom felvétele. Visszaad: a felvett nap (1..7), vagy nil, ha ma már felvette.
function RewardService.claimDaily(player: Player): number?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local today = Formulas.rewardDay(os.time())
	local canClaim, day = Formulas.dailyStatus(data.daily(), today)
	if not canClaim then
		return nil
	end
	data.daily { streak = day, lastDay = today }
	announce(player, grant(player, Rewards.Daily[day], "Daily"))
	return day
end

-- Egy playtime ajándék felvétele (ha már nyitva van és ma még nem vette fel). Visszaad: sikerült-e.
function RewardService.claimPlaytime(player: Player, index: number): boolean
	local data = DataService.get(player)
	local gift = Rewards.Playtime[index]
	if not data or not gift then
		return false
	end
	local playtime = data.playtime()
	local bit = 2 ^ (index - 1)
	if playtime.day ~= Formulas.rewardDay(os.time()) then
		return false
	end
	if playtime.seconds < gift.Minutes * 60 or bit32.btest(playtime.claimed, bit) then
		return false
	end
	data.playtime.claimed(bit32.bor(playtime.claimed, bit))
	announce(player, grant(player, gift.Reward, "Playtime"))
	return true
end

-- Kód beváltása. Visszaad: sikerült-e, és az üzenet a játékosnak (angolul, a Codes fül alatt jelenik meg).
function RewardService.redeemCode(player: Player, input: string): (boolean, string)
	local data = DataService.get(player)
	if not data then
		return false, "Please wait a moment and try again."
	end
	local code = string.upper((string.gsub(input, "%s", "")))
	local entry = Config.Codes[code]
	if not entry or (entry.Expires and os.time() > entry.Expires) then
		return false, "That code doesn't exist or has expired."
	end
	local redeemed = table.clone(data.codes())
	if redeemed[code] then
		return false, "You already redeemed this code."
	end
	redeemed[code] = true
	data.codes(redeemed)
	local kind, amount, petId = grant(player, entry.Reward, "Code")
	announce(player, kind, amount, petId)
	local text = if kind == "Pet"
		then Config.Pets.List[petId :: string].Name
		elseif kind == "Tickets" then `{amount} Aura Ticket{if amount == 1 then "" else "s"}`
		else NumberFormat.money(amount)
	return true, `Code redeemed! You got {text}.`
end

-- Mp-enként: az aznapi játékidő nő; új napon (UTC) nulláról indul, az ajándékok újra felvehetők.
local function playtimeTick()
	local today = Formulas.rewardDay(os.time())
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end
		local playtime = data.playtime()
		if playtime.day ~= today then
			data.playtime { day = today, seconds = 0, claimed = 0 }
		else
			data.playtime.seconds(playtime.seconds + 1)
		end
	end
end

function RewardService.start()
	Guard.connect(Remotes.ClaimDaily, function(player)
		if not throttled(player) then
			RewardService.claimDaily(player)
		end
	end)
	Guard.connect(Remotes.ClaimPlaytime, function(player, index: unknown)
		if type(index) == "number" and index == math.floor(index) and not throttled(player) then
			RewardService.claimPlaytime(player, index)
		end
	end)
	Guard.connect(Remotes.RedeemCode, function(player, code: unknown)
		if type(code) ~= "string" or #code > 40 or throttled(player) then
			return
		end
		Remotes.CodeResult:FireClient(player, RewardService.redeemCode(player, code))
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
	while true do
		task.wait(1)
		playtimeTick()
	end
end

return RewardService
