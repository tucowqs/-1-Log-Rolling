--[[
	ZoneLighting — the light for any camera position (LightingConfig): Base outside every area, each
	named area's own look inside it (Height bands blend between band middles; Volumes switch and let
	the controller's Ease smooth it). Used by LightingController every frame and by edit-mode previews.
	  ZoneLighting.Look(position) -> { Ambient, OutdoorAmbient, Atmosphere, Grade, Bloom }
	  ZoneLighting.Named(name)    -> that look (Base merged under it)
	  ZoneLighting.Blend(a, b, t) -> the look t of the way from a to b
	  ZoneLighting.Apply(look, atmosphere?, grade?, bloom?) -> writes it to Lighting and those effects
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

-- Relative require, so a Shared:Clone() in edit mode (DevTools.LightingPreview) reads a fresh config.
local Config = require(script.Parent.Parent.Config.LightingConfig)

local ZoneLighting = {}

local KEYS = { "Ambient", "OutdoorAmbient", "Atmosphere", "Grade", "Bloom" }

local looks = {}
function ZoneLighting.Named(name: string)
	if not looks[name] then
		local def = name == "Base" and Config.Base or Config.Looks[name]
		assert(def, "LightingConfig has no look " .. name)
		local look = {}
		for _, key in KEYS do
			look[key] = if def[key] ~= nil then def[key] else Config.Base[key]
		end
		looks[name] = look
	end
	return looks[name]
end

local function mix(a, b, t: number)
	if typeof(a) == "number" then
		return a + (b - a) * t
	elseif typeof(a) == "Color3" then
		return a:Lerp(b, t)
	end
	local out = {}
	for key, value in a do
		out[key] = b[key] ~= nil and mix(value, b[key], t) or value
	end
	return out
end

function ZoneLighting.Blend(a, b, t: number)
	return mix(a, b, math.clamp(t, 0, 1))
end

local function heightLook(y: number)
	local H = Config.Height
	local prevY, prev = H.Top, ZoneLighting.Named("Base")
	if y >= prevY then
		return prev
	end
	for _, band in H.Bands do
		local look = ZoneLighting.Named(band.Look)
		local midY = (band.Top + band.Bottom) / 2
		if y >= midY then
			return ZoneLighting.Blend(prev, look, (prevY - y) / (prevY - midY))
		end
		prevY, prev = midY, look
	end
	return prev
end

local function volumeLook(position: Vector3)
	for _, volume in CollectionService:GetTagged(Config.VolumeTag) do
		if volume:IsA("BasePart") then
			local p = volume.CFrame:PointToObjectSpace(position):Abs()
			local half = volume.Size / 2
			if p.X <= half.X and p.Y <= half.Y and p.Z <= half.Z then
				return ZoneLighting.Named(volume:GetAttribute("Look"))
			end
		end
	end
	return ZoneLighting.Named("Base")
end

function ZoneLighting.Look(position: Vector3)
	local forced = workspace:GetAttribute(Config.OverrideAttribute)
	if forced then
		return ZoneLighting.Named(forced)
	end
	return if Config.Mode == "Height" then heightLook(position.Y) else volumeLook(position)
end

function ZoneLighting.Apply(look, atmosphere: Atmosphere?, grade: ColorCorrectionEffect?, bloom: BloomEffect?)
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	if atmosphere then
		for key, value in look.Atmosphere do
			atmosphere[key] = value
		end
	end
	if grade then
		grade.TintColor = look.Grade.Color
		grade.Brightness, grade.Saturation, grade.Contrast = look.Grade.Brightness, look.Grade.Saturation, look.Grade.Contrast
	end
	if bloom then
		bloom.Intensity = look.Bloom
	end
end

return ZoneLighting
