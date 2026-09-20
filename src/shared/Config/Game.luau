-- SQUEEZE - globális beállítások
return {
	Persistence = false, -- session-only egyelőre

	-- edzés
	TrainTapGain = 0.8, -- ennyi Erő jár egy guggolásért (hand szorzóval)
	TrainCycle = 2.4, -- automatikus edzés: ennyi mp-enként egy guggolás
	TrainTapMinInterval = 2.1, -- kis hálózati tolerancia a 2.4 mp-es kliens ciklushoz
	PassiveTick = 1, -- passzív Erő ennyi másodpercenként adódik

	-- edzés animációk
	-- FIGYELEM: az ingyenes workout KeyframeSequence-ek csak a HumanoidRootPart-ot
	-- animálják (nem látszik rajtuk semmi), ezért amíg nincs rendes R15 animáció,
	-- marad a beépített visszajelzés (por + kamera-dip).
	-- Ha lesz publikált squat animáció: ide írd az ID-t, pl. "rbxassetid://123..."
	-- szorítás animáció (a Blenderben készült, publikált animáció)
	SqueezeAnimationId = "rbxassetid://122431006026975",
	-- procedurális szorítás póz (R6 karok/törzs, C0 tween)
	-- A karok a vállból előre (X) és befelé (Y) fordulnak, a kéz a tárgy oldalára kerül.
	SqueezeAnim = {
		ArmReach = 1.5, -- R6: kéz távolsága a válltól (stud)
		ArmYaw = 13, -- karok befelé fordulása (fok)
		ArmLiftMax = 30, -- mennyit emelhet a tárgy magasságához (fok)
		SqueezeYaw = 27, -- szorításkor ennyire zárnak befelé
		SqueezePitch = 9, -- szorításkor ennyit nyomnak lefelé
		Lean = 8, -- törzs előredőlés
		BurstYaw = 65, -- pop-nál szétnyílnak oldalra
		BurstPitch = 100, -- pop-nál mellek magasságában
		BurstLean = -6, -- pop-nál hátradőlés
		PulseIn = 0.06, -- szorítás-pulzus be (mp)
		PulseOut = 0.10, -- szorítás-pulzus ki (mp)
		ScrubStart = 0.28, -- az animáció eleji "kézfelemelés" átugrása (itt kezdődik a zárás)
		ScrubEnd = 0.64, -- a tényleges kézzáró szakasz vége; utána az animáció már csak kitartja a pózt
		ScrubSpeed = 14, -- milyen gyorsan simul rá a célpozícióra (1/mp); nagyobb = gyorsabb, simább
	},
	-- cinematic kamera a szorításhoz
	Cinematic = {
		FOV = 60, -- szorítás közbeni látószög
		TapFOV = 56, -- minden kattintásnál ennyire szűkül (punch)
		StandDistance = 2.0, -- távolság a tárgy felületétől; az asztal szélén kívül tartja a karaktert
		CameraDistance = 7, -- vízszintes eltolás (kicsi: felülről nézünk)
		CameraHeight = 11, -- magasan, hogy felülről lássuk a jelenetet
		LookHeight = 1.0, -- az asztal/tárgy szintjére néz
		SideAngle = 0, -- fok: 0 = szemből, felülről (nincs oldaleltolás)
	},

	-- edzés animáció: a feltöltött R6 guggolás animáció (ez az elsődleges).
	-- Ha üres lenne, a beépített procedurális R6 guggolás (C0 tween) megy fallbackként.
	SquatAnimationId = "rbxassetid://140689504024158",
	TrainAnimStopDelay = 1.2, -- ennyi mp kattintás nélkül áll le az edzés animáció

	-- szorítás (minigame)
	SqueezeRange = 14, -- ezen belül lehet szorítani
	TapRateLimit = 10, -- max szorítás-kattintás / mp
	MinTapInterval = 0.1, -- ennyi mp kell két kattintás között (szerver limit)
	BaseClicks = 5, -- ennyi kattintás kell jelentős túlerőnél
	MaxClicks = 18, -- ennyi kell, amikor a játékos épp eléri a Power gate-et
	FailDecay = 1.5, -- mp-enként ennyi progress vész el, ha nem kattintasz
	StartGrace = 1.5, -- ennyi mp türelmi idő van az első kattintásig
	RespawnTime = 5, -- objektum újra megjelenik ennyi mp után

	-- világ
	MapName = "SqueezeMap",
	TrainingPadName = "TrainingPad",
	ObjectFolderName = "Objects",
	ObjectSpacing = 128, -- stud; each object has its own themed landscape section

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
