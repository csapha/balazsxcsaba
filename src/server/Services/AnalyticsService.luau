-- GDD 13: analytics (Roblox AnalyticsService → Creator Hub, Analytics).
--   Onboarding funnel: betöltés → első sütő → első merge → első eladás → első pénzfelvétel → első chef →
--     első tojás → első rebirth. Minden lépés egyszer játékosonként (mentve: Data.funnel, bitmaszk).
--   Economy: a pénz forrásai (Source) és nyelői (Sink). Nem minden eseményt küld külön (másodpercenként
--     több vásárlás / eladás is lehet): játékosonként és tételenként összegyűjti, és percenként egyszer küldi.
-- A szolgáltatások hívják: AnalyticsService.step(player, "FirstOven"), .source(...), .sink(...).
-- Studióban a Roblox nem küld adatot; a Config.Game.AnalyticsDebug (csak Studióban) kiírja, mi menne el.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ReplicatedStorage.Shared.Data)

local FLUSH_INTERVAL = 60
local DEBUG = RunService:IsStudio() and Config.Game.AnalyticsDebug
local CURRENCY = "Money"

-- a funnel lépései, sorrendben (a sorszám a Roblox lépésszáma)
local STEPS = {
	"Loaded",
	"FirstOven",
	"FirstMerge",
	"FirstSale",
	"FirstCollect",
	"FirstChef",
	"FirstEgg",
	"FirstRebirth",
}
local STEP_INDEX = {}
for index, name in STEPS do
	STEP_INDEX[name] = index
end

-- Roblox tranzakció-típusok (Enum.AnalyticsEconomyTransactionType)
export type TransactionType = "Gameplay" | "Shop" | "TimedReward" | "Onboarding" | "ContextualPurchase" | "IAP"

type Pending = { flow: Enum.AnalyticsEconomyFlowType, kind: string, sku: string, amount: number }

local AnalyticsService = {}

local pending: { [Player]: { [string]: Pending } } = {}

local function debugPrint(message: string)
	if DEBUG then
		print(`[Analytics] {message}`)
	end
end

-- Az onboarding funnel egy lépése (egyszer játékosonként; ha már megvolt, nem csinál semmit).
function AnalyticsService.step(player: Player, name: string)
	local index = STEP_INDEX[name]
	local data = Data.server[player]
	if not index or not data then
		return
	end
	local mask = data.funnel()
	local bit = 2 ^ (index - 1)
	if bit32.btest(mask, bit) then
		return
	end
	data.funnel(bit32.bor(mask, bit), false) -- false: a kliensnek nem kell
	debugPrint(`{player.Name} funnel {index} {name}`)
	local ok, err = pcall(RobloxAnalytics.LogOnboardingFunnelStepEvent, RobloxAnalytics, player, index, name)
	if not ok then
		warn(`[Analytics] funnel: {err}`)
	end
end

local function record(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, kind: TransactionType, sku: string)
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	local perPlayer = pending[player]
	if not perPlayer then
		if not player:IsDescendantOf(Players) then
			return
		end
		perPlayer = {}
		pending[player] = perPlayer
	end
	local key = `{flow.Name}|{kind}|{sku}`
	local entry = perPlayer[key]
	if entry then
		entry.amount += amount
	else
		perPlayer[key] = { flow = flow, kind = kind, sku = sku, amount = amount }
	end
end

-- Pénz forrása (bevétel). kind: Roblox tranzakció-típus, sku: mi adta (pl. "CounterSales", "Daily").
function AnalyticsService.source(player: Player, amount: number, kind: TransactionType, sku: string)
	record(player, Enum.AnalyticsEconomyFlowType.Source, amount, kind, sku)
end

-- Pénz nyelője (költés). sku: mire (pl. "Oven", "ChefHire", "Egg2").
function AnalyticsService.sink(player: Player, amount: number, kind: TransactionType, sku: string)
	record(player, Enum.AnalyticsEconomyFlowType.Sink, amount, kind, sku)
end

local function flush(player: Player, balance: number?)
	local perPlayer = pending[player]
	if not perPlayer or next(perPlayer) == nil then
		return
	end
	pending[player] = {}
	if not balance then
		local data = Data.server[player]
		balance = if data then data.money() else 0
	end
	for _, entry in perPlayer do
		debugPrint(
			`{player.Name} {entry.flow.Name} {entry.kind}/{entry.sku} {math.floor(entry.amount)} (balance {math.floor(balance :: number)})`
		)
		local ok, err = pcall(
			RobloxAnalytics.LogEconomyEvent,
			RobloxAnalytics,
			player,
			entry.flow,
			CURRENCY,
			math.floor(entry.amount),
			math.floor(balance :: number),
			entry.kind,
			entry.sku
		)
		if not ok then
			warn(`[Analytics] economy: {err}`)
		end
	end
end

function AnalyticsService.start()
	local function onJoined(player: Player)
		local data = Data.server.Service:waitForData(player)
		if data then
			AnalyticsService.step(player, "Loaded")
		end
	end
	Players.PlayerAdded:Connect(onJoined)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoined, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = Data.server[player]
		flush(player, if data then data.money() else nil)
		pending[player] = nil
	end)

	while true do
		task.wait(FLUSH_INTERVAL)
		for player in pending do
			task.spawn(flush, player)
		end
	end
end

return AnalyticsService
