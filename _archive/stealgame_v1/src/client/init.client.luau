-- Kliens belépési pont
-- Nincs HUD: mining interakció + világ-effektek.

local Controllers = script:WaitForChild("Controllers")

local MiningController = require(Controllers:WaitForChild("MiningController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))

MiningController.init()
EffectsController.init()
