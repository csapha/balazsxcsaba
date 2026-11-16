-- GDD 6.4: Schnitzel Pass (szezon bérlet, Config.SeasonPass). 30 szint, Free + Premium sáv.
-- Pass XP: a többi service-hez nem nyúlunk, hanem másodpercenként összevetjük a játékos adatát az előző
-- állapottal (merge-ek, rebirthek, napi jutalom, playtime ajándékok, kikelt petek), és a különbség után jár XP;
-- a játékidő után percenként. A korlátos források (merge, tojás) napi (UTC) XP-je a mentésben van.
-- A Premium és a +1 szint dev product (Config.Shop.Products.SeasonPremium / SeasonSkip), a ShopService hívja.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local PassConfig = Config.SeasonPass
local Xp = PassConfig.Xp
local Palette = Config.Palette
local IS_STUDIO = RunService:IsStudio()
local COOLDOWN = 0.25 -- mp (dupla kattintás ellen)
local ANNOUNCE_GAP = 0.35 -- "Claim all": a felugró feliratok egymás után jönnek

local SeasonPassService = {}

-- Az XP-források előző állapota játékosonként (a mentésben nincs: belépéskor ebből indulunk, XP nélkül)
type Snapshot = { merges: number, rebirths: number, dailyDay: number, giftDay: number, gifts: number, nextPet: number, playSeconds: number }
local snapshots: { [Player]: Snapshot } = {}
local lastClaim: { [Player]: number } = {}

local function active(): boolean
	return Formulas.seasonActive(os.time(), IS_STUDIO)
end

local function bitCount(mask: number): number
	local count = 0
	while mask > 0 do
		count += mask % 2
		mask = mask // 2
	end
	return count
end

local function takeSnapshot(raw: any): Snapshot
	return {
		merges = raw.stats.merges,
		rebirths = raw.rebirths,
		dailyDay = raw.daily.lastDay,
		giftDay = raw.playtime.day,
		gifts = bitCount(raw.playtime.claimed),
		nextPet = raw.pets.nextId,
		playSeconds = 0,
	}
end

-- Új szezon (más Id): a Pass adatai nulláról. Visszaad: a (lehet, hogy új) pass tábla.
local function ensureSeason(data: any): any
	local pass = data().seasonPass
	if pass.season ~= PassConfig.Season.Id then
		data.seasonPass({
			season = PassConfig.Season.Id,
			xp = 0,
			premium = false,
			free = 0,
			paid = 0,
			day = 0,
			merges = 0,
			eggs = 0,
		})
	end
	return data().seasonPass
end

-- XP hozzáadása (source: a korlátos forrás kulcsa a mentésben: "merges" / "eggs", vagy nil).
-- Visszaad: a ténylegesen kapott XP.
function SeasonPassService.addXp(player: Player, amount: number, capped: ("merges" | "eggs")?, cap: number?): number
	local data = DataService.get(player)
	if not data or amount <= 0 or not active() then
		return 0
	end
	local pass = table.clone(ensureSeason(data))
	if capped and cap then
		local today = Formulas.rewardDay(os.time())
		if pass.day ~= today then
			pass.day, pass.merges, pass.eggs = today, 0, 0
		end
		amount = math.min(amount, cap - pass[capped])
		if amount <= 0 then
			return 0
		end
		pass[capped] += amount
	end
	local before = Formulas.seasonTier(pass.xp)
	pass.xp += amount
	data.seasonPass(pass)
	local after = Formulas.seasonTier(pass.xp)
	if after > before then
		Remotes.SeasonTier:FireClient(player, after)
		Remotes.EventReward:FireClient(player, `Pass Tier {after}!`, Palette.Lemon)
	end
	return amount
end

-- Egy jutalom kiosztása. Visszaad: a felugró felirat (nil: a saját animációja a visszajelzés, pl. pet, tojás).
local function grant(player: Player, reward: any): string?
	local data = DataService.get(player)
	local raw = data()
	local kind = reward.Kind
	if kind == "Money" then
		local amount = Formulas.rewardMoney(raw, reward.Minutes)
		data.money(raw.money + amount)
		AnalyticsService.source(player, amount, "TimedReward", "SeasonPass")
		return `+{NumberFormat.money(amount)}`
	elseif kind == "Tickets" then
		data.auras.tickets(raw.auras.tickets + reward.Amount)
		return `+{reward.Amount} Aura Ticket{if reward.Amount == 1 then "" else "s"}`
	elseif kind == "Boost" then
		local boosts = table.clone(raw.timedBoosts)
		boosts[reward.Boost] = math.max(boosts[reward.Boost] or 0, os.time()) + reward.Minutes * 60
		data.timedBoosts(boosts)
		return `{Config.Shop.BoostNames[reward.Boost]} for {reward.Minutes} min!`
	elseif kind == "Tokens" then
		data.rebirthTokens(raw.rebirthTokens + reward.Amount)
		return `+{reward.Amount} Rebirth Token{if reward.Amount == 1 then "" else "s"}`
	elseif kind == "Trail" then
		CosmeticService.grant(player, reward.Trail)
		return `{Config.Shop.Trails[reward.Trail].Name} equipped!`
	elseif kind == "Pet" then
		PetService.give(player, reward.Pet)
		Remotes.EggOpened:FireClient(player, 0, reward.Pet) -- a tojásnyitás animációja (a Golden Egg színével)
		return nil
	elseif kind == "Egg" then
		PetService.openRobuxEgg(player, reward.Count) -- maga indítja a nyitás animációját
		return nil
	end
	return nil
end

-- Egy jutalom felvétele. Visszaad: a felugró felirat, vagy false, ha nem vehető fel.
local function claimOne(player: Player, track: string, tier: number): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, nil
	end
	local pass = ensureSeason(data)
	if not Formulas.seasonClaimable(pass, track, tier) then
		return false, nil
	end
	local updated = table.clone(pass)
	local bit = 2 ^ (tier - 1)
	if track == "Free" then
		updated.free = bit32.bor(pass.free, bit)
	else
		updated.paid = bit32.bor(pass.paid, bit)
	end
	data.seasonPass(updated)
	local text = grant(player, PassConfig[track][tier])
	-- a jutalomból kikelt petek nem adnak tojás XP-t
	local snapshot = snapshots[player]
	if snapshot then
		snapshot.nextPet = data().pets.nextId
	end
	return true, text
end

local function announce(player: Player, texts: { string })
	for index, text in texts do
		task.delay((index - 1) * ANNOUNCE_GAP, function()
			if player.Parent then
				Remotes.EventReward:FireClient(player, text, Palette.Lemon)
			end
		end)
	end
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < COOLDOWN then
		return true
	end
	lastClaim[player] = now
	return false
end

local function onClaim(player: Player, track: unknown, tier: unknown)
	if not active() or throttled(player) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local texts = {}
	if track == "All" then
		local pass = ensureSeason(data)
		for t = 1, Formulas.seasonTier(pass.xp) do
			for _, name in { "Free", "Premium" } do
				local ok, text = claimOne(player, name, t)
				if ok and text then
					table.insert(texts, text)
				end
			end
		end
	elseif (track == "Free" or track == "Premium") and type(tier) == "number" then
		local ok, text = claimOne(player, track, tier)
		if ok and text then
			table.insert(texts, text)
		end
	end
	announce(player, texts)
end

-- Dev product: a Premium sáv az aktuális szezonra. Visszaad: sikerült-e (ha már megvolt, akkor is igaz).
function SeasonPassService.unlockPremium(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local pass = table.clone(ensureSeason(data))
	pass.premium = true
	data.seasonPass(pass)
	return true
end

-- Dev product: +1 szint (a hiányzó XP). Visszaad: sikerült-e (a max szinten nem).
function SeasonPassService.skipTier(player: Player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local pass = table.clone(ensureSeason(data))
	local tier = Formulas.seasonTier(pass.xp)
	if tier >= Formulas.seasonMaxTier() then
		return false
	end
	pass.xp = Formulas.seasonTierStart(tier + 1)
	data.seasonPass(pass)
	Remotes.SeasonTier:FireClient(player, tier + 1)
	return true
end

-- Megvehető-e most a termék (a ShopService a vásárlás előtt nézi).
function SeasonPassService.available(raw: any, effect: string): boolean
	if not active() then
		return false
	end
	local pass = raw.seasonPass
	local current = pass.season == PassConfig.Season.Id
	if effect == "SeasonPremium" then
		return not (current and pass.premium)
	elseif effect == "SeasonSkip" then
		return not current or Formulas.seasonTier(pass.xp) < Formulas.seasonMaxTier()
	end
	return false
end

-- Mp-enként: játékidő + az adatváltozásokból járó XP.
local function tick()
	if not active() then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end
		local raw = data()
		local snapshot = snapshots[player]
		if not snapshot then
			ensureSeason(data)
			snapshots[player] = takeSnapshot(raw)
			continue
		end
		local now = takeSnapshot(raw)

		snapshot.playSeconds += 1
		if snapshot.playSeconds >= 60 then
			snapshot.playSeconds = 0
			SeasonPassService.addXp(player, Xp.Play)
		end
		if now.merges > snapshot.merges then
			SeasonPassService.addXp(player, (now.merges - snapshot.merges) * Xp.Merge.Amount, "merges", Xp.Merge.DailyCap)
		end
		if now.rebirths > snapshot.rebirths then
			SeasonPassService.addXp(player, (now.rebirths - snapshot.rebirths) * Xp.Rebirth)
		end
		if now.dailyDay > snapshot.dailyDay then
			SeasonPassService.addXp(player, Xp.Daily)
		end
		-- új napon a playtime ajándékok nullázódnak: az nem felvétel
		if now.giftDay == snapshot.giftDay and now.gifts > snapshot.gifts then
			SeasonPassService.addXp(player, (now.gifts - snapshot.gifts) * Xp.Gift)
		end
		if now.nextPet > snapshot.nextPet then
			SeasonPassService.addXp(player, (now.nextPet - snapshot.nextPet) * Xp.Egg.Amount, "eggs", Xp.Egg.DailyCap)
		end

		snapshot.merges, snapshot.rebirths = now.merges, now.rebirths
		snapshot.dailyDay, snapshot.giftDay, snapshot.gifts = now.dailyDay, now.giftDay, now.gifts
		snapshot.nextPet = now.nextPet
	end
end

function SeasonPassService.start()
	Guard.connect(Remotes.SeasonClaim, onClaim)
	Players.PlayerRemoving:Connect(function(player)
		snapshots[player] = nil
		lastClaim[player] = nil
	end)
	while true do
		task.wait(1)
		tick()
	end
end

return SeasonPassService
