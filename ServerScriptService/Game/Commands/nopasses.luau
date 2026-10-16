return {
	Name = "nopasses",
	Aliases = { "mockpasses" },
	Description = "THIS SESSION ONLY: switches off every gamepass the players own, so they play like a fresh save with no pass benefits (false = turn them back on). Nothing is saved; rejoining restores them.",
	Group = "Game",
	Args = {
		{ Type = "players", Name = "players", Description = "Whose passes" },
		{ Type = "boolean", Name = "off", Description = "true (default) = passes off, false = passes back on", Optional = true },
	},
}
