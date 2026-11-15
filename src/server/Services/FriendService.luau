-- GDD 8: Friend Boost. Minden Roblox barát ugyanazon a szerveren +FriendBoostPerFriend eladási ár,
-- legfeljebb +FriendBoostMax (Config.Game). A SellService az eladásnál szorozza (FriendService.moneyBonus).
-- A kliens a játékos "FriendBoost" attribútumából (a barátok száma a szerveren) írja ki a HUD-on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)

local FriendService = {}

-- játékos → a szerveren lévő barátai
local friends: { [Player]: { [Player]: true } } = {}

local function refresh(player: Player)
	local set = friends[player]
	local count = 0
	if set then
		for _ in set do
			count += 1
		end
	end
	player:SetAttribute("FriendBoost", count)
end

-- Pénzszorzó a szerveren lévő barátokból (1 = nincs bónusz).
function FriendService.moneyBonus(player: Player): number
	return Formulas.friendMoneyBonus(player:GetAttribute("FriendBoost") or 0)
end

local function onAdded(player: Player)
	friends[player] = friends[player] or {}
	refresh(player)
	for _, other in Players:GetPlayers() do
		if other == player or not friends[other] then
			continue
		end
		-- IsFriendsWith hálózati hívás (vár, hibázhat): ilyenkor nem számít barátnak
		local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
		if ok and isFriend and friends[player] and friends[other] then
			friends[player][other] = true
			friends[other][player] = true
			refresh(player)
			refresh(other)
		end
	end
end

function FriendService.start()
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local set = friends[player]
		friends[player] = nil
		if set then
			for other in set do
				if friends[other] then
					friends[other][player] = nil
					refresh(other)
				end
			end
		end
	end)
end

return FriendService
