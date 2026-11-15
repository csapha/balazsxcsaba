-- GDD 7 FTUE on the client (Config.Tutorial; the server steps through data.tutorial – TutorialService).
--   Bubble (top): the chef, 2–4 words, step dots (●●●○○) and a mini picture of what happens
--     (oven + oven = better oven), SKIP TUTORIAL (two taps: skips the whole tutorial, every HUD button shows).
--   Target: a pulsing gold outline (Highlight), a light pillar and a pulsing ring on the floor, a big bouncing arrow,
--     and a gold light trail on the floor from you to it.
--   Edge pointer: when the target is off screen, an arrow at the screen edge points to it, with the distance.
--   "Nice!" after every finished step (sparkles + sound).
--   Intro: right after the loading screen a 2 s drone flight over your plot, then the first step
--     (the server waits for Remotes.TutorialIntroDone).
--   Tutorial.revealed: which HUD buttons are shown yet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Ui = require(Shared.Ui)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local C = Theme.Colors
local TutorialConfig = Config.Tutorial
local GOLD = Color3.fromHex("FFD23F")
local player = Players.LocalPlayer

local Tutorial = {}

local confirmSkip = source(false) -- the SKIP TUTORIAL button asks "SURE?" first
local cheer = source(nil :: string?) -- "Nice!" text while it shows
local cheerToken = 0

-- a ticking source for the chef's wave in the bubble (re-evaluated every frame)
local wave = source(0)
RunService.Heartbeat:Connect(function()
	wave(os.clock())
end)

-- The current step while the tutorial runs (nil when done or in free play).
function Tutorial.step(): string?
	local tutorial = State.tutorial()
	if tutorial.done or tutorial.step == "" or tutorial.step == "Free" then
		return nil
	end
	return tutorial.step
end

-- GDD 7 (decision 2026-11-15): HUD buttons appear by PROGRESS (not time); a returning player (tutorial done)
-- sees them all. Shop – after the main tutorial steps; Index – the first Lv3 oven; Pets – the first pet;
-- Auras – the first ticket / aura; Rebirth – past 1% of the requirement.
function Tutorial.revealed(name: string): boolean
	local tutorial = State.tutorial()
	if tutorial.done then
		return true
	end
	local reveal = TutorialConfig.Reveal
	if name == "Shop" then
		return tutorial.step ~= "" and table.find(TutorialConfig.Main, tutorial.step) == nil
	elseif name == "Index" then
		return State.highestOven() >= reveal.IndexLevel
	elseif name == "Pets" then
		return #State.pets().inventory > 0
	elseif name == "Auras" then
		local auras = State.auras()
		return auras.tickets > 0 or next(auras.owned) ~= nil
	elseif name == "Rebirth" then
		return State.rebirths() > 0
			or State.earned() / Formulas.rebirthRequirement(State.rebirths()) >= reveal.RebirthProgress
	end
	return true
end

-- A newly revealed button: the chef introduces it ("New: Shop!") with the same pop as "Nice!".
function Tutorial.announce(text: string)
	-- a little later, so a step's "Nice!" (it comes at the same time, e.g. Shop after the main steps) shows first
	task.delay(0.9, function()
		cheerToken += 1
		local token = cheerToken
		cheer(text)
		task.delay(2, function()
			if token == cheerToken then
				cheer(nil)
			end
		end)
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

local function localPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- A local, invisible anchor part (for targets that are not parts: the sleeping chef).
local anchor = localPart("TutorialAnchor")
anchor.Transparency = 1
anchor.Size = Vector3.new(1, 1, 1)

-- The target of a step: a part, and how high the arrow floats above its centre.
local function resolve(target: string?): (BasePart?, number)
	if not target then
		return nil, 0
	end
	local kind, key = string.match(target, "^(%w+):?(.*)$")
	if kind == "Pad" then
		local plot = ownPlot()
		local part = plot and plot:FindFirstChild(key)
		return if part and part:IsA("BasePart") then part else nil, 8
	elseif kind == "Egg" then
		local plaza = workspace:FindFirstChild("EggPlaza")
		local egg = plaza and plaza:FindFirstChild("Egg" .. key)
		return if egg and egg:IsA("BasePart") then egg else nil, 12
	elseif kind == "SleepingChef" then
		local plot = ownPlot()
		local chefs = plot and plot:FindFirstChild("Chefs", true)
		local origin = plot and plot:GetAttribute("Origin")
		if not chefs or typeof(origin) ~= "CFrame" then
			return nil, 0
		end
		for _, chef in chefs:GetChildren() do
			local from = chef:GetAttribute("From")
			if chef:GetAttribute("Phase") == "sleep" and typeof(from) == "Vector3" then
				anchor.CFrame = origin * CFrame.new(from)
				anchor.Parent = workspace
				return anchor, 6
			end
		end
	end
	return nil, 0
end

------------------------------------------------------------------------------------------------
-- World guidance: highlight, light pillar, floor ring, big arrow, light trail
------------------------------------------------------------------------------------------------
type Guide = {
	target: BasePart?,
	height: number,
	items: { Instance },
	arrow: BillboardGui?,
	ring: Part?,
	highlight: Highlight?,
	from: Attachment?,
}
local guide: Guide = { height = 0, items = {} }

local function clearGuide()
	for _, item in guide.items do
		item:Destroy()
	end
	guide = { height = 0, items = {} }
end

local function buildGuide(target: BasePart, height: number)
	clearGuide()
	guide.target = target
	guide.height = height
	local bottom = target.Position.Y - target.Size.Y / 2
	local items = guide.items

	-- pulsing gold outline (not on the invisible chef anchor)
	if target ~= anchor then
		local highlight = Instance.new("Highlight")
		highlight.Name = "TutorialHighlight"
		highlight.Adornee = target
		highlight.FillColor = GOLD
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.6
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = workspace -- local only (the client created it)
		guide.highlight = highlight
		table.insert(items, highlight)
	end

	-- light pillar (a waypoint that shows from far away) and a pulsing ring on the floor
	local pillar = localPart("TutorialPillar")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = GOLD
	pillar.Transparency = 0.65
	pillar.Size = Vector3.new(40, 1.4, 1.4)
	pillar.CFrame = CFrame.new(target.Position.X, bottom + 20, target.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = workspace
	table.insert(items, pillar)

	local ring = localPart("TutorialRing")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.2, 8, 8)
	ring.CFrame = CFrame.new(target.Position.X, bottom + 0.15, target.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	guide.ring = ring
	table.insert(items, ring)

	-- the big bouncing arrow
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "TutorialArrow"
	arrow.Adornee = target
	arrow.Size = UDim2.fromOffset(110, 110)
	arrow.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "▼"
	text.TextScaled = true
	text.TextColor3 = GOLD
	Ui.worldText(text, 4)
	text.Parent = arrow
	arrow.Parent = player:WaitForChild("PlayerGui")
	guide.arrow = arrow
	table.insert(items, arrow)

	-- the light trail on the floor, from your feet to the target
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local from = Instance.new("Attachment")
		from.Name = "TutorialFrom"
		from.Position = Vector3.new(0, -2.6, 0)
		from.Parent = root
		local to = Instance.new("Attachment")
		to.Name = "TutorialTo"
		to.Position = Vector3.new(0, -target.Size.Y / 2 + 0.3, 0)
		to.Parent = target
		local beam = Instance.new("Beam")
		beam.Name = "TutorialTrail"
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Texture = Ui.Textures.TutorialArrow
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = 3
		beam.TextureSpeed = 1.2
		beam.Color = ColorSequence.new(GOLD)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 2
		beam.Width1 = 2
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new(0.15)
		beam.Parent = root
		guide.from = from
		table.insert(items, from)
		table.insert(items, to)
		table.insert(items, beam)
	end
end

------------------------------------------------------------------------------------------------
-- Edge pointer: an arrow at the screen edge towards an off-screen target, with the distance
------------------------------------------------------------------------------------------------
local pointerGui = Instance.new("ScreenGui")
pointerGui.Name = "TutorialPointer"
pointerGui.IgnoreGuiInset = true
pointerGui.ResetOnSpawn = false
pointerGui.DisplayOrder = 5
local pointer = Instance.new("Frame")
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = UDim2.fromOffset(90, 90)
pointer.BackgroundTransparency = 1
pointer.Visible = false
pointer.Parent = pointerGui
local pointerArrow = Instance.new("TextLabel")
pointerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
pointerArrow.Position = UDim2.fromScale(0.5, 0.4)
pointerArrow.Size = UDim2.fromOffset(64, 64)
pointerArrow.BackgroundTransparency = 1
pointerArrow.Text = "▲"
pointerArrow.TextScaled = true
pointerArrow.TextColor3 = GOLD
Ui.worldText(pointerArrow, 4)
pointerArrow.Parent = pointer
local pointerDistance = Instance.new("TextLabel")
pointerDistance.AnchorPoint = Vector2.new(0.5, 0)
pointerDistance.Position = UDim2.fromScale(0.5, 0.78)
pointerDistance.Size = UDim2.fromOffset(90, 24)
pointerDistance.BackgroundTransparency = 1
pointerDistance.TextSize = 20
pointerDistance.TextColor3 = Color3.new(1, 1, 1)
Ui.worldText(pointerDistance, 2.5)
pointerDistance.Parent = pointer

local EDGE = 70

local function updatePointer()
	local target = guide.target
	local camera = workspace.CurrentCamera
	if not target or not target.Parent or not camera then
		pointer.Visible = false
		return
	end
	local viewport = camera.ViewportSize
	local point, onScreen = camera:WorldToViewportPoint(target.Position)
	local inside = onScreen
		and point.X > EDGE
		and point.X < viewport.X - EDGE
		and point.Y > EDGE
		and point.Y < viewport.Y - EDGE
	if inside then
		pointer.Visible = false
		return
	end
	-- direction from the screen centre (behind the camera the projection is mirrored)
	local center = viewport / 2
	local direction = Vector2.new(point.X, point.Y) - center
	if point.Z < 0 then
		direction = -direction
	end
	if direction.Magnitude < 1 then
		direction = Vector2.new(0, 1)
	end
	local unit = direction.Unit
	local half = center - Vector2.new(EDGE, EDGE)
	local scale = math.min(
		if unit.X ~= 0 then math.abs(half.X / unit.X) else math.huge,
		if unit.Y ~= 0 then math.abs(half.Y / unit.Y) else math.huge
	)
	local at = center + unit * scale
	pointer.Position = UDim2.fromOffset(at.X, at.Y)
	pointerArrow.Rotation = math.deg(math.atan2(unit.X, -unit.Y))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	pointerDistance.Text = if root then `{math.floor((root.Position - target.Position).Magnitude)}m` else ""
	pointer.Visible = true
end

------------------------------------------------------------------------------------------------
-- Intro: the drone flight right after the loading screen (GDD 7.2)
------------------------------------------------------------------------------------------------
local introPlayed = false
local function playIntro()
	introPlayed = true
	task.spawn(function()
		local function done()
			Remotes.TutorialIntroDone:FireServer()
		end
		-- after the loading screen (it sets LoadingDone), at most 15 s
		local waited = 0
		while not player:GetAttribute("LoadingDone") and waited < 15 do
			waited += task.wait(0.1)
		end
		local plot = ownPlot()
		local origin = plot and plot:GetAttribute("Origin")
		local camera = workspace.CurrentCamera
		if typeof(origin) ~= "CFrame" or not camera then
			done()
			return
		end
		local center = (origin :: CFrame).Position
		local startCF = CFrame.lookAt(((origin :: CFrame) * CFrame.new(-45, 55, -70)).Position, center)
		local endCF = CFrame.lookAt(((origin :: CFrame) * CFrame.new(30, 30, 65)).Position, center)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = startCF
		Audio.play("Whoosh")
		local tween = TweenService:Create(camera, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			CFrame = endCF,
		})
		tween:Play()
		tween.Completed:Wait()
		camera.CameraType = Enum.CameraType.Custom
		task.wait(0.6) -- a moment for the chef's "Hi!"
		done()
	end)
end

-- GDD 7.3: the free egg says "Open (FREE)" locally while that step runs.
local function updateFreeEgg(free: boolean)
	local plaza = workspace:FindFirstChild("EggPlaza")
	local egg = plaza and plaza:FindFirstChild("Egg1")
	if not egg then
		return
	end
	for _, prompt in egg:GetChildren() do
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("EggPrompt") == nil then
			if prompt:GetAttribute("NormalText") == nil then
				prompt:SetAttribute("NormalText", prompt.ActionText)
			end
			prompt.ActionText = if free then "Open (FREE)" else prompt:GetAttribute("NormalText")
		end
	end
end

local CHEERS = { "Nice!", "Great!", "Awesome!", "Perfect!", "Well done!" }
local function showCheer()
	cheerToken += 1
	local token = cheerToken
	cheer(CHEERS[math.random(1, #CHEERS)])
	Audio.play("Chime")
	task.delay(1.4, function()
		if token == cheerToken then
			cheer(nil)
		end
	end)
end

function Tutorial.start()
	pointerGui.Parent = player:WaitForChild("PlayerGui")
	local lastStep: string? = nil
	task.spawn(function()
		while true do
			task.wait(0.2)
			local step = Tutorial.step()
			if step ~= lastStep then
				-- a finished step (not the welcome) gets a "Nice!"
				if lastStep and lastStep ~= "Welcome" then
					showCheer()
				end
				lastStep = step
				updateFreeEgg(step == "FreeEgg")
				if step == "Welcome" and not introPlayed and not State.tutorial().introDone then
					playIntro()
				end
			end
			local definition = step and TutorialConfig.Steps[step]
			local target, height = resolve(definition and definition.Target)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local stale = guide.from ~= nil and guide.from.Parent ~= root
			if target ~= guide.target or stale then
				if target then
					buildGuide(target, height)
				else
					clearGuide()
					anchor.Parent = nil
				end
			end
		end
	end)
	-- the arrow bounces, the outline and the ring pulse, the pointer follows
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if guide.arrow then
			guide.arrow.StudsOffsetWorldSpace = Vector3.new(0, guide.height + math.sin(t * 5) * 0.6, 0)
		end
		if guide.highlight then
			guide.highlight.FillTransparency = 0.55 + math.sin(t * 4) * 0.2
		end
		local ring = guide.ring
		if ring then
			local phase = (t * 1.2) % 1
			ring.Size = Vector3.new(0.2, 6 + phase * 5, 6 + phase * 5)
			ring.Transparency = 0.3 + phase * 0.65
		end
		updatePointer()
	end)
end

------------------------------------------------------------------------------------------------
-- Bubble + "Nice!"
------------------------------------------------------------------------------------------------
local PICTURE_SLOTS = 5
local DOT = 12

function Tutorial.render(): Frame
	local function definition(): any?
		local step = Tutorial.step()
		if not step then
			return nil
		end
		return TutorialConfig.Steps[step]
	end
	local shown = spring(function()
		return if definition() ~= nil then 1 else 0
	end, 0.25, 0.6)

	-- step dots: only for the main steps (●●●○○○○), the Welcome step has none
	local function mainIndex(): number?
		return table.find(TutorialConfig.Main, Tutorial.step() or "")
	end
	local function onMainStep(): boolean
		local index = mainIndex()
		return index ~= nil and index > 1
	end
	local dots = {}
	for i = 1, #TutorialConfig.Main - 1 do
		table.insert(dots, create "Frame" {
			Name = "Dot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(DOT, DOT),
			BackgroundColor3 = function()
				local index = mainIndex()
				return if index and index - 1 >= i then GOLD else C.Ink
			end,
			create "UICorner" { CornerRadius = UDim.new(0.5, 0) },
			Kit.outline(nil, 2),
		})
	end

	-- mini picture: icons and signs ("+", "=", ">")
	local slots = {}
	for i = 1, PICTURE_SLOTS do
		local function entry(): string?
			local d = definition()
			return d and d.Picture and d.Picture[i]
		end
		local function isIcon(): boolean
			local e = entry()
			return e ~= nil and Ui.Icons[e] ~= nil
		end
		table.insert(slots, create "Frame" {
			Name = "Slot" .. i,
			LayoutOrder = i,
			Size = function()
				return if isIcon() then UDim2.fromOffset(40, 40) else UDim2.fromOffset(18, 40)
			end,
			BackgroundTransparency = 1,
			Visible = function()
				return entry() ~= nil
			end,
			create "ImageLabel" {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = function()
					local e = entry()
					return if e and Ui.Icons[e] then Ui.Icons[e] else ""
				end,
				Visible = isIcon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			},
			Kit.text {
				Text = function()
					return if isIcon() then "" else entry() or ""
				end,
				TextSize = 22,
				TextColor3 = GOLD,
				Gradient = false,
				Visible = function()
					return not isIcon()
				end,
				ZIndex = 3,
			},
		})
	end

	local cheerLayer = create "Frame" {
		Name = "CheerBurst",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
	} :: Frame
	Vide.effect(function()
		if cheer() then
			Kit.burst(cheerLayer, UDim2.new(0.5, 0, 0, 128), GOLD, 12, 1.4)
		end
	end)
	local cheerPop = spring(function()
		return if cheer() then 1 else 0
	end, 0.2, 0.45)

	return create "Frame" {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = function()
			return UDim2.new(0.5, 0, 0, Kit.topbarCenter() + 82)
		end,
		Size = UDim2.fromOffset(640, 170),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Kit.scale(),
		-- the chef bubble
		create "Frame" {
			Name = "Bubble",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(640, 90),
			BackgroundTransparency = 1,
			Visible = function()
				return shown() > 0.02
			end,
			create "UIScale" {
				Scale = function()
					return math.max(0, shown())
				end,
			},
			Kit.darkBox {
				Name = "Box",
				Size = UDim2.fromScale(1, 1),
				Fill = C.Panel,
				Transparency = Theme.PanelTransparency,
				Line = GOLD,
				create "ImageLabel" {
					Name = "Chef",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(44, 45),
					Size = UDim2.fromOffset(76, 76),
					BackgroundTransparency = 1,
					Image = Ui.Icons.Chefs,
					ScaleType = Enum.ScaleType.Fit,
					Rotation = function()
						return math.sin(wave() * 3) * 6 -- the chef waves
					end,
					ZIndex = 3,
				},
				Kit.text {
					Name = "Text",
					Text = function()
						local d = definition()
						return if d then d.Text else ""
					end,
					TextSize = 24,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = function()
						return UDim2.fromOffset(90, if onMainStep() then 6 else 0)
					end,
					Size = function()
						return UDim2.new(1, -390, if onMainStep() then 0.68 else 1, 0)
					end,
					ZIndex = 3,
				},
				create "Frame" {
					Name = "Dots",
					Position = UDim2.new(0, 90, 1, -24),
					Size = UDim2.fromOffset(200, DOT),
					BackgroundTransparency = 1,
					Visible = onMainStep,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					dots,
				},
				create "Frame" {
					Name = "Picture",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -124, 0.5, 0),
					Size = UDim2.fromOffset(220, 44),
					BackgroundTransparency = 1,
					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					slots,
				},
				-- SKIP TUTORIAL (decision 2026-11-15): skips the whole tutorial; the first tap asks "SURE?"
				Kit.button {
					Name = "Skip",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(104, 40),
					TextSize = 14,
					Color = function()
						return if confirmSkip() then "Red" else "Gray"
					end,
					Text = function()
						return if confirmSkip() then "SURE?" else "SKIP TUTORIAL"
					end,
					Activated = function()
						if confirmSkip() then
							confirmSkip(false)
							Remotes.TutorialSkip:FireServer()
						else
							confirmSkip(true)
							task.delay(3, function()
								confirmSkip(false)
							end)
						end
					end,
					ZIndex = 4,
				},
			},
		},
		-- "Nice!" under the bubble
		Kit.text {
			Name = "Cheer",
			Text = function()
				return cheer() or ""
			end,
			TextSize = 48,
			StrokeThickness = 4,
			Gradient = ColorSequence.new(Color3.fromHex("FFF38A"), Color3.fromHex("F4A91C")),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.fromOffset(400, 56),
			Visible = function()
				return cheerPop() > 0.02
			end,
			ZIndex = 8,
			create "UIScale" {
				Scale = function()
					return math.max(0, cheerPop())
				end,
			},
		},
		cheerLayer,
	} :: Frame
end

return Tutorial
