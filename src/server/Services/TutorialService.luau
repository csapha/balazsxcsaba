-- GDD 7 FTUE: a tutorial lépései a szerveren (Config.Tutorial). A lépés a mentésben van (data.tutorial), a kliens
-- ebből rajzolja a fénycsíkot, a nyilat és a chef buborékot (UI/Tutorial). Másodpercenként:
--   a fő lépések feltételét nézi (sütő vétel, merge, felvétel, leadás, pénz felvétel, újabb sütő), és léptet;
--   "Free" állapotban a játékidő alapján indítja az ajándék chefet (~3. perc) és az ingyen tojást (~7. perc);
--   10 perc után (és ha minden egyszeri lépés megvolt) a tutorial kész. A HUD menü gombjai már a fő lépések végén megjelennek.
-- A többi szolgáltatás jelez: SellService (pénz felvétel), ChefService (elalszik / felébred / ajándék chef),
-- PetService (ingyen tojás).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Lib.Guard)
local DataService = require(script.Parent.DataService)

local Tutorial = Config.Tutorial
local TICK = 1

local TutorialService = {}

-- A fő lépések feltétele (a mentett adatból): ha igaz, jön a következő lépés.
local CONDITIONS: { [string]: (raw: any) -> boolean } = {
	Welcome = function(raw)
		-- a repülő kamera után (a kliens jelzi), vagy ha valamiért nem jött jelzés, IntroTimeout mp után
		return raw.tutorial.introDone or raw.tutorial.playtime >= Tutorial.IntroTimeout
	end,
	BuyOven1 = function(raw)
		return raw.ovensBought >= 1
	end,
	BuyOven2 = function(raw)
		return raw.ovensBought >= 2
	end,
	Merge = function(raw)
		return raw.stats.highestOven >= 2
	end,
	Pickup = function(raw)
		return raw.carried > 0 or raw.counterStock > 0 or raw.stats.totalSold > 0
	end,
	Deposit = function(raw)
		return raw.counterStock > 0 or raw.stats.totalSold > 0
	end,
	Collect = function(raw)
		return raw.tutorial.collected
	end,
	BuyMore = function(raw)
		return raw.ovensBought >= 3
	end,
}

local function setTutorial(data: any, change: (tutorial: any) -> ())
	local tutorial = table.clone(data().tutorial)
	change(tutorial)
	data.tutorial(tutorial)
end

-- Az aktuális lépés (nil, ha kész vagy még nem töltött be).
function TutorialService.step(player: Player): string?
	local data = DataService.get(player)
	if not data or data().tutorial.done then
		return nil
	end
	return data().tutorial.step
end

local function nextMain(step: string): string
	local index = table.find(Tutorial.Main, step)
	if index and index < #Tutorial.Main then
		return Tutorial.Main[index + 1]
	end
	return "Free"
end

-- Jelzések a többi szolgáltatásból.
function TutorialService.event(player: Player, name: string)
	local data = DataService.get(player)
	if not data or data().tutorial.done then
		return
	end
	-- csak akkor írunk, ha tényleg változik valami (a pénz felvétel pl. másodpercenként sokszor jelez)
	local current = data().tutorial
	local step = current.step
	if name == "Collected" and not current.collected then
		setTutorial(data, function(tutorial)
			tutorial.collected = true
		end)
	elseif name == "ChefAsleep" and step == "Free" and not current.wake then
		setTutorial(data, function(tutorial)
			tutorial.step = "Wake"
		end)
	elseif name == "ChefWoken" and step == "Wake" then
		setTutorial(data, function(tutorial)
			tutorial.step = "Free"
			tutorial.wake = true
		end)
	elseif name == "ChefHired" and step == "ChefGift" then
		setTutorial(data, function(tutorial)
			tutorial.step = "Free"
			tutorial.chefGift = true
		end)
	elseif name == "EggOpened" and step == "FreeEgg" then
		setTutorial(data, function(tutorial)
			tutorial.step = "Free"
			tutorial.freeEgg = true
		end)
	end
end

-- A vezetett rész (a fő lépések) fut-e még. Közben nem jön napi ajándék (MembershipService), hogy a
-- kezdőpénz pontosan 2 sütő maradjon, és ne ugorjon fel ajándék ablak a repülő kamera alatt.
function TutorialService.guided(raw: any): boolean
	local tutorial = raw.tutorial
	return not tutorial.done and (tutorial.step == "" or table.find(Tutorial.Main, tutorial.step) ~= nil)
end

-- Ingyen-e most a chef felvétel / az 1. tojás (a ChefService / PetService kérdezi).
function TutorialService.chefFree(raw: any): boolean
	return not raw.tutorial.done and raw.tutorial.step == "ChefGift" and raw.chefs.count == 0
end

function TutorialService.eggFree(raw: any, eggIndex: number): boolean
	return not raw.tutorial.done and raw.tutorial.step == "FreeEgg" and eggIndex == 1
end

local function tickPlayer(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local raw = data()
	if raw.tutorial.done then
		return
	end
	setTutorial(data, function(tutorial)
		tutorial.playtime += TICK
		if tutorial.playtime >= Tutorial.GiveUpAt then
			tutorial.done = true -- ne ragadjon be (pl. kihagyta az ingyen tojást)
			return
		end
		if tutorial.step == "" then
			tutorial.step = Tutorial.Main[1]
		end

		local condition = CONDITIONS[tutorial.step]
		-- a feltételek a friss játékidőt látják
		local view = table.clone(raw)
		view.tutorial = tutorial
		if condition then
			-- egy tickben több lépést is átléphet (pl. ha valaki már előre csinálta)
			while condition and condition(view) do
				tutorial.step = nextMain(tutorial.step)
				condition = CONDITIONS[tutorial.step]
			end
			return
		end

		if tutorial.step ~= "Free" then
			return
		end
		if not tutorial.chefGift and tutorial.playtime >= Tutorial.ChefGiftAt then
			if raw.chefs.count == 0 then
				tutorial.step = "ChefGift"
			else
				tutorial.chefGift = true -- már vett chefet
			end
		elseif tutorial.chefGift and not tutorial.freeEgg and tutorial.playtime >= Tutorial.FreeEggAt then
			if #raw.pets.inventory == 0 then
				tutorial.step = "FreeEgg"
			else
				tutorial.freeEgg = true -- már van petje
			end
		elseif tutorial.playtime >= Tutorial.DoneAt and tutorial.chefGift and tutorial.freeEgg then
			tutorial.done = true
		end
	end)
end


function TutorialService.start()
	-- GDD 7.2: a kliens a repülő kamera végén jelez → a Welcome lépés kész, jöhet a "Buy an oven!"
	Guard.connect(Remotes.TutorialIntroDone, function(player)
		local data = DataService.get(player)
		if data and not data().tutorial.introDone then
			setTutorial(data, function(tutorial)
				tutorial.introDone = true
			end)
		end
	end)
	-- SKIP TUTORIAL (döntés 2026-11-15): az egész tutorial kész – minden HUD gomb látszik, nincs több vezetés
	Guard.connect(Remotes.TutorialSkip, function(player)
		local data = DataService.get(player)
		if data and not data().tutorial.done then
			setTutorial(data, function(tutorial)
				tutorial.done = true
				tutorial.introDone = true
			end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				tickPlayer(player)
			end
		end
	end)
end

return TutorialService
