--[[
	AuraConfig — the particle auras on the later logs and the rarer pets (Shared/Modules/Aura). Each aura is an invisible
	box that follows the model (the rolling log, the log on its shop pad, a follower pet), and every emitter below sprays
	from that box's surface. A spec is a VFXKit emitter spec (keys in VFXKit's header; Tex names in VFXConfig.Tex).
	Logs / pets with no entry get no aura.
]]
local rgb = Color3.fromRGB

local twinkle = { { 0, 0 }, { 0.5, 1.8, 0.4 }, { 1, 0 } } -- grow in, shrink out
local mote = { { 0, 0.55 }, { 1, 0 } }

return {
	Shape = { "Box", "Surface" }, -- the default emitter shape
	PetFit = 1.15, -- a pet's aura box = its bounding box x this (a bit bigger, so particles start outside the body, not buried in it)
	LogFit = Vector3.new(1, 1.45, 1.45), -- a log's aura box = its length x diameter x this (particles start clear of the bark)

	Logs = {
		Golden = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 22, Life = { 0.7, 1.3 }, Size = { { 0, 0 }, { 0.5, 2.2, 0.5 }, { 1, 0 } },
				Color = rgb(255, 220, 110), Bright = 3, Speed = { 0.2, 1 }, Spread = 180, Drag = 1.5, Fade = "dip" },
			{ Name = "Dust", Tex = "dotHalo", Rate = 16, Life = { 1, 1.8 }, Size = mote, Color = rgb(255, 200, 80), Bright = 2.5, Speed = 0.4, Spread = 180, Accel = Vector3.new(0, 1.5, 0) },
		},
		Crystal = {
			{ Name = "Glint", Tex = "flare", Rate = 9, Life = { 0.4, 0.7 }, Size = twinkle, Color = rgb(170, 240, 255), Bright = 3, Spin = { -40, 40 } },
			{ Name = "Shards", Tex = "streakDiamond", Rate = 18, Life = { 0.8, 1.4 }, Size = { { 0, 0.9 }, { 1, 0 } }, Color = { rgb(140, 220, 255), rgb(210, 250, 255) },
				Bright = 2.5, Speed = { 1, 2.5 }, Spread = 180, Drag = 1, Rot = { -30, 30 } },
		},
		Ruby = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 22, Life = { 0.7, 1.3 }, Size = { { 0, 0 }, { 0.5, 2.1, 0.5 }, { 1, 0 } },
				Color = rgb(255, 80, 110), Bright = 3, Speed = { 0.2, 1 }, Spread = 180, Drag = 1.5, Fade = "dip" },
			{ Name = "Glint", Tex = "flare", Rate = 7, Life = { 0.4, 0.7 }, Size = twinkle, Color = rgb(255, 150, 170), Bright = 3, Spin = { -40, 40 } },
		},
		Magma = {
			{ Name = "Embers", Tex = "dotHalo", Rate = 32, Life = { 0.8, 1.6 }, Size = mote, Color = { rgb(255, 210, 90), rgb(255, 110, 30), rgb(200, 40, 20) },
				Bright = 3, Speed = { 0.5, 2 }, Spread = 180, Accel = Vector3.new(0, 4, 0), Drag = 0.6 },
			{ Name = "Flames", Tex = "fireFlip", Rate = 8, Life = { 0.5, 0.8 }, Size = { { 0, 1.2 }, { 1, 0.4 } }, Color = rgb(255, 140, 50), Bright = 2,
				Speed = 1, Spread = 30, Accel = Vector3.new(0, 3, 0), Rot = { -20, 20 } },
		},
		Cosmic = {
			{ Name = "Stars", Tex = "star", Rate = 18, Life = { 0.8, 1.5 }, Size = twinkle, Color = { rgb(255, 240, 170), rgb(200, 150, 255) }, Bright = 3,
				Speed = { 0.3, 1.2 }, Spread = 180, Drag = 1, Spin = { -60, 60 } },
			{ Name = "Nebula", Tex = "glowRadial", Rate = 3, Life = { 1.2, 1.8 }, Size = { { 0, 1.5 }, { 1, 3 } }, Color = rgb(150, 90, 255), Bright = 1.2, Fade = "soft", Z = -1, Shape = { "Box", "Volume" } },
		},
		-- World 3 (Dream Kingdom): the top logs carry auras too (same recipes, their own colours)
		PrismLog = {
			{ Name = "Glint", Tex = "flare", Rate = 9, Life = { 0.4, 0.7 }, Size = twinkle, Color = { rgb(255, 170, 220), rgb(170, 220, 255), rgb(190, 255, 220) }, Bright = 3, Spin = { -40, 40 } },
		},
		RainbowLog = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 22, Life = { 0.7, 1.3 }, Size = { { 0, 0 }, { 0.5, 2.1, 0.5 }, { 1, 0 } },
				Color = { rgb(255, 110, 120), rgb(255, 210, 90), rgb(110, 225, 130), rgb(100, 180, 255), rgb(190, 120, 250) }, Bright = 3, Speed = { 0.2, 1 }, Spread = 180, Drag = 1.5, Fade = "dip" },
		},
		CometLog = {
			{ Name = "Embers", Tex = "dotHalo", Rate = 32, Life = { 0.8, 1.6 }, Size = mote, Color = { rgb(255, 230, 150), rgb(255, 150, 60), rgb(140, 190, 255) },
				Bright = 3, Speed = { 0.5, 2 }, Spread = 180, Accel = Vector3.new(0, 3, 0), Drag = 0.6 },
			{ Name = "Ice", Tex = "streakDiamond", Rate = 12, Life = { 0.7, 1.2 }, Size = { { 0, 0.9 }, { 1, 0 } }, Color = rgb(190, 230, 255), Bright = 2.5, Speed = { 1, 2.5 }, Spread = 180, Drag = 1, Rot = { -30, 30 } },
		},
		GalaxyLog = {
			{ Name = "Stars", Tex = "star", Rate = 20, Life = { 0.8, 1.5 }, Size = twinkle, Color = { rgb(255, 240, 170), rgb(170, 190, 255), rgb(255, 160, 230) }, Bright = 3,
				Speed = { 0.3, 1.2 }, Spread = 180, Drag = 1, Spin = { -60, 60 } },
			{ Name = "Nebula", Tex = "glowRadial", Rate = 3, Life = { 1.2, 1.8 }, Size = { { 0, 1.5 }, { 1, 3 } }, Color = rgb(120, 90, 255), Bright = 1.2, Fade = "soft", Z = -1, Shape = { "Box", "Volume" } },
		},
		DreamLog = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 24, Life = { 0.7, 1.3 }, Size = { { 0, 0 }, { 0.5, 2.2, 0.5 }, { 1, 0 } },
				Color = { rgb(255, 170, 225), rgb(255, 230, 140), rgb(170, 220, 255) }, Bright = 3, Speed = { 0.2, 1 }, Spread = 180, Drag = 1.5, Fade = "dip" },
			{ Name = "Stars", Tex = "star", Rate = 10, Life = { 0.8, 1.5 }, Size = twinkle, Color = rgb(255, 235, 160), Bright = 3, Speed = { 0.3, 1.2 }, Spread = 180, Drag = 1, Spin = { -60, 60 } },
			{ Name = "Glow", Tex = "glowRadial", Rate = 2, Life = { 1.2, 1.8 }, Size = { { 0, 2.4 }, { 1, 3.4 } }, Color = rgb(255, 170, 230), Bright = 1.0, Fade = "soft", Z = -1, Shape = { "Box", "Volume" } },
		},
	},

	-- by rarity (PetsConfig.Rarities); colours follow the rarity's Rays
	Pets = {
		Rare = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 10, Life = { 0.7, 1.2 }, Size = { { 0, 0 }, { 0.5, 1.1, 0.3 }, { 1, 0 } },
				Color = rgb(120, 190, 255), Bright = 1.6, Speed = { 0.1, 0.5 }, Spread = 180, Drag = 1.5, Fade = "dip" },
		},
		Epic = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 13, Life = { 0.7, 1.2 }, Size = { { 0, 0 }, { 0.5, 1.2, 0.3 }, { 1, 0 } },
				Color = rgb(210, 130, 255), Bright = 1.6, Speed = { 0.1, 0.5 }, Spread = 180, Drag = 1.5, Fade = "dip" },
			{ Name = "Motes", Tex = "dotHalo", Rate = 10, Life = { 1, 1.6 }, Size = { { 0, 0.32 }, { 1, 0 } }, Color = rgb(190, 110, 255), Bright = 1.6, Speed = 0.2, Spread = 180,
				Accel = Vector3.new(0, 1.2, 0) },
		},
		Legendary = {
			{ Name = "Sparkle", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 16, Life = { 0.7, 1.2 }, Size = { { 0, 0 }, { 0.5, 1.4, 0.3 }, { 1, 0 } },
				Color = rgb(255, 214, 90), Bright = 1.6, Speed = { 0.1, 0.6 }, Spread = 180, Drag = 1.5, Fade = "dip" },
			{ Name = "Embers", Tex = "dotHalo", Rate = 16, Life = { 0.8, 1.4 }, Size = { { 0, 0.36 }, { 1, 0 } }, Color = { rgb(255, 230, 120), rgb(255, 120, 40) },
				Bright = 1.6, Speed = 0.3, Spread = 180, Accel = Vector3.new(0, 2, 0) },
			{ Name = "Glow", Tex = "glowRadial", Rate = 2, Life = { 1, 1.5 }, Size = { { 0, 3 }, { 1, 3.6 } }, Color = rgb(255, 190, 70), Bright = 0.8, Fade = "soft", Z = -1, Shape = { "Box", "Volume" } },
		},
	},
}
