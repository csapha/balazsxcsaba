-- HUD (GDD 9.3, mobile-first), built on the shared UI Kit (same look as the Snowboard game):
--   left: menu buttons in a 2 × 2 grid (Rebirth %, Index, Pets, Auras)
--   top: navigation (My Plot / Eggs) + event timer
--   bottom left: money, the schnitzel you are carrying (and its worth), rebirth multiplier and tokens
-- Windows open one at a time (State.window) through AnimatedWindow.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local EventState = require(Shared.EventState)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Teleport = require(script.Parent.Parent.Util.Teleport)

local AnimatedWindow = require(script.Parent.AnimatedWindow)
local AurasWindow = require(script.Parent.AurasWindow)
local Effects = require(script.Parent.Effects)
local IndexWindow = require(script.Parent.IndexWindow)
local Kit = require(script.Parent.Kit)
local OfflineWindow = require(script.Parent.OfflineWindow)
local PetsWindow = require(script.Parent.PetsWindow)
local RebirthWindow = require(script.Parent.RebirthWindow)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local C = Theme.Colors

local MONEY_GRADIENT = ColorSequence.new(C.MoneyTop, C.MoneyBottom)
local GOLD_TOP = Color3.fromHex("FFF38A")
local GOLD_BOTTOM = Color3.fromHex("F4A91C")
local GOLD_STROKE = Color3.fromHex("4A2A06")

local Hud = {}

-- Keeps a State source in sync with a replicated data value.
local function bind(target: (any) -> (), value: any)
	target(value())
	value.Changed(function(new)
		target(new)
	end)
end

local function serverClock(): () -> number
	local clock = source(workspace:GetServerTimeNow())
	local running = true
	task.spawn(function()
		while running do
			clock(workspace:GetServerTimeNow())
			task.wait(0.25)
		end
	end)
	Vide.cleanup(function()
		running = false
	end)
	return clock
end

local function menuButton(order: number, name: string, text: string | () -> string, icon: string, color: string)
	return Kit.button {
		Name = name,
		LayoutOrder = order,
		Text = text,
		TextSize = 15,
		Icon = icon,
		IconSize = 0.9,
		Color = color,
		Size = UDim2.fromOffset(74, 74),
		Activated = function()
			State.toggle(name)
		end,
	}
end

local function leftMenu(): Frame
	return create "Frame" {
		Name = "LeftMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = function()
			return UDim2.new(0, 14 - Kit.sideSlack("Left"), 0.5, -30)
		end,
		Size = UDim2.fromOffset(74 * 2 + 14, 74 * 2 + 22),
		BackgroundTransparency = 1,
		Kit.scale(),
		-- 2 × 2 grid (the labels hang below each button, hence the larger vertical gap)
		create "UIGridLayout" {
			CellSize = UDim2.fromOffset(74, 74),
			CellPadding = UDim2.fromOffset(14, 22),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		menuButton(1, "Rebirth", function()
			return `Rebirth {math.floor(RebirthWindow.progress() * 100)}%`
		end, Ui.Icons.Rebirth, "Green"),
		menuButton(2, "Index", "Index", Ui.Icons.Index, "Yellow"),
		menuButton(3, "Pets", "Pets", Ui.Icons.Pets, "Blue"),
		menuButton(4, "Auras", "Auras", Ui.Icons.Crystal, "Purple"),
	} :: Frame
end

-- A wide button with the icon on the left of the label.
local function navButton(order: number, name: string, text: string, icon: string, color: string, onClick: () -> ())
	return Kit.button {
		Name = name,
		LayoutOrder = order,
		Text = text,
		TextSize = 24,
		TextNudge = 18,
		Color = color,
		Size = UDim2.fromOffset(170, 50),
		Activated = onClick,
		create "ImageLabel" {
			Name = "NavIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 26, 0.5, -3),
			Size = UDim2.fromOffset(44, 44),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = -6,
			ZIndex = 6,
		},
	}
end

local function topBar(clock: () -> number): Frame
	local function eventSeconds(): number
		local now = clock()
		local config = EventState.config()
		local target = if config then EventState.endsAt() else EventState.nextAt()
		return math.max(0, math.ceil(target - now))
	end
	return create "Frame" {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = function()
			return UDim2.new(0.5, 0, 0, Kit.topbarCenter() - 25)
		end,
		Size = UDim2.fromOffset(380, 92),
		BackgroundTransparency = 1,
		Kit.scale(),
		create "Frame" {
			Name = "Nav",
			Size = UDim2.new(1, 0, 0, 54),
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			navButton(1, "Home", "My Plot", Ui.Icons.Home, "Orange", Teleport.home),
			navButton(2, "Eggs", "Eggs", Ui.Icons.Egg, "Pink", Teleport.eggs),
		},
		-- GDD 3.12: "Next event: 05:39" / the running event's countdown
		create "Frame" {
			Name = "EventTimer",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 60),
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			create "ImageLabel" {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(28, 28),
				BackgroundTransparency = 1,
				Image = Ui.Icons.Clock,
				ScaleType = Enum.ScaleType.Fit,
			},
			Kit.text {
				LayoutOrder = 2,
				Text = function()
					local seconds = eventSeconds()
					local timer = string.format("%d:%02d", seconds // 60, seconds % 60)
					local config = EventState.config()
					if config then
						return `{config.Name}  {timer}`
					end
					return `Next event: {timer}`
				end,
				TextColor3 = function()
					clock()
					local config = EventState.config()
					return if config then config.Color else C.White
				end,
				Gradient = false,
				TextSize = 22,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
			},
		},
	} :: Frame
end

-- Bottom left, one place for the numbers: money, the schnitzel you carry (and its worth), rebirth bonus.
local function stats(): Frame
	local shownMoney = spring(State.money, 0.35, 1)
	local bump = source(0)
	local last = Vide.untrack(State.carried)
	Vide.effect(function()
		local now = State.carried()
		if now > last then
			bump(1)
			task.delay(0.06, bump, 0)
		end
		last = now
	end)
	local pop = spring(function()
		return if bump() > 0 then 1.12 else 1
	end, 0.25, 0.5)
	local function rebirthShown(): boolean
		return State.rebirths() > 0 or State.tokens() > 0
	end
	return create "Frame" {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = function()
			return UDim2.new(0, 16 - Kit.sideSlack("Left"), 1, -14)
		end,
		Size = UDim2.fromOffset(400, 140),
		BackgroundTransparency = 1,
		Kit.scale(),
		create "Frame" {
			Name = "Rows",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			create "UIListLayout" {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			},
			create "Frame" {
				Name = "MoneyRow",
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 48),
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "ImageLabel" {
					Name = "MoneyIcon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(50, 50),
					BackgroundTransparency = 1,
					Image = Ui.Icons.Coin,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
				},
				Kit.text {
					Name = "Money",
					Text = function()
						-- the spring runs in float32: snap to the exact value when it is close
						local target = State.money()
						local shown = shownMoney()
						if math.abs(shown - target) <= math.max(1, math.abs(target) * 1e-4) then
							shown = target
						end
						return NumberFormat.money(shown)
					end,
					TextSize = 44,
					StrokeThickness = 4,
					StrokeColor = C.MoneyStroke,
					Gradient = MONEY_GRADIENT,
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 48),
					ZIndex = 2,
				},
			},
			create "Frame" {
				Name = "SchnitzelRow",
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 44),
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "TextLabel" {
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(44, 40),
					BackgroundTransparency = 1,
					Text = "🥩",
					TextScaled = true,
					Rotation = -10,
					create "UIScale" { Scale = pop },
				},
				Kit.text {
					Name = "Count",
					LayoutOrder = 2,
					Text = function()
						return NumberFormat.grouped(State.carried())
					end,
					TextSize = 36,
					StrokeThickness = 3.5,
					Gradient = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM),
					StrokeColor = GOLD_STROKE,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 42),
					create "UIScale" { Scale = pop },
				},
				Kit.text {
					Name = "Value",
					LayoutOrder = 3,
					Text = function()
						return `worth {NumberFormat.money(State.carriedValue())}`
					end,
					TextSize = 20,
					TextColor3 = C.Money,
					Gradient = false,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 26),
				},
			},
			create "Frame" {
				Name = "RebirthRow",
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 3,
				Size = UDim2.fromOffset(0, 30),
				BackgroundTransparency = 1,
				Visible = rebirthShown,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				create "ImageLabel" {
					Name = "RebirthIcon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(30, 30),
					BackgroundTransparency = 1,
					Image = Ui.Icons.Rebirth,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
				},
				Kit.text {
					Name = "Rebirth",
					Text = function()
						local tokens = State.tokens()
						return `x{Formulas.rebirthMultiplier(State.rebirths())} money, {tokens} token{if tokens
								== 1
							then("")
							else("s")}`
					end,
					TextSize = 22,
					TextColor3 = C.Lemon,
					Gradient = false,
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 30),
					ZIndex = 2,
				},
			},
		},
	} :: Frame
end

local function hasOffline(): boolean
	return State.offline().pending > 0
end

function Hud.mount(data: any)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	State.data = data
	bind(State.money, data.money)
	bind(State.carried, data.carried)
	bind(State.carriedValue, data.carriedValue)
	bind(State.earned, data.cycleEarned)
	bind(State.rebirths, data.rebirths)
	bind(State.tokens, data.rebirthTokens)
	bind(State.perks, data.rebirthPerks)
	bind(State.pets, data.pets)
	bind(State.auras, data.auras)
	bind(State.offline, data.offline)

	Remotes.Rebirthed.OnClientEvent:Connect(function(rebirths: number, multiplier: number)
		Effects.rebirth(playerGui, rebirths, multiplier)
	end)
	Remotes.EggOpened.OnClientEvent:Connect(function(eggIndex: number, petId: string)
		Effects.eggReveal(playerGui, eggIndex, petId)
	end)
	Remotes.AuraRolled.OnClientEvent:Connect(function(id: string, level: number, isNew: boolean)
		Effects.auraRoll(playerGui, id, level, isNew)
	end)

	-- GDD 9.4: blurred background while a window is open
	local blur = Instance.new("BlurEffect")
	blur.Name = "WindowBlur"
	blur.Size = 0
	blur.Parent = Lighting

	Vide.mount(function()
		local clock = serverClock()
		Vide.effect(function()
			blur.Size = if State.window() ~= nil or hasOffline() then 10 else 0
		end)
		return create "ScreenGui" {
			Name = "GameUi",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			create "Frame" {
				Name = "Hud",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				leftMenu(),
				topBar(clock),
				stats(),
			},
			AnimatedWindow("Rebirth", RebirthWindow.render, nil, true),
			AnimatedWindow("Index", IndexWindow.render, nil, true),
			AnimatedWindow("Pets", PetsWindow.render, nil, true),
			AnimatedWindow("Auras", AurasWindow.render, nil, true),
			AnimatedWindow(hasOffline, OfflineWindow.render),
		}
	end, playerGui)

	-- Studio testing: set the player's "UiWindow" attribute (e.g. from the command bar) to open a window.
	if game:GetService("RunService"):IsStudio() then
		local player = Players.LocalPlayer
		player:GetAttributeChangedSignal("UiWindow"):Connect(function()
			local name = player:GetAttribute("UiWindow")
			State.window(if type(name) == "string" and name ~= "" then name else nil)
		end)
	end

	local gameUi = playerGui:WaitForChild("GameUi") :: ScreenGui
	local function track()
		Kit.guiOrigin(gameUi.AbsolutePosition)
		Kit.guiSize(gameUi.AbsoluteSize)
	end
	gameUi:GetPropertyChangedSignal("AbsolutePosition"):Connect(track)
	gameUi:GetPropertyChangedSignal("AbsoluteSize"):Connect(track)
	track()
end

return Hud
