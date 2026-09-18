-- Napi jutalmak konfigurációja
local DailyRewards = {}

DailyRewards.cooldown = 86400 -- 24 óra másodpercben

DailyRewards.days = {
	{
		day = 1,
		title = "Day 1",
		rewardType = "cash",
		amount = 1000,
		displayReward = "$1K",
		color = Color3.fromRGB(32, 90, 42),
		emoji = "💵",
	},
	{
		day = 2,
		title = "Day 2",
		rewardType = "power",
		amount = 250,
		displayReward = "+250 Power",
		color = Color3.fromRGB(115, 48, 38),
		emoji = "💪",
	},
	{
		day = 3,
		title = "Day 3",
		rewardType = "cash",
		amount = 5000,
		displayReward = "$5K",
		color = Color3.fromRGB(140, 55, 32),
		emoji = "💰",
	},
	{
		day = 4,
		title = "Day 4",
		rewardType = "power",
		amount = 1000,
		displayReward = "+1K Power",
		color = Color3.fromRGB(110, 78, 38),
		emoji = "⚡",
	},
	{
		day = 5,
		title = "Day 5",
		rewardType = "cash",
		amount = 25000,
		displayReward = "$25K",
		color = Color3.fromRGB(32, 90, 42),
		emoji = "💵",
	},
	{
		day = 6,
		title = "Day 6",
		rewardType = "speed_cash",
		amount = 50000,
		displayReward = "+Speed & $50K",
		color = Color3.fromRGB(35, 125, 95),
		emoji = "🧪",
	},
	{
		day = 7,
		title = "Day 7",
		rewardType = "jackpot",
		amount = 200000,
		displayReward = "OP Pet",
		subReward = "+Slot & $200K",
		color = Color3.fromRGB(98, 32, 140),
		emoji = "🐾",
		isBig = true,
	},
}

return DailyRewards

