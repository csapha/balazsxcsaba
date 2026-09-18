-- RebirthService: Rebirth ("New Hands") server logic and event handling
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.Rebirth)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local RebirthService = {}

local function notify(player, text, color)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, text, color)
	end
end

local function broadcast(text, color)
	local remote = Net.get("Notify")
	if remote then
		remote:FireAllClients(text, color)
	end
end

function RebirthService.init()
	local rebirthRemote = Net.get("DoRebirth")
	if not rebirthRemote then
		return
	end

	rebirthRemote.OnServerEvent:Connect(function(player)
		if not PlayerData.isLoaded(player) then
			return
		end

		local ok, rebirthCount, skin = PlayerData.doRebirth(player)
		if ok then
			local newMulti = RebirthConfig.getMultiplier(rebirthCount)
			notify(
				player,
				string.format("🎉 REBIRTH #%d! Unlocked %s & x%.1f Multiplier!", rebirthCount, skin.name, newMulti),
				Color3.fromRGB(255, 215, 0)
			)

			-- Announce to all players in the server
			broadcast(
				string.format("⚡ %s just achieved REBIRTH #%d (%s skin, x%.1f permanent multi)!", player.DisplayName, rebirthCount, skin.name, newMulti),
				Color3.fromRGB(80, 240, 255)
			)
		else
			local currentRebirths = PlayerData.getRebirths(player)
			local reqPower = RebirthConfig.getPowerRequired(currentRebirths)
			notify(
				player,
				string.format("Need %s Power to Rebirth!", Format.number(reqPower)),
				Color3.fromRGB(235, 100, 100)
			)
		end
	end)
end

return RebirthService

