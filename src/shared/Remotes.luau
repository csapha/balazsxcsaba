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
	"EggOpened", -- szerver → nyitó: (eggIndex, petId, fast?) tojásnyitás animáció (eggIndex 0 = Golden Egg)
	"PetHatched", -- szerver → összes kliens: (playerName, petId) legendás pet bejelentés
	"AuraAction", -- kliens → szerver: ("roll", "ticket" | "money") | ("equip", auraId) | ("unequip")
	"AuraRolled", -- szerver → dobó: (auraId, level, isNew) dobás animáció
	"AuraAnnounce", -- szerver → összes kliens: (playerName, auraId) legendás / mitikus aura
	"EventReward", -- szerver → játékos: (text, color?) felugró jutalom felirat a feje felett (event)
	"ClaimOffline", -- kliens → szerver: az offline kereset felvétele
	"BuyPerk", -- kliens → szerver: (perkId) rebirth-fa perk vásárlás tokenért
	"Rebirthed", -- szerver → tulajdonos: (rebirths, multiplier) rebirth effekt
	"ClaimDaily", -- kliens → szerver: a napi jutalom felvétele
	"ClaimPlaytime", -- kliens → szerver: (index) egy nyitott playtime ajándék felvétele
	"RedeemCode", -- kliens → szerver: (code) kód beváltása (Settings ablak, RewardService; GDD 5.1 ⑦)
	"CodeResult", -- szerver → játékos: (ok, message) a kód beváltás eredménye
	"SaveSettings", -- kliens → szerver: (settings) a beállítások mentése (a szerver ellenőrzi)
	"ShopBuy", -- kliens → szerver: (kind: "Pass" | "Product" | "Deal", key) vásárlás indítása (GDD 5)
	"ShopPurchased", -- szerver → vásárló: (kind, key, message) sikeres vásárlás effekt
	"FunEffect", -- szerver → összes kliens: (kind: "Tenderize" | "SchnitzelRain", playerName) troll termékek (GDD 6.3)
	"ToastSeen", -- kliens → szerver: (toastId) az ajánlat-toast megjelent, többet ne jöjjön (GDD 6.5)
	"CosmeticAction", -- kliens → szerver: ("equip" | "unequip" | "buyMoney", id) kozmetikumok (GDD 5.1 ⑥)
	"TutorialIntroDone", -- kliens → szerver: a tutorial repülő kamerája lefutott (GDD 7.2), indulhat az első lépés
	"TutorialSkip", -- kliens → szerver: a játékos átugorja az egész tutorialt (SKIP TUTORIAL gomb)
	"SeasonClaim", -- kliens → szerver: ("Free" | "Premium", tier) vagy ("All") Schnitzel Pass jutalom felvétele
	"SeasonTier", -- szerver → játékos: (tier) új Pass szint (ünneplés a Pass ikonon)
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
