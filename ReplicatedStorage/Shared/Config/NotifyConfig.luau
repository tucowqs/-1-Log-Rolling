--[[
	NotifyConfig — the one toast system (NotifyController / NotifyService / Emphasis).
	Look (the kit's house design): big white bold rich text, scaled black stroke, no background (the original Studio
	template adds a soft UIShadow).
	Toasts stack from the TOP of the screen, newest on top, growing in (Back) and shrinking out.
	Style rule: only notify what the screen doesn't already show (no "Equipped X", no countdowns already
	visible). Keep: purchase success / not enough cash, banked items, hands full, rare-find announcements.
]]
local rgb = Color3.fromRGB

return {
	Bridges = { "Notify", "Announcement" }, -- (Net registers them)

	Duration = 3, -- seconds a normal toast stays up
	Max = 3, -- non-sticky toasts on screen at once (the oldest are pushed off)
	At = Vector2.new(0.5, 0), -- screen share (x, y) where the stack starts: top-centre
	Top = 35, -- design px from the screen top to the first toast
	Gap = 4, -- design px between toasts
	Grow = 0.35, -- seconds: grow in (Back)
	Shrink = 0.25, -- seconds: shrink out (Back In) + collapse its slot
	Holder = Vector2.new(900, 600), -- design px of the top-centre stack (Fit scales it per device)
	DisplayOrder = 20,

	-- The toast label. Template = path under PlayerGui to a hand-designed TextLabel to clone (e.g.
	-- { "GUI", "Notification", "Template" }; its parent frame is hidden at start), drawn at TemplateScale
	-- (Steal Treasure's was sized for a ~1150 px-tall view: 0.62 maps it onto the 720 px design).
	-- Template = nil builds the same look in code from Label.
	Template = nil,
	TemplateScale = 0.62,
	Label = {
		Size = Vector2.new(820, 58), -- design px
		Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold), -- the UI pack's font
		Color = rgb(255, 255, 255),
		Stroke = 0.06, -- ScaledSize stroke: a fraction of the text size
	},

	-- Emphasis.Em(word, kind): rich-text colour per kind for the important words.
	Emphasis = {
		Success = rgb(120, 255, 130),
		Warning = rgb(255, 180, 60),
		Error = rgb(255, 95, 95),
		Info = rgb(255, 220, 70),
	},
	-- Sound per kind (SoundConfig names).
	Sounds = { Success = "Purchase", Error = "Error", Info = "Click", Warning = "Click", Announcement = "Announcement" },
	-- The big title over a sticky toast ("TUTORIAL:"): Height = share of a toast's height, Width = of its width.
	Header = { Height = 0.5, Width = 0.3, Color = rgb(255, 220, 70) }, -- (1.1 / 0.7 was too big - playtester)
}
