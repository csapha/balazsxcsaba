-- Kliens belépési pont
local Controllers = script:WaitForChild("Controllers")

local HudController = require(Controllers:WaitForChild("HudController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))
local TrainingController = require(Controllers:WaitForChild("TrainingController"))
local SqueezeController = require(Controllers:WaitForChild("SqueezeController"))
local UpgradeController = require(Controllers:WaitForChild("UpgradeController"))
local DailyRewardController = require(Controllers:WaitForChild("DailyRewardController"))
local GachaController = require(Controllers:WaitForChild("GachaController"))
local RebirthController = require(Controllers:WaitForChild("RebirthController"))
local TeleportController = require(Controllers:WaitForChild("TeleportController"))

local hud = HudController.init()
EffectsController.init()
TrainingController.init(hud)
SqueezeController.init(hud)
UpgradeController.init(hud)
DailyRewardController.init(hud)
GachaController.init(hud)
RebirthController.init(hud)
TeleportController.init(hud)

