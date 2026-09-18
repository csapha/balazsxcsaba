-- Kliens szinkron: leaderstats + adat snapshot kiküldése.
-- Ez az egyetlen hely, ahol a szerver adatot küld a HUD-nak.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)

local ClientSync = {}

local function ensureLeaderstats(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end

	local cash = folder:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = folder
	end

	return cash
end

function ClientSync.init()
	PlayerData.Changed:Connect(function(player, data)
		local cash = ensureLeaderstats(player)
		cash.Value = math.floor(data.cash)

		local remote = Net.get("DataChanged")
		if remote then
			remote:FireClient(player, PlayerData.snapshot(player))
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		ensureLeaderstats(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		ensureLeaderstats(player)
	end
end

return ClientSync
