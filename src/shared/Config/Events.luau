-- GDD 3.12: random eventek – szerver-szintűek, mindenki egyszerre éli meg.
-- Döntések (2026-11-12): a Panírvihar az utcán közös (aki elsőként felkapja); az Ételkritikus akkor
-- elégedett, ha a pult 30 mp-en belül elad; Studióban 60–90 mp-enként jön event a teszteléshez.
return table.freeze({
	IntervalMin = 300, -- élesben 5–7 percenként
	IntervalMax = 420,
	FirstEventDelay = 300, -- GDD 7.3: az első event fixen 5 percnél
	StudioIntervalMin = 60,
	StudioIntervalMax = 90,
	StudioFirstEventDelay = 60,

	-- Weight: súly a véletlen választásnál. Color: banner / vignetta színe.
	List = table.freeze({
		LunchRush = table.freeze({
			Name = "Lunch Rush",
			Icon = "🍽️",
			Description = "Twice the customers, double selling speed!",
			Duration = 60,
			Weight = 25,
			Color = Color3.fromRGB(255, 170, 60),
			SellMultiplier = 2,
			CustomerMultiplier = 2,
			MaxCustomers = 12,
		}),
		GoldenOil = table.freeze({
			Name = "Golden Oil",
			Icon = "🛢️",
			Description = "5x chance for Golden Schnitzel!",
			Duration = 45,
			Weight = 20,
			Color = Color3.fromRGB(255, 200, 40),
			RarityChanceMultipliers = table.freeze({ [3] = 5 }), -- Config.Rarities.List[3] = Arany
		}),
		PanirStorm = table.freeze({
			Name = "Breadcrumb Storm",
			Icon = "🌧️",
			Description = "Schnitzels are falling on the street! Grab them first!",
			Duration = 30,
			Weight = 20,
			Color = Color3.fromRGB(210, 150, 70),
			DropCount = 60, -- összesen ennyi hullik az esemény alatt
			DropIncomeSeconds = 3, -- egy darab ennyi mp-nyi bevételt ér (a felkapó bevételéből)
			DropMinValue = 50,
		}),
		Critic = table.freeze({
			Name = "Food Critic",
			Icon = "🎩",
			Description = "A VIP guest is coming! Serve them within 30 seconds!",
			Duration = 30,
			Weight = 15,
			Color = Color3.fromRGB(190, 100, 255),
			RewardIncomeSeconds = 120, -- jutalom: ennyi mp-nyi bevétel
			RewardMin = 500,
		}),
		Grandma = table.freeze({
			Name = "Grandma's Visit",
			Icon = "👵",
			Description = "Every oven bakes at +1 level!",
			Duration = 30,
			Weight = 15,
			Color = Color3.fromRGB(255, 120, 180),
			OvenLevelBonus = 1,
		}),
		Blackout = table.freeze({
			Name = "Blackout",
			Icon = "🔌",
			Description = "The ovens are off… but chefs are 3x faster!",
			Duration = 20,
			Weight = 5,
			Color = Color3.fromRGB(80, 90, 140),
			ChefSpeedMultiplier = 3,
		}),
	}),
})
