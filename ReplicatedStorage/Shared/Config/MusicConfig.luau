--[[
	MusicConfig — background music by mood (MusicController). The mood is picked every Check seconds:
	MusicController.SetOverride(mood) wins; else the first Rule whose player attribute is truthy; else
	Default. Moods crossfade over Fade seconds; a mood with several tracks rotates its playlist (starting
	at a random track), a single track loops. The SettingKey setting (true = off) silences the Music
	SoundGroup. APM Music and DistroKid tracks are licensed for every experience.
]]
return {
	Volume = 0.35, -- the Music SoundGroup volume
	Fade = 1.6, -- crossfade seconds
	Check = 0.5, -- seconds between mood checks
	SettingKey = "MusicOff", -- ClientState.Settings key that mutes music (Settings system)
	Default = "Main",
	-- In priority order: while the player attribute is truthy, that mood plays.
	Rules = {
		{ Attribute = "Chased", Mood = "Chase" },
	},

	Moods = {
		Main = {
			Volume = 1,
			Tracks = {
				"rbxassetid://9040172578", -- APM "Trickle" (playful)
				"rbxassetid://1839782598", -- APM "Gentle Day"
				"rbxassetid://9042169165", -- APM "Glass Half Full"
				"rbxassetid://1840383905", -- APM "Happy Shoppers" (the kit author's pick)
			},
		},
		Calm = {
			Volume = 0.9,
			Tracks = {
				"rbxassetid://77590414162150", -- DistroKid "Echoes of Serenity"
				"rbxassetid://116882606930335", -- DistroKid "Stillness Beneath Skies"
			},
		},
		Chase = {
			Volume = 1.2,
			Tracks = { "rbxassetid://1847683499" }, -- the kit author's pick for chases
		},
	},
}
