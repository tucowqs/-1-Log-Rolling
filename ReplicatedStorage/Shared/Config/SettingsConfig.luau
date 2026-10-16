--[[
	SettingsConfig — the Settings window (SettingsMenu) and the saved settings (SettingsService).
	Rows, in order:
	  Kind "Toggle"       a saved boolean data.Settings[Key] (Default for new saves); Inverted = the saved key
	                      means "off" (MusicOff), so the button shows the opposite
	  Kind "SkipTutorial" a SKIP button, shown only while the tutorial runs (Tutorial system)
	Systems read ClientState.Settings[Key]: Audio (MusicOff), Performance (ReducedEffects).
	Steal Treasure also had "SkipReveal" (Fast Chests) and a swim-throttle row: game-specific, add your own.
]]
return {
	Menu = "Settings", -- the ClientState menu name (the Settings TopbarPlus icon opens it); its window look is
	-- UiPackConfig.Menus.Settings (the UI pack's Upgrades window shell, one pack row per setting)
	Rows = {
		{
			Key = "MusicOff", Kind = "Toggle", Default = false, Inverted = true, Title = "Music", Desc = "Game music",
			Icon = "rbxassetid://112361285300191",
		},
		{
			Key = "ReducedEffects", Kind = "Toggle", Default = false, Title = "Low Effects", Desc = "For low-end devices",
			Icon = "rbxassetid://88618176549768",
		},
		{
			Key = "SkipTutorial", Kind = "SkipTutorial", Title = "Tutorial", Desc = "Skip the tutorial",
			Icon = "rbxassetid://100127205971263",
		},
	},
	Buttons = { On = "Green", Off = "Gray", Skip = "Red" }, -- UiPackConfig palettes
	-- Settings also mirrored to Player attributes (SettingsService, on load and on every change) for systems
	-- that read an attribute instead of ClientState (Ambient reads "ReducedEffects").
	Attributes = { "ReducedEffects" },
}
