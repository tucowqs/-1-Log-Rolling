--[[
	DataConfig — saved player data (DataService on ProfileStore). Bump StoreName to wipe everyone's data
	(a new universe, e.g. moving the game to a group, also starts with empty saves).
	Template holds only the fields the GAME owns; each system defaults its own fields on load
	(DataService.OnPrepare), so adding a system never needs an edit here.
	Key collections by GUID uids (Items[uid] = id) and keep per-item extras in parallel maps.
]]
return {
	-- Bridges this system uses (Net registers them): the snapshot, the client's "listening" ping, setting saves.
	Bridges = { "Snapshot", "Ready", "SaveSettings" },

	StoreName = "LogRoll_v1",

	Template = {
		Wins = 0, -- the currency: paid when a log breaks, spent on logs
		Speed = 0, -- persistent; grows per bump/ramp hit and while running on a treadmill
		Hits = 0, -- lifetime bumps + ramps hit (drives the level bar)
		Level = 1,
		Rebirths = 0, -- permanent: each one adds +0.5x Speed gain and raises the max level (RebirthConfig / EconomyConfig)
		LevelHits = 0, -- XP (Speed) into the current level; Level and this are derived from Speed (Progress)
		TotalLevels = 0, -- HIDDEN (not mirrored or snapshotted): every level ever gained, never reset by a rebirth (Progress); drives Curves.TrainTick
		Logs = { Wood = true }, -- owned log ids
		Equipped = "Wood",
		Runs = 0,
		Best = 0, -- furthest distance (studs) a log has ever reached
		Purchases = {}, -- the last Robux receipt PurchaseIds granted (kept on data resets)
	},

	-- The currency DataService.AddCash / Spend work on (a Template field).
	Currency = "Wins",

	-- Versioned migrations (ServerScriptService.Game.Modules.DataMigrations): saves whose DataVersion is
	-- below Version run every migration above it once, in order, on load. Bump it when you add one.
	-- Fields that must NOT apply to old saves stay out of the Template and get initialised on load instead.
	Version = 4,

	-- Mirrored to Player attributes for the HUD, leaderstats and other services. Attributes replicate to
	-- EVERYONE, so mirror only small values and throttle frequent ones (AddCash's `quiet`).
	Attributes = { "Wins", "Speed", "Level", "Rebirths", "Equipped" },

	-- Saved fields the client keeps in ClientState.Data (snapshot-diffed: only changed fields resend).
	-- Systems add their own with DataService.AddSnapshot(key).
	Snapshot = { "Logs", "Equipped", "Hits", "Level", "LevelHits", "Rebirths", "Best", "Runs" },

	-- How many receipt ids to remember per player (Roblox retries recent receipts).
	KeepPurchases = 50,

	LoadFailKick = "Your save couldn't load, so we stopped before touching it. Please rejoin.",
	SessionEndKick = "Your save was opened in another server. Please rejoin.",
	ResetKick = "Your data was reset. Rejoin to start fresh!",
}
