-- Chefek (GDD 3.6, 12.2): a szerver csak időalapon szimulálja a körutat, a kliens rajzolja ki őket.
-- Körút: collector → (felvesz max Stack sütést) → leadó asztal → (lead) → vissza a collectorhoz.
-- Stamina: ha elfogy, a chef ott helyben elalszik; SleepTime után magától felkel, vagy a tulajdonos
-- felébreszti (Anti-Sleep boost: gyorsabb egy ideig).
-- Replikáció: plot.Chefs/Chef{i} (Configuration) attribútumai, csak fázisváltáskor frissülnek:
--   Phase, From, To (telek-lokális Vector3), Start (szerveridő), Duration, Carrying (sütés), BoostUntil.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local PlotService = require(script.Parent.PlotService)
local SellService = require(script.Parent.SellService)

local Settings = Config.Chefs
local Palette = Config.Palette
local Pads = Config.Plot.Pads

local TICK = 0.1

-- stat neve (Config) → mentett mező
local STAT_FIELDS = {
	Stack = "stack",
	Speed = "speed",
	Stamina = "stamina",
	AntiSleep = "antiSleep",
}

type Phase = "toCollector" | "atCollector" | "toTable" | "atTable" | "sleep"

type Chef = {
	index: number,
	instance: Configuration,
	phase: Phase,
	from: Vector3,
	to: Vector3,
	start: number,
	duration: number,
	stamina: number,
	boostUntil: number,
	carrying: { count: number, units: number, value: number }?,
	resume: { phase: Phase, to: Vector3 }?,
}

local ChefService = {}

local function point(v: Vector2, lane: number): Vector3
	return Vector3.new(v.X + lane, 0, v.Y)
end

local function laneOffset(index: number, count: number): number
	return (index - (count + 1) / 2) * Settings.LaneSpacing
end

local function statLevel(raw: any, stat: string): number
	return raw.chefs[STAT_FIELDS[stat]]
end

local function speedOf(chef: Chef, raw: any, now: number): number
	local speed = Settings.BaseSpeed
		* (1 + Formulas.chefStat("Speed", statLevel(raw, "Speed")))
		* (1 + Formulas.boosts(raw).ChefSpeed) -- GDD 3.9–3.10: pet + aura "Chef seb." bónusz
	if now < chef.boostUntil then
		speed *= Settings.BoostSpeedMultiplier
	end
	-- GDD 3.12 Áramszünet: a chefek háromszor gyorsabbak
	local event = EventState.config()
	if event and event.ChefSpeedMultiplier then
		speed *= event.ChefSpeedMultiplier
	end
	return speed
end

local function currentPosition(chef: Chef, now: number): Vector3
	if chef.duration <= 0 then
		return chef.to
	end
	local alpha = math.clamp((now - chef.start) / chef.duration, 0, 1)
	return chef.from:Lerp(chef.to, alpha)
end

local function replicate(chef: Chef)
	local instance = chef.instance
	instance:SetAttribute("Phase", chef.phase)
	instance:SetAttribute("From", chef.from)
	instance:SetAttribute("To", chef.to)
	instance:SetAttribute("Start", chef.start)
	instance:SetAttribute("Duration", chef.duration)
	instance:SetAttribute("Carrying", if chef.carrying then chef.carrying.count else 0)
	instance:SetAttribute("BoostUntil", chef.boostUntil)
end

local function setPhase(chef: Chef, phase: Phase, from: Vector3, to: Vector3, now: number, duration: number)
	chef.phase = phase
	chef.from = from
	chef.to = to
	chef.start = now
	chef.duration = duration
	replicate(chef)
end

local function walk(chef: Chef, raw: any, phase: Phase, from: Vector3, to: Vector3, now: number)
	local duration = (to - from).Magnitude / speedOf(chef, raw, now)
	setPhase(chef, phase, from, to, now, duration)
end

local function targets(chef: Chef, count: number): (Vector3, Vector3)
	local lane = laneOffset(chef.index, count)
	return point(Settings.CollectorPoint, lane), point(Settings.TablePoint, lane)
end

local function fallAsleep(chef: Chef, now: number)
	local position = currentPosition(chef, now)
	chef.resume = { phase = chef.phase, to = chef.to }
	setPhase(chef, "sleep", position, position, now, Settings.SleepTime)
end

local function wake(chef: Chef, raw: any, now: number, byPlayer: boolean)
	if chef.phase ~= "sleep" then
		return
	end
	chef.stamina = Formulas.chefStat("Stamina", statLevel(raw, "Stamina"))
	if byPlayer then
		chef.boostUntil = now + Formulas.chefStat("AntiSleep", statLevel(raw, "AntiSleep"))
	end

	local position = chef.from
	local resume = chef.resume or { phase = "toCollector" :: Phase, to = position }
	chef.resume = nil
	if resume.phase == "toCollector" or resume.phase == "toTable" then
		walk(chef, raw, resume.phase, position, resume.to, now)
	else
		setPhase(chef, resume.phase, position, position, now, Settings.PickupTime)
	end
end

local function tickChef(state: PlotService.PlotState, chef: Chef, raw: any, now: number, count: number)
	if chef.phase ~= "sleep" then
		chef.stamina -= TICK
		if chef.stamina <= 0 then
			fallAsleep(chef, now)
			return
		end
	end

	if now < chef.start + chef.duration then
		return
	end

	local collector, tableSpot = targets(chef, count)
	if chef.phase == "toCollector" then
		setPhase(chef, "atCollector", chef.to, chef.to, now, Settings.PickupTime)
	elseif chef.phase == "atCollector" then
		local stack = Formulas.chefStat("Stack", statLevel(raw, "Stack"))
		local taken, units, value = SellService.takeFromTray(state, stack)
		if taken > 0 then
			chef.carrying = { count = taken, units = units, value = value }
			walk(chef, raw, "toTable", chef.to, tableSpot, now)
		else
			-- üres a collector: vár, és 1 mp múlva újra próbálja
			setPhase(chef, "atCollector", chef.to, chef.to, now, 1)
		end
	elseif chef.phase == "toTable" then
		setPhase(chef, "atTable", chef.to, chef.to, now, Settings.PickupTime)
	elseif chef.phase == "atTable" then
		local carrying = chef.carrying
		chef.carrying = nil
		if carrying then
			SellService.depositFromChef(state, carrying.units, carrying.value)
		end
		walk(chef, raw, "toCollector", chef.to, collector, now)
	elseif chef.phase == "sleep" then
		wake(chef, raw, now, false)
	end
end

local function spawnChef(state: PlotService.PlotState, raw: any, index: number, now: number): Chef
	local instance = Instance.new("Configuration")
	instance.Name = `Chef{index}`
	instance:SetAttribute("Index", index)
	instance.Parent = state.plot.chefs

	local rest = Config.Plot.ChefRest.Position
	local chef: Chef = {
		index = index,
		instance = instance,
		phase = "toCollector",
		from = Vector3.zero,
		to = Vector3.zero,
		start = now,
		duration = 0,
		stamina = Formulas.chefStat("Stamina", statLevel(raw, "Stamina")),
		boostUntil = 0,
	}
	local collector = targets(chef, raw.chefs.count)
	walk(chef, raw, "toCollector", Vector3.new(rest.X + laneOffset(index, raw.chefs.count), 0, rest.Y), collector, now)
	return chef
end

local function tick()
	local now = workspace:GetServerTimeNow()
	for _, state in PlotService.all() do
		local raw = state.data()
		local chefs = state.chefList or {}
		state.chefList = chefs

		local count = raw.chefs.count
		while #chefs < count do
			table.insert(chefs, spawnChef(state, raw, #chefs + 1, now))
		end
		for _, chef in chefs do
			tickChef(state, chef, raw, now, count)
		end
	end
end

-- Minden chef eltűnik (rebirth). A mentett chef adatokat a hívó nullázza.
function ChefService.reset(state: PlotService.PlotState)
	for _, chef in state.chefList or {} do
		chef.instance:Destroy()
	end
	state.chefList = {}
end

-- +1 Chef vásárlás
function ChefService.hire(state: PlotService.PlotState): boolean
	local data = state.data
	local raw = data()
	local count = raw.chefs.count
	if count >= Formulas.maxChefs(raw.rebirths) then
		return false
	end
	local price = Formulas.chefHirePrice(count)
	if raw.money < price then
		return false
	end
	data.money(raw.money - price)
	data.chefs.count(count + 1)
	return true
end

-- Chef stat fejlesztés (globális, minden chefre hat)
function ChefService.upgrade(state: PlotService.PlotState, stat: string): boolean
	local data = state.data
	local raw = data()
	local field = STAT_FIELDS[stat]
	local level = raw.chefs[field]
	if Formulas.chefStatMaxed(stat, level) then
		return false
	end
	local price = Formulas.chefStatPrice(stat, level)
	if raw.money < price then
		return false
	end
	data.money(raw.money - price)
	data.chefs[field](level + 1)
	return true
end

-- Rövid érték-formátum a feliratokhoz (a mértékegység a gomb nevéből / a "→" utáni értékből kiderül).
local function formatStat(stat: string, value: number): string
	if stat == "Speed" then
		return `+{math.floor(value * 100 + 0.5)}%`
	elseif stat == "Stack" then
		return tostring(value)
	end
	return `{value}s`
end

local function render(state: PlotService.PlotState, raw: any)
	local labels = state.plot.labels

	local count = raw.chefs.count
	local hire = labels.ChefHire
	if count >= Formulas.maxChefs(raw.rebirths) then
		hire.Title.Text = `Chefek: {count}/{Formulas.maxChefs(raw.rebirths)}`
		hire.Info.Text = "MAX"
		hire.Info.TextColor3 = Palette.Lemon
	else
		local price = Formulas.chefHirePrice(count)
		hire.Title.Text = `+1 Chef ({count}/{Formulas.maxChefs(raw.rebirths)})`
		hire.Info.Text = NumberFormat.money(price)
		hire.Info.TextColor3 = if raw.money >= price then Palette.Money else Palette.Danger
	end

	for key, pad in Pads do
		local stat = pad.ChefStat
		if not stat then
			continue
		end
		-- két rövid sor, mint a vásárló gomboknál: "Stack 3→4" / "$600"
		local label = labels[key]
		local level = statLevel(raw, stat)
		local current = Formulas.chefStat(stat, level)
		if Formulas.chefStatMaxed(stat, level) then
			label.Title.Text = `{pad.Title} {formatStat(stat, current)}`
			label.Info.Text = "MAX"
			label.Info.TextColor3 = Palette.Lemon
		else
			local price = Formulas.chefStatPrice(stat, level)
			label.Title.Text =
				`{pad.Title} {formatStat(stat, current)}→{formatStat(stat, Formulas.chefStat(stat, level + 1))}`
			label.Info.Text = NumberFormat.money(price)
			label.Info.TextColor3 = if raw.money >= price then Palette.Money else Palette.Danger
		end
	end
end

local function onWake(player: Player, chefIndex: unknown)
	if type(chefIndex) ~= "number" then
		return
	end
	local state = PlotService.get(player)
	local chef = state and state.chefList and state.chefList[chefIndex]
	if not state or not chef or chef.phase ~= "sleep" then
		return
	end

	-- távolság-ellenőrzés (GDD 12.2 anti-exploit)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local chefWorld = (state.plot.origin * CFrame.new(chef.from)).Position
	local flat = Vector3.new(root.Position.X - chefWorld.X, 0, root.Position.Z - chefWorld.Z)
	if flat.Magnitude > Settings.WakeDistance then
		return
	end

	wake(chef, state.data(), workspace:GetServerTimeNow(), true)
	Remotes.ChefWoke:FireAllClients(state.plot.index, chef.index)
end

function ChefService.init()
	PlotService.registerPad("ChefHire", {
		enter = function(_player, state)
			ChefService.hire(state)
		end,
	})
	for key, pad in Pads do
		local stat = pad.ChefStat
		if stat then
			PlotService.registerPad(key, {
				enter = function(_player, state)
					ChefService.upgrade(state, stat)
				end,
			})
		end
	end
	PlotService.addRenderer(render)
end

function ChefService.start()
	Remotes.WakeChef.OnServerEvent:Connect(onWake)
	Players.PlayerRemoving:Connect(function(player)
		local state = PlotService.get(player)
		if state then
			state.chefList = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return ChefService
