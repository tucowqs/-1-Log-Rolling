--[[
	ShopUiConfig — WHAT the Robux shop shows and on which GameUI pack card (PackViews/ShopView, ShopController).
	Prices, names and grants stay in ShopConfig (ShopMath keys); the window shell and colours are UiPackConfig's
	(menu "Shop": the pack Shop window, red header, NO side buttons; menu "ShopOffer": the offer popup).
	Sections follow +1 Rock Skipping's shop top to bottom: packs, the limited Admin Egg offer, gamepasses, zones, boosts,
	Wins packs, codes.

	Sections: the shop is ONE vertical scroll. Each section = a 3D Header (Text = UiPackConfig.Text gradient) + Rows of
	card ids; cards in a row share its width, and Columns = cards per row keeps a short row's cards the SAME size (a row's own
	Columns field overrides the section's, e.g. the full-width Mega Pack under the 2-wide Wins packs).
	Cards (pack shop cards, UiPack.Card), by card id; Key = the ShopMath key the card sells:
	  Starter  art, Name / Tag, Lines = up to 3 item frames ({ Amount, Name, Art }), Old = crossed-out price, Value
	  Offer    the rainbow crate card: Art, Name / Tag, Title, odds row (ShopController.SetOdds; OddsEgg = a PetsConfig egg whose
	           odds fill it), Buttons = { { Key, Text, Color } }
	  Wide     Art, Title, a SHORT From -> To row, Desc, one price button
	  Half     Art, Title, Desc, price
	  Pack     the cash tile: Image (or Art), Amount text, price
	  Codes    (game card on the Wide shell) the code box + Redeem button (CodesController)
	Every card with a giftable Key (ShopConfig Gift field) shows the purple gift button left of its price (GiftController).
	Fly = { image, UiPackConfig.Targets kind } the purchase celebration flies into. Art = UiPack/Art spec: { Image } or
	{ Models = { { Path (under ReplicatedStorage.Assets), Count?, Size?, Tint? } }, Spin }, Rays = Color3 tint.
]]
local IconPick = require(script.Parent.Parent.Modules.IconPick)
local UiPackConfig = require(script.Parent.UiPackConfig)

local rgb = Color3.fromRGB
local icon = IconPick.Image

local P = UiPackConfig.Icons
local TROPHY = icon("Trophy")
local WINS = { TROPHY, "Wins" }

local function pet(id: string, rays: Color3?)
	return { Models = { { Path = "Pets." .. id } }, Spin = "Swing", Rays = rays }
end

local function tread(id: string, rays: Color3?)
	return { Models = { { Path = "World." .. id } }, Spin = "Turn", Rays = rays }
end

local function trophies(scale: number)
	return { Image = TROPHY, Rays = rgb(255, 220, 90), Scale = scale }
end

return {
	Texts = {
		Owned = "OWNED",
		Cash = "+%s Wins", -- the default live note of "Cash" products
		Chance = "%d%%",
		Codes = { Title = "Redeem codes for free items, boosts & more!", Hint = "Enter code here...", Button = "Redeem" },
	},
	Sounds = { Celebrate = "Mythic", Arrive = "Gain" }, -- SoundConfig names: the burst, each icon landing
	NoteEvery = 3, -- seconds between live note refreshes while the window is open
	Gift = { Color = "Purple", Size = 0.75 }, -- the gift button: a square (Size x the price button's height) on its top-left corner

	Layout = {
		Ratio = { Starter = 4.5, Offer = 3.21, Wide = 3.21, Half = 1.55, Pack = 1.05, Codes = 3.21 },
		Width = 0.968, Gap = 0.03, HeaderRatio = 14, Padding = 8, BottomRoom = 24, Settle = 0.4,
	},

	Sections = {
		{ Key = "Featured", Header = "~ Packs ~", Text = "Pink", Rows = { { "Starter" }, { "Demon" } } },
		{ Key = "Limited", Header = "~ Limited Offer ~", Text = "Green", Rows = { { "AdminEgg" } } },
		{ Key = "Passes", Header = "~ Gamepasses ~", Text = "Purple", Columns = 3, Rows = {
			{ "PassPetSlot1", "PassPetSlot3", "PassPetSlot6" },
			{ "PassEggs3", "PassEggs8", "PassEggs16" },
		} },
		{ Key = "Multipliers", Header = "~ Multipliers ~", Text = "Orange", Rows = { { "PassSpeed2x" }, { "PassWins2x" } } },
		{ Key = "Zones", Header = "~ Zones ~", Text = "Green", Rows = { { "PassAdminZone" }, { "PassKoiZone", "PassGoldenZone" } } },
		{ Key = "Boosts", Header = "~ Boosts ~", Text = "Blue", Rows = { { "BoostBundle" }, { "SpeedPotion", "WinsPotion" } } },
		{ Key = "Wins", Header = "~ Wins Pack ~", Text = "Gold", Columns = 2, Rows = {
			{ "TinyWins", "SmallWins" }, { "MediumWins", "LargeWins" }, { "MegaWins", Columns = 1 },
		} },
		{ Key = "Codes", Header = "~ Codes ~", Text = "LightBlue", Rows = { { "Codes" } } },
	},

	Cards = {
		Starter = { Card = "Starter", Key = "Starter", Color = "Rainbow", Title = "Starter Pack", Name = "Starter Pack", Tag = "ONE TIME!",
			TagColor = "Orange", Old = 199, Value = "84% OFF!", Art = pet("RainbowKitty", rgb(255, 200, 255)),
			Lines = {
				{ Amount = "x5", Name = "Rainbow Kitty", Art = pet("RainbowKitty") },
				{ Amount = "+10", Name = "Levels", Art = { Image = icon("Boost") } },
				{ Amount = "+1", Name = "Rebirth", Art = { Image = P.Rebirth } },
			},
			Fly = { P.Gift, nil } },
		Demon = { Card = "Starter", Key = "Demon", Color = "Red", Title = "Demon Pack", Name = "Demon Pack", Tag = "BEST VALUE!",
			TagColor = "Red", Old = 759, Value = "68% OFF!", Art = pet("DemonPup", rgb(255, 80, 80)),
			Lines = {
				{ Amount = "x12", Name = "Demon Pup", Art = pet("DemonPup") },
				{ Amount = "x3", Name = "Boosts", Art = { Image = icon("Boost") } },
				{ Amount = "+3", Name = "Rebirths", Art = { Image = P.Rebirth } },
			},
			Fly = { P.Gift, nil } },
		AdminEgg = { Card = "Offer", Color = "Green", Title = "Admin Egg", Name = "Admin Egg", Tag = "LIMITED OFFER", OddsEgg = "Admin",
			Art = { Models = { { Path = "Pets.AdminEgg" } }, Spin = "Swing", Rays = rgb(80, 255, 120) },
			Buttons = { { Key = "AdminEgg8", Text = "Buy 8", Color = "Green" }, { Key = "AdminEgg3", Text = "Buy 3", Color = "Green" },
				{ Key = "AdminEgg1", Text = "Buy 1", Color = "Green" } } },
		PassPetSlot1 = { Card = "Half", Key = "PassPetSlot1", Color = "Blue", Title = "+1 Pet Slot", Art = pet("TimberCub") },
		PassPetSlot3 = { Card = "Half", Key = "PassPetSlot3", Color = "Purple", Title = "+3 Pet Slots", Art = pet("FrostFox") },
		PassPetSlot6 = { Card = "Half", Key = "PassPetSlot6", Color = "Red", Title = "+6 Pet Slots", Art = pet("BlazeCat") },
		PassSpeed2x = { Card = "Wide", Key = "PassSpeed2x", Color = "Green", Title = "2x Speed!", From = "x1", To = "x2",
			Art = { Image = icon("Boost"), Rays = rgb(180, 255, 140) } },
		PassWins2x = { Card = "Wide", Key = "PassWins2x", Color = "Orange", Title = "2x Wins!", From = "x1", To = "x2",
			Art = { Image = TROPHY, Rays = rgb(255, 230, 120) }, Fly = WINS },
		PassEggs3 = { Card = "Half", Key = "PassEggs3", Color = "Blue", Title = "+3 Eggs", Desc = "Hatch 3 at once", Art = pet("CommonEgg") },
		PassEggs8 = { Card = "Half", Key = "PassEggs8", Color = "Purple", Title = "+8 Eggs", Desc = "Hatch 8 at once", Art = pet("RareEgg") },
		PassEggs16 = { Card = "Half", Key = "PassEggs16", Color = "Pink", Title = "+16 Eggs", Desc = "Hatch 16 at once", Art = pet("RainbowEgg") },
		PassAdminZone = { Card = "Wide", Key = "PassAdminZone", Color = "Green", Title = "Admin Zone", From = "12x", To = "SPEED", Rainbow = true, Old = 799,
			Desc = "Works in every world!", Art = tread("TreadAdmin", rgb(80, 255, 120)) },
		PassKoiZone = { Card = "Half", Key = "PassKoiZone", Color = "Pink", Title = "Koi Zone", Desc = "4x Speed", Art = tread("TreadKoi") },
		PassGoldenZone = { Card = "Half", Key = "PassGoldenZone", Color = "Orange", Title = "Golden Zone", Desc = "8x Speed", Art = tread("TreadGolden") },
		BoostBundle = { Card = "Wide", Key = "BoostBundle", Color = "Blue", Title = "Boost Bundle", From = "2+2", To = "BOOSTS",
			Row = { { Image = icon("Boost"), Text = "x2" }, { Image = TROPHY, Text = "x2" } }, -- speed + wins icon, no arrow
			Desc = "2 Speed + 2 Wins Boosts", Art = { Image = icon("Boost"), Rays = rgb(140, 220, 255) } },
		SpeedPotion = { Card = "Half", Key = "SpeedPotion", Color = "Red", Title = "Speed Boost", Desc = "2x Speed for 10 min", Art = { Image = icon("Boost") } },
		WinsPotion = { Card = "Half", Key = "WinsPotion", Color = "Orange", Title = "Wins Boost", Desc = "2x Wins for 10 min", Art = { Image = TROPHY }, Fly = WINS },
		TinyWins = { Card = "Pack", Key = "TinyWins", Color = "Orange", Image = TROPHY, ImageScale = 0.45, Fly = WINS },
		SmallWins = { Card = "Pack", Key = "SmallWins", Color = "Orange", Image = TROPHY, ImageScale = 0.52, Fly = WINS },
		MediumWins = { Card = "Pack", Key = "MediumWins", Color = "Orange", Image = TROPHY, ImageScale = 0.6, Fly = WINS },
		LargeWins = { Card = "Pack", Key = "LargeWins", Color = "Orange", Image = TROPHY, ImageScale = 0.68, Fly = WINS },
		-- Mega: the first purchase sells MegaWinsFirst (FIRST TIME DISCOUNT, crossed-out 460); once bought the card sells MegaWins
		MegaWins = { Card = "Wide", Key = "MegaWinsFirst", Then = "MegaWins", Color = "Orange", Title = "Mega Pack", From = "+1M", To = "WINS", Rainbow = true,
			Desc = "FIRST TIME DISCOUNT", Art = trophies(1.2), Fly = WINS },
		Codes = { Card = "Codes", Color = "Blue" },
	},
}
