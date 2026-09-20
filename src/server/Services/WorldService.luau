-- Világ: a tárgyak (dinnye, kókusz, ...) legyártása a mapon + respawn.
-- Minden procedurálisan jön létre, nem kell Studio-ban kézzel építeni.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local PlayerData = require(script.Parent.PlayerData)
local MapScenery = require(script.Parent.MapScenery)
local StationModels = require(script.Parent.StationModels)

local WorldService = {}

local mapFolder = nil
local objectFolder = nil
local tableFolder = nil
local byId = {} -- [objectId] = { part = BasePart, ... }
local gateEntries = {}
local lastGateNotify = {}

local TABLE_HEIGHT = 3.0 -- az asztallap teteje ennyi magasan van (stud)

local function makeBillboard(part, object)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	-- Scale components are world-space studs. This keeps the label in the same
	-- proportion to the object instead of making it look huge after zooming out.
	billboard.Size = UDim2.fromScale(6.2, 1.8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, object.size * 0.9 + 1.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard:SetAttribute("DisplayDistance", 55)
	billboard.Enabled = false
	billboard:SetAttribute("AnimatedObjectInfo", true)
	billboard.Parent = part

	local scaleFrame = Instance.new("CanvasGroup")
	scaleFrame.Name = "ScaleFrame"
	scaleFrame.Size = UDim2.fromScale(1, 1)
	scaleFrame.BackgroundTransparency = 1
	scaleFrame.Parent = billboard

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "PopScale"
	uiScale.Parent = scaleFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Text = object.name .. "  (" .. Format.weight(object.weight) .. ")"
	title.Parent = scaleFrame

	-- ugyanaz a fehér -> szürke gradiens, mint a többi UI szövegnél
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
	})
	titleGradient.Rotation = 90
	titleGradient.Parent = title

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(255, 212, 71)
	status.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	status.TextStrokeTransparency = 0
	status.Text = ""
	status.Parent = scaleFrame

	return billboard
end

local function makePrompt(part, object)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SqueezePrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom -- a kliens rajzolja a saját UI-t
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

local function tryUnlockZone(player, objectId)
	local success, costOrErr, object = PlayerData.unlockTeleport(player, objectId)
	local notifyRemote = Net.get("Notify")
	if success and notifyRemote and object then
		notifyRemote:FireClient(
			player,
			string.format("Unlocked %s for %s Power!", object.name, Format.number(costOrErr)),
			Color3.fromRGB(80, 255, 120)
		)
	elseif not success and notifyRemote then
		notifyRemote:FireClient(player, tostring(costOrErr), Color3.fromRGB(255, 100, 100))
	end
	return success
end

function WorldService.build()
	mapFolder = Workspace:FindFirstChild(GameConfig.MapName)
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = GameConfig.MapName
		mapFolder.Parent = Workspace
	end
	local scenery = MapScenery.build(mapFolder, Objects.list, GameConfig.ObjectSpacing)

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

	-- Replace edit-mode station previews when the server starts.
	objectFolder:ClearAllChildren()
	tableFolder:ClearAllChildren()
	byId = {}

	for _, object in ipairs(Objects.list) do
		local baseX = 30 + (object.index - 1) * GameConfig.ObjectSpacing
		local baseZ = 0

		-- asztal az objektum alá
		local stationTable = StationModels.createTable(object, Vector3.new(baseX, 0, baseZ), TABLE_HEIGHT)
		stationTable.Parent = tableFolder
		local part = StationModels.createObject(object, Vector3.new(baseX, TABLE_HEIGHT + object.size * 0.5, baseZ))

		local billboard = makeBillboard(part, object)
		local prompt = makePrompt(part, object)
		part.Parent = objectFolder

		byId[object.id] = {
			part = part,
			billboard = billboard,
			status = billboard:FindFirstChild("Status", true),
			prompt = prompt,
			object = object,
			spawnCFrame = part.CFrame,
		}
	end

	gateEntries = {}
	local gates = scenery:FindFirstChild("ZoneGates")
	if gates then
		for _, gate in ipairs(gates:GetChildren()) do
			local prompt = gate:FindFirstChild("ZoneUnlockPrompt", true)
			local blocker = gate:FindFirstChild("ZoneBlocker")
			local targetObjectId = gate:GetAttribute("TargetObjectId")
			local boundaryX = gate:GetAttribute("BoundaryX")
			if prompt and prompt:IsA("ProximityPrompt") and blocker and targetObjectId and boundaryX then
				table.insert(gateEntries, {
					model = gate,
					blocker = blocker,
					prompt = prompt,
					targetObjectId = targetObjectId,
					boundaryX = boundaryX,
				})
				prompt.Triggered:Connect(function(player)
					tryUnlockZone(player, targetObjectId)
				end)
			end
		end
		table.sort(gateEntries, function(a, b)
			return a.boundaryX < b.boundaryX
		end)
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

-- pop: eltűnik, majd azonnal újra megjelenik (nincs visszaszámlálás).
function WorldService.popObject(objectId)
	local entry = byId[objectId]
	if not entry then
		return
	end

	entry.part:SetAttribute("Active", false)
	entry.prompt.Enabled = false
	StationModels.setVisible(entry.part, false)
	entry.part.CanQuery = false
	entry.part.CanTouch = false

	task.delay(0.25, function()
		StationModels.setVisible(entry.part, true)
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
			tryUnlockZone(player, objectId)
		end)
	end
end)

-- Server-side fallback: locked zones cannot be bypassed around the visual gate.
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not PlayerData.isLoaded(player) then
				continue
			end

			for _, gate in ipairs(gateEntries) do
				if not PlayerData.isTeleportUnlocked(player, gate.targetObjectId)
					and root.Position.X > gate.boundaryX then
					local safePosition = Vector3.new(gate.boundaryX - 4, root.Position.Y, root.Position.Z)
					root.CFrame = CFrame.lookAt(
						safePosition,
						Vector3.new(gate.boundaryX, root.Position.Y, root.Position.Z)
					)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero

					local now = os.clock()
					if now - (lastGateNotify[player] or 0) > 2 then
						lastGateNotify[player] = now
						local target = Objects.byId[gate.targetObjectId]
						local notifyRemote = Net.get("Notify")
						if target and notifyRemote then
							notifyRemote:FireClient(
								player,
								"Unlock " .. target.name .. " Zone first!",
								Color3.fromRGB(255, 100, 100)
							)
						end
					end
					break
				end
			end
		end
	end
end)

return WorldService
