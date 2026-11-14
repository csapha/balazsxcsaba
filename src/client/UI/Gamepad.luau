local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))

local create = Vide.create
local source = Vide.source
local read = Vide.read

local Gamepad = {}

export type Mode = "Gamepad" | "Touch" | "Keyboard"

Gamepad.Keys = {
	Roll = Enum.KeyCode.ButtonR2,
	Auto = Enum.KeyCode.ButtonL2,
	Close = Enum.KeyCode.ButtonB,
	Skills = Enum.KeyCode.ButtonY,
	Index = Enum.KeyCode.ButtonX,
}

local function modeOf(inputType: Enum.UserInputType): Mode?
	if inputType.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType == Enum.UserInputType.Keyboard or inputType.Name:sub(1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

local function initialMode(): Mode
	local last = modeOf(UserInputService:GetLastInputType())
	if last then
		return last
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		return "Gamepad"
	end
	return if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "Keyboard"
end

Gamepad.mode = source(initialMode())
local revision = source(0)

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	local mode = modeOf(inputType)
	if mode and mode ~= Gamepad.mode() then
		Gamepad.mode(mode)
		revision(revision() + 1)
	end
end)
UserInputService.GamepadConnected:Connect(function()
	revision(revision() + 1)
end)
UserInputService.GamepadDisconnected:Connect(function()
	revision(revision() + 1)
end)

function Gamepad.active(): boolean
	return Gamepad.mode() == "Gamepad"
end

local XBOX_DPAD = {
	[Enum.KeyCode.DPadLeft] = "rbxassetid://129362582510012",
	[Enum.KeyCode.DPadUp] = "rbxassetid://102140941895492",
	[Enum.KeyCode.DPadRight] = "rbxassetid://105873216983085",
	[Enum.KeyCode.DPadDown] = "rbxassetid://113502818263585",
}

function Gamepad.image(keyCode: Enum.KeyCode): string
	local _ = revision()
	local ok, image = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
	if not ok or type(image) ~= "string" then
		return ""
	end
	if XBOX_DPAD[keyCode] and image:find("XboxController", 1, true) then
		return XBOX_DPAD[keyCode]
	end
	return image
end

function Gamepad.glyph(props: { [any]: any }): Frame
	local key = props.Key
	local z = props.ZIndex or 1
	local function image(): string
		local code = read(key)
		return if code then Gamepad.image(code) else ""
	end
	local out: { [any]: any } = {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(28, 28),
		Visible = function()
			return Gamepad.active() and read(key) ~= nil
		end,
		create "ImageLabel" {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Fit,
			Image = image,
			ImageColor3 = Color3.fromHex("0B0A12"),
			ImageTransparency = 0.35,
			ZIndex = z,
		},
		create "ImageLabel" {
			Name = "Image",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Fit,
			Image = image,
			ZIndex = z + 1,
		},
	}
	for k, v in props do
		if type(k) == "number" then
			table.insert(out, v)
		elseif k ~= "Key" then
			out[k] = v
		end
	end
	return create "Frame"(out) :: Frame
end

function Gamepad.after(key: any, size: number?): Frame
	local pixels = size or 30
	local glyph = Gamepad.glyph {
		Key = key,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(pixels, pixels),
		ZIndex = 6,
	}
	local connections = {}
	local function place(label: TextLabel)
		-- TextBounds and AbsoluteSize are both screen pixels, so their ratio is scale independent.
		local width = if label.AbsoluteSize.X > 0 then label.TextBounds.X / label.AbsoluteSize.X else 0
		local start = if label.TextXAlignment == Enum.TextXAlignment.Left then width else 0.5 + width / 2
		glyph.Position = UDim2.new(start, 8, 0.5, 0)
		glyph.Parent = label
	end
	glyph.AncestryChanged:Connect(function()
		if #connections > 0 then
			return
		end
		local parent = glyph.Parent
		local label = if parent and parent:IsA("TextLabel") then parent
			elseif parent then parent:FindFirstChild("Label", true) :: TextLabel?
			else nil
		if not label or not label:IsA("TextLabel") then
			return
		end
		for _, property in { "TextBounds", "AbsoluteSize" } do
			table.insert(connections, label:GetPropertyChangedSignal(property):Connect(function()
				place(label)
			end))
		end
		place(label)
	end)
	Vide.cleanup(function()
		for _, c in connections do
			c:Disconnect()
		end
	end)
	return glyph
end

return Gamepad
