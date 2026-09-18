-- Bányászat (szerver-oldali hitelesítés).
-- NEM kell a kőre célozni: elég, ha a játékos közel van a bányakőhöz,
-- a kezében van a csákány, és az ütés cooldownon kívül esik.
-- Csak olyan érc eshet, amelyikhez van tényleges modell (Gem_*).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Hierarchy = require(Shared.Hierarchy)
local Ores = require(Shared.Config.Ores)
local Pickaxes = require(Shared.Config.Pickaxes)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local OreService = require(script.Parent.OreService)

local MiningService = {}

local lastHit = {} -- [userId] = os.clock()
local mineModel = nil
local availableOres = {}

local function nearMine(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not mineModel or not root then
		return false
	end
	local distance = (root.Position - mineModel:GetPivot().Position).Magnitude
	return distance <= GameConfig.MineReach
end

local function hasPickaxeEquipped(player)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool.Name == "Pickaxe"
end

local function broadcastMined(miner, ore, position)
	local remote = Net.get("OreMined")
	if not remote then
		return
	end

	local payload = { oreId = ore.id, position = position }
	for _, player in ipairs(Players:GetPlayers()) do
		if player == miner then
			remote:FireClient(player, payload)
		else
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and position
				and (root.Position - position).Magnitude <= GameConfig.EffectBroadcastRange then
				remote:FireClient(player, payload)
			end
		end
	end
end

local function tryHit(player)
	if not PlayerData.isLoaded(player) then
		return
	end

	if not nearMine(player) then
		return
	end

	if not hasPickaxeEquipped(player) then
		return
	end

	local now = os.clock()
	if now - (lastHit[player.UserId] or 0) < GameConfig.HitCooldown then
		return
	end
	lastHit[player.UserId] = now

	local data = PlayerData.get(player)
	local pickaxe = Pickaxes.byId[data.pickaxe] or Pickaxes.byId[Pickaxes.defaultId]
	local ore = Ores.roll(pickaxe.luck, availableOres)
	if not ore then
		return
	end

	PlayerData.registerHit(player)

	local instance, anchorPart = OreService.spawnOre(player, ore)
	local position = instance and anchorPart and anchorPart.Position or nil
	broadcastMined(player, ore, position)

	if ore.tier >= 5 then
		Net.get("Notify"):FireClient(player, "Rare find: " .. ore.name .. "!")
	end
end

function MiningService.init()
	mineModel = Hierarchy.find(Workspace, GameConfig.Paths.Mine)
	if not mineModel then
		mineModel = Workspace:FindFirstChild(GameConfig.MineTemplateName)
	end
	if not mineModel then
		warn("[MiningService] Nem találom a bányakövet (Workspace.Map.Mine.MineRock)!")
		return
	end

	availableOres = OreService.getAvailableOres()
	if #availableOres == 0 then
		warn("[MiningService] Egyetlen ércmodell sem található a Gem sablonok között!")
	end

	Net.get("MineRequest").OnServerEvent:Connect(function(player)
		tryHit(player)
	end)
end

return MiningService
