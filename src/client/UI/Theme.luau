local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local create = Vide.create

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromHex("0B0A12"),
	Panel = Color3.fromHex("0E1017"),
	PanelLine = Color3.fromHex("6A7080"),
	Card = Color3.fromHex("040508"),
	CardLine = Color3.fromHex("5A5F6C"),
	CardSelected = Color3.fromHex("1C4A1E"),
	CardSelectedLine = Color3.fromHex("3F7A3A"),
	Selected = Color3.fromHex("5BF03A"),
	Slot = Color3.fromHex("0E1017"),
	SlotLine = Color3.fromHex("6A7080"),
	Muted = Color3.fromHex("A9B0CC"),
	White = Color3.new(1, 1, 1),
	Money = Color3.fromHex("8BFF3D"),
	MoneyTop = Color3.fromHex("E2FF42"),
	MoneyBottom = Color3.fromHex("6EF530"),
	MoneyStroke = Color3.fromHex("0A2406"),
	Bad = Color3.fromHex("FF4545"),
	Good = Color3.fromHex("5EEB5B"),
	Mint = Color3.fromHex("7FE0C4"),
	Vanilla = Color3.fromHex("FFF4D6"),
	Lemon = Color3.fromHex("FFE066"),
	Outline = Color3.fromHex("0B0A12"),
}

Theme.PanelTransparency = 0.25
Theme.CardTransparency = 0.45
Theme.SlotTransparency = 0.35

export type Palette = { light: Color3, top: Color3, bottom: Color3, lip: Color3, weld: Color3 }
Theme.Palettes = {
	Yellow = {
		light = Color3.fromHex("FFF38A"),
		top = Color3.fromHex("FFE23A"),
		bottom = Color3.fromHex("F48E1C"),
		lip = Color3.fromHex("6E3510"),
		weld = Color3.fromHex("D9821A"),
	},
	Blue = {
		light = Color3.fromHex("8AF9FF"),
		top = Color3.fromHex("4AE9FF"),
		bottom = Color3.fromHex("2A8CF8"),
		lip = Color3.fromHex("1A4372"),
		weld = Color3.fromHex("1E78D8"),
	},
	Purple = {
		light = Color3.fromHex("FF6CF2"),
		top = Color3.fromHex("E62BD6"),
		bottom = Color3.fromHex("AE1CF4"),
		lip = Color3.fromHex("561272"),
		weld = Color3.fromHex("9A16D0"),
	},
	Pink = {
		light = Color3.fromHex("FF6AF6"),
		top = Color3.fromHex("EC2AEC"),
		bottom = Color3.fromHex("B02CF6"),
		lip = Color3.fromHex("5A1870"),
		weld = Color3.fromHex("A01CD8"),
	},
	Red = {
		light = Color3.fromHex("FF7FEA"),
		top = Color3.fromHex("FA47DC"),
		bottom = Color3.fromHex("EE2C22"),
		lip = Color3.fromHex("6A1508"),
		weld = Color3.fromHex("C81E3A"),
	},
	Green = {
		light = Color3.fromHex("C2FF8A"),
		top = Color3.fromHex("8CF54E"),
		bottom = Color3.fromHex("2DB82A"),
		lip = Color3.fromHex("185212"),
		weld = Color3.fromHex("26A022"),
	},
	-- Breadcrumb gold (the schnitzel accent colour).
	Orange = {
		light = Color3.fromHex("FFE08A"),
		top = Color3.fromHex("FFBE4A"),
		bottom = Color3.fromHex("E8781C"),
		lip = Color3.fromHex("6A3410"),
		weld = Color3.fromHex("CC6A18"),
	},
	Gray = {
		light = Color3.fromHex("C9CDD8"),
		top = Color3.fromHex("A3A8B8"),
		bottom = Color3.fromHex("6A6F82"),
		lip = Color3.fromHex("2C2F3A"),
		weld = Color3.fromHex("7C8194"),
	},
} :: { [string]: Palette }

-- A candy palette built from one colour (e.g. an event's colour from Config).
function Theme.paletteFrom(color: Color3): Palette
	local black, white = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
	return {
		light = color:Lerp(white, 0.45),
		top = color:Lerp(white, 0.18),
		bottom = color:Lerp(black, 0.18),
		lip = color:Lerp(black, 0.6),
		weld = color:Lerp(black, 0.08),
	}
end

function Theme.faceGradient(palette: Palette): ColorSequence
	return ColorSequence.new(palette.top, palette.bottom)
end

Theme.Font = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui")).Font

function Theme.corner(radius: number?): Instance
	return create "UICorner" { CornerRadius = UDim.new(0, radius or 5) }
end

function Theme.stroke(thickness: number?, color: Color3?): Instance
	return create "UIStroke" {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}
end

function Theme.textStroke(thickness: number?): Instance
	return create "UIStroke" {
		Color = Theme.Colors.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}
end

local NumberFormat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NumberFormat"))
Theme.formatNumber = NumberFormat.grouped
Theme.formatMoney = NumberFormat.money

function Theme.scaleFor(viewportHeight: number): number
	local ratio = viewportHeight / 660
	if ratio > 1 then
		ratio = 1 + (ratio - 1) * 0.4
	end
	return math.clamp(ratio, 0.55, 1.6)
end

return Theme
