-- Csak Studióban: fejlesztői parancsok a teszteléshez (pl. MCP / command bar).
-- A command bar külön module cache-t használ, ezért a játék szolgáltatásait egy BindableFunction-ön
-- (ServerStorage.DevCommand) keresztül éri el. Élesben (nem Studio) nem jön létre.
--
-- Használat (szerver oldali command bar):
--   local dev = game.ServerStorage.DevCommand
--   dev:Invoke("get")                                  -- az első játékos adatai (másolat)
--   dev:Invoke("set", { "ovens" }, { 15, 15, ... })     -- adat írása útvonalon (data.ovens(...))
--   dev:Invoke("set", { "ovenStars", 3 }, 2)            -- data.ovenStars[3](2)
--   dev:Invoke("call", "OvenService", "buy", "$state", 100, true)  -- "$state" = a játékos PlotState-je
-- Minden parancs utolsó, opcionális paramétere nélkül az első játékosra vonatkozik.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PlotService = require(script.Parent.PlotService)

local DevService = {}

local function firstState(): PlotService.PlotState?
	for _, state in PlotService.all() do
		return state
	end
	return nil
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

local commands = {}

function commands.get(state: PlotService.PlotState)
	return copy(state.data())
end

function commands.set(state: PlotService.PlotState, path: { string | number }, value: any)
	local node = state.data
	for _, key in path do
		node = node[key]
	end
	node(value)
	return copy(state.data())
end

function commands.call(state: PlotService.PlotState, serviceName: string, fnName: string, ...: any)
	local service = require(script.Parent:FindFirstChild(serviceName) :: ModuleScript) :: any
	local args = table.pack(...)
	for i = 1, args.n do
		if args[i] == "$state" then
			args[i] = state
		end
	end
	return service[fnName](table.unpack(args, 1, args.n))
end

function DevService.init()
	if not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "DevCommand"
	bindable.OnInvoke = function(command: string, ...: any)
		local handler = commands[command]
		assert(handler, `Unknown dev command: {command}`)
		local state = firstState()
		assert(state, "No player with a plot yet")
		return handler(state, ...)
	end
	bindable.Parent = ServerStorage
end

return DevService
