-- Shared UI state: which window is open (only one at a time) and the player's data as Vide sources.
-- Hud.mount fills the data sources from the replicated player data (Shared.Data).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Vide"))
local source = Vide.source

export type Pet = { uid: number, id: string, golden: boolean }
export type PetsData = { inventory: { Pet }, equipped: { number }, nextId: number }
export type AurasData = { owned: { [string]: number }, equipped: string, tickets: number, ticketProgress: number }
export type Offline = { pending: number, seconds: number }

local State = {
	window = source(nil :: string?),

	money = source(0),
	carried = source(0),
	carriedValue = source(0),

	earned = source(0), -- money earned since the last rebirth
	rebirths = source(0),
	tokens = source(0),
	perks = source({} :: { [string]: number }),

	pets = source({ inventory = {}, equipped = {}, nextId = 1 } :: PetsData),
	auras = source({ owned = {}, equipped = "", tickets = 0, ticketProgress = 0 } :: AurasData),
	offline = source({ pending = 0, seconds = 0 } :: Offline),

	-- the full replicated data (Shared.Data client), for formulas that need the whole profile
	data = nil :: any,
}

function State.toggle(name: string)
	State.window(if State.window() == name then nil else name)
end

function State.close()
	State.window(nil)
end

return State
