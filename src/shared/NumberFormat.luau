-- GDD 4.5: számformátum – 1.2K, 15.6M, 3.4B, 1.1T, 2.5Qa, 7.8Qi ... max 4 értékes jegy.
local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

function NumberFormat.short(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)

	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end

	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES)
	local value = n / 10 ^ (3 * tier)
	local intDigits = #tostring(math.floor(value))
	local decimals = math.max(0, 4 - intDigits)
	local factor = 10 ^ decimals
	value = math.floor(value * factor) / factor -- lefelé kerekít, hogy ne legyen "1000K"

	local text = string.format(`%.{decimals}f`, value)
	if decimals > 0 then
		text = (text:gsub("0+$", ""))
		text = (text:gsub("%.$", ""))
	end
	return sign .. text .. SUFFIXES[tier]
end

function NumberFormat.money(n: number): string
	return "$" .. NumberFormat.short(n)
end

-- Ezres csoportosítás szóközzel (150 148), 1M felett rövid formátum.
function NumberFormat.grouped(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return NumberFormat.short(n)
	end
	local text = tostring(n)
	local result = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (result:gsub("^ ", ""))
end

return NumberFormat
