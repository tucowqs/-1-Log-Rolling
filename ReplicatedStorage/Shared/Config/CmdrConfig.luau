--[[
	CmdrConfig — the Cmdr admin console (CmdrService / CmdrController). Cmdr itself (v1.12.0, evaera/Cmdr)
	lives in ServerStorage.ServerPackages.Cmdr; the game's commands are in ServerScriptService.Game.Commands
	(a "<name>" definition + "<name>Server" pair each) and custom argument types in
	ServerScriptService.Game.CmdrTypes (optional folder).
	Admins are gated by UserId, never by Name: Studio team-test players are Player1/Player2 with fake ids.
]]
return {
	-- SET YOUR Roblox UserId: who may run commands in live servers. `node new.js <Game> --admin <userId>` fills it;
	-- 0 = nobody (Studio playtests still work through StudioOpen). Add teammates as more ids.
	Admins = { 0 },
	StudioOpen = true, -- anyone in a Studio playtest may (team-test players have fake UserIds)
	ActivationKeys = { Enum.KeyCode.F2 }, -- opens the console
	DefaultCommands = true, -- Cmdr's built-ins too (help, teleport, kill, respawn, ...)
	Denied = "You don't have permission to run that.",
}
