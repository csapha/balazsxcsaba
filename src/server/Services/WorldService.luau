-- Világ: a tárgyak (dinnye, kókusz, ...) legyártása a mapon + respawn.
-- Minden procedurálisan jön létre, nem kell Studio-ban kézzel építeni.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local PlayerData = require(script.Parent.PlayerData)

local WorldService = {}

local mapFolder = nil
local objectFolder = nil
local tableFolder = nil
local byId = {} -- [objectId] = { part = BasePart, ... }

local TABLE_HEIGHT = 3.0 -- az asztallap teteje ennyi magasan van (stud)

local function makeTable(position, objectSize)
	-- kisebb asztal, hogy a karakter közel tudjon állni és elérje a tárgyat
	local topSize = Vector3.new(objectSize + 1.4, 0.5, objectSize + 1.4)

	local top = Instance.new("Part")
	top.Name = "TableTop"
	top.Size = topSize
	top.Color = Color3.fromRGB(122, 84, 48)
	top.Material = Enum.Material.Wood
	top.Anchored = true
	top.CanCollide = true
	top.CanTouch = false
	top.CanQuery = false
	top.CFrame = CFrame.new(position.X, TABLE_HEIGHT - 0.25, position.Z)
	top.Parent = tableFolder

	for _, offset in ipairs({
		Vector3.new(1, 0, 1),
		Vector3.new(-1, 0, 1),
		Vector3.new(1, 0, -1),
		Vector3.new(-1, 0, -1),
	}) do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.5, TABLE_HEIGHT - 0.5, 0.5)
		leg.Color = Color3.fromRGB(92, 62, 36)
		leg.Material = Enum.Material.Wood
		leg.Anchored = true
		leg.CanCollide = true
		leg.CanTouch = false
		leg.CanQuery = false
		leg.CFrame = CFrame.new(
			position.X + offset.X * (topSize.X * 0.5 - 0.4),
			(TABLE_HEIGHT - 0.5) * 0.5,
			position.Z + offset.Z * (topSize.Z * 0.5 - 0.4)
		)
		leg.Parent = tableFolder
	end
end

local function makeBillboard(part, object)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, object.size * 0.9 + 1.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.Parent = part

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromHex(object.color)
	title.TextStrokeTransparency = 0.35
	title.Text = object.name .. "  -  " .. Format.weight(object.weight)
	title.Parent = billboard

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(0, 28)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 15
	status.TextColor3 = Color3.fromRGB(235, 240, 255)
	status.TextStrokeTransparency = 0.4
	status.Text = ""
	status.Parent = billboard

	return billboard
end

local function makePrompt(part, object)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SqueezePrompt"
	prompt.ActionText = "SQUEEZE"
	prompt.ObjectText = object.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.SqueezeRange
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

local function shapeFor(object)
	if object.shape == "Ball" then
		return Enum.PartType.Ball
	elseif object.shape == "Cylinder" then
		return Enum.PartType.Cylinder
	end
	return Enum.PartType.Block
end

function WorldService.build()
	mapFolder = Workspace:FindFirstChild(GameConfig.MapName)
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = GameConfig.MapName
		mapFolder.Parent = Workspace
	end

	objectFolder = mapFolder:FindFirstChild(GameConfig.ObjectFolderName)
	if not objectFolder then
		objectFolder = Instance.new("Folder")
		objectFolder.Name = GameConfig.ObjectFolderName
		objectFolder.Parent = mapFolder
	end

	tableFolder = mapFolder:FindFirstChild("Tables")
	if not tableFolder then
		tableFolder = Instance.new("Folder")
		tableFolder.Name = "Tables"
		tableFolder.Parent = mapFolder
	end

	for _, object in ipairs(Objects.list) do
		local baseX = 30 + (object.index - 1) * GameConfig.ObjectSpacing
		local baseZ = 0

		-- asztal az objektum alá
		makeTable(Vector3.new(baseX, 0, baseZ), object.size)

		local part = Instance.new("Part")
		part.Name = object.name
		part.Shape = shapeFor(object)
		part.Size = Vector3.new(object.size, object.size, object.size)
		part.Color = Color3.fromHex(object.color)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		part.CFrame = CFrame.new(baseX, TABLE_HEIGHT + object.size * 0.5, baseZ)
		part:SetAttribute("ObjectId", object.id)
		part:SetAttribute("Weight", object.weight)
		part:SetAttribute("Active", true)

		local billboard = makeBillboard(part, object)
		local prompt = makePrompt(part, object)
		part.Parent = objectFolder

		byId[object.id] = {
			part = part,
			billboard = billboard,
			status = billboard:FindFirstChild("Status"),
			prompt = prompt,
			object = object,
			spawnCFrame = part.CFrame,
		}
	end
end

function WorldService.getPart(objectId)
	local entry = byId[objectId]
	return entry and entry.part or nil
end

function WorldService.getEntry(objectId)
	return byId[objectId]
end

function WorldService.setStatus(objectId, text, color)
	local entry = byId[objectId]
	if not entry or not entry.status then
		return
	end
	entry.status.Text = text
	entry.status.TextColor3 = color or Color3.fromRGB(235, 240, 255)
end

-- pop: eltűnik és RespawnTime múlva visszajön (visszaszámlálással)
function WorldService.popObject(objectId)
	local entry = byId[objectId]
	if not entry then
		return
	end

	entry.part:SetAttribute("Active", false)
	entry.prompt.Enabled = false
	entry.part.Transparency = 1
	entry.part.CanQuery = false
	entry.part.CanTouch = false

	task.spawn(function()
		local remaining = GameConfig.RespawnTime
		while remaining > 0 do
			local minutes = math.floor(remaining / 60)
			local seconds = remaining % 60
			WorldService.setStatus(objectId,
				string.format("Refresh In %d:%02d", minutes, seconds),
				Color3.fromRGB(255, 212, 71))
			task.wait(1)
			remaining -= 1
		end

		entry.part.Transparency = 0
		entry.part.CanQuery = false
		entry.part.CanTouch = false
		entry.part:SetAttribute("Active", true)
		entry.prompt.Enabled = true
		WorldService.setStatus(objectId, "")
	end)
end

function WorldService.teleportPlayer(player, objectId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local object = Objects.byId[objectId]
	if not object then
		return false
	end

	if not PlayerData.isTeleportUnlocked(player, objectId) then
		local notifyRemote = Net.get("Notify")
		if notifyRemote then
			local cost = Objects.getUnlockCost(object)
			notifyRemote:FireClient(
				player,
				string.format("Need %s Power to unlock %s!", Format.number(cost), object.name),
				Color3.fromRGB(255, 100, 100)
			)
		end
		return false
	end

	local baseX = 30 + (object.index - 1) * GameConfig.ObjectSpacing
	local standDistance = object.size * 0.5 + 3.2
	local standPos = Vector3.new(baseX, 3.5, standDistance)
	local lookTarget = Vector3.new(baseX, 3.5, 0)

	root.CFrame = CFrame.lookAt(standPos, lookTarget)

	local notifyRemote = Net.get("Notify")
	if notifyRemote then
		notifyRemote:FireClient(
			player,
			string.format("Teleported to %s (%s)!", object.name, Format.weight(object.weight)),
			Color3.fromRGB(80, 240, 255)
		)
	end
	return true
end

-- Remote események figyelése a teleportáláshoz és feloldáshoz
task.spawn(function()
	local tpRemote = Net.get("TeleportToObject")
	if tpRemote then
		tpRemote.OnServerEvent:Connect(function(player, objectId)
			WorldService.teleportPlayer(player, objectId)
		end)
	end

	local unlockRemote = Net.get("UnlockTeleport")
	if unlockRemote then
		unlockRemote.OnServerEvent:Connect(function(player, objectId)
			local success, costOrErr, object = PlayerData.unlockTeleport(player, objectId)
			local notifyRemote = Net.get("Notify")
			if success and notifyRemote and object then
				notifyRemote:FireClient(
					player,
					string.format("Unlocked %s for %s Power!", object.name, Format.number(costOrErr)),
					Color3.fromRGB(80, 255, 120)
				)
			elseif not success and notifyRemote then
				notifyRemote:FireClient(
					player,
					tostring(costOrErr),
					Color3.fromRGB(255, 100, 100)
				)
			end
		end)
	end
end)

return WorldService
