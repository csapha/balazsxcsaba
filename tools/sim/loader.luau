-- Betöltő a lune szimulátorhoz: a játék src/shared moduljait (Config, Formulas) tölti be változtatás nélkül.
-- A Roblox-stílusú `require(script.Parent.X)` hivatkozásokat fájlútvonalakra fordítja, és megadja a
-- szükséges Roblox globálisokat (Vector3, Color3, CFrame, Enum ... a @lune/roblox-ból).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Loader = {}

local cache: { [string]: any } = {}
local paths: { [any]: string } = {}

-- A szimulátorban a table.freeze nem fagyaszt, hogy a Config értékei futtatásonként felülírhatók
-- legyenek (pl. `Ovens.PriceGrowth=1.01`). A játékban természetesen fagyasztva maradnak.
local unfrozenTable = table.clone(table)
unfrozenTable.freeze = function(t)
	return t
end

-- A Luau standard globálisok (a betöltött modulok környezete ebből örököl)
local standard = {
	math = math,
	string = string,
	table = unfrozenTable,
	bit32 = bit32,
	utf8 = utf8,
	os = os,
	coroutine = coroutine,
	print = print,
	warn = print,
	error = error,
	assert = assert,
	pcall = pcall,
	xpcall = xpcall,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	select = select,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	unpack = table.unpack,
	-- Roblox adattípusok
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	CFrame = roblox.CFrame,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Enum = roblox.Enum,
}

-- A szimulátor "élesben" fut: nem Studio, szerver oldal.
local runService = {
	IsStudio = function()
		return false
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsRunning = function()
		return false
	end,
}
standard.game = {
	GetService = function(_self, name: string)
		if name == "RunService" then
			return runService
		end
		return {}
	end,
}

local function moduleFile(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	end
	if fs.isDir(path) and fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

-- A `script` proxy csak útvonalat épít (a lune fájlműveletei nem futhatnak metametódusban);
-- a létezést a require ellenőrzi.
local function makeScript(path: string)
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				assert(parent, `{path}: nincs szülő`)
				return makeScript(parent)
			end
			return makeScript(path .. "/" .. key)
		end,
	})
	paths[proxy] = path
	return proxy
end

-- Egy modul betöltése útvonal alapján (pl. "src/shared/Formulas" vagy "src/shared/Config").
function Loader.require(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = moduleFile(path)
	assert(file, `Nincs ilyen modul: {path}`)

	-- (a lune a környezet kulcsait másolja, metatáblát nem követ – ezért minden globálist közvetlenül adunk át)
	local environment = table.clone(standard)
	environment.script = makeScript(path)
	environment.require = function(target: any)
		local targetPath = paths[target]
		assert(targetPath, "Csak script-hivatkozással lehet require-olni")
		return Loader.require(targetPath)
	end

	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = environment })
	local result = chunk()
	cache[path] = result
	return result
end

return Loader
