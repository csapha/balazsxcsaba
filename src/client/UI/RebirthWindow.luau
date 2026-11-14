-- Rebirth window (GDD 3.8, 9.4). Two tabs: Rebirth (requirement, rewards, what resets / stays, the button)
-- and the Rebirth Tree (permanent perks for Rebirth Tokens).
-- The button is two-step: the first tap asks "Sure?", the second sends Remotes.RequestRebirth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source

local C = Theme.Colors
local Tree = Config.Rebirth.Tree

local RebirthWindow = {}

-- Progress towards the next rebirth (0..1).
function RebirthWindow.progress(): number
	return math.clamp(State.earned() / Formulas.rebirthRequirement(State.rebirths()), 0, 1)
end

local function ready(): boolean
	return State.earned() >= Formulas.rebirthRequirement(State.rebirths())
end

local function perkValueText(perk: string, level: number): string
	local definition = Tree.Perks[perk]
	if perk == "StartMoney" then
		return `x{NumberFormat.short(definition.Step ^ level)}`
	elseif perk == "Money" or perk == "OfflineRate" then
		return `+{math.floor(definition.Step * level * 100 + 0.5)}%`
	elseif perk == "OfflineTime" then
		return `+{math.floor(definition.Step * level / 3600)}h`
	end
	return `+{definition.Step * level}`
end

-- The rewards of the next rebirth: { icon, text }.
local function rewards(rebirths: number): { { icon: string, text: string } }
	local upcoming = rebirths + 1
	local list = {
		{
			icon = Ui.Icons.RebirthCash,
			text = `x{Formulas.rebirthMultiplier(upcoming)} money (now x{Formulas.rebirthMultiplier(rebirths)})`,
		},
		{ icon = Ui.Icons.Star, text = `+{Config.Rebirth.TokensPerRebirth} Rebirth Token` },
	}
	local slotsNow, slotsNext = Formulas.rebirthSlots(rebirths), Formulas.rebirthSlots(upcoming)
	if slotsNext > slotsNow then
		table.insert(list, { icon = Ui.Icons.Upgrade, text = `+{slotsNext - slotsNow} oven slots ({slotsNow} → {slotsNext})` })
	end
	local chefsNow, chefsNext = Formulas.maxChefs(rebirths), Formulas.maxChefs(upcoming)
	if chefsNext > chefsNow then
		table.insert(list, { icon = Ui.Icons.Friends, text = `+{chefsNext - chefsNow} max chef` })
	end
	local soon = Config.Rebirth.ComingSoon[upcoming]
		or (if upcoming % Config.Rebirth.WorldEvery == 0 then "New world" else nil)
	if soon then
		table.insert(list, { icon = Ui.Icons.Crown, text = `{soon} (coming soon)` })
	end
	return list
end

local function rewardRow(index: number): Frame
	local function entry()
		return rewards(State.rebirths())[index]
	end
	return create "Frame" {
		Name = "Reward" .. index,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Visible = function()
			return entry() ~= nil
		end,
		create "ImageLabel" {
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			Image = function()
				local e = entry()
				return if e then e.icon else ""
			end,
			ScaleType = Enum.ScaleType.Fit,
		},
		Kit.text {
			Text = function()
				local e = entry()
				return if e then e.text else ""
			end,
			TextSize = 20,
			TextColor3 = C.Good,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -38, 1, 0),
		},
	} :: Frame
end

local function infoLine(order: number, label: string, text: string | () -> string, color: Color3): Frame
	return Kit.darkBox {
		Name = label,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		Corner = 0,
		-- the padding sits on an inner frame: on the box itself it would also shift the box's inner ring
		create "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
			create "UIPadding" { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) },
			Kit.text {
				RichText = true,
				Text = function()
					local value = if type(text) == "function" then text() else text
					return `<font color="#{color:ToHex()}">{label}:</font> {value}`
				end,
				TextSize = 17,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
		},
	} :: Frame
end

local function rebirthPage(visible: () -> boolean, anim: Motion.Anim): Frame
	local confirming = source(false)
	Vide.effect(function()
		if not anim.opened() then
			confirming(false)
		end
	end)
	local rows = {}
	for i = 1, 5 do
		table.insert(rows, rewardRow(i))
	end
	return create "Frame" {
		Name = "RebirthPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		-- requirement
		Kit.text {
			Name = "Requirement",
			Text = "Earn money this run",
			TextSize = 20,
			TextColor3 = C.Muted,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 22),
		},
		Kit.bar {
			Name = "Progress",
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 30),
			Palette = function()
				return if ready() then "Green" else "Yellow"
			end,
			Label = function()
				return `{NumberFormat.money(State.earned())} / {NumberFormat.money(Formulas.rebirthRequirement(State.rebirths()))}`
			end,
			Right = function()
				return `{math.floor(RebirthWindow.progress() * 100)}%`
			end,
			Value = RebirthWindow.progress,
		},
		-- rewards
		Kit.darkBox {
			Name = "Rewards",
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(0.5, -6, 1, -66 - 70),
			Line = C.CardSelectedLine,
			create "Frame" {
				Name = "List",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 3,
				create "UIPadding" {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 8),
				},
				create "UIListLayout" { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder },
				Kit.text {
				LayoutOrder = 0,
				Text = "REWARDS",
				TextSize = 22,
				TextColor3 = C.Lemon,
				Gradient = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 26),
				},
				rows,
			},
		},
		-- what resets / what stays
		create "Frame" {
			Name = "Rules",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 66),
			Size = UDim2.new(0.5, -6, 1, -66 - 70),
			BackgroundTransparency = 1,
			create "UIListLayout" { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
			infoLine(1, "Resets", "money, ovens, generation", C.Bad),
			infoLine(2, "Resets", "chefs, sell speed, counter level", C.Bad),
			infoLine(3, "Keeps", function()
				return `tokens ({State.tokens()}), slots, pets, auras`
			end, C.Good),
			infoLine(4, "Keeps", "Index, rebirth tree perks", C.Good),
		},
		Kit.button {
			Name = "RebirthButton",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.fromOffset(320, 56),
			TextSize = 28,
			Color = function()
				if not ready() then
					return "Gray"
				end
				return if confirming() then "Red" else "Green"
			end,
			Text = function()
				if not ready() then
					local missing = Formulas.rebirthRequirement(State.rebirths()) - State.earned()
					return `{NumberFormat.money(missing)} more`
				end
				return if confirming() then "Sure? Tap again!" else "REBIRTH!"
			end,
			Activated = function()
				if not ready() then
					Audio.play("Error")
					return
				end
				if confirming() then
					confirming(false)
					State.close()
					Remotes.RequestRebirth:FireServer()
				else
					confirming(true)
					task.delay(3, function()
						confirming(false)
					end)
				end
			end,
		},
	} :: Frame
end

local function perkRow(order: number, perk: string): Frame
	local definition = Tree.Perks[perk]
	local function level(): number
		return State.perks()[perk] or 0
	end
	local function maxed(): boolean
		return level() >= definition.Max
	end
	local function canBuy(): boolean
		return not maxed() and State.tokens() >= Tree.TokenCost
	end
	local pips = {}
	for i = 1, definition.Max do
		table.insert(pips, create "Frame" {
			Name = "Pip" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = function()
				return if level() >= i then C.Lemon else C.Ink
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			Kit.outline(nil, 2),
		})
	end
	return Kit.darkBox {
		Name = perk,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 62),
		Line = function()
			return if canBuy() then C.CardSelectedLine else C.CardLine
		end,
		Kit.text {
			Name = "Title",
			Text = definition.Name,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.4, 0, 0, 26),
		},
		create "Frame" {
			Name = "Pips",
			Position = UDim2.new(0.4, 0, 0, 12),
			Size = UDim2.fromOffset(120, 14),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			pips,
		},
		Kit.text {
			Name = "Effect",
			RichText = true,
			Text = function()
				local now = perkValueText(perk, level())
				if maxed() then
					return `{definition.Description}  <font color="#5EEB5B">{now} (MAX)</font>`
				end
				return `{definition.Description}  <font color="#5EEB5B">{now} » {perkValueText(perk, level() + 1)}</font>`
			end,
			TextSize = 16,
			TextColor3 = C.Muted,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -190, 0, 20),
		},
		Kit.button {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -1),
			Size = UDim2.fromOffset(150, 42),
			TextSize = 19,
			Color = function()
				if maxed() then
					return "Gray"
				end
				return if canBuy() then "Yellow" else "Gray"
			end,
			Text = function()
				if maxed() then
					return "MAX"
				end
				return `{Tree.TokenCost} token{if Tree.TokenCost == 1 then "" else "s"}`
			end,
			Activated = function()
				if canBuy() then
					Audio.play("Chime")
					Remotes.BuyPerk:FireServer(perk)
				else
					Audio.play("Error")
				end
			end,
		},
	} :: Frame
end

local function treePage(visible: () -> boolean): Frame
	local rows = {}
	for order, perk in Tree.Order do
		table.insert(rows, perkRow(order, perk))
	end
	return create "Frame" {
		Name = "TreePage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		Kit.text {
			Name = "Tokens",
			Text = function()
				return `Rebirth Tokens: {State.tokens()}`
			end,
			TextSize = 22,
			TextColor3 = C.Lemon,
			Gradient = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 26),
		},
		create "ScrollingFrame" {
			Name = "Perks",
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 1, -32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = C.PanelLine,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			create "UIListLayout" { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
			create "UIPadding" { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6) },
			rows,
		},
	} :: Frame
end

function RebirthWindow.render(anim: Motion.Anim)
	local tab = source("Rebirth")
	local function tabButton(order: number, name: string, icon: string)
		return Kit.button {
			Name = name,
			LayoutOrder = order,
			Icon = icon,
			IconSize = 0.85,
			Color = "Green",
			Shine = false,
			Size = UDim2.fromOffset(60, 60),
			Selected = function()
				return tab() == name
			end,
			Activated = function()
				tab(name)
			end,
		}
	end
	return Kit.window {
		Name = "Rebirth",
		Title = function()
			return if tab() == "Tree" then "Rebirth Tree" else `Rebirth #{State.rebirths() + 1}`
		end,
		Color = "Green",
		Icon = Ui.Icons.Rebirth,
		Size = function()
			return UDim2.fromOffset(Kit.WindowWidth, Kit.windowHeight(480))
		end,
		Anim = anim,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = {
			tabButton(1, "Rebirth", Ui.Icons.Rebirth),
			tabButton(2, "Tree", Ui.Icons.Upgrade),
		},
		Body = {
			rebirthPage(function()
				return tab() == "Rebirth"
			end, anim),
			treePage(function()
				return tab() == "Tree"
			end),
		},
	}
end

return RebirthWindow
