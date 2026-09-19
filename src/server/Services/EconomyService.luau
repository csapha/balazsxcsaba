-- Gazdaság: fejlesztések vásárlása (kezek, edzés).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local EconomyService = {}

local function notify(player, text, color)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, text, color)
	end
end

local CATEGORY_HANDLERS = {
	hands = {
		byId = Upgrades.handsById,
		getCurrent = function(data)
			return data.hands
		end,
		set = PlayerData.setHands,
		prefix = "Stronger hands: ",
	},
	training = {
		byId = Upgrades.trainingById,
		getCurrent = function(data)
			return data.training
		end,
		set = PlayerData.setTraining,
		prefix = "Training: ",
	},
	petSlots = {
		byId = Upgrades.petSlotsById,
		getCurrent = function(data)
			return data.petSlots
		end,
		set = PlayerData.setPetSlots,
		prefix = "Pet Slots: ",
	},
	speed = {
		byId = Upgrades.speedById,
		getCurrent = function(data)
			return data.speed
		end,
		set = PlayerData.setSpeed,
		prefix = "Speed: ",
	},
}

function EconomyService.init()
	Net.get("BuyUpgrade").OnServerEvent:Connect(function(player, kind, id)
		if type(kind) ~= "string" or type(id) ~= "string" then
			return
		end
		if not PlayerData.isLoaded(player) then
			return
		end

		local handler = CATEGORY_HANDLERS[kind]
		if not handler then
			return
		end

		local data = PlayerData.get(player)
		local currentId = handler.getCurrent(data)
		local current = handler.byId[currentId]
		local target = handler.byId[id]

		if not target or (current and target.order ~= current.order + 1) then
			notify(player, "Buy the previous tier first!", Color3.fromRGB(235, 100, 100))
			return
		end

		if not PlayerData.trySpend(player, target.cost) then
			notify(
				player,
				("Not enough cash (need %s)"):format(Format.money(target.cost)),
				Color3.fromRGB(235, 100, 100)
			)
			return
		end

		handler.set(player, target.id)
		notify(player, handler.prefix .. target.name .. "!", Color3.fromRGB(80, 220, 140))
	end)

	local claimRemote = Net.get("ClaimDailyReward")
	if claimRemote then
		claimRemote.OnServerEvent:Connect(function(player)
			if not PlayerData.isLoaded(player) then
				return
			end
			local ok, res = PlayerData.claimDaily(player)
			if ok then
				notify(
					player,
					"Claimed " .. res.title .. ": " .. res.displayReward .. "!",
					Color3.fromRGB(80, 245, 120)
				)
			else
				notify(player, "Daily reward is not ready yet!", Color3.fromRGB(235, 100, 100))
			end
		end)
	end
end

return EconomyService
