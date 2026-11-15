-- Settings window, opened from the TopbarPlus "Settings" icon (Controllers/SettingsController). Two tabs:
--   Settings: volume slider + ON / OFF toggles in sections (Audio, Graphics, Other Players), the same candy
--     slider, toggles and rows as the EggDrop game's settings. Changes apply at once
--     (State.settings) and are sent to the server shortly after (Remotes.SaveSettings, saved with the profile).
--   Codes (GDD 5.1 ⑦): type a code, REDEEM; the server checks it (Config.Codes) and answers (Remotes.CodeResult).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(ReplicatedStorage.Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local C = Theme.Colors

local ROW = 64
local TRACK = 30
local SAVE_DELAY = 0.6 -- s after the last change

local SettingsWindow = {}

local saveToken = 0
local function change(key: string, value: any)
	local settings = table.clone(State.settings())
	settings[key] = value
	State.settings(settings)
	-- send once the slider stops moving
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token == saveToken then
			Remotes.SaveSettings:FireServer(State.settings())
		end
	end)
end

-- Candy slider: dark capsule track, coloured fill, white knob at the end; click or drag to set.
local function slider(key: string, palette: Theme.Palette, preview: string?)
	local function value(): number
		return State.settings()[key]
	end
	local dragging = Vide.source(false)
	local track: ImageButton
	local function update(x: number)
		local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
		if width > 0 then
			change(key, math.clamp((x - left) / width, 0, 1))
		end
	end
	local connections = {
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging()
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				update(input.Position.X)
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if
				dragging()
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging(false)
				-- a sample at the new volume on release
				if preview then
					Audio.play(preview)
				end
			end
		end),
	}
	Vide.cleanup(function()
		for _, c in connections do
			c:Disconnect()
		end
	end)
	local knobScale = Vide.spring(function()
		return if dragging() then 1.15 else 1
	end, 0.15, 0.55)
	track = create "ImageButton" {
		Name = "Track",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -86, 0.5, 0),
		Size = UDim2.new(0.45, 0, 0, TRACK),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 0.2,
		create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
		Kit.outline(),
		Kit.pillBorder(C.CardLine),
		InputBegan = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging(true)
				update(input.Position.X)
			end
		end,
		-- the fill is always at least as wide as it is tall, so it stays a capsule
		create "Frame" {
			Name = "Fill",
			BackgroundColor3 = C.White,
			ZIndex = 2,
			Size = function()
				return UDim2.new(value(), (1 - value()) * TRACK, 1, 0)
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			create "UIGradient" { Rotation = 90, Color = Theme.faceGradient(palette) },
			Kit.pillBorder(palette.light, 0.3),
		},
		create "Frame" {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.White,
			ZIndex = 3,
			Size = UDim2.fromOffset(TRACK + 10, TRACK + 10),
			Position = function()
				return UDim2.new(value(), TRACK / 2 - value() * TRACK, 0.5, 0)
			end,
			create "UIScale" { Scale = knobScale },
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			create "UIGradient" { Rotation = 90, Color = ColorSequence.new(C.White, Color3.fromHex("C9CDD8")) },
			Kit.outline(),
		},
	} :: ImageButton
	return {
		track,
		Kit.text {
			Name = "Percent",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = function()
				return `{math.round(value() * 100)}%`
			end,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(64, 28),
		},
	}
end

-- ON / OFF candy button (green / gray).
local function toggle(key: string)
	local function on(): boolean
		return State.settings()[key] == true
	end
	return Kit.button {
		Name = "Toggle",
		TextSize = 22,
		Shine = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(120, 42),
		Text = function()
			return if on() then "ON" else "OFF"
		end,
		Color = function()
			return if on() then "Green" else "Gray"
		end,
		Activated = function()
			change(key, not on())
		end,
	}
end

local function row(order: number, label: string, hint: string, control: any, appear: () -> number)
	return create "Frame" {
		Name = label,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		Kit.darkBox {
			Name = "Row",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Position = function()
				return UDim2.new(0.5, 0, 0.5, (1 - appear()) * 30)
			end,
			create "UIScale" {
				Scale = function()
					return math.max(0, appear())
				end,
			},
			Kit.text {
				Name = "Label",
				Text = label,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(16, 7),
				Size = UDim2.new(0.36, 0, 0, 28),
			},
			Kit.text {
				Name = "Hint",
				Text = hint,
				TextSize = 14,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(17, 36),
				Size = UDim2.new(0.36, 0, 0, 18),
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
			control,
		},
	}
end

local function section(order: number, text: string)
	return Kit.text {
		Name = text,
		LayoutOrder = order,
		Text = text,
		TextSize = 20,
		TextColor3 = C.Lemon,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
	}
end

-- The settings, by section (the keys and defaults: Shared/Settings).
local SECTIONS = {
	{
		title = "AUDIO",
		rows = {
			{ "Sound Effects", "Buttons, coins, events", function()
				return slider("sfx", Theme.Palettes.Blue, "Coins")
			end },
		},
	},
	{
		title = "GRAPHICS",
		rows = {
			{ "Low Mode", "Faster on slow devices", function()
				return toggle("lowMode")
			end },
			{ "Visual Effects", "Aura particles, event screen colours", function()
				return toggle("effects")
			end },
			{ "Popup Texts", "+$ and +n above your head", function()
				return toggle("popups")
			end },
		},
	},
	{
		title = "OTHER PLAYERS",
		rows = {
			{ "Their Pets", "Pets following other players", function()
				return toggle("otherPets")
			end },
			{ "Their Stacks", "Schnitzel towers on other heads", function()
				return toggle("otherStacks")
			end },
		},
	},
}

local function settingsPage(anim: Motion.Anim, visible: () -> boolean): Frame
	local total = 0
	for _, group in SECTIONS do
		total += #group.rows
	end
	local rows = {}
	local order, index = 0, 0
	for _, group in SECTIONS do
		order += 1
		table.insert(rows, section(order, group.title))
		for _, entry in group.rows do
			order += 1
			index += 1
			table.insert(rows, row(order, entry[1], entry[2], entry[3](), anim.stagger(index, total)))
		end
	end
	return create "ScrollingFrame" {
		Name = "Options",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0, -- scrolls by drag / wheel, the bar itself is not drawn (like the Rebirth Tree)
		ScrollBarImageTransparency = 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		Visible = visible,
		create "UIPadding" {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
		},
		create "UIListLayout" { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder },
		rows,
	} :: Frame
end

local function codesPage(visible: () -> boolean): Frame
	local box: TextBox
	local function redeem()
		local code = box.Text
		if string.gsub(code, "%s", "") == "" then
			return
		end
		Remotes.RedeemCode:FireServer(code)
	end
	-- clear the box after a successful redeem
	local lastResult = Vide.untrack(State.codeResult)
	Vide.effect(function()
		local result = State.codeResult()
		if result ~= lastResult then
			lastResult = result
			if result and result.ok and box then
				box.Text = ""
			end
		end
	end)

	box = create "TextBox" {
		Name = "Input",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = Theme.Font,
		TextSize = 26,
		TextColor3 = C.White,
		PlaceholderText = "Enter code",
		PlaceholderColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
		Theme.textStroke(3),
		FocusLost = function(enterPressed: boolean)
			if enterPressed then
				redeem()
			end
		end,
	} :: TextBox

	return create "Frame" {
		Name = "Codes",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = visible,
		create "UIListLayout" {
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		create "ImageLabel" {
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(84, 84),
			BackgroundTransparency = 1,
			Image = Ui.Icons.Ticket,
			ScaleType = Enum.ScaleType.Fit,
		},
		Kit.text {
			LayoutOrder = 2,
			Text = "Have a code? Redeem it for free rewards!",
			TextSize = 20,
			TextColor3 = C.Lemon,
			Size = UDim2.new(1, 0, 0, 26),
		},
		create "Frame" {
			Name = "Entry",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(500, 52),
			BackgroundTransparency = 1,
			Kit.darkBox {
				Name = "Box",
				Size = UDim2.new(1, -170, 1, 0),
				Fill = C.Panel,
				Line = C.PanelLine,
				Transparency = Theme.PanelTransparency,
				box,
			},
			Kit.button {
				Name = "Redeem",
				Text = "REDEEM",
				TextSize = 24,
				Color = "Green",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(156, 52),
				Interactable = State.loaded,
				Activated = redeem,
			},
		},
		Kit.text {
			Name = "Result",
			LayoutOrder = 4,
			Text = function()
				local result = State.codeResult()
				return if result then result.message else ""
			end,
			TextSize = 20,
			TextColor3 = function()
				local result = State.codeResult()
				return if result and result.ok then C.Money else C.Bad
			end,
			Gradient = false,
			Size = UDim2.new(1, 0, 0, 26),
		},
		Kit.text {
			LayoutOrder = 5,
			Text = "Like the game and follow us for new codes!",
			TextSize = 15,
			TextColor3 = C.Muted,
			Gradient = false,
			Size = UDim2.new(1, 0, 0, 20),
		},
	} :: Frame
end

function SettingsWindow.render(anim: Motion.Anim)
	local tab = Vide.source("Settings")
	local function tabButton(order: number, name: string, icon: string, color: string)
		return Kit.button {
			Name = name,
			LayoutOrder = order,
			Icon = icon,
			IconSize = 0.85,
			Color = color,
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
		Name = "Settings",
		Title = function()
			return if tab() == "Codes" then "Codes" else "Settings"
		end,
		-- the header follows the tab: blue + gear for Settings, yellow + ticket for Codes (like the tab buttons)
		Icon = function()
			return if tab() == "Codes" then Ui.Icons.Ticket else Ui.Icons.Settings
		end,
		Color = function()
			return if tab() == "Codes" then "Yellow" else "Blue"
		end,
		Anim = anim,
		Size = function()
			return UDim2.fromOffset(620, Kit.windowHeight(470))
		end,
		Kit.windowScale(anim.scale),
		OnClose = State.close,
		Tabs = {
			tabButton(1, "Settings", Ui.Icons.Settings, "Blue"),
			tabButton(2, "Codes", Ui.Icons.Ticket, "Yellow"),
		},
		Body = {
			settingsPage(anim, function()
				return tab() == "Settings"
			end),
			codesPage(function()
				return tab() == "Codes"
			end),
		},
	}
end

return SettingsWindow
