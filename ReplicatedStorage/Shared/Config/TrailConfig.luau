--[[
	TrailConfig — trails (TrailService / TrailsController, the HUD Trails button): bought with Wins, one equipped at a time,
	drawn behind the character (a Trail between two root attachments, made on the server so everyone sees it, also while
	rolling). The equipped trail's Boost adds to the Speed multiplier (BoostMath: attribute TrailBoost).
	Colors = the trail's colour keyframes (ColorSequence), Width = studs at the start (tapers to 0), Life = seconds.
	Price = the Price of the log of its Tier (Economy.LogPrice, 2026-10-15 economy); Boost = +5% ... +50% Speed (small: it stacks additively with friends).
]]
local Economy = require(script.Parent.Parent.Modules.Economy)

local rgb = Color3.fromRGB

return {
	Bridges = {
		"TrailBuy", -- C->S { Id }   buy (if not owned) or equip / unequip
	},
	Menu = "Trails",
	Trails = {
		{ Id = "Leaf", Name = "Leaf Trail", Price = Economy.LogPrice(5), Boost = 0.05, Colors = { rgb(120, 220, 90), rgb(40, 150, 60) } },
		{ Id = "Ocean", Name = "Ocean Trail", Price = Economy.LogPrice(7), Boost = 0.1, Colors = { rgb(90, 200, 255), rgb(20, 90, 220) } },
		{ Id = "Sunset", Name = "Sunset Trail", Price = Economy.LogPrice(9), Boost = 0.15, Colors = { rgb(255, 210, 80), rgb(255, 90, 60) } },
		{ Id = "Candy", Name = "Candy Trail", Price = Economy.LogPrice(11), Boost = 0.2, Colors = { rgb(255, 140, 210), rgb(255, 255, 255), rgb(140, 220, 255) } },
		{ Id = "Toxic", Name = "Toxic Trail", Price = Economy.LogPrice(13), Boost = 0.25, Colors = { rgb(170, 255, 60), rgb(40, 120, 30) } },
		{ Id = "Magma", Name = "Magma Trail", Price = Economy.LogPrice(15), Boost = 0.3, Colors = { rgb(255, 230, 90), rgb(255, 90, 20), rgb(90, 20, 10) } },
		{ Id = "Galaxy", Name = "Galaxy Trail", Price = Economy.LogPrice(17), Boost = 0.4, Colors = { rgb(120, 70, 255), rgb(255, 100, 230), rgb(40, 20, 90) } },
		{ Id = "Rainbow", Name = "Rainbow Trail", Price = Economy.LogPrice(19), Boost = 0.5, Colors = { rgb(255, 60, 60), rgb(255, 220, 60), rgb(60, 220, 90), rgb(60, 160, 255), rgb(200, 80, 255) } },
		-- World 3 trails (the boost keeps climbing +10% per step, priced like the log of their Tier)
		{ Id = "Aurora", Name = "Aurora Trail", Price = Economy.LogPrice(23), Boost = 0.6, Colors = { rgb(120, 255, 200), rgb(110, 160, 255), rgb(220, 120, 255) } },
		{ Id = "Stardust", Name = "Stardust Trail", Price = Economy.LogPrice(27), Boost = 0.7, Colors = { rgb(255, 240, 160), rgb(255, 160, 230), rgb(120, 130, 255), rgb(30, 20, 90) } },
	},
	Look = { Width = 1.6, Life = 0.5, Light = 0.4, Lift = 0.2 }, -- Lift = studs over the root centre the trail's top sits
	Text = { Bought = "Bought the %s!", Poor = "Need %s more Wins!", Boost = "+%d%% Speed", Price = "%s Wins" },
}
