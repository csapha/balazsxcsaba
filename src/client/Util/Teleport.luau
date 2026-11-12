-- Teleport a saját telekre / a Tojás térre (GDD 9.3 navigáció).
-- A játékos a saját karakterét mozgatja (a kliens birtokolja), ezért nem kell szerver kérés.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Teleport = {}

local function moveTo(cframe: CFrame)
	local character = Players.LocalPlayer.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(cframe)
	end
end

function Teleport.home()
	local index = Players.LocalPlayer:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and index and plots:FindFirstChild(`Plot{index}`)
	local origin = plot and plot:GetAttribute("Origin")
	if typeof(origin) ~= "CFrame" then
		return
	end
	local layout = Config.Plot
	local position = layout.Spawn + Vector3.new(0, layout.FloorTop + 3, 0)
	local lookAt = layout.SpawnLookAt + Vector3.new(0, layout.FloorTop + 3, 0)
	moveTo(origin * CFrame.lookAt(position, lookAt))
end

function Teleport.eggs()
	local center = Config.Pets.Plaza.Center
	local position = center + Vector3.new(0, 3, 9)
	moveTo(CFrame.lookAt(position, center + Vector3.new(0, 3, 0)))
end

return Teleport
