return {
	Name = "setdata",
	Aliases = {},
	Description = "Sets a top-level saved field. Value: true/false, a number, JSON ({...} / [...]) or text.",
	Group = "Game",
	Args = {
		{ Type = "players", Name = "players", Description = "Whose data" },
		{ Type = "string", Name = "key", Description = "Speed, Level or Wins (or any other top-level field)" },
		{ Type = "string", Name = "value", Description = "New value" },
	},
}
