--[[
	IconPicksConfig — UI icons picked from the RhosGFX vector icon pack BY FILE NAME ONLY
	(the kit's assets/icons: `node <kit>/assets/icons/icons.js search <words>`; license: never open / view the PNGs, never commit
	the pack). Path = the pack relpath, Id = its uploaded asset id (<ROBLOXKIT_HOME>/icons/uploaded.json, seeded from the kit's uploaded.seed.json; 0 = not
	uploaded yet: upload with Roblox_Studio upload_image, then `icons.js record`). Until an Id is filled in,
	IconPick.Image(name) shows UIConfig.Icons[Fallback], so the UI never has a hole.
	These ids are uploads on the kit author's user account; a group-owned game re-uploads (same paths) and records.
	Add the game's own picks below the kit's.
]]
return {
	-- Menus / HUD buttons
	Dumbbell = { Path = "Sports/Dumbbell/Dumbbell Outline 256.png", Id = 0, Fallback = "Upgrade" },
	Trophy = { Path = "General/Trophy/Trophy Outline 256.png", Id = 0, Fallback = "Trophy" },
	Shop = { Path = "General/Shop/Shop Outline 256.png", Id = 89212886922207, Fallback = "CoinStack" },
	Rewards = { Path = "General/Gift Box/Gift Box Outline 256.png", Id = 121205649949590, Fallback = "Chest" },
	Settings = { Path = "General/Settings/Gear Outline 256.png", Id = 103412063811268, Fallback = "Gear" },
	Index = { Path = "Items/Book/Book Outline 256.png", Id = 138602644936204, Fallback = "Book" },
	Rebirth = { Path = "General/Rebirth/Rebirth Outline 256.png", Id = 128206101057387, Fallback = "Upgrade" },
	Upgrade = { Path = "General/Upgrade/Upgrade Outline 256.png", Id = 121084958267146, Fallback = "Upgrade" },
	Stats = { Path = "General/Stats/Stats 2 Outline 256.png", Id = 76451312717668, Fallback = "ArrowUp" },
	-- Currencies / items
	Robux = { Path = "Currency/Robux/Robux Outline 256.png", Id = 112029391178896, Fallback = "CoinStack" },
	Cash = { Path = "Currency/Cash/Cash Outline 256.png", Id = 103513230930752, Fallback = "Cash" },
	CoinStack = { Path = "Currency/Coin Stack/Coin Stack Gold Outline 256.png", Id = 88035916937286, Fallback = "CoinStack" },
	Safe = { Path = "Items/Safe/Safe Outline 256.png", Id = 124474900067972, Fallback = "Chest" },
	Gem = { Path = "Currency/Gem/Gem Blue Outline 256.png", Id = 83276448785838, Fallback = "Sparkle" },
	Chest = { Path = "Items/Chest/Chest 2/Chest Large 2 Outline 256.png", Id = 135868742556746, Fallback = "Chest" },
	LuckyBlock = { Path = "Items/Lucky Block/Lucky Block Yellow Outline 256.png", Id = 116725755671163, Fallback = "QuestionMark" },
	-- Perks / boosts
	Boost = { Path = "General/Lightning Bolt/Lightning Bolt Yellow Outline 256.png", Id = 139552705029339, Fallback = "Lightning" },
	Event = { Path = "General/Lightning Bolt/Lightning Bolt Purple Outline 256.png", Id = 121235309496277, Fallback = "Lightning" },
	Speed = { Path = "Player/Speed/Speed Outline 256.png", Id = 73889871104097, Fallback = "Speed" },
	Rocket = { Path = "Transport/Rocket/Rocket Outline 256.png", Id = 112471393527903, Fallback = "Speed" },
	Magnet = { Path = "Tools/Magnet/Magnet Outline 256.png", Id = 127567686596643, Fallback = "CoinStack" },
	Crown = { Path = "Clothing/Crown/Crown Outline 256.png", Id = 94146179855988, Fallback = "Trophy" },
	Fire = { Path = "Nature/Fire/Fire Outline 256.png", Id = 88365459382455, Fallback = "Star" },
	Plus = { Path = "UI/Plus/Plus Outline 256.png", Id = 79907690083677, Fallback = "Upgrade" },
	-- Rewards / time
	Calendar = { Path = "UI/Calendar/Calendar Outline 256.png", Id = 120302463541527, Fallback = "Star" },
	Timer = { Path = "Tools/Clock/Clock Outline 256.png", Id = 87799752610861, Fallback = "Play" },
	Hourglass = { Path = "Tools/Hourglass/Hourglass Outline 256.png", Id = 83353979972796, Fallback = "Play" },
	GiftBlue = { Path = "General/Gift Box/Gift Box Blue Outline 256.png", Id = 94226587043677, Fallback = "Chest" },
	GiftGreen = { Path = "General/Gift Box/Gift Box Green Outline 256.png", Id = 71747216471688, Fallback = "Chest" },
	GiftPurple = { Path = "General/Gift Box/Gift Box Purple Outline 256.png", Id = 132141787059798, Fallback = "Chest" },
	Lock = { Path = "General/Lock/Lock Outline 256.png", Id = 117069239513475, Fallback = "X" },
	-- Uploaded 2026-10-13 under the user account (Paw 73816990222509, Trash 88791494926404, Backpack 100773940511996) but this place is
	-- GROUP-owned, so the experience is refused them ("no access permission"). Share the assets with the group, then fill the Ids in.
	Paw = { Path = "General/Paw/Paw Outline 256.png", Id = 0, Fallback = "Star" },
	Trash = { Path = "UI/Trash/Trash Outline 256.png", Id = 0, Fallback = "Trash" },
	Backpack = { Path = "Clothing/Backpack/Backpack Outline 256.png", Id = 0, Fallback = "Backpack" },
	Check = { Path = "UI/Check Mark/Check Mark Outline 256.png", Id = 75816530486817, Fallback = "CheckMark" },
}
