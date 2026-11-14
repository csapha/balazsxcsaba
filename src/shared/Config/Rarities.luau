-- GDD 3.4: schnitzel ritkaságok. Minden sütés kap egy ritkaság-dobást.
-- Chance: esély sütésenként (0..1), a "Sima" a maradék.
-- Döntés 2026-11-12: a ritkaság több darabot is ad ÉS minden darab többet is ér:
--   darab = alap darab × UnitMult,  $/darab = alap ár × ValueMult
-- A kettő szorzata a GDD 3.4 ár-szorzója (x5, x25, x150, x10 000) – a balance szimulátor (GDD 4.4)
-- szerint a korábbi 5×5 / 25×25 / 150×150 / 10 000×10 000 kb. 1000-szeresre emelte az átlagbevételt.
local Palette = require(script.Parent.Palette)

return table.freeze({
	List = table.freeze({
		table.freeze({
			Id = "Normal",
			Name = "Classic Wiener",
			Chance = 0,
			UnitMult = 1,
			ValueMult = 1,
			Color = Palette.Schnitzel,
		}),
		table.freeze({
			Id = "Silver",
			Name = "Silver Schnitzel",
			Chance = 0.03,
			UnitMult = 2,
			ValueMult = 2.5,
			Color = Palette.RaritySilver,
		}),
		table.freeze({
			Id = "Gold",
			Name = "Golden Schnitzel",
			Chance = 0.005,
			UnitMult = 5,
			ValueMult = 5,
			Color = Palette.RarityGold,
		}),
		table.freeze({
			Id = "Diamond",
			Name = "Diamond Schnitzel",
			Chance = 0.001,
			UnitMult = 10,
			ValueMult = 15,
			Color = Palette.RarityDiamond,
		}),
		table.freeze({
			Id = "Nagyi",
			Name = "Grandma's Secret Recipe",
			Chance = 0.00001,
			UnitMult = 100,
			ValueMult = 100,
			Color = Palette.RarityNagyi,
			Announce = true, -- szerver-szintű chat üzenet (GDD 3.4)
		}),
	}),
})
