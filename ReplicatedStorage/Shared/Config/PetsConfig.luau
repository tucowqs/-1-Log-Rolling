--[[
	PetsConfig — pets, eggs and the Pets window (PetService + PetsController + EggController + HatchController +
	PetFollowController, all maths in Shared/Modules/PetMath).
	  * Pets (Blender models, ServerStorage.MeshData) in rarities. Each equipped pet adds its Mult to a PET BONUS
	    that multiplies every Speed gain: Total = RebirthMult x (1 + sum of equipped pet Mults)  (PetMath.Total).
	  * 2026-10-15 economy: a pet's Mult is GENERATED from its Rank on one ladder (Economy.PetMult: 0.1 x 1.35^(Rank-1), so
	    Rank 1 = +0.1 ... Rank 10 = +1.5, Rank 18 = +16); World 2 pets continue World 1's ladder (World 3's Ranks 21-28 go on from there) and the Robux pets sit on it too.
	    A Wins egg's Price is the Price of the log of its Tier (Economy.LogPrice): an egg costs "one log" of progress.
	  * Two eggs on podiums behind the spawn (built in Studio by tools/build_eggs.lua). Stand near one: a billboard shows its
	    odds and the Hatch x1 / x3 buttons (E / R) appear; hatching costs Wins (server validates everything).
	  * Equipped pets follow their owner everywhere except while the log is rolling (client-side, Controllers/PetFollowController).
]]
local Economy = require(script.Parent.Parent.Modules.Economy)

local rgb = Color3.fromRGB

local config = {
	Bridges = {
		"PetHatch", -- C->S {Egg, Count}          hatch Count (1 or 3) eggs of that egg
		"PetHatched", -- S->owner {Egg, Pets = {petId...}}   the result (the hatch animation plays it)
		"PetEquip", -- C->S {Uid, On}               equip / unequip one pet
		"PetEquipBest", -- C->S {}                  equip the highest-Mult pets that fit
		"PetDelete", -- C->S {Uid}                  delete one (unequipped) pet
	},

	Menu = "Pets", -- ClientState menu name (UiPackConfig.Menus.Pets is the window)
	-- The first-pet guide (PetGuideController): after a new player's first hatch, a sticky toast + the screen dim (Spotlight,
	-- TutorialConfig.Dim) walk them through the HUD Pets button -> that pet's tile -> EQUIP. Ends for good once they equip a pet.
	FirstPet = { Header = "NEW PET:", Open = "Open your Pets!", Select = "Tap your %s!", Equip = "Equip it!" },
	Storage = 200, -- most pets a player can hold
	EquipMax = 3, -- pets equipped at once before slot passes (ShopConfig PetSlot*: + Slots) and bundle slots (data.ExtraSlots)
	-- Hatching (the Rock Skipping egg card): E = Hatch 1, R = Multi (MultiBase eggs, or the biggest ShopConfig Eggs* pass owned),
	-- T = Auto (hatches again and again, Auto.Every s apart, until toggled off, the player walks away or runs out of Wins).
	MultiBase = 2,
	MultiPasses = { "Eggs3", "Eggs8", "Eggs16" }, -- ShopConfig passes, smallest first (the egg card's left column)
	Auto = { Every = 0.25 }, -- seconds between auto hatches (after each reveal)

	-- Rarity bands: Rays = the sunburst behind the art, Text = UiPackConfig.Text gradient of the name, Order = sort + Equip Best tie-break.
	Rarities = {
		Common = { Order = 1, Rays = rgb(200, 205, 215), Text = "White", Tile = "Silver" },
		Uncommon = { Order = 2, Rays = rgb(120, 230, 110), Text = "Green", Tile = "Green" },
		Rare = { Order = 3, Rays = rgb(90, 170, 255), Text = "Blue", Tile = "Blue" },
		Epic = { Order = 4, Rays = rgb(200, 100, 255), Text = "Purple", Tile = "Purple" },
		Legendary = { Order = 5, Rays = rgb(255, 200, 60), Text = "Gold", Tile = "Orange" },
		Mythic = { Order = 6, Rays = rgb(255, 90, 200), Text = "Pink", Tile = "Pink" },
		Exclusive = { Order = 7, Rays = rgb(255, 60, 60), Text = "Red", Tile = "Red" },
		Limited = { Order = 8, Rays = rgb(90, 255, 230), Text = "LightBlue", Tile = "Rainbow" },
	},

	-- Id = the Blender model in Assets.Pets; Rank = its place on the pet ladder (Mult = its share of the Speed-gain bonus, filled below).
	Pets = {
		{ Id = "PebblePup", Name = "Pebble Pup", Rarity = "Common", Rank = 1 },
		{ Id = "MossyBunny", Name = "Mossy Bunny", Rarity = "Common", Rank = 2 },
		{ Id = "TimberCub", Name = "Timber Cub", Rarity = "Common", Rank = 3 },
		{ Id = "FrostFox", Name = "Frost Fox", Rarity = "Uncommon", Rank = 4 },
		{ Id = "HoneyBee", Name = "Honey Bee", Rarity = "Uncommon", Rank = 5, Fly = true },
		{ Id = "MossTurtle", Name = "Moss Turtle", Rarity = "Uncommon", Rank = 6 },
		{ Id = "BlazeCat", Name = "Blaze Cat", Rarity = "Rare", Rank = 7 },
		{ Id = "SkyDragon", Name = "Sky Dragon", Rarity = "Rare", Rank = 8, Fly = true },
		{ Id = "CosmicOwl", Name = "Cosmic Owl", Rarity = "Epic", Rank = 9, Fly = true },
		{ Id = "SunPhoenix", Name = "Sun Phoenix", Rarity = "Legendary", Rank = 10, Fly = true },
		-- Robux pets (2026-10-14: the Rock Skipping monetization). Packs: ShopConfig Starter / Demon.
		{ Id = "RainbowKitty", Name = "Rainbow Kitty", Rarity = "Exclusive", Rank = 10, Fly = true },
		{ Id = "DemonPup", Name = "Demon Pup", Rarity = "Exclusive", Rank = 13, Fly = true },
		{ Id = "PrismPup", Name = "Prism Pup", Rarity = "Mythic", Rank = 8 },
		{ Id = "CandyBunny", Name = "Candy Bunny", Rarity = "Mythic", Rank = 9 },
		{ Id = "AuroraFox", Name = "Aurora Fox", Rarity = "Mythic", Rank = 11 },
		{ Id = "CodeCat", Name = "Code Cat", Rarity = "Exclusive", Rank = 12 },
		{ Id = "AdminKnight", Name = "Admin Knight", Rarity = "Exclusive", Rank = 14 },
		{ Id = "VoidBat", Name = "Void Bat", Rarity = "Exclusive", Rank = 16, Fly = true },
		{ Id = "FrostWyrm", Name = "Frost Wyrm", Rarity = "Exclusive", Rank = 18, Fly = true },
		{ Id = "GoldenOverlord", Name = "Golden Overlord", Rarity = "Exclusive", Rank = 20, Fly = true },
		-- World 2 (Haunted Halloween) Wins pets: the Spooky / Cursed eggs
		{ Id = "PumpkinPup", Name = "Pumpkin Pup", Rarity = "Common", Rank = 11 },
		{ Id = "CandyCornChick", Name = "Candy Corn Chick", Rarity = "Common", Rank = 12 },
		{ Id = "SkeleDog", Name = "Skele Dog", Rarity = "Uncommon", Rank = 13 },
		{ Id = "MummyBear", Name = "Mummy Bear", Rarity = "Uncommon", Rank = 14 },
		{ Id = "GhostKitty", Name = "Ghost Kitty", Rarity = "Rare", Rank = 15, Fly = true },
		{ Id = "WitchCat", Name = "Witch Cat", Rarity = "Epic", Rank = 16 },
		{ Id = "BatBun", Name = "Bat Bun", Rarity = "Epic", Rank = 17, Fly = true },
		{ Id = "VampireBat", Name = "Vampire Bat", Rarity = "Legendary", Rank = 18, Fly = true },
		-- World 3 (Dream Kingdom) Wins pets: the Dream / Cosmic eggs (ranks 21-28 continue the ladder)
		{ Id = "JellyBear", Name = "Jelly Bear", Rarity = "Common", Rank = 21 },
		{ Id = "CloudLamb", Name = "Cloud Lamb", Rarity = "Common", Rank = 22 },
		{ Id = "NeonFox", Name = "Neon Fox", Rarity = "Uncommon", Rank = 23 },
		{ Id = "GearBot", Name = "Gear Bot", Rarity = "Uncommon", Rank = 24 },
		{ Id = "PrismDeer", Name = "Prism Deer", Rarity = "Rare", Rank = 25 },
		{ Id = "RainbowUnicorn", Name = "Rainbow Unicorn", Rarity = "Epic", Rank = 26 },
		{ Id = "CometCat", Name = "Comet Cat", Rarity = "Epic", Rank = 27, Fly = true },
		{ Id = "GalaxyWhale", Name = "Galaxy Whale", Rarity = "Legendary", Rank = 28, Fly = true },
		-- the limited "BEST IN GAME" pet (LimitedConfig): Better = always this many times your best other pet's Mult (PetMath.MultOf)
		{ Id = "KingBones", Name = "King Bones", Rarity = "Limited", Mult = 0, Better = 3 },
	},

	-- Eggs: Odds = percent per pet (each egg's list sums to 100), Tier = the log tier whose Price it costs in Wins (Price filled below), Pos = the podium (offset from Track.Origin).
	-- Robux = the ShopConfig product key one hatch buys (the egg is paid in Robux, never Wins; Price is then the Robux shown).
	-- The Common egg mostly hatches Common pets, the Rare egg none: Uncommon and up, with the best odds of Rare / Epic / Legendary.
	Eggs = {
		{ Id = "Common", World = 1, Name = "Common Egg", Model = "CommonEgg", Tier = 4, Price = 70, Rarity = "COMMON", Title = "White", Color = rgb(250, 232, 190), Pos = Vector3.new(-30, 0, -150),
			Odds = { PebblePup = 36, MossyBunny = 28, TimberCub = 20, FrostFox = 8, HoneyBee = 5, MossTurtle = 3 } },
		{ Id = "Uncommon", World = 1, Name = "Uncommon Egg", Model = "UncommonEgg", Tier = 7, Rarity = "UNCOMMON", Title = "Green", Color = rgb(120, 230, 110), Pos = Vector3.new(-10, 0, -150),
			Odds = { MossyBunny = 30, TimberCub = 28, FrostFox = 20, HoneyBee = 12, MossTurtle = 7, BlazeCat = 3 } },
		{ Id = "Rare", World = 1, Name = "Rare Egg", Model = "RareEgg", Tier = 10, Rarity = "RARE", Title = "Purple", Color = rgb(124, 98, 232), Pos = Vector3.new(10, 0, -150),
			Odds = { FrostFox = 20, HoneyBee = 20, MossTurtle = 15, BlazeCat = 22, SkyDragon = 14, CosmicOwl = 7, SunPhoenix = 2 } },
		{ Id = "Rainbow", World = 1, Name = "Rainbow Egg", Model = "RainbowEgg", Robux = "RainbowEgg1", Price = 36, Rarity = "RAINBOW", Title = "Pink", Color = rgb(255, 120, 220), Pos = Vector3.new(30, 0, -150),
			Odds = { PrismPup = 55, CandyBunny = 35, AuroraFox = 10 } },
		-- World 2 (World = the world whose hatchery holds the podium, tools/lobby_layout.lua)
		{ Id = "Spooky", World = 2, Name = "Spooky Egg", Model = "SpookyEgg", Tier = 13, Rarity = "SPOOKY", Title = "Orange", Color = rgb(255, 140, 30), Pos = Vector3.new(-10, 0, -150),
			Odds = { PumpkinPup = 35, CandyCornChick = 28, SkeleDog = 20, MummyBear = 10, GhostKitty = 5, WitchCat = 2 } },
		{ Id = "Cursed", World = 2, Name = "Cursed Egg", Model = "CursedEgg", Tier = 18, Rarity = "CURSED", Title = "Purple", Color = rgb(150, 60, 220), Pos = Vector3.new(10, 0, -150),
			Odds = { SkeleDog = 25, MummyBear = 25, GhostKitty = 20, WitchCat = 15, BatBun = 10, VampireBat = 5 } },
		-- World 3 (Dream Kingdom): Tier 23 / 28 = the price of that log, like World 2's 13 / 18
		{ Id = "Dream", World = 3, Name = "Dream Egg", Model = "DreamEgg", Tier = 23, Rarity = "DREAMY", Title = "Pink", Color = rgb(255, 160, 205), Pos = Vector3.new(-10, 0, -150),
			Odds = { JellyBear = 35, CloudLamb = 28, NeonFox = 20, GearBot = 10, PrismDeer = 5, RainbowUnicorn = 2 } },
		{ Id = "Cosmic", World = 3, Name = "Cosmic Egg", Model = "CosmicEgg", Tier = 28, Rarity = "COSMIC", Title = "Blue", Color = rgb(110, 120, 255), Pos = Vector3.new(10, 0, -150),
			Odds = { NeonFox = 25, GearBot = 25, PrismDeer = 20, RainbowUnicorn = 15, CometCat = 10, GalaxyWhale = 5 } },
		-- shop-only (the Limited Offer card): no podium
		{ Id = "Admin", Name = "Admin Egg", Model = "AdminEgg", Robux = "AdminEgg1", Price = 140, Rarity = "ADMIN", Title = "Green", Color = rgb(40, 220, 90), Shop = true,
			Odds = { CodeCat = 40, AdminKnight = 34, VoidBat = 20, FrostWyrm = 5, GoldenOverlord = 1 } },
	},

	-- The hatchery behind the spawn (tools/build_eggs.lua): a path from the spawn path back to a round plaza with the two podiums.
	World = {
		PathWidth = 10, PathColor = rgb(206, 200, 232),
		Plaza = { Z = -150, Radius = 44, Color = rgb(190, 186, 226), Rim = rgb(150, 144, 196) }, -- tools/lobby_layout.lua (the enlarged lobby)
		Podium = { Model = "EggPodium", Size = 7, Height = 0.98, Floor = 0.55 }, -- the Blender pad (client-placed by EggController) + its invisible collider
		Egg = { Gap = 0.9, Bob = 0.25, BobSpeed = 1.6, Turn = 0.7, Size = 6.5 }, -- gap = studs between the podium top and the egg bottom, turn = rad/s
		Billboard = { Size = Vector2.new(12.5, 10.4), Near = 16, Show = 14, Far = 19, Lift = 1.2, Front = 0, In = 0.4, Out = 0.22 }, -- the odds panel stands Front studs in front (+Z) of the egg (0 = right over it), Lift from the egg centre; it tweens up (In s, Back ease) when the player comes within Show (flat distance, also the hatch reach) and back down (Out s) once they are past Far; Near = it stops growing closer than this (pixel size = studs x px-per-stud / max(distance, Near))
		Title = { Size = Vector2.new(11, 5.6), Near = 20, Lift = 6.8 }, -- the always-on rarity + price sign over the egg (Lift from the egg centre)
		Sign = { Text = "EGG HATCHERY", Z = -88, Width = 22 }, -- the arch over the path where it enters the plaza
	},

	-- Once per egg per session, when Wins first cover its Price: a toast plus the tutorial's arrow beam + marker to its podium, until the
	-- player walks up to it (within Billboard.Show) or can no longer afford it (EggGuideController).
	Guide = { Text = "You can afford the %s! Visit the hatchery.", Kind = "Success", Marker = "HATCH" },

	-- The follower pets (client): they trail their owner in a loose line, bobbing; hidden while the log rolls.
	Follow = {
		Size = 2.6, -- studs tall (the model is scaled to this)
		Spacing = 3.4, Behind = 4.2, Side = 2.6, -- first pet this far behind, the others fan out sideways by Side and back by Spacing
		Lerp = 9, -- follow smoothing (per second)
		Bob = { 0.35, 7 }, -- stud height, speed
		Ground = 3, -- how far down (studs) to raycast for the floor under a pet
		Pop = 0.45, -- seconds a pet takes to grow in / out
		WalkSpeed = 16, -- the owner speed (studs/s) at which a pet counts as fully walking (Move = 1)
		Fly = { Height = 2.4, Bob = { 0.35, 3 }, Lean = 12 }, -- flyers: hover height (studs), bob (studs, speed), forward lean while moving (deg)
		Waddle = { Speed = 9, Amp = 8 }, -- walkers sway side to side while moving (rad/s, degrees)
		Anim = { -- PetRig joint motion per kind: Speed rad/s, Phase offset per side, Amp degrees at rest, MoveAmp extra degrees at full walk
			Ear = { Speed = 5, Phase = 1.2, Amp = 6, MoveAmp = 14 },
			Tail = { Speed = 7, Phase = 0, Amp = 14, MoveAmp = 18 },
			Leg = { Speed = 14, Phase = 0, Amp = 0, MoveAmp = 32 },
			Wing = { Speed = 10, Phase = 0, Amp = 25, MoveAmp = 20 },
		},
	},

	-- Hatch reveal (HatchController, Rock Skipping's click-to-hatch): Shake = {Time, Angle(deg), Count} stages after the click,
	-- then Flash and the pet pop. HideGuis = the ScreenGuis hidden while it plays; Blur = the world blur size; Dim = the black veil.
	Hatch = {
		Size = 0.36, -- egg art height as a share of the screen height (1 egg)
		MultiSize = 0.26, -- several eggs: the largest egg size; many eggs shrink to the biggest grid that fits the screen (Grid)
		Grid = { CellW = 1.65, CellH = 1.7, Width = 0.96, Height = 0.84, Y = 0.45 }, -- one egg's cell (x egg size, with the pet + texts), the share of the screen width / height the grid may use, its centre height
		Drop = 0.45, -- seconds the egg drops in
		Wobble = { Angle = 6, Speed = 3 }, -- the idle sway while waiting for the click (degrees, rad/s)
		Shake = { { 0.35, 10, 3 }, { 0.32, 17, 4 }, { 0.3, 26, 5 } }, -- three stages of rising shake
		Flash = 0.28, Pop = 0.6, Out = 0.3,
		AutoHold = 0.9, -- auto hatching: seconds each "click" waits instead
		HideGuis = { "Hud", "Main", "RunHud" }, Blur = 18, Dim = 0.55,
		PetSize = 1.25, -- the pet art is this much bigger than the egg art
		Confetti = 28,
	},

	Text = {
		Title = "My Pets", Stored = "%d / %d", Equipped = "Equipped: %d / %d",
		Equip = "EQUIP", Unequip = "UNEQUIP", EquipBest = "Equip Best", Delete = "DELETE", Empty = "No pets yet! Hatch an egg behind the spawn.",
		Mult = "+%sx", Pick = "Pick a pet", Hatch = "Hatch", HatchMulti = "Hatch x%d", Cost = "%s Wins", Keys = { "E", "R", "T" },
		Multi = "Multi", Auto = "Auto", AutoOn = "Auto ON", MoreEggs = "+%d Eggs", ClickHatch = "Click to hatch", ClickHatchN = "Click to hatch %d",
		ClickContinue = "Click to continue", Better = "Always %d%% better!",
		Full = "Your pet storage is full!", Poor = "Not enough Wins!",
		NeedRoom = "You need %d free pet slots!", Deleted = "Deleted %s", MaxEquipped = "Unequip a pet first (max %d equipped)",
		Equippedtoast = "Equipped the best pets!", Hint = "[%s] %s", Chance = "%s%%", NeedPass = "Get the +%d Eggs pass to hatch %d at once!",
	},
}

for _, pet in config.Pets do
	if pet.Rank then
		pet.Mult = Economy.PetMult(pet.Rank)
	end
end
for _, egg in config.Eggs do
	if egg.Tier then
		egg.Price = egg.Price or Economy.LogPrice(egg.Tier) -- a Price written on the egg overrides the formula (Common: 70, 2026-10-15)
	end
end

return config
