-- VIP gamepass extrák (GDD 6.2) + Roblox Premium és csoport jutalom (GDD 6.4). Döntés 2026-11-15:
--   VIP: [VIP] címke (a "VIP" játékos attribútumból rajzolja a kliens: chat + név felett), VIP terület a
--        Tojás téren (csak VIP léphet be – a kliens a saját VIP karakterének kapcsolja ki az ütközést),
--        bent nagyobb esély a ritkább petekre (PetService), VIP pet egyszer, napi ajándék.
--   Premium: napi ajándék. Csoport: +10% pénz (Formulas.shopMoneyMultiplier, data.shop.inGroup).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local PetService = require(script.Parent.PetService)
local TutorialService = require(script.Parent.TutorialService)

local ShopConfig = Config.Shop
local Palette = Config.Palette
local CHECK_INTERVAL = 60 -- mp: napváltás figyelése (a napi ajándékhoz)

local MembershipService = {}

local function today(): number
	return os.time() // 86400
end

local function setShop(data: any, change: (shop: any) -> ())
	local shop = table.clone(data().shop)
	change(shop)
	data.shop(shop)
end

-- Napi ajándék: income mp bevétel (legalább Min $) + aura ticketek. Visszaad: a felugró szöveg.
local function giveGift(player: Player, data: any, gift: any, sku: string): string
	local raw = data()
	local perSecond = Formulas.incomePerSecond(raw) * IndexService.moneyBonus(player)
	local amount = math.max(gift.Min, math.floor(perSecond * gift.IncomeSeconds))
	data.money(raw.money + amount)
	AnalyticsService.source(player, amount, "TimedReward", sku)
	data.auras.tickets(raw.auras.tickets + gift.Tickets)
	return `+{NumberFormat.money(amount)} and +{gift.Tickets} aura ticket`
end

local function dailyGifts(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- GDD 7: a tutorial vezetett része alatt még nem (a percenkénti ellenőrzés utána odaadja)
	if TutorialService.guided(data()) then
		return
	end
	local day = today()
	if Formulas.hasPass(data(), "VIP") and data().shop.vipGiftDay < day then
		local message = giveGift(player, data, ShopConfig.Vip.DailyGift, "VipGift")
		setShop(data, function(shop)
			shop.vipGiftDay = day
		end)
		Remotes.ShopPurchased:FireClient(player, "Gift", "VipGift", message)
	end
	if player.MembershipType == Enum.MembershipType.Premium and data().shop.premiumGiftDay < day then
		local message = giveGift(player, data, ShopConfig.Premium, "PremiumGift")
		setShop(data, function(shop)
			shop.premiumGiftDay = day
		end)
		Remotes.ShopPurchased:FireClient(player, "Gift", "PremiumGift", message)
	end
end

-- Belépéskor és VIP vásárláskor: címke, VIP pet (egyszer), napi ajándékok.
function MembershipService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local vip = Formulas.hasPass(data(), "VIP")
	player:SetAttribute("VIP", if vip then true else nil)
	if vip and not data().shop.vipPetGiven then
		PetService.give(player, Config.Pets.VipPet)
		setShop(data, function(shop)
			shop.vipPetGiven = true
		end)
		local pet = Config.Pets.List[Config.Pets.VipPet]
		Remotes.ShopPurchased:FireClient(player, "Gift", "VipPet", `{pet.Name} joined you!`)
	end
	dailyGifts(player)
end

local function checkGroup(player: Player)
	local groupId = ShopConfig.Group.GroupId
	local data = DataService.get(player)
	if groupId <= 0 or not data then
		return
	end
	local ok, member = pcall(player.IsInGroup, player, groupId)
	if ok and member ~= data().shop.inGroup then
		setShop(data, function(shop)
			shop.inGroup = member
		end)
	end
end

-- VIP terület a Tojás téren: arany szőnyeg, kötél-oszlopok, és láthatatlan falak (VipBarrier tag),
-- amiken csak a VIP játékos megy át (a kliense kapcsolja ki rajtuk az ütközést).
local function buildVipArea()
	local folder = Instance.new("Folder")
	folder.Name = "VipArea"
	folder.Parent = workspace
	local center, size = Formulas.vipArea()
	local gold = ShopConfig.Vip.TagColor

	local carpet = Instance.new("Part")
	carpet.Name = "VipCarpet"
	carpet.Anchored = true
	carpet.CanCollide = false
	carpet.Size = Vector3.new(size.X, 0.2, size.Y)
	carpet.CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0))
	carpet.Color = gold
	carpet.Material = Enum.Material.Fabric
	carpet.Parent = folder

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(8, 1.6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "VIP ONLY – better egg luck!"
	label.TextColor3 = gold
	label.Parent = sign
	sign.Parent = carpet

	local wallHeight = 8
	local halfX, halfZ = size.X / 2, size.Y / 2
	local walls = {
		{ Vector3.new(0, 0, -halfZ), Vector3.new(size.X, wallHeight, 0.4) },
		{ Vector3.new(0, 0, halfZ), Vector3.new(size.X, wallHeight, 0.4) },
		{ Vector3.new(-halfX, 0, 0), Vector3.new(0.4, wallHeight, size.Y) },
		{ Vector3.new(halfX, 0, 0), Vector3.new(0.4, wallHeight, size.Y) },
	}
	for index, wall in walls do
		local part = Instance.new("Part")
		part.Name = `VipBarrier{index}`
		part.Anchored = true
		part.Transparency = 1
		part.Size = wall[2]
		part.CFrame = CFrame.new(center + wall[1] + Vector3.new(0, wallHeight / 2, 0))
		part.Parent = folder
		CollectionService:AddTag(part, "VipBarrier")
	end

	-- kötél-oszlopok a sarkokban és a hosszú oldalak közepén
	for _, offset in {
		Vector3.new(-halfX, 0, -halfZ), Vector3.new(halfX, 0, -halfZ), Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ), Vector3.new(0, 0, -halfZ), Vector3.new(0, 0, halfZ),
	} do
		local post = Instance.new("Part")
		post.Name = "VipPost"
		post.Anchored = true
		post.CanCollide = false
		post.Shape = Enum.PartType.Cylinder
		post.Size = Vector3.new(3, 0.6, 0.6)
		post.CFrame = CFrame.new(center + offset + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		post.Color = Palette.Gold
		post.Material = Enum.Material.Metal
		post.Parent = folder
	end
end

function MembershipService.init()
	buildVipArea()
end

function MembershipService.start()
	local function setup(player: Player)
		if not DataService.wait(player) then
			return
		end
		checkGroup(player)
		MembershipService.refresh(player)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerMembershipChanged:Connect(function(player)
		dailyGifts(player)
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				dailyGifts(player)
			end
		end
	end)
end

return MembershipService
