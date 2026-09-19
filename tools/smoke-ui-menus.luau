local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local controllers = StarterPlayer.StarterPlayerScripts.Client.Controllers
local UiIcons = require(Shared.UiIcons)
local MenuCoordinator = require(controllers.MenuCoordinator)

local iconHost = Instance.new("Frame")
local icon = UiIcons.create(iconHost, "upgrade", UDim2.fromOffset(58, 58), UDim2.fromOffset(0, 0), 2)
assert(icon.ImageContent.SourceType == Enum.ContentSourceType.Object, "Embedded icon was not attached")

local closed = {}
MenuCoordinator.register("smokeA", function()
	table.insert(closed, "A")
end)
MenuCoordinator.register("smokeB", function()
	table.insert(closed, "B")
end)
MenuCoordinator.opening("smokeA")
MenuCoordinator.opening("smokeB")
assert(#closed == 1 and closed[1] == "A", "Menu switching did not close the previous menu")
MenuCoordinator.closed("smokeB")

local gui = Instance.new("ScreenGui")
local hud = {
	gui = gui,
	preview = true,
	notify = function() end,
}

local UpgradeController = require(controllers.UpgradeController)
local GachaController = require(controllers.GachaController)
local RebirthController = require(controllers.RebirthController)
local TeleportController = require(controllers.TeleportController)
local DailyRewardController = require(controllers.DailyRewardController)

UpgradeController.init(hud)
GachaController.init(hud)
RebirthController.init(hud)
TeleportController.init(hud)
DailyRewardController.init(hud)

local expectedHudPositions = {
	HudUpgradeWrapper = UDim2.new(0, 20, 0.5, -43),
	GachaHudWrapper = UDim2.new(0, 106, 0.5, -43),
	RebirthHudWrapper = UDim2.new(0, 20, 0.5, 43),
	TeleportHudWrapper = UDim2.new(0, 106, 0.5, 43),
}

for name, expectedPosition in expectedHudPositions do
	local wrapper = gui:FindFirstChild(name)
	assert(wrapper, `Missing HUD button {name}`)
	assert(wrapper.Size == UDim2.fromOffset(76, 76), `Wrong compact size for {name}`)
	assert(wrapper.Position == expectedPosition, `Wrong 2x2 grid position for {name}`)
	assert(wrapper:FindFirstChild("Icon", true), `Missing embedded icon for {name}`)
end

UpgradeController.open()
assert(gui.UpgradeModalOverlay.Visible, "Upgrade menu did not open")
GachaController.open()
assert(gui.GachaModalOverlay.Visible, "Chests menu did not open")
assert(MenuCoordinator.getActiveMenu() == "chests", "Chests did not become the active menu")
GachaController.toggle()
assert(MenuCoordinator.getActiveMenu() == nil, "Pressing the active Chests button did not close it")

RebirthController.open()
TeleportController.open()
assert(gui.TeleportModalOverlay.Visible, "Teleport menu did not open")
assert(MenuCoordinator.getActiveMenu() == "teleport", "Teleport did not replace Rebirth")
DailyRewardController.open()
assert(gui.DailyRewardModalOverlay.Visible, "Daily Reward menu did not open")
assert(MenuCoordinator.getActiveMenu() == "dailyReward", "Daily Reward did not replace Teleport")
DailyRewardController.close()

-- Rapid A -> B -> A switching must not leave both overlays visible.
UpgradeController.open()
GachaController.open()
UpgradeController.open()
assert(gui.UpgradeModalOverlay.Visible, "Rapid switching closed the final requested menu")
assert(MenuCoordinator.getActiveMenu() == "upgrades", "Rapid switching lost the final requested menu")
UpgradeController.close()

print("SMOKE_UI_MENUS_OK")
