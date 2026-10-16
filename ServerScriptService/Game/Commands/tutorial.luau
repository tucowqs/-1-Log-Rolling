return {
	Name = "tutorial",
	Aliases = {},
	Description = "Restarts the tutorial for players (nothing else in their data changes), from the first step or the named one.",
	Group = "Game",
	Args = {
		{ Type = "players", Name = "players", Description = "Who restarts the tutorial" },
		{ Type = "string", Name = "step", Description = "Step id to start at (TutorialConfig.Steps)", Optional = true },
	},
}
