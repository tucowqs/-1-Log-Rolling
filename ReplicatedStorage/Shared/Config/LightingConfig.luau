--[[
	LightingConfig — every area's light (ZoneLighting, LightingController). Authored = true (default): the
	game's Lighting is hand-authored in Studio and nothing here is applied. With Authored = false: World = the
	static Lighting properties applied once; Base = the look outside every area; Looks = each named area's own look,
	eased in smoothly as the camera moves between areas (and over Ease while it changes):
	  Ambient / OutdoorAmbient : the area's fill light (with no sun / shadows this IS the light on walls)
	  Atmosphere               : { Color, Decay, Density 0.15-0.26, Haze } - barely shows at room distances
	  Grade                    : ABSOLUTE values for the world ColorCorrection { Color, Brightness, Saturation,
	                             Contrast } - each area OWNS the grade (stacked tints turned deep areas electric);
	                             keep Saturation 0.12-0.32 in coloured areas
	  Bloom                    : BloomEffect.Intensity (lower it - not the lights - when a pale floor is "blinding")
	  Lights                   : { Colors = {..}, Brightness, Range } for the area's accent lights (PointLights in
	                             AccentMarker parts under a folder whose AreaAttribute names the look)
	  LightScale               : extra multiplier on every light in the area (tame a bright area)
	A Look leaves out what it shares with Base. Pick how the camera's area is found with Mode:
	  "Height"  : Bands from the top down; above Height.Top = Base; each band's look is reached at its
	              middle and blended in between (an abyss, a tower, floors of a dungeon)
	  "Volumes" : parts tagged VolumeTag with a "Look" attribute; inside one (its box) = that look
	workspace attribute OverrideAttribute = a look name forces that look (events, cutscenes).
]]
local rgb = Color3.fromRGB

return {
	Ease = 3, -- how quickly the look follows the camera (per second)
	Mode = "Height",
	Height = {
		Top = -40, -- above this Y: Base
		Bands = { -- top to bottom; Look = a key of Looks
			{ Look = "Ruins", Top = -40, Bottom = -168 },
			{ Look = "Grotto", Top = -168, Bottom = -296 },
		},
	},
	VolumeTag = "LightingVolume",
	OverrideAttribute = "LightingLook", -- on workspace: force a look
	AreaAttribute = "LightingLook", -- on a map folder: the look its accent lights / LightScale belong to

	-- Lights in these workspace folders are toned down (Brightness x PointLights.Brightness, Range x
	-- PointLights.Range, x their area's LightScale) and, when they stream in, fade up from dark over
	-- StreamFade.Time instead of popping on.
	StreamFade = { Time = 1.2, Roots = {} }, -- e.g. { "Map", "Decor" }
	PointLights = { Brightness = 0.4, Range = 0.7 },
	AccentMarker = "Glow", -- a light inside a part of this name is an area accent light (gets Lights colours)

	-- true (THE KIT DEFAULT) = Lighting (its properties + Atmosphere / ColorCorrection / Bloom / Sky) is
	-- hand-authored per game in Studio and is the source of truth: LightingController and the WorldBuilder
	-- Lighting step never set a Lighting property or effect (no runtime overrides, so the playtest matches edit
	-- mode). Tune the look with the ColorCorrection in Lighting; keep the sun (Brightness) moderate.
	-- false = the World / Base / Looks tables below drive it (per-area looks eased with the camera).
	Authored = true,

	-- Everything below is used only when Authored = false.
	-- Static Lighting properties (set once). Steal Treasure's "bright & punchy" no-shadow base.
	World = {
		GlobalShadows = false,
		ClockTime = 13,
		GeographicLatitude = 10,
		Brightness = 3,
		ColorShift_Top = rgb(255, 235, 200),
		ColorShift_Bottom = rgb(40, 80, 130),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 0.7,
		ShadowSoftness = 0.6,
	},
	Bloom = { Size = 24, Threshold = 0.95 }, -- static BloomEffect settings (Intensity comes from the look)

	Base = {
		Ambient = rgb(70, 110, 140), OutdoorAmbient = rgb(110, 150, 175),
		Atmosphere = { Color = rgb(60, 195, 230), Decay = rgb(30, 140, 200), Density = 0.2, Haze = 0.9 },
		Grade = { Color = rgb(222, 230, 238), Brightness = 0, Saturation = 0.48, Contrast = 0.24 },
		Bloom = 0.5,
	},

	Looks = {
		-- Example areas (Steal Treasure zone looks): sunny ruins and a neon grotto.
		Ruins = {
			Ambient = rgb(215, 210, 200), OutdoorAmbient = rgb(225, 220, 210),
			Atmosphere = { Color = rgb(60, 195, 230), Decay = rgb(30, 140, 200), Density = 0.26, Haze = 0.9 },
			Grade = { Color = rgb(226, 246, 255), Brightness = 0.05, Saturation = 0.4, Contrast = 0.2 },
			Bloom = 0.45,
			Lights = { Colors = { rgb(255, 205, 150), rgb(140, 240, 220) }, Brightness = 0.3, Range = 35 },
		},
		Grotto = {
			Ambient = rgb(205, 170, 220), OutdoorAmbient = rgb(215, 180, 230),
			Atmosphere = { Color = rgb(150, 70, 195), Decay = rgb(40, 160, 190), Density = 0.16, Haze = 0.6 },
			Grade = { Color = rgb(255, 238, 250), Brightness = 0.05, Saturation = 0.23, Contrast = 0.22 },
			Bloom = 0.8,
			Lights = { Colors = { rgb(70, 240, 210), rgb(240, 80, 210) }, Brightness = 1.8, Range = 60 },
			LightScale = 1,
		},
	},
}
