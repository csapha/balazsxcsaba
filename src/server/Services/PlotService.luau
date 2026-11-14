-- Telek kiosztás + rálépős padek kezelése (GDD 3.1, 12.1 PlotService).
-- A szerver nézi, hol áll a játékos (GDD 12.2: szerver az igazság, távolság-ellenőrzés).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotBuilder = require(script.Parent.Parent.Lib.PlotBuilder)
local DataService = require(script.Parent.DataService)

type PlotRefs = PlotBuilder.PlotRefs

export type PlotState = {
	player: Player,
	plot: PlotRefs,
	data: any, -- DataServiceTyped Value
	dirty: boolean,
	inside: { [string]: boolean },
	[string]: any, -- a többi szolgáltatás saját mezői
}

type PadHandlers = {
	enter: ((player: Player, state: PlotState) -> ())?,
	stay: ((player: Player, state: PlotState) -> ())?,
}

local POLL_INTERVAL = 0.1

local PlotService = {}

local plotsFolder: Folder
local plots: { [number]: PlotRefs } = {}
local owners: { [number]: Player } = {}
local states: { [Player]: PlotState } = {}
local padHandlers: { [string]: PadHandlers } = {}
local renderers: { (state: PlotState, raw: any) -> () } = {}
local assignedHandlers: { (state: PlotState) -> () } = {}
local cleanups: { [Player]: { () -> () } } = {}

local function safeCall(fn: (...any) -> (), ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(`[PlotService] {err}`)
	end
end

-- Rálépős pad regisztrálása. enter: belépéskor egyszer, stay: amíg rajta áll (~10×/mp).
function PlotService.registerPad(key: string, handlers: PadHandlers)
	assert(Config.Plot.Pads[key], `Unknown pad: {key}`)
	padHandlers[key] = handlers
end

-- Megjelenítő: akkor fut, ha a játékos adata változott (feliratok, sütő modellek).
function PlotService.addRenderer(fn: (state: PlotState, raw: any) -> ())
	table.insert(renderers, fn)
end

-- Akkor fut (külön szálon), amikor egy játékos megkapta a telkét.
function PlotService.onAssigned(fn: (state: PlotState) -> ())
	table.insert(assignedHandlers, fn)
end

-- Igaz, amíg a state még az aktuális (a játékos nem lépett ki).
function PlotService.isActive(state: PlotState): boolean
	return states[state.player] == state
end

function PlotService.get(player: Player): PlotState?
	return states[player]
end

function PlotService.all(): { [Player]: PlotState }
	return states
end

-- A játékos (HumanoidRootPart) a pad területén van-e. A Config.Plot.Pads alapján, telek-lokálisan:
-- a pad mérete + Reach (asztalnál nem kell ráállni), és a padló / pad teteje feletti magasság.
local function isOnPad(origin: CFrame, key: string, position: Vector3): boolean
	local pad = Config.Plot.Pads[key]
	local relative = origin:PointToObjectSpace(position)
	local reach = pad.Reach or 0
	local top = Config.Plot.FloorTop + (pad.Height or 0.3)
	return math.abs(relative.X - pad.Position.X) <= pad.Size.X / 2 + reach
		and math.abs(relative.Z - pad.Position.Y) <= pad.Size.Y / 2 + reach
		and relative.Y > Config.Plot.FloorTop - 1
		and relative.Y < top + 7
end

local function teleportToPlot(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or states[player] ~= state then
		return
	end
	local layout = Config.Plot
	local position = layout.Spawn + Vector3.new(0, layout.FloorTop + 3, 0)
	local lookAt = layout.SpawnLookAt + Vector3.new(0, layout.FloorTop + 3, 0)
	task.defer(function()
		character:PivotTo(state.plot.origin * CFrame.lookAt(position, lookAt))
	end)
end

-- A játékos visszakerül a telke spawn pontjára (pl. rebirth után).
function PlotService.teleportHome(player: Player)
	if player.Character then
		teleportToPlot(player, player.Character)
	end
end

local function assignPlot(player: Player)
	local data = DataService.wait(player)
	if not data or not player:IsDescendantOf(Players) or states[player] then
		return
	end

	local index
	for i = 1, #plots do
		if not owners[i] then
			index = i
			break
		end
	end
	if not index then
		warn(`[PlotService] No free plot: {player.Name}`)
		return
	end

	local plot = plots[index]
	owners[index] = player
	plot.model:SetAttribute("OwnerId", player.UserId)
	plot.sign.Text = `{player.DisplayName}'s Shop`
	player:SetAttribute("PlotIndex", index)

	local state: PlotState = {
		player = player,
		plot = plot,
		data = data,
		dirty = true,
		inside = {},
	}
	states[player] = state

	local list = {}
	table.insert(
		list,
		data.Changed(function()
			state.dirty = true
		end)
	)
	local connection = player.CharacterAdded:Connect(function(character)
		teleportToPlot(player, character)
	end)
	table.insert(list, function()
		connection:Disconnect()
	end)
	cleanups[player] = list

	if player.Character then
		teleportToPlot(player, player.Character)
	end

	for _, handler in assignedHandlers do
		task.spawn(safeCall, handler, state)
	end
end

local function releasePlot(player: Player)
	local state = states[player]
	states[player] = nil
	for _, cleanup in cleanups[player] or {} do
		cleanup()
	end
	cleanups[player] = nil
	if not state then
		return
	end

	-- A telek újraépül tisztán, a következő játékosnak.
	local index = state.plot.index
	owners[index] = nil
	state.plot.model:Destroy()
	plots[index] = PlotBuilder.build(index, plotsFolder)
end

local function poll()
	for player, state in states do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0

		for key in state.plot.pads do
			local inside = alive and isOnPad(state.plot.origin, key, (root :: BasePart).Position)
			local handlers = padHandlers[key]
			if handlers and inside then
				if not state.inside[key] and handlers.enter then
					safeCall(handlers.enter, player, state)
				end
				if handlers.stay then
					safeCall(handlers.stay, player, state)
				end
			end
			state.inside[key] = inside
		end

		if state.dirty and states[player] == state then
			state.dirty = false
			local raw = state.data()
			for _, render in renderers do
				safeCall(render, state, raw)
			end
		end
	end
end

function PlotService.init()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	PlotBuilder.buildWorld(world)

	for index = 1, Config.Game.MaxPlayers do
		plots[index] = PlotBuilder.build(index, plotsFolder)
	end
end

function PlotService.start()
	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(assignPlot, player)
	end

	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			poll()
		end
	end)
end

return PlotService
