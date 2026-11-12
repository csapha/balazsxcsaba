-- Random eventek (GDD 3.12): 5–7 percenként (Studióban 60–90 mp) egy szerver-szintű esemény.
-- Az állapot a ReplicatedStorage.EventState attribútumaiban van (Shared.EventState), ebből olvas
-- minden szolgáltatás és a kliens is:
--   Ebédcsúcs → SellService (eladás x2), CustomerService (több vendég)
--   Arany Olaj → OvenService (arany esély x5)
--   Nagyi Látogatás → OvenService (+1 sütő szint)
--   Áramszünet → OvenService (nem süt), ChefService (chef x3), kliens (sötétebb, áll a szalag)
--   Panírvihar → itt: schnitzelek hullanak az utcára, aki elsőként felkapja, pénzt kap
--   Ételkritikus → CustomerService: VIP vendég minden telken
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EventState = require(ReplicatedStorage.Shared.EventState)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local CustomerService = require(script.Parent.CustomerService)

local Events = Config.Events
local Palette = Config.Palette

local STREET_HALF_WIDTH = 150 -- X irányban ennyin belül hullanak (az utca közepétől)
local STREET_HALF_DEPTH = 14 -- Z irányban (az utca két széle között)
local DROP_HEIGHT = 60
local DROP_LIFETIME = 20

local EventService = {}

local rng = Random.new()
local isStudio = RunService:IsStudio()
local stormFolder: Folder

local function interval(): number
	if isStudio then
		return rng:NextNumber(Events.StudioIntervalMin, Events.StudioIntervalMax)
	end
	return rng:NextNumber(Events.IntervalMin, Events.IntervalMax)
end

local function pickEvent(): string
	local total = 0
	for _, event in Events.List do
		total += event.Weight
	end
	local roll = rng:NextNumber() * total
	for id, event in Events.List do
		roll -= event.Weight
		if roll < 0 then
			return id
		end
	end
	return "LunchRush"
end

-- Panírvihar: egy hulló schnitzel az utcán; aki elsőként megérinti, a bevételéhez skálázott pénzt kap.
local function dropSchnitzel(config: any)
	local part = Instance.new("Part")
	part.Name = "StormSchnitzel"
	part.Size = Vector3.new(1.8, 0.4, 1.4)
	part.Color = Palette.Schnitzel
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(
		rng:NextNumber(-STREET_HALF_WIDTH, STREET_HALF_WIDTH),
		DROP_HEIGHT,
		rng:NextNumber(-STREET_HALF_DEPTH, STREET_HALF_DEPTH)
	) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Palette.Gold
	sparkles.Parent = part

	local taken = false
	part.Touched:Connect(function(hit)
		if taken then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local data = player and DataService.get(player)
		if not player or not data then
			return
		end
		taken = true
		local raw = data()
		local value = math.max(config.DropMinValue, math.floor(Formulas.incomePerSecond(raw) * config.DropIncomeSeconds))
		data.money(raw.money + value)
		Remotes.EventReward:FireClient(player, `+{NumberFormat.money(value)}`, Palette.Money)
		part:Destroy()
	end)

	part.Parent = stormFolder
	task.delay(DROP_LIFETIME, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local function runStorm(config: any)
	local gap = config.Duration / config.DropCount
	for _ = 1, config.DropCount do
		if not EventState.is("PanirStorm") then
			return
		end
		dropSchnitzel(config)
		task.wait(gap)
	end
end

local function startEvent(id: string, now: number)
	local config = Events.List[id]
	EventState.instance:SetAttribute("Active", id)
	EventState.instance:SetAttribute("EndsAt", now + config.Duration)

	if id == "PanirStorm" then
		task.spawn(runStorm, config)
	elseif id == "Critic" then
		CustomerService.startCritic(config)
	end
end

local function endEvent(id: string)
	EventState.instance:SetAttribute("Active", "")
	if id == "PanirStorm" then
		-- a földön maradt darabok még pár mp-ig felkaphatók (DROP_LIFETIME), utána eltűnnek
	elseif id == "Critic" then
		CustomerService.endCritic()
	end
end

function EventService.init()
	stormFolder = Instance.new("Folder")
	stormFolder.Name = "PanirStorm"
	stormFolder.Parent = workspace
end

function EventService.start()
	task.spawn(function()
		local first = if isStudio then Events.StudioFirstEventDelay else Events.FirstEventDelay
		EventState.instance:SetAttribute("NextAt", workspace:GetServerTimeNow() + first)

		while true do
			-- várakozás a következő eventig
			while workspace:GetServerTimeNow() < EventState.nextAt() do
				task.wait(0.5)
			end

			local id = pickEvent()
			local now = workspace:GetServerTimeNow()
			startEvent(id, now)
			task.wait(Events.List[id].Duration)
			endEvent(id)

			EventState.instance:SetAttribute("NextAt", workspace:GetServerTimeNow() + interval())
		end
	end)
end

return EventService
