--[[
	UIConfig — the look of every screen (UiKit): a chunky, glossy theme copied from the Studs UI
	Pack. Screens are laid out at Design size in pixels and each top-level container is scaled to
	the viewport with its own "Fit" UIScale (UiCore.Fit), so proportions match on phones, PCs and TVs.
	Swap Fonts / Skins / Colors / Icons per game; the numbers below are the proven Steal Treasure ones.
]]
local rgb = Color3.fromRGB

return {
	Design = Vector2.new(1280, 720),
	MinScale = 0.62,
	MaxScale = 1.6,

	-- The GameUI pack's font (GothamSSm ExtraBold, UiPackConfig.Font) for everything still built with the kit
	-- (world signs, billboards, leaderboards, tutorial marker) so it matches the pack screens.
	Fonts = {
		Title = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
		Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
	},

	Texture = "rbxassetid://70699239093270", -- pack's tiled stud overlay on every face
	TextureTile = UDim2.fromOffset(46, 46),
	TextureTransparency = 0.33,
	Sunburst = "rbxassetid://98508264222687", -- pack's rays behind item icons
	SunburstSpin = 12, -- seconds per turn

	Corner = 8,
	Stroke = 3, -- ink outline round every face
	Rim = 3, -- white inner rim
	RimTransparency = 0.4,
	Lip = 5, -- darker bottom edge under a face (the "3D" button base)
	TextStroke = 2.5, -- outline on big text; smaller text gets thinner (TextStrokeRatio x size, min TextStrokeMin)
	TextStrokeRatio = 0.09,
	TextStrokeMin = 1.5,
	TextStrokeColor = rgb(0, 0, 0),
	WellTransparency = 0.28, -- dark see-through window bodies
	CellTransparency = 0.72,

	-- Named colours: text/tints. Faces with a pack gradient use Skins below; any other
	-- Color3 gets a derived gradient (lighter top -> colour, darker lip).
	Colors = {
		Text = rgb(255, 255, 255),
		SubText = rgb(215, 235, 255),
		Outline = rgb(25, 25, 25),
		Panel = rgb(60, 140, 235),
		PanelDark = rgb(30, 70, 160),
		Cash = rgb(110, 240, 90),
		Accent = rgb(255, 205, 45),
		Danger = rgb(255, 70, 60),
		Green = rgb(85, 215, 70),
		Blue = rgb(60, 150, 255),
		Red = rgb(245, 70, 70),
		Yellow = rgb(255, 200, 40),
		Orange = rgb(255, 145, 40),
		Purple = rgb(160, 90, 255),
		Pink = rgb(255, 110, 190),
		Gray = rgb(120, 135, 160),
		Good = rgb(85, 215, 70),
		Bad = rgb(245, 70, 70),
		Neutral = rgb(60, 150, 255),
	},

	-- The pack's own face gradients { Top, Bottom, Lip }.
	Skins = {
		Green = { rgb(255, 255, 0), rgb(21, 255, 0), rgb(7, 138, 0) },
		Blue = { rgb(144, 235, 253), rgb(7, 126, 254), rgb(0, 71, 138) },
		Red = { rgb(255, 0, 140), rgb(255, 0, 4), rgb(138, 0, 0) },
		Pink = { rgb(255, 114, 199), rgb(255, 0, 4), rgb(121, 3, 7) },
		Yellow = { rgb(255, 234, 0), rgb(255, 106, 0), rgb(166, 83, 0) },
		Orange = { rgb(255, 190, 40), rgb(255, 80, 0), rgb(150, 50, 0) },
		Purple = { rgb(234, 0, 255), rgb(106, 0, 255), rgb(99, 0, 138) },
		Silver = { rgb(255, 255, 255), rgb(178, 186, 200), rgb(98, 106, 122) },
		Gray = { rgb(190, 190, 190), rgb(75, 75, 75), rgb(63, 63, 63) },
	},

	-- Vector icon pack images (the Studs UI Pack's "<Name> Outline 256" uploads on the kit author's account).
	-- Ui.Icon(parent, "Gear", props). Add a game's own icons here.
	Icons = {
		ArrowDown = "rbxassetid://98090053078288",
		ArrowUp = "rbxassetid://79194705268624",
		Backpack = "rbxassetid://98286148870880",
		Book = "rbxassetid://75194686905082",
		Cash = "rbxassetid://72514911084191",
		CheckMark = "rbxassetid://140179626493172",
		Chest = "rbxassetid://113150618959067",
		CoinStack = "rbxassetid://94560964793601",
		Dice = "rbxassetid://92668223748590",
		DoorOpen = "rbxassetid://139283651495518",
		Eye = "rbxassetid://103902775015556",
		Gear = "rbxassetid://95985042841987",
		Lightning = "rbxassetid://126028860542576",
		LocationPin = "rbxassetid://80929401761813",
		MessageBox = "rbxassetid://136337887227158",
		Music = "rbxassetid://112361285300191",
		PalmTree = "rbxassetid://102885345866214",
		Play = "rbxassetid://117504637389790",
		PointingHand = "rbxassetid://117070362914321",
		QuestionMark = "rbxassetid://123986932331093",
		SharkTooth = "rbxassetid://94862888938279",
		SkipForward = "rbxassetid://92135551065999",
		Sparkle = "rbxassetid://88618176549768",
		Speed = "rbxassetid://83910641728304",
		Star = "rbxassetid://100127205971263",
		Swim = "rbxassetid://127133901379770",
		Trash = "rbxassetid://115006351515592",
		Trophy = "rbxassetid://109773839688014",
		Unlock = "rbxassetid://93470439069510",
		Upgrade = "rbxassetid://123552425252926",
		Warning = "rbxassetid://97496968536597",
		Water = "rbxassetid://129247146861559",
		X = "rbxassetid://126334603223225",
	},

	-- Menu windows (design px). Kept <= 780 wide so a centred window clears the HUD menu buttons.
	Window = {
		TitleHeight = 88,
		CenterX = 0.57, -- screen width fraction; right of centre so windows clear left-side HUD buttons
		CenterY = 0.56, -- screen height fraction; low enough that title icons clear the top-left stats
		IconSize = 118,
		TitleTextSize = 54,
		Sizes = { -- Ui.WindowSizes.Large etc.; add a game's named windows here
			Large = Vector2.new(780, 540),
			Tall = Vector2.new(780, 560),
			Small = Vector2.new(580, 350),
		},
	},

	Tween = { Pop = 0.12, Slide = 0.28, Bounce = 0.35 },
	-- Every button's feel (Ui.Feel): grows on hover, pushes down while held, springs back on release.
	ButtonFeel = { Hover = 1.08, Press = 0.92 },

	-- UiMotion: window open/close, grid stagger, idle sway/pulse.
	Motion = {
		Open = 0.38, OpenFrom = 0.65, Close = 0.16, CloseTo = 0.55,
		IconWobble = 0.55, IconWobbleFrom = -38,
		-- Grid cells grow into place one after another (Ui.Stagger); after StaggerMax cells they
		-- all go together, so long lists still finish quickly.
		Stagger = 0.03, StaggerMax = 24, StaggerTime = 0.42,
		SwayAngle = 5, SwayPeriod = 1.7,
		PulseScale = 1.15, PulsePeriod = 0.55,
		Count = 0.45, -- number count-up (HUD cash)
	},

	-- Rarity look (RarityText, RevealLabel; Notify's Emphasis.Colors takes a Gradient for rich text).
	-- Gradient stops run left -> right (top -> bottom when not shimmering); Shimmer = the gradient
	-- slides along the text (RarityShimmerController, Speed below). Keep a game's rarity NAMES here;
	-- its odds live in its own config.
	Rarities = {
		Common = { Color = rgb(170, 170, 170), Gradient = { rgb(235, 235, 235), rgb(150, 150, 150) } },
		Uncommon = { Color = rgb(80, 220, 90), Gradient = { rgb(190, 255, 120), rgb(40, 195, 70) } },
		Rare = { Color = rgb(60, 140, 255), Gradient = { rgb(140, 225, 255), rgb(30, 110, 255) } },
		Epic = { Color = rgb(170, 80, 255), Gradient = { rgb(245, 150, 255), rgb(135, 45, 255) } },
		Legendary = { Color = rgb(255, 190, 40), Shimmer = true,
			Gradient = { rgb(255, 170, 20), rgb(255, 240, 120), rgb(255, 255, 230), rgb(255, 240, 120), rgb(255, 170, 20) } },
		Mythic = { Color = rgb(255, 50, 60), Shimmer = true,
			Gradient = { rgb(255, 40, 70), rgb(255, 120, 190), rgb(255, 150, 60), rgb(255, 40, 70) } },
		Secret = { Color = rgb(255, 255, 255), Shimmer = true,
			Gradient = { rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 255, 120), rgb(60, 200, 255), rgb(190, 90, 255), rgb(255, 80, 80) } },
		Divine = { Color = rgb(255, 236, 160), Shimmer = true,
			Gradient = { rgb(255, 255, 255), rgb(255, 226, 120), rgb(255, 255, 255), rgb(140, 230, 255), rgb(255, 255, 255) } },
	},
	RarityShimmer = { Speed = 0.45 }, -- gradient passes per second / 2

	-- RevealLabel: studs; Lines = default height share of each line by number (last one repeats).
	RevealLabel = { Size = Vector2.new(10, 3.4), Lift = 1.4, MaxDistance = 150, Lines = { 0.55, 0.5, 0.4 } },

	-- Every SurfaceGui text gets a semi-thick stroke that scales with the text (SurfaceTextController).
	SurfaceText = { Stroke = 0.08 },

	-- StudTilesController: keeps a UI pack's tiled studs square on the hand-made ScreenGui `Gui`
	-- (StarterGui copy in PlayerGui), for tiled images inside folders named `Folder`. Gui = nil: off.
	StudTiles = { Gui = nil, Folder = "Textures" },

	-- World billboards (WorldLabel.Apply(gui, UIConfig.WorldLabels.Sign)): Size in studs, so they shrink
	-- with distance like a real sign; closer than Near (studs) they stop growing.
	WorldLabels = {
		Sign = { Size = Vector2.new(16, 3), Near = 30 }, -- owner / plot name sign
		Label = { Size = Vector2.new(12, 1.8), Near = 25 },
		Price = { Size = Vector2.new(6, 1.4), Near = 18 }, -- "Unlock $75K" over a locked spot
		Beacon = { Size = Vector2.new(60, 14), Near = 120 }, -- a far-off landmark
		Item = { Size = Vector2.new(7, 2.7), Near = 18 }, -- label over a displayed item
	},
}
