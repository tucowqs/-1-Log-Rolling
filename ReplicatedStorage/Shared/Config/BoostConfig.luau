--[[
	BoostConfig — everything that multiplies Speed gains or Wins payouts on top of rebirths + pets (BoostService,
	BoostMath, the HUD "xN Multiplier" label and status chips, the Inventory window).
	  Potions   bought (ShopConfig "Bundle" Potions) or won, kept in data.Potions = { [kind] = count } and drunk from
	            the Inventory: each adds Minutes of x Mult. Time only runs while the player is in game (saved as
	            data.BoostLeft = { [kind] = seconds } on leave); the live end time is the attribute <kind>BoostUntil
	            (server clock, the HUD chip counts it down).
	  Passes    ShopConfig pass keys: x Mult while owned.
	  Friends   +PerFriend for each Roblox friend in the same server (max Max), attribute FriendBoost (a fraction).
	  Trail     the equipped trail's bonus (TrailConfig), attribute TrailBoost (a fraction).
	Speed mult = passes x potion x (1 + FriendBoost + TrailBoost); Wins mult = passes x potion x (1 + FriendBoost).
]]
return {
	Bridges = {
		"UsePotion", -- C->S { Kind }   drink one potion of that kind
	},

	Potions = {
		Speed = { Name = "Speed Boost", Mult = 2, Minutes = 10, Attribute = "SpeedBoostUntil", Icon = "Boost", Color = "Blue", Text = "Blue" },
		Wins = { Name = "Wins Boost", Mult = 2, Minutes = 10, Attribute = "WinsBoostUntil", Icon = "Trophy", Color = "Orange", Text = "Gold" },
	},
	PotionOrder = { "Speed", "Wins" },

	Passes = { Speed = { "Speed2x" }, Wins = { "Wins2x" } }, -- ShopConfig passes (each x its Factor below)
	PassMult = 2,

	Friends = { PerFriend = 0.1, Max = 0.5, Attribute = "FriendBoost" },
	TrailAttribute = "TrailBoost",

	Text = {
		Used = "%s active! (%s)", -- name, time left
		None = "You don't have any %s!",
		Mult = "x%s Multiplier", -- the HUD label over the level bar
		Friend = "Friend Boost +%d%%",
		Chip = "x%d %s", -- status chip: "x2 12:30"
	},
}
