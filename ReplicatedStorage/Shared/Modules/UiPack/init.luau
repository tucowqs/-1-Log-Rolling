--[[
	UiPack — every screen is built from the GameUI pack's REAL instances (cloned from
	ReplicatedStorage.UiPack, which tools/ui_import.lua rebuilds from assets/ui/GameUI.json), never re-drawn in
	code. Look knobs: UiPackConfig. Component catalogue + style tokens: docs/UI_PACK.md.

	UiPack.X is the whole kit (falls through Core -> Parts):
	  Core     Get, Screen, Hud, Text, TextGradient, Face, Paint, Clickable, Badge, Dim
	  Widgets  Square, Wide, Offer, Gift, Cash, Chip, ValuePill, SetLabel (HUD components; layout = HudConfig)
	  Parts    Button, PriceButton, Robux, SetText, Pill, SetPill, StatRow, Bar, SetBar, Card, DayCard, Cell, Row, Place
	  UiPack.Window(name, opts)  a menu window shell (UiPack/Window)
	  UiPack.Art                 viewport / icon item art (UiPack/Art)
	  UiPack.Celebrate           purchase / claim celebration (UiPack/Celebrate)
]]
local Core = require(script.Core)
local Parts = require(script.Parts)
local Window = require(script.Window)
local Widgets = require(script.Widgets)

local UiPack = setmetatable({}, { __index = function(_, key)
	return Core[key] or Parts[key] or Widgets[key]
end })

UiPack.Art = require(script.Art)
UiPack.Celebrate = require(script.Celebrate)

function UiPack.Window(name: string, opts)
	return Window.new(name, opts or {})
end

return UiPack
