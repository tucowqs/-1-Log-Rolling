--[[
	EventConfig — the countdown sign over the lobby boards (EventController; Rock Skipping's "HALLOWEEN EVENT IN 2D 14H"). Shows
	Countdown until At (os.time UTC), then Live until Ends, then nothing. Pos = from each world's start line (above the back row
	of boards, tools/lobby_layout.lua). Text = UiPackConfig.Text gradient.
]]
return {
	Bridges = {},
	Name = "HALLOWEEN EVENT",
	At = 1793404800, -- 2026-10-31 00:00 UTC
	Ends = 1793491200, -- 2026-11-01 00:00 UTC
	Pos = Vector3.new(0, 46, -300),
	Billboard = { Size = Vector2.new(60, 8), Near = 60 },
	Text = { Countdown = "%s IN %s", Live = "%s IS LIVE!", Gradient = "Orange" },
}
