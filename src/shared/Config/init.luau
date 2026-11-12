-- Közös beállítások (szerver + kliens). Minden balance szám a Config almodulokban van (GDD 12.1).
local Config = {
	Game = require(script.Game),
	Palette = require(script.Palette),
	Ovens = require(script.Ovens),
	Sell = require(script.Sell),
	Plot = require(script.Plot),
	Rarities = require(script.Rarities),
	Chefs = require(script.Chefs),
	Rebirth = require(script.Rebirth),
	Pets = require(script.Pets),
	Auras = require(script.Auras),
	Events = require(script.Events),
	Offline = require(script.Offline),
	Index = require(script.Index),
}

return table.freeze(Config)
