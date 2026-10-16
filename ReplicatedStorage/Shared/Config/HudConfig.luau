--[[
	HudConfig — the game's OWN HUD, built from GameUI pack COMPONENTS (UiPack/Widgets: Square, Wide, Offer, Gift, Chip +
	Parts.StatRow). Layout after +1 Rock Skipping (2026-10-14, Preston: "I want our whole game feel"):

	                 [AUTO ROLL  ONLY R$20]
	 [Shop][Rebirth%]                                   [Starter Pack]
	 [Pets][Trails  ]                                   [+2x SPEED R$5]
	 [Inv ][Gifts ! ]                                   [2x WINS  R$48]
	 [   Worlds     ]
	 (rebirths) 2      [ Speed ............. x8 Multiplier ]   (status chips)
	 (trophy) 100      [ Level 60 ===================== ]
	 Friend Boost +0% [+]  [+5 Levels][+10 Levels][+25 Levels]      <- StarterGui.Main.Bottom (hand-built; HudExtrasController)

	Groups are transparent frames in ScreenGui "Hud" (UiPack.Hud()), sized as a share of screen HEIGHT
	(SizeConstraint RelativeYY) so they keep their shape on every device; Position is screen scale. An
	element's Box (Size / Position) is a share of its group. Celebration targets and Tutorial gates use the
	paths Hud.<Group>.<Name> (UiPackConfig.Targets, TutorialConfig.Gates).
	  HudController        Buttons (every group below; slid away while any menu window is open: HideOnMenu)
	  HudStatsController   Stats (main currencies)
	  HudStatusController  Status (bottom-right timer chips)
	  HudExtrasController  the Rebirth "%" tag, the Friend Boost row, the hand-built bar's multiplier + level products

	Button defs: Name, Widget ("Wide" | "Square" | "Offer" | "Gift"), Text, Color (UiPackConfig palette), Icon, Box, and ONE
	action: Menu (+ Tab = the menu's context) | Buy = a ShopMath key (Shop system).
	  Price    = a ShopMath key whose Robux price fills an Offer / Gift button's price (PriceText formats it)
	  HideWhen = a player attribute that hides the button while true (bought offers, owned passes)
	  Owned    = { Attribute, Event, On, Off }: once that pass attribute is true a click emits the ClientState Event instead of
	             buying, and the label reads On / Off from the player attribute Attribute .. "On" (AutoController's toggles)
	  Badge    = a ClientState event whose count shows on the red "!" bubble
	  Lock     = a key of Locks
]]
local IconPick = require(script.Parent.Parent.Modules.IconPick)
local UiPackConfig = require(script.Parent.UiPackConfig)

local icon = IconPick.Image
local P = UiPackConfig.Icons

local function centred(x: number, y: number, w: number, h: number)
	return { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), AnchorPoint = Vector2.new(0.5, 0.5) }
end

local function at(x: number, y: number, w: number, h: number)
	return { Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h) }
end

return {
	Groups = {
		-- Main menu buttons ALWAYS vertically centred on the LEFT edge (standing rule): AnchorPoint (0, 0.5) at Y 0.5.
		Left = { Size = UDim2.fromScale(0.25, 0.46), Position = UDim2.fromScale(0.012, 0.47), Anchor = Vector2.new(0, 0.5) },
		Right = { Size = UDim2.fromScale(0.21, 0.4), Position = UDim2.fromScale(0.988, 0.45), Anchor = Vector2.new(1, 0.5) },
		Top = { Size = UDim2.fromScale(0.26, 0.075), Position = UDim2.fromScale(0.5, 0.012), Anchor = Vector2.new(0.5, 0) },
		-- Bottom-left: ONLY the main currencies, packed tight.
		Stats = { Size = UDim2.fromScale(0.36, 0.2), Position = UDim2.fromScale(0.012, 0.975), Anchor = Vector2.new(0, 1) },
		-- Bottom-right: status chips (potion timers), right-aligned.
		Status = { Size = UDim2.fromScale(0.52, 0.08), Position = UDim2.fromScale(0.988, 0.975), Anchor = Vector2.new(1, 1) },
	},

	Buttons = {
		Left = {
			{ Name = "Shop", Widget = "Square", Text = "Shop", Color = "Red", Icon = P.Shop, Menu = "Shop", Box = centred(0.25, 0.12, 0.46, 0.235) },
			{ Name = "Rebirth", Widget = "Square", Text = "Rebirth", Color = "Purple", Icon = P.Rebirth, Menu = "Rebirth", Box = centred(0.75, 0.12, 0.46, 0.235) },
			{ Name = "Pets", Widget = "Square", Text = "Pets", Color = "Orange", Icon = P.Paw, Menu = "Pets", Box = centred(0.25, 0.375, 0.46, 0.235) },
			{ Name = "Trails", Widget = "Square", Text = "Trails", Color = "Blue", Icon = icon("Speed"), Menu = "Trails", Box = centred(0.75, 0.375, 0.46, 0.235) },
			{ Name = "Inventory", Widget = "Square", Text = "Items", Color = "Green", Icon = P.Backpack, Menu = "Inventory", Box = centred(0.25, 0.63, 0.46, 0.235) },
			{ Name = "Gifts", Widget = "Square", Text = "Gifts", Color = "Pink", Icon = P.Gift, Menu = "Gifts", Badge = "GiftsReady", Box = centred(0.75, 0.63, 0.46, 0.235) },
			{ Name = "Worlds", Widget = "Wide", Text = "Worlds", Color = "Blue", Icon = P.Arrow, Menu = "Worlds", Box = centred(0.5, 0.875, 0.98, 0.17) },
		},
		Right = {
			{ Name = "StarterPack", Widget = "Gift", Text = "Starter Pack", Icon = P.Gift, Price = "Starter", Buy = "Starter", HideWhen = "StarterBought",
				Box = centred(0.5, 0.2, 0.62, 0.4) },
			{ Name = "Speed2x", Widget = "Offer", Text = "+2x SPEED", Color = "Green", Price = "PassSpeed2x", Buy = "PassSpeed2x", HideWhen = "PassSpeed2x",
				Box = centred(0.5, 0.56, 0.9, 0.2) },
			{ Name = "Wins2x", Widget = "Offer", Text = "2x WINS", Color = "Orange", Price = "PassWins2x", Buy = "PassWins2x", HideWhen = "PassWins2x",
				Box = centred(0.5, 0.82, 0.9, 0.2) },
		},
		Top = {},
	},
	PriceText = "ONLY %s", -- an Offer / Gift button's price line (%s = the Robux price)

	Locks = {},

	-- Bottom-left stats (Speed lives in the bottom bar's MultFrame, SpeedLabelController). Text = UiPackConfig.Text gradient.
	Stats = {
		{ Name = "Rebirths", Attribute = "Rebirths", Icon = P.Rebirth, Text = "Blue", Box = at(0, 0.02, 0.5, 0.3) },
		{ Name = "Wins", Attribute = "Wins", Icon = icon("Trophy"), Text = "Gold", Box = at(0, 0.34, 0.6, 0.36) },
	},
	Cash = nil, -- no separate cash row: Wins is a stat row
	Friend = { Box = at(0.01, 0.74, 0.62, 0.2), Plus = at(0.66, 0.74, 0.1, 0.2) }, -- HudExtrasController: "Friend Boost +N%" + invite "+"

	-- While any menu window is open these groups slide off their edge (standing rule: windows never sit over HUD buttons).
	HideOnMenu = { Groups = { Left = -1, Right = 1 }, Time = 0.22 }, -- group -> direction (-1 off left, 1 off right)
	Count = 0.45, -- seconds: values count to their new number instead of jumping (the first value after load snaps)
	Float = { Rise = 0.035, Time = 1.1, Jitter = 0.5, Tilt = 10, Gap = 8 }, -- "+N" pops RIGHT of the stat row and rises

	-- Bottom-right timer chips (right to left), each shown only while its attribute (a server-time "until" timestamp) is ahead.
	Status = { Gap = 0.02, Refresh = 0.25, Chips = {
		{ Name = "SpeedBoost", Attribute = "SpeedBoostUntil", Icon = icon("Boost"), Text = "x2 %s", Gradient = "Blue", Menu = "Inventory", Size = UDim2.fromScale(0.2, 1) },
		{ Name = "WinsBoost", Attribute = "WinsBoostUntil", Icon = icon("Trophy"), Text = "x2 %s", Gradient = "Gold", Menu = "Inventory", Size = UDim2.fromScale(0.2, 1) },
	} },
}
