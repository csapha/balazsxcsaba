-- Petek (GDD 3.9): Tojás tér az utca közepén, tojásnyitás, leltár, felszerelés, törlés, arany pet.
-- A bónuszokat a Formulas.petBonuses számolja (pénz, sütés, szerencse, chef sebesség).
-- A többi játékos is látja a petjeidet: a "EquippedPets" játékos-attribútumból (PetFollowController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PetConfig = Config.Pets
local Palette = Config.Palette

local OPEN_COOLDOWN = 0.6 -- mp (gyors tojásnyitás gamepass később, GDD 6.2)

local PetService = {}

local rng = Random.new()
local lastOpen: { [Player]: number } = {}
local eggStands: { BasePart } = {}

-- A játékos petjeinek új állapota (egyben írjuk, egyszerűbb a replikáció).
local function writePets(player: Player, inventory: { any }, equipped: { number }, nextId: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.pets({ inventory = inventory, equipped = equipped, nextId = nextId })

	-- a többi kliens ebből rajzolja ki a követő peteket: "Kutyus:0,Sarkany:1"
	local byUid = {}
	for _, pet in inventory do
		byUid[pet.uid] = pet
	end
	local parts = {}
	for _, uid in equipped do
		local pet = byUid[uid]
		if pet then
			table.insert(parts, `{pet.id}:{if pet.golden then 1 else 0}`)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(parts, ","))
end

local function snapshot(player: Player): (any?, { any }, { number }, number)
	local data = DataService.get(player)
	if not data then
		return nil, {}, {}, 1
	end
	local raw = data()
	return raw, table.clone(raw.pets.inventory), table.clone(raw.pets.equipped), raw.pets.nextId
end

function PetService.openEgg(player: Player, eggIndex: number): string?
	local egg = PetConfig.Eggs[eggIndex]
	local stand = eggStands[eggIndex]
	if not egg or not stand then
		return nil
	end

	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < OPEN_COOLDOWN then
		return nil
	end

	-- távolság-ellenőrzés (GDD 12.2)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - stand.Position).Magnitude > PetConfig.Plaza.OpenDistance + 6 then
		return nil
	end

	local raw, inventory, equipped, nextId = snapshot(player)
	if not raw or #inventory >= PetConfig.MaxInventory or raw.money < egg.Price then
		return nil
	end
	local petId = Formulas.rollEgg(rng, eggIndex)
	if not petId then
		return nil
	end
	lastOpen[player] = now

	local data = DataService.get(player)
	data.money(raw.money - egg.Price)

	local uid = nextId
	table.insert(inventory, { uid = uid, id = petId, golden = false })
	-- ha van szabad aktív hely, rögtön felszereljük
	if #equipped < PetConfig.ActiveSlots then
		table.insert(equipped, uid)
	end
	writePets(player, inventory, equipped, nextId + 1)

	Remotes.EggOpened:FireClient(player, eggIndex, petId)
	local rarity = PetConfig.Rarities[PetConfig.List[petId].Rarity]
	if rarity.Announce then
		Remotes.PetHatched:FireAllClients(player.DisplayName, petId)
	end
	return petId
end

local function indexOfUid(list: { any }, uid: number, field: string?): number?
	for i, item in list do
		local value = if field then item[field] else item
		if value == uid then
			return i
		end
	end
	return nil
end

local actions = {}

function actions.equip(player: Player, uid: unknown)
	local raw, inventory, equipped, nextId = snapshot(player)
	if not raw or type(uid) ~= "number" or not indexOfUid(inventory, uid, "uid") then
		return
	end
	if indexOfUid(equipped, uid) or #equipped >= PetConfig.ActiveSlots then
		return
	end
	table.insert(equipped, uid)
	writePets(player, inventory, equipped, nextId)
end

function actions.unequip(player: Player, uid: unknown)
	local raw, inventory, equipped, nextId = snapshot(player)
	local index = raw and type(uid) == "number" and indexOfUid(equipped, uid)
	if not index then
		return
	end
	table.remove(equipped, index)
	writePets(player, inventory, equipped, nextId)
end

function actions.delete(player: Player, uid: unknown)
	local raw, inventory, equipped, nextId = snapshot(player)
	local index = raw and type(uid) == "number" and indexOfUid(inventory, uid, "uid")
	if not index then
		return
	end
	table.remove(inventory, index)
	local equippedIndex = indexOfUid(equipped, uid :: number)
	if equippedIndex then
		table.remove(equipped, equippedIndex)
	end
	writePets(player, inventory, equipped, nextId)
end

-- 5 azonos (nem arany) pet → 1 arany. Elsőként a nem felszerelteket használja fel;
-- ha felszereltet is felhasznált, a helyére az új arany pet kerül.
function actions.golden(player: Player, petId: unknown)
	local raw, inventory, equipped, nextId = snapshot(player)
	if not raw or type(petId) ~= "string" or not PetConfig.List[petId] then
		return
	end

	local candidates = {}
	for _, pet in inventory do
		if pet.id == petId and not pet.golden then
			table.insert(candidates, pet.uid)
		end
	end
	if #candidates < PetConfig.GoldenCount then
		return
	end
	table.sort(candidates, function(a, b)
		local aEquipped = indexOfUid(equipped, a) ~= nil
		local bEquipped = indexOfUid(equipped, b) ~= nil
		if aEquipped ~= bEquipped then
			return not aEquipped
		end
		return a < b
	end)

	local usedEquipped = false
	for i = 1, PetConfig.GoldenCount do
		local uid = candidates[i]
		local index = indexOfUid(inventory, uid, "uid")
		if index then
			table.remove(inventory, index)
		end
		local equippedIndex = indexOfUid(equipped, uid)
		if equippedIndex then
			table.remove(equipped, equippedIndex)
			usedEquipped = true
		end
	end

	local uid = nextId
	table.insert(inventory, { uid = uid, id = petId, golden = true })
	if usedEquipped or #equipped < PetConfig.ActiveSlots then
		table.insert(equipped, uid)
	end
	writePets(player, inventory, equipped, nextId + 1)
end

-- Tojás tér: 4 talapzat tojással, felirat (név, ár, esélyek) és "Nyisd ki" prompt.
local function buildPlaza()
	local folder = Instance.new("Folder")
	folder.Name = "EggPlaza"
	folder.Parent = workspace

	local plaza = PetConfig.Plaza
	local count = #PetConfig.Eggs
	for index, egg in PetConfig.Eggs do
		local x = plaza.Center.X + (index - (count + 1) / 2) * plaza.Spacing
		local base = Vector3.new(x, plaza.Center.Y, plaza.Center.Z)

		local pedestal = Instance.new("Part")
		pedestal.Name = `EggPedestal{index}`
		pedestal.Anchored = true
		pedestal.Size = Vector3.new(6, 2, 6)
		pedestal.CFrame = CFrame.new(base + Vector3.new(0, 1, 0))
		pedestal.Color = Palette.Wood
		pedestal.Material = Enum.Material.WoodPlanks
		pedestal.Parent = folder

		local eggPart = Instance.new("Part")
		eggPart.Name = `Egg{index}`
		eggPart.Anchored = true
		eggPart.Size = Vector3.new(4, 5, 4)
		eggPart.CFrame = CFrame.new(base + Vector3.new(0, 4.6, 0))
		eggPart.Color = egg.Color
		eggPart.Material = Enum.Material.SmoothPlastic
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = eggPart
		eggPart.Parent = folder
		eggStands[index] = eggPart

		-- felirat: név, ár, esélyek
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(9, 6.5)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 120
		local layout = Instance.new("UIListLayout")
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = gui

		local lines = {
			{ egg.Name, Palette.White, 0.2 },
			{ NumberFormat.money(egg.Price), Palette.Money, 0.16 },
		}
		for _, entry in egg.Pets do
			local pet = PetConfig.List[entry[1]]
			local rarity = PetConfig.Rarities[pet.Rarity]
			table.insert(lines, { `{pet.Name} {entry[2]}%`, rarity.Color, 0.14 })
		end
		for order, line in lines do
			local label = Instance.new("TextLabel")
			label.LayoutOrder = order
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, line[3])
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = line[1]
			label.TextColor3 = line[2]
			Ui.worldText(label)
			label.Parent = gui
		end
		gui.Parent = eggPart

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `Open ({NumberFormat.money(egg.Price)})`
		prompt.ObjectText = egg.Name
		prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by the client's PromptController (UI Kit card)
		prompt:SetAttribute("Color", "Pink")
		prompt:SetAttribute("Icon", Ui.Icons.Egg)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = plaza.OpenDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = eggPart
		prompt.Triggered:Connect(function(player)
			PetService.openEgg(player, index)
		end)
	end
end

function PetService.init()
	buildPlaza()
end

function PetService.start()
	Remotes.PetAction.OnServerEvent:Connect(function(player, action: unknown, arg: unknown)
		local handler = type(action) == "string" and actions[action]
		if handler then
			handler(player, arg)
		end
	end)

	-- belépéskor a követő petek attribútuma
	local function setup(player: Player)
		local data = DataService.wait(player)
		if not data then
			return
		end
		local raw = data()
		writePets(player, raw.pets.inventory, raw.pets.equipped, raw.pets.nextId)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
end

return PetService
