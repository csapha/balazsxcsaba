-- Kliens belépési pont
local Controllers = script:WaitForChild("Controllers")

local HudController = require(Controllers:WaitForChild("HudController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))
local TrainingController = require(Controllers:WaitForChild("TrainingController"))
local SqueezeController = require(Controllers:WaitForChild("SqueezeController"))

local hud = HudController.init()
EffectsController.init()
TrainingController.init(hud)
SqueezeController.init(hud)
