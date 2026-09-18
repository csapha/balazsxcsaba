-- Szerver belépési pont
-- Sorrend fontos: előbb az adat, aztán a világ, végül a logika.

local Players = game:GetService("Players")

local Services = script:WaitForChild("Services")

local PlayerData = require(Services:WaitForChild("PlayerData"))
local ClientSync = require(Services:WaitForChild("ClientSync"))
local PickaxeService = require(Services:WaitForChild("PickaxeService"))
local OreService = require(Services:WaitForChild("OreService"))
local MiningService = require(Services:WaitForChild("MiningService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))

-- init
ClientSync.init()
PickaxeService.init()
OreService.init()
MiningService.init()
EconomyService.init()

-- játékos életciklus
Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerData.load(player)
end

print("[StealAGem] szerver elindult")
