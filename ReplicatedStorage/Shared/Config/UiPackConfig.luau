--[[
	UiPackConfig — the GameUI pack as the look of EVERY screen (docs/UI_PACK.md). GameUI is the kit author's own
	UI pack, shipped with the kit by permission.
	The pack's real instances live in ReplicatedStorage[Root] (rebuilt from assets/ui/GameUI.json by
	tools/ui_import.lua; the first tools/push.js push installs it); Shared/Modules/UiPack clones them by the
	Templates paths below and recolours them with the Colors palettes (all sampled from the pack itself).

	Colors: { Top, Bottom (face gradient), Lip (the button's own background = the darker base), Outer (ink
	stroke), Shadow (UIShadow glow), Stops (multi-stop gradient instead of Top/Bottom), Rotation }.
	Text: gradients for the top layer of a pack 3D label (UiPack.TextGradient).
	Menus: Source = the pack window cloned for the shell (Main.<Source>), Color = header palette,
	Title, Icon, Tabs = a rarity-style tab column on the right (cloned from Main.Index.Buttons).
]]
local rgb = Color3.fromRGB

local PACK = "rbxassetid://"
local ICONS = {
	Shop = PACK .. "120193355846545", Pass = PACK .. "101290675044650", Rebirth = PACK .. "121755902488154",
	Index = PACK .. "129030873600192", Daily = PACK .. "78232029614793", Upgrades = PACK .. "107595170905450",
	Cash = PACK .. "82091418744362", Clover = PACK .. "129696763827427", Gift = PACK .. "122857906055586",
	Crate = PACK .. "136342823476293", Arrow = PACK .. "126528937891812", Verified = PACK .. "138081334422366",
	LuckyBlock = PACK .. "83377644326374", Check = PACK .. "139529464530005", Clock = PACK .. "78072213686354",
	Backpack = PACK .. "70904786570214", Ticket = PACK .. "130316231507000", Rays = PACK .. "98508264222687",
	Gear = "rbxassetid://103412063811268", -- IconPicksConfig Settings (the pack has no gear)
	Paw = "rbxassetid://100127205971263", -- the UIConfig star until the Paw upload (IconPicksConfig) is shared with the group
}

return {
	Root = "UiPack", -- ReplicatedStorage child (a ScreenGui holding HUD + Main: components to clone, never a layout)
	Robux = utf8.char(0xE002), -- the Robux glyph the pack prefixes prices with
	Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
	Ink = rgb(25, 25, 25),

	-- Pack pieces by role (paths under Root). UiPack.Get(name) clones one.
	Templates = {
		-- HUD components (UiPack/Widgets). Smallest pieces only: the pack HUD is NOT a layout to fill.
		Window = "Main.Shop",
		TabColumn = "Main.Index.Buttons",
		Tab = "Main.Index.Buttons.Container.Common",
		Badge = "HUD.Left.Daily.Notification",
		WideButton = "HUD.Left.Daily", -- skinned wide button, 3D left label, faint art
		SquareButton = "HUD.Left.Index", -- icon square with a 3D name over its bottom edge
		OfferButton = "HUD.Right.X2Money", -- rainbow offer button with a 3D price under it
		GiftButton = "HUD.Right.StarterPack", -- sunburst rays + art, name over, price under
		CashRow = "HUD.BottomLeft.CashFrame", -- big 3D number + small "+" square
		StatRow = "HUD.BottomLeft.RebirthFrame", -- icon + 3D gradient number
		StatText = "HUD.BottomLeft.RebirthFrame.Amount", -- a bare pack 3D label
		Chip = "HUD.BottomRight.CashBoost", -- icon with a small 3D caption over its bottom
		Bar = "Main.Rebirth.Main.Middle.Bar", -- dark progress bar with a Progress fill
		RunBar = "HUD.Bottom.BarFrame.Bar", -- the HUD level bar: Effect is the fill, Level / XP are the left / centre labels
		BigButton = "Main.Rebirth.Main.Bottom.Rebirth.Btn", -- chunky 3D-text button (Rebirth / Skip)
		PriceButton = "Main.Shop.Scrolling.X2Money.Button.Buy", -- green Robux price button
		Pill = "Main.Daily.Main.2.Claim", -- CLAIM / CLAIMED / LOCKED pill
		DayCard = "Main.Daily.Main.2",
		BigDayCard = "Main.Daily.Main.7",
		Cell = "Main.Index.Main.Scrolling.Item",
		Row = "Main.Upgrades.Scrolling.Template",
		Card = {
			Offer = "Main.Shop.Scrolling.ExclusiveOffer", -- rainbow card: art, odds row, two price buttons
			Starter = "Main.Shop.Scrolling.StarterPack", -- art + item frames + VALUE + price w/ old price
			Wide = "Main.Shop.Scrolling.ServerLuck", -- art, x1 -> x2 row, description, price
			Half = "Main.Shop.Scrolling.X2Money", -- half-width: art, title, description, price
			Pack = "Main.Shop.Scrolling.X2Money", -- the cash tile (ShopCards re-lays the X2Money card out)
		},
	},

	Colors = {
		Green = { Top = rgb(255, 255, 0), Bottom = rgb(21, 255, 0), Lip = rgb(7, 138, 0), Outer = rgb(27, 39, 0), Shadow = rgb(170, 255, 127) },
		Red = { Top = rgb(255, 0, 140), Bottom = rgb(255, 0, 4), Lip = rgb(138, 0, 0), Outer = rgb(39, 0, 6), Shadow = rgb(255, 85, 127) },
		Pink = { Top = rgb(255, 114, 199), Bottom = rgb(255, 0, 4), Lip = rgb(121, 3, 7), Outer = rgb(25, 25, 25), Shadow = rgb(255, 85, 127) },
		Orange = { Top = rgb(255, 234, 0), Bottom = rgb(255, 106, 0), Lip = rgb(166, 83, 0), Outer = rgb(39, 34, 0), Shadow = rgb(255, 255, 127) },
		Purple = { Top = rgb(234, 0, 255), Bottom = rgb(106, 0, 255), Lip = rgb(99, 0, 138), Outer = rgb(21, 0, 39), Shadow = rgb(255, 170, 255) },
		Blue = { Top = rgb(144, 235, 253), Bottom = rgb(7, 126, 254), Lip = rgb(0, 71, 138), Outer = rgb(0, 39, 38), Shadow = rgb(170, 255, 255) },
		Gray = { Top = rgb(190, 190, 190), Bottom = rgb(75, 75, 75), Lip = rgb(63, 63, 63), Outer = rgb(25, 25, 25), Shadow = rgb(200, 200, 200) },
		Silver = { Top = rgb(253, 253, 253), Bottom = rgb(136, 136, 136), Lip = rgb(25, 25, 25), Outer = rgb(39, 34, 0), Shadow = rgb(255, 255, 255) },
		Dark = { Top = rgb(138, 138, 138), Bottom = rgb(49, 49, 49), Lip = rgb(25, 25, 25), Outer = rgb(39, 34, 0), Shadow = rgb(255, 255, 255) },
		Rainbow = { Stops = { rgb(234, 0, 255), rgb(255, 0, 140), rgb(255, 234, 0), rgb(0, 238, 255), rgb(234, 0, 255) }, Rotation = -160,
			Lip = rgb(25, 25, 25), Outer = rgb(39, 34, 0), Shadow = rgb(255, 85, 255) },
	},
	Text = {
		Green = { rgb(255, 255, 0), rgb(21, 255, 0) },
		Pink = { rgb(255, 114, 199), rgb(255, 0, 4) },
		Orange = { rgb(255, 234, 0), rgb(255, 106, 0) },
		Blue = { rgb(144, 235, 253), rgb(7, 126, 254) },
		LightBlue = { rgb(225, 248, 255), rgb(120, 205, 255) },
		Purple = { rgb(234, 0, 255), rgb(106, 0, 255) },
		Gold = { rgb(255, 249, 165), rgb(255, 151, 2) },
		White = { rgb(255, 255, 255), rgb(255, 255, 255) },
		Red = { rgb(255, 120, 120), rgb(255, 20, 20) },
	},

	-- The pack's own art (glossy icons) by meaning; game icons stay in IconPicksConfig.
	Icons = ICONS,

	Windows = {
		Order = 10, -- DisplayOrder of the shared "Windows" ScreenGui
		-- Phones: a viewport shorter than CompactHeight px grows every window by Compact (pack windows are
		-- sized in screen fractions, so they would get tiny on an 844x390 landscape phone).
		CompactHeight = 520,
		Compact = 1.32,
		TabWidth = 0.277, -- tab column width as a share of a 1.48-aspect window (the pack's Index)
		TabHeight = 0.133, TabGap = 0.03, -- tab button height / gap (share of the column); many tabs shrink
		Open = { From = 0.65, Time = 0.38, IconFrom = -38, IconTime = 0.55 },
		Close = { To = 0.55, Time = 0.16 },
	},

	-- Item art (UiPack/Art): ViewportFrame model piles / an icon on the pack's sunburst rays.
	Art = {
		Assets = "Assets", -- model paths are under ReplicatedStorage[Assets]
		TintSkip = "^Face",
		Fov = 30, Pitch = 14,
		Turn = 0.6, Swing = { 28, 1.6 }, -- radians/s; swing degrees, speed
		Bob = { 0.03, 1.6 }, -- share of the art's height, seconds per cycle
		RaysTransparency = 0.35, RaysSpin = 14, -- seconds per turn
	},

	-- Preloading (standing rule: nothing pops in when a window opens). Once the save has loaded ("Loaded"),
	-- UiPreloadController runs ContentProvider:PreloadAsync on these ReplicatedStorage children (pack images,
	-- model meshes); an Index view pre-builds its viewports PerFrame cells a frame (IndexView:Prebuild).
	Preload = { Roots = { "UiPack" }, PerFrame = 3 }, -- (the Blender models are EditableMeshes built by AssetLibrary)

	-- Purchase / claim celebration (UiPack/Celebrate).
	Celebrate = {
		Confetti = 70, ConfettiTime = 2.6, Gravity = 900, Speed = { 350, 820 }, Colors = {
			rgb(255, 80, 80), rgb(255, 200, 40), rgb(90, 220, 90), rgb(70, 170, 255), rgb(200, 100, 255), rgb(255, 130, 200),
		},
		Flyers = 10, FlyerSize = 64, Spread = 150, FlyTime = 0.7, Hold = 0.3, BurstSize = 520, BurstTime = 1,
	},

	-- Every menu window: Source = Main.<Source> cloned as the shell; Color = header palette; Extra = the
	-- header button kept (ClaimAll / PremiumPass / Restock; the others are removed); Tabs = a tab column.
	-- Every window's BODY is centred on screen; a tab column hangs off its right (UiPack/Window:Center).
	-- One size family (standing rule): every big window is 0.6 of the screen height like Shop / Index / Daily;
	-- give a Source with another size an explicit Size (Lift raises it), never a tiny odd-one-out window.
	Menus = {
		Shop = { Source = "Shop", Color = "Red", Title = "Shop", Icon = ICONS.Shop }, -- one scroll of sections, no side buttons
		-- the one-time offer popup (Shop system, ShopConfig.Ui.OfferMenu): one shop card in a small window
		ShopOffer = { Source = "Shop", Color = "Purple", Title = "Special Offer!", Icon = ICONS.Gift, Size = UDim2.fromScale(0.5, 0.42), Aspect = 2.2 },
		Rewards = { Source = "Daily", Color = "Blue", Title = "Daily Rewards", Icon = ICONS.Daily, Extra = "ClaimAll", Tabs = true },
		Rebirth = { Source = "Rebirth", Color = "Purple", Title = "Rebirth", Icon = ICONS.Rebirth, Size = UDim2.fromScale(0.5, 0.6), Lift = 0.04 }, -- Lift = share of the screen height the window sits above centre
		-- PackViews a game can use for its own systems (RebirthView / IndexView / UpgradesView):
		Index = { Source = "Index", Color = "Blue", Title = "Index", Icon = ICONS.Index, Tabs = true },
		Upgrades = { Source = "Upgrades", Color = "Green", Title = "Upgrades", Icon = ICONS.Upgrades },
		-- LogRoll pets: the Shop shell, its scroll replaced by the pet card + grid (PackViews/PetsView)
		Pets = { Source = "Shop", Color = "Blue", Title = "My Pets", Icon = ICONS.Paw, Aspect = 1.62 },
		Settings = { Source = "Upgrades", Color = "Blue", Title = "Settings", Icon = ICONS.Gear },
		-- Rock Skipping systems (2026-10-14): list windows on the Upgrades shell (PackViews/ListView), Worlds on the Shop scroll
		GiftPick = { Source = "Upgrades", Color = "Purple", Title = "Gift To...", Icon = ICONS.Gift },
		Inventory = { Source = "Upgrades", Color = "Green", Title = "Items", Icon = ICONS.Backpack },
		Trails = { Source = "Upgrades", Color = "Blue", Title = "Trails", Icon = ICONS.Arrow },
		Gifts = { Source = "Upgrades", Color = "Pink", Title = "Free Gifts", Icon = ICONS.Gift },
		Worlds = { Source = "Shop", Color = "Blue", Title = "Worlds", Icon = ICONS.Arrow },
		-- LogRoll: the run result (the Rebirth shell). Logs are bought on the pedestals near spawn (LogPadService).
	},

	-- HUD guis a purchase / claim celebration flies into, by kind (paths under PlayerGui: the Hud system's
	-- groups, HudConfig: Hud.<Group>.<Name>). Shop cards and reward kinds name these in their Fly. A missing
	-- target = the icons float and fade.
	Targets = {
		Wins = { "Hud", "Stats", "Wins" },
		Rebirths = { "Hud", "Stats", "Rebirths" },
	},

	Badge = { Size = 0.3, At = Vector2.new(0.92, 0.06) }, -- the "!" bubble on square buttons / tabs (share, centre)
	Dim = 0.45, -- black overlay on unselected tabs / claimed cards
	Pulse = { 1.07, 0.55 }, -- ready pills / badges: scale, seconds
}
