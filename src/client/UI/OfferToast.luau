-- Offer toasts (GDD 6.5): a small card bottom right at the moment the wish appears:
--   your chef fell asleep → Tireless Chefs; a rare (Gold+) schnitzel on your plot → Lucky x2;
--   half way to the next rebirth → Rebirth Skip; a later session within the starter pack's 3 days → Starter Pack.
-- Each one only once ever (data.shop.toasts, Remotes.ToastSeen), at most one per Config.Shop.Toasts.Gap seconds,
-- and none in the first MinSessionSeconds of a session (the Starter Pack waits 20 s on a later session).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local ShopWindow = require(script.Parent.ShopWindow)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local C = Theme.Colors
local ShopConfig = Config.Shop
local Toasts = ShopConfig.Toasts
local player = Players.LocalPlayer

local OfferToast = {}

local current = source(nil :: string?)
local sessionStart = os.clock()
local lastShown = -math.huge
local hideToken = 0

-- What the toast sells: kind ("Pass" / "Product") and key; the Rebirth Skip follows the current tier.
local function target(id: string): (string, string)
	local entry = Toasts.List[id]
	if entry.Kind == "Skip" then
		return "Product", Formulas.rebirthSkipProduct(State.rebirths())
	end
	return entry.Kind, entry.Key
end

local function item(id: string): any
	local kind, key = target(id)
	return if kind == "Pass" then ShopConfig.Passes[key] else ShopConfig.Products[key]
end

local function price(id: string): number
	local kind, key = target(id)
	if kind == "Pass" then
		return (ShopWindow.passPrice(key, os.time()))
	end
	return ShopWindow.productPrice(key)
end

local function hide()
	current(nil)
end

local function canShow(id: string, ignoreSession: boolean?): boolean
	local entry = Toasts.List[id]
	if not entry or State.shop().toasts[id] or current() ~= nil or State.window() ~= nil then
		return false
	end
	if entry.Kind == "Pass" and State.passes()[entry.Key] then
		return false
	end
	local now = os.clock()
	if not ignoreSession and now - sessionStart < Toasts.MinSessionSeconds then
		return false
	end
	return now - lastShown >= Toasts.Gap
end

function OfferToast.show(id: string, ignoreSession: boolean?)
	if not canShow(id, ignoreSession) then
		return
	end
	lastShown = os.clock()
	current(id)
	Audio.play("Ding")
	Remotes.ToastSeen:FireServer(id)
	hideToken += 1
	local token = hideToken
	task.delay(Toasts.ShowSeconds, function()
		if token == hideToken then
			hide()
		end
	end)
end

local function ownPlot(): Instance?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function chefAsleep(): boolean
	local plot = ownPlot()
	local chefs = plot and plot:FindFirstChild("Chefs", true)
	if not chefs then
		return false
	end
	for _, chef in chefs:GetDescendants() do
		if chef:GetAttribute("Phase") == "sleep" then
			return true
		end
	end
	return false
end

-- the triggers
function OfferToast.start()
	Remotes.RareBake.OnClientEvent:Connect(function(plotIndex: number, _slot: number, rarity: number)
		if plotIndex == player:GetAttribute("PlotIndex") and rarity >= 3 then
			OfferToast.show("Lucky")
		end
	end)

	-- a later session while the starter pack is still on sale
	task.delay(20, function()
		local shop = State.shop()
		local data = { shop = shop }
		if os.time() - shop.firstJoin > 30 * 60 and Formulas.starterRemaining(data) > 0 then
			OfferToast.show("Starter", true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			if chefAsleep() then
				OfferToast.show("TirelessChefs")
			end
			local requirement = Formulas.rebirthRequirement(State.rebirths())
			local progress = State.earned() / requirement
			if progress >= 0.5 and progress < 1 then
				OfferToast.show("RebirthSkip")
			end
		end
	end)
end

function OfferToast.render(): Frame
	local shown = spring(function()
		return if current() ~= nil then 1 else 0
	end, 0.3, 0.75)
	local function field(get: (id: string) -> string): () -> string
		return function()
			local id = current()
			return if id then get(id) else ""
		end
	end
	return create "Frame" {
		Name = "OfferToast",
		AnchorPoint = Vector2.new(1, 1),
		-- slides in from the right edge
		Position = function()
			return UDim2.new(1, -16 + (1 - shown()) * 420, 1, -16)
		end,
		Size = UDim2.fromOffset(380, 112),
		BackgroundTransparency = 1,
		Visible = function()
			return shown() > 0.01
		end,
		ZIndex = 8,
		Kit.scale(),
		Kit.darkBox {
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			Fill = C.Panel,
			Transparency = Theme.PanelTransparency,
			Line = Theme.Palettes.Yellow.light,
			create "ImageLabel" {
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(52, 56),
				Size = UDim2.fromOffset(120, 120),
				BackgroundTransparency = 1,
				Image = Ui.Textures.Soft,
				ImageColor3 = Theme.Palettes.Yellow.top,
				ImageTransparency = 0.6,
			},
			create "ImageLabel" {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(52, 56),
				Size = UDim2.fromOffset(74, 74),
				BackgroundTransparency = 1,
				Image = function()
					local id = current()
					return if id then Ui.Icons[item(id).Icon] or Ui.Icons.Shop else ""
				end,
				ScaleType = Enum.ScaleType.Fit,
				Rotation = -8,
				ZIndex = 3,
			},
			Kit.text {
				Name = "Text",
				Text = field(function(id)
					return Toasts.List[id].Text
				end),
				TextSize = 15,
				TextColor3 = C.Muted,
				Gradient = false,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(100, 10),
				Size = UDim2.new(1, -150, 0, 38),
				ZIndex = 3,
			},
			Kit.text {
				Name = "Item",
				Text = field(function(id)
					return item(id).Name
				end),
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(100, 46),
				Size = UDim2.new(1, -110, 0, 26),
				ZIndex = 3,
			},
			Kit.button {
				Name = "Buy",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 100, 1, -8),
				Size = UDim2.fromOffset(150, 34),
				TextSize = 18,
				Bounce = 0.5,
				Color = "Green",
				Text = field(function(id)
					return `R$ {price(id)}`
				end),
				Activated = function()
					local id = current()
					if id then
						local kind, key = target(id)
						Remotes.ShopBuy:FireServer(kind, key)
						hide()
					end
				end,
				ZIndex = 4,
			},
			Kit.closeButton {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -24, 0, 24),
				Size = UDim2.fromOffset(30, 30),
				Activated = hide,
				ZIndex = 4,
			},
		},
	} :: Frame
end

return OfferToast
