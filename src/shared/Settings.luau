-- A játékos beállításai (GDD 11.1, 10): alapértékek + ellenőrzés. A szerver (DataService, mentés) és a kliens
-- (UI/SettingsWindow, a controllerek) is ezt használja. Új beállításhoz: ide egy sor, a SettingsWindow-ba egy sor,
-- és ahol hat, ott State.settings().<kulcs>.
--   sfx          effekt-hangerő 0..1 (Audio)
--   lowMode      gyenge gépekre: nincs árnyék, nincs elmosás az ablakok mögött, a többiek szalagján nem gurul
--                schnitzel, a sajátodon is kevesebb (ConveyorController, Hud)
--   effects      aura részecskék és fények, az event színes kerete (AuraController, EventController)
--   popups       a fej feletti "+$" / "+n" feliratok (EventController, CollectorController, StackController)
--   otherPets    a többi játékos petjei (PetFollowController)
--   otherStacks  a schnitzel-torony a többi játékos feje felett (StackController)
local Settings = {}

export type Settings = {
	sfx: number,
	lowMode: boolean,
	effects: boolean,
	popups: boolean,
	otherPets: boolean,
	otherStacks: boolean,
}

Settings.Defaults = table.freeze({
	sfx = 1,
	lowMode = false,
	effects = true,
	popups = true,
	otherPets = true,
	otherStacks = true,
})

-- Érvényes beállítás-tábla bármiből: az ismeretlen kulcsok kimaradnak, a rossz típusú / hiányzó értékek helyett
-- az alapérték, a számok 0..1 közé szorítva.
function Settings.normalize(input: any): Settings
	local out = table.clone(Settings.Defaults) :: any
	if type(input) ~= "table" then
		return out
	end
	for key, default in Settings.Defaults do
		local value = input[key]
		if type(default) == "number" then
			if type(value) == "number" and value == value then -- (value == value: nem NaN)
				out[key] = math.clamp(value, 0, 1)
			end
		elseif type(value) == type(default) then
			out[key] = value
		end
	end
	return out
end

return Settings
