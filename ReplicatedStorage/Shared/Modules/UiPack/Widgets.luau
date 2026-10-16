--[[
	UiPack/Widgets — the pack's HUD-sized COMPONENTS. Each clones the smallest pack piece that has the look
	(UiPackConfig.Templates) and restyles it; WHERE it goes is the caller's (HudConfig holds the game's own
	layout). The pack HUD itself is never cloned as a layout.
	Every constructor is Widget(spec, props): spec = content, props = placement (Parent, Name, Size, Position,
	AnchorPoint, LayoutOrder, ...). spec.OnClick makes it a button (UiPack.Clickable).
	  Square({ Color, Icon, Text })            icon square with its 3D name over the bottom edge
	  Wide({ Color, Icon?, Text })             wide skinned button, 3D label, faint icon art behind it
	  Offer({ Color, Text, Price })            rainbow offer button with a 3D price under it
	  Gift({ Icon, Text, Price, Rays? })       the sunburst offer (rays + art, name over, price under)
	  Cash({ Gradient? , OnPlus })             big 3D cash number + the small "+" square
	  Chip({ Icon, Text?, Gradient? })         icon with a small 3D caption over its bottom (timers, events)
	  ValuePill({ Icon })                      dark well: icon, 3D value, 3D timer  (-> pill.Value, pill.Timer)
	  SetLabel(widget, text)                   the 3D label of any widget above
	(StatRow, Badge, Paint, Text live in Parts / Core.)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local Core = require(script.Parent.Core)
local Parts = require(script.Parent.Parts)

local Widgets = {}

local function make(template: string, spec, props): any
	local gui = Parts.Place(Core.Get(template), props)
	if spec.Color then
		Core.Paint(gui, spec.Color)
	end
	if spec.OnClick then
		Core.Clickable(gui, spec.OnClick)
	else
		gui.Active = false
	end
	return gui
end

local function label(gui: Instance): TextLabel
	local container = gui:FindFirstChild("Container")
	return gui:FindFirstChild("Name") or (container and container:FindFirstChild("Name")) or gui:FindFirstChild("Amount")
end

function Widgets.SetLabel(gui: Instance, text: string)
	Core.Text(label(gui), text)
end

local function icon(gui: Instance, image: string?)
	local face = gui:FindFirstChild("Container") or gui
	for _, name in { "Icon", "ImageBg" } do
		local art = face:FindFirstChild(name)
		if art and image then
			art.Image = image
		end
	end
end

-- Strips the square's box (face, rim, lip, shadow, faint art) so only the icon, name and badge remain.
local function bare(gui: any)
	local face = gui.Container
	gui.BackgroundTransparency, face.BackgroundTransparency = 1, 1
	gui.Text = "" -- the TextButton's default "Button" shows through once the box is gone
	for _, name in { "Textures", "Effect", "Inner", "UIGradient", "ImageBg" } do
		face[name]:Destroy()
	end
	gui.Outer:Destroy()
	gui:FindFirstChildOfClass("UIShadow"):Destroy()
end

function Widgets.Square(spec, props)
	local gui = make("SquareButton", spec, props)
	if spec.Bare then -- spec.Bare = just the icon, no box (the shop cards' gift buttons)
		bare(gui)
	end
	icon(gui, spec.Icon)
	Widgets.SetLabel(gui, spec.Text)
	return gui
end

function Widgets.Wide(spec, props)
	local gui = make("WideButton", spec, props)
	gui.Notification:Destroy()
	icon(gui, spec.Icon)
	Widgets.SetLabel(gui, spec.Text)
	return gui
end

function Widgets.Offer(spec, props)
	local gui = make("OfferButton", spec, props)
	Widgets.SetLabel(gui, spec.Text)
	Core.Text(gui.Price, spec.Price)
	return gui
end

function Widgets.Gift(spec, props)
	local gui = make("GiftButton", spec, props)
	gui.Icon.Image = spec.Icon
	if spec.Rays then
		gui.ImageColor3 = spec.Rays
	end
	Widgets.SetLabel(gui, spec.Text)
	Core.Text(gui.Price, spec.Price)
	return gui
end

function Widgets.Cash(spec, props)
	local gui = Parts.Place(Core.Get("CashRow"), props)
	Core.TextGradient(gui.Amount, spec.Gradient or "Green")
	gui.Shop.SizeConstraint, gui.Shop.Size = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(0.8, 0.8) -- square, row-height
	Core.Clickable(gui.Shop, spec.OnPlus)
	return gui
end

function Widgets.Chip(spec, props)
	local gui = make("Chip", spec, props)
	gui.Icon.Image = spec.Icon
	Core.Text(gui.Amount, spec.Text or "")
	if spec.Gradient then
		Core.TextGradient(gui.Amount, spec.Gradient)
	end
	return gui
end

-- A pack well (the Rebirth requirements bar, fill removed) carrying an icon, a value and a timer.
function Widgets.ValuePill(spec, props)
	local gui = Parts.Place(Core.Get("Bar"), props)
	gui.Progress:Destroy()
	Ui.Make("ImageLabel", { Name = "Icon", Image = spec.Icon, BackgroundTransparency = 1, Size = UDim2.fromScale(0.2, 1.3),
		Position = UDim2.fromScale(0.02, 0.5), AnchorPoint = Vector2.new(0, 0.5), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = gui })
	for name, box in { Value = { 0.24, 0.42, 0.95 }, Timer = { 0.68, 0.3, 0.7 } } do
		local text = Core.Get("StatText")
		text.Name, text.Size, text.Position, text.AnchorPoint = name, UDim2.fromScale(box[2], box[3]), UDim2.fromScale(box[1], 0.5), Vector2.new(0, 0.5)
		text.Parent = gui
	end
	return gui
end

return Widgets
