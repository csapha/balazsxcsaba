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

function EconomyService.init()
	Net.get("BuyUpgrade").OnServerEvent:Connect(function(player, kind, id)
		if type(kind) ~= "string" or type(id) ~= "string" then
			return
		end
		if not PlayerData.isLoaded(player) then
			return
		end

		local data = PlayerData.get(player)

		if kind == "hands" then
			-- id = a MEGVÁSárolni kívánt tier (a következő kell legyen)
			local current = Upgrades.handsById[data.hands]
			local target = Upgrades.handsById[id]
			if not target or target.order ~= current.order + 1 then
				notify(player, "Buy the previous tier first!", Color3.fromRGB(235, 100, 100))
				return
			end
			if not PlayerData.trySpend(player, target.cost) then
				notify(player,
					("Not enough cash (need %s)"):format(Format.money(target.cost)),
					Color3.fromRGB(235, 100, 100))
				return
			end
			PlayerData.setHands(player, target.id)
			notify(player, "Stronger hands: " .. target.name .. "!", Color3.fromRGB(80, 220, 140))
		elseif kind == "training" then
			local current = Upgrades.trainingById[data.training]
			local target = Upgrades.trainingById[id]
			if not target or target.order ~= current.order + 1 then
				notify(player, "Buy the previous tier first!", Color3.fromRGB(235, 100, 100))
				return
			end
			if not PlayerData.trySpend(player, target.cost) then
				notify(player,
					("Not enough cash (need %s)"):format(Format.money(target.cost)),
					Color3.fromRGB(235, 100, 100))
				return
			end
			PlayerData.setTraining(player, target.id)
			notify(player, "Training: " .. target.name .. "!", Color3.fromRGB(80, 220, 140))
		end
	end)
end

return EconomyService
