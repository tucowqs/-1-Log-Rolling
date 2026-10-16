--[[
	ShopConfig — every Robux item (ShopService grants, ShopController sells). WHAT is sold lives here; HOW it
	looks (sections, GameUI pack cards, art) is ShopUiConfig, keyed by the same ShopMath keys ("Pass<Key>" for passes,
	the product Key for products). Prices copy +1 Rock Skipping (2026-10-14, Preston: "all the monetization from this game").

	IDs: 0 = PLACEHOLDER, not created on the Creator Dashboard yet. A 0 button says ComingSoon instead of
	prompting; ShopService warns about receipts it can't match (and leaves them NotProcessedYet).
	Gift = the developer product id that buys this item FOR another player (GiftController picks who; 0 = no gift yet).
	Every item with a Gift field shows the purple gift button on its card.

	Grant kinds (MonetizeService registers them; "Cash" = Wins is built in):
	  "Cash"    { Amount }                             Wins (DataConfig.Currency)
	  "Speed"   { Levels }                             the Speed for that many more levels (no multipliers), clamped at the cap
	  "Bundle"  { Bundle = { Pets?, Speed? (levels), Wins?, Potions?, Rebirths?, Slots? } }   a pack of everything
	  "Egg"     { Egg, Count }                         hatches Count of a Robux egg (PetsConfig.Eggs, paid random)
	  "Limited" { Limited }                            one of LimitedConfig.Items (global stock)
	Passes: Attribute = the player attribute ShopService sets while the pass is active; the game reads it
	(BoostMath for 2x Speed / 2x Wins, PetService slots, TrainingService zones, EggController multi).
]]
-- Creator Dashboard ids (created through Open Cloud 2026-10-15): Pass = the gamepass, Gift = the dev product that buys it for another player.
local PASS_IDS = {
	PassAdminZone = { Pass = 2036864660, Gift = 3718791415 },
	-- PassAutoRoll (Pass 2037878683, Gift 3718791356) was removed from the game 2026-10-15
	PassEggs16 = { Pass = 2037512707, Gift = 3718791432 },
	PassEggs3 = { Pass = 2037992704, Gift = 3718791421 },
	PassEggs8 = { Pass = 2037428665, Gift = 3718791425 },
	PassGoldenZone = { Pass = 2037860699, Gift = 3718791407 },
	PassKoiZone = { Pass = 2037086699, Gift = 3718791400 },
	PassPetSlot1 = { Pass = 2036792669, Gift = 3718791380 },
	PassPetSlot3 = { Pass = 2040056429, Gift = 3718791386 },
	PassPetSlot6 = { Pass = 2036720657, Gift = 3718791389 },
	PassSpeed2x = { Pass = 2037590678, Gift = 3718791343 },
	PassWins2x = { Pass = 2038250668, Gift = 3718791350 },
}

local function pass(name, price, attribute, extra)
	local ids = PASS_IDS[attribute]
	local def = { Name = name, Price = price, Pass = ids.Pass, Gift = ids.Gift, Attribute = attribute }
	for key, value in extra or {} do
		def[key] = value
	end
	return def
end

return {
	Bridges = { "ShopPurchased" }, -- S->C { Key } after a fresh product grant / pass purchase: the client celebrates.

	RandomKinds = { Egg = true }, -- Robux eggs are paid random items (refused where PolicyService restricts them)

	Passes = {
		Speed2x = pass("2x Speed", 5, "PassSpeed2x", { Desc = "Double every Speed gain, forever!" }),
		Wins2x = pass("2x Wins", 48, "PassWins2x", { Desc = "Double every Wins payout, forever!" }),
		PetSlot1 = pass("+1 Pet Slot", 56, "PassPetSlot1", { Slots = 1 }),
		PetSlot3 = pass("+3 Pet Slots", 156, "PassPetSlot3", { Slots = 3 }),
		PetSlot6 = pass("+6 Pet Slots", 400, "PassPetSlot6", { Slots = 6 }),
		-- Robux treadmills (BalanceConfig.Training.Treadmills[].Pass): work in every world
		KoiZone = pass("Koi Zone", 80, "PassKoiZone", { Desc = "4x Speed treadmill, all worlds!" }),
		GoldenZone = pass("Golden Zone", 200, "PassGoldenZone", { Desc = "8x Speed treadmill, all worlds!" }),
		AdminZone = pass("Admin Zone", 480, "PassAdminZone", { Desc = "12x Speed treadmill, all worlds!" }),
		-- hatch more eggs at once (EggController Multi = the biggest owned; Rock Skipping's prices weren't on screen: guesses)
		Eggs3 = pass("+3 Eggs", 99, "PassEggs3", { Eggs = 3 }),
		Eggs8 = pass("+8 Eggs", 299, "PassEggs8", { Eggs = 8 }),
		Eggs16 = pass("+16 Eggs", 699, "PassEggs16", { Eggs = 16 }),
	},
	PassOrder = { "Speed2x", "Wins2x", "PetSlot1", "PetSlot3", "PetSlot6",
		"KoiZone", "GoldenZone", "AdminZone", "Eggs3", "Eggs8", "Eggs16" },

	-- Developer products. Key must be unique and never reused for something else (receipts name it).
	Products = {
		-- the HUD's three level buttons under the level bar (StarterGui.Main.Bottom; Rock Skipping's +100K / +1M / +10M Skill):
		-- Levels = levels of Speed added (capped at the rebirth max level: the button refuses at the cap)
		{ Key = "Levels5", Kind = "Speed", Levels = 5, Price = 9, Product = 3718791439, Gift = 3718791441, Name = "+5 Levels" },
		{ Key = "Levels10", Kind = "Speed", Levels = 10, Price = 36, Product = 3718791446, Gift = 3718791449, Name = "+10 Levels" },
		{ Key = "Levels25", Kind = "Speed", Levels = 25, Price = 76, Product = 3718791452, Gift = 3718791456, Name = "+25 Levels" },
		-- packs (ShopUiConfig "Featured")
		{ Key = "Starter", Kind = "Bundle", Price = 32, Old = 199, Product = 3718791459, Gift = 3718791463, OneTime = true, Name = "Starter Pack",
			Bundle = { Pets = { "RainbowKitty" }, Speed = 10, Potions = { Wins = 1 }, Rebirths = 1 } },
		{ Key = "Demon", Kind = "Bundle", Price = 240, Old = 759, Product = 3718791466, Gift = 3718791467, Name = "Demon Pack",
			Bundle = { Pets = { "DemonPup" }, Potions = { Speed = 2, Wins = 1 }, Slots = 1, Rebirths = 3 } }, -- 3 rebirths (was 10): each raises the level cap, so 10 at once stranded new buyers at a cap their log couldn't reach
		-- the Admin Egg limited offer (ShopUiConfig "Limited" card) and the Robux eggs on the hatchery podiums
		{ Key = "AdminEgg1", Kind = "Egg", Egg = "Admin", Count = 1, Price = 140, Product = 3718791470, Gift = 3718791473, Name = "Admin Egg" },
		{ Key = "AdminEgg3", Kind = "Egg", Egg = "Admin", Count = 3, Price = 368, Product = 3718791475, Gift = 3718791480, Name = "3 Admin Eggs" },
		{ Key = "AdminEgg8", Kind = "Egg", Egg = "Admin", Count = 8, Price = 920, Product = 3718791484, Gift = 3718791490, Name = "8 Admin Eggs" },
		{ Key = "RainbowEgg1", Kind = "Egg", Egg = "Rainbow", Count = 1, Price = 36, Product = 3718791498, Gift = 3718791501, Name = "Rainbow Egg" },
		-- boosts (BoostConfig.Potions: used from the Inventory)
		{ Key = "BoostBundle", Kind = "Bundle", Price = 76, Old = 199, Product = 3718791505, Gift = 3718791509, Name = "Boost Bundle",
			Bundle = { Potions = { Speed = 2, Wins = 2 } } },
		{ Key = "SpeedPotion", Kind = "Bundle", Price = 24, Product = 3718791513, Gift = 3718791520, Name = "Speed Boost", Bundle = { Potions = { Speed = 1 } } },
		{ Key = "WinsPotion", Kind = "Bundle", Price = 24, Product = 3718791522, Gift = 3718791523, Name = "Wins Boost", Bundle = { Potions = { Wins = 1 } } },
		-- Wins packs (Mega: the first purchase is discounted, then MegaWins at the full price)
		{ Key = "TinyWins", Kind = "Cash", Amount = 1e4, Price = 20, Product = 3718791529, Gift = 3718791531, Name = "Tiny Pack" },
		{ Key = "SmallWins", Kind = "Cash", Amount = 5e4, Price = 48, Product = 3718791537, Gift = 3718791540, Name = "Small Pack" },
		{ Key = "MediumWins", Kind = "Cash", Amount = 2e5, Price = 92, Product = 3718791544, Gift = 3718791547, Name = "Medium Pack" },
		{ Key = "LargeWins", Kind = "Cash", Amount = 5e5, Price = 184, Product = 3718791556, Gift = 3718791562, Name = "Large Pack" },
		{ Key = "MegaWinsFirst", Kind = "Cash", Amount = 1e6, Price = 368, Old = 460, Product = 3718791571, OneTime = true, Name = "Mega Pack" },
		{ Key = "MegaWins", Kind = "Cash", Amount = 1e6, Price = 460, Product = 3718791577, Gift = 3718791584, Name = "Mega Pack" },
		-- limited-stock items on their lobby pedestals (LimitedConfig)
		{ Key = "KingBones", Kind = "Limited", Limited = "KingBones", Price = 1040, Product = 3718791586, Name = "King Bones" },
		{ Key = "ReaperRelic", Kind = "Limited", Limited = "ReaperRelic", Price = 560, Product = 3718791588, Name = "Reaper Relic" },
	},

	-- Cash packs with Minutes grow with this player attribute (cash per second; the game mirrors it). nil = fixed.
	IncomeAttribute = nil,

	-- The one-time offer popup (ShopOfferController): the Starter Pack, on the 2nd session.
	Offer = { Key = "Starter", Session = 2, AfterRun = 1.5 }, -- pops AfterRun seconds after a roll ends (not during the tutorial)

	-- Buying (ShopController.Buy). The window's look and layout live in ShopUiConfig.
	Ui = {
		Menu = "Shop", -- ClientState menu (ClientState.OpenMenu("Shop", sectionKey?))
		OfferMenu = "ShopOffer", -- its window: UiPackConfig.Menus.ShopOffer
		ComingSoon = "This item isn't for sale yet!",
		Restricted = "This item isn't available in your region.",
		MaxLevel = "You're at max level! Rebirth first.", -- a Speed product while Speed is capped
	},

	-- In-game Wins purchases (PurchaseService.Charge).
	NotEnough = "Need %s more Wins for %s!", -- (missing amount, item) - both emphasised
	Purchased = "%s purchased!",
}
