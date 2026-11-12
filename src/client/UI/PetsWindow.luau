-- Pet ablak (GDD 3.9, 9.4): aktív bónuszok, leltár (kártyák), kijelölt pet műveletei:
--   Felszerel / Levesz, "5 → Arany", Törlés (kétlépcsős megerősítéssel).
-- + Tojásnyitás animáció (remegő tojás → villanás → a pet kártyája), a szép VFX a 10. fejezetben.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local create = vide.create
local source = vide.source
local spring = vide.spring
local effect = vide.effect
local cleanup = vide.cleanup
local derive = vide.derive
local indexes = vide.indexes

local PetConfig = Config.Pets
local Palette = Config.Palette

type Source<T> = vide.Source<T>
type Pet = { uid: number, id: string, golden: boolean }
type PetsData = { inventory: { Pet }, equipped: { number }, nextId: number }

local PetsWindow = {}

local function text(props: { [any]: any })
	return create "TextLabel" {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,
		create "UIStroke" { Color = Palette.Stroke, Thickness = 2 },
		props,
	}
end

local function button(props: { [any]: any })
	return create "TextButton" {
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,
		AutoButtonColor = true,
		create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		create "UIPadding" { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) },
		props,
	}
end

local function percent(value: number): string
	return `+{math.floor(value * 100 + 0.5)}%`
end

local function bonusText(id: string, golden: boolean): string
	local definition = PetConfig.List[id]
	return `{PetConfig.Bonuses[definition.Bonus]} {percent(Formulas.petBonusValue(id, golden))}`
end

function PetsWindow.create(open: Source<boolean>, pets: Source<PetsData>)
	local selected = source(nil :: number?)
	local confirmDelete = source(false)

	local scale = spring(function()
		return if open() then 1 else 0.6
	end, 0.25, 0.55)

	local blur = Instance.new("BlurEffect")
	blur.Name = "PetsBlur"
	blur.Size = 0
	blur.Parent = Lighting
	effect(function()
		blur.Size = if open() then 12 else 0
	end)
	cleanup(blur)

	effect(function()
		if not open() then
			confirmDelete(false)
		end
	end)

	local function isEquipped(uid: number): boolean
		return table.find(pets().equipped, uid) ~= nil
	end

	-- leltár: felszereltek elöl, aztán arany, aztán ritkaság szerint
	local sorted = derive(function()
		local list = table.clone(pets().inventory)
		local equipped = pets().equipped
		table.sort(list, function(a, b)
			local ae, be = table.find(equipped, a.uid) ~= nil, table.find(equipped, b.uid) ~= nil
			if ae ~= be then
				return ae
			end
			if a.golden ~= b.golden then
				return a.golden
			end
			local ar = PetConfig.Rarities[PetConfig.List[a.id].Rarity].Order
			local br = PetConfig.Rarities[PetConfig.List[b.id].Rarity].Order
			if ar ~= br then
				return ar > br
			end
			return a.uid < b.uid
		end)
		return list
	end)

	local selectedPet = derive(function(): Pet?
		local uid = selected()
		if not uid then
			return nil
		end
		for _, pet in pets().inventory do
			if pet.uid == uid then
				return pet
			end
		end
		return nil
	end)

	local function sameCount(pet: Pet): number
		local count = 0
		for _, other in pets().inventory do
			if other.id == pet.id and not other.golden then
				count += 1
			end
		end
		return count
	end

	local function card(item: () -> Pet, _index: number)
		local function definition()
			return PetConfig.List[item().id]
		end
		return create "TextButton" {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = function()
				return if item().golden then Palette.RarityGold else definition().Color
			end,

			create "UICorner" { CornerRadius = UDim.new(0.15, 0) },
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = function()
					return if selected() == item().uid then 5 else 3
				end,
				Color = function()
					if selected() == item().uid then
						return Palette.White
					end
					return PetConfig.Rarities[definition().Rarity].Color
				end,
			},

			text {
				Position = UDim2.fromScale(0.05, 0.04),
				Size = UDim2.fromScale(0.9, 0.36),
				Text = function()
					return (if item().golden then "⭐ " else "") .. definition().Name
				end,
			},
			text {
				Position = UDim2.fromScale(0.05, 0.42),
				Size = UDim2.fromScale(0.9, 0.24),
				TextColor3 = function()
					return PetConfig.Rarities[definition().Rarity].Color
				end,
				Text = function()
					return PetConfig.Rarities[definition().Rarity].Name
				end,
			},
			text {
				Position = UDim2.fromScale(0.05, 0.68),
				Size = UDim2.fromScale(0.9, 0.26),
				TextColor3 = Palette.Money,
				Text = function()
					local mark = if isEquipped(item().uid) then "✔ " else ""
					return mark .. bonusText(item().id, item().golden)
				end,
			},

			Activated = function()
				confirmDelete(false)
				selected(if selected() == item().uid then nil else item().uid)
			end,
		}
	end

	return create "Frame" {
		Name = "PetsWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.72, 0.8),
		BackgroundColor3 = Palette.Panel,
		BackgroundTransparency = 0.1,
		Visible = function()
			return open() or scale() > 0.65
		end,
		ZIndex = 10,

		create "UIScale" { Scale = scale },
		create "UIAspectRatioConstraint" { AspectRatio = 1.35 },
		create "UISizeConstraint" { MaxSize = Vector2.new(920, 680) },
		create "UICorner" { CornerRadius = UDim.new(0.04, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 4 },

		-- Fejléc
		create "Frame" {
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Palette.Money,
			create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
			create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },
			text {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromScale(1.5, 1.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Text = "🐶",
			},
			text {
				Position = UDim2.fromScale(0.08, 0.12),
				Size = UDim2.fromScale(0.5, 0.76),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = function()
					return `Petek  {#pets().inventory}/{PetConfig.MaxInventory}`
				end,
			},
			button {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundColor3 = Palette.Danger,
				Text = "X",
				Activated = function()
					open(false)
				end,
			},
		},

		-- Aktív bónuszok összesítve
		text {
			Position = UDim2.fromScale(0.03, 0.12),
			Size = UDim2.fromScale(0.94, 0.06),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Lemon,
			Text = function()
				local data = pets()
				local bonus = Formulas.petBonuses({ pets = data })
				local active = `Aktív {#data.equipped}/{PetConfig.ActiveSlots}`
				local money = `Pénz {percent(bonus.Money)}`
				local bake = `Sütés {percent(bonus.BakeSpeed)}`
				local luck = `Szerencse {percent(bonus.Luck)}`
				local chef = `Chef {percent(bonus.ChefSpeed)}`
				return `{active} · {money} · {bake} · {luck} · {chef}`
			end,
		},

		-- Leltár
		create "ScrollingFrame" {
			Position = UDim2.fromScale(0.03, 0.2),
			Size = UDim2.fromScale(0.94, 0.62),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),

			create "UIGridLayout" {
				CellSize = UDim2.new(0.2, -8, 0, 96),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			create "UIPadding" { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) },

			indexes(sorted, card),
		},

		text {
			Position = UDim2.fromScale(0.03, 0.2),
			Size = UDim2.fromScale(0.94, 0.08),
			Visible = function()
				return #pets().inventory == 0
			end,
			Text = "Még nincs peted – nyiss tojást a Tojás téren (🥚)!",
		},

		-- Műveletek a kijelölt petre
		create "Frame" {
			Position = UDim2.fromScale(0.03, 0.85),
			Size = UDim2.fromScale(0.94, 0.12),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},

			button {
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.3, 1),
				BackgroundColor3 = function()
					local pet = selectedPet()
					if not pet then
						return Palette.Locked
					end
					if not isEquipped(pet.uid) and #pets().equipped >= PetConfig.ActiveSlots then
						return Palette.Locked
					end
					return Palette.Money
				end,
				Text = function()
					local pet = selectedPet()
					if not pet then
						return "Válassz petet"
					end
					if isEquipped(pet.uid) then
						return "Levesz"
					end
					return if #pets().equipped >= PetConfig.ActiveSlots then "Tele (3/3)" else "Felszerel"
				end,
				Activated = function()
					local pet = selectedPet()
					if pet then
						Remotes.PetAction:FireServer(if isEquipped(pet.uid) then "unequip" else "equip", pet.uid)
					end
				end,
			},
			button {
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.3, 1),
				BackgroundColor3 = function()
					local pet = selectedPet()
					if pet and not pet.golden and sameCount(pet) >= PetConfig.GoldenCount then
						return Palette.RarityGold
					end
					return Palette.Locked
				end,
				Text = function()
					local pet = selectedPet()
					if not pet then
						return `{PetConfig.GoldenCount} → Arany`
					end
					if pet.golden then
						return "Már arany ⭐"
					end
					return `{math.min(sameCount(pet), PetConfig.GoldenCount)}/{PetConfig.GoldenCount} → Arany`
				end,
				Activated = function()
					local pet = selectedPet()
					if pet and not pet.golden and sameCount(pet) >= PetConfig.GoldenCount then
						Remotes.PetAction:FireServer("golden", pet.id)
						selected(nil)
					end
				end,
			},
			button {
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.3, 1),
				BackgroundColor3 = function()
					return if selectedPet() then Palette.Danger else Palette.Locked
				end,
				Text = function()
					if not selectedPet() then
						return "Törlés"
					end
					return if confirmDelete() then "Biztos? Újra!" else "Törlés"
				end,
				Activated = function()
					local pet = selectedPet()
					if not pet then
						return
					end
					if confirmDelete() then
						confirmDelete(false)
						Remotes.PetAction:FireServer("delete", pet.uid)
						selected(nil)
					else
						confirmDelete(true)
						task.delay(3, function()
							confirmDelete(false)
						end)
					end
				end,
			},
		},
	}
end

-- Tojásnyitás animáció: a tojás remeg, megreped (villanás), előugrik a pet kártyája ritkaság színnel.
function PetsWindow.playEggReveal(playerGui: Instance, eggIndex: number, petId: string)
	local egg = PetConfig.Eggs[eggIndex]
	local pet = PetConfig.List[petId]
	if not egg or not pet then
		return
	end
	local rarity = PetConfig.Rarities[pet.Rarity]

	local gui = Instance.new("ScreenGui")
	gui.Name = "EggReveal"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local eggFrame = Instance.new("Frame")
	eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	eggFrame.Position = UDim2.fromScale(0.5, 0.48)
	eggFrame.Size = UDim2.fromScale(0.16, 0.2)
	eggFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	eggFrame.BackgroundColor3 = egg.Color
	local eggCorner = Instance.new("UICorner")
	eggCorner.CornerRadius = UDim.new(0.5, 0)
	eggCorner.Parent = eggFrame
	local eggStroke = Instance.new("UIStroke")
	eggStroke.Color = Palette.Stroke
	eggStroke.Thickness = 4
	eggStroke.Parent = eggFrame
	eggFrame.Parent = gui

	gui.Parent = playerGui

	-- remegés
	task.spawn(function()
		for i = 1, 12 do
			eggFrame.Rotation = (if i % 2 == 0 then 1 else -1) * (6 + i)
			task.wait(0.06)
		end
		eggFrame.Rotation = 0

		-- villanás + a pet kártyája
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = rarity.Color
		flash.BorderSizePixel = 0
		flash.Parent = gui
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		eggFrame:Destroy()

		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.48)
		card.Size = UDim2.fromScale(0.42, 0.32)
		card.BackgroundColor3 = Palette.Panel
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarity.Color
		stroke.Thickness = 5
		stroke.Parent = card
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.3
		uiScale.Parent = card

		for i, line in {
			{ pet.Name, Palette.White, 0.38 },
			{ rarity.Name, rarity.Color, 0.26 },
			{ bonusText(petId, false), Palette.Money, 0.26 },
		} do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(0.05, 0.05 + (i - 1) * 0.31)
			label.Size = UDim2.fromScale(0.9, line[3])
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = line[1]
			label.TextColor3 = line[2]
			local labelStroke = Instance.new("UIStroke")
			labelStroke.Color = Palette.Stroke
			labelStroke.Thickness = 3
			labelStroke.Parent = label
			label.Parent = card
		end
		card.Parent = gui
		TweenService:Create(uiScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()

		task.wait(2.2)
		gui:Destroy()
	end)
end

return PetsWindow
