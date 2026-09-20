-- Edzés: a hotbarban lévő "Train" Tool (guggolás) + passzív Erő.
-- A szerver validálja a kattintások ütemét, a kliens csak jelzést küld.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local TrainingService = {}

local TOOL_NAME = "Train"
local lastTap = {} -- [userId] = os.clock()

local function buildTrainTool()
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Equip to start training"
	return tool
end

local function give(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild(TOOL_NAME) then
		return
	end
	if player.Character and player.Character:FindFirstChild(TOOL_NAME) then
		return
	end
	local tool = buildTrainTool()
	tool.Parent = backpack
	-- NEM adjuk a kézbe: a játékos veszi elő a hotbarból (1), akkor indul az edzés
end

local function onTap(player)
	if not PlayerData.isLoaded(player) then
		return
	end

	-- A kliens csak akkor kaphat Power-t, ha a szerver szerint is kézben van a Train Tool.
	local character = player.Character
	local equippedTool = character and character:FindFirstChild(TOOL_NAME)
	if not equippedTool or not equippedTool:IsA("Tool") then
		return
	end

	local now = os.clock()
	if now - (lastTap[player.UserId] or 0) < GameConfig.TrainTapMinInterval then
		return
	end
	lastTap[player.UserId] = now

	local gain = PlayerData.getTapGain(player)
	PlayerData.addPower(player, gain)
	PlayerData.registerTap(player)
	PlayerData.sync(player)
end

function TrainingService.init()
	Net.get("TrainTap").OnServerEvent:Connect(onTap)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			give(player)
		end)
		task.wait(0.2)
		give(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		give(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTap[player.UserId] = nil
	end)

	-- passzív Erő minden másodpercben
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local passive = PlayerData.getPassivePerSecond(player)
				if passive > 0 then
					PlayerData.addPower(player, passive)
					PlayerData.sync(player)
				end
			end
		end
	end)
end

return TrainingService
