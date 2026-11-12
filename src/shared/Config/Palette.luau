-- GDD 9.2: színpaletta (schnitzel téma) + placeholder világ-színek.
return table.freeze({
	-- UI
	Gold = Color3.fromHex("F2A93B"),
	Lemon = Color3.fromHex("FFE14D"),
	Money = Color3.fromHex("5BD94A"),
	Robux = Color3.fromHex("FFC21A"),
	Danger = Color3.fromHex("E8433A"),
	Panel = Color3.fromHex("3B2418"),
	Stroke = Color3.fromHex("2A1A10"),
	White = Color3.new(1, 1, 1),

	-- Ritkaság színek (GDD 3.4)
	RaritySilver = Color3.fromHex("C9D3DD"),
	RarityGold = Color3.fromHex("FFC93C"),
	RarityDiamond = Color3.fromHex("5CD6FF"),
	RarityNagyi = Color3.fromHex("FF6AD5"), -- szivárvány helyett egyelőre egy szín (UI-n gradiens)
	Locked = Color3.fromRGB(58, 44, 36),

	-- Placeholder világ (szürke dobozok, később modellek váltják)
	Floor = Color3.fromRGB(214, 190, 150),
	SlotMarker = Color3.fromRGB(150, 128, 98),
	Platform = Color3.fromRGB(176, 140, 104),
	ChefPad = Color3.fromRGB(120, 200, 255),
	ChefRest = Color3.fromRGB(160, 200, 160),
	Wood = Color3.fromRGB(122, 74, 34),
	Conveyor = Color3.fromRGB(64, 64, 72),
	Tray = Color3.fromRGB(200, 200, 205),
	Merge = Color3.fromRGB(122, 42, 90),
	Schnitzel = Color3.fromHex("D99A3D"),
	Ground = Color3.fromRGB(110, 160, 80),
	Street = Color3.fromRGB(90, 90, 96),
})
