-- Egyszerű signal implementáció (függőség nélkül)
-- Használat:
--   local Signal = require(...)
--   local sig = Signal.new()
--   local conn = sig:Connect(function(a) end)
--   sig:Fire(1)
--   conn:Disconnect()

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Signal:Connect - függvény kell")
	table.insert(self._handlers, fn)
	return {
		Disconnect = function()
			local index = table.find(self._handlers, fn)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in ipairs(table.clone(self._handlers)) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Signal] handler hiba: " .. tostring(err))
		end
	end
end

return Signal
