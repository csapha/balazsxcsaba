-- Általános játékbeállítások
-- Itt vannak a globális konstansok (időzítők, limitek, nevek).
-- A könnyű hangolhatóság kedvéért minden "varázsszám" itt legyen.

return {
	-- adatkezelés
	Persistence = false, -- egyelőre session-only (nincs DataStore mentés)
	DataStoreName = "PlayerData_v1",
	SaveInterval = 60, -- másodperc

	-- bányászat
	HitCooldown = 0.4, -- ennyi mp-en belül nem lehet újra ütni (szerver-oldali limit)
	MineTemplateName = "MineRock", -- legacy fallback (ha nincs a Map alatt)
	MineReach = 14, -- ezen a távolságon (stud) belül lehet ütni
	SwingTime = 0.36, -- a kliens swing animáció hossza (mp)

	-- struktúra (Workspace / ServerStorage alatt)
	Paths = {
		Mine = { "Map", "Mine", "MineRock" },
		Drops = { "Drops" },
		PickaxeTemplates = { "Templates", "Pickaxes", "DefaultPickaxe" },
		GemTemplates = { "Templates", "Gems" },
	},

	-- swing animáció (ha üres -> beépített procedurális swing)
	-- Publikált animáció ID-t ide írj, pl. "rbxassetid://123456789"
	SwingAnimationId = "",

	-- érc (drop)
	OreFolderName = "Ores",
	OreLifetime = 120, -- ennyi mp után eltűnik a földről
	OreOwnerLock = 45, -- ennyi mp-ig csak a bányász veheti fel
	OreMagnetTime = 0.35, -- felvételkor a gem ennyi ideig repül a játékoshoz
	EffectBroadcastRange = 160, -- ennyi studon belül látják mások az ütés effektjét

	-- gazdaság
	StartCash = 0,

	-- színek (UI)
	Colors = {
		Panel = Color3.fromRGB(24, 27, 43),
		PanelLight = Color3.fromRGB(38, 43, 66),
		Text = Color3.fromRGB(240, 244, 255),
		Accent = Color3.fromRGB(116, 210, 250),
		Gold = Color3.fromRGB(255, 212, 71),
		Good = Color3.fromRGB(80, 220, 140),
		Bad = Color3.fromRGB(235, 100, 100),
	},
}
