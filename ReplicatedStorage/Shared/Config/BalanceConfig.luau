--[[
	BalanceConfig — THE single place for every gameplay/balance number in LogRoll. Rebalance here only; no logic file
	holds a tunable. Read by Track / Layout / RunSim / Curves (shared), RollService / LogService / TrainingService
	(server) and the run/shop/training controllers (client).

	Units: studs, seconds, studs/second. S = the player's Speed, n = log10(1 + S).
	Soft cap: Soft(S) = n / (n + Speed.Half) climbs fast early and flattens late (never reaches 1).
	    value = Low + (High - Low) * Soft(S)
	Economy loop: hits -> Speed -> a faster log (literal velocity) -> further area in the same lifespan -> Wins -> better log -> more Speed per hit.
]]
local Economy = require(script.Parent.Parent.Modules.Economy)
local EconomyConfig = require(script.Parent.EconomyConfig)

local rgb = Color3.fromRGB

return {
	-- Bridges (Net registers these). ONE table payload per Fire.
	Bridges = {
		"LogPadUse", -- C->S {Id}                        used a log pedestal's prompt: buy the log, or equip it if owned
		"Launch", -- C->S {Seed}                       start a run on the ramp field the client rolled (the one-tap Roll / Roll again)
		"ReturnTop", -- C->S {}                         walk back up to the start without rolling
		"ReturnSpawn", -- C->S {}                       after a break: back to the lobby spawn (the camera pans there)
		"RunStarted", -- S->all {UserId, StartTime, Speed, LogId, Seed, Steer, Infinite}   everyone replays the same run
		"Steer", -- C->S {T, D}                      steering input (run time, -1..1); server re-simulates from T
		"RunSteer", -- S->all {UserId, T, D}         everyone applies the same steering to that log
		"RunHits", -- S->owner {Gain, Speed, Hits, Level, LevelHits, Count, Levels}   batched hit totals (<= 5 / s)
		"RunEnded", -- S->all {UserId}                 the run is over (everyone drops that log)
		"RunResult", -- S->owner {AreaIndex, Wins, SpeedGained, Distance, Best, Levels, Finished}
		"BuyLog", -- C->S {Id}
		"EquipLog", -- C->S {Id}
		"LogBought", -- S->owner {Id}   purchase confirmed (celebration + sound)
		"TrainBegin", -- C->S {Station}   step onto a treadmill and start running
		"TrainEnd", -- C->S {}
		"TrainResult", -- S->owner {Gain, Speed, Station, Level, LevelHits, Levels}
	},

	-- ===== The hill (one continuous downhill, +Z heading, X = lateral). Areas run top -> bottom. =====
	Track = {
		Origin = Vector3.new(0, 4700, 0), -- the start line at the top (the launch point)
		HalfWidth = 78, -- the playable half width: lanes are -HalfWidth .. HalfWidth
		SurfaceHalfWidth = 92, -- the built slope (and the lobby plateau) is this wide each side; studded banks lean out from there
		MetersPerStud = 0.28, -- the HUD distance counter (RunHudController) shows metres, not studs
		Blend = 26, -- studs either side of an area joint where the log's tilt eases between pitches
		FinishMargin = 70, -- the log stops this far before the bottom edge
		LogRadius = 3.2, -- studs of a full-size log
	},

	-- The hill's 8 zones (2026-10-14: 8 per world). Only the SHAPE lives here, shared by every world; each zone's name, colours,
	-- Wins and props are WorldsConfig.Worlds[w].Areas[i] (Worlds.Area). Every zone has the same Pitch: one straight downhill plane.
	Areas = {
		{ Length = 600, Pitch = 22 }, { Length = 650, Pitch = 22 }, { Length = 700, Pitch = 22 }, { Length = 750, Pitch = 22 },
		{ Length = 800, Pitch = 22 }, { Length = 850, Pitch = 22 }, { Length = 900, Pitch = 22 }, { Length = 950, Pitch = 22 },
	},

	-- ===== Bumps and ramps (rolled on the CLIENT per run from a random seed; Layout.luau) =====
	-- The same everywhere on the hill: no per-area logic. Each obstacle is a weighted roll, the worse ones weigh more.
	Obstacles = {
		Weights = { Ramp = 66, Super = 31, Hyper = 3 }, -- relative odds of each kind (Bumps / rocks removed 2026-10-15: the mini Ramp is the smallest; Hyper 6% -> 3%)
		Gap = 52, -- average studs between obstacle centres (jittered 0.6x .. 1.5x)
		MinSpacing = 30, -- hard minimum studs between two obstacles (edge to edge), so they never overlap or stack
		AfterRampGap = 70, -- extra clear run after a ramp (it throws the log far)
		StartMargin = 90, -- first obstacle this far down the hill
		StartZone = { Length = 200, Spacing = 40 }, -- dense start: one every ~Spacing studs, so early runs always hit several
		-- Scale = { min, max } size roll; bigger ramps are rolled for the better kinds
		Bump = { Width = 20, Depth = 13, Height = 2.6, Speed = 1, AirTime = 0.5, AirHeight = 5, Scale = { 0.9, 1.3 } },
		Ramp = { Width = 26, Depth = 24, Height = 6.5, Speed = 3, AirTime = 1.15, AirHeight = 17, Scale = { 1.1, 1.6 } },
		-- the Super Ramp: launches TWICE as high as a ramp and pays 3x the Speed
		Super = { Width = 30, Depth = 28, Height = 10, Speed = 9, AirTime = 1.6, AirHeight = 34, Scale = { 1.5, 2 } },
		-- the Hyper Ramp: launches ~2x as high as a Super and pays 3x its Speed. It launches from its LIP, and the climb plays as a slow-motion cutscene
		Hyper = { Width = 36, Depth = 32, Height = 14, Speed = 27, AirTime = 2.4, AirHeight = 60, Scale = { 2, 2.6 } },
		-- Hyper cutscene (RunSim time warp, Run/HyperCutscene): wall-clock seconds of the slow climb (Rate = climb / Climb, clamped); normal speed resumes at the launch / explosion
		HyperCine = { Climb = 2.4, MinRate = 0.08, MaxRate = 0.5 },
		TouchLookBack = 180, -- studs behind the log that Ramp touch tests still look (>= the deepest ramp)
		HitSlack = 3, -- extra lateral studs of forgiveness when testing a hit
		LeadIn = 0.6, -- seconds the log lingers on the start line before it rolls (camera/countdown)
	},

	-- ===== Rolling physics (1D along the hill, deterministic) =====
	Physics = {
		Dt = 1 / 30, -- fixed sim step: server and clients replay identical runs
		MaxRunTime = 150, -- seconds, hard stop
		Lane = { Wobble = 22, Wobble2 = 9, Length1 = 190, Length2 = 61, MaxSpeed = 46, MagnetTime = 1.5, MagnetRange = 120 },
		Steer = { Speed = 55, Lag = 0.3, DragPixels = 90, MaxPerSecond = 12 }, -- player steering: studs/s at full input, oldest past input the server accepts (s); the client applies its own input at once, drag px for full input, send rate cap
	},

	-- ===== Speed curves (diminishing / soft-capped) =====
	Speed = {
		Half = 4, -- larger = Speed matters for longer
		MaxSpeed = { 58, 300 }, -- Low, High: the log's constant velocity in studs/s (Low at 0 Speed, High at the soft cap)
	},

	-- ===== The log shrinks continuously and breaks at MinSize =====
	Shrink = {
		Seconds = 15, -- fallback life; each log lives its own Durability seconds (Logs below), whatever your Speed
		MinSize = 0.28, -- the log breaks when it shrinks to this fraction of its size
		LandWait = 1.2, -- max extra seconds to finish an airborne arc before breaking
	},

	-- ===== Wins (paid when the log breaks) =====
	Wins = {
		Base = 1,
		DistanceBonus = 0.5, -- + up to 50% across the area the log stopped in
		FinishMult = 1.5, -- reaching the bottom of the hill
	},

	-- ===== Level = Speed: the same value is your Speed and your XP (Curves.LevelFor). XP to leave level L = BaseXP x Growth^(L-1) (EconomyConfig) =====
	Level = EconomyConfig.Level,

	-- ===== Logs: Mult = Speed per hit, Durability = seconds the log lasts on its own world's hill (Curves.Life wears it down in later worlds).
	-- Mult / Price / Durability (and Tier / World) are GENERATED from the log's place in this list by Economy.FillLogs (formulas: EconomyConfig);
	-- PerWorld logs per world, in order. Colors drive the Studio/Blender look. =====
	Logs = Economy.FillLogs({
		{ Id = "Wood", Name = "Basic Log", Rays = rgb(205, 150, 90) },
		{ Id = "Birch", Name = "Birch Log", Rays = rgb(235, 235, 225) },
		{ Id = "Oak", Name = "Oak Log", Rays = rgb(150, 100, 60) },
		{ Id = "Stone", Name = "Stone Log", Rays = rgb(170, 170, 180) },
		{ Id = "Iron", Name = "Iron Log", Rays = rgb(150, 175, 205) },
		{ Id = "Crystal", Name = "Crystal Log", Rays = rgb(130, 235, 255) },
		{ Id = "Golden", Name = "Golden Log", Rays = rgb(255, 210, 60) },
		{ Id = "Magma", Name = "Magma Log", Rays = rgb(255, 110, 40) },
		{ Id = "Cosmic", Name = "Cosmic Log", Rays = rgb(190, 110, 255) },
		{ Id = "Ruby", Name = "Ruby Log", Rays = rgb(255, 70, 110) },
		-- World 2 logs (Haunted Halloween; World = the world whose pads sell it, tools/lobby_layout.lua)
		{ Id = "PumpkinLog", World = 2, Name = "Pumpkin Log", Rays = rgb(255, 150, 40) },
		{ Id = "BoneLog", World = 2, Name = "Bone Log", Rays = rgb(240, 230, 210) },
		{ Id = "CoffinLog", World = 2, Name = "Coffin Log", Rays = rgb(150, 90, 60) },
		{ Id = "CobwebLog", World = 2, Name = "Cobweb Log", Rays = rgb(220, 220, 230) },
		{ Id = "CauldronLog", World = 2, Name = "Cauldron Log", Rays = rgb(120, 255, 90) },
		{ Id = "GhostLog", World = 2, Name = "Ghost Log", Rays = rgb(200, 255, 250) },
		{ Id = "CandyCornLog", World = 2, Name = "Candy Corn Log", Rays = rgb(255, 200, 60) },
		{ Id = "SpiderLog", World = 2, Name = "Spider Log", Rays = rgb(140, 90, 200) },
		{ Id = "VampireLog", World = 2, Name = "Vampire Log", Rays = rgb(220, 40, 60) },
		{ Id = "CursedLog", World = 2, Name = "Cursed Log", Rays = rgb(180, 80, 255) },
		-- World 3 logs (Dream Kingdom, tiers 21-30; the same ladders as every other log: Economy.FillLogs)
		{ Id = "CandyLog", World = 3, Name = "Candy Log", Rays = rgb(255, 150, 190) },
		{ Id = "CoralLog", World = 3, Name = "Coral Log", Rays = rgb(255, 130, 120) },
		{ Id = "NeonLog", World = 3, Name = "Neon Log", Rays = rgb(0, 200, 230) },
		{ Id = "GearLog", World = 3, Name = "Gear Log", Rays = rgb(214, 160, 80) },
		{ Id = "PrismLog", World = 3, Name = "Prism Log", Rays = rgb(200, 170, 255) },
		{ Id = "CloudLog", World = 3, Name = "Cloud Log", Rays = rgb(230, 240, 255) },
		{ Id = "RainbowLog", World = 3, Name = "Rainbow Log", Rays = rgb(255, 200, 90) },
		{ Id = "CometLog", World = 3, Name = "Comet Log", Rays = rgb(255, 160, 70) },
		{ Id = "GalaxyLog", World = 3, Name = "Galaxy Log", Rays = rgb(150, 100, 255) },
		{ Id = "DreamLog", World = 3, Name = "Dream Log", Rays = rgb(255, 170, 230) },
		-- the limited Robux log (LimitedConfig.ReaperRelic): "Always 200% better" = Better x your best other log (Curves.LogMult); never on a pad.
		-- It lasts as long as the best World 1 log (so it can't skip World 2's zones: it wears down there like any World 1 log)
		{ Id = "ReaperLog", Name = "Reaper Relic", Price = math.huge, Limited = true, Better = 2, Mult = 0, Durability = Economy.LogLife(EconomyConfig.Logs.PerWorld), Rays = rgb(90, 255, 230) },
	}),
	LogPads = { -- the purchasable logs on a stepped podium on the LEFT of the lobby, facing the spawn path: touch one with enough Wins to buy + equip it (LogPadService)
		-- Rows nearest the path first (filled in Logs order): Count pedestals, X = row centre, Y = the top of the step the row stands on (offsets from the start line)
		Rows = { { Count = 5, X = 64, Y = 1.8 }, { Count = 5, X = 80, Y = 4.6 } },
		Z = -80, -- centre of the podium along Z (tools/lobby_layout.lua places the pads from Rows / Z / Spacing)
		Spacing = 13, -- studs between pedestals
		Pad = Vector3.new(8, 1.2, 8), -- the pedestal (its top face is the touch plate)
		Log = { Length = 5.4, Radius = 1.5, Lift = 0.3 }, -- the studio-built log lying on the pedestal (axis along Z, so the side faces the path)
		Float = { Hover = 1.5, Bob = 0.3, Speed = 1.6 }, -- client: each log hovers this many studs over its pedestal and bobs +-Bob studs (Speed rad/s)
		Cooldown = 1.5, -- seconds before the same player can trigger the same pedestal again
		Prompt = { Distance = 6, Slack = 6 }, -- the ProximityPrompt's reach in studs; the server accepts Distance + Slack from the pedestal
		Afford = { Text = "You can afford the %s! Visit the log stand.", Kind = "Success" }, -- toast (once per log) for the best log you don't own that your Wins cover (LogAffordController)
		Billboard = { Size = Vector2.new(6.4, 3.8), Near = 16, Lift = 7.8 }, -- studs; Lift = height over the pedestal top (clear of the hovering log)
	},

	-- ===== Lobby (the small flat start area behind the start line; built in Studio by tools/build_lobby.lua) =====
	Lobby = {
		Depth = 176, -- how far the flat plateau runs back from the start line (the lobby platforms, then the pet hatchery behind the spawn)
		SpawnZ = -40, -- the spawn (and the cross path) sit this far behind the start line
		Platforms = { -- Center = offset from the start line (Y = the plateau), Size.Y = how far the platform stands over it
			Train = { Center = Vector3.new(-50, 0, -40), Size = Vector3.new(44, 1, 56), Color = rgb(88, 190, 215) }, -- RIGHT of the spawn (treadmills)
			Logs = { Center = Vector3.new(47, 0, -40), Size = Vector3.new(38, 1, 56), Color = rgb(190, 186, 226) }, -- LEFT of the spawn (log podium)
		},
		StepDepth = 14, -- width of each podium step (along X)
		Path = { Color = rgb(206, 200, 232), Width = 10, Thickness = 0.5 }, -- the cross path through the spawn, plus the approach to the start line
		Throw = { Color = rgb(255, 196, 70), Width = 60, Depth = 8, Z = -8 }, -- the orange pad in front of the start line
	},

	-- ===== Training (running on treadmills near spawn) =====
	Training = {
		-- server: seconds of running per Speed payout (Curves.TrainTick): Fast for a brand-new player, easing up to Slow once their
		-- hidden lifetime level count (data.TotalLevels, never reset by rebirths) reaches SlowAt, then staying there.
		-- ~100 total levels = around 5 rebirths (9 + 14 + 19 + 24 + 29 levels).
		Tick = { Fast = 0.15, Slow = 0.3, SlowAt = 100 },
		Rate = EconomyConfig.Training.Rate, -- tick gain = Rate x belt Mult x the equipped log's Mult (Curves.TrainGain): Rate 1 = the log's "+N Speed / hit" per tick on Jog, no Wins
		Reach = 13, -- studs from the belt centre you must stay within (the runner stands on top of the log, so this includes its height)
		Prompt = { Distance = 11 }, -- the Run / Stop ProximityPrompt's reach in studs from the belt centre; the server accepts a start within this of the belt's edge
		LogScale = 0.8, -- size of the visual log the runner balances on (its length fits the belt width)
		LogSpin = 7, -- radians per second the visual log turns under the runner
		RunAnimation = "rbxassetid://507767714", -- the standard Roblox R15 run
		RunAnimSpeed = 1.15, -- playback speed of the run animation on the belt
		Belt = { Size = Vector3.new(8, 1, 16), Color = rgb(52, 52, 60) }, -- studs (X = width, Z = run length): the walkable collider; the Blender "Conveyor" model (tinted per treadmill) is the look
		Yaw = 90, -- degrees: the belts' +Z end (the runner's front) points +X, toward the spawn path (the model's front; its motor end is behind)
		RunFacing = -1, -- the runner faces the belt's -Z (away from the spawn path), against the model's front; +1 = faces the front
		Billboard = { Size = Vector2.new(12, 5.4), Near = 18, Lift = 6.5, AlwaysOnTop = true }, -- studs (2026-10-15: 1.5x, drawn over the belts); the name + Skill-needed label over each belt (built in Studio by tools/build_lobby.lua)
		-- a row of treadmills; Pos = offset from the start line (the spawn is at Lobby.SpawnZ). Rebirths = rebirths required to use it (better belts are locked behind more rebirths).
		-- 2026-10-15 economy: Mult is a plain ladder (the log's Mult carries the world scaling); World 2 belts unlock from rebirth 13, about when World 2 opens.
		Guide = { Text = "Run on the %s!", Header = "REBIRTHED:", Marker = "RUN" }, -- after a rebirth: a sticky toast + arrow beam to the best treadmill they can use, until they step on it (TreadmillGuideController)
		Sign = { Unlocked = "UNLOCKED", Locked = "LOCKED", Mult = "%dx SPEED", Price = "ONLY %s", AllWorlds = "ALL WORLDS" }, -- the billboard texts (TrainSignController colours the status green / red per player)
		-- Model = the themed Blender treadmill laid over the Belt (LogRolling/tools/blender/treadmills.py; animated by TreadmillFxController)
		-- 2026-10-14 (Rock Skipping layout): 4 rebirth-locked belts per world (World = the world they stand in) + the 3 Robux zones in
		-- EVERY world (AllWorlds: Curves.Treadmills makes one station per world, same Mult; Pass = the ShopConfig
		-- pass that unlocks it; a locked one prompts the pass). Pos = from the world's start line (tools/lobby_layout.lua places them).
		Treadmills = {
			{ Id = "Jog", World = 1, Model = "TreadRiver", Name = "Jogging Belt", Mult = 1, Rebirths = 0, Color = rgb(92, 190, 84), Pos = Vector3.new(-84, 1, -45) },
			{ Id = "Sprint", World = 1, Model = "TreadSawmill", Name = "Sprint Belt", Mult = 2, Rebirths = 3, Color = rgb(255, 160, 50), Pos = Vector3.new(-84, 1, -73) },
			{ Id = "Turbo", World = 1, Model = "TreadRocket", Name = "Turbo Belt", Mult = 3, Rebirths = 6, Color = rgb(235, 70, 70), Pos = Vector3.new(-84, 1, -101) },
			{ Id = "Volcano", World = 1, Model = "TreadVolcano", Name = "Volcano Belt", Mult = 4, Rebirths = 9, Color = rgb(255, 110, 40), Pos = Vector3.new(-84, 1, -129) },
			{ Id = "Pumpkin", World = 2, Model = "TreadPumpkin", Name = "Pumpkin Belt", Mult = 5, Rebirths = 13, Color = rgb(255, 140, 30), Pos = Vector3.new(-84, 1, -45) },
			{ Id = "Graveyard", World = 2, Model = "TreadGraveyard", Name = "Graveyard Belt", Mult = 6, Rebirths = 16, Color = rgb(150, 160, 150), Pos = Vector3.new(-84, 1, -73) },
			{ Id = "Witch", World = 2, Model = "TreadWitch", Name = "Witch Belt", Mult = 8, Rebirths = 19, Color = rgb(170, 90, 230), Pos = Vector3.new(-84, 1, -101) },
			{ Id = "Vampire", World = 2, Model = "TreadVampire", Name = "Vampire Belt", Mult = 10, Rebirths = 22, Color = rgb(220, 40, 60), Pos = Vector3.new(-84, 1, -129) },
			-- World 3 (Dream Kingdom): the next steps of the ladder (x12 .. x20), unlocked from rebirth 25 (World 3 opens around rebirth 24)
			{ Id = "Candy", World = 3, Model = "TreadCandy", Name = "Candy Belt", Mult = 12, Rebirths = 25, Color = rgb(255, 150, 190), Pos = Vector3.new(-84, 1, -45) },
			{ Id = "Neon", World = 3, Model = "TreadNeon", Name = "Neon Belt", Mult = 14, Rebirths = 28, Color = rgb(0, 200, 230), Pos = Vector3.new(-84, 1, -73) },
			{ Id = "Gear", World = 3, Model = "TreadGear", Name = "Gear Belt", Mult = 17, Rebirths = 31, Color = rgb(214, 160, 80), Pos = Vector3.new(-84, 1, -101) },
			{ Id = "Galaxy", World = 3, Model = "TreadGalaxy", Name = "Galaxy Belt", Mult = 20, Rebirths = 34, Color = rgb(150, 90, 235), Pos = Vector3.new(-84, 1, -129) },
			{ Id = "Koi", AllWorlds = true, Pass = "KoiZone", Model = "TreadKoi", Name = "Koi Zone", Mult = 4, Rebirths = 0, Color = rgb(255, 150, 190), Pos = Vector3.new(-84, 1, -169) },
			{ Id = "Golden", AllWorlds = true, Pass = "GoldenZone", Model = "TreadGolden", Name = "Golden Zone", Mult = 8, Rebirths = 0, Color = rgb(255, 200, 60), Pos = Vector3.new(-84, 1, -197) },
			{ Id = "Admin", AllWorlds = true, Pass = "AdminZone", Model = "TreadAdmin", Name = "Admin Zone", Mult = 12, Rebirths = 0, Color = rgb(60, 230, 110), Pos = Vector3.new(-84, 1, -225) },
		},
	},

	-- ===== Scenery: streamed + pooled on every client (EditableMesh models are client-built) =====
	World = {
		Seed = 7717,
		Ahead = 1500, Behind = 260, Tick = 0.25, -- studs of hill kept alive around the camera, seconds between updates
		PropGap = { 22, 40 }, -- studs between props down each side
		Edge = { 4, 11 }, -- lateral studs beyond the playable lane (the slope only extends 14 past it)
		Gates = { StartAt = 0, Scale = 2.2 }, -- the roll sign over the start line (Blender RollSign); an AreaGate sits at each joint
		Sign = { Title = "Orange", Hint = "Step on the pad to roll!" }, -- the roll sign board: title gradient (UiPackConfig.Text), hint line
		-- per-zone props + landmarks: WorldsConfig (Worlds.Area(world, i).Props / .Landmark)
	},

	-- ===== Run feel =====
	Feel = {
		WalkSpeed = 30, -- the default walk speed in the lobby (StarterPlayer.CharacterWalkSpeed, set by tools/build_world.lua Base); unrelated to the log's roll speed
		Camera = { Back = 36, Height = 13, Look = 24, Fov = 68, FovBoost = 30, FovKick = 9, KickDecay = 6, ShakeHit = 0.7, ShakeRamp = 1.4, ShakeSuper = 2.6, ShakeHyper = 4, ShakeBreak = 3.2, ShakeDecay = 5 },
		-- the LOG HEALTH bar: a runtime clone of the XP bar (StarterGui.Main.Bottom.BarFrame.Bar) pinned to the top edge; Size / Top are design px, the fill goes Blue -> Purple -> Red as the log shrinks
		HealthBar = { Size = Vector2.new(640, 46), Top = 6, Text = "LOG HEALTH", Blue = Color3.fromRGB(40, 140, 255), Purple = Color3.fromRGB(170, 80, 235), Red = Color3.fromRGB(255, 50, 50) },
		-- the Hyper Ramp cutscene (Run/HyperCutscene; the slow-motion itself is Obstacles.HyperCine). Camera offsets are in the log's frame
		-- { side (toward the track centre), up, ahead } studs + FOV, at the start / middle / lip of the climb, then After the launch.
		HyperCine = {
			-- the camera pans round to the side of the ramp while the look point stays at LookUp (LookEnd = LookUp: no tilt)
			Path = { { 0, 12, -34, 62 }, { 32, 7, -14, 46 }, { 26, 3, 10, 38 } }, After = { 20, 8, 22, 44 }, LookUp = 2.5, LookEnd = 2.5,
			Sound = { Id = "rbxassetid://77174423806230", Volume = 1 }, -- plays through the climb, stretched (PlaybackSpeed) to last until the launch
			BlendIn = 0.45, BlendOut = 1.1, -- seconds the camera takes to swing onto the cutscene pose / back onto the chase camera
			Bolts = { Every = 0.06, Life = 0.2, Segments = 7, Reach = { 12, 26 }, Thick = 0.4, Pool = 8 }, -- procedural lightning around the log
			Shake = 0.9, BlastShake = 6, Flash = 0.45, -- climb shake at the lip, shake at the explosion, seconds of the white screen flash
		},
		Fall = { Time = 0.7 }, -- seconds the avatar takes to faceplant when the log breaks (RunAvatar.Fall)
		-- hit zoom (CameraZoom.Pulse): FOV change in degrees (negative = zoom in), seconds in / back out; bigger ramps zoom further and ease back slower
		HitZoom = {
			Bump = { Fov = -27, In = 0.07, Out = 0.32 },
			Ramp = { Fov = -54, In = 0.1, Out = 0.55 },
			Super = { Fov = -96, In = 0.14, Out = 1.0 },
			Hyper = { Fov = -140, In = 0.16, Out = 1.4 },
			MinFov = 14, -- CameraZoom never lets the camera FOV drop below this (the x3 hit zooms would otherwise pass zero)
		},
		-- speed lines (SpeedLines): a constant stream while rolling (Cruise: lines per second at Speed01 = 1, scaled by speed; Length px, Time s,
		-- Alpha = peak transparency, lower = brighter) that swells on a hit: Kinds[kind] = { Count = extra streaks at once, Size = length multiplier,
		-- Rate = rate multiplier, Hold = seconds before the swell fades (Fade) }. Inner / Travel are ring radii (screen fractions).
		SpeedLines = {
			Color = Color3.fromRGB(255, 255, 255), Thickness = 4, Inner = { 0.55, 0.9 }, Travel = { 0.25, 0.4 }, Fade = 3,
			Cruise = { Rate = 48, Min = 0.4, Length = { 100, 220 }, Time = 0.5, Alpha = 0.25 },
			Kinds = {
				Bump = { Count = 5, Size = 1.3, Rate = 1.4, Hold = 0.15, Alpha = 0.65 },
				Ramp = { Count = 11, Size = 1.6, Rate = 1.8, Hold = 0.4, Alpha = 0.59 },
				Super = { Count = 21, Size = 2.1, Rate = 2.5, Hold = 1.0, Alpha = 0.53 },
				Hyper = { Count = 35, Size = 2.1, Rate = 3, Hold = 1.6, Alpha = 0.515 },
			},
		},
		LevelZoom = { Fov = -16, In = 0.12, Out = 0.35 }, -- level-up FOV dip: degrees (negative = zoom in), seconds in / back out (CameraZoom)
GainFly = { StartX = { 0.38, 0.62 }, StartY = { 0.34, 0.58 }, Width = 150, Height = 50, PopTime = 0.3, Hold = 0.35, FlyTime = 0.7, ShrinkFrom = 0.7, Max = 12 }, -- the "[speed icon] +N" gain (GainFly): random start box (screen fractions), size (px), seconds, shrink begins at this fraction of the flight, max at once
		RunAnim = { Id = "rbxassetid://507767714", Speed = { 0.8, 2.2 } }, -- the Roblox run animation while riding the log; playback speed low..high with the log's speed
		Popup = { Rise = 7, Time = 0.9, Max = 14 }, -- "+N" billboard
		Dust = { Near = 220 }, -- other players' hits only puff within this many studs of the camera
		BreakHold = 1.6, -- seconds the camera lingers on the splinters before it pans back to the spawn
		ReturnPan = 0.7, -- seconds of the quick camera pan back to the spawn
		NotifyTime = 0.8, -- seconds the white "[trophy] +N" notifier takes to rise and fade, before the trophies burst out
		WinsCount = 1.4, -- seconds the Wins stat counts up after the trophies land
		HitBatch = 0.2, -- server batches RunHits at most this often
		LaunchCooldown = 1.0,
		Respawn = 4, -- Roll again hides the result after this fade
	},

	-- Stub sound ids (SoundConfig names) so real audio can be swapped in one place.
	SoundNames = { Impact = "Impact", Boost = "Boost", Break = "Break", Purchase = "Purchase", LevelUp = "LevelUp", Lift = "Lift", Ramp = "RampHit", Super = "SuperHit", Hyper = "HyperHit" },
}
