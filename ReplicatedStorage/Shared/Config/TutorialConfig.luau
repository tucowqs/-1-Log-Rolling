--[[
	TutorialConfig — the first-time sequence (TutorialService / TutorialFlowService / TutorialController / Spotlight).
	Each step's Text stays up as a sticky notification (key words via Emphasis.Em) and an arrow beam + bouncing marker point
	at its Target until the step is done. TutorialFlowService (server) decides when each step is done; TutorialService saves it.
	Step fields:
	  Id, Text           required (Text may hold one %s / %d, see below)
	  TextMobile         the text on touch-only devices (no keyboard)
	  Target             a name TutorialController resolves: "RollZone" (the throw pad), "LogPad" (the cheapest log the
	                     player is told to buy, chosen by the server when the Buy step starts), "Treadmill", or a TargetTag instance
	  Highlight          "Roll" = dim the screen around the ROLL! button (Spotlight) while it is on screen;
	                     "Gifts" = around the HUD Gifts button, then gift 1's CLAIM button once the window is open
	  Poor               Buy only: { Text, Target, Highlight } shown instead while the player can't afford the log yet
	  GoalAttribute      "Level": a training step; Text shows "%d/%d" = their Level / the "TutorialGoal" attribute the server
	                     sets when it starts (Goal, or one above their Level then, whichever is higher)
	  Goal               the Level a training step asks for at least (nil = just one level up)
	  ResumeAt           a step whose progress isn't saved (a roll in flight) restarts at this step on rejoin
	  Marker             the marker's text over the target ("HERE" by default)
	Version: bump it when the steps change; anyone mid-way through an older tutorial restarts it.
]]
local Em = require(script.Parent.Parent.Modules.Emphasis).Em
local Balance = require(script.Parent.BalanceConfig)

local TrainLevel = 2

return {
	Bridges = { "Tutorial", "SkipTutorial" }, -- (Net registers them)

	Header = "TUTORIAL:", -- the big title over the current step's notification
	Version = 5, -- 2: Train (to level 2) moved first. 4: Train -> Edge -> Roll -> Steer -> Buy Birch. 5: + TrainMore, Gifts
	Steps = {
		{
			Id = "Train", Text = "Train on the " .. Em("treadmill") .. "! Level %d/%d", -- (goal: "TutorialGoal" attribute)
			Target = "Treadmill", Marker = "TRAIN", Goal = TrainLevel, GoalAttribute = "Level",
		},
		{ Id = "Edge", Text = "Walk up to the " .. Em("edge") .. "!", Target = "RollZone", Marker = "EDGE" },
		{ Id = "Roll", Text = Em("Roll!"), Target = "RollZone", Highlight = "Roll", Marker = "ROLL", ResumeAt = "Edge" },
		{ Id = "Steer", Text = Em("A and D") .. " to go left and right!", TextMobile = Em("Drag") .. " to go left or right!", ResumeAt = "Edge" },
		{
			Id = "Buy", Text = "Buy the %s!", Target = "LogPad", Marker = "BUY",
			Poor = { Text = "Roll again to earn " .. Em("Wins") .. "!", Target = "RollZone", Highlight = "Roll" },
		},
		{
			Id = "TrainMore", Text = "Back on the " .. Em("treadmill") .. "! Level %d/%d",
			Target = "Treadmill", Marker = "TRAIN", GoalAttribute = "Level",
		},
		{
			Id = "Gifts", Text = "Open your " .. Em("Gifts") .. "!", Highlight = "Gifts", Gift = 1,
			Claim = "Claim your " .. Em("50 Wins", "Success") .. " gift!", Wait = "Your " .. Em("50 Wins", "Success") .. " gift unlocks in %s!",
		},
	},
	FirstRollWins = 20, -- the tutorial's first roll (Roll / Steer step) pays at least this many Wins: enough for the Birch Log
	TrainLevel = TrainLevel, -- the Train step (the first step) ends at this Level, or one above the Level it started at if higher (replays)
	BuyLog = "Birch", -- the log the Buy step asks for (the cheapest unowned one if they already own it)
	ZoneHeight = 12, -- studs above / below the RollZone that still count as standing in it

	-- A save that already rolled before the tutorial existed never sees it (Cmdr "tutorial" replays it).
	SkipIf = function(data): boolean
		return (data.Runs or 0) > 0
	end,

	-- The cheapest log the player doesn't own yet (its id), or nil when they own them all.
	CheapestUnowned = function(owned: { [string]: boolean }): string?
		local best
		for _, log in Balance.Logs do
			if not owned[log.Id] and (not best or log.Price < best.Price) then
				best = log
			end
		end
		return best and best.Id
	end,

	-- Instances tagged this with a string attribute "Target" are pointer targets by name (nearest wins).
	TargetTag = "TutorialTarget",

	-- The pointer from your feet to the target: a beam of arrows scrolling toward it.
	Arrow = {
		-- White chevron pointing DOWN the image: a beam lays the image's height along its length, top at
		-- Attachment0 (you), so it points at the target.
		Texture = "rbxassetid://125034500555973",
		Width = 2.4, -- studs
		Spacing = 3, -- studs per arrow (TextureLength)
		Speed = 1.5, -- arrows per second scrolling toward the target
		Color = Color3.fromRGB(255, 150, 0), -- the chevron is white, tinted: orange reads on the white path and the green grass
		LightEmission = 0.4,
		FootOffset = 2.6, -- studs below the avatar's root the beam starts (the ground under its feet)
		Lead = 4, -- studs ahead of the avatar (toward the target) the beam starts, so the avatar never hides it
		Lift = 0.8, -- studs above the target's top surface the beam ends
	},
	-- The bouncing billboard over the target.
	Marker = {
		Text = "HERE",
		Color = Color3.fromRGB(255, 205, 45),
		Size = Vector2.new(170, 130), -- px
		Lift = 3, Bounce = 1.5, BounceSpeed = 3, -- studs over the target's top, bounce height, speed
		Icons = { Down = "rbxassetid://98090053078288", Up = "rbxassetid://79194705268624" },
	},

	-- The screen dim around the highlighted button: ONE hole-shaped Frame with a massive UIStroke (same technique as the
	-- Rebirth prompt). Order sits above the HUD and below the notifications.
	Dim = { Thickness = 4000, Transparency = 0.25, Color = Color3.new(0, 0, 0), Pad = 6, Radius = 26, Fade = 0.3, Order = 8, Grow = 12, Period = 0.55 },

	-- HUD pieces hidden until the tutorial reaches the step where each first matters (TutorialUIController).
	Gates = {},
}
