--[[
	LeaderstatsConfig — what shows on the Roblox player list (LeaderstatsService).
	  Stats: each { Name = column title, Attribute = the player attribute it mirrors }, in column order.
	  Abbreviate: true shows "4.09M" (a StringValue, like the HUD); false shows the raw number (an
	  IntValue, which the player list can sort).
]]
return {
	Abbreviate = true,
	Stats = {
		{ Name = "Speed", Attribute = "Speed" },
		{ Name = "Wins", Attribute = "Wins" },
	},
}
