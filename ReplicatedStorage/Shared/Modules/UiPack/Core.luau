--[[
	UiPack/Core — the plumbing every pack-built screen uses (look: UiPackConfig; catalogue: docs/UI_PACK.md):
	  Get(name) -> clone            a pack piece by UiPackConfig.Templates key ("PriceButton", "Card.Offer")
	                                or a raw path under ReplicatedStorage[Root] ("Main.Daily.Main.7")
	  Screen(name, order, parent?)  a ScreenGui with the pack's screen settings (inset, insets, sibling Z)
	  Hud() -> ScreenGui            the one HUD ScreenGui "Hud" (empty: HudController lays our own HUD in it)
	  Text(label, text)             a pack 3D label: the dark base + its white "Color" top layer
	  TextGradient(label, kind?)    the top layer's gradient (UiPackConfig.Text), nil = plain white
	  Face(gui) / Paint(gui, kind)  recolour a skinned piece (face gradient, lip, ink stroke, glow, rim)
	  Clickable(button, fn)         Active + the kit button feel + click sound; inside a UIListLayout the
	                                button is moved into a same-size "slot" so the hover grow never reflows
	  Badge(gui) -> badge           the pack's red "!" bubble (badge["!"] is its label)
	  Dim(gui, on)                  black overlay (unselected tabs, claimed cards)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local Core = {}

function Core.Find(path: string): Instance
	local node: Instance = ReplicatedStorage:WaitForChild(Config.Root)
	for name in path:gmatch("[^%.]+") do
		node = node:FindFirstChild(name) or error(("[UiPack] no %s in %s"):format(name, path))
	end
	return node
end

function Core.Get(name: string): any
	local group, key = name:match("^(%w+)%.(%w+)$")
	local entry = Config.Templates[name] or (group and type(Config.Templates[group]) == "table" and Config.Templates[group][key])
	local copy = Core.Find(entry or name):Clone()
	if copy:IsA("GuiObject") then
		copy.Visible = true
	end
	return copy
end

function Core.Screen(name: string, order: number, parent: Instance?): ScreenGui
	local pack = ReplicatedStorage:WaitForChild(Config.Root) :: ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name, screen.DisplayOrder, screen.ResetOnSpawn = name, order, false
	screen.IgnoreGuiInset, screen.ScreenInsets, screen.ZIndexBehavior = pack.IgnoreGuiInset, pack.ScreenInsets, pack.ZIndexBehavior
	screen.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

local hud: ScreenGui? = nil
function Core.Hud(parent: Instance?): ScreenGui
	if not hud then
		hud = Core.Screen("Hud", 1, parent)
	end
	return hud :: ScreenGui
end

function Core.Text(label: TextLabel, text: string)
	label.Text = text
	local top = label:FindFirstChild("Color")
	if top and top:IsA("TextLabel") then
		top.Text = text
	end
end

function Core.TextGradient(label: TextLabel, kind: string?)
	local top = label:FindFirstChild("Color")
	local target = if top and top:IsA("TextLabel") then top else label
	local gradient = target:FindFirstChildOfClass("UIGradient") or Ui.Make("UIGradient", { Rotation = 90, Parent = target })
	gradient.Enabled = kind ~= nil
	if kind then
		local c = Config.Text[kind]
		gradient.Color, gradient.Rotation = ColorSequence.new(c[1], c[2]), 90
	end
end

local function sequence(p): ColorSequence
	if not p.Stops then
		return ColorSequence.new(p.Top, p.Bottom)
	end
	local keys = {}
	for i, c in p.Stops do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#p.Stops - 1), c))
	end
	return ColorSequence.new(keys)
end

-- The gradient face of a skinned piece: the gui itself (cards) or its Container (buttons, headers).
function Core.Face(gui: Instance): GuiObject
	local container = gui:FindFirstChild("Container")
	if container and container:FindFirstChildOfClass("UIGradient") then
		return container :: GuiObject
	end
	return gui :: GuiObject
end

function Core.Paint(gui: GuiObject, kind: string)
	local p = Config.Colors[kind] or error("[UiPack] no colour " .. kind)
	local face = Core.Face(gui)
	local gradient = face:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color, gradient.Rotation = sequence(p), p.Rotation or 90
	if face ~= gui then
		if gui.BackgroundColor3 ~= Config.Ink then -- black-lipped pack pieces (tabs, Rebirth buttons) stay black
			gui.BackgroundColor3 = p.Lip
		end
		local outer = gui:FindFirstChild("Outer")
		if outer and outer:IsA("UIStroke") then
			outer.Color = p.Outer
		end
	end
	local rim = face:FindFirstChild("Inner")
	local rimGradient = rim and rim:FindFirstChildOfClass("UIGradient")
	if rimGradient then
		rimGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), p.Top or p.Stops[1])
	end
	local shadow = gui:FindFirstChildOfClass("UIShadow")
	if shadow then
		shadow.Color = p.Shadow
	end
	gui:SetAttribute("Paint", kind)
end

local function slot(button: GuiObject)
	local holder = Instance.new("Frame")
	holder.Name, holder.BackgroundTransparency, holder.ZIndex = button.Name, 1, button.ZIndex
	holder.Size, holder.Position, holder.AnchorPoint = button.Size, button.Position, button.AnchorPoint
	holder.LayoutOrder, holder.Visible = button.LayoutOrder, button.Visible
	holder:SetAttribute("Slot", true)
	holder.Parent = button.Parent
	button.Size, button.Position, button.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	button.Parent = holder
	button:GetPropertyChangedSignal("Visible"):Connect(function()
		holder.Visible = button.Visible
	end)
end

function Core.Clickable(button: GuiButton, fn: () -> ())
	button.Active, button.AutoButtonColor = true, false
	if button.Parent and button.Parent:FindFirstChildOfClass("UIListLayout") then
		slot(button)
	end
	Ui.Feel(button)
	button.Activated:Connect(function()
		if Ui.OnClick then
			Ui.OnClick()
		end
		fn()
	end)
	return button
end

function Core.Badge(gui: GuiObject): any
	local badge = gui:FindFirstChild("Notification")
	if not badge then
		badge = Core.Get("Badge")
		local B = Config.Badge
		badge.Size, badge.Position, badge.AnchorPoint = UDim2.fromScale(B.Size, B.Size), UDim2.fromScale(B.At.X, B.At.Y), Vector2.new(0.5, 0.5)
		badge.ZIndex = 120
		Ui.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = badge })
		badge.Parent = gui
	end
	badge.Visible = false
	return badge
end

function Core.Dim(gui: GuiObject, on: boolean)
	local face = Core.Face(gui)
	local dim = face:FindFirstChild("Dim") or Ui.Make("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Config.Dim, ZIndex = 90, Parent = face })
	dim.Visible = on
end

return Core
