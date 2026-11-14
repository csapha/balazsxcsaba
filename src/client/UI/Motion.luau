local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))

local Motion = {}

Motion.CLOSE_TOTAL = 0.3

local OPEN_TIME = 0.42
local CLOSE_TIME = 0.18

export type Anim = {
	opened: () -> boolean,
	appear: (openDelay: number, closeDelay: number?, style: Enum.EasingStyle?, openTime: number?, closeTime: number?) -> () -> number,
	stagger: (index: number, count: number, extraDelay: number?, style: Enum.EasingStyle?) -> () -> number,
	window: () -> number,
	scale: () -> number,
}

function Motion.tweened(initial: number): (() -> number, (target: number, info: TweenInfo) -> ())
	local holder = Instance.new("NumberValue")
	holder.Value = initial
	local value = Vide.source(initial)
	local connection = holder.Changed:Connect(value)
	local tween: Tween? = nil
	Vide.cleanup(function()
		if tween then
			tween:Cancel()
		end
		connection:Disconnect()
		holder:Destroy()
	end)
	return value, function(target: number, info: TweenInfo)
		if tween then
			tween:Cancel()
		end
		tween = TweenService:Create(holder, info, { Value = target })
		tween:Play()
	end
end

-- Add or remove many elements in batches: doing it in one frame caused a ~40 ms hitch.
function Motion.reveal(opened: () -> boolean, first: number, total: number, delay: number, batch: number): () -> number
	local count = Vide.source(first)
	local token = 0
	Vide.effect(function()
		local open = opened()
		token += 1
		local current = token
		local target = if open then total else first
		task.delay(if open then delay else Motion.CLOSE_TOTAL, function()
			while current == token and Vide.untrack(count) ~= target do
				local now = Vide.untrack(count)
				count(if now < target then math.min(target, now + batch) else math.max(target, now - batch))
				RunService.Heartbeat:Wait()
			end
		end)
	end)
	return count
end

function Motion.anim(opened: () -> boolean): Anim
	local function appear(openDelay: number, closeDelay: number?, style: Enum.EasingStyle?, openTime: number?, closeTime: number?)
		local value, to = Motion.tweened(0)
		Vide.effect(function()
			if opened() then
				to(1, TweenInfo.new(openTime or OPEN_TIME, style or Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, openDelay))
			else
				to(0, TweenInfo.new(closeTime or CLOSE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, closeDelay or 0))
			end
		end)
		return value
	end
	local window = appear(0, 0.05, Enum.EasingStyle.Back, OPEN_TIME, 0.23)
	return {
		opened = opened,
		appear = appear,
		stagger = function(index: number, count: number, extraDelay: number?, style: Enum.EasingStyle?)
			return appear(0.1 + 0.07 * (index - 1) + (extraDelay or 0), 0.03 * (count - index), style)
		end,
		window = window,
		scale = function()
			return if opened() then 0.35 + 0.65 * window() else window()
		end,
	}
end

return Motion
