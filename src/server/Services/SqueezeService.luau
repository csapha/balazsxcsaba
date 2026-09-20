-- Szorítás: gate ellenőrzés, klikk-minigame, POP + jutalom.
-- Minden a szerveren dől el (távolság, gate, kattintás-ütem, progress).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local WorldService = require(script.Parent.WorldService)

local SqueezeService = {}

local sessions = {} -- [Player] = { objectId, progress, needed, lastTick }

-- A tárgy vizuális modelljének "összenyomása": a Visual modell partjait
-- a két kéz irányában keskenyítjük, a többi irányban kidudorítjuk.
local function captureVisual(root)
	local visual = root:FindFirstChild("Visual")
	if not visual then
		return nil
	end

	local pivot = visual:GetPivot()
	local parts = {}
	for _, p in ipairs(visual:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, {
				part = p,
				size = p.Size,
				offset = pivot:ToObjectSpace(p.CFrame),
			})
		end
	end
	return { pivot = pivot, parts = parts, tweens = {} }
end

local function scaledPartSize(entry, scale)
	-- The squash scale uses the visual pivot's axes. Detail parts may be
	-- rotated, so calculate which local Size component points into each axis.
	local rotation = entry.offset.Rotation
	local function axisScale(axis)
		return (axis * scale).Magnitude
	end
	return entry.size * Vector3.new(
		axisScale(rotation.RightVector),
		axisScale(rotation.UpVector),
		axisScale(rotation.LookVector)
	)
end

local function applySquash(visualData, scale, duration)
	for _, tween in ipairs(visualData.tweens) do
		tween:Cancel()
	end
	table.clear(visualData.tweens)

	for _, entry in ipairs(visualData.parts) do
		local p = entry.part
		if p.Parent then
			local goal = {
				Size = scaledPartSize(entry, scale),
				CFrame = visualData.pivot
					* CFrame.new(entry.offset.Position * scale)
					* entry.offset.Rotation,
			}
			if duration and duration > 0 then
				local tween = TweenService:Create(
					p,
					TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					goal
				)
				table.insert(visualData.tweens, tween)
				tween:Play()
			else
				p.Size = goal.Size
				p.CFrame = goal.CFrame
			end
		end
	end
end

local function endSession(player, objectId)
	local session = sessions[player]
	if session and session.visual then
		applySquash(session.visual, Vector3.one, 0.12)
	end

	sessions[player] = nil
	local entry = WorldService.getEntry(objectId)
	if entry and entry.prompt and entry.part and entry.part:GetAttribute("Active") ~= false then
		entry.prompt.Enabled = true
	end
end

local function notify(player, text, color)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, text, color)
	end
end

local function distanceTo(player, part)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

local function startSqueeze(player, part)
	if not PlayerData.isLoaded(player) then
		return
	end
	if sessions[player] then
		return
	end

	local objectId = part:GetAttribute("ObjectId")
	local object = Objects.byId[objectId]
	if not object or part:GetAttribute("Active") == false then
		return
	end

	if distanceTo(player, part) > GameConfig.SqueezeRange then
		return
	end

	local data = PlayerData.get(player)
	local gate = Objects.getRequiredPower(object)
	if data.power < gate then
		notify(player, ("Need %s Power to squeeze %s"):format(Format.number(gate), object.name),
			Color3.fromRGB(255, 212, 71))
		return
	end

	local needed = Objects.clicksNeeded(object, data.power, GameConfig)
	sessions[player] = {
		objectId = objectId,
		progress = 0,
		needed = needed,
		lastTick = os.clock(),
		started = false,
		visual = captureVisual(part),
	}

	-- a prompt ne lógjon bele a cinematic jelenetbe
	local entry = WorldService.getEntry(objectId)
	if entry and entry.prompt then
		entry.prompt.Enabled = false
	end

	local remote = Net.get("SqueezeState")
	if remote then
		remote:FireClient(player, {
			state = "start",
			objectId = objectId,
			name = object.name,
			needed = needed,
			position = part.Position,
		})
	end
end

local function tick(player)
	local session = sessions[player]
	if not session then
		return
	end

	local part = WorldService.getPart(session.objectId)
	local object = Objects.byId[session.objectId]
	if not part or not object or part:GetAttribute("Active") == false then
		endSession(player, session.objectId)
		return
	end

	if distanceTo(player, part) > GameConfig.SqueezeRange then
		endSession(player, session.objectId)
		Net.get("SqueezeState"):FireClient(player, { state = "fail" })
		WorldService.setStatus(session.objectId, "")
		return
	end

	local now = os.clock()
	if now - session.lastTick < GameConfig.MinTapInterval then
		return
	end
	session.lastTick = now
	session.started = true
	session.progress += 1

	-- Látható összenyomódás: a kezek között keskenyedik és kidudorodik.
	if session.visual then
		local t = math.clamp(session.progress / session.needed, 0, 1)
		local flat = 1 - 0.42 * t
		local verticalBulge = 1 + 0.18 * t
		local depthBulge = 1 + 0.12 * t
		applySquash(session.visual, Vector3.new(flat, verticalBulge, depthBulge), 0.075)
	end

	if session.progress < session.needed then
		return
	end

	-- POP
	local hands = PlayerData.getHands(player)
	local cashMultiplier = hands.cashMultiplier or 1
	local reward = math.floor(Objects.getCashReward(object) * cashMultiplier)

	PlayerData.addCash(player, reward)
	PlayerData.registerPop(player, object.id, object.weight)
	PlayerData.sync(player)

	WorldService.popObject(session.objectId)
	endSession(player, session.objectId)
	WorldService.setStatus(session.objectId, "")

	local remote = Net.get("SqueezeState")
	if remote then
		remote:FireClient(player, {
			state = "pop",
			objectId = session.objectId,
			name = object.name,
			reward = reward,
			position = part.Position,
			color = object.color,
			weight = object.weight,
		})
	end
end

function SqueezeService.init()
	-- promptok bekötése minden tárgyra
	for _, object in ipairs(Objects.list) do
		local entry = WorldService.getEntry(object.id)
		if entry and entry.prompt then
			entry.prompt.Triggered:Connect(function(player)
				startSqueeze(player, entry.part)
			end)
		end
	end

	Net.get("SqueezeTick").OnServerEvent:Connect(tick)

	-- fail decay + eltávolodás figyelése
	task.spawn(function()
		while true do
			task.wait(1)
			for player, session in pairs(sessions) do
				if not player.Parent then
					endSession(player, session.objectId)
					WorldService.setStatus(session.objectId, "")
					continue
				end

				local part = WorldService.getPart(session.objectId)
				if not part then
					endSession(player, session.objectId)
					continue
				end

				if distanceTo(player, part) > GameConfig.SqueezeRange then
					endSession(player, session.objectId)
					Net.get("SqueezeState"):FireClient(player, { state = "fail" })
					WorldService.setStatus(session.objectId, "")
					continue
				end

				local idle = os.clock() - session.lastTick

				if session.progress > 0 then
					-- csak akkor fogy a progress, ha tényleg nem kattint
					if idle > 0.35 then
						session.progress -= GameConfig.FailDecay
						if session.progress > 0 and session.visual then
							local t = math.clamp(session.progress / session.needed, 0, 1)
							applySquash(session.visual, Vector3.new(
								1 - 0.42 * t,
								1 + 0.18 * t,
								1 + 0.12 * t
							), 0.15)
						end
						if session.progress <= 0 then
							endSession(player, session.objectId)
							Net.get("SqueezeState"):FireClient(player, { state = "fail" })
							WorldService.setStatus(session.objectId, "")
						end
					end
				elseif idle > GameConfig.StartGrace then
					-- el sem kezdte kattintani: türelmi idő után lezárjuk
					endSession(player, session.objectId)
					Net.get("SqueezeState"):FireClient(player, { state = "fail" })
					WorldService.setStatus(session.objectId, "")
				end
			end
		end
	end)
end

return SqueezeService
