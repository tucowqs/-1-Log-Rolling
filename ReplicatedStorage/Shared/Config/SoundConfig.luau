--[[
	SoundConfig — every sound effect by name (Creator Store audio, picked by title; swap any id freely).
	SoundController plays these; an empty id is silent. Volume = master x each sound's own Volume.
	NotifyController plays Success -> Purchase, Error -> Error, Info/Warning -> Click,
	Announcement -> Announcement; UiKit buttons play Click (Ui.OnClick).
]]
return {
	Volume = 0.6,
	Sounds = {
		Click = { Id = "rbxassetid://17779566040", Volume = 0.4 },
		Purchase = { Id = "rbxassetid://134810204798705", Volume = 0.6 }, -- cash register
		Error = { Id = "rbxassetid://115538192371692", Volume = 0.35 },
		Announcement = { Id = "rbxassetid://4612374495", Volume = 0.6 }, -- simple "bling" (a long victory jingle was too much)
		Pickup = { Id = "rbxassetid://4612374393", Volume = 0.6 }, -- bling
		Safe = { Id = "rbxassetid://103516326607012", Volume = 0.6 }, -- achievement bell
		Alert = { Id = "rbxassetid://140672733714900", Volume = 0.9 }, -- "Spotted"
		Hit = { Id = "rbxassetid://112534219704486", Volume = 0.8 }, -- heavy hit
		-- Pro Sound Effects "Bubble Bloop High Pitched Cute 1": item received / placed. Recorded quiet, so boosted.
		Received = { Id = "rbxassetid://9112751536", Volume = 3 },
		Open = { Id = "rbxassetid://116841971399984", Volume = 0.8 }, -- chest opening
		RareOpen = { Id = "rbxassetid://1840076509", Volume = 1 }, -- APM "Through the Roof" sting
		Legendary = { Id = "rbxassetid://77566342592571", Volume = 0.5 }, -- "magical UI" chime (gentle on purpose)
		Mythic = { Id = "rbxassetid://96371406627429", Volume = 0.5 }, -- "Nice Prize"
		Secret = { Id = "rbxassetid://116748378864976", Volume = 0.5 }, -- "magic"
		Unlock = { Id = "rbxassetid://3406813517", Volume = 0.8 }, -- "Power_Up"
		Income = { Id = "rbxassetid://128506762153961", Volume = 0.06 }, -- faint cha-ching (0.18 was too loud)
		Gain = { Id = "rbxassetid://4612374393", Volume = 0.22, Pitch = 1.6 }, -- small repeated gain tick
		Charge = { Id = "rbxassetid://136823772920703", Volume = 0.8 },
		Shake = { Id = "rbxassetid://119461042040425", Volume = 0.35 },
		Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.5 },
		Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5 },
		Siren = { Id = "rbxassetid://3165700530", Volume = 1 }, -- alarm
		Tick = { Id = "rbxassetid://117751546358455", Volume = 0.9 }, -- countdown beep
		EventStart = { Id = "rbxassetid://1839881844", Volume = 0.9 }, -- APM "Spinning Around (b)": fun 2 s sting
		Thunder = { Id = "rbxassetid://9126099928", Volume = 0.8 },
		-- LogRoll stubs (BalanceConfig.SoundNames): placeholder ids from the catalog, swap each for real audio here.
		Impact = { Id = "rbxassetid://112534219704486", Volume = 0.7, Pitch = 0.8 }, -- bump thud (TODO real wood thud)
		RampHit = { Id = "rbxassetid://79833203443837", Volume = 0.9 }, -- ramp launch
		SuperHit = { Id = "rbxassetid://119573908217733", Volume = 1 }, -- super ramp launch
		HyperHit = { Id = "rbxassetid://119573908217733", Volume = 1.3, Pitch = 0.75 }, -- hyper ramp launch (the super sound, lower and louder; TODO real sound)
		Boost = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.45, Pitch = 1.3 }, -- speed boost whoosh (TODO)
		Break = { Id = "rbxassetid://116841971399984", Volume = 1 }, -- the log breaks (TODO real wood crack)
		LevelUp = { Id = "rbxassetid://77566342592571", Volume = 0.7 }, -- level-up chime (TODO)
		Lift = { Id = "rbxassetid://119461042040425", Volume = 0.5, Pitch = 0.9 }, -- weight rep (TODO)
	},
	MaxLifetime = 10, -- seconds: a sound that never fires Ended is destroyed after this
}
