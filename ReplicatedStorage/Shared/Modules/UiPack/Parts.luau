--[[
	UiPack/Parts — constructors for the pack's reusable pieces (UiPackConfig.Templates). Each returns a fresh
	clone, placed with props ({ Parent, Size, Position, AnchorPoint, LayoutOrder, Name, ZIndex, Visible })
	BEFORE it is made clickable (so buttons inside list layouts get their hover slot).
	  Button(kind, text, fn?, props)        chunky 3D-text button (pack Rebirth / Skip)
	  PriceButton(kind, text, fn?, props)   price button (pack shop Buy); Robux(n) -> "<glyph>n"
	  SetText(button, text)                 the label of any pack button (its Price, else Text, else text)
	  Pill(kind, text, fn?, props) / SetPill(pill, kind, text)   the day-card CLAIM / CLAIMED / LOCKED pill
	  StatRow(image, textKind, props)       HUD icon + 3D gradient number (pack RebirthFrame)
	  Bar(props) / SetBar(bar, share)       dark progress bar with the orange fill (pack Rebirth requirements)
	  Card(kind, props)                     shop cards: "Offer" | "Starter" | "Wide" | "Half"
	  DayCard(big, props) / Cell(props) / Row(props)   day card, index cell, upgrade row (raw clones)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Core = require(script.Parent.Core)

local Parts = {}

function Parts.Place(gui: any, props)
	for key, value in props or {} do
		if key ~= "Parent" then
			gui[key] = value
		end
	end
	gui.Parent = props and props.Parent
	return gui
end

function Parts.Robux(amount: number | string): string
	return Config.Robux .. tostring(amount)
end

function Parts.SetText(button: GuiObject, text: string)
	local face = Core.Face(button)
	local label = face:FindFirstChild("Price") or face:FindFirstChild("Text") or face:FindFirstChild("text")
	if label:FindFirstChild("Color") then
		Core.Text(label, text)
	else
		label.Text = text
	end
end

local function button(template: string, kind: string, text: string, fn, props)
	local gui = Parts.Place(Core.Get(template), props)
	Core.Paint(gui, kind)
	Parts.SetText(gui, text)
	if fn then
		Core.Clickable(gui, fn)
	end
	return gui
end

function Parts.Button(kind: string, text: string, fn, props)
	return button("BigButton", kind, text, fn, props)
end

function Parts.PriceButton(kind: string, text: string, fn, props)
	return button("PriceButton", kind, text, fn, props)
end

function Parts.Pill(kind: string, text: string, fn, props)
	return button("Pill", kind, text, fn, props)
end

function Parts.SetPill(pill: GuiObject, kind: string, text: string)
	if pill:GetAttribute("Paint") ~= kind then
		Core.Paint(pill, kind)
	end
	Parts.SetText(pill, text)
end

function Parts.StatRow(image: string, textKind: string?, props)
	local row = Parts.Place(Core.Get("StatRow"), props)
	row.Icon.Image = image
	Core.TextGradient(row.Amount, textKind)
	return row
end

function Parts.Bar(props)
	return Parts.Place(Core.Get("Bar"), props)
end

function Parts.SetBar(bar: Frame, share: number)
	bar.Progress.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
end

function Parts.Card(kind: string, props)
	return Parts.Place(Core.Get("Card." .. kind), props)
end

function Parts.DayCard(big: boolean, props)
	return Parts.Place(Core.Get(if big then "BigDayCard" else "DayCard"), props)
end

function Parts.Cell(props)
	return Parts.Place(Core.Get("Cell"), props)
end

function Parts.Row(props)
	return Parts.Place(Core.Get("Row"), props)
end

return Parts
