--[[
	CodesConfig — redeemable codes (the shop's Codes card; CodesService). Each code pays a reward bundle once per player
	(MonetizeService.Bundle: Pets, Speed (levels), Wins, Potions, Rebirths, Slots). Codes are matched case-insensitively;
	Expires = os.time() after which the code stops working (nil = never). Add / remove codes here.
]]
return {
	Bridges = {
		"RedeemCode", -- C->S { Code }
	},
	Codes = {
		RELEASE = { Reward = { Wins = 500, Potions = { Speed = 1 } } },
		LOGROLL = { Reward = { Potions = { Wins = 1, Speed = 1 } } },
		SPOOKY = { Reward = { Wins = 2500 }, Expires = 1793491200 }, -- 2026-11-01 00:00 UTC
	},
	Cooldown = 1, -- seconds between a player's tries
	Text = {
		Redeemed = "Code redeemed: %s",
		Used = "You already used that code!",
		Invalid = "That code doesn't exist!",
		Expired = "That code has expired!",
	},
}
