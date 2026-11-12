-- Rebirth (GDD 3.8). A kliens a Rebirth ablakból kéri (Remotes.RequestRebirth), a szerver ellenőrzi.
-- Teljes újrakezdés: pénz → kezdőpénz, sütők, generáció, eladó, chefek, pult, minden készlet nullázódik.
-- Megmarad: rebirth szám, tokenek, slotok (a rebirth bővíti), Index, statisztikák.
-- Jutalom: pénzszorzó x(1 + rebirthek), +1 Rebirth Token, az 1–3. rebirth +4 slot, a 3. +1 max chef.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local ChefService = require(script.Parent.ChefService)

local COOLDOWN = 2 -- mp (dupla kattintás ellen)

local RebirthService = {}

local lastRebirth: { [Player]: number } = {}

function RebirthService.canRebirth(raw: any): boolean
	return raw.cycleEarned >= Formulas.rebirthRequirement(raw.rebirths)
end

function RebirthService.rebirth(state: PlotService.PlotState): boolean
	local data = state.data
	local raw = data()
	if not RebirthService.canRebirth(raw) then
		return false
	end

	local rarityCount = #Config.Rarities.List
	local rebirths = raw.rebirths + 1
	local baseMoney = if RunService:IsStudio() then Config.Game.StudioStartMoney else Config.Game.StartMoney
	-- rebirth-fa: kezdőpénz ×10^szint, kezdő chefek, kezdő generáció
	local startMoney = baseMoney * Formulas.perkValue(raw, "StartMoney")
	local startChefs = math.min(Formulas.perkValue(raw, "StartChefs"), Formulas.maxChefs(rebirths))
	local startGeneration = math.min(1 + Formulas.perkValue(raw, "StartGeneration"), Formulas.maxGeneration())

	-- futó szimulációk leállítása (szalagon lévő sütések, chefek)
	state.pending = {}
	state.lastCycle = {}
	state.sellRemainder = 0
	ChefService.reset(state)

	-- jutalom
	data.rebirths(rebirths)
	data.rebirthTokens(raw.rebirthTokens + Config.Rebirth.TokensPerRebirth)
	data.slots(math.max(raw.slots, Formulas.rebirthSlots(rebirths)))

	-- nullázás
	data.money(startMoney)
	data.ovens(table.create(Config.Ovens.MaxSlots, 0))
	data.ovensBought(0)
	data.cycleEarned(0)
	data.generation(startGeneration)
	data.generationBought(0)
	data.tray({
		count = 0,
		units = 0,
		value = 0,
		rarityCount = table.create(rarityCount, 0),
		rarityUnits = table.create(rarityCount, 0),
		rarityValue = table.create(rarityCount, 0),
	})
	data.carried(0)
	data.carriedValue(0)
	data.counterStock(0)
	data.counterValue(0)
	data.moneyPile(0)
	data.upgrades.sellSpeed(0)
	data.chefs({ count = startChefs, stack = 0, speed = 0, stamina = 0, antiSleep = 0 })
	data.counter({ level = 1, xp = 0 })

	Remotes.Rebirthed:FireClient(state.player, rebirths, Formulas.rebirthMultiplier(rebirths))
	PlotService.teleportHome(state.player)
	return true
end

-- Rebirth-fa: egy perk szint vásárlása Rebirth Tokenért.
function RebirthService.buyPerk(state: PlotService.PlotState, perk: unknown): boolean
	local tree = Config.Rebirth.Tree
	if type(perk) ~= "string" or not tree.Perks[perk] then
		return false
	end
	local data = state.data
	local raw = data()
	local level = Formulas.perkLevel(raw, perk)
	if level >= tree.Perks[perk].Max or raw.rebirthTokens < tree.TokenCost then
		return false
	end
	data.rebirthTokens(raw.rebirthTokens - tree.TokenCost)
	data.rebirthPerks[perk](level + 1)
	return true
end

local function onRequest(player: Player)
	local now = os.clock()
	if lastRebirth[player] and now - lastRebirth[player] < COOLDOWN then
		return
	end
	local state = PlotService.get(player)
	if not state then
		return
	end
	if RebirthService.rebirth(state) then
		lastRebirth[player] = now
	end
end

function RebirthService.start()
	Remotes.RequestRebirth.OnServerEvent:Connect(onRequest)
	Remotes.BuyPerk.OnServerEvent:Connect(function(player, perk: unknown)
		local state = PlotService.get(player)
		if state then
			RebirthService.buyPerk(state, perk)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRebirth[player] = nil
	end)
end

return RebirthService
