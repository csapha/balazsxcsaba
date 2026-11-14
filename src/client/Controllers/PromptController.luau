-- Custom ProximityPrompt card in the UI Kit style (from the Snowboard game). Prompts with Style = Custom use it;
-- the "Color" attribute picks the key plate palette, the "Icon" attribute an image next to the texts.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local UI = script.Parent.Parent.UI
local Audio = require(UI.Audio)
local Kit = require(UI.Kit)
local Theme = require(UI.Theme)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring
local C = Theme.Colors

local PromptController = {}

local player = Players.LocalPlayer

local CARD_H = 68
local KEY = 50
local ICON = 46
local SIZE = 0.7
local CANVAS = Vector2.new(520, 140)

local POP_OUT = 0.06
local GONE_AFTER = 0.4

type Entry = {
	unmount: () -> (),
	gui: BillboardGui?,
	connections: { RBXScriptConnection },
	bump: (number) -> (),
	gone: (number) -> (),
}
local shown: { [ProximityPrompt]: Entry } = {}

-- Vide.mount's cleanup only tears down the scope, not the BillboardGui: destroy it here or old cards linger.
local function destroy(entry: Entry)
	entry.unmount()
	if entry.gui then
		entry.gui:Destroy()
	end
end

local function hide(prompt: ProximityPrompt, instant: boolean?)
	local entry = shown[prompt]
	if not entry then
		return
	end
	shown[prompt] = nil
	for _, c in entry.connections do
		c:Disconnect()
	end
	if instant then
		destroy(entry)
		return
	end
	if entry.gui then
		entry.gui.Active = false
	end
	entry.bump(1.1)
	task.delay(POP_OUT, entry.gone, 0)
	task.delay(GONE_AFTER, destroy, entry)
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	hide(prompt, true)
	local adornee = prompt.Parent
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
		return
	end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local gamepad = inputType == Enum.ProximityPromptInputType.Gamepad
	local palette = prompt:GetAttribute("Color")
	if type(palette) ~= "string" or not Theme.Palettes[palette] then
		palette = "Yellow"
	end
	local icon = prompt:GetAttribute("Icon")

	local actionText = source(prompt.ActionText)
	local objectText = source(prompt.ObjectText)
	local hold = source(0)
	local appear = source(0.55)
	local bump = source(1)
	local gone = source(1)
	local connections: { RBXScriptConnection } = {}
	local gui: BillboardGui? = nil

	local unmount = Vide.mount(function()
		local popIn = spring(function()
			return appear() * bump()
		end, 0.22, 0.6)
		local popOut = spring(gone, 0.14, 1)
		local function scale()
			return math.max(popIn() * popOut(), 0)
		end
		-- Not Kit.darkBox: its Scale-sized inner ring feeds back into AutomaticSize and inflates the card.
		local card = create "Frame" {
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, CARD_H),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.12,
			create "UICorner" { CornerRadius = UDim.new(0, 12) },
			Kit.outline(),
			create "UIGradient" {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromHex("2A3042"), C.Panel),
			},
			create "UIScale" {
				Scale = function()
					return SIZE * Kit.screenScale() * scale()
				end,
			},
			create "UIPadding" {
				PaddingLeft = UDim.new(0, 9),
				PaddingRight = UDim.new(0, 20),
			},
			create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Kit.plate {
				Name = "Key",
				LayoutOrder = 1,
				Color = palette,
				Text = if gamepad then "" elseif touch then "TAP" else UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode),
				TextSize = if touch then 18 else 26,
				Size = UDim2.fromOffset(if touch then 62 else KEY, KEY),
				create "Frame" {
					Name = "Hold",
					Size = function()
						return UDim2.fromScale(hold(), 1)
					end,
					BackgroundColor3 = C.White,
					BackgroundTransparency = 0.45,
					ZIndex = 6,
					create "UICorner" { CornerRadius = UDim.new(0, 4) },
				},
				if gamepad
					then create "ImageLabel" {
						Name = "Glyph",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.45),
						Size = UDim2.fromScale(0.72, 0.72),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode),
						ZIndex = 7,
					}
					else nil,
			},
			if type(icon) == "string" and icon ~= ""
				then create "ImageLabel" {
					Name = "Icon",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(ICON, ICON),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = icon,
				}
				else nil,
			create "Frame" {
				Name = "Texts",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(0, CARD_H - 14),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				create "UIListLayout" {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Kit.text {
					Name = "Object",
					LayoutOrder = 1,
					Text = objectText,
					Visible = function()
						return objectText() ~= ""
					end,
					TextSize = 15,
					TextColor3 = C.Muted,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.fromOffset(0, 18),
					AutomaticSize = Enum.AutomaticSize.X,
				},
				Kit.text {
					Name = "Action",
					LayoutOrder = 2,
					Text = actionText,
					TextSize = 27,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.fromOffset(0, 30),
					AutomaticSize = Enum.AutomaticSize.X,
				},
			},
		}
		-- Sibling, not child, of the card so the UIListLayout ignores it.
		local click = create "TextButton" {
			Name = "Click",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 10,
		} :: TextButton
		local function fit()
			click.Size = UDim2.fromOffset(card.AbsoluteSize.X, card.AbsoluteSize.Y)
		end
		table.insert(connections, card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		fit()
		table.insert(connections, click.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(connections, click.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))

		local billboard = create "BillboardGui" {
			Name = "Prompt",
			Adornee = adornee :: any,
			-- Offset size: fixed pixels regardless of zoom and distance.
			Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
			StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Active = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			card,
			click,
		} :: BillboardGui
		gui = billboard
		return billboard
	end, player:WaitForChild("PlayerGui"))

	local holdStart: number? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		holdStart = os.clock()
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		holdStart = nil
		hold(0)
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function()
		if holdStart and prompt.HoldDuration > 0 then
			hold(math.clamp((os.clock() - holdStart) / prompt.HoldDuration, 0, 1))
		end
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		holdStart = nil
		hold(1)
		Audio.play("Click")
		bump(1.12)
		task.delay(0.12, function()
			bump(1)
			hold(0)
		end)
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		actionText(prompt.ActionText)
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		objectText(prompt.ObjectText)
	end))

	shown[prompt] = { unmount = unmount, gui = gui, connections = connections, bump = bump, gone = gone }
	task.defer(appear, 1)
end

function PromptController.init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		hide(prompt)
	end)
end

return PromptController
