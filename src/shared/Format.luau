-- Szám formázás (1.2K, 3.4M, 5.6B, 1.2T ...)
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function truncate(n, decimalPlaces)
	local scale = 10 ^ decimalPlaces
	return math.floor(n * scale) / scale
end

function Format.number(n)
	n = tonumber(n) or 0
	local negative = n < 0
	n = math.abs(n)

	local suffixIndex = 1
	while n >= 1000 and suffixIndex < #SUFFIXES do
		n /= 1000
		suffixIndex += 1
	end

	local text
	if suffixIndex == 1 then
		text = string.format("%.0f", math.floor(n))
	else
		local decimalPlaces
		if n >= 100 then
			decimalPlaces = 0
		elseif n >= 10 then
			decimalPlaces = 1
		else
			decimalPlaces = 2
		end

		-- A Roblox leaderstats lefelé rövidít (pl. 999,999,999,500 -> 999B),
		-- ezért itt sem kerekítünk fel 1000B-re.
		text = string.format("%." .. decimalPlaces .. "f", truncate(n, decimalPlaces))
		-- Felesleges záró nullák és tizedespont levágása (pl. 1.000.000 -> 1M, 5.200.000.000 -> 5.2B)
		if string.find(text, "%.") then
			text = text:gsub("0+$", "")
			text = text:gsub("%.$", "")
		end
	end

	return (negative and "-" or "") .. text .. SUFFIXES[suffixIndex]
end

function Format.money(n)
	return "$" .. Format.number(n)
end

function Format.weight(n)
	return Format.number(n) .. " kg"
end

return Format
