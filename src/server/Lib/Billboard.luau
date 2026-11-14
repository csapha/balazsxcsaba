-- Egyszerű BillboardGui feliratok a 3D világba (GDD 9.5).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(ReplicatedStorage.Shared.Ui)

local Palette = Config.Palette

export type Line = {
	name: string,
	color: Color3?,
	height: number, -- a billboard magasságának hányad része
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
		label.Parent = gui
		labels[line.name] = label
	end

	gui.Parent = adornee
	return labels
end

return Billboard
