-- Only show the labels of your own plot: the texts above the pads, ovens and boards of other players' plots
-- (and of free plots) are hidden for the local player. The plot's name sign (SignPost) stays visible.
-- BillboardGuis are hidden with PlayerToHideFrom (the server only toggles Enabled, e.g. the "!" alerts),
-- SurfaceGuis with Enabled (the server never toggles those).
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PlotLabelsController = {}

local function isMine(plot: Instance): boolean
	return plot:GetAttribute("OwnerId") == player.UserId
end

local function apply(gui: Instance, plot: Instance)
	if gui:FindFirstAncestor("SignPost") then
		return
	end
	local show = isMine(plot)
	if gui:IsA("BillboardGui") then
		gui.PlayerToHideFrom = if show then nil else player
	elseif gui:IsA("SurfaceGui") then
		gui.Enabled = show
	end
end

local function watch(plot: Instance)
	local function refresh()
		for _, d in plot:GetDescendants() do
			apply(d, plot)
		end
	end
	plot:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
	plot.DescendantAdded:Connect(function(d)
		apply(d, plot)
	end)
	refresh()
end

function PlotLabelsController.init()
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots")
		plots.ChildAdded:Connect(watch)
		for _, plot in plots:GetChildren() do
			watch(plot)
		end
	end)
end

return PlotLabelsController
