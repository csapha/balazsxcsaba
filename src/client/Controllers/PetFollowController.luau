-- Követő petek (GDD 3.9): minden játékos aktív petjei a játékos mögött ívben követik, enyhén ugrálva.
-- A szerver a "EquippedPets" attribútumba írja: "Kutyus:0,Sarkany:1" (id:arany).
-- Placeholder blokkos figurák (test + fej + fülek + szemek), az arany pet csillog.
-- Legendás pet kikelésekor chat bejelentés (GDD 8: szerver announcement).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Chat = require(script.Parent.Parent.Util.Chat)

local PetConfig = Config.Pets
local Palette = Config.Palette

-- az aktív petek helye a játékoshoz képest (jobbra-hátra, hátra, balra-hátra)
local OFFSETS = {
	Vector3.new(3.2, 0, 3),
	Vector3.new(0, 0, 4.2),
	Vector3.new(-3.2, 0, 3),
	Vector3.new(0, 0, 6.5),
}
local FOLLOW_SPEED = 8

type PetVisual = {
	key: string,
	model: Model,
	parts: { [string]: BasePart },
	cframe: CFrame?,
}

local PetFollowController = {}

local folder: Folder
local visuals: { [Player]: { PetVisual } } = {}

local function part(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildPet(id: string, golden: boolean): (Model, { [string]: BasePart })
	local definition = PetConfig.List[id]
	local color = if golden then Palette.RarityGold else (definition and definition.Color or Palette.White)
	local model = Instance.new("Model")
	model.Name = id

	local parts = {
		Body = part("Body", Vector3.new(1.6, 1.2, 2), color, model),
		Head = part("Head", Vector3.new(1.3, 1.2, 1.2), color, model),
		EarL = part("EarL", Vector3.new(0.35, 0.6, 0.3), color, model),
		EarR = part("EarR", Vector3.new(0.35, 0.6, 0.3), color, model),
		EyeL = part("EyeL", Vector3.new(0.2, 0.25, 0.05), Color3.new(0.1, 0.1, 0.1), model),
		EyeR = part("EyeR", Vector3.new(0.2, 0.25, 0.05), Color3.new(0.1, 0.1, 0.1), model),
	}
	if golden then
		for _, name in { "Body", "Head", "EarL", "EarR" } do
			parts[name].Material = Enum.Material.Neon
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Palette.RarityGold
		sparkles.Parent = parts.Body
	end

	model.Parent = folder
	return model, parts
end

local function poseParts(parts: { [string]: BasePart }, root: CFrame)
	parts.Body.CFrame = root
	local head = root * CFrame.new(0, 0.7, -1.1)
	parts.Head.CFrame = head
	parts.EarL.CFrame = head * CFrame.new(-0.4, 0.85, 0)
	parts.EarR.CFrame = head * CFrame.new(0.4, 0.85, 0)
	parts.EyeL.CFrame = head * CFrame.new(-0.3, 0.15, -0.61)
	parts.EyeR.CFrame = head * CFrame.new(0.3, 0.15, -0.61)
end

local function parseEquipped(value: unknown): { { id: string, golden: boolean } }
	local result = {}
	if type(value) ~= "string" or value == "" then
		return result
	end
	for entry in string.gmatch(value, "[^,]+") do
		local id, golden = string.match(entry, "^([^:]+):(%d)$")
		if id and PetConfig.List[id] then
			table.insert(result, { id = id, golden = golden == "1" })
		end
	end
	return result
end

local function clear(player: Player)
	for _, visual in visuals[player] or {} do
		visual.model:Destroy()
	end
	visuals[player] = nil
end

local function update(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local wanted = if root then parseEquipped(player:GetAttribute("EquippedPets")) else {}

		-- a lista igazítása a felszerelt petekhez (sorrendben): ami egyezik, marad, a többi újraépül
		local old = visuals[player] or {}
		local list: { PetVisual } = {}
		local kept = {}
		for i, want in wanted do
			local key = `{want.id}:{want.golden}`
			local visual = old[i]
			if visual and visual.key == key then
				kept[visual] = true
				list[i] = visual
			else
				local model, parts = buildPet(want.id, want.golden)
				list[i] = { key = key, model = model, parts = parts, cframe = visual and visual.cframe }
			end
		end
		for _, visual in old do
			if not kept[visual] then
				visual.model:Destroy()
			end
		end
		visuals[player] = list

		if not root then
			continue
		end
		local rootPart = root :: BasePart
		local base = rootPart.CFrame
		local flat = CFrame.new(base.Position) * CFrame.fromOrientation(0, select(2, base:ToOrientation()), 0)
		for i, visual in list do
			local offset = OFFSETS[i] or OFFSETS[#OFFSETS]
			local hop = math.abs(math.sin(now * 6 + i)) * 0.5
			local target = flat * CFrame.new(offset.X, -2.2 + hop, offset.Z)
			local current = visual.cframe or target
			local alpha = math.clamp(dt * FOLLOW_SPEED, 0, 1)
			visual.cframe = current:Lerp(target, alpha)
			poseParts(visual.parts, visual.cframe :: CFrame)
		end
	end

	for player in visuals do
		if player.Parent ~= Players then
			clear(player)
		end
	end
end

local function onHatched(playerName: string, petId: string)
	local pet = PetConfig.List[petId]
	if not pet then
		return
	end
	local rarity = PetConfig.Rarities[pet.Rarity]
	Chat.announce(`🎉 {playerName} kikeltette: {pet.Name} ({rarity.Name})!`, rarity.Color)
end

function PetFollowController.init()
	folder = Instance.new("Folder")
	folder.Name = "PetVisuals"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(update)
	Players.PlayerRemoving:Connect(clear)
	Remotes.PetHatched.OnClientEvent:Connect(onHatched)
end

return PetFollowController
