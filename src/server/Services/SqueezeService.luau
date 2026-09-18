-- Szorítás: gate ellenőrzés, klikk-minigame, POP + jutalom.
-- Minden a szerveren dől el (távolság, gate, kattintás-ütem, progress).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Objects = require(Shared.Config.Objects)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local WorldService = require(script.Parent.WorldService)

local SqueezeService = {}

local sessions = {} -- [Player] = { objectId, progress, needed, lastTick }

local function endSession(player, objectId)
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
	local gate = object.weight * object.gateRatio
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
	}

	-- a prompt ne lógjon bele a cinematic jelenetbe
	local entry = WorldService.getEntry(objectId)
	if entry and entry.prompt then
		entry.prompt.Enabled = false
	end

	WorldService.setStatus(objectId, "SQUEEZING...", Color3.fromRGB(116, 210, 250))

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

	if session.progress < session.needed then
		return
	end

	-- POP
	local handsMulti = PlayerData.getHands(player).multiplier
	local reward = math.floor(object.weight * GameConfig.CashPerWeight * handsMulti)

	PlayerData.addCash(player, reward)
	PlayerData.registerPop(player, object.weight)
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
					sessions[player] = nil
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
					-- már elkezdte: fogy a progress, 0-nál megszakad
					session.progress -= GameConfig.FailDecay
					if session.progress <= 0 then
						endSession(player, session.objectId)
						Net.get("SqueezeState"):FireClient(player, { state = "fail" })
						WorldService.setStatus(session.objectId, "")
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
