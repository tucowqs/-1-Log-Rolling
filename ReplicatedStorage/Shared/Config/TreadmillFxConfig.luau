--[[
	TreadmillFxConfig — the moving parts and particles of the three themed treadmills (TreadmillFxController; models from
	LogRolling/tools/blender/treadmills.py, picked per treadmill by BalanceConfig.Training.Treadmills[].Model).
	Power: 0 idle .. 1 while someone trains on that belt (player attribute Training = the treadmill Id), eased by Ease.
	Motions are keyed by the joint's kind (model attribute JointKind_<J>); Joints overrides one joint by name.
	  Spin   = rad/s at full power about Axis (model space), Idle = share of it while nobody runs
	  Swing  = { From, To } degrees about Axis, swept by power, + Jitter degrees at Rate while running (a speed dial)
	  Bob    = { studs, rad/s } up and down + Rock degrees of roll (always on)
	Fx: particle boxes at model-space At (studs, Roblox axes: X right, Y up, Z toward the console), Size = the box, Dir = the
	face they spray from, Idle = share of each emitter's Rate while nobody runs, Spec = VFXKit emitter specs.
	Flash: Glow parts (by name) that blink between their colour and Dim at Rate blinks/s (faster x Boost while running).
]]
local rgb = Color3.fromRGB

return {
	Ease = 3, -- power eases toward its target at this rate (per second)
	Range = 220, -- studs: farther treadmills don't animate
	Boost = 2.5, -- flash rate multiplier while running

	Models = {
		-- 2026-10-14 treadmills (tools/blender/treadmills.py build_new + treadmills_halloween.py): World 1's 20x, the three Robux zones
		-- (every world) and World 2's four. Kinds Spin / Turn / Bob are defined per model.
		TreadVolcano = { Motions = { Roller = { Spin = -14, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.3, 1.6 }, Rock = 10 } }, Fx = {}, Flash = {} },
		TreadKoi = { Motions = { Roller = { Spin = -6, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.08, 2 }, Rock = 12 } }, Fx = {}, Flash = {} },
		TreadGolden = { Motions = { Roller = { Spin = -13, Idle = 0.12, Axis = Vector3.xAxis }, Spin = { Spin = 0.8, Idle = 0.5, Axis = Vector3.yAxis } }, Fx = {}, Flash = {} },
		TreadAdmin = { Motions = { Roller = { Spin = -16, Idle = 0.12, Axis = Vector3.xAxis }, Spin = { Spin = 3, Idle = 0.4, Axis = Vector3.yAxis } }, Fx = {},
			Flash = { { Part = "GlowLED", Dim = rgb(10, 60, 30), Rate = 2 } } },
		TreadPumpkin = { Motions = { Roller = { Spin = -6, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.25, 1.4 }, Rock = 8 } }, Fx = {},
			Flash = { { Part = "GlowCarve", Dim = rgb(120, 60, 20), Rate = 1.2 } } },
		TreadGraveyard = { Motions = { Roller = { Spin = -9, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.35, 1.2 }, Rock = 6 } }, Fx = {},
			Flash = { { Part = "GlowGhostLamp", Dim = rgb(40, 90, 80), Rate = 0.8 } } },
		TreadWitch = { Motions = { Roller = { Spin = -12, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.4, 2.2 }, Rock = 0 } }, Fx = {}, Flash = {} },
		TreadVampire = { Motions = { Roller = { Spin = -14, Idle = 0.12, Axis = Vector3.xAxis }, Bob = { Bob = { 0.3, 1.6 }, Rock = 10 } }, Fx = {},
			Flash = { { Part = "GlowCandle", Dim = rgb(90, 10, 20), Rate = 1.6 } } },
		-- World 3 (Dream Kingdom, blender/logroll/treads_e.py): static models (no joint parts); the Glow* parts blink while someone runs
		TreadCandy = { Motions = {}, Fx = {}, Flash = { { Part = "GlowSign", Dim = rgb(150, 90, 120), Rate = 1.2 } } },
		TreadNeon = { Motions = {}, Fx = {}, Flash = { { Part = "GlowMagenta", Dim = rgb(90, 20, 70), Rate = 1.6 }, { Part = "GlowSign", Dim = rgb(0, 80, 100), Rate = 0.8 } } },
		TreadGear = { Motions = {}, Fx = {}, Flash = { { Part = "GlowCore", Dim = rgb(120, 80, 30), Rate = 1.4 } } },
		TreadGalaxy = { Motions = {}, Fx = {}, Flash = { { Part = "GlowStar", Dim = rgb(120, 110, 60), Rate = 1.0 }, { Part = "GlowRing", Dim = rgb(120, 100, 60), Rate = 0.7 } } },
		TreadRiver = {
			Motions = {
				Roller = { Spin = -7, Idle = 0.12, Axis = Vector3.xAxis }, -- the floating logs roll toward the back under your feet
				Wheel = { Spin = -1.4, Idle = 0.6, Axis = Vector3.xAxis },
				Bob = { Bob = { 0.12, 2.2 }, Rock = 8 },
			},
			Fx = {
				{ At = Vector3.new(0, 0.7, -8), Size = Vector3.new(1.6, 0.2, 2.5), Dir = "Top", Idle = 0.5, Spec = {
					{ Name = "Splash", Tex = "dotHalo", Rate = 26, Life = { 0.5, 0.9 }, Size = { { 0, 0.35 }, { 1, 0.1 } }, Color = rgb(200, 240, 255),
						LE = 0.4, Speed = { 3, 6 }, Spread = 35, Accel = Vector3.new(0, -18, 0) },
					{ Name = "Mist", Tex = "smoke", Rate = 3, Life = { 1, 1.6 }, Size = { { 0, 1 }, { 1, 2.4 } }, Color = rgb(225, 245, 255), LE = 0, LI = 1,
						Fade = "soft", Speed = 0.6, Spread = 60 },
				} },
				{ At = Vector3.new(0, 0.9, 8.6), Size = Vector3.new(7, 0.2, 1), Dir = "Top", Idle = 0, Spec = { -- the logs churn the water at the front
					{ Name = "Spray", Tex = "dotHalo", Rate = 18, Life = { 0.4, 0.7 }, Size = { { 0, 0.3 }, { 1, 0.08 } }, Color = rgb(210, 245, 255),
						LE = 0.4, Speed = { 2, 4 }, Spread = 40, Accel = Vector3.new(0, -16, 0) },
				} },
			},
			Flash = {},
		},

		TreadSawmill = {
			Motions = {
				Roller = { Spin = -9, Idle = 0.12, Axis = Vector3.xAxis },
				Saw = { Spin = 16, Idle = 0.25, Axis = Vector3.xAxis },
				Gear = { Spin = 2.4, Idle = 0.3, Axis = Vector3.zAxis },
				Needle = { Swing = { -55, 55 }, Jitter = 4, Rate = 11, Axis = Vector3.zAxis },
			},
			Joints = { GearB = { Spin = -3.4, Idle = 0.3, Axis = Vector3.zAxis } }, -- meshes against GearA
			Fx = {
				{ At = Vector3.new(-5.36, 0.6, 2.4), Size = Vector3.new(0.3, 0.3, 0.6), Dir = "Bottom", Idle = 0.1, Spec = { -- sawdust off each blade
					{ Name = "Sawdust", Tex = "dot", Rate = 30, Life = { 0.4, 0.8 }, Size = { { 0, 0.2 }, { 1, 0.08 } }, Color = { rgb(222, 172, 112), rgb(196, 134, 82) },
						LE = 0, LI = 1, Speed = { 4, 8 }, Spread = 45, Accel = Vector3.new(0, -20, 0), Rot = { 0, 360 }, Spin = { -200, 200 } },
				} },
				{ At = Vector3.new(5.36, 0.6, 2.4), Size = Vector3.new(0.3, 0.3, 0.6), Dir = "Bottom", Idle = 0.1, Spec = {
					{ Name = "Sawdust", Tex = "dot", Rate = 30, Life = { 0.4, 0.8 }, Size = { { 0, 0.2 }, { 1, 0.08 } }, Color = { rgb(222, 172, 112), rgb(196, 134, 82) },
						LE = 0, LI = 1, Speed = { 4, 8 }, Spread = 45, Accel = Vector3.new(0, -20, 0), Rot = { 0, 360 }, Spin = { -200, 200 } },
				} },
				{ At = Vector3.new(3, 7, -9), Size = Vector3.new(0.8, 0.2, 0.8), Dir = "Top", Idle = 0.4, Spec = { -- smoke stack
					{ Name = "Smoke", Tex = "smoke", Rate = 8, Life = { 1.6, 2.6 }, Size = { { 0, 1 }, { 1, 3.4 } }, Color = { rgb(150, 150, 160), rgb(110, 110, 120) },
						LE = 0, LI = 1, Fade = "soft", Speed = { 2, 3 }, Spread = 12, Accel = Vector3.new(0.6, 1, 0), Spin = { -30, 30 } },
				} },
				{ At = Vector3.new(-3.2, 4.6, -9), Size = Vector3.new(0.3, 0.2, 0.3), Dir = "Top", Idle = 0.2, Spec = { -- steam vent
					{ Name = "Steam", Tex = "smoke", Rate = 10, Life = { 0.5, 0.9 }, Size = { { 0, 0.4 }, { 1, 1.6 } }, Color = rgb(240, 244, 250),
						LE = 0, LI = 1, Fade = "soft", Speed = { 4, 6 }, Spread = 8 },
				} },
			},
			Flash = {},
		},

		TreadRocket = {
			Motions = {
				Roller = { Spin = -12, Idle = 0.12, Axis = Vector3.xAxis },
			},
			Fx = {
				{ At = Vector3.new(-2.3, 2.4, -10.5), Size = Vector3.new(1.2, 1.2, 0.2), Dir = "Front", Idle = 0.25, Spec = { -- rocket flames
					{ Name = "Flame", Tex = "fireFlip", Rate = 40, Life = { 0.25, 0.45 }, Size = { { 0, 1.6 }, { 1, 0.4 } }, Color = { rgb(255, 230, 140), rgb(255, 120, 40) },
						Bright = 2, Speed = { 10, 16 }, Spread = 6, Rot = { -20, 20 } },
					{ Name = "Smoke", Tex = "smoke", Rate = 6, Life = { 0.8, 1.4 }, Size = { { 0, 1 }, { 1, 3 } }, Color = rgb(120, 120, 130), LE = 0, LI = 1,
						Fade = "soft", Speed = { 6, 9 }, Spread = 10, Drag = 1.5 },
				} },
				{ At = Vector3.new(2.3, 2.4, -10.5), Size = Vector3.new(1.2, 1.2, 0.2), Dir = "Front", Idle = 0.25, Spec = {
					{ Name = "Flame", Tex = "fireFlip", Rate = 40, Life = { 0.25, 0.45 }, Size = { { 0, 1.6 }, { 1, 0.4 } }, Color = { rgb(255, 230, 140), rgb(255, 120, 40) },
						Bright = 2, Speed = { 10, 16 }, Spread = 6, Rot = { -20, 20 } },
					{ Name = "Smoke", Tex = "smoke", Rate = 6, Life = { 0.8, 1.4 }, Size = { { 0, 1 }, { 1, 3 } }, Color = rgb(120, 120, 130), LE = 0, LI = 1,
						Fade = "soft", Speed = { 6, 9 }, Spread = 10, Drag = 1.5 },
				} },
				{ At = Vector3.new(0, 0.6, -6.2), Size = Vector3.new(7, 0.2, 0.4), Dir = "Front", Idle = 0, Spec = { -- sparks thrown back off the rollers while running
					{ Name = "Sparks", Tex = "spark", Rate = 30, Life = { 0.2, 0.4 }, Size = { { 0, 0.25 }, { 1, 0 } }, Color = rgb(255, 200, 90), Bright = 3,
						Orient = "VelocityParallel", Squash = 1.5, Speed = { 8, 14 }, Spread = 30, Accel = Vector3.new(0, -30, 0) },
				} },
			},
			Flash = { { Part = "GlowBeacon", Dim = rgb(90, 20, 20), Rate = 1.2 } },
		},
	},
}
