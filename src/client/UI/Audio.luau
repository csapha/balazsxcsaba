-- UI sounds (taken from the Snowboard game's Audio module; no music here yet, GDD 11).
local SoundService = game:GetService("SoundService")

local Audio = {}

type Entry = { id: number | string, volume: number, pitch: number?, speed: number? }

local SOUNDS: { [string]: Entry } = {
	Click = { id = 15675059323, volume = 0.5, pitch = 0.04 },
	Hover = { id = 15675032796, volume = 0.18, pitch = 0.06 },
	Open = { id = 15675037413, volume = 0.4 },
	Close = { id = 15675028888, volume = 0.3 },
	Error = { id = 15675075163, volume = 0.4 },
	Coins = { id = 1210852193, volume = 0.4 },
	Tick = { id = 15675032796, volume = 0.55, pitch = 0.03 },
	Whoosh = { id = 15674975792, volume = 0.5, pitch = 0.05 },
	Ding = { id = 9126073001, volume = 0.45 },
	Stinger = { id = 15675043410, volume = 0.6 },
	Chime = { id = 9116395089, volume = 0.65 },
	Golden = { id = 9039712090, volume = 0.6 },
	Victory = { id = 94590027038118, volume = 0.6 },
	Boom = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.8, pitch = 0.05 },
	New = { id = 1844278029, volume = 0.45 },
	Impact = { id = 9125484526, volume = 0.8 },
	Swoosh = { id = 9116416708, volume = 0.55, pitch = 0.05 },
}

local folder = Instance.new("Folder")
folder.Name = "UiSounds"
folder.Parent = SoundService

local group = Instance.new("SoundGroup")
group.Name = "Effects"
group.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, entry in SOUNDS do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = if type(entry.id) == "string" then entry.id else "rbxassetid://" .. entry.id
	sound.Volume = entry.volume
	sound.SoundGroup = group
	sound.Parent = folder
	templates[name] = sound
end

local random = Random.new()
local lastPlayed: { [string]: number } = {}
local MIN_GAP = 0.04

function Audio.play(name: string, speed: number?)
	local template = templates[name]
	local now = os.clock()
	if not template or now - (lastPlayed[name] or 0) < MIN_GAP then
		return
	end
	lastPlayed[name] = now
	local entry = SOUNDS[name]
	local jitter = entry.pitch or 0
	local sound = template:Clone()
	sound.PlaybackSpeed = (speed or entry.speed or 1) + random:NextNumber(-jitter, jitter)
	sound.Parent = folder
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

return Audio
