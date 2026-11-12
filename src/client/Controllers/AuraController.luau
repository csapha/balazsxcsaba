-- Aura effektek (GDD 3.10, 10): minden játékos aktív aurája részecskékként a karaktere körül.
-- A szerver a "Aura" játékos-attribútumba írja az aura id-t. Beépített Roblox textúrák (placeholder,
-- a szép VFX a 10. fejezetben). Legendás / mitikus aura megszerzésekor chat bejelentés.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Chat = require(script.Parent.Parent.Util.Chat)

local AuraConfig = Config.Auras

local TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 74, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 154, 42)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 224, 74)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 217, 74)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(74, 168, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 255)),
})

type Active = { id: string, character: Model, attachment: Attachment }

local AuraController = {}

local active: { [Player]: Active } = {}

local function build(root: BasePart, id: string): Attachment?
	local aura = AuraConfig.List[id]
	if not aura then
		return nil
	end
	local particle = aura.Particle

	-- hulló effekt (negatív "Speed") a fej felől, a többi a derék magasságából száll fel
	local falling = particle.Speed < 0
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Position = Vector3.new(0, if falling then 3 else -1, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = TEXTURES[particle.Texture] or TEXTURES.sparkles
	emitter.Color = if particle.Rainbow then RAINBOW else ColorSequence.new(particle.Color)
	emitter.LightEmission = if particle.Light then 0.8 else 0.2
	emitter.Rate = particle.Rate
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(particle.Spread * 0.4, particle.Spread)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, particle.Speed, 0)
	emitter.Drag = 1.5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, particle.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = attachment

	if particle.Light then
		local light = Instance.new("PointLight")
		light.Color = if particle.Rainbow then Color3.fromRGB(255, 120, 220) else particle.Color
		light.Brightness = 1.5
		light.Range = 8
		light.Parent = attachment
	end

	attachment.Parent = root
	return attachment
end

local function clear(player: Player)
	local current = active[player]
	if current then
		current.attachment:Destroy()
		active[player] = nil
	end
end

local function update()
	for _, player in Players:GetPlayers() do
		local id = player:GetAttribute("Aura")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local current = active[player]

		if type(id) ~= "string" or not root then
			if current then
				clear(player)
			end
			continue
		end
		if current and current.id == id and current.character == character and current.attachment.Parent then
			continue
		end

		clear(player)
		local attachment = build(root :: BasePart, id)
		if attachment then
			active[player] = { id = id, character = character :: Model, attachment = attachment }
		end
	end
end

local function onAnnounce(playerName: string, id: string)
	local aura = AuraConfig.List[id]
	if not aura then
		return
	end
	local rarity = AuraConfig.Rarities[aura.Rarity]
	Chat.announce(`✨ {playerName} megszerezte: {aura.Name} ({rarity.Name} aura)!`, rarity.Color)
end

function AuraController.init()
	RunService.Heartbeat:Connect(update)
	Players.PlayerRemoving:Connect(clear)
	Remotes.AuraAnnounce.OnClientEvent:Connect(onAnnounce)
end

return AuraController
