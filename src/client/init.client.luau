-- Kliens belépési pont.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script:WaitForChild("Controllers")

for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if type(controller) == "table" and controller.init then
			controller.init()
		end
	end
end

-- A Data require addig vár, amíg a szerver elküldi a játékos adatát.
local data = require(ReplicatedStorage.Shared.Data).client
require(script:WaitForChild("UI"):WaitForChild("Hud")).mount(data)
