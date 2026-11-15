-- Shop (GDD 5) + Robux vásárlások (GDD 6.2–6.3).
--   Gamepass: belépéskor UserOwnsGamePassAsync → data.passes; vásárlás után PromptGamePassPurchaseFinished.
--   Dev product: ProcessReceipt; a teljesített PurchaseId-k a data.receipts-be kerülnek (ne teljesüljön kétszer).
--   Studióban a 0-s ID-jű termék ingyen teljesül (teszt, döntés 2026-11-15); élesben a 0-s ID nem vehető.
--   Kódok (GDD 5.1 ⑦): a RewardService-ben (Config.Codes); a Boost jutalomhoz a ShopService.addBoost-ot hívja.
--   Robux padek a telken (GDD 6.1): Config.Plot.Pads RobuxPass kulccsal.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local AuraService = require(script.Parent.AuraService)
local CosmeticService = require(script.Parent.CosmeticService)
local EventService = require(script.Parent.EventService)
local IndexService = require(script.Parent.IndexService)
local MembershipService = require(script.Parent.MembershipService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local RebirthService = require(script.Parent.RebirthService)

local ShopConfig = Config.Shop
local Palette = Config.Palette
local IS_STUDIO = RunService:IsStudio()
local MAX_RECEIPTS = 50
local BOOST_CLEANUP = 1 -- mp
local DEFAULT_JUMP_HEIGHT = 7.2
local DEFAULT_JUMP_POWER = 50

local ShopService = {}

-- ProductId → mit ad (termék vagy kozmetikum); GamePassId → gamepass kulcs (csak a 0-tól különböző ID-k)
type Grant = { kind: "Product" | "Cosmetic", key: string }
local productsById: { [number]: Grant } = {}
local passesById: { [number]: string } = {}

local function itemName(kind: string, key: string): string
	local item = if kind == "Pass" then ShopConfig.Passes[key] else ShopConfig.Products[key]
	return if item then item.Name else key
end

-- Bevétel-skálázott pénz (a Cash csomagok és a kód-jutalmak): seconds mp bevétel, legalább min $.
local function incomeCash(player: Player, raw: any, seconds: number, min: number): number
	local perSecond = Formulas.incomePerSecond(raw) * IndexService.moneyBonus(player)
	return math.max(min, math.floor(perSecond * seconds))
end

local function addBoost(data: any, key: string, duration: number)
	local boosts = table.clone(data().timedBoosts)
	local now = os.time()
	boosts[key] = math.max(boosts[key] or 0, now) + duration
	data.timedBoosts(boosts)
end

-- Robuxért kapott pénz (analytics: IAP forrás, sku = a termék kulcsa)
local function addMoney(player: Player, data: any, amount: number, sku: string)
	data.money(data().money + amount)
	AnalyticsService.source(player, amount, "IAP", sku)
end

-- Időszakos boost (a kódok is adhatnak ilyet: RewardService).
ShopService.addBoost = addBoost

-- Elérhető-e most a termék (a kliens is ugyanezt nézi, a szerver a vásárlás előtt is ellenőrzi).
local function available(raw: any, key: string): boolean
	local item = ShopConfig.Products[key]
	if not item or item.Soon or not item.Effect then
		return false
	end
	if item.Effect == "Starter" then
		return Formulas.starterRemaining(raw) > 0
	elseif item.Effect == "OfflineX10" then
		return raw.offline.pending > 0
	elseif item.Effect == "RebirthSkip" then
		return key == Formulas.rebirthSkipProduct(raw.rebirths) and Formulas.rebirthSkipReady(raw)
	end
	return true
end

-- Super Jump: Duration mp-ig magas ugrás (a karakter újraszületésekor visszaáll az alap).
local function superJump(player: Player, item: any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local token = (player:GetAttribute("SuperJump") or 0) + 1
	player:SetAttribute("SuperJump", token)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = item.JumpHeight
	task.delay(item.Duration, function()
		if player:GetAttribute("SuperJump") == token and humanoid.Parent then
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	end)
end

-- Egy dev product hatása. Visszaad: sikerült-e, és a felugró szöveg.
local function grantProduct(player: Player, key: string): (boolean, string)
	local data = DataService.get(player)
	local item = ShopConfig.Products[key]
	if not data or not item then
		return false, ""
	end
	local raw = data()
	local effect = item.Effect

	if effect == "Cash" then
		local amount = incomeCash(player, raw, item.Seconds, item.Min)
		addMoney(player, data, amount, key)
		return true, `+{NumberFormat.money(amount)}`
	elseif effect == "Boost" then
		addBoost(data, item.Boost, item.Duration)
		return true, `{ShopConfig.BoostNames[item.Boost]} active!`
	elseif effect == "AuraRoll" then
		return AuraService.roll(player, "free") ~= nil, "Aura roll!"
	elseif effect == "OfflineX10" then
		local pending = raw.offline.pending
		if pending <= 0 then
			-- időközben felvette: helyette 15 perc bevétel (a vásárlás már megtörtént)
			local amount = incomeCash(player, raw, 15 * 60, 1_000)
			addMoney(player, data, amount, key)
			return true, `+{NumberFormat.money(amount)}`
		end
		local amount = pending * 10
		data.money(raw.money + amount)
		AnalyticsService.source(player, amount, "IAP", key)
		data.cycleEarned(raw.cycleEarned + pending) -- a sima felvétel is számít a rebirthbe
		data.offline({ pending = 0, seconds = 0 })
		return true, `+{NumberFormat.money(amount)} (x10)`
	elseif effect == "Starter" then
		addBoost(data, item.Boost, item.Duration)
		PetService.give(player, item.Pet)
		addMoney(player, data, item.Cash, key)
		local shop = table.clone(data().shop)
		shop.starterBought = true
		data.shop(shop)
		return true, "Starter Pack unlocked!"
	elseif effect == "RobuxEgg" then
		-- a tojásnyitás animációja maga a visszajelzés
		return #PetService.openRobuxEgg(player, item.Count) > 0, ""
	elseif effect == "RebirthSkip" then
		local state = PlotService.get(player)
		return state ~= nil and RebirthService.skip(state), ""
	elseif effect == "SuperJump" then
		superJump(player, item)
		return true, `Super Jump for {item.Duration} seconds!`
	elseif effect == "SchnitzelRain" then
		EventService.rain(item)
		Remotes.FunEffect:FireAllClients("SchnitzelRain", player.DisplayName)
		return true, "Schnitzels are raining on the street!"
	elseif effect == "Tenderize" then
		Remotes.FunEffect:FireAllClients("Tenderize", player.DisplayName)
		return true, "You tenderized the server!"
	end
	return false, ""
end

local function grantPass(player: Player, key: string, silent: boolean?): boolean
	local data = DataService.get(player)
	if not data or not ShopConfig.Passes[key] then
		return false
	end
	local raw = data()
	if raw.passes[key] then
		return true
	end
	local passes = table.clone(raw.passes)
	passes[key] = true
	data.passes(passes)
	player:SetAttribute("Pass" .. key, true) -- a kliens ebből állítja a tojás promptjait
	if not silent then
		Remotes.ShopPurchased:FireClient(player, "Pass", key, `{itemName("Pass", key)} unlocked!`)
	end
	if key == "VIP" then
		MembershipService.refresh(player) -- címke, VIP pet, napi ajándék
	end
	return true
end

local function notifyProduct(player: Player, key: string, message: string)
	if message ~= "" then
		Remotes.ShopPurchased:FireClient(player, "Product", key, message)
	end
end

local function grantCosmetic(player: Player, id: string): boolean
	local ok = CosmeticService.grant(player, id)
	if ok then
		Remotes.ShopPurchased:FireClient(player, "Cosmetic", id, "Equipped!")
	end
	return ok
end

-- Robux termék: van ID → Roblox vásárlás ablak; nincs ID → Studióban ingyen (teszt), élesben semmi.
local function promptProduct(player: Player, productId: number, freeGrant: () -> ())
	if productId > 0 then
		MarketplaceService:PromptProductPurchase(player, productId)
	elseif IS_STUDIO then
		freeGrant()
	end
end

local function grantAndNotify(player: Player, key: string)
	local ok, message = grantProduct(player, key)
	if ok then
		notifyProduct(player, key, message)
	end
end

-- Vásárlás indítása a kliens kérésére.
local function onBuy(player: Player, kind: unknown, key: unknown)
	local data = DataService.get(player)
	if not data then
		return
	end
	local raw = data()

	if kind == "Pass" and type(key) == "string" then
		local item = ShopConfig.Passes[key]
		if not item or item.Soon or raw.passes[key] then
			return
		end
		if item.GamePassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, item.GamePassId)
		elseif IS_STUDIO then
			grantPass(player, key)
		end
	elseif kind == "Product" and type(key) == "string" then
		local item = ShopConfig.Products[key]
		if not item or not available(raw, key) then
			return
		end
		promptProduct(player, item.ProductId, function()
			grantAndNotify(player, key)
		end)
	elseif kind == "Deal" and type(key) == "number" then
		local deal = ShopConfig.Deals[key]
		if key ~= Formulas.dailyDeal() or not deal or not available(raw, deal.Product) then
			return
		end
		promptProduct(player, deal.ProductId, function()
			grantAndNotify(player, deal.Product)
		end)
	elseif kind == "EventOffer" and type(key) == "string" then
		local offer = ShopConfig.EventOffers[key]
		if not offer or not EventState.is(key) or not available(raw, offer.Product) then
			return
		end
		promptProduct(player, offer.ProductId, function()
			grantAndNotify(player, offer.Product)
		end)
	elseif kind == "Cosmetic" and type(key) == "string" then
		-- csak trail vehető (a telek témák később feloldhatók lesznek, nem a Shopban – döntés 2026-11-15)
		local item = ShopConfig.Trails[key]
		if not item or not item.Price or CosmeticService.owns(raw, key) then
			return
		end
		promptProduct(player, item.ProductId, function()
			grantCosmetic(player, key)
		end)
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and DataService.get(player)
	local grant = productsById[info.ProductId]
	if not player or not data or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data().receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, granted, message
	if grant.kind == "Cosmetic" then
		ok, granted = pcall(grantCosmetic, player, grant.key)
		message = ""
	else
		ok, granted, message = pcall(grantProduct, player, grant.key)
	end
	if not ok or not granted then
		warn(`[ShopService] {grant.key} not granted: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = table.clone(data().receipts)
	table.insert(receipts, info.PurchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	data.receipts(receipts, false) -- nem kell a kliensnek
	if grant.kind == "Product" then
		notifyProduct(player, grant.key, message)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Belépéskor: a megvett Roblox gamepassok beírása a mentésbe.
local function checkOwnedPasses(player: Player)
	if not DataService.wait(player) then
		return
	end
	for id, key in passesById do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok and owns then
			grantPass(player, key, true)
		end
	end
	-- a mentésben lévő gamepassok attribútuma (a kliens ebből állítja a tojás promptjait)
	local data = DataService.get(player)
	if data then
		for key, owned in data().passes do
			if owned then
				player:SetAttribute("Pass" .. key, true)
			end
		end
	end
	MembershipService.refresh(player)
end

-- GDD 6.5: a kliens jelzi, hogy egy ajánlat-toast megjelent (többet ne jöjjön).
local function onToastSeen(player: Player, id: unknown)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" or not ShopConfig.Toasts.List[id] or data().shop.toasts[id] then
		return
	end
	local shop = table.clone(data().shop)
	shop.toasts = table.clone(shop.toasts)
	shop.toasts[id] = true
	data.shop(shop)
end

-- A lejárt boostok törlése: így az adat változik, és a sütők / szalag újra számolnak (BakeInterval).
local function cleanupBoosts()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end
		local boosts = data().timedBoosts
		local expired = false
		for _, expires in boosts do
			if expires <= now then
				expired = true
				break
			end
		end
		if expired then
			local kept = {}
			for key, expires in boosts do
				if expires > now then
					kept[key] = expires
				end
			end
			data.timedBoosts(kept)
		end
	end
end

-- GDD 6.1: Robux padek a telken – rálépve feljön a gamepass vásárlás; ha már megvan, "OWNED".
local function renderRobuxPads(state: PlotService.PlotState, raw: any)
	for key, pad in Config.Plot.Pads do
		local passKey = pad.RobuxPass
		local labels = passKey and state.plot.labels[key]
		if labels then
			local owned = Formulas.hasPass(raw, passKey)
			labels.Info.Text = if owned then "OWNED" else `R$ {ShopConfig.Passes[passKey].Price}`
			labels.Info.TextColor3 = if owned then Palette.Money else Palette.Gold
		end
	end
end

function ShopService.init()
	for key, item in ShopConfig.Products do
		if item.ProductId > 0 then
			productsById[item.ProductId] = { kind = "Product", key = key }
		end
	end
	for _, deal in ShopConfig.Deals do
		if deal.ProductId > 0 then
			productsById[deal.ProductId] = { kind = "Product", key = deal.Product }
		end
	end
	for _, offer in ShopConfig.EventOffers do
		if offer.ProductId > 0 then
			productsById[offer.ProductId] = { kind = "Product", key = offer.Product }
		end
	end
	for _, list in { ShopConfig.Trails, ShopConfig.Themes } do
		for id, item in list do
			if (item.ProductId or 0) > 0 then
				productsById[item.ProductId] = { kind = "Cosmetic", key = id }
			end
		end
	end
	for key, item in ShopConfig.Passes do
		if item.GamePassId > 0 then
			passesById[item.GamePassId] = key
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
	-- a tojás "Open 3" / "Fast Open" promptja gamepass nélkül a vásárlást indítja
	PetService.requestPass = function(player: Player, key: string)
		onBuy(player, "Pass", key)
	end

	for key, pad in Config.Plot.Pads do
		local passKey = pad.RobuxPass
		if passKey then
			PlotService.registerPad(key, {
				enter = function(player, _state)
					onBuy(player, "Pass", passKey)
				end,
			})
		end
	end
	PlotService.addRenderer(renderRobuxPads)
end

function ShopService.start()
	Guard.connect(Remotes.ShopBuy, onBuy)
	Guard.connect(Remotes.ToastSeen, onToastSeen)
	-- (a kódbeváltás a RewardService-ben van: Settings ablak, Config.Codes)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passesById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)

	Players.PlayerAdded:Connect(checkOwnedPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnedPasses, player)
	end

	task.spawn(function()
		while true do
			task.wait(BOOST_CLEANUP)
			cleanupBoosts()
		end
	end)
end

return ShopService
