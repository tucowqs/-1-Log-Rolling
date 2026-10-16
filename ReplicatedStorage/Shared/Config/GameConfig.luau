--[[
	GameConfig - game-wide identity and loader knobs (Main.server / Main.client read it).
]]
return {
	-- Shown in the "[Name] server ready" / "client ready" lines and HANGING warnings.
	Name = "LogRoll",
	-- Bump on every publish you want to tell apart in logs.
	Version = "0.1.0",
	-- Seconds a Service.Start may run before the loader warns it is HANGING.
	HangWarning = 5,
}
