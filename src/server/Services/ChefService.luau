-- Chefek (GDD 3.6, 12.2): a szerver csak időalapon szimulálja a körutat, a kliens rajzolja ki őket.
-- Körút: collector → (felvesz max Stack sütést) → leadó asztal → (lead) → vissza a collectorhoz.
-- Stamina: ha elfogy, a chef átsétál a Chef Rest négyzetre (döntés 2026-11-16: ne a padokon / gombokon aludjon), és
-- ott alszik el; SleepTime után magától felkel, vagy a tulajdonos felébreszti (Anti-Sleep boost: gyorsabb egy ideig),
-- és onnan folytatja (ha visz sütést, a leadó asztalhoz megy, különben a collectorhoz).
-- Replikáció: plot.Chefs/Chef{i} (Configuration) attribútumai, csak fázisváltáskor frissülnek:
--   Phase, From, To (telek-lokális Vector3), Start (szerveridő), Duration, Carrying (sütés), BoostUntil.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EventState = require(ReplicatedStorage.Shared.EventState)
local PlotService = require(script.Parent.PlotService)
local SellService = require(script.Parent.SellService)
local TutorialService = require(script.Parent.TutorialService)

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

type Phase = "toCollector" | "atCollector" | "toTable" | "atTable" | "toRest" | "sleep"

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

-- The chef's bed on the Chef Rest square (12 × 12 studs): the first one in the middle, the others around it.
local REST_SPACING = 2.6
local REST_SPOTS = {
	Vector2.new(0, 0), Vector2.new(-1, 0), Vector2.new(1, 0), Vector2.new(0, -1), Vector2.new(0, 1),
	Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1),
	Vector2.new(-2, 0), Vector2.new(2, 0), Vector2.new(0, -2), Vector2.new(0, 2),
	Vector2.new(-2, -2), Vector2.new(2, -2), Vector2.new(-2, 2), Vector2.new(2, 2), -- up to 17 chefs (15 + the pass)
}
local function restSpot(chef: Chef): Vector3
	local spot = REST_SPOTS[(chef.index - 1) % #REST_SPOTS + 1] * REST_SPACING
	local center = Settings.RestPoint
	return Vector3.new(center.X + spot.X, 0, center.Y + spot.Y)
end

-- Out of stamina: walk to the Chef Rest square first (not asleep on the collector / table pads).
local function goToRest(chef: Chef, raw: any, now: number)
	walk(chef, raw, "toRest", currentPosition(chef, now), restSpot(chef), now)
end

local function wake(chef: Chef, raw: any, now: number, byPlayer: boolean)
	if chef.phase ~= "sleep" and chef.phase ~= "toRest" then
		return
	end
	chef.stamina = Formulas.chefStat("Stamina", statLevel(raw, "Stamina"))
	if byPlayer then
		chef.boostUntil = now + Formulas.chefStat("AntiSleep", statLevel(raw, "AntiSleep"))
	end

	-- back to work from where it is: with schnitzels to the table, otherwise to the collector
	local collector, tableSpot = targets(chef, raw.chefs.count)
	local position = currentPosition(chef, now)
	if chef.carrying then
		walk(chef, raw, "toTable", position, tableSpot, now)
	else
		walk(chef, raw, "toCollector", position, collector, now)
	end
end

local function tickChef(state: PlotService.PlotState, chef: Chef, raw: any, now: number, count: number)
	-- GDD 6.2–6.3: Tireless Chefs gamepass / Chef Energy Drink → nem alszanak el (az alvót rögtön felkeltjük)
	if Formulas.chefsTireless(raw) then
		if chef.phase == "sleep" or chef.phase == "toRest" then
			wake(chef, raw, now, false)
		end
		chef.stamina = math.max(chef.stamina, TICK)
	elseif chef.phase ~= "sleep" and chef.phase ~= "toRest" then
		chef.stamina -= TICK
		if chef.stamina <= 0 then
			goToRest(chef, raw, now)
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
	elseif chef.phase == "toRest" then
		setPhase(chef, "sleep", chef.to, chef.to, now, Settings.SleepTime)
		TutorialService.event(state.player, "ChefAsleep") -- GDD 7.3: "Wake him up!" (csak egyszer)
	elseif chef.phase == "sleep" then
		wake(chef, raw, now, false)
		TutorialService.event(state.player, "ChefWoken") -- magától felkelt
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
	if count >= Formulas.maxChefs(raw.rebirths, raw) then
		return false
	end
	-- GDD 7.3: az ajándék chef (a tutorial "ChefGift" lépésében) ingyen jár
	local free = TutorialService.chefFree(raw)
	local price = if free then 0 else Formulas.chefHirePrice(count)
	if raw.money < price then
		return false
	end
	data.money(raw.money - price)
	AnalyticsService.sink(state.player, price, "Shop", "ChefHire")
	AnalyticsService.step(state.player, "FirstChef")
	data.chefs.count(count + 1)
	if free then
		TutorialService.event(state.player, "ChefHired")
	end
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
	AnalyticsService.sink(state.player, price, "Shop", `Chef{stat}`)
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
	if count >= Formulas.maxChefs(raw.rebirths, raw) then
		hire.Title.Text = `Chefs: {count}/{Formulas.maxChefs(raw.rebirths, raw)}`
		hire.Info.Text = "MAX"
		hire.Info.TextColor3 = Palette.Lemon
	else
		local price = Formulas.chefHirePrice(count)
		hire.Title.Text = `+1 Chef ({count}/{Formulas.maxChefs(raw.rebirths, raw)})`
		if TutorialService.chefFree(raw) then
			hire.Info.Text = "FREE" -- GDD 7.3 ajándék chef
			hire.Info.TextColor3 = Palette.Money
		else
			hire.Info.Text = NumberFormat.money(price)
			hire.Info.TextColor3 = if raw.money >= price then Palette.Money else Palette.Danger
		end
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
	TutorialService.event(player, "ChefWoken")
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
	Guard.connect(Remotes.WakeChef, onWake)
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
