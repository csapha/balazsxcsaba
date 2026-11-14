local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.State)
local Audio = require(script.Parent.Audio)
local create = Vide.create

return function(kind: string | () -> boolean, render: (Motion.Anim) -> any, away: (() -> boolean)?, keep: boolean?)
	local function wanted(): boolean
		return if type(kind) == "function" then kind() else State.window() == kind
	end
	local function opened(): boolean
		return wanted() and not (away and away())
	end
	local name = if type(kind) == "string" then kind else "Window"
	local presented = Vide.source(false)
	local transition = 0
	local disposed = false
	Vide.cleanup(function()
		disposed = true
	end)
	local wasOpen = false
	Vide.effect(function()
		local open = opened()
		local want = wanted()
		transition += 1
		local current = transition
		if want ~= wasOpen then
			Audio.play(if want then "Open" else "Close")
			wasOpen = want
		end
		if open then
			presented(true)
		else
			task.delay(Motion.CLOSE_TOTAL, function()
				if not disposed and current == transition then
					presented(false)
				end
			end)
		end
	end)
	local function build()
		-- Plain Frame, not CanvasGroup: re-rendering the whole group every animated frame stuttered on phones.
		return create "Frame" {
			Name = name .. "Transition", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			ZIndex = 5,
			Interactable = opened,
			SelectionGroup = true,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			render(Motion.anim(opened)),
		}
	end
	if not keep then
		return Vide.show(presented, build)
	end
	-- Kept windows are built once (at mount) and only moved in / out of the GUI tree: rebuilding hundreds of
	-- instances on open and destroying them on close caused 30-40 ms hitches. Detached, they cost nothing to render.
	local content = build() :: Frame
	local holder = create "Frame" {
		Name = name .. "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	} :: Frame
	Vide.effect(function()
		content.Parent = if presented() then holder else nil
	end)
	Vide.cleanup(function()
		content:Destroy()
	end)
	return holder
end
