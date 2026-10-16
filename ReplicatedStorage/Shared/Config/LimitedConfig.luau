--[[
	LimitedConfig — limited-stock Robux items on lobby pedestals (LimitedService / LimitedController), Rock Skipping's
	"STOCK 8535/10000 / BEST IN GAME / Always 1200% Better" pet and "Reaper Relic" rock.
	The stock is GLOBAL: every sale adds 1 to a DataStore counter (Store, key = item key); each server reads it every Refresh
	seconds into the workspace attribute "Limited<Key>Sold". Sold out = the pedestal says SOLD OUT and never prompts (a sale
	already paid for is always granted, even if it crosses the stock).
	Item: Product = the ShopConfig product key; Pet = the PetsConfig pet granted, or Log = the BalanceConfig log granted and
	equipped; Model = what floats on the pedestal (ServerStorage.MeshData name); Lines = the billboard's texts (top first,
	Text = UiPackConfig.Text gradient); Pos = pedestal offset from Track.Origin (the lobby layout, tools/lobby_layout.lua).
]]
return {
	Bridges = {},
	Store = "LogRoll_LimitedSold_v1",
	Refresh = 60,
	Folder = "LimitedPedestals", -- workspace folder (tools/lobby_layout.lua builds a pedestal part per item, named by key)

	Items = {
		KingBones = { Product = "KingBones", Pet = "KingBones", Model = "KingBones", Stock = 10000, ModelSize = 6,
			Lines = { { "BEST IN GAME", "Pink" }, { "Always 300%", "Blue" }, { "Better", "Green" } } },
		ReaperRelic = { Product = "ReaperRelic", Log = "ReaperLog", Model = "ReaperLog", Stock = 10000, ModelSize = 7,
			Lines = { { "REAPER RELIC", "Purple" }, { "Always 200% Better", "Pink" } } },
	},

	Billboard = { Size = Vector2.new(10, 7), Lift = 9, Near = 26 }, -- studs; Lift = over the pedestal top
	Float = { Lift = 4, Bob = 0.4, Speed = 1.4, Turn = 0.6 }, -- the item over its pedestal
	Prompt = { Distance = 10, Buy = "Buy", Equip = "Equip", Owned = "Owned" },
	Text = { Stock = "STOCK: %s/%s", SoldOut = "SOLD OUT!", Price = "ONLY %s", Granted = "%s (#%d of %d)" },
}
