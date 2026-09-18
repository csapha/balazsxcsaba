-- Remote-ok központi kezelése.
-- A szerver létrehozza a ReplicatedStorage.Remotes alatt, a kliens vár rá.
-- Így mindkét oldalon ugyanazok a nevek, nincs elgépelés.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"DataChanged", -- szerver -> kliens: teljes adat snapshot
	"Notify", -- szerver -> kliens: üzenet a HUD-ra
	"MineRequest", -- kliens -> szerver: ütés (célirány)
	"OreMined", -- szerver -> kliens: ütés történt (effekthez)
	"OrePicked", -- szerver -> kliens: felvétel történt (effekthez)
	"BuyPickaxe", -- kliens -> szerver: csákány vásárlás
	"SellOre", -- kliens -> szerver: érc eladás
}

local Net = {}

local function getFolder()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder and RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	return folder or ReplicatedStorage:WaitForChild("Remotes", 15)
end

if RunService:IsServer() then
	local folder = getFolder()
	for _, name in ipairs(REMOTE_NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.get(name)
	local folder = getFolder()
	if not folder then
		return nil
	end
	return folder:WaitForChild(name, 15)
end

return Net
