-- Vendégsor (GDD 3.5 vizuál): a telek tulajdonosának Roblox barátai a saját avatarjukkal.
--   1. az utcáról besétálnak a sor végére,
--   2. ha a pult elad, az első vendég kap egy schnitzelt, és az utca másik irányába elsétál,
--   3. a sor előrébb lép, a végére új vendég jön.
-- Ha nincs eladás (üres a pult), a vendégek a sorban várnak.
-- Tartalék: ha nincs elérhető barát, a tulajdonos saját avatarja, végső esetben egy alap avatar.
-- Csak vizuál: a pénz a SellService-ben számolódik, a vendégektől függetlenül.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local PlotService = require(script.Parent.PlotService)

local Layout = Config.Plot
local Settings = Layout.Customers
local Palette = Config.Palette

local MAX_FRIEND_PAGES = 4 -- max ~200 barát
local LOOP_INTERVAL = 0.25
local MOVE_TIMEOUT = 8
local ANIMATIONS = {
	[Enum.HumanoidRigType.R15] = { idle = "rbxassetid://507766666", walk = "rbxassetid://507777826" },
	[Enum.HumanoidRigType.R6] = { idle = "rbxassetid://180435571", walk = "rbxassetid://180426354" },
}

type Guest = { userId: number, name: string }

type Customer = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	idle: AnimationTrack?,
	walk: AnimationTrack?,
	pathId: number,
	arrivedAt: number?, -- mikor ért a sorban a helyére (nil, ha még megy)
	vip: boolean?, -- Ételkritikus (GDD 3.12)
}

local CustomerService = {}

-- Avatar sablonok gyorsítótára (userId → Model), hogy ne kelljen minden vendéghez újra letölteni.
local templateFolder: Folder
local templates: { [number]: Model } = {}

local function fetchFriends(userId: number): { Guest }
	local friends = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)
	if not ok or not pages then
		return friends
	end

	for _ = 1, MAX_FRIEND_PAGES do
		for _, friend in pages:GetCurrentPage() do
			table.insert(friends, {
				userId = friend.Id,
				name = if friend.DisplayName and friend.DisplayName ~= "" then friend.DisplayName else friend.Username,
			})
		end
		if pages.IsFinished then
			break
		end
		if not pcall(function()
			pages:AdvanceToNextPageAsync()
		end) then
			break
		end
	end
	return friends
end

local function getTemplate(guest: Guest?): Model?
	local key = if guest then guest.userId else 0
	local cached = templates[key]
	if cached then
		return cached
	end

	local ok, model = pcall(function()
		if guest and guest.userId > 0 then
			return Players:CreateHumanoidModelFromUserId(guest.userId)
		end
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return if guest then getTemplate(nil) else nil
	end

	model.Parent = templateFolder
	templates[key] = model
	return model
end

local function loadTrack(humanoid: Humanoid, id: string): AnimationTrack?
	local ok, track = pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local loaded = animator:LoadAnimation(animation)
		loaded.Looped = true
		return loaded
	end)
	return if ok then track else nil
end

local function setWalking(customer: Customer, walking: boolean)
	if walking then
		if customer.idle then
			customer.idle:Stop(0.2)
		end
		if customer.walk and not customer.walk.IsPlaying then
			customer.walk:Play(0.2)
		end
	else
		if customer.walk then
			customer.walk:Stop(0.2)
		end
		if customer.idle and not customer.idle.IsPlaying then
			customer.idle:Play(0.2)
		end
	end
end

-- Telek-lokális (X, Z) → világ pozíció a padló szintjén.
local function worldPoint(state: PlotService.PlotState, x: number, z: number): Vector3
	return (state.plot.origin * CFrame.new(x, Layout.FloorTop, z)).Position
end

-- A sorban az index-edik hely (1 = a pultnál). LineLength után balra fordul (L alak), hogy ne lógjon ki az utcára.
local function queuePosition(index: number): (number, number)
	local counter = Layout.Counter
	local line = math.min(index, Settings.LineLength)
	local z = counter.Position.Y + Settings.FirstOffset + (line - 1) * Settings.Spacing
	local x = counter.Position.X - math.max(0, index - Settings.LineLength) * Settings.Spacing
	return x, z
end

-- Végigsétáltatja a vendéget a pontokon. Egy újabb walk() megszakítja az előzőt.
local function walk(customer: Customer, points: { Vector3 }, onArrive: (() -> ())?)
	customer.pathId += 1
	local pathId = customer.pathId
	customer.arrivedAt = nil

	task.spawn(function()
		setWalking(customer, true)
		for _, point in points do
			if customer.pathId ~= pathId or not customer.model.Parent then
				return
			end
			customer.humanoid:MoveTo(point)
			local reached = false
			local connection = customer.humanoid.MoveToFinished:Connect(function(success)
				reached = success
			end)
			local started = os.clock()
			while not reached and os.clock() - started < MOVE_TIMEOUT do
				if customer.pathId ~= pathId or not customer.model.Parent then
					connection:Disconnect()
					return
				end
				task.wait(0.1)
			end
			connection:Disconnect()
			if not reached and customer.model.Parent then
				-- elakadt (pl. meglökték): odaugrik
				customer.model:PivotTo(CFrame.new(point + Vector3.new(0, customer.root.Size.Y / 2 + customer.humanoid.HipHeight, 0)))
			end
		end
		if customer.pathId == pathId and customer.model.Parent then
			setWalking(customer, false)
			if onArrive then
				onArrive()
			end
		end
	end)
end

local function spawnCustomer(state: PlotService.PlotState, guest: Guest?): Customer?
	local template = getTemplate(guest)
	if not template or not PlotService.isActive(state) then
		return nil
	end

	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		model:Destroy()
		return nil
	end

	model.Name = "Customer"
	root.Anchored = false
	humanoid.WalkSpeed = Settings.WalkSpeed
	humanoid.DisplayName = if guest then guest.name else "Guest"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	local entry = worldPoint(state, Settings.EntryX, Settings.StreetZ)
	local height = humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.lookAt(entry + Vector3.new(0, height, 0), worldPoint(state, 0, Settings.StreetZ) + Vector3.new(0, height, 0)))
	model.Parent = state.plot.customers
	pcall(function()
		root:SetNetworkOwner(nil) -- a szerver mozgatja
	end)

	local animations = ANIMATIONS[humanoid.RigType] or ANIMATIONS[Enum.HumanoidRigType.R15]
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		idle = loadTrack(humanoid, animations.idle),
		walk = loadTrack(humanoid, animations.walk),
		pathId = 0,
	}
end

-- A vendég a sorban a helyére megy (az utcáról érkezve az utcán át, egyébként egyenesen előre).
local function goToQueue(state: PlotService.PlotState, customer: Customer, index: number, fromStreet: boolean)
	local x, z = queuePosition(index)
	local points = {}
	if fromStreet then
		table.insert(points, worldPoint(state, x, Settings.StreetZ))
	end
	table.insert(points, worldPoint(state, x, z))
	walk(customer, points, function()
		customer.arrivedAt = os.clock()
		-- a pult felé fordul
		local counter = Layout.Counter
		local look = worldPoint(state, counter.Position.X, counter.Position.Y)
		local position = customer.root.Position
		customer.root.CFrame = CFrame.lookAt(position, Vector3.new(look.X, position.Y, look.Z))
	end)
end

-- Schnitzel a kiszolgált vendég kezébe.
local function giveSchnitzel(customer: Customer)
	local hand = customer.model:FindFirstChild("RightHand") or customer.model:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local schnitzel = Instance.new("Part")
	schnitzel.Name = "Schnitzel"
	schnitzel.Size = Vector3.new(1.6, 0.25, 1.2)
	schnitzel.Color = Palette.Schnitzel
	schnitzel.Material = Enum.Material.SmoothPlastic
	schnitzel.CanCollide = false
	schnitzel.Massless = true
	schnitzel.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -0.4)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = schnitzel
	weld.Parent = schnitzel
	schnitzel.Parent = customer.model
end

-- Kiszolgálva: a kijárati sávon át az utca másik irányába, majd eltűnik.
local function leave(state: PlotService.PlotState, customer: Customer)
	giveSchnitzel(customer)
	local _, z = queuePosition(1)
	walk(customer, {
		worldPoint(state, Settings.ExitLaneX, z),
		worldPoint(state, Settings.ExitLaneX, Settings.StreetZ),
		worldPoint(state, Settings.ExitX, Settings.StreetZ),
	}, function()
		customer.model:Destroy()
	end)
end

-- GDD 3.12 Ételkritikus: az aktuális kritikus-event (id, határidő, beállítások)
local critic: { id: number, active: boolean, deadline: number, config: any } = {
	id = 0,
	active = false,
	deadline = 0,
	config = nil,
}

function CustomerService.startCritic(config: any)
	critic.id += 1
	critic.active = true
	critic.deadline = os.clock() + config.Duration
	critic.config = config
end

function CustomerService.endCritic()
	critic.active = false
end

-- A VIP vendég: alap avatar arany koronával, "⭐ Food Critic" névvel.
local function spawnCritic(state: PlotService.PlotState): Customer?
	local customer = spawnCustomer(state, nil)
	if not customer then
		return nil
	end
	customer.vip = true
	customer.humanoid.DisplayName = "⭐ Food Critic"
	local head = customer.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(1.3, 0.5, 1.3)
		crown.Color = Palette.RarityGold
		crown.Material = Enum.Material.Neon
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.3, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = crown
		weld.Parent = crown
		crown.Parent = customer.model
	end
	return customer
end

local function rewardCritic(state: PlotService.PlotState)
	local config = critic.config
	local data = state.data
	local raw = data()
	local reward = math.max(config.RewardMin, math.floor(Formulas.incomePerSecond(raw) * config.RewardIncomeSeconds))
	data.money(raw.money + reward)
	Remotes.EventReward:FireClient(state.player, `🎩 The Food Critic loved it! +{NumberFormat.money(reward)}`, config.Color)
end

-- A VIP kiszolgálás nélkül, dühösen távozik (nincs schnitzel a kezében).
local function criticLeavesAngry(state: PlotService.PlotState, customer: Customer)
	Remotes.EventReward:FireClient(state.player, "😠 The Food Critic left hungry…", Palette.Danger)
	local x, z = queuePosition(1)
	walk(customer, {
		worldPoint(state, x, Settings.StreetZ),
		worldPoint(state, Settings.EntryX, Settings.StreetZ),
	}, function()
		customer.model:Destroy()
	end)
end

local function runQueue(state: PlotService.PlotState)
	local owner = state.player
	local pool = fetchFriends(owner.UserId)
	if #pool == 0 and owner.UserId > 0 then
		pool = { { userId = owner.UserId, name = owner.DisplayName } }
	end

	local rng = Random.new()
	local order = {}
	local function nextGuest(): Guest?
		if #pool == 0 then
			return nil
		end
		if #order == 0 then
			order = table.clone(pool)
			rng:Shuffle(order)
		end
		return table.remove(order)
	end

	local queue: { Customer } = {}
	local lastServed = 0
	local criticId = 0 -- melyik kritikus-eventhez spawnoltunk már VIP-et

	local function reposition()
		for index, customer in queue do
			goToQueue(state, customer, index, false)
		end
	end

	while PlotService.isActive(state) do
		local event = EventState.config()
		local now = os.clock()

		-- 1. a sor feltöltése (egyszerre egy új vendég); a hossz a pult szintjétől függ (GDD 3.5),
		--    Ebédcsúcs alatt több vendég (GDD 3.12)
		local wanted = Formulas.customerCount(state.data().counter.level)
		if event and event.CustomerMultiplier then
			wanted = math.min(wanted * event.CustomerMultiplier, event.MaxCustomers or wanted)
		end
		if #queue < wanted then
			local customer = spawnCustomer(state, nextGuest())
			if customer then
				table.insert(queue, customer)
				goToQueue(state, customer, #queue, true)
			end
		end

		-- 2. Ételkritikus: VIP a sor elejére (eventenként egyszer)
		if critic.active and criticId ~= critic.id then
			criticId = critic.id
			local vip = spawnCritic(state)
			if vip then
				table.insert(queue, 1, vip)
				goToQueue(state, vip, 1, true)
				for index = 2, #queue do
					goToQueue(state, queue[index], index, false)
				end
			end
		end
		-- ha lejárt az idő, a ki nem szolgált VIP dühösen elmegy
		local vipIndex
		for index, customer in queue do
			if customer.vip then
				vipIndex = index
				break
			end
		end
		if vipIndex and (not critic.active or now > critic.deadline) then
			local vip = table.remove(queue, vipIndex)
			criticLeavesAngry(state, vip)
			reposition()
		end

		-- 3. kiszolgálás, ha a pult nemrég adott el (a VIP-et azonnal, a többieket ServeInterval-onként)
		local front = queue[1]
		local selling = state.lastSaleAt ~= nil and now - state.lastSaleAt <= Settings.SaleWindow
		local serveInterval = Settings.ServeInterval / (if event then event.SellMultiplier or 1 else 1)
		if
			front
			and front.arrivedAt
			and selling
			and now - front.arrivedAt >= Settings.ServeTime
			and (front.vip or now - lastServed >= serveInterval)
		then
			lastServed = now
			table.remove(queue, 1)
			if front.vip then
				rewardCritic(state)
			end
			leave(state, front)
			reposition()
		end

		task.wait(LOOP_INTERVAL)
	end
end

function CustomerService.init()
	templateFolder = Instance.new("Folder")
	templateFolder.Name = "CustomerTemplates"
	templateFolder.Parent = ServerStorage

	PlotService.onAssigned(runQueue)
end

return CustomerService
