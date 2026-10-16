return {
	Name = "getdata",
	Aliases = {},
	Description = "Shows a saved field (or the whole save) as JSON.",
	Group = "Game",
	Args = {
		{ Type = "player", Name = "player", Description = "Whose data" },
		{ Type = "string", Name = "key", Description = "Field name (blank = everything)", Optional = true },
	},
}
