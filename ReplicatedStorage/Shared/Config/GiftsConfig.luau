--[[
	GiftsConfig — free playtime gifts (GiftsService / GiftsController, the HUD "Gifts" button and its "!" badge): each gift
	unlocks after Minutes of play in THIS session and is claimed once per session. Reward = a MonetizeService.Bundle
	(Wins, Potions, Speed levels, Pets...). The session clock is the player attribute "SessionStart" (server time).
]]
return {
	Bridges = {
		"GiftClaim", -- C->S { Index }
	},
	Menu = "Gifts",
	Gifts = {
		{ Minutes = 1, Reward = { Wins = 50 } },
		{ Minutes = 3, Reward = { Potions = { Speed = 1 } } },
		{ Minutes = 5, Reward = { Wins = 250 } },
		{ Minutes = 10, Reward = { Speed = 2 } },
		{ Minutes = 15, Reward = { Potions = { Wins = 1 } } },
		{ Minutes = 20, Reward = { Wins = 1500 } },
		{ Minutes = 30, Reward = { Potions = { Speed = 1, Wins = 1 } } },
		{ Minutes = 45, Reward = { Speed = 5, Wins = 5000 } },
	},
	Text = { Title = "Gift %d", Ready = "CLAIM", Claimed = "CLAIMED", Wait = "%s" },
}
