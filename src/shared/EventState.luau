-- Az aktuális random event állapota (GDD 3.12), szerver és kliens is innen olvassa.
-- A szerver (EventService) a ReplicatedStorage.EventState attribútumait írja:
--   Active (event id vagy ""), EndsAt (szerveridő), NextAt (szerveridő).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local holder: Instance
if RunService:IsServer() then
	holder = ReplicatedStorage:FindFirstChild("EventState") or Instance.new("Configuration")
	holder.Name = "EventState"
	holder:SetAttribute("Active", "")
	holder.Parent = ReplicatedStorage
else
	holder = ReplicatedStorage:WaitForChild("EventState")
end

local EventState = {}

EventState.instance = holder

-- Az aktív event id-je (nil, ha nincs).
function EventState.active(): string?
	local id = holder:GetAttribute("Active")
	return if type(id) == "string" and id ~= "" then id else nil
end

-- Az aktív event beállításai (Config.Events.List), vagy nil.
function EventState.config(): any?
	local id = EventState.active()
	return if id then Config.Events.List[id] else nil
end

function EventState.is(id: string): boolean
	return EventState.active() == id
end

function EventState.endsAt(): number
	return holder:GetAttribute("EndsAt") or 0
end

function EventState.nextAt(): number
	return holder:GetAttribute("NextAt") or 0
end

return EventState
