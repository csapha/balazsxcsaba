-- Szám formázás (1.2K, 3.4M, 5.6B)
local Format = {}

function Format.number(n)
	n = math.floor(tonumber(n) or 0)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

function Format.money(n)
	return "$" .. Format.number(n)
end

return Format
