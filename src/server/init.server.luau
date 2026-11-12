-- Szerver belépési pont.
-- 1. minden Services modul betöltése, 2. init() mindegyiken (regisztrációk), 3. start() (loopok, események).
local Services = script:WaitForChild("Services")

local services = {}
for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(services, { name = module.Name, service = require(module) })
	end
end

for _, entry in services do
	if type(entry.service) == "table" and entry.service.init then
		entry.service.init()
	end
end

for _, entry in services do
	if type(entry.service) == "table" and entry.service.start then
		task.spawn(entry.service.start)
	end
end

print("[Schnitzel] szerver elindult")
