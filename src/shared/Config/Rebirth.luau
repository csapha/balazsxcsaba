-- Rebirth ("New Hands") Configuration (Design Doc 4.7)
local Rebirth = {}

Rebirth.multiplierPerRebirth = 1.5

-- Power requirements for each rebirth level
Rebirth.requirements = {
	[1] = 50000, -- Rebirth 1
	[2] = 250000, -- Rebirth 2
	[3] = 1500000, -- Rebirth 3
	[4] = 10000000, -- Rebirth 4
	[5] = 75000000, -- Rebirth 5
	[6] = 500000000, -- Rebirth 6
}

function Rebirth.getPowerRequired(currentRebirths)
	local targetRebirth = currentRebirths + 1
	if Rebirth.requirements[targetRebirth] then
		return Rebirth.requirements[targetRebirth]
	end
	-- Exponential scaling for higher tiers
	return math.floor(500000000 * (4 ^ (targetRebirth - 6)))
end

function Rebirth.getMultiplier(currentRebirths)
	return 1.0 + (currentRebirths * Rebirth.multiplierPerRebirth)
end

-- Exclusive glove skins unlocked per rebirth
Rebirth.skins = {
	[0] = { id = "Skin_Default", name = "Default Hands", color = Color3.fromRGB(230, 200, 160), emoji = "👐" },
	[1] = { id = "Skin_Gold", name = "Golden Touch", color = Color3.fromRGB(255, 215, 0), emoji = "✨" },
	[2] = { id = "Skin_Magma", name = "Magma Grip", color = Color3.fromRGB(255, 75, 20), emoji = "🔥" },
	[3] = { id = "Skin_Neon", name = "Cyber Neon", color = Color3.fromRGB(0, 240, 255), emoji = "⚡" },
	[4] = { id = "Skin_Void", name = "Void Squeeze", color = Color3.fromRGB(155, 45, 245), emoji = "🌌" },
	[5] = { id = "Skin_Celestial", name = "Celestial God", color = Color3.fromRGB(255, 255, 255), emoji = "👑" },
}

function Rebirth.getSkin(currentRebirths)
	if Rebirth.skins[currentRebirths] then
		return Rebirth.skins[currentRebirths]
	end
	return Rebirth.skins[5]
end

return Rebirth

