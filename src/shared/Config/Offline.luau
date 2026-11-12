-- GDD 3.13: offline kereset. Kilépéskor a bevétel egy része tovább "fut", belépéskor Claim ablak.
-- Döntés (2026-11-12): most csak sima Claim; az x2 (reklám / napi ingyen) és az x10 (Robux) később.
-- Az arány és a max idő a rebirth-fával nő (Config.Rebirth.Tree).
return table.freeze({
	BaseRate = 0.30, -- a becsült bevétel ennyi része fut offline
	BaseMaxSeconds = 2 * 60 * 60, -- max 2 óra
	MinSeconds = 60, -- ennél rövidebb távollét után nincs ablak
	HeartbeatInterval = 60, -- mp-enként mentjük az "utoljára online" időt (crash esetére)
})
