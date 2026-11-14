local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local Gamepad = require(script.Parent.Gamepad)
local Audio = require(script.Parent.Audio)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local read = Vide.read

local C = Theme.Colors

local Kit = {}

export type Value<T> = T | () -> T

local CORNER = 5
local SMALL_CORNER = 4
local OUTLINE = 3
local INNER_LINE = 1.5
local INNER_TRANSPARENCY = 0.45
-- Ring texture is a 64x64 9-slice with a 20 px corner arc: SliceScale = corner / 20 matches UICorner.
local RING_RADIUS = 20
local WELD_TILE = 84

local function passthrough(props: { [any]: any }, custom: { string }): { [any]: any }
	local out = {}
	for k, v in props do
		if not table.find(custom, k) then
			out[k] = v
		end
	end
	return out
end

local screenScale = source(1)
local viewportSize = source(Vector2.new(1280, 660))
Kit.viewportSize = viewportSize
Kit.screenScale = screenScale
Kit.topbarInset = source(GuiService.TopbarInset)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
	Kit.topbarInset(GuiService.TopbarInset)
end)
Kit.topbarClear = source(GuiService.TopbarInset.Min.X)
Kit.topbarCenter = source((GuiService.TopbarInset.Min.Y + GuiService.TopbarInset.Max.Y) / 2)
Kit.guiOrigin = source(Vector2.zero)
Kit.guiSize = source(Vector2.new(1280, 660))
-- In landscape the safe inset is symmetric but the notch is on one side only (LandscapeLeft: notch right).
Kit.screenOrientation = source(Enum.ScreenOrientation.LandscapeSensor)
task.spawn(function()
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local function update()
		Kit.screenOrientation(playerGui.CurrentScreenOrientation)
	end
	playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(update)
	update()
end)
function Kit.sideSlack(side: "Left" | "Right"): number
	local inset = Kit.guiOrigin().X
	local orientation = Kit.screenOrientation()
	local cutout = if orientation == Enum.ScreenOrientation.LandscapeLeft then "Right"
		elseif orientation == Enum.ScreenOrientation.LandscapeRight then "Left"
		else nil
	return if inset > 0 and cutout ~= nil and cutout ~= side then inset else 0
end
task.spawn(function()
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	while true do
		local clear = GuiService.TopbarInset.Min.X
		local center = (GuiService.TopbarInset.Min.Y + GuiService.TopbarInset.Max.Y) / 2
		local topbar = playerGui:FindFirstChild("TopbarStandard")
		local holders = topbar and topbar:FindFirstChild("Holders")
		local left = holders and holders:FindFirstChild("Left")
		if left then
			for _, icon in left:GetChildren() do
				if icon:IsA("GuiObject") and icon.Visible and icon.AbsoluteSize.X > 0 then
					clear = math.max(clear, icon.AbsolutePosition.X + icon.AbsoluteSize.X)
					-- TopbarStandard ignores the GUI inset, so AbsolutePosition is in screen coordinates.
					center = icon.AbsolutePosition.Y + icon.AbsoluteSize.Y / 2
				end
			end
		end
		if clear ~= Vide.untrack(Kit.topbarClear) then
			Kit.topbarClear(clear)
		end
		if math.abs(center - Vide.untrack(Kit.topbarCenter)) > 0.5 then
			Kit.topbarCenter(center)
		end
		task.wait(0.5)
	end
end)
do
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			viewportSize(camera.ViewportSize)
			screenScale(Theme.scaleFor(camera.ViewportSize.Y))
		end
	end
	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) else nil
		rescale()
	end
	bindCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
end

function Kit.scale(extra: (() -> number)?): UIScale
	return create "UIScale" {
		Scale = function()
			return screenScale() * (if extra then extra() else 1)
		end,
	} :: UIScale
end

function Kit.fitScale(width: number, height: number, extra: (() -> number)?): UIScale
	return create "UIScale" {
		Scale = function()
			local viewport = viewportSize()
			local fit = math.min(screenScale(), math.max(0.3, (viewport.X - 28) / width), math.max(0.3, (viewport.Y - 156) / height))
			return fit * (if extra then extra() else 1)
		end,
	} :: UIScale
end

Kit.WindowWidth = 780
function Kit.windowFit(): number
	local viewport = viewportSize()
	return math.min(Theme.scaleFor(viewport.Y), math.max(0.3, (viewport.X - 28) / Kit.WindowWidth),
		math.max(0.3, (viewport.Y - 156) / 444))
end

function Kit.windowScale(extra: (() -> number)?): UIScale
	return create "UIScale" {
		Scale = function()
			return Kit.windowFit() * (if extra then extra() else 1)
		end,
	} :: UIScale
end

function Kit.windowHeight(maximum: number): number
	return math.min(maximum, math.max(190, viewportSize().Y - 126) / Kit.windowFit())
end

-- Hidden (Visible = false) elements still get re-laid out every frame, so they are removed from the tree.
function Kit.attach(parent: Instance, child: Instance, shown: () -> boolean)
	Vide.effect(function()
		child.Parent = if shown() then parent else nil
	end)
	Vide.cleanup(function()
		child:Destroy()
	end)
end

local TEXT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHex("ABABB6")),
})

-- Map the gradient onto the real text band (TextBounds); watching AbsoluteSize was ~1500 calls per frame.
local function fitGradient(sequence: ColorSequence)
	return Vide.action(function(instance: Instance)
		local label = instance :: TextLabel
		local gradient = label:FindFirstChildOfClass("UIGradient")
		if not gradient then
			return
		end
		local lastSpan, lastAlignment = -1, nil
		local function update()
			local h = label.AbsoluteSize.Y
			if h <= 0 then
				return
			end
			local span = math.clamp(label.TextBounds.Y / h, 0.05, 1)
			if math.abs(span - lastSpan) < 0.01 and label.TextYAlignment == lastAlignment then
				return
			end
			lastSpan, lastAlignment = span, label.TextYAlignment
			local top = if label.TextYAlignment == Enum.TextYAlignment.Top
				then 0
				elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then 1 - span
				else (1 - span) / 2
			local keypoints = sequence.Keypoints
			local out = { ColorSequenceKeypoint.new(0, keypoints[1].Value) }
			for _, kp in keypoints do
				local t = top + kp.Time * span
				if t > out[#out].Time + 0.0005 and t < 0.9995 then
					table.insert(out, ColorSequenceKeypoint.new(t, kp.Value))
				end
			end
			table.insert(out, ColorSequenceKeypoint.new(1, keypoints[#keypoints].Value))
			gradient.Color = ColorSequence.new(out)
		end
		update()
		local queued = false
		local function changed()
			update()
			if not queued then
				queued = true
				RunService.Heartbeat:Once(function()
					queued = false
					update()
				end)
			end
		end
		local firstMeasure: RBXScriptConnection? = nil
		if lastSpan < 0 then
			firstMeasure = label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				update()
				if lastSpan >= 0 and firstMeasure then
					firstMeasure:Disconnect()
				end
			end)
		end
		for _, property in { "Text", "TextSize", "FontFace", "TextWrapped", "TextYAlignment", "Size" } do
			label:GetPropertyChangedSignal(property):Connect(changed)
		end
		local parentSize: RBXScriptConnection? = nil
		local function watchParent()
			if parentSize then
				parentSize:Disconnect()
				parentSize = nil
			end
			local parent = label.Parent
			if parent and parent:IsA("GuiObject") then
				parentSize = parent:GetPropertyChangedSignal("Size"):Connect(changed)
			end
			changed()
		end
		label:GetPropertyChangedSignal("Parent"):Connect(watchParent)
		watchParent()
	end)
end

function Kit.text(props: { [any]: any }): TextLabel
	local size = if type(props.TextSize) == "number" then props.TextSize else 18
	local gradient = if props.Gradient == false then nil else props.Gradient or TEXT_GRADIENT
	return create "TextLabel" {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = C.White,
		TextSize = size,
		Size = UDim2.fromScale(1, 1),
		create "UIStroke" {
			Color = props.StrokeColor or C.Ink,
			Thickness = props.StrokeThickness or math.clamp(size / 9, 1.5, 3.5),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
		},
		if gradient then create "UIGradient" { Rotation = 90, Color = gradient } else nil,
		if gradient then fitGradient(gradient) else nil,
		passthrough(props, { "StrokeThickness", "StrokeColor", "Gradient" }),
	} :: TextLabel
end

function Kit.outline(color: Value<Color3>?, thickness: number?, join: Enum.LineJoinMode?): UIStroke
	return create "UIStroke" {
		Color = color or C.Ink,
		Thickness = thickness or OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = join or Enum.LineJoinMode.Round,
	} :: UIStroke
end

local SQUARE_LINE = 2
function Kit.ring(color: Value<Color3>, corner: number?, transparency: Value<number>?): GuiObject
	if corner == 0 then
		return create "Frame" {
			Name = "Ring",
			Position = UDim2.fromOffset(SQUARE_LINE, SQUARE_LINE),
			Size = UDim2.new(1, -2 * SQUARE_LINE, 1, -2 * SQUARE_LINE),
			BackgroundTransparency = 1,
			ZIndex = 2,
			create "UIStroke" {
				Color = color,
				Transparency = transparency or INNER_TRANSPARENCY,
				Thickness = SQUARE_LINE,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			},
		} :: Frame
	end
	return create "ImageLabel" {
		Name = "Ring",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Ui.Textures.Ring,
		ImageColor3 = color,
		ImageTransparency = transparency or INNER_TRANSPARENCY,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(RING_RADIUS + 4, RING_RADIUS + 4, 64 - RING_RADIUS - 4, 64 - RING_RADIUS - 4),
		SliceScale = (corner or CORNER) / RING_RADIUS,
		ZIndex = 2,
	} :: ImageLabel
end

function Kit.weld(color: Value<Color3>, transparency: number?, corner: number?): ImageLabel
	return create "ImageLabel" {
		Name = "Weld",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Ui.Textures.Weld,
		ImageColor3 = color,
		ImageTransparency = transparency or 0.55,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(WELD_TILE, WELD_TILE),
		create "UICorner" { CornerRadius = UDim.new(0, corner or CORNER) },
	} :: ImageLabel
end

local SHINE_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 3)
function Kit.shine(transparency: number?): Frame
	local streak = create "ImageLabel" {
		Name = "Streak",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1.2, 1.2),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = Ui.Textures.Shine,
		ImageTransparency = transparency or 0.55,
	}
	local tween = TweenService:Create(streak, SHINE_TWEEN, {
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	tween:Play()
	Vide.cleanup(function()
		tween:Cancel()
	end)
	return create "Frame" {
		Name = "ShineClip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		streak,
	} :: Frame
end

local function lipFor(height: number): number
	return math.clamp(math.round(height * 0.08), 3, 5)
end

local function candyFace(
	palette: () -> Theme.Palette,
	height: number,
	corner: number,
	shine: boolean,
	dim: (() -> Color3)?,
	children: { any }?
): Frame
	return create "Frame" {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -lipFor(height)),
		BackgroundColor3 = dim or C.White,
		create "UICorner" { CornerRadius = UDim.new(0, corner) },
		create "UIGradient" {
			Rotation = 90,
			Color = function()
				return Theme.faceGradient(palette())
			end,
		},
		Kit.weld(function()
			return palette().weld
		end, 0.55, corner),
		if shine then Kit.shine() else nil,
		Kit.ring(function()
			return palette().light
		end, corner),
		children,
	} :: Frame
end

local function pressable(extra: (() -> number)?, appear: (() -> number)?, grow: number?): (UIScale, { [string]: any })
	local hovered = source(false)
	local pressed = source(false)
	local hoverScale = grow or 1.05
	local springy = spring(function()
		local base = if extra then extra() else 1
		return base * (if pressed() then 0.9 elseif hovered() then hoverScale else 1)
	end, 0.18, 0.55)
	local scale = if appear
		then function()
			return springy() * math.max(0, appear())
		end
		else springy
	local events = {
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
			pressed(false)
		end,
		SelectionGained = function()
			hovered(true)
		end,
		SelectionLost = function()
			hovered(false)
			pressed(false)
		end,
		InputBegan = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA then
				pressed(true)
			end
		end,
		InputEnded = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA then
				pressed(false)
			end
		end,
	}
	return create "UIScale" { Scale = scale } :: UIScale, events
end

local function withSounds(events: { [string]: any }, activated: ((...any) -> ())?): ({ [string]: any }, (...any) -> ())
	local enter = events.MouseEnter
	events.MouseEnter = function()
		enter()
		Audio.play("Hover")
	end
	return events, function(...)
		Audio.play("Click")
		if activated then
			activated(...)
		end
	end
end

function Kit.button(props: { [any]: any }): ImageButton
	local corner = props.Corner or CORNER
	local size: UDim2 = props.Size or UDim2.fromOffset(150, 48)
	local height = if size.Y.Offset > 0 then size.Y.Offset else 48
	local selected = props.Selected
	-- UIScale scales around AnchorPoint, so buttons are centre-anchored and grow from the middle.
	local wide = size.X.Scale > 0 or size.X.Offset > 260
	local anchor: Vector2 = props.AnchorPoint or Vector2.zero
	local shift = UDim2.new(size.X.Scale * (0.5 - anchor.X), size.X.Offset * (0.5 - anchor.X),
		size.Y.Scale * (0.5 - anchor.Y), size.Y.Offset * (0.5 - anchor.Y))
	local position = props.Position
	local centered = if type(position) == "function"
		then function()
			return position() + shift
		end
		else (position or UDim2.new()) + shift
	local scale, events = pressable(if selected then function()
		return if read(selected) then 1.1 else 0.94
	end else nil, props.Appear, if wide then 1.03 else nil)
	local clicked
	events, clicked = withSounds(events, props.Activated)
	local palette = function(): Theme.Palette
		return Theme.Palettes[read(props.Color or "Blue")]
	end
	local textSize = props.TextSize or 24
	local hasText = props.Text ~= nil

	local content = {}
	if props.Icon then
		local iconSize = props.IconSize or 0.78
		table.insert(content, create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, if hasText then 0.42 else 0.5),
			Size = UDim2.fromScale(iconSize, iconSize),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			Image = props.Icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end
	if hasText then
		table.insert(content, Kit.text {
			Name = "Label",
			Text = props.Text,
			TextSize = textSize,
			AnchorPoint = Vector2.new(0.5, if props.Icon then 1 else 0.5),
			Position = if props.Icon
				then UDim2.new(0.5, 0, 1, 2 + lipFor(height))
				else UDim2.new(0.5, props.TextNudge or 0, 0.5, 0),
			Size = UDim2.new(1, 8, 0, textSize),
			ZIndex = 4,
		})
	end

	return create "ImageButton" {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundColor3 = function()
			return palette().lip
		end,
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = centered,
		events,
		Activated = clicked,
		scale,
		create "UICorner" { CornerRadius = UDim.new(0, corner) },
		Kit.outline(),
		if props.Glyph
			then Gamepad.glyph {
				Key = props.Glyph,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if props.GlyphInside then UDim2.fromOffset(9, 9) else UDim2.fromOffset(4, 4),
				Size = UDim2.fromOffset(math.clamp(height * 0.48, 22, 28), math.clamp(height * 0.48, 22, 28)),
				ZIndex = 8,
			}
			else nil,
		candyFace(palette, height, corner, props.Shine ~= false, function()
			return if selected and not read(selected) then Color3.fromRGB(150, 150, 165) else C.White
		end, content),
		passthrough(props, { "Color", "Text", "TextSize", "TextNudge", "Icon", "IconSize", "Corner", "Shine", "Activated", "Selected", "Size", "Appear", "Glyph", "GlyphInside", "AnchorPoint", "Position" }),
	} :: ImageButton
end

function Kit.plate(props: { [any]: any }): Frame
	local size: UDim2 = props.Size or UDim2.new(1, 0, 0, 38)
	local height = if size.Y.Offset > 0 then size.Y.Offset else 38
	local palette = function(): Theme.Palette
		return Theme.Palettes[read(props.Color or "Blue")]
	end
	return create "Frame" {
		Name = "Plate",
		Size = size,
		BackgroundColor3 = function()
			return palette().lip
		end,
		create "UICorner" { CornerRadius = UDim.new(0, SMALL_CORNER) },
		Kit.outline(),
		candyFace(palette, height, SMALL_CORNER, true, nil, {
			Kit.text {
				Name = "Label",
				Text = props.Text,
				TextSize = props.TextSize or 22,
				ZIndex = 4,
			},
		}),
		passthrough(props, { "Color", "Text", "TextSize", "Size" }),
	} :: Frame
end

local HEADER = 58
local HEADER_FACE = HEADER - lipFor(HEADER)
local CLOSE_SIZE = 38
local CLOSE_GAP = (HEADER_FACE - CLOSE_SIZE) / 2

function Kit.closeButton(props: { [any]: any }): ImageButton
	local merged: { [any]: any } = {
		Name = "Close",
		Color = "Red",
		Text = "X",
		TextSize = 25,
		TextNudge = -1.5,
		Shine = false,
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
	}
	for k, v in props do
		merged[k] = v
	end
	return Kit.button(merged)
end

function Kit.softBehind(labels: { TextLabel }, props: { [string]: any }?): ImageLabel
	local options = props or {}
	local pad: Vector2 = options.Padding or Vector2.new(26, 10)
	local soft = Ui.softPanel(options.Transparency or 0.45, options.Radius or 22)
	soft.Name = "SoftBackdrop"
	soft.ZIndex = options.ZIndex or 0
	soft.Visible = false
	local connections = {}
	local function sync()
		local parent = soft.Parent
		if not parent or not parent:IsA("GuiBase2d") then
			return
		end
		local parentSize, parentPosition = parent.AbsoluteSize, parent.AbsolutePosition
		if parentSize.X <= 0 or parentSize.Y <= 0 then
			return
		end
		local low, high = nil :: Vector2?, nil :: Vector2?
		for _, label in labels do
			local bounds = label.TextBounds
			if label.Visible and label.Text ~= "" and bounds.X > 0 then
				local size, position = label.AbsoluteSize, label.AbsolutePosition
				local x = if label.TextXAlignment == Enum.TextXAlignment.Left then position.X
					elseif label.TextXAlignment == Enum.TextXAlignment.Right then position.X + size.X - bounds.X
					else position.X + (size.X - bounds.X) / 2
				local y = if label.TextYAlignment == Enum.TextYAlignment.Top then position.Y
					elseif label.TextYAlignment == Enum.TextYAlignment.Bottom then position.Y + size.Y - bounds.Y
					else position.Y + (size.Y - bounds.Y) / 2
				local a, b = Vector2.new(x, y), Vector2.new(x + bounds.X, y + bounds.Y)
				low = if low then low:Min(a) else a
				high = if high then high:Max(b) else b
			end
		end
		soft.Visible = low ~= nil
		if low and high then
			-- Position as a fraction of the parent so nested UIScales are not applied twice.
			soft.Position = UDim2.new((low.X - parentPosition.X) / parentSize.X, -pad.X, (low.Y - parentPosition.Y) / parentSize.Y, -pad.Y)
			soft.Size = UDim2.new((high.X - low.X) / parentSize.X, pad.X * 2, (high.Y - low.Y) / parentSize.Y, pad.Y * 2)
		end
	end
	local parentConnections = {}
	local function watchParent()
		for _, c in parentConnections do
			c:Disconnect()
		end
		table.clear(parentConnections)
		local parent = soft.Parent
		if parent and parent:IsA("GuiBase2d") then
			table.insert(parentConnections, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync))
			table.insert(parentConnections, parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync))
		end
		sync()
	end
	for _, label in labels do
		for _, property in { "TextBounds", "AbsoluteSize", "AbsolutePosition", "Visible", "Text" } do
			table.insert(connections, label:GetPropertyChangedSignal(property):Connect(sync))
		end
	end
	table.insert(connections, soft.AncestryChanged:Connect(watchParent))
	Vide.cleanup(function()
		for _, c in connections do
			c:Disconnect()
		end
		for _, c in parentConnections do
			c:Disconnect()
		end
	end)
	return soft
end

function Kit.darkBox(props: { [any]: any }): Frame
	local corner = props.Corner or SMALL_CORNER
	return create "Frame" {
		BackgroundColor3 = props.Fill or C.Card,
		BackgroundTransparency = props.Transparency or Theme.CardTransparency,
		if corner > 0 then create "UICorner" { CornerRadius = UDim.new(0, corner) } else nil,
		Kit.outline(props.Outline, nil, if corner > 0 then nil else Enum.LineJoinMode.Miter),
		if corner > 2 * CORNER
			then create "Frame" {
				Name = "Ring",
				Position = UDim2.fromOffset(INNER_LINE, INNER_LINE),
				Size = UDim2.new(1, -2 * INNER_LINE, 1, -2 * INNER_LINE),
				BackgroundTransparency = 1,
				ZIndex = 2,
				create "UICorner" { CornerRadius = UDim.new(0, corner - INNER_LINE) },
				create "UIStroke" {
					Color = props.Line or C.CardLine,
					Thickness = INNER_LINE,
					Transparency = INNER_TRANSPARENCY,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},
			}
			else Kit.ring(props.Line or C.CardLine, corner),
		passthrough(props, { "Fill", "Line", "Outline", "Transparency", "Corner" }),
	} :: Frame
end

function Kit.statRow(props: { Label: Value<string>, Value: Value<string>, Color: Value<Color3>, LayoutOrder: number? }): Frame
	return Kit.darkBox {
		Name = "Stat",
		Size = UDim2.new(1, 0, 0, 26),
		Corner = 0,
		LayoutOrder = props.LayoutOrder,
		create "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create "UIPadding" { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) },
			Kit.text {
				Text = function()
					return read(props.Label) .. ":"
				end,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			Kit.text {
				Text = props.Value,
				TextSize = 15,
				TextColor3 = props.Color,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		},
	}
end

function Kit.pillBorder(color: Value<Color3>, transparency: number?): Frame
	return create "Frame" {
		Name = "Inner",
		Position = UDim2.fromOffset(INNER_LINE, INNER_LINE),
		Size = UDim2.new(1, -2 * INNER_LINE, 1, -2 * INNER_LINE),
		BackgroundTransparency = 1,
		ZIndex = 2,
		create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
		create "UIStroke" {
			Color = color,
			Thickness = INNER_LINE,
			Transparency = transparency or INNER_TRANSPARENCY,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	} :: Frame
end

function Kit.bar(props: { Label: Value<string>, Right: Value<string>, Value: () -> number, Palette: Value<string>?, Size: UDim2?, [any]: any }): Frame
	local function palette(): Theme.Palette
		return Theme.Palettes[read(props.Palette or "Yellow")]
	end
	local size = props.Size or UDim2.fromOffset(260, 28)
	local fill = spring(function()
		return math.clamp(props.Value(), 0, 1)
	end, 0.5, 1)
	return create "Frame" {
		Name = "Bar",
		Size = size,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
		Kit.outline(),
		create "Frame" {
			Name = "Fill",
			BackgroundColor3 = C.White,
			ZIndex = 2,
			Size = function()
				return UDim2.fromScale(fill(), 1)
			end,
			Visible = function()
				return fill() > 0.005
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			create "UISizeConstraint" { MinSize = Vector2.new(size.Y.Offset, 0) },
			create "UIGradient" { Rotation = 90, Color = function() return Theme.faceGradient(palette()) end },
			Kit.pillBorder(function() return palette().light end, 0.15),
		},
		create "Frame" {
			Name = "Labels",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
			create "UIPadding" { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
			Kit.text {
				Text = props.Label,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			},
			Kit.text {
				Text = props.Right,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
			},
		},
		passthrough(props, { "Label", "Right", "Value", "Palette", "Size" }),
	} :: Frame
end

function Kit.searchBox(props: { Text: (string?) -> string, Placeholder: string?, [any]: any }): Frame
	return Kit.darkBox {
		Name = "Search",
		Size = UDim2.fromOffset(300, 38),
		Fill = C.Panel,
		Line = C.PanelLine,
		Transparency = Theme.PanelTransparency,
		Corner = CORNER,
		create "TextBox" {
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			FontFace = Theme.Font,
			TextSize = 22,
			TextColor3 = C.White,
			PlaceholderText = props.Placeholder or "Search",
			PlaceholderColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Theme.textStroke(3),
			Vide.changed("Text", props.Text),
		},
		passthrough(props, { "Text", "Placeholder" }),
	}
end

local function squareCorner(color: Color3, transparency: number, anchor: Vector2, position: UDim2): Frame
	return create "Frame" {
		Name = "SquareCorner",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(CORNER, CORNER),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
	} :: Frame
end

local BURST_COUNT = 9
local function burst(layer: GuiObject, center: UDim2, color: Color3, count: number?, reach: number?)
	local total = count or BURST_COUNT
	local far = reach or 1
	for i = 1, total do
		local angle = (i / total + math.random() * 0.06) * math.pi * 2
		local distance = (70 + math.random() * 50) * far
		local size = (18 + math.random() * 14) * math.sqrt(far)
		local sparkle = Instance.new("ImageLabel")
		sparkle.Name = "Sparkle"
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = center
		sparkle.Size = UDim2.fromOffset(size * 0.4, size * 0.4)
		sparkle.BackgroundTransparency = 1
		sparkle.Image = Ui.Textures.Sparkle
		sparkle.ImageColor3 = if i % 2 == 0 then C.White else color
		sparkle.ZIndex = 6
		sparkle.Parent = layer
		local info = TweenInfo.new(0.55 + math.random() * 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(sparkle, info, {
			Position = center + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance * 0.7),
			Size = UDim2.fromOffset(size, size),
			Rotation = (math.random() - 0.5) * 240,
		}):Play()
		TweenService:Create(sparkle, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), {
			ImageTransparency = 1,
		}):Play()
		task.delay(0.9, sparkle.Destroy, sparkle)
	end
end
Kit.burst = burst

function Kit.window(props: { [any]: any }): Frame
	local palette = Theme.Palettes[props.Color or "Pink"]
	local anim: Motion.Anim? = props.Anim
	local position: UDim2 = props.Position or UDim2.fromScale(0.5, 0.52)
	local function tabsInside(): boolean
		if props.Tabs == nil then
			return false
		end
		local size = read(props.Size)
		local width = if typeof(size) == "UDim2" and size.X.Offset > 0 then size.X.Offset else Kit.WindowWidth
		local tabsLeft = Kit.guiSize().X / 2 - (width / 2 + 78) * Kit.windowFit()
		return tabsLeft < 14 + 76 * screenScale() + 8
	end
	local function one(): number
		return 1
	end
	local windowIn = if anim then anim.window else one
	local iconIn = if anim then anim.appear(0.08, 0, Enum.EasingStyle.Elastic, 0.85) else one
	local titleIn = if anim then anim.appear(0.12, 0, Enum.EasingStyle.Back, 0.4) else one
	local closeIn = if anim then anim.appear(0.24, 0, Enum.EasingStyle.Back, 0.4) else one
	local burstLayer = create "Frame" {
		Name = "Burst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	} :: Frame
	if anim then
		Vide.effect(function()
			if anim.opened() then
				task.delay(0.12, function()
					if burstLayer.Parent then
						burst(burstLayer, UDim2.fromOffset(34, 24), palette.light)
					end
				end)
			end
		end)
	end
	return create "Frame" {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return position + UDim2.fromOffset(0, (1 - windowIn()) * 60)
		end,
		Size = UDim2.fromOffset(660, 400),
		BackgroundTransparency = 1,
		Active = true,
		create "UICorner" { CornerRadius = UDim.new(0, CORNER) },
		Kit.outline(),
		create "Frame" {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, HEADER),
			BackgroundColor3 = palette.lip,
			ZIndex = 2,
			create "UICorner" { CornerRadius = UDim.new(0, CORNER) },
			candyFace(function()
				return palette
			end, HEADER, CORNER, true),
			squareCorner(palette.lip, 0, Vector2.new(0, 1), UDim2.fromScale(0, 1)),
			squareCorner(palette.lip, 0, Vector2.new(1, 1), UDim2.fromScale(1, 1)),
			create "ImageLabel" {
				Name = "TitleIcon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(34, 24),
				Size = UDim2.fromOffset(76, 76),
				BackgroundTransparency = 1,
				Image = props.Icon,
				ScaleType = Enum.ScaleType.Fit,
				Rotation = function()
					return -6 - (1 - iconIn()) * 120
				end,
				ZIndex = 5,
				create "UIScale" {
					Scale = function()
						return math.max(0, iconIn())
					end,
				},
			},
			burstLayer,
			Kit.text {
				Name = "Title",
				Text = props.Title,
				TextSize = 38,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = function()
					return UDim2.fromOffset(78 - (1 - titleIn()) * 50, -2)
				end,
				Size = UDim2.new(1, -200, 1, 0),
				ZIndex = 4,
			},
			if props.Count
				then Kit.text {
					Name = "Count",
					Text = props.Count,
					TextSize = 32,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -64, 0, -2),
					Size = UDim2.new(0, 120, 1, 0),
					ZIndex = 4,
				}
				else nil,
			Kit.closeButton {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -CLOSE_GAP - CLOSE_SIZE / 2, 0, HEADER_FACE / 2),
				Activated = props.OnClose,
				Glyph = Gamepad.Keys.Close,
				ZIndex = 4,
				Appear = if anim then closeIn else nil,
				Rotation = function()
					return (1 - closeIn()) * -180
				end,
			},
		},
		if props.Tabs
			then create "Frame" {
				Name = "Tabs",
				AnchorPoint = Vector2.new(1, 0),
				Position = function() return UDim2.fromOffset(if tabsInside() then 74 else -14, HEADER + 14) end,
				Size = UDim2.fromOffset(64, 200),
				BackgroundTransparency = 1,
				ZIndex = 3,
				create "UIListLayout" {
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				},
				props.Tabs,
			}
			else nil,
		create "Frame" {
			Name = "Divider",
			Position = UDim2.fromOffset(0, HEADER),
			Size = UDim2.new(1, 0, 0, OUTLINE),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			ZIndex = 2,
		},
		create "Frame" {
			Name = "Body",
			Position = UDim2.fromOffset(0, HEADER + OUTLINE),
			Size = UDim2.new(1, 0, 1, -HEADER - OUTLINE),
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = Theme.PanelTransparency,
			create "UICorner" { CornerRadius = UDim.new(0, CORNER) },
			squareCorner(C.Panel, Theme.PanelTransparency, Vector2.new(0, 0), UDim2.fromScale(0, 0)),
			squareCorner(C.Panel, Theme.PanelTransparency, Vector2.new(1, 0), UDim2.fromScale(1, 0)),
			Kit.ring(C.PanelLine, CORNER),
			create "Frame" {
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				create "UIPadding" {
					PaddingLeft = function() return UDim.new(0, if tabsInside() then 88 else 12) end,
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
				},
				props.Body,
			},
		},
		passthrough(props, { "Title", "Icon", "Color", "Count", "OnClose", "Tabs", "Body", "Anim", "Position" }),
	} :: Frame
end

return Kit
