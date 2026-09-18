-- Szerver belépési pont
local Services = script:WaitForChild("Services")

local ClientSync = require(Services:WaitForChild("ClientSync"))
local WorldService = require(Services:WaitForChild("WorldService"))
local TrainingService = require(Services:WaitForChild("TrainingService"))
local SqueezeService = require(Services:WaitForChild("SqueezeService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local GachaService = require(Services:WaitForChild("GachaService"))
local RebirthService = require(Services:WaitForChild("RebirthService"))

-- init sorrend: adat -> világ -> logika
ClientSync.init()
WorldService.build()
TrainingService.init()
SqueezeService.init()
EconomyService.init()
GachaService.init()
RebirthService.init()

print("[SQUEEZE] Server initialized successfully")
