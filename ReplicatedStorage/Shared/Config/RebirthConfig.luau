--[[
	RebirthConfig — the rebirth loop (RebirthService + RebirthController + RebirthMath).
	Level is capped: a player with N rebirths tops out at MaxLevel(N) = BaseMaxLevel + LevelsPerRebirth x N (10, 15, 20 ... 110 at 20).
	At the cap Speed stops rising ("max level"); REBIRTH resets Speed and Level to the start and raises a PERMANENT Speed-gain
	multiplier: Mult(N) = 1 + MultPerRebirth x N (x1, x1.5, x2 ... x11 at 20: ADDITIVE, so it never runs away).
	Every Speed gain (Progress.AddSpeed) is multiplied. The three numbers live in EconomyConfig.Rebirth (the economy knobs).
]]
local EconomyConfig = require(script.Parent.EconomyConfig)

local E = EconomyConfig.Rebirth

return {
	-- Bridges (Net registers these). ONE table payload per Fire.
	Bridges = {
		"Rebirth", -- C->S {}                       press REBIRTH (server re-checks the level)
		"RebirthDone", -- S->owner {Rebirths, Level, LevelHits, Speed}   the reset happened
	},

	BaseMaxLevel = E.BaseMaxLevel, -- the max level before any rebirth
	LevelsPerRebirth = E.LevelsPerRebirth, -- each rebirth adds this many levels to the cap
	MultPerRebirth = E.MultPerRebirth, -- each rebirth ADDS this to the Speed-gain multiplier (x1 -> x1.5 -> x2)

	-- RebirthPromptController: when the level cap is reached the screen is dimmed (a hole-shaped Frame whose UIStroke is huge) except around the HUD Rebirth button
	-- until the window is opened; if the window is then closed without rebirthing, the HUD button pulses until the rebirth happens.
	Prompt = {
		Dim = { Thickness = 4000, Transparency = 0.12, Color = Color3.new(0, 0, 0), Pad = 6, Radius = 26, Fade = 0.3, Order = 3 }, -- Pad / Radius = px around the button; Order = the dim ScreenGui's DisplayOrder (above the HUD)
		Pulse = { Scale = 1.18, Period = 0.5 }, -- the HUD button's endless heartbeat (scale peak, seconds each way)
		Frame = { Grow = 14, Period = 0.55 }, -- while the dim shows, the hole frame around the button breathes: it grows by this many px each side and back every Period seconds
	},

	Menu = "Rebirth", -- the ClientState menu name (UiPackConfig.Menus.Rebirth is the window)
	Text = {
		Current = "Now",
		Next = "Next",
		Need = "Reach Level %d",
		Progress = "Level %d / %d",
		Ready = "Max level! Rebirth for a permanent x%s Speed multiplier.",
		Locked = "Reach level %d to rebirth",
		Button = "REBIRTH",
		Mult = "x%s Multiplier",
		Done = "Rebirth %d! Speed gain is now x%s",
	},
}
