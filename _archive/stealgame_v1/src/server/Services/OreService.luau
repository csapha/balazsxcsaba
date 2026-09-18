-- Ércek a világban (drop).
-- Nincs ProximityPrompt: a gemet a játékos FELSÉTÁLÁSSAL szedi fel (Touched),
-- ilyenkor a gem a játékoshoz repül (magnet), majd az inventoryba kerül.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Hierarchy = require(Shared.Hierarchy)
local Ores = require(Shared.Config.Ores)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local OreService = {}

local oreFolder = nil

local function getMineModel()
	local mine = Hierarchy.find(Workspace, GameConfig.Paths.Mine)
	if mine then
		return mine
	end
	return Workspace:FindFirstChild(GameConfig.MineTemplateName)
end

-- sablon keresési sorrend:
--   ServerStorage.Templates.Gems -> ReplicatedStorage.Assets -> Workspace
local function findTemplate(ore)
	local name = ore.template or ("Gem_" .. ore.id)

	local templates = Hierarchy.find(ServerStorage, GameConfig.Paths.GemTemplates)
	if templates then
		local template = templates:FindFirstChild(name)
		if template then
			return template
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local template = assets:FindFirstChild(name)
		if template then
			return template
		end
	end

	return Workspace:FindFirstChild(name)
end

local function getSpawnPosition(mine)
	local pivot = mine:GetPivot()
	local angle = math.random() * math.pi * 2
	local distance = 2.0 + math.random() * 2.5
	return pivot.Position
		+ Vector3.new(math.cos(angle) * distance, 1.0, math.sin(angle) * distance)
end

local function prepareClone(clone)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = true
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end

	if clone:IsA("Model") then
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
		end
		return clone.PrimaryPart ~= nil
	end

	return clone:IsA("BasePart")
end

-- csak azok az ércek kerülnek a sorsolásba, amelyekhez van tényleges modell
function OreService.getAvailableOres()
	local list = {}
	for _, ore in ipairs(Ores.list) do
		if findTemplate(ore) then
			table.insert(list, ore)
		end
	end
	return list
end

local function getPosition(instance)
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return instance.Position
end

local function moveTo(instance, cframe)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	else
		instance.CFrame = cframe
	end
end

local function collect(instance, anchorPart, player)
	if not instance.Parent or instance:GetAttribute("Collecting") then
		return
	end

	local ownerUserId = instance:GetAttribute("OwnerUserId") or anchorPart:GetAttribute("OwnerUserId")
	if ownerUserId ~= player.UserId then
		return
	end

	if not PlayerData.isLoaded(player) then
		return
	end

	local oreId = instance:GetAttribute("OreId") or anchorPart:GetAttribute("OreId")
	local ore = Ores.byId[oreId]
	if not ore then
		instance:Destroy()
		return
	end

	instance:SetAttribute("Collecting", true)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		instance:Destroy()
		return
	end

	-- szép magnet: ívelt pálya, gyorsuló pörgéssel
	local startPos = getPosition(instance)
	local started = os.clock()
	while instance.Parent and root.Parent do
		local t = math.clamp((os.clock() - started) / GameConfig.OreMagnetTime, 0, 1)
		local eased = 1 - (1 - t) ^ 3 -- easeOutCubic
		local position = startPos:Lerp(root.Position, eased)
			+ Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
		moveTo(instance, CFrame.new(position) * CFrame.Angles(0, t * math.rad(720), 0))
		if t >= 1 then
			break
		end
		task.wait()
	end

	if not instance.Parent then
		return
	end

	PlayerData.addOre(player, oreId, 1)

	local remote = Net.get("OrePicked")
	if remote then
		remote:FireClient(player, { oreId = oreId, position = getPosition(instance) })
	end

	instance:Destroy()
end

local function hookTouch(instance, anchorPart)
	local function onTouched(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			collect(instance, anchorPart, player)
		end
	end

	if instance:IsA("Model") then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Touched:Connect(onTouched)
			end
		end
	else
		instance.Touched:Connect(onTouched)
	end
end

function OreService.init()
	oreFolder = Hierarchy.ensureFolder(Workspace, GameConfig.Paths.Drops)
end

function OreService.spawnOre(player, ore)
	local mine = getMineModel()
	if not mine or not oreFolder then
		return nil, nil
	end

	local template = findTemplate(ore)
	if not template then
		return nil, nil
	end

	local clone = template:Clone()
	if not prepareClone(clone) then
		clone:Destroy()
		return nil, nil
	end

	local spawnCFrame = CFrame.new(getSpawnPosition(mine))
		* CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

	local anchorPart
	if clone:IsA("Model") then
		clone:PivotTo(spawnCFrame)
		anchorPart = clone.PrimaryPart
	else
		clone.CFrame = spawnCFrame
		anchorPart = clone
	end

	clone:SetAttribute("OreId", ore.id)
	clone:SetAttribute("OwnerUserId", player.UserId)
	anchorPart:SetAttribute("OreId", ore.id)
	anchorPart:SetAttribute("OwnerUserId", player.UserId)

	hookTouch(clone, anchorPart)
	clone.Parent = oreFolder

	task.delay(GameConfig.OreLifetime, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)

	return clone, anchorPart
end

return OreService
