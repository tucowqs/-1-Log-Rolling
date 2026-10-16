--[[
	Ui — the UI kit every screen is built from, in the Studs UI Pack look (UIConfig theme).
	Every coloured surface is a "skin": a darker lip under a gradient face with a white inner
	rim, the pack's tiled squiggle texture and diagonal shine stripes, all ringed in ink.
	Dark "wells" (window bodies, item cells) are see-through black with a faint rim.
	Icons are vector-pack images named in UIConfig.Icons. Plumbing (Make, Screen, Fit, Tween,
	Pop) comes from UiCore and surfaces (Skin, SetColor, Sunburst...) from UiSkin, both
	re-exported. Ui.OnClick is a hook the SoundController sets.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.UIConfig)
local Core = require(script.Parent.UiCore)
local Motion = require(script.Parent.UiMotion)
local Skin = require(script.Parent.UiSkin)

-- Skin (surfaces), Motion (Open/Close/Stagger/Sway/Pulse) and Core (plumbing) are re-exported.
local Ui = setmetatable({}, { __index = function(_, key)
	return Skin[key] or Motion[key] or Core[key]
end })
Ui.Colors = Config.Colors
Ui.WindowSizes = Config.Window.Sizes
Ui.Fonts = Config.Fonts
Ui.OnClick = nil

local WHITE = Color3.new(1, 1, 1)

-- Text always fills its box (TextScaled, no size cap). MaxSize is only a hint for how thick the
-- outline should be when the box's height is given in scale rather than pixels.
function Ui.Label(props)
	local height = props.Size and props.Size.Y.Offset or 0
	local textSize = height > 0 and height or (props.MaxSize or 40)
	props.MaxSize = nil
	props.BackgroundTransparency = 1
	props.FontFace = props.Title and Config.Fonts.Title or Config.Fonts.Body
	props.Title = nil
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Config.Colors.Text
	local label = Core.Make("TextLabel", props)
	-- Outline scales with the text so small labels stay crisp instead of clogged.
	local thickness = math.clamp(textSize * Config.TextStrokeRatio, Config.TextStrokeMin, Config.TextStroke)
	Core.Make("UIStroke", { Color = Config.TextStrokeColor, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end

function Ui.IconId(name: string): string
	return Config.Icons[name]
end

-- A vector-pack icon image. props like ImageLabel props.
function Ui.Icon(parent: Instance, name: string, props)
	props.Name = props.Name or "Icon"
	props.Image = Config.Icons[name]
	props.BackgroundTransparency = 1
	props.ScaleType = Enum.ScaleType.Fit
	props.Parent = parent
	return Core.Make("ImageLabel", props)
end

-- The button feel (UIConfig.ButtonFeel): grows when the mouse is over it, pushes down while
-- held, springs back with a bounce on release. Works on any GuiButton (the kit's and the pack's).
function Ui.Feel(button: GuiButton)
	local F = Config.ButtonFeel
	local bounce = Core.BounceScale(button)
	local rest = Core.Rest(bounce)
	local over = false
	button.MouseEnter:Connect(function()
		over = true
		Core.Tween(bounce, Config.Tween.Pop, { Scale = rest * F.Hover })
	end)
	button.MouseLeave:Connect(function()
		over = false
		Core.Tween(bounce, Config.Tween.Pop, { Scale = rest })
	end)
	button.MouseButton1Down:Connect(function()
		Core.Tween(bounce, Config.Tween.Pop, { Scale = rest * F.Press })
	end)
	button.MouseButton1Up:Connect(function()
		Core.Tween(bounce, Config.Tween.Bounce, { Scale = rest * (over and F.Hover or 1) }, Enum.EasingStyle.Back)
	end)
end

local function hookButton(button: GuiButton, onClick)
	Ui.Feel(button)
	button.Activated:Connect(function()
		if Ui.OnClick then
			Ui.OnClick()
		end
		if onClick then
			onClick()
		end
	end)
end

-- props: Size, Position, AnchorPoint, Color (skin name or Color3), Text, Icon (icon name), Shine,
-- TextSize(max), Parent, LayoutOrder, Visible, Name, ZIndex.
function Ui.Button(props, onClick)
	local button = Core.Make("TextButton", {
		Name = props.Name or "Button", Size = props.Size, Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero, LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false, Text = "", AutoButtonColor = false, ZIndex = props.ZIndex or 1, Parent = props.Parent,
	})
	local face = Ui.Skin(button, props.Color, nil, props.Shine)
	local z = button.ZIndex + 1
	local textLeft = 6
	if props.Icon then
		local icon = Ui.Icon(face, props.Icon, { Size = UDim2.new(1, 4, 1, 4), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z })
		Core.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = icon })
		textLeft = props.Size.Y.Offset > 0 and props.Size.Y.Offset or 50
	end
	Ui.Label({
		Name = "Label", Size = UDim2.new(1, -textLeft - 6, 1, -8), Position = UDim2.fromOffset(textLeft, 4), Text = props.Text or "",
		Title = true, MaxSize = props.TextSize or 30, ZIndex = z, Parent = face,
	})
	hookButton(button, onClick)
	return button
end

function Ui.SetText(button: GuiObject, text: string)
	button.Face.Label.Text = text
end

-- A panel: skinned when props.Color is given, otherwise a dark see-through well.
function Ui.Panel(props)
	local value = props.Color
	local shine = props.Shine
	props.Color = nil
	props.Shine = nil
	props.BorderSizePixel = 0
	local frame = Core.Make("Frame", props)
	if value and value ~= "Dark" then
		Ui.Skin(frame, value, Config.Corner + 4, shine)
		return frame
	end
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = Config.WellTransparency
	Ui.Corner(frame, Config.Corner + 4)
	Ui.Stroke(frame)
	Skin.Rim(frame, 0.65)
	return frame
end

-- A dark item cell with rarity-tinted rays (Index / inventory grids). Returns the button.
function Ui.Cell(props, onClick)
	local tint = props.Tint or WHITE
	local cell = Core.Make("TextButton", {
		Name = props.Name or "Cell", Size = props.Size or UDim2.new(), LayoutOrder = props.LayoutOrder or 0, Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Config.CellTransparency, BorderSizePixel = 0, Parent = props.Parent,
	})
	Ui.Corner(cell)
	Ui.Stroke(cell)
	local edge = Skin.Rim(cell, 0.2)
	edge.Color = tint
	Ui.Sunburst(cell, tint, { Size = UDim2.fromScale(1.1, 1.1), Position = UDim2.fromScale(0.5, 0.42), Transparency = 0.45 })
	hookButton(cell, onClick)
	return cell
end

-- A centred, fitted window: dark body, a skinned title bar with an overhanging icon, and a
-- square close button. size in design pixels (Ui.WindowSizes). Returns window, body.
function Ui.Window(screen: ScreenGui, title: string, onClose, size: Vector2, tint, icon: string?)
	local bar = Config.Window.TitleHeight
	local iconSize = Config.Window.IconSize
	local window = Ui.Panel({
		Name = "Window", Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromScale(Config.Window.CenterX, Config.Window.CenterY),
		AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = screen,
	})
	Core.Fit(window)
	local titleBar = Ui.Panel({ Name = "TitleBar", Size = UDim2.new(1, 0, 0, bar), Color = tint or "Blue", Shine = true, ZIndex = 3, Parent = window })
	if icon then
		Ui.Icon(titleBar, icon, { Size = UDim2.fromOffset(iconSize, iconSize), Position = UDim2.fromOffset(-iconSize * 0.3, -iconSize * 0.28), Rotation = -10, ZIndex = 5 })
	end
	Ui.Label({ Name = "Title", Size = UDim2.new(1, -220, 0, bar - 26), Position = UDim2.fromOffset(icon and iconSize * 0.78 or 22, 8), Text = title, Title = true, TextXAlignment = Enum.TextXAlignment.Left, MaxSize = Config.Window.TitleTextSize, ZIndex = 5, Parent = titleBar })
	local close = Ui.Button({ Name = "Close", Size = UDim2.fromOffset(bar - 20, bar - 22), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), Text = "X", Color = "Pink", TextSize = 40, Parent = titleBar }, onClose)
	close.ZIndex = 5
	local body = Core.Make("Frame", {
		Name = "Body", Size = UDim2.new(1, -36, 1, -(bar + 30)), Position = UDim2.fromOffset(18, bar + 14), BackgroundTransparency = 1, ZIndex = 2, Parent = window,
	})
	return window, body
end

-- The pack's money text: a dark copy underneath and a gradient-filled copy nudged up on top, so
-- the number looks thick and 3D. Update it with Ui.SetStatText.
function Ui.StatText(props, skin: string)
	local maxSize = props.MaxSize
	local base = Ui.Label(props)
	base.TextColor3 = Config.TextStrokeColor
	local face = Ui.Label({
		Name = "Color", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, -0.07), Text = base.Text, Title = true,
		TextXAlignment = base.TextXAlignment, MaxSize = maxSize, ZIndex = base.ZIndex + 1, Parent = base,
	})
	Core.Make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Config.Skins[skin][1], Config.Skins[skin][2]), Parent = face })
	return base
end

function Ui.SetStatText(label: TextLabel, text: string)
	label.Text = text
	label.Color.Text = text
end

-- HUD stat row: a big icon beside pack-style gradient stat text. Returns row, stat label.
function Ui.Stat(parent: Instance, icon: string, skin: string, props)
	local height = props.Size.Y.Offset
	local row = Core.Make("Frame", { Size = props.Size, LayoutOrder = props.LayoutOrder or 0, BackgroundTransparency = 1, Parent = parent })
	Ui.Icon(row, icon, { Size = UDim2.fromOffset(height + 6, height + 6), Position = UDim2.new(0, -3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Rotation = -6, ZIndex = 3 })
	local value = Ui.StatText({
		Size = UDim2.new(1, -(height + 8), 1, 0), Position = UDim2.fromOffset(height + 8, 0), Text = "", Title = true,
		TextXAlignment = Enum.TextXAlignment.Left, MaxSize = props.TextSize or height, ZIndex = 2, Parent = row,
	}, skin)
	return row, value
end

-- Square menu button: a big tilted icon with a caption along the bottom.
function Ui.IconButton(parent: Instance, icon: string, caption: string, tint, onClick, props)
	local button = Ui.Button({ Size = props.Size, Position = props.Position, LayoutOrder = props.LayoutOrder, Color = tint, Text = "", Shine = true, Parent = parent }, onClick)
	local image = Ui.Icon(button.Face, icon, { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -4, ZIndex = button.ZIndex + 1 })
	Motion.Sway(image, (props.LayoutOrder or 0) * 0.35)
	Ui.Label({ Name = "Caption", Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0, 2, 0.72, 0), Text = caption, Title = true, MaxSize = 22, ZIndex = button.ZIndex + 2, Parent = button.Face })
	return button
end

-- Red round count badge in a gui's top-right corner.
function Ui.Badge(parent: GuiObject)
	local badge = Ui.Label({ Name = "Badge", Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, 8, 0, -8), AnchorPoint = Vector2.new(1, 0), Text = "", Title = true, MaxSize = 20, BackgroundTransparency = 0, BackgroundColor3 = Config.Skins.Red[2], ZIndex = parent.ZIndex + 3, Visible = false, Parent = parent })
	badge.BackgroundTransparency = 0
	Ui.Corner(badge, 100)
	Skin.Rim(badge, 0)
	Ui.Stroke(badge, Config.Colors.Outline, 2.5)
	Motion.Pulse(badge)
	return badge
end

function Ui.List(parent: Instance, props)
	props.SortOrder = Enum.SortOrder.LayoutOrder
	props.Parent = parent
	return Core.Make("UIListLayout", props)
end

function Ui.Aspect(parent: Instance, ratio: number)
	return Core.Make("UIAspectRatioConstraint", { AspectRatio = ratio, Parent = parent })
end

-- A scrolling grid of fixed-pixel cells.
function Ui.Grid(parent: Instance, cell: Vector2, props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 8
	props.ScrollBarImageColor3 = WHITE
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.CanvasSize = UDim2.new()
	props.Parent = parent
	local scroll = Core.Make("ScrollingFrame", props)
	Core.Make("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	Core.Make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = scroll })
	return scroll
end

return Ui
