--[[
	VFXConfig — the data side of VFXKit: texture names, flipbook layouts, transparency fades, the
	instant on/off TimeScale, and proven recipes (the kit author's VFX Lab ~5,400-emitter study, distilled in roblox-craft
	references/vfx.md, and the Steal Treasure effects). A recipe is a list of VFXKit specs; VFXKit.Recipe(parent, "Glint",
	{ Color = ... }) builds every layer with the overrides merged into each.
	Texture traps: the BLACK-background textures (rays, raysSoft, lightningBeam, flareSharp, crescentGlow,
	starfield, energySplash, flameTongue, burstSpikes) MUST run at LE 1 or the black square shows.
	The stock sparkles_main.dds is banned - use `sparkle` / a game texture.
]]
local rgb = Color3.fromRGB

return {
	-- How long-lived emitters are pushed through their steady state for an instant ON (VFXKit.InstantOn).
	InstantOnTimeScale = 25,

	Tex = {
		-- workhorses
		spark = "rbxassetid://10439119562", streak = "rbxassetid://6660412891", streakDiamond = "rbxassetid://15431912045",
		needle = "rbxassetid://1315202524", smoke = "rbxassetid://6764385668", wisp = "rbxassetid://10545078665",
		smokeCloud = "rbxassetid://10180479311", glow = "rbxassetid://8451174579", glowRadial = "rbxassetid://1075864321",
		dotHalo = "rbxassetid://8030760338", dot = "rbxassetid://10205180639", sparkle = "rbxassetid://89169149094251",
		ring = "rbxassetid://4609193944", ringHard = "rbxassetid://100035775651006", ringSoft = "rbxassetid://11187763403",
		burstRing = "rbxassetid://10176632695", flare = "rbxassetid://13161986324", star = "rbxassetid://5043599095",
		swirl = "rbxassetid://6706234595", nebula = "rbxassetid://10716752960", vortex = "rbxassetid://10357952493",
		orbShell = "rbxassetid://2916153928", softLine = "rbxassetid://7216979420", beamSmoke = "rbxassetid://7673945506",
		wispBeam = "rbxassetid://6444655780", waveBeam = "rbxassetid://13370272316", jaggedBeam = "rbxassetid://13378758969",
		speedlines = "rbxassetid://6091474388", crescent = "rbxassetid://10558510611", dome = "rbxassetid://242102147",
		veinsBeam = "rbxassetid://10811367080", flareChromatic = "rbxassetid://13948669435",
		-- flipbooks (layouts in Flipbooks below)
		lightningFlip = "rbxassetid://11492870634", lightningFlip2 = "rbxassetid://117907214673915",
		fireFlip = "rbxassetid://11388840312", fireFlip2 = "rbxassetid://11395118687", fireFlip8 = "rbxassetid://11657089737",
		smokeFlip = "rbxassetid://12524470529", smokeFlip2 = "rbxassetid://13712007292", bubbleFlip = "rbxassetid://11373148100",
		-- black background: LE 1 only
		rays = "rbxassetid://11975019541", raysSoft = "rbxassetid://1084999891", lightningBeam = "rbxassetid://5511893461",
		flareSharp = "rbxassetid://11975015979", crescentGlow = "rbxassetid://8101328122", starfield = "rbxassetid://1084976679",
		energySplash = "rbxassetid://13370275515", flameTongue = "rbxassetid://6954174382", burstSpikes = "rbxassetid://8214516794",
		-- the kit author's uploads (Steal Treasure)
		bubble = "rbxassetid://116649285029251", goldStar = "rbxassetid://5946093983", softGlow = "rbxassetid://98411405003052",
		snow = "rbxassetid://136001885840344", petal = "rbxassetid://117480447696162", lightShaft = "rbxassetid://12402898856",
	},

	-- Texture name -> FlipbookLayout (picked automatically; a spec's Flip overrides).
	Flipbooks = {
		sparkle = "Grid8x8", fireFlip8 = "Grid8x8",
		lightningFlip = "Grid4x4", lightningFlip2 = "Grid4x4", fireFlip = "Grid4x4", fireFlip2 = "Grid4x4",
		smokeFlip = "Grid4x4", smokeFlip2 = "Grid4x4", bubbleFlip = "Grid4x4",
	},

	-- Transparency over life ({ time, value, envelope? }).
	Fades = {
		dip = { { 0, 1 }, { 0.2, 0 }, { 0.75, 0 }, { 1, 1 } }, -- fade in AND out (the most common shape in good packs)
		out = { { 0, 0 }, { 1, 1 } },
		late = { { 0, 0 }, { 0.6, 0 }, { 1, 1 } }, -- hold, then fade
		impact = { { 0, 0 }, { 0.2, 0 }, { 1, 1 } },
		soft = { { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.5 }, { 1, 1 } },
	},

	-- Proven recipes: lists of VFXKit.Emitter specs. Sizes are studs at the size the effect is
	-- authored at - ScaleTo the model AFTER adding them (ScaleTo scales Size/Speed/Accel, not ZOffset).
	Recipes = {
		-- Soft glow behind an object.
		Glow = {
			{ Name = "Glow", Tex = "glowRadial", Rate = 2, Life = { 1.2, 2 }, Size = { { 0, 3 }, { 1, 3.5 } }, Bright = 1, Fade = "soft", Z = -1 },
		},
		-- Occasional glint on a treasure.
		Glint = {
			{ Name = "Glint", Tex = "flare", Rate = 0.8, Life = { 0.5, 0.8 }, Size = { { 0, 0 }, { 0.5, 1.6 }, { 1, 0 } }, Spin = { -30, 30 }, Bright = 2.8, Z = 0.6, Locked = true },
		},
		-- Twinkling sparkle motes round an item.
		Sparkles = {
			{ Name = "Sparkles", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Rate = 20, Life = { 0.8, 1.6 },
				Size = { { 0, 0 }, { 0.5, 1.2, 0.4 }, { 1, 0 } }, Speed = { 0.2, 1.5 }, Spread = 180, Drag = 1.3, Bright = 3.5, Fade = "dip", Locked = true },
		},
		-- Rising motes (magic, heat).
		Motes = {
			{ Name = "Motes", Tex = "dotHalo", Rate = 10, Life = { 1.2, 2.4 }, Size = { { 0, 0.22 }, { 1, 0 } }, Accel = Vector3.new(0, 0.7, 0), Bright = 3, Speed = 0.3, Spread = 180 },
		},
		-- Underwater / potion bubbles.
		Bubbles = {
			{ Name = "Bubbles", Tex = "dotHalo", Rate = 4, Life = { 1.4, 2.2 }, Size = { { 0, 0.2 }, { 1, 0.26 } }, LE = 0.5, Speed = { 0.4, 1.4 }, Accel = Vector3.new(0, 0.6, 0), Rot = 0, Spread = 25 },
		},
		-- Burst of impact sparks (Emit = { count, delay }: Rate 0, fire with VFXKit.Fire).
		ImpactSparks = {
			{ Name = "Sparks", Tex = "spark", Emit = { 24 }, Orient = "VelocityParallel", Squash = 1.8, Life = { 0.25, 0.4 },
				Size = { { 0, 0.4 }, { 1, 0 } }, Speed = { 28, 100 }, Drag = 15, Spread = { 360, 360 }, Bright = 5, Color = rgb(255, 210, 120) },
			{ Name = "Flash", Tex = "glow", Emit = { 1 }, Life = 0.3, Size = { { 0, 2 }, { 1, 4 } }, Fade = "out", Bright = 1, Color = rgb(255, 170, 80) },
		},
		-- Rising embers.
		Embers = {
			{ Name = "Embers", Tex = "spark", Orient = "VelocityParallel", Squash = 1.5, Rate = 8, Life = { 0.8, 1.4 }, Size = { { 0, 0.25 }, { 1, 0 } },
				Speed = { 1.5, 4 }, Spread = 40, Accel = Vector3.new(0, 3.5, 0), Drag = 3, Bright = 5, Color = rgb(255, 140, 40) },
		},
		-- Soft white steam (LE 0.3-0.7; dark smoke = LE 0 and a dark colour).
		Steam = {
			{ Name = "Steam", Tex = "smoke", Rate = 3, Life = { 0.8, 2 }, Size = { { 0, 0.6 }, { 1, 3 } }, LE = 0.5, Speed = { 1, 4 }, Spread = 18, Drag = 1.5, Spin = { -50, 50 }, Fade = "soft", Color = rgb(235, 235, 240) },
		},
		-- Floor rune ring (emit from Top; flat on the floor).
		FloorRing = {
			{ Name = "Ring", Tex = "ringHard", Orient = "VelocityPerpendicular", Speed = 0.001, Rot = 0, Spin = { 15, 30 }, Rate = 1.5, Life = 2,
				Size = { { 0, 1.5 }, { 0.5, 5 }, { 1, 8 } }, Fade = "late", Bright = 2 },
		},
		-- Rarity reveal burst: big flare + dim blur + star twinkles + rising sparkle (fire with VFXKit.Fire).
		Reveal = {
			{ Name = "Flare", Tex = "flare", Emit = { 1 }, Life = 1, Size = { { 0, 0 }, { 0.3, 8 }, { 1, 0 } }, Spin = { 60, 60 }, Bright = 3 },
			{ Name = "Blur", Tex = "glowRadial", Emit = { 1 }, Life = 1.2, Size = { { 0, 20 }, { 1, 30 } }, Fade = "soft", Bright = 1 },
			{ Name = "Twinkles", Tex = "star", Emit = { 12 }, Life = { 0.6, 1.2 }, Size = { { 0, 0 }, { 0.5, 2.5 }, { 1, 0 } }, Speed = { 4, 10 }, Spread = 180, Drag = 4, Bright = 3 },
			{ Name = "Rise", Tex = "sparkle", FlipMode = "Loop", FlipRandom = true, Emit = { 30 }, Life = { 1, 1.6 }, Size = { { 0, 0 }, { 0.4, 1 }, { 1, 0 } },
				Speed = { 2, 6 }, Spread = 180, Accel = Vector3.new(0, 1, 0), Drag = 5, Bright = 4 },
		},
		-- LogRoll: a bump thud (dust cloud + wood chips; the "Dust" layer is tinted per area at fire time).
		HitDust = {
			{ Name = "Dust", Tex = "smoke", Emit = { 7 }, Life = { 0.5, 0.9 }, Size = { { 0, 3 }, { 1, 9 } }, LE = 0.15, Speed = { 10, 26 }, Spread = 75,
				Drag = 3, Fade = "out", Spin = { -60, 60 }, Accel = Vector3.new(0, 7, 0), Color = rgb(225, 205, 170) },
			{ Name = "Chips", Tex = "dot", Emit = { 9 }, Life = { 0.6, 1.0 }, Size = { { 0, 0.8 }, { 1, 0.35 } }, LE = 0, Speed = { 22, 52 }, Spread = 60,
				Accel = Vector3.new(0, -70, 0), Color = rgb(176, 124, 72) },
		},
		-- LogRoll: a ramp launch (bigger dust, sparks, a flash).
		RampBurst = {
			{ Name = "Dust", Tex = "smoke", Emit = { 12 }, Life = { 0.6, 1.1 }, Size = { { 0, 4 }, { 1, 13 } }, LE = 0.15, Speed = { 14, 34 }, Spread = 80,
				Drag = 3, Fade = "out", Spin = { -60, 60 }, Accel = Vector3.new(0, 9, 0), Color = rgb(235, 215, 180) },
			{ Name = "Chips", Tex = "dot", Emit = { 16 }, Life = { 0.7, 1.2 }, Size = { { 0, 1 }, { 1, 0.4 } }, LE = 0, Speed = { 30, 70 }, Spread = 65,
				Accel = Vector3.new(0, -80, 0), Color = rgb(176, 124, 72) },
			{ Name = "Sparks", Tex = "spark", Emit = { 18 }, Orient = "VelocityParallel", Squash = 1.8, Life = { 0.25, 0.5 }, Size = { { 0, 0.6 }, { 1, 0 } },
				Speed = { 40, 110 }, Drag = 12, Spread = 70, Bright = 5, Color = rgb(255, 220, 130) },
			{ Name = "Flash", Tex = "glow", Emit = { 1 }, Life = 0.3, Size = { { 0, 4 }, { 1, 12 } }, Fade = "out", Bright = 1, Color = rgb(255, 220, 140) },
		},
		-- LogRoll: a SUPER ramp launch (a ramp burst plus a golden shockwave flare and a rising star shower).
		SuperBurst = {
			{ Name = "Dust", Tex = "smoke", Emit = { 18 }, Life = { 0.7, 1.3 }, Size = { { 0, 6 }, { 1, 18 } }, LE = 0.15, Speed = { 18, 44 }, Spread = 80,
				Drag = 3, Fade = "out", Spin = { -60, 60 }, Accel = Vector3.new(0, 10, 0), Color = rgb(240, 225, 190) },
			{ Name = "Sparks", Tex = "spark", Emit = { 34 }, Orient = "VelocityParallel", Squash = 1.8, Life = { 0.3, 0.7 }, Size = { { 0, 0.9 }, { 1, 0 } },
				Speed = { 60, 150 }, Drag = 10, Spread = 70, Bright = 5, Color = rgb(255, 200, 70) },
			{ Name = "Stars", Tex = "star", Emit = { 14 }, Life = { 0.8, 1.4 }, Size = { { 0, 0 }, { 0.4, 3 }, { 1, 0 } }, Speed = { 20, 60 }, Spread = 60,
				Drag = 2, Accel = Vector3.new(0, 14, 0), Bright = 3, Color = rgb(255, 230, 120) },
			{ Name = "Flash", Tex = "flare", Emit = { 1 }, Life = 0.5, Size = { { 0, 0 }, { 0.3, 26 }, { 1, 0 } }, Spin = { 60, 60 }, Fade = "out", Bright = 2.5, Color = rgb(255, 214, 120) },
		},
		-- LogRoll: a HYPER ramp launch (a super burst, bigger: a white-hot core flash, a cyan-magenta shockwave and a long star shower).
		HyperBurst = {
			{ Name = "Dust", Tex = "smoke", Emit = { 26 }, Life = { 0.8, 1.5 }, Size = { { 0, 8 }, { 1, 26 } }, LE = 0.15, Speed = { 24, 60 }, Spread = 85,
				Drag = 3, Fade = "out", Spin = { -60, 60 }, Accel = Vector3.new(0, 12, 0), Color = rgb(240, 225, 255) },
			{ Name = "Sparks", Tex = "spark", Emit = { 60 }, Orient = "VelocityParallel", Squash = 1.8, Life = { 0.4, 0.9 }, Size = { { 0, 1.2 }, { 1, 0 } },
				Speed = { 80, 220 }, Drag = 9, Spread = 75, Bright = 5, Color = rgb(120, 230, 255) },
			{ Name = "Stars", Tex = "star", Emit = { 26 }, Life = { 1.0, 1.8 }, Size = { { 0, 0 }, { 0.4, 4.5 }, { 1, 0 } }, Speed = { 30, 90 }, Spread = 70,
				Drag = 2, Accel = Vector3.new(0, 18, 0), Bright = 3, Color = rgb(255, 120, 220) },
			{ Name = "Flash", Tex = "flare", Emit = { 1 }, Life = 0.7, Size = { { 0, 0 }, { 0.3, 48 }, { 1, 0 } }, Spin = { 80, 80 }, Fade = "out", Bright = 3, Color = rgb(235, 245, 255) },
			{ Name = "Ring", Tex = "ringHard", Emit = { 1 }, Orient = "VelocityPerpendicular", Speed = 0.001, Life = 0.6, Size = { { 0, 4 }, { 1, 60 } }, Fade = "out", Bright = 2, Color = rgb(150, 235, 255) },
		},
		-- LogRoll: the HYPER climb charge: a steady crackle of lightning flipbooks, sparks and a violet glow round the log (parent follows it; the long bolts are drawn by HyperCutscene).
		HyperCharge = {
			{ Name = "Arcs", Tex = "lightningFlip", FlipMode = "Loop", FlipRandom = true, Rate = 16, Life = { 0.2, 0.35 }, Size = { { 0, 9 }, { 1, 14 } }, Spread = 180, Speed = 0.001,
				Fade = "dip", Bright = 4, Color = rgb(170, 235, 255), Locked = true },
			{ Name = "Sparks", Tex = "spark", Rate = 60, Orient = "VelocityParallel", Squash = 1.6, Life = { 0.25, 0.5 }, Size = { { 0, 0.8 }, { 1, 0 } },
				Speed = { 25, 70 }, Spread = 180, Drag = 6, Bright = 5, Color = rgb(150, 230, 255) },
			{ Name = "Glow", Tex = "glowRadial", Rate = 4, Life = { 0.5, 0.8 }, Size = { { 0, 12 }, { 1, 20 } }, Fade = "soft", Bright = 2, Color = rgb(150, 100, 255), Locked = true, Z = -1 },
		},
		-- LogRoll: the HYPER launch EXPLOSION (HyperBurst is the ground hit; this is the blast around the log as it leaves the ramp).
		HyperBlast = {
			{ Name = "Core", Tex = "flare", Emit = { 2 }, Life = 0.8, Size = { { 0, 0 }, { 0.25, 90 }, { 1, 0 } }, Spin = { 70, 70 }, Fade = "out", Bright = 4, Color = rgb(240, 248, 255) },
			{ Name = "Fire", Tex = "fireFlip", Emit = { 8 }, Life = { 0.7, 1.2 }, Size = { { 0, 14 }, { 1, 46 } }, Speed = { 10, 40 }, Spread = 180, Drag = 3, Fade = "out", Bright = 2, Color = rgb(150, 220, 255) },
			{ Name = "Shock", Tex = "ringHard", Emit = { 2 }, Orient = "FacingCamera", Speed = 0.001, Life = 0.7, Size = { { 0, 6 }, { 1, 120 } }, Fade = "out", Bright = 3, Color = rgb(190, 235, 255) },
			{ Name = "Sparks", Tex = "spark", Emit = { 90 }, Orient = "VelocityParallel", Squash = 1.8, Life = { 0.5, 1.1 }, Size = { { 0, 1.6 }, { 1, 0 } },
				Speed = { 90, 300 }, Drag = 8, Spread = 180, Bright = 5, Color = rgb(130, 225, 255) },
			{ Name = "Stars", Tex = "star", Emit = { 30 }, Life = { 1, 1.8 }, Size = { { 0, 0 }, { 0.4, 6 }, { 1, 0 } }, Speed = { 40, 120 }, Spread = 180,
				Drag = 2, Bright = 3, Color = rgb(255, 130, 230) },
		},
		-- LogRoll: the log breaks: splinters everywhere, a dust cloud, a flash.
		BreakSplinters = {
			{ Name = "Splinters", Tex = "streakDiamond", Emit = { 40 }, Orient = "VelocityParallel", Squash = 1.2, Life = { 0.8, 1.5 }, Size = { { 0, 1.8 }, { 1, 0.8 } },
				LE = 0, Speed = { 30, 95 }, Spread = 180, Drag = 1, Accel = Vector3.new(0, -60, 0), Color = rgb(180, 126, 72) },
			{ Name = "Chunks", Tex = "dot", Emit = { 18 }, Life = { 1, 1.6 }, Size = { { 0, 2.2 }, { 1, 1.2 } }, LE = 0, Speed = { 20, 60 }, Spread = 180,
				Accel = Vector3.new(0, -70, 0), Color = rgb(130, 86, 48) },
			{ Name = "Dust", Tex = "smoke", Emit = { 16 }, Life = { 1, 1.8 }, Size = { { 0, 6 }, { 1, 22 } }, LE = 0.1, Speed = { 12, 36 }, Spread = 180,
				Drag = 3, Fade = "out", Spin = { -40, 40 }, Accel = Vector3.new(0, 6, 0), Color = rgb(225, 205, 170) },
			{ Name = "Flash", Tex = "flare", Emit = { 1 }, Life = 0.5, Size = { { 0, 0 }, { 0.3, 18 }, { 1, 0 } }, Spin = { 60, 60 }, Bright = 2.5, Color = rgb(255, 230, 170) },
		},
		-- Dark contrast specks so sparkles read on pale/bright floors (LE 0, behind).
		Contrast = {
			{ Name = "Contrast", Tex = "star", Rate = 6, Life = { 0.8, 1.4 }, Size = { { 0, 0 }, { 0.5, 0.8 }, { 1, 0 } }, LE = 0, Color = rgb(60, 20, 100), Z = -0.5, Speed = 0.5, Spread = 180 },
		},
	},
}
