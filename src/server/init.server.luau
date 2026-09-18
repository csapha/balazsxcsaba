-- Szerver belépési pont
local Services = script:WaitForChild("Services")

local ClientSync = require(Services:WaitForChild("ClientSync"))
local WorldService = require(Services:WaitForChild("WorldService"))
local TrainingService = require(Services:WaitForChild("TrainingService"))
local SqueezeService = require(Services:WaitForChild("SqueezeService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))

-- init sorrend: adat -> világ -> logika
ClientSync.init()
WorldService.build()
TrainingService.init()
SqueezeService.init()
EconomyService.init()

print("[SQUEEZE] szerver elindult")
