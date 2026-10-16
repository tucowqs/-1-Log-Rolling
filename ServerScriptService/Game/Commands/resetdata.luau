return {
	Name = "resetdata",
	Aliases = { "wipe" },
	Description = "Resets players' saved data to a fresh start (keeps receipt ids so Robux buys can't double-grant) and kicks them to rejoin.",
	Group = "Game",
	Args = {
		{ Type = "players", Name = "players", Description = "Whose data to reset" },
	},
}
