-- GachaService: Ládanyitási logika, pity és kesztyű-anyag kezelés
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gacha = require(Shared.Config.Gacha)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local GachaService = {}

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

-- Súlyozott random választás
local function rollWeighted(pool)
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.weight
	end

	local rand = math.random() * totalWeight
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.weight
		if rand <= cumulative then
			return entry.material
		end
	end

	return pool[#pool].material
end

function GachaService.init()
	-- Láda nyitása
	local openRemote = Net.get("OpenChest")
	if openRemote then
		openRemote.OnServerEvent:Connect(function(player, chestId)
			if type(chestId) ~= "string" then
				return
			end
			if not PlayerData.isLoaded(player) then
				return
			end

			local chest = Gacha.chestsById[chestId]
			if not chest then
				return
			end

			if not PlayerData.trySpend(player, chest.cost) then
				notify(
					player,
					("Not enough cash (need %s)"):format(Format.money(chest.cost)),
					Color3.fromRGB(235, 100, 100)
				)
				return
			end

			local pity = PlayerData.getPity(player)
			local wasPity = false
			local rolledMatId = nil

			if pity + 1 >= Gacha.pityThreshold then
				wasPity = true
				rolledMatId = rollWeighted(Gacha.pityPool)
			else
				rolledMatId = rollWeighted(chest.pool)
			end

			local materialDef = Gacha.materials[rolledMatId]
			if not materialDef then
				materialDef = Gacha.materials.Rubber
				rolledMatId = "Rubber"
			end

			local newPity = pity + 1
			if materialDef.tier >= 4 then
				newPity = 0
				PlayerData.setPity(player, 0)
			else
				PlayerData.setPity(player, newPity)
			end

			PlayerData.addMaterial(player, rolledMatId)

			print(string.format("[GACHA] %s opened %s -> %s (x%.1f)", player.DisplayName, chest.name, materialDef.name, materialDef.multiplier))

			local openedRemote = Net.get("ChestOpened")
			if openedRemote then
				openedRemote:FireClient(player, {
					material = materialDef,
					wasPity = wasPity,
					pity = newPity,
					chest = chest,
				})
			end

			if materialDef.rarity == "Secret" then
				broadcast(
					string.format("[SECRET] %s unboxed %s (x%.1f multiplier)!", player.DisplayName, materialDef.name, materialDef.multiplier),
					Color3.fromRGB(255, 20, 147)
				)
			elseif materialDef.rarity == "Legendary" then
				broadcast(
					string.format("[LEGENDARY] %s unboxed %s (x%.1f multiplier)!", player.DisplayName, materialDef.name, materialDef.multiplier),
					Color3.fromRGB(255, 215, 0)
				)
			end
		end)
	end

	-- Anyag felszerelése
	local equipRemote = Net.get("EquipMaterial")
	if equipRemote then
		equipRemote.OnServerEvent:Connect(function(player, materialId)
			if type(materialId) ~= "string" then
				return
			end
			if not PlayerData.isLoaded(player) then
				return
			end

			local materials = PlayerData.getMaterials(player)
			if (materials[materialId] or 0) <= 0 then
				notify(player, "You do not own this material!", Color3.fromRGB(235, 100, 100))
				return
			end

			local materialDef = Gacha.materials[materialId]
			if not materialDef then
				return
			end

			PlayerData.setEquippedMaterial(player, materialId)
			notify(
				player,
				string.format("Equipped %s material (x%.1f multiplier)!", materialDef.name, materialDef.multiplier),
				Color3.fromRGB(80, 240, 120)
			)
		end)
	end
end

return GachaService

