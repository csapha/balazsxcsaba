-- Saját, stílusos hotbar (az alap Roblox backpack/hotbar ki van kapcsolva).
-- Sötét csempék, vékony világos keret, nincs kép. Kattintásra / számra előveszi a toolt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local player = Players.LocalPlayer

local HotbarController = {}

local bar = nil
local slots = {} -- [tool] = { frame = Frame, stroke = UIStroke, label = TextLabel }

local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local COLOR_TILE = Color3.fromRGB(20, 20, 24)
local COLOR_BORDER = Color3.fromRGB(8, 8, 10)
local COLOR_TEXT_DIM = Color3.fromRGB(150, 150, 158)

local function getBackpack()
	return player:FindFirstChildOfClass("Backpack")
end

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getTools()
	local tools = {}
	local backpack = getBackpack()
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	return tools
end

local function isEquipped(tool)
	return tool.Parent == player.Character
end

local function stopPulse(slot)
	if slot.pulse then
		slot.pulse:Cancel()
		slot.pulse = nil
	end
	slot.stroke.Transparency = 0.15
end

local function startPulse(slot)
	stopPulse(slot)
	local tween = TweenService:Create(
		slot.stroke,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5 }
	)
	tween:Play()
	slot.pulse = tween
end

local function refreshSlot(tool)
	local slot = slots[tool]
	if not slot then
		return
	end
	if isEquipped(tool) then
		-- elővett: visszafogott külső keret + finoman lélegző belső glow
		slot.stroke.Color = COLOR_BORDER
		slot.stroke.Transparency = 0.0
		slot.frame.BackgroundTransparency = 0.15
		slot.label.TextColor3 = Color3.fromRGB(255, 255, 255)
		startPulse(slot)
	else
		stopPulse(slot)
		slot.stroke.Color = COLOR_BORDER
		slot.stroke.Transparency = 0.15
		slot.frame.BackgroundTransparency = 0.4
		slot.label.TextColor3 = Color3.fromRGB(228, 228, 234)
	end
end

local function equipTool(tool)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	if isEquipped(tool) then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

local function rebuild()
	if not bar then
		return
	end

	for _, child in ipairs(bar:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	slots = {}

	for index, tool in ipairs(getTools()) do
		local frame = Instance.new("Frame")
		frame.Name = tool.Name
		frame.Size = UDim2.fromOffset(64, 64)
		frame.BackgroundColor3 = COLOR_TILE
		frame.BackgroundTransparency = 0.4
		frame.BorderSizePixel = 0
		frame.LayoutOrder = index
		frame.Parent = bar

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLOR_BORDER
		stroke.Thickness = 2
		stroke.Transparency = 0.1
		stroke.Parent = frame

		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.fromRGB(40, 40, 46), Color3.fromRGB(10, 10, 14))
		shade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.3),
		})
		shade.Rotation = 90
		shade.Parent = frame

		local outline = Instance.new("TextLabel")
		outline.AnchorPoint = Vector2.new(0.5, 0.5)
		outline.Position = UDim2.fromScale(0.5, 0.5)
		outline.Size = UDim2.new(1, -8, 0, 20)
		outline.BackgroundTransparency = 1
		outline.Font = Enum.Font.GothamBold
		outline.TextSize = 13
		outline.TextColor3 = Color3.fromRGB(0, 0, 0)
		outline.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		outline.TextStrokeTransparency = 0
		outline.Text = string.upper(tool.Name)
		outline.Parent = frame
		Ui.applyDisplay(outline)

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.new(1, -8, 0, 20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Text = string.upper(tool.Name)
		label.Parent = frame
		Ui.applyDisplay(label)
		local labelGradient = Ui.applyTextGradient(label)
		labelGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(246, 246, 250)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 206)),
		})
		labelGradient.Rotation = 90

		local number = Instance.new("TextLabel")
		number.Size = UDim2.fromOffset(14, 14)
		number.Position = UDim2.fromOffset(5, 4)
		number.BackgroundTransparency = 1
		number.Font = Enum.Font.GothamBold
		number.TextSize = 11
		number.TextColor3 = COLOR_TEXT_DIM
		number.Text = tostring(index)
		number.Parent = frame
		Ui.applyDisplay(number)

		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = frame
		button.MouseButton1Click:Connect(function()
			equipTool(tool)
		end)
		button.MouseEnter:Connect(function()
			if not isEquipped(tool) then
				frame.BackgroundTransparency = 0.25
			end
		end)
		button.MouseLeave:Connect(function()
			refreshSlot(tool)
		end)

		slots[tool] = { frame = frame, stroke = stroke, label = label }
		refreshSlot(tool)
	end
end

local function hookContainer(container)
	if not container then
		return
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			rebuild()
		end
	end)
	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			rebuild()
		end
	end)
end

function HotbarController.init()
	-- alap Roblox hotbar/backpack kikapcsolása
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SqueezeHotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.Size = UDim2.fromOffset(0, 64)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	hookContainer(getBackpack())
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			hookContainer(child)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		hookContainer(character)
		task.wait(0.2)
		rebuild()
	end)

	if player.Character then
		hookContainer(player.Character)
	end

	-- számbillentyűk: 1..9 előveszi a megfelelő toolt
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local index = table.find(NUMBER_KEYS, input.KeyCode)
		if not index then
			return
		end
		local tools = getTools()
		local tool = tools[index]
		if tool then
			equipTool(tool)
		end
	end)

	task.wait(0.5)
	rebuild()
end

return HotbarController
