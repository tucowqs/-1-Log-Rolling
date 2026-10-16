return {
	Name = "givecash",
	Aliases = { "cash" },
	Description = "Gives currency (DataConfig.Currency); a negative amount takes it.",
	Group = "Game",
	Args = {
		{ Type = "players", Name = "players", Description = "Who gets it" },
		{ Type = "number", Name = "amount", Description = "How much" },
	},
}
