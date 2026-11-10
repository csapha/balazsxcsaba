-- Szerver belépési pont: minden ModuleScript a Services mappában init()-et kap.
local Services = script:WaitForChild("Services")

for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module)
		if type(service) == "table" and service.init then
			service.init()
		end
	end
end

print("[Schnitzel] szerver elindult")
