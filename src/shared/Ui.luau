-- UI segédek: egységes font és gradiens a játékhoz.
-- A játék betűtípusa: GothamBold (címek/gombok) és Gotham (szövegek).
local Ui = {}

function Ui.applyDisplay(label)
	label.Font = Enum.Font.GothamBold
end

function Ui.applyBody(label)
	label.Font = Enum.Font.Gotham
end

-- vízszintes gradiens: széleken átlátszó, középen fekete
function Ui.applyFadeBackground(frame, centerTransparency)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, centerTransparency or 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = 0 -- vízszintes
	gradient.Parent = frame
	return gradient
end

-- szövegre: fehér -> nagyon világos (fehér gradiens)
function Ui.applyTextGradient(label)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(236, 236, 242))
	gradient.Rotation = 90
	gradient.Parent = label
	return gradient
end

return Ui
