-- Egyszerű BillboardGui feliratok a 3D világba (GDD 9.5).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)

local Palette = Config.Palette

export type Line = {
	name: string,
	color: Color3?,
	height: number, -- a billboard magasságának hányad része
	icon: string?,
}

export type Options = {
	offset: Vector3,
	size: Vector2, -- studban
	lines: { Line },
	maxDistance: number?,
}

local Billboard = {}

function Billboard.new(adornee: BasePart, options: Options): { [string]: TextLabel }
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(options.size.X, options.size.Y) -- BillboardGui-nál a Scale studban értendő
	gui.StudsOffsetWorldSpace = options.offset
	gui.LightInfluence = 0
	gui.MaxDistance = options.maxDistance or 160
	gui.Adornee = adornee

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local labels = {}
	for index, line in options.lines do
		local label = Instance.new("TextLabel")
		label.Name = line.name
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(1, line.height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line.color or Palette.White
		Ui.worldText(label)
		label.Text = ""
		if line.icon then
			local row = Instance.new("Frame")
			row.Name = line.name .. "Row"
			row.LayoutOrder = index
			row.Size = label.Size
			row.BackgroundTransparency = 1
			row.Parent = gui
			local icon = Ui.icon(line.icon, 0)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Parent = row
			label.Parent = row

			-- Use stud-space proportions so the icon and text stay centred at any distance.
			local rowWidth, rowHeight = options.size.X, options.size.Y * line.height
			local function sync()
				local showIcon = label:GetAttribute("ShowIcon") == true and label.Text ~= ""
				icon.Visible = showIcon
				if not showIcon then
					label.AnchorPoint = Vector2.zero
					label.Position = UDim2.fromScale(0, 0)
					label.Size = UDim2.fromScale(1, 1)
					label.TextXAlignment = Enum.TextXAlignment.Center
					return
				end
				local bounds = TextService:GetTextSize(label.Text, 100, Enum.Font.FredokaOne, Vector2.new(100000, 1000))
				local aspect = bounds.X / math.max(bounds.Y, 1)
				local height = math.min(rowHeight, rowWidth / (aspect + 1.1))
				local iconSize, gap = height * 0.9, height * 0.2
				local textWidth = height * aspect
				local left = (rowWidth - iconSize - gap - textWidth) / 2
				icon.Position = UDim2.fromScale(left / rowWidth, 0.5)
				icon.Size = UDim2.fromScale(iconSize / rowWidth, iconSize / rowHeight)
				label.AnchorPoint = Vector2.new(0, 0.5)
				label.Position = UDim2.fromScale((left + iconSize + gap) / rowWidth, 0.5)
				label.Size = UDim2.fromScale(textWidth / rowWidth, height / rowHeight)
				label.TextXAlignment = Enum.TextXAlignment.Left
			end
			label:GetPropertyChangedSignal("Text"):Connect(sync)
			label:GetAttributeChangedSignal("ShowIcon"):Connect(sync)
			sync()
		else
			label.Parent = gui
		end
		labels[line.name] = label
	end

	gui.Parent = adornee
	return labels
end

return Billboard
