-- Kliens belépési pont.
local Controllers = script:FindFirstChild("Controllers")

for _, module in if Controllers then Controllers:GetChildren() else {} do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if type(controller) == "table" and controller.init then
			controller.init()
		end
	end
end

require(script:WaitForChild("UI"):WaitForChild("Hud")).mount()
