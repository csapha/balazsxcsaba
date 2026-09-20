-- Global environment tuning for the bright, stylized outdoor map.
-- Kept in code so play tests and published servers always use the same look.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LightingService = {}

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = parent:FindFirstChildOfClass(className)
	end

	if not existing then
		existing = Instance.new(className)
		existing.Parent = parent
	end
	existing.Name = name

	return existing
end

function LightingService.init()
	-- A late-afternoon sun gives the props readable shape without making the
	-- colorful zones look gloomy or overly orange.
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.ExposureCompensation = -0.05
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.Ambient = Color3.fromRGB(72, 78, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 138, 150)
	Lighting.EnvironmentDiffuseScale = 0.38
	Lighting.EnvironmentSpecularScale = 0.55

	local atmosphere = getOrCreate(Lighting, "Atmosphere", "SqueezeAtmosphere")
	atmosphere.Color = Color3.fromRGB(205, 222, 238)
	atmosphere.Decay = Color3.fromRGB(116, 126, 144)
	atmosphere.Density = 0.2
	atmosphere.Offset = 0.12
	atmosphere.Haze = 1.15
	atmosphere.Glare = 0.1

	-- These values are intentionally restrained: the map should gain depth and
	-- material definition without washing out its UI-like, saturated palette.
	local colorCorrection = getOrCreate(Lighting, "ColorCorrectionEffect", "SqueezeColorGrade")
	colorCorrection.Brightness = 0.01
	colorCorrection.Contrast = 0.07
	colorCorrection.Saturation = 0.04
	colorCorrection.TintColor = Color3.fromRGB(255, 249, 240)
	colorCorrection.Enabled = true

	local bloom = getOrCreate(Lighting, "BloomEffect", "SqueezeBloom")
	bloom.Intensity = 0.1
	bloom.Size = 22
	bloom.Threshold = 1.35
	bloom.Enabled = true

	local sunRays = getOrCreate(Lighting, "SunRaysEffect", "SqueezeSunRays")
	sunRays.Intensity = 0.035
	sunRays.Spread = 0.82
	sunRays.Enabled = true

	local clouds = getOrCreate(Workspace.Terrain, "Clouds", "SqueezeClouds")
	clouds.Color = Color3.fromRGB(246, 249, 255)
	clouds.Cover = 0.18
	clouds.Density = 0.28
end

return LightingService
