-- GDD 12.2 anti-exploit: minden kliens → szerver remote ezen keresztül fut.
--   Guard.connect(remote, handler): sebességkorlát játékosonként és remote-onként (Config.Security.RemoteLimits),
--     a túl sok kérést csendben eldobja (Studióban figyelmeztet).
--   Guard.near(player, position, distance): él-e a karakter, és elég közel van-e (Prompt / Touched mellé).
-- Az argumentumok típusát továbbra is a handler ellenőrzi (a kliens bármit küldhet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Security = Config.Security
local isStudio = RunService:IsStudio()

type Bucket = { tokens: number, at: number, warned: boolean }

local Guard = {}

-- játékos → remote neve → token bucket
local buckets: { [Player]: { [string]: Bucket } } = {}

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- Igaz, ha a kérés belefér a keretbe (és levon egy tokent).
function Guard.allow(player: Player, name: string): boolean
	local limit = Security.RemoteLimits[name] or Security.DefaultLimit
	local perPlayer = buckets[player]
	if not perPlayer then
		if not player:IsDescendantOf(Players) then
			return false
		end
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = limit.Burst, at = now, warned = false }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(limit.Burst, bucket.tokens + (now - bucket.at) * limit.Rate)
	bucket.at = now
	if bucket.tokens < 1 then
		if isStudio and not bucket.warned then
			bucket.warned = true
			warn(`[Guard] {player.Name}: too many {name} requests, dropping`)
		end
		return false
	end
	bucket.tokens -= 1
	bucket.warned = false
	return true
end

function Guard.connect(remote: RemoteEvent, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	local name = remote.Name
	return remote.OnServerEvent:Connect(function(player, ...)
		if Guard.allow(player, name) then
			handler(player, ...)
		end
	end)
end

-- A játékos (élő karakter, HumanoidRootPart) legfeljebb `distance` studra van-e a ponttól.
function Guard.near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - position).Magnitude <= distance
end

return Guard
