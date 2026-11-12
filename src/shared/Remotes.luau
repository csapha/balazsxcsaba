-- Hálózati események (GDD 12.1 Remotes/). A szerver hozza létre, a kliens megvárja.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"RareBake", -- szerver → összes kliens: (plotIndex, slot, rarityIndex, ownerName)
	"PickedUp", -- szerver → tulajdonos: ({ { rarity: number, units: number } }) a collectorból felvett mennyiség
	"Deposited", -- szerver → tulajdonos: (plotIndex, units) a leadó asztalra tett mennyiség
	"WakeChef", -- kliens → szerver: (chefIndex) a tulajdonos felébreszt egy alvó chefet
	"ChefWoke", -- szerver → összes kliens: (plotIndex, chefIndex) "pof!" vizuál
	"RequestRebirth", -- kliens → szerver: rebirth kérés (a szerver ellenőrzi a követelményt)
	"PetAction", -- kliens → szerver: (action: "equip" | "unequip" | "delete" | "golden", arg)
	"EggOpened", -- szerver → nyitó: (eggIndex, petId) tojásnyitás animáció
	"PetHatched", -- szerver → összes kliens: (playerName, petId) legendás pet bejelentés
	"AuraAction", -- kliens → szerver: ("roll", "ticket" | "money") | ("equip", auraId) | ("unequip")
	"AuraRolled", -- szerver → dobó: (auraId, level, isNew) dobás animáció
	"AuraAnnounce", -- szerver → összes kliens: (playerName, auraId) legendás / mitikus aura
	"EventReward", -- szerver → játékos: (text, color?) felugró jutalom felirat a feje felett (event)
	"ClaimOffline", -- kliens → szerver: az offline kereset felvétele
	"BuyPerk", -- kliens → szerver: (perkId) rebirth-fa perk vásárlás tokenért
	"Rebirthed", -- szerver → tulajdonos: (rebirths, multiplier) rebirth effekt
}

local Remotes = {} :: { [string]: RemoteEvent }

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, name in EVENTS do
		local event = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		Remotes[name] = event :: RemoteEvent
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
