-- Kozmetikumok (GDD 5.1 ⑥). Döntés 2026-11-15: most csak trail-ek és telek-színek (a modellek később jönnek).
--   Trail: a karakter mögött (szerver oldali Trail, mindenki látja).
--   Telek téma: a telek padlója, platformja, pultja és tábla-oszlopa más színű / anyagú (Classic = az alap).
-- Vásárlás: Robuxért a ShopService hívja a grant-ot; játékpénzért (MoneyPrice) a "buyMoney" akció.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local ShopConfig = Config.Shop

-- telek rész neve → a téma melyik színét kapja
local THEME_PARTS = {
	Floor = "Floor",
	Platform = "Platform",
	Counter = "Counter",
	SignPost = "Accent",
}

local CosmeticService = {}

local function kindOf(id: string): string?
	if ShopConfig.Trails[id] then
		return "Trail"
	elseif ShopConfig.Themes[id] then
		return "Theme"
	end
	return nil
end

function CosmeticService.owns(raw: any, id: string): boolean
	local theme = ShopConfig.Themes[id]
	if theme and theme.Free then
		return true
	end
	return raw.cosmetics.owned[id] == true
end

local function rainbow(): ColorSequence
	local keypoints = {}
	for i = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.85, 1)))
	end
	return ColorSequence.new(keypoints)
end

-- A felszerelt trail a karakterre (vagy le, ha nincs).
function CosmeticService.applyTrail(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = DataService.get(player)
	if not root or not data then
		return
	end
	for _, name in { "CosmeticTrail", "CosmeticTrailTop", "CosmeticTrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local definition = ShopConfig.Trails[data().cosmetics.trail]
	if not definition then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "CosmeticTrailTop"
	top.Position = Vector3.new(0, 0.6, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "CosmeticTrailBottom"
	bottom.Position = Vector3.new(0, -1.6, 0.4)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = if definition.Rainbow then rainbow() else ColorSequence.new(definition.Colors[1], definition.Colors[2])
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.7
	trail.MinLength = 0.1
	trail.LightEmission = if definition.Glow then 0.7 else 0
	trail.FaceCamera = true
	trail.Parent = root
end

-- A telek színei a felszerelt téma szerint (az eredeti színt / anyagot attribútumban őrizzük, így a Classic
-- és a következő tulajdonos is visszakapja az alapot).
function CosmeticService.applyTheme(state: PlotService.PlotState)
	local raw = state.data()
	local theme = ShopConfig.Themes[raw.cosmetics.theme] or ShopConfig.Themes.Classic
	for name, key in THEME_PARTS do
		local part = state.plot.model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if part:GetAttribute("BaseColor") == nil then
				part:SetAttribute("BaseColor", part.Color)
				part:SetAttribute("BaseMaterial", part.Material.Name)
			end
			part.Color = (theme :: any)[key] or part:GetAttribute("BaseColor")
			if name == "Floor" then
				part.Material = theme.FloorMaterial or (Enum.Material :: any)[part:GetAttribute("BaseMaterial")]
			end
		end
	end
end

local function refresh(player: Player)
	CosmeticService.applyTrail(player)
	local state = PlotService.get(player)
	if state then
		CosmeticService.applyTheme(state)
	end
end

local function setCosmetics(player: Player, change: (cosmetics: any) -> ())
	local data = DataService.get(player)
	if not data then
		return
	end
	local raw = data()
	local cosmetics = {
		owned = table.clone(raw.cosmetics.owned),
		trail = raw.cosmetics.trail,
		theme = raw.cosmetics.theme,
	}
	change(cosmetics)
	data.cosmetics(cosmetics)
	refresh(player)
end

local function equip(player: Player, id: string)
	local kind = kindOf(id)
	setCosmetics(player, function(cosmetics)
		if kind == "Trail" then
			cosmetics.trail = id
		elseif kind == "Theme" then
			cosmetics.theme = id
		end
	end)
end

-- Robux vásárlás (ShopService): megkapja és rögtön fel is veszi.
function CosmeticService.grant(player: Player, id: string): boolean
	if not kindOf(id) then
		return false
	end
	setCosmetics(player, function(cosmetics)
		cosmetics.owned[id] = true
	end)
	equip(player, id)
	return true
end

local function onAction(player: Player, action: unknown, id: unknown)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" or not kindOf(id) then
		return
	end
	local raw = data()
	if action == "equip" then
		if CosmeticService.owns(raw, id) then
			equip(player, id)
		end
	elseif action == "unequip" then
		setCosmetics(player, function(cosmetics)
			if cosmetics.trail == id then
				cosmetics.trail = ""
			end
			if cosmetics.theme == id then
				cosmetics.theme = "Classic"
			end
		end)
	elseif action == "buyMoney" then
		local trail = ShopConfig.Trails[id]
		local price = trail and trail.MoneyPrice
		if not price or CosmeticService.owns(raw, id) or raw.money < price then
			return
		end
		data.money(raw.money - price)
		AnalyticsService.sink(player, price, "Shop", `Trail{id}`)
		CosmeticService.grant(player, id)
		Remotes.ShopPurchased:FireClient(player, "Cosmetic", id, "Equipped!")
	end
end

function CosmeticService.init()
	PlotService.onAssigned(function(state)
		CosmeticService.applyTheme(state)
	end)
end

function CosmeticService.start()
	Guard.connect(Remotes.CosmeticAction, onAction)
	local function setup(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			CosmeticService.applyTrail(player)
		end)
		if DataService.wait(player) and player.Character then
			CosmeticService.applyTrail(player)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
end

return CosmeticService
