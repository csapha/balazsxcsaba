-- Gazdaság: érc eladás és csákány vásárlás.
-- Minden ellenőrzés szerver-oldalon történik (kliens csak kér).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ores = require(Shared.Config.Ores)
local Pickaxes = require(Shared.Config.Pickaxes)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local EconomyService = {}

local function notify(player, message)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, message)
	end
end

function EconomyService.sellOre(player, oreId)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	local ore = Ores.byId[oreId]
	local count = data.inventory[oreId] or 0
	if not ore or count <= 0 then
		return
	end

	local total = ore.value * count
	data.inventory[oreId] = 0
	PlayerData.addCash(player, total)
	notify(player, ("Sold %d x %s: +%s"):format(count, ore.name, Format.money(total)))
end

function EconomyService.buyPickaxe(player, tierId)
	local data = PlayerData.get(player)
	local tier = Pickaxes.byId[tierId]
	if not data or not tier then
		return
	end

	local current = Pickaxes.byId[data.pickaxe] or Pickaxes.byId[Pickaxes.defaultId]
	if tier.order <= current.order then
		notify(player, "You already own this pickaxe.")
		return
	end
	if tier.order ~= current.order + 1 then
		notify(player, "Buy the previous tier first!")
		return
	end
	if data.cash < tier.cost then
		notify(player, ("Not enough cash (need %s)."):format(Format.money(tier.cost)))
		return
	end

	PlayerData.trySpend(player, tier.cost)
	PlayerData.setPickaxe(player, tier.id)
	notify(player, "New pickaxe: " .. tier.name .. "!")
end

function EconomyService.init()
	Net.get("SellOre").OnServerEvent:Connect(function(player, oreId)
		if type(oreId) ~= "string" then
			return
		end
		EconomyService.sellOre(player, oreId)
	end)

	Net.get("BuyPickaxe").OnServerEvent:Connect(function(player, tierId)
		if type(tierId) ~= "string" then
			return
		end
		EconomyService.buyPickaxe(player, tierId)
	end)
end

return EconomyService
