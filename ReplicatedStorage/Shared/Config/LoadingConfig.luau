--[[
	LoadingConfig — the join loading screen (LoadingController): a strong blur over the world, every other ScreenGui held
	back (and the Roblox chat / backpack), an animated "Loading game..." label, until the lobby (its walls, props, egg
	podiums + eggs, the lobby's Blender models) is really in. Then the text scales out, the blur fades and the UI comes
	back. Toasts (NotifyController) wait for it too.
]]

return {
	Text = "Loading game", -- the three animated dots follow it
	DisplayOrder = 1000, -- over every other screen
	Blur = 56, -- BlurEffect.Size (56 is the engine's max)
	FontSize = 76, -- design px (Fit scales it per device)
	Stroke = 4,
	DotWidth = 0.34, -- of FontSize
	DotSpeed = 1.3, -- hops per second
	DotLag = 0.17, -- cycle share between one dot and the next
	DotHop = 0.22, -- of FontSize
	In = 0.4, -- seconds: the label grows in (Back)
	Out = 0.45, -- seconds: it scales away (Back In)
	Unblur = 0.7, -- seconds: the blur fades out

	MinTime = 0.8, -- never flashes by faster than this
	MaxTime = 60, -- gives up waiting (so nobody is stuck) after this many seconds
	Settle = 0.15, -- a last beat once everything is in (a final preload pass already catches late props)
	Poll = 0.05, -- seconds between readiness checks

	-- Server (AssetBuildService): the Groups below are built first, this many models at once (their uploads overlap), then
	-- the rest of the hill RestWidth at a time (gentler: players are already in by then).
	BuildWidth = 8,
	RestWidth = 3,

	-- Workspace folders that must exist (and get preloaded): the lobby, its cliff walls, the hatchery and the rest of the start area.
	Folders = { "Lobby", "LobbyTheme", "Plateau", "Training", "LogPads", "Hatchery", "Leaderboards", "Portals", "LimitedPedestals" },
	-- AssetGroups groups the lobby needs (the Blender models: logs, treadmills, eggs + pets, boards, the lobby's props).
	Groups = { "Core", "Treadmills", "Pets", "Boards", "Logs", "Limited", "Lobby" },
	-- CoreGui parts hidden while loading (not the player list: the topbar icons manage that).
	CoreGui = { "Chat", "Backpack", "EmotesMenu", "Health" },
}
