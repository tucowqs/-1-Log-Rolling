--[[
	WorldsConfig — the worlds (2026-10-14, Preston: "each world has 8 zones ... for now just make 2 worlds"; World 1 Timber Wilds,
	World 2 Haunted Halloween, World 3 Dream Kingdom (2026-10-16)). Every world is the SAME hill shape (BalanceConfig.Areas = the 8 zone lengths / pitches) and the
	same lobby layout, built Offset studs away (tools/world_build.lua); its zones only differ in look, props and Wins.
	Runs are simulated in hill space (RunSim / Layout use s + lane only); the client draws them at the local world's Offset
	(Track.Offset), the server adds it where it moves characters (WorldService, RollService, BoundsService).
	  Need       Speed needed to unlock (Rock Skipping's "THROW WITH 100M"); once unlocked a world stays open (data.Worlds).
	             World 2: ~60% of the Speed cap at 13 rebirths (EconomyConfig), so it opens about when the World 1 logs run out
	  Art        the Worlds window card art (UiPack/Art spec)
	Zone fields (Worlds.Area): Name, WinsMult (Wins paid in the zone, Curves.WinsFor; GENERATED: Economy.ZoneWins, one ladder through
	every world), Ground / Accent (slope colours),
	Obstacle (bump / ramp tint), Wall = { checker pair, cap pair } (the ramp-wall look, tools/world_build.lua), WallProps (models the
	wall ledges carry, WallPropsController), Props + Landmark (scenery beside the lane, WorldPlan: Props = { { Model, Weight,
	{ minScale, maxScale } } }, Landmark = { Model, At (0-1 of the zone), Side, Offset, Scale }).
]]
local Economy = require(script.Parent.Parent.Modules.Economy)

local rgb = Color3.fromRGB

local function zone(name, ground, accent, obstacle, wall, wallProps, props, landmark)
	return { Name = name, Ground = ground, Accent = accent, Obstacle = { Main = obstacle[1], Trim = obstacle[2] },
		Wall = wall, WallProps = wallProps, Props = props, Landmark = landmark }
end

local config = {
	Bridges = {
		"WorldTravel", -- C->S { World }   teleport (unlocking it first if the player has the Speed)
	},
	Menu = "Worlds",
	Spawn = Vector3.new(0, 3, -40), -- a world's arrival point, from its Track.Origin + Offset (the World 1 SpawnLocation)
	-- The Worlds portal in every lobby (PortalController builds the Blender WorldPortal on Workspace.Portals.<world>, an anchor placed
	-- Place studs from that world's start line, facing the lobby path). Its swirl turns at Spin rad/s, the model's Main / Glow parts take the
	-- world's Art.Rays colour, the ProximityPrompt (Prompt.Reach studs, sits Prompt.Lift over the anchor) opens the Worlds window.
	Portal = {
		Size = Vector3.new(14, 16, 2),
		Place = Vector3.new(-26, 0, -78),
		Spin = 1.2,
		Prompt = { Action = "Worlds", Object = "Portal", Reach = 14, Lift = 6 },
		Billboard = { Size = Vector2.new(15, 7.3), Near = 20, Lift = 24, Max = 400 }, -- the sign over the arch (studs, WorldLabel)
		Gradients = { "Green", "Orange", "Pink" }, -- the sign's title gradient per world (UiPackConfig.Text)
		Text = { Title = "WORLDS", World = "World %d: %s" },
	},

	Worlds = {
		{
			Name = "Timber Wilds", Offset = Vector3.zero, Need = 0, RollZone = "RollZone",
			Art = { Models = { { Path = "World.Pine" } }, Spin = "Turn", Rays = rgb(120, 220, 90) },
			Areas = {
				zone("Whispering Woods", rgb(92, 178, 74), rgb(60, 140, 55), { rgb(188, 128, 72), rgb(122, 80, 44) },
					{ { rgb(204, 104, 74), rgb(168, 80, 60) }, { rgb(124, 206, 72), rgb(98, 182, 58) } }, { "WallLogPile", "WallMushroomRing", "WallBirdhouse" },
					{ { "Pine", 4, { 1.5, 2.3 } }, { "RoundTree", 3, { 1.5, 2.2 } }, { "Bush", 3, { 1.3, 2.0 } }, { "Stump", 1, { 1.3, 1.8 } } },
					{ "GiantTree", 0.55, -1, 120, 2.6 }),
				zone("Mossy Hollow", rgb(78, 150, 96), rgb(46, 110, 70), { rgb(150, 120, 80), rgb(90, 70, 46) },
					{ { rgb(96, 120, 84), rgb(76, 98, 66) }, { rgb(110, 200, 110), rgb(86, 176, 90) } }, { "WallMossyStump", "WallFern", "WallGlowMoss" },
					{ { "SwampTree", 3, { 1.5, 2.2 } }, { "Bush", 3, { 1.4, 2.1 } }, { "GlowShroom", 3, { 1.4, 2.0 } }, { "Stump", 2, { 1.4, 1.9 } } },
					{ "GiantTree", 0.5, 1, 130, 2.2 }),
				zone("Granite Cliffs", rgb(150, 150, 160), rgb(105, 105, 120), { rgb(206, 164, 104), rgb(132, 96, 60) },
					{ { rgb(128, 130, 140), rgb(104, 106, 116) }, { rgb(120, 180, 84), rgb(98, 160, 70) } }, { "WallBoulderStack", "WallPickaxeCart" },
					{ { "Boulder", 4, { 1.6, 3.0 } }, { "RockSpire", 3, { 1.6, 2.6 } }, { "Crag", 2, { 1.5, 2.4 } }, { "Pine", 1, { 1.3, 1.8 } } },
					{ "StoneArch", 0.5, 1, 140, 2.6 }),
				zone("Frostbite Fields", rgb(230, 242, 252), rgb(150, 205, 240), { rgb(70, 170, 235), rgb(34, 100, 190) },
					{ { rgb(150, 182, 214), rgb(122, 154, 190) }, { rgb(244, 250, 255), rgb(222, 236, 250) } }, { "WallIcicles", "WallSnowPile", "WallSled" },
					{ { "SnowPine", 4, { 1.5, 2.3 } }, { "IceBoulder", 3, { 1.6, 2.6 } }, { "IceSpire", 2, { 1.2, 2.0 } }, { "Snowman", 1, { 1.4, 1.9 } } },
					{ "IceSpire", 0.5, -1, 130, 3.4 }),
				zone("Sunscorch Canyon", rgb(232, 150, 80), rgb(190, 88, 52), { rgb(150, 92, 60), rgb(96, 56, 38) },
					{ { rgb(222, 140, 76), rgb(194, 110, 56) }, { rgb(255, 200, 110), rgb(246, 176, 84) } }, { "WallCactusPot", "WallWagonWheel", "WallSkullSign" },
					{ { "Cactus", 4, { 1.5, 2.3 } }, { "DesertRock", 3, { 1.6, 2.8 } }, { "Mesa", 2, { 1.2, 2.2 } }, { "Skull", 1, { 1.5, 2.0 } } },
					{ "MesaArch", 0.5, 1, 150, 2.4 }),
				zone("Blossom Ridge", rgb(246, 176, 206), rgb(214, 100, 150), { rgb(255, 150, 190), rgb(190, 80, 120) },
					{ { rgb(240, 152, 192), rgb(216, 124, 168) }, { rgb(255, 242, 248), rgb(255, 222, 236) } }, { "WallSakuraBush", "WallPaperLantern", "WallBench" },
					{ { "SakuraTree", 4, { 1.5, 2.3 } }, { "StoneLantern", 3, { 1.4, 2.0 } }, { "Bamboo", 3, { 1.4, 2.1 } }, { "Bush", 1, { 1.3, 1.8 } } },
					{ "Pagoda", 0.5, -1, 140, 2.6 }),
				zone("Toxic Marsh", rgb(76, 162, 150), rgb(40, 110, 110), { rgb(130, 232, 90), rgb(54, 140, 60) },
					{ { rgb(66, 152, 142), rgb(50, 126, 118) }, { rgb(134, 222, 202), rgb(108, 200, 180) } }, { "WallToxicDrum", "WallLilyPod", "WallBogLantern" },
					{ { "SwampTree", 3, { 1.5, 2.3 } }, { "ToxicMushroom", 4, { 1.5, 2.3 } }, { "BogReeds", 3, { 1.4, 2.0 } }, { "ToxicBarrel", 1, { 1.4, 1.8 } } },
					{ "GiantMushroom", 0.5, -1, 140, 2.6 }),
				zone("Magma Mountain", rgb(75, 60, 68), rgb(255, 92, 40), { rgb(255, 128, 56), rgb(150, 44, 30) },
					{ { rgb(74, 54, 52), rgb(54, 40, 40) }, { rgb(255, 120, 40), rgb(232, 86, 30) } }, { "WallLavaVent", "WallObsidianShard", "WallMinecart" },
					{ { "LavaRock", 4, { 1.6, 2.8 } }, { "ObsidianSpike", 3, { 1.4, 2.4 } }, { "DeadTree", 2, { 1.4, 2.0 } } },
					{ "Volcano", 0.6, 1, 330, 2.2 }),
			},
		},
		{
			Name = "Haunted Halloween", Offset = Vector3.new(1500, 0, 0), Need = 1e6, RollZone = "RollZone2",
			Art = { Models = { { Path = "World.JackOLantern" } }, Spin = "Turn", Rays = rgb(255, 140, 30) },
			Areas = {
				zone("Pumpkin Patch", rgb(120, 150, 60), rgb(255, 140, 30), { rgb(255, 150, 40), rgb(120, 60, 20) },
					{ { rgb(150, 90, 50), rgb(120, 70, 40) }, { rgb(255, 150, 40), rgb(230, 120, 30) } }, { "WallPumpkinStack", "WallScarecrow", "WallHayBale" },
					{ { "JackOLantern", 4, { 1.4, 2.2 } }, { "WallHayBale", 2, { 1.4, 2.0 } }, { "DeadTree", 2, { 1.4, 2.0 } } },
					{ "JackOLantern", 0.5, -1, 130, 6 }),
				zone("Graveyard", rgb(80, 96, 80), rgb(150, 160, 150), { rgb(170, 170, 180), rgb(80, 80, 90) },
					{ { rgb(90, 96, 100), rgb(70, 76, 80) }, { rgb(110, 130, 100), rgb(90, 110, 84) } }, { "WallGrave", "WallCoffinStand", "WallIronFence" },
					{ { "Gravestone", 4, { 1.4, 2.1 } }, { "SpookyTree", 3, { 1.5, 2.3 } }, { "GhostLamp", 2, { 1.4, 2.0 } } },
					{ "HauntedMansion", 0.5, 1, 190, 2.6 }),
				zone("Haunted Hollow", rgb(84, 64, 110), rgb(255, 140, 30), { rgb(255, 140, 30), rgb(70, 40, 90) },
					{ { rgb(84, 64, 110), rgb(64, 48, 88) }, { rgb(150, 110, 200), rgb(124, 90, 176) } }, { "WallDeadTree", "WallGhost", "WallCrookedSign" },
					{ { "SpookyTree", 4, { 1.5, 2.3 } }, { "JackOLantern", 3, { 1.4, 2.0 } }, { "GhostLamp", 2, { 1.4, 2.0 } } },
					{ "SpookyTree", 0.5, -1, 140, 5 }),
				zone("Witch Woods", rgb(70, 100, 70), rgb(170, 90, 230), { rgb(170, 90, 230), rgb(60, 30, 90) },
					{ { rgb(70, 60, 90), rgb(54, 46, 72) }, { rgb(120, 200, 90), rgb(96, 176, 74) } }, { "WallCauldron", "WallBroom", "WallPotionShelf" },
					{ { "SpookyTree", 3, { 1.5, 2.3 } }, { "ToxicMushroom", 3, { 1.4, 2.1 } }, { "WallCauldron", 1, { 1.4, 1.9 } } },
					{ "WallCauldron", 0.5, 1, 140, 6 }),
				zone("Bone Canyon", rgb(210, 190, 150), rgb(160, 130, 100), { rgb(240, 230, 210), rgb(140, 120, 100) },
					{ { rgb(200, 170, 130), rgb(176, 148, 110) }, { rgb(240, 230, 210), rgb(220, 206, 184) } }, { "WallRibcage", "WallBonePile", "WallDinoSkull" },
					{ { "Skull", 3, { 1.5, 2.2 } }, { "DesertRock", 3, { 1.6, 2.6 } }, { "WallBonePile", 2, { 1.4, 2.0 } } },
					{ "WallDinoSkull", 0.5, -1, 150, 6 }),
				zone("Ghost Ship Cove", rgb(60, 110, 130), rgb(120, 230, 220), { rgb(120, 230, 220), rgb(40, 80, 100) },
					{ { rgb(70, 90, 110), rgb(54, 72, 90) }, { rgb(110, 200, 200), rgb(86, 176, 180) } }, { "WallAnchor", "WallBarrelStack", "WallShipWheel" },
					{ { "WallBarrelStack", 3, { 1.4, 2.0 } }, { "GhostLamp", 3, { 1.4, 2.0 } }, { "DeadTree", 2, { 1.4, 2.0 } } },
					{ "WallShipWheel", 0.5, 1, 140, 5 }),
				zone("Spider Caves", rgb(60, 50, 70), rgb(140, 255, 120), { rgb(140, 255, 120), rgb(50, 40, 60) },
					{ { rgb(56, 48, 66), rgb(42, 36, 52) }, { rgb(110, 90, 130), rgb(90, 72, 110) } }, { "WallCobweb", "WallSpiderEgg", "WallGiantSpider" },
					{ { "WallSpiderEgg", 3, { 1.4, 2.0 } }, { "ObsidianSpike", 3, { 1.4, 2.2 } }, { "GlowShroom", 2, { 1.4, 2.0 } } },
					{ "WallGiantSpider", 0.5, -1, 140, 5 }),
				zone("Vampire Castle", rgb(70, 40, 50), rgb(220, 40, 60), { rgb(220, 40, 60), rgb(40, 20, 30) },
					{ { rgb(64, 44, 56), rgb(48, 32, 42) }, { rgb(200, 40, 60), rgb(170, 30, 50) } }, { "WallCandelabra", "WallGargoyle", "WallBatBanner" },
					{ { "WallCandelabra", 3, { 1.4, 2.0 } }, { "SpookyTree", 3, { 1.5, 2.3 } }, { "Gravestone", 2, { 1.4, 2.0 } } },
					{ "WallGargoyle", 0.5, 1, 160, 6 }),
			},
		},
		{
			Name = "Dream Kingdom", Offset = Vector3.new(3000, 0, 0), Need = 9e8, RollZone = "RollZone3",
			Art = { Models = { { Path = "World.RainbowArch" } }, Spin = "Turn", Rays = rgb(255, 150, 220) },
			Areas = {
				zone("Candy Meadow", rgb(255, 196, 224), rgb(255, 120, 170), { rgb(255, 150, 190), rgb(160, 70, 120) },
					{ { rgb(255, 170, 205), rgb(240, 140, 185) }, { rgb(255, 244, 230), rgb(255, 226, 200) } }, { "WallCandyJar", "WallGingerbread", "WallDonutStack" },
					{ { "Lollipop", 4, { 1.4, 2.1 } }, { "Gumdrop", 3, { 1.5, 2.2 } }, { "CandyCane", 3, { 1.4, 2.0 } }, { "Cupcake", 1, { 1.3, 1.8 } } },
					{ "CandyCastle", 0.5, -1, 200, 1.8 }),
				zone("Coral Lagoon", rgb(120, 215, 220), rgb(255, 130, 120), { rgb(255, 140, 120), rgb(190, 70, 90) },
					{ { rgb(90, 190, 205), rgb(70, 166, 184) }, { rgb(255, 214, 200), rgb(240, 190, 176) } }, { "WallCoralFan", "WallBubbleTank", "WallTreasureChest" },
					{ { "CoralTree", 4, { 1.4, 2.1 } }, { "Anemone", 3, { 1.4, 2.0 } }, { "KelpStalk", 3, { 1.3, 1.9 } }, { "SeaShell", 1, { 1.4, 2.0 } } },
					{ "GiantClam", 0.5, 1, 190, 2.2 }),
				zone("Neon Metropolis", rgb(52, 58, 100), rgb(0, 200, 230), { rgb(0, 200, 230), rgb(210, 50, 170) },
					{ { rgb(44, 50, 88), rgb(34, 40, 72) }, { rgb(210, 50, 170), rgb(180, 40, 146) } }, { "WallArcade", "WallNeonBillboard", "WallDroneBot" },
					{ { "NeonPylon", 3, { 1.3, 1.9 } }, { "DataCube", 3, { 1.4, 2.0 } }, { "HoloSign", 2, { 1.3, 1.8 } }, { "SatelliteDish", 2, { 1.3, 1.8 } } },
					{ "NeonSkyscraper", 0.5, -1, 170, 1.6 }),
				zone("Clockwork Foundry", rgb(140, 108, 70), rgb(236, 180, 90), { rgb(214, 160, 80), rgb(96, 70, 50) },
					{ { rgb(110, 86, 60), rgb(90, 70, 50) }, { rgb(214, 160, 80), rgb(190, 138, 66) } }, { "WallCogWheel", "WallPistonRig", "WallWindupToy" },
					{ { "BigGear", 3, { 1.3, 1.9 } }, { "SteamPipe", 3, { 1.3, 1.9 } }, { "Boiler", 2, { 1.2, 1.7 } }, { "CogStack", 2, { 1.3, 1.9 } } },
					{ "ClockTower", 0.5, 1, 170, 1.8 }),
				zone("Crystal Caverns", rgb(96, 84, 130), rgb(190, 130, 255), { rgb(170, 100, 240), rgb(60, 40, 100) },
					{ { rgb(84, 74, 112), rgb(66, 58, 92) }, { rgb(170, 230, 255), rgb(140, 206, 240) } }, { "WallGeode", "WallMineLamp", "WallGemPile" },
					{ { "CrystalCluster", 4, { 1.4, 2.1 } }, { "CrystalSpire", 3, { 1.3, 1.9 } }, { "PrismShard", 2, { 1.4, 2.0 } } },
					{ "CrystalTower", 0.5, -1, 180, 2.0 }),
				zone("Cloud Gardens", rgb(236, 242, 255), rgb(255, 214, 110), { rgb(255, 214, 110), rgb(150, 120, 200) },
					{ { rgb(214, 226, 250), rgb(190, 206, 240) }, { rgb(255, 236, 170), rgb(246, 214, 130) } }, { "WallCloudBench", "WallStarFlower", "WallHarp" },
					{ { "CloudPuff", 4, { 1.4, 2.1 } }, { "StarLantern", 3, { 1.3, 1.9 } }, { "RainbowArch", 1, { 0.8, 1.1 } } },
					{ "CelestialGate", 0.5, 1, 200, 1.2 }),
				zone("Starfall Summit", rgb(52, 44, 110), rgb(255, 226, 120), { rgb(255, 170, 90), rgb(60, 50, 120) },
					{ { rgb(44, 38, 92), rgb(34, 30, 74) }, { rgb(120, 150, 255), rgb(96, 126, 240) } }, { "WallTelescope", "WallRocketPod", "WallMeteor" },
					{ { "CometSpike", 3, { 1.3, 1.9 } }, { "MoonRock", 4, { 1.5, 2.4 } }, { "StarCrystal", 3, { 1.3, 1.9 } } },
					{ "RingedPlanet", 0.5, -1, 230, 1.6 }),
				zone("Dream Summit", rgb(200, 170, 250), rgb(255, 160, 220), { rgb(255, 150, 210), rgb(100, 60, 170) },
					{ { rgb(186, 150, 240), rgb(166, 130, 224) }, { rgb(255, 224, 130), rgb(246, 200, 96) } }, { "WallCrown", "WallTrophyStar", "WallBanner" },
					{ { "StarLantern", 3, { 1.4, 2.0 } }, { "StarCrystal", 3, { 1.4, 2.0 } }, { "PrismShard", 2, { 1.4, 2.0 } }, { "CloudPuff", 2, { 1.4, 2.0 } } },
					{ "RainbowArch", 0.5, 1, 220, 5 }),
			},
		},
	},

	Text = { Here = "YOU ARE HERE", Go = "TELEPORT", Locked = "LOCKED", Need = "Roll with %s Speed", Title = "World %d", Unlocked = "%s unlocked!",
		NeedMore = "You need %s Speed to unlock %s!" },
}

for w, world in config.Worlds do
	for i, area in world.Areas do
		area.WinsMult = Economy.ZoneWins(w, i)
	end
end

return config
