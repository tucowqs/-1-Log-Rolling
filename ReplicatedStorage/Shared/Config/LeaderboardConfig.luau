--[[
	LeaderboardConfig — the two lobby leaderboards (LeaderboardService + LeaderboardController, built in Studio by
	tools/build_boards.lua as Workspace.Leaderboards.<Id>). Each board is a SurfaceGui with a ScrollingFrame of the top
	Top players (global: an OrderedDataStore per board, so every server shows the same list) and a podium beside it
	where the #1 player's avatar dances under a "No.1" billboard.
	  Store     OrderedDataStore name (bump the suffix to wipe a board). Values are the BEST ever reached (a rebirth
	            resets Speed, the board keeps the peak).
	  Attribute the player attribute the value comes from (DataConfig.Attributes).
	  Pos       station centre as an offset from Track.Origin; the board faces Look (also an offset), the podium stands
	            Side studs to the board's right (-) / left (+) as seen by a viewer.
]]
local rgb = Color3.fromRGB

return {
	Bridges = {},

	Top = 50,
	Refresh = 45, -- seconds between a server's writes + reads (an OrderedDataStore budget is 60 + 10 x players a minute)
	MaxValue = 9e15, -- OrderedDataStore values are integers; stay inside the exact double range
	Look = Vector3.new(0, 0, -150), -- every board turns to face this point (the path between the spawn and the hatchery)

	Boards = {
		{ Id = "Rebirths", Store = "LogRoll_TopRebirths_v1", Attribute = "Rebirths", Title = "Top Rebirths", Icon = "Rebirth", Color = "Purple", Text = "Purple",
			Value = "%s", Unit = "Rebirths", Tint = rgb(176, 96, 255), Pos = Vector3.new(-160, 0, -300), Side = 17 },
		{ Id = "Speed", Store = "LogRoll_TopSpeed_v1", Attribute = "Speed", Title = "Top Speed", Icon = "Upgrades", Color = "Blue", Text = "Blue",
			Value = "%s", Unit = "Speed", Tint = rgb(70, 180, 255), Pos = Vector3.new(160, 0, -300), Side = -17 },
		-- Rock Skipping's three (2026-10-14): clones of the Rebirths board (tools/lobby_layout.lua retitles them). Time = Value is seconds
		{ Id = "Wins", Store = "LogRoll_TopWins_v1", Attribute = "Wins", Title = "Top Wins", Icon = "Index", Color = "Orange", Text = "Gold",
			Value = "%s", Unit = "Wins", Tint = rgb(255, 200, 60), Pos = Vector3.new(0, 0, -300), Side = 17 },
		{ Id = "TimePlayed", Store = "LogRoll_TopTime_v1", Attribute = "TimePlayed", Title = "Top Time Played", Icon = "Daily", Color = "Green", Text = "Green",
			Value = "%s", Unit = "Time", Time = true, Tint = rgb(110, 230, 110), Pos = Vector3.new(-80, 0, -300), Side = 17 },
		{ Id = "RobuxSpent", Store = "LogRoll_TopRobux_v1", Attribute = "RobuxSpent", Title = "Top Robux Spent", Icon = "Shop", Color = "Red", Text = "Pink",
			Value = "%s", Unit = "Robux", Tint = rgb(255, 90, 140), Pos = Vector3.new(80, 0, -300), Side = -17 },
	},

	-- The board face (a SurfaceGui; the builder lays out the pack window + 50 pre-built rows, the controller only sets text).
	Board = { Size = Vector2.new(22, 30), Canvas = Vector2.new(1100, 1500), Lift = 3, Thickness = 1, RowHeight = 100, RowGap = 10 },
	Empty = "Nobody yet - be the first!",
	Podium = { Scale = 1.5, Model = "WinnerPodium", Top = 3.08 }, -- Top = the Blender podium's standing height (studs, before Scale)
	Dances = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" }, -- the R15 emote dances; one is picked per champion
	Billboard = { Size = Vector2.new(9, 5.2), Near = 24, Lift = 11.6, Text = "No.1" }, -- Lift = studs over the podium top
	Gold = rgb(255, 196, 50),
	Colors = { rgb(255, 205, 60), rgb(215, 222, 235), rgb(224, 150, 90) }, -- rank 1-3 row accents (gold, silver, bronze)
}
