-- Remote-ok központi kezelése
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"DataChanged", -- szerver -> kliens: teljes snapshot
	"Notify", -- szerver -> kliens: üzenet
	"TrainTap", -- kliens -> szerver: edzés kattintás
	"SqueezeStart", -- kliens -> szerver: szorítás kezdése (objectId)
	"SqueezeTick", -- kliens -> szerver: szorítás kattintás
	"SqueezeState", -- szerver -> kliens: bar állapot / eredmény
	"BuyUpgrade", -- kliens -> szerver: fejlesztés vásárlás (kind, id)
	"Popup", -- szerver -> kliens: jutalom popup (position, text, color)
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
