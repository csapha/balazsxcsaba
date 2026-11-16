-- GDD 7: FTUE – az első 10 perc. Döntések (2026-11-15):
--   szöveges logó a betöltőképernyőn; a kezdőpénz pontosan 2 sütő (Config.Game.StartMoney);
--   vezetés: arany fénycsík a padlón + ugráló nyíl a cél felett + chef buborék fent (átugorható, a nyíl marad);
--   a HUD menü gombjai a fő lépések után jelennek meg (mind egyszerre); ajándék chef ~3. perc, "Wake him up!", első event fixen 5 percnél
--   (Config.Events.FirstEventDelay, Panírvihar), ingyen tojás ~7. perc; a questek a 8. fejezettel jönnek;
--   repülő kamera az első belépéskor + a sütő "leesik az égből"; csak angol szöveg.
--
-- Lépések: a fő lépések sorban (a szerver figyeli a feltételt és lépteti), utána "Free" (szabad játék),
-- amiből a játékidő alapján jönnek a későbbi lépések (ChefGift, FreeEgg), és a Wake, ha elalszik az első chef.
-- Target: "Pad:<kulcs>" (a saját telek padja), "Egg:<index>" (Tojás tér), "SleepingChef" (az alvó chef), nil.
-- Picture: a buborék mini ábrája – Ui.Icons kulcsok és jelek ("+", "=", ">"), pl. sütő + sütő = jobb sütő.
return table.freeze({
	-- Studióban is fut (a mock mentés miatt minden teszt-belépés új játékos); false = Studióban kész a tutorial
	StudioEnabled = true,

	Main = table.freeze({ "Welcome", "BuyOven1", "BuyOven2", "Merge", "Pickup", "Deposit", "Collect", "BuyMore" }),

	Steps = table.freeze({
		-- a nyíl már az üdvözlésnél (és a repülő kamera alatt) az első sütő padjára mutat, ne legyen üres várakozás
		Welcome = table.freeze({ Text = "Hi! Help me open the schnitzel shop!", Target = "Pad:BuyOne", Picture = { "Home" } }),
		BuyOven1 = table.freeze({ Text = "Buy an oven!", Target = "Pad:BuyOne", Picture = { "Coin", ">", "Ovens" } }),
		BuyOven2 = table.freeze({ Text = "Buy one more!", Target = "Pad:BuyOne", Picture = { "Coin", ">", "Ovens" } }),
		Merge = table.freeze({ Text = "Two same ovens? MERGE!", Target = "Pad:Merge", Picture = { "Ovens", "+", "Ovens", "=", "Upgrade" } }),
		Pickup = table.freeze({ Text = "Grab the schnitzels!", Target = "Pad:Pickup", Picture = { "Schnitzel" } }),
		Deposit = table.freeze({ Text = "Bring them to the counter!", Target = "Pad:Deposit", Picture = { "Schnitzel", ">", "CoinBag" } }),
		Collect = table.freeze({ Text = "Take your money!", Target = "Pad:Collect", Picture = { "CoinBag" } }),
		BuyMore = table.freeze({ Text = "Buy another oven!", Target = "Pad:BuyOne", Picture = { "Coin", ">", "Ovens" } }),
		ChefGift = table.freeze({ Text = "A gift chef for the opening!", Target = "Pad:ChefHire", Picture = { "Gift", ">", "Chefs" } }),
		Wake = table.freeze({ Text = "Your chef fell asleep – wake him up!", Target = "SleepingChef", Picture = { "Energy", ">", "Chefs" } }),
		FreeEgg = table.freeze({ Text = "A free egg for you! Go open it!", Target = "Egg:1", Picture = { "Gift", ">", "Egg" } }),
	}),

	IntroTimeout = 10, -- ha a kliens addig nem jelzi, hogy lefutott a repülő kamera, a tutorial akkor is indul
	IntroLoadingWait = 5, -- a kliens legfeljebb ennyit vár a betöltőképernyő végére a repülő kamera előtt (mp)
	ChefGiftAt = 180, -- játékidő (mp): ajándék chef
	FreeEggAt = 420, -- ingyen tojás (az első tojás ára 0)
	DoneAt = 600, -- utána kész a tutorial (minden HUD gomb látszik), ha az egyszeri lépések megvoltak
	GiveUpAt = 900, -- ennyi játékidő után akkor is kész, ha kihagyott valamit (pl. nem ment el a tojásért)

	-- A HUD menü gombjai (döntés 2026-11-16, a haladás szerinti helyett): a fő lépések alatt egy sem látszik
	-- (az ajándék aura ticket sem hozza elő az Aurast), a fő lépések végén (vagy SKIP után) MIND egyszerre
	-- megjelenik, a chef bemutatja ("New buttons unlocked!"). A fő lépések alatt napi ajándék sem jön.
})
