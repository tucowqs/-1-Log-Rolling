--[[
	GiftConfig — buying a shop item FOR another player in the server (GiftService / GiftController). Every ShopConfig item
	with a Gift product id shows a purple gift button; it opens the "GiftPick" list of the other players, picking one sends
	GiftPick { Key, UserId } (the server remembers it) and prompts the item's Gift product. Its receipt grants the item to
	that player (a pass is granted outright); if they left meanwhile the buyer gets it instead.
]]
return {
	Bridges = {
		"GiftPick", -- C->S { Key, UserId }   who the next gift purchase of Key is for
	},
	Menu = "GiftPick",
	Text = {
		Title = "Gift %s", -- the window title (item name)
		Row = "Send them this gift!",
		Button = "GIFT",
		Alone = "Nobody else is here to gift to!",
		Sent = "You gifted %s to %s!",
		Received = "%s gifted you %s!",
		Fallback = "%s left, so the %s is yours!",
		Owned = "%s already owns that!",
	},
}
