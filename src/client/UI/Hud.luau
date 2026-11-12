-- HUD (GDD 9.3, mobile-first):
--   bal alul: pénz (felpörgő számláló, GDD 4.5)
--   lent középen: a játékosnál lévő schnitzel darab (legfontosabb szám)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.Vide)
local Config = require(ReplicatedStorage.Shared.Config)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EventState = require(ReplicatedStorage.Shared.EventState)
local IndexWindow = require(script.Parent.IndexWindow)
local RebirthWindow = require(script.Parent.RebirthWindow)
local PetsWindow = require(script.Parent.PetsWindow)
local AurasWindow = require(script.Parent.AurasWindow)
local OfflineWindow = require(script.Parent.OfflineWindow)
local Teleport = require(script.Parent.Parent.Util.Teleport)

local create = vide.create
local source = vide.source
local spring = vide.spring

local Palette = Config.Palette

local Hud = {}

-- Vastag, kerekített "cartoon chunky" felirat (GDD 9.1): fehér/színes szöveg sötét körvonallal.
local function chunkyLabel(props: { [any]: any })
	return create "TextLabel" {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Palette.White,

		create "UIStroke" {
			Color = Palette.Stroke,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		},

		props,
	}
end

-- Bal oldali menügomb (GDD 9.3: ikonos, nagy, mobilon min. ~70 px).
local function menuButton(order: number, icon: string, title: string | () -> string, onClick: () -> ())
	return create "TextButton" {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = Palette.Gold,
		AutoButtonColor = true,
		Text = "",

		create "UICorner" { CornerRadius = UDim.new(0.25, 0) },
		create "UIStroke" {
			Color = Palette.Stroke,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},

		chunkyLabel {
			Position = UDim2.fromScale(0.1, 0.05),
			Size = UDim2.fromScale(0.8, 0.6),
			Text = icon,
		},
		chunkyLabel {
			Position = UDim2.fromScale(0.05, 0.64),
			Size = UDim2.fromScale(0.9, 0.3),
			Text = title,
		},

		Activated = onClick,
	}
end

-- Fenti navigációs gomb (teleport).
local function navButton(label: string, color: Color3, onClick: () -> ())
	return create "TextButton" {
		Size = UDim2.fromOffset(160, 52),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
		create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
		create "UIStroke" { Color = Palette.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		chunkyLabel {
			Position = UDim2.fromScale(0.06, 0.15),
			Size = UDim2.fromScale(0.88, 0.7),
			Text = label,
		},
		Activated = onClick,
	}
end

function Hud.mount(data: any)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local money = source(data.money() :: number)
	local carried = source(data.carried() :: number)
	local carriedValue = source(data.carriedValue() :: number)
	data.money.Changed(function(value: number)
		money(value)
	end)
	data.carried.Changed(function(value: number)
		carried(value)
	end)
	data.carriedValue.Changed(function(value: number)
		carriedValue(value)
	end)

	-- Rebirth (GDD 3.8): haladás, rebirthek száma, tokenek
	local rebirthState: RebirthWindow.State = {
		earned = source(data.cycleEarned() :: number),
		rebirths = source(data.rebirths() :: number),
		tokens = source(data.rebirthTokens() :: number),
		perks = source(data.rebirthPerks()),
	}
	data.rebirthPerks.Changed(function(value)
		rebirthState.perks(value)
	end)

	-- Offline kereset (GDD 3.13)
	local offline = source(data.offline())
	data.offline.Changed(function(value)
		offline(value)
	end)
	data.cycleEarned.Changed(function(value: number)
		rebirthState.earned(value)
	end)
	data.rebirths.Changed(function(value: number)
		rebirthState.rebirths(value)
	end)
	data.rebirthTokens.Changed(function(value: number)
		rebirthState.tokens(value)
	end)
	Remotes.Rebirthed.OnClientEvent:Connect(function(rebirths: number, multiplier: number)
		RebirthWindow.playEffect(playerGui, rebirths, multiplier)
	end)

	-- Petek (GDD 3.9)
	local pets = source(data.pets())
	data.pets.Changed(function(value)
		pets(value)
	end)
	Remotes.EggOpened.OnClientEvent:Connect(function(eggIndex: number, petId: string)
		PetsWindow.playEggReveal(playerGui, eggIndex, petId)
	end)

	-- Aurák (GDD 3.10)
	local auras = source(data.auras())
	data.auras.Changed(function(value)
		auras(value)
	end)
	Remotes.AuraRolled.OnClientEvent:Connect(function(id: string, level: number, isNew: boolean)
		AurasWindow.playRoll(playerGui, id, level, isNew)
	end)

	vide.mount(function()
		local shownMoney = spring(money, 0.35, 1)
		local indexOpen = source(false)
		local rebirthOpen = source(false)
		local petsOpen = source(false)
		local aurasOpen = source(false)

		-- szerveridő óra az event időzítőhöz (fél mp-enként frissül)
		local clock = source(workspace:GetServerTimeNow())
		local ticking = true
		task.spawn(function()
			while ticking do
				clock(workspace:GetServerTimeNow())
				task.wait(0.5)
			end
		end)
		vide.cleanup(function()
			ticking = false
		end)

		-- egyszerre csak egy ablak legyen nyitva
		local windows = { indexOpen, rebirthOpen, petsOpen, aurasOpen }
		local function toggle(window: typeof(indexOpen))
			local willOpen = not window()
			for _, other in windows do
				other(false)
			end
			window(willOpen)
		end

		return create "ScreenGui" {
			Name = "Hud",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			-- Bal oldal: menü gombok
			create "Frame" {
				Name = "Menu",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.45, 0),
				Size = UDim2.fromScale(0.08, 0.5),
				BackgroundTransparency = 1,

				create "UISizeConstraint" { MinSize = Vector2.new(70, 0), MaxSize = Vector2.new(96, math.huge) },
				create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				-- GDD 9.3: "🔄 Rebirth 2%"
				menuButton(1, "🔄", function()
					return `Rebirth {math.floor(RebirthWindow.progress(rebirthState) * 100)}%`
				end, function()
					toggle(rebirthOpen)
				end),
				menuButton(2, "📖", "Index", function()
					toggle(indexOpen)
				end),
				menuButton(3, "🐶", "Petek", function()
					toggle(petsOpen)
				end),
				menuButton(4, "✨", "Aurák", function()
					toggle(aurasOpen)
				end),
			},

			-- Fent középen: navigáció (GDD 9.3: [🏠 Telkem] [🥚 Tojások])
			create "Frame" {
				Name = "Nav",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(330, 52),
				BackgroundTransparency = 1,
				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 10),
				},
				navButton("🏠 Telkem", Palette.Gold, Teleport.home),
				navButton("🥚 Tojások", Palette.Lemon, Teleport.eggs),
			},

			-- GDD 3.12: "Következő esemény: 05:39" / aktív event visszaszámláló
			chunkyLabel {
				Name = "EventTimer",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 66),
				Size = UDim2.fromOffset(420, 30),
				TextColor3 = function()
					clock()
					local config = EventState.config()
					return if config then config.Color else Palette.White
				end,
				Text = function()
					local now = clock()
					local config = EventState.config()
					local seconds
					if config then
						seconds = math.max(0, math.ceil(EventState.endsAt() - now))
					else
						seconds = math.max(0, math.ceil(EventState.nextAt() - now))
					end
					local timer = string.format("%d:%02d", seconds // 60, seconds % 60)
					if config then
						return `{config.Icon} {config.Name} · {timer}`
					end
					return `Következő esemény: {timer}`
				end,
			},

			IndexWindow.create(indexOpen),
			RebirthWindow.create(rebirthOpen, rebirthState),
			PetsWindow.create(petsOpen, pets),
			AurasWindow.create(aurasOpen, auras, money, data),
			OfflineWindow.create(offline, data),

			-- Bal alul a pénz felett: Rebirth Token (később a rebirth-fán költhető)
			chunkyLabel {
				Name = "Tokens",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -100),
				Size = UDim2.fromOffset(240, 32),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Lemon,
				Visible = function()
					return rebirthState.tokens() > 0 or rebirthState.rebirths() > 0
				end,
				Text = function()
					return `🔄 x{rebirthState.rebirths() + 1} pénz · {rebirthState.tokens()} token`
				end,
			},

			-- Bal alul: pénz
			create "Frame" {
				Name = "Money",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -16),
				Size = UDim2.fromScale(0.3, 0.1),
				BackgroundTransparency = 1,

				create "UIAspectRatioConstraint" { AspectRatio = 4 },
				create "UISizeConstraint" { MaxSize = Vector2.new(360, 90) },

				chunkyLabel {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Palette.Money,
					Text = function()
						-- a spring float32-ben számol: ha már közel van, a pontos érték látszik
						local target = money()
						local shown = shownMoney()
						if math.abs(shown - target) <= math.max(1, math.abs(target) * 1e-4) then
							shown = target
						end
						return NumberFormat.money(shown)
					end,
				},
			},

			-- Lent középen: schnitzel a játékosnál
			create "Frame" {
				Name = "Carried",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.fromScale(0.34, 0.11),
				BackgroundColor3 = Palette.Panel,
				BackgroundTransparency = 0.15,

				create "UIAspectRatioConstraint" { AspectRatio = 3.6 },
				create "UISizeConstraint" { MaxSize = Vector2.new(400, 110) },
				create "UICorner" { CornerRadius = UDim.new(0.3, 0) },
				create "UIStroke" { Color = Palette.Stroke, Thickness = 3 },
				create "UIPadding" {
					PaddingLeft = UDim.new(0.06, 0),
					PaddingRight = UDim.new(0.06, 0),
					PaddingTop = UDim.new(0.12, 0),
					PaddingBottom = UDim.new(0.12, 0),
				},

				chunkyLabel {
					Size = UDim2.fromScale(1, 0.64),
					TextColor3 = Palette.Gold,
					Text = function()
						return `🥩 x {NumberFormat.grouped(carried())}`
					end,
				},

				-- a nálad lévő schnitzelek értéke
				chunkyLabel {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0.34),
					TextColor3 = Palette.Money,
					Text = function()
						return `{NumberFormat.money(carriedValue())} értékben`
					end,
				},
			},
		}
	end, playerGui)
end

return Hud
