-- Pets window (GDD 3.9, 9.4): active bonuses, the inventory grid, and the selected pet's actions:
--   Equip / Unequip, "5 → Golden", Delete (two-step confirmation).
-- Layout follows the Snowboard Gear Shop: detail panel on the left, card grid on the right.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local derive = Vide.derive
local indexes = Vide.indexes

local C = Theme.Colors
local PetConfig = Config.Pets

local LEFT_W = 250
local GAP = 12
local CARD_W = 108
local CARD_H = 128

local PetsWindow = {}

local function percent(value: number): string
	return `+{math.floor(value * 100 + 0.5)}%`
end

function PetsWindow.bonusText(id: string, golden: boolean): string
	local definition = PetConfig.List[id]
	return `{percent(Formulas.petBonusValue(id, golden))} {PetConfig.Bonuses[definition.Bonus]}`
end

local function rarityOf(id: string)
	return PetConfig.Rarities[PetConfig.List[id].Rarity]
end

local function spinForever(instance: GuiObject, seconds: number): GuiObject
	local tween = TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = instance.Rotation + 360,
	})
	tween:Play()
	Vide.cleanup(function()
		tween:Cancel()
	end)
	return instance
end

-- Placeholder pet portrait (until the pet models get icons): a round body in the pet's colour with eyes.
function PetsWindow.avatar(color: Color3 | () -> Color3, props: { [any]: any }): Frame
	local function eye(x: number)
		return create "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.42),
			Size = UDim2.fromScale(0.13, 0.17),
			BackgroundColor3 = C.Ink,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			create "Frame" {
				Position = UDim2.fromScale(0.25, 0.15),
				Size = UDim2.fromScale(0.4, 0.3),
				BackgroundColor3 = C.White,
				create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			},
		}
	end
	return create "Frame" {
		Name = "Avatar",
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = color,
		create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
		Kit.outline(),
		create "UIGradient" {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		},
		eye(0.36),
		eye(0.64),
		create "Frame" {
			Name = "Mouth",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.64),
			Size = UDim2.fromScale(0.18, 0.08),
			BackgroundColor3 = C.Ink,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
		},
		props,
	} :: Frame
end

local function isEquipped(uid: number): boolean
	return table.find(State.pets().equipped, uid) ~= nil
end

local function sameCount(pet: State.Pet): number
	local count = 0
	for _, other in State.pets().inventory do
		if other.id == pet.id and not other.golden then
			count += 1
		end
	end
	return count
end

local function detail(selectedPet: () -> State.Pet?, selected: (number?) -> number?, appear: () -> number): Frame
	local confirmDelete = source(false)
	Vide.effect(function()
		selectedPet()
		confirmDelete(false)
	end)
	local burstLayer = create "Frame" {
		Name = "Burst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	} :: Frame
	local function color(): Color3
		local pet = selectedPet()
		if not pet then
			return C.CardLine
		end
		return if pet.golden then Config.Palette.RarityGold else rarityOf(pet.id).Color
	end
	local function full(): boolean
		return #State.pets().equipped >= PetConfig.ActiveSlots
	end
	return Kit.darkBox {
		Name = "Detail",
		Size = UDim2.new(0, LEFT_W, 1, 0),
		Line = color,
		create "UIScale" {
			Scale = function()
				return math.max(0, appear())
			end,
		},
		burstLayer,
		create "Frame" {
			Name = "Stage",
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			spinForever(create "ImageLabel" {
				Name = "Sunburst",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(240, 240),
				BackgroundTransparency = 1,
				Image = Ui.Textures.Sunburst,
				ImageColor3 = color,
				ImageTransparency = 0.7,
			} :: ImageLabel, 26),
			PetsWindow.avatar(function()
				local pet = selectedPet()
				return if pet then PetConfig.List[pet.id].Color else C.Slot
			end, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromScale(0.62, 0.62),
				Visible = function()
					return selectedPet() ~= nil
				end,
				ZIndex = 2,
			}),
			Kit.text {
				Name = "Empty",
				Text = "Pick a pet",
				TextSize = 22,
				TextColor3 = C.Muted,
				Gradient = false,
				Visible = function()
					return selectedPet() == nil
				end,
			},
		},
		create "Frame" {
			Name = "Info",
			Position = UDim2.fromOffset(0, 150),
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundTransparency = 1,
			create "UIPadding" { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
			create "UIListLayout" { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder },
			Kit.text {
				LayoutOrder = 1,
				Text = function()
					local pet = selectedPet()
					if not pet then
						return ""
					end
					return (if pet.golden then "Golden " else "") .. PetConfig.List[pet.id].Name
				end,
				TextSize = 22,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 26),
				create "UITextSizeConstraint" { MaxTextSize = 22 },
			},
			Kit.text {
				LayoutOrder = 2,
				Text = function()
					local pet = selectedPet()
					return if pet then string.upper(rarityOf(pet.id).Name) else ""
				end,
				TextSize = 16,
				TextColor3 = color,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 18),
			},
			Kit.text {
				LayoutOrder = 3,
				Text = function()
					local pet = selectedPet()
					return if pet then PetsWindow.bonusText(pet.id, pet.golden) else ""
				end,
				TextSize = 20,
				TextColor3 = C.Good,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 22),
			},
		},
		create "Frame" {
			Name = "Actions",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -24, 0, 44 * 3 + 16),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			},
			Kit.button {
				Name = "Equip",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 44),
				TextSize = 22,
				Color = function()
					local pet = selectedPet()
					if not pet then
						return "Gray"
					end
					if isEquipped(pet.uid) then
						return "Blue"
					end
					return if full() then "Gray" else "Green"
				end,
				Text = function()
					local pet = selectedPet()
					if pet and isEquipped(pet.uid) then
						return "UNEQUIP"
					end
					return if full() then `FULL ({PetConfig.ActiveSlots}/{PetConfig.ActiveSlots})` else "EQUIP"
				end,
				Activated = function()
					local pet = selectedPet()
					if not pet then
						return
					end
					local equipped = isEquipped(pet.uid)
					if not equipped and full() then
						Audio.play("Error")
						return
					end
					if not equipped then
						Audio.play("Chime")
						Kit.burst(burstLayer, UDim2.new(0.5, 0, 0, 82), color(), 12, 1)
					end
					Remotes.PetAction:FireServer(if equipped then "unequip" else "equip", pet.uid)
				end,
			},
			Kit.button {
				Name = "Golden",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 44),
				TextSize = 20,
				Color = function()
					local pet = selectedPet()
					return if pet and not pet.golden and sameCount(pet) >= PetConfig.GoldenCount then "Yellow" else "Gray"
				end,
				Text = function()
					local pet = selectedPet()
					if not pet then
						return `{PetConfig.GoldenCount} → GOLDEN`
					end
					if pet.golden then
						return "ALREADY GOLDEN"
					end
					return `{math.min(sameCount(pet), PetConfig.GoldenCount)}/{PetConfig.GoldenCount} → GOLDEN`
				end,
				Activated = function()
					local pet = selectedPet()
					if pet and not pet.golden and sameCount(pet) >= PetConfig.GoldenCount then
						Audio.play("Golden")
						Remotes.PetAction:FireServer("golden", pet.id)
						selected(nil)
					else
						Audio.play("Error")
					end
				end,
			},
			Kit.button {
				Name = "Delete",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 44),
				TextSize = 20,
				Color = function()
					return if selectedPet() then "Red" else "Gray"
				end,
				Text = function()
					return if confirmDelete() then "SURE? TAP AGAIN" else "DELETE"
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
	} :: Frame
end

local function card(item: () -> State.Pet, selected: (number?) -> number?): Frame
	local function definition()
		return PetConfig.List[item().id]
	end
	local function color(): Color3
		return if item().golden then Config.Palette.RarityGold else rarityOf(item().id).Color
	end
	return Kit.darkBox {
		Name = "Pet",
		Line = function()
			return if selected() == item().uid then C.White else color()
		end,
		Fill = function()
			return if isEquipped(item().uid) then C.CardSelected else C.Card
		end,
		create "ImageButton" {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
			Activated = function()
				Audio.play("Click")
				selected(if selected() == item().uid then nil else item().uid)
			end,
		},
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 44),
			Size = UDim2.fromOffset(100, 70),
			BackgroundTransparency = 1,
			Image = Ui.Textures.Soft,
			ImageColor3 = color,
			ImageTransparency = 0.65,
		},
		PetsWindow.avatar(function()
			return definition().Color
		end, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(62, 62),
			ZIndex = 2,
		}),
		create "ImageLabel" {
			Name = "Equipped",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Image = Ui.Icons.Check,
			ScaleType = Enum.ScaleType.Fit,
			Visible = function()
				return isEquipped(item().uid)
			end,
			ZIndex = 4,
		},
		create "ImageLabel" {
			Name = "GoldenStar",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Image = Ui.Icons.Star,
			ScaleType = Enum.ScaleType.Fit,
			Visible = function()
				return item().golden
			end,
			ZIndex = 4,
		},
		Kit.text {
			Name = "Name",
			Text = function()
				return definition().Name
			end,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(4, 78),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 3,
		},
		Kit.text {
			Name = "Bonus",
			Text = function()
				return PetsWindow.bonusText(item().id, item().golden)
			end,
			TextSize = 13,
			TextColor3 = C.Good,
			Gradient = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 4, 1, -8),
			Size = UDim2.new(1, -8, 0, 16),
			ZIndex = 3,
		},
	} :: Frame
end

function PetsWindow.render(anim: Motion.Anim)
	local selected = source(nil :: number?)

	-- inventory: equipped first, then golden, then by rarity
	local sorted = derive(function()
		local data = State.pets()
		local list = table.clone(data.inventory)
		local equipped = data.equipped
		table.sort(list, function(a, b)
			local ae, be = table.find(equipped, a.uid) ~= nil, table.find(equipped, b.uid) ~= nil
			if ae ~= be then
				return ae
			end
			if a.golden ~= b.golden then
				return a.golden
			end
			local ar, br = rarityOf(a.id).Order, rarityOf(b.id).Order
			if ar ~= br then
				return ar > br
			end
			return a.uid < b.uid
		end)
		return list
	end)

	local selectedPet = derive(function(): State.Pet?
		local uid = selected()
		if not uid then
			return nil
		end
		for _, pet in State.pets().inventory do
			if pet.uid == uid then
				return pet
			end
		end
		return nil
	end)

	return Kit.window {
		Name = "Pets",
		Title = "Pets",
		Count = function()
			return `{#State.pets().inventory}/{PetConfig.MaxInventory}`
		end,
		Color = "Blue",
		Icon = Ui.Icons.Pets,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(500))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Body = {
			detail(selectedPet, selected, anim.appear(0.12, 0, Enum.EasingStyle.Back, 0.45)),
			Kit.text {
				Name = "Bonuses",
				RichText = true,
				Text = function()
					local data = State.pets()
					local bonus = Formulas.petBonuses({ pets = data })
					return `Active {#data.equipped}/{PetConfig.ActiveSlots}   `
						.. `<font color="#8BFF3D">Money {percent(bonus.Money)}</font>   `
						.. `<font color="#FFE066">Baking {percent(bonus.BakeSpeed)}</font>   `
						.. `<font color="#7FE0C4">Luck {percent(bonus.Luck)}</font>   `
						.. `<font color="#8AF9FF">Chefs {percent(bonus.ChefSpeed)}</font>`
				end,
				TextSize = 18,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(LEFT_W + GAP, 0),
				Size = UDim2.new(1, -(LEFT_W + GAP), 0, 26),
			},
			create "ScrollingFrame" {
				Name = "Grid",
				Position = UDim2.fromOffset(LEFT_W + GAP, 34),
				Size = UDim2.new(1, -(LEFT_W + GAP), 1, -34),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = C.PanelLine,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				create "UIGridLayout" {
					CellSize = UDim2.fromOffset(CARD_W, CARD_H),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "UIPadding" {
					PaddingTop = UDim.new(0, 3),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 3),
					PaddingRight = UDim.new(0, 12),
				},
				indexes(sorted, function(item)
					return card(item, selected)
				end),
			},
			Kit.text {
				Name = "Empty",
				Text = "No pets yet! Open an egg at the Egg Plaza.",
				TextSize = 22,
				TextColor3 = C.Muted,
				Gradient = false,
				TextWrapped = true,
				Visible = function()
					return #State.pets().inventory == 0
				end,
				Position = UDim2.new(0, LEFT_W + GAP, 0.4, 0),
				Size = UDim2.new(1, -(LEFT_W + GAP), 0, 60),
			},
		},
	}
end

return PetsWindow
