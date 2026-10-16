--[[
	UiSkin — the Studs UI Pack surface recipe the kit paints with: pack gradients per colour, ink
	outlines, the white inner rim, and Skin() — a darker lip under a gradient face carrying the
	pack's tiled texture and (opt-in) diagonal shine stripes. Also the spinning sunburst behind icons.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.UIConfig)
local Core = require(script.Parent.UiCore)

local Skin = {}

local WHITE = Color3.new(1, 1, 1)
local SHINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.02, 0.25), NumberSequenceKeypoint.new(0.13, 1),
	NumberSequenceKeypoint.new(0.28, 0.25), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.36, 0.25),
	NumberSequenceKeypoint.new(0.66, 1), NumberSequenceKeypoint.new(0.84, 0.28), NumberSequenceKeypoint.new(0.841, 1),
	NumberSequenceKeypoint.new(0.99, 0.24), NumberSequenceKeypoint.new(1, 1),
})

-- { Top, Bottom, Lip } for a skin name or any Color3.
local function palette(value)
	local skin = Config.Skins[value or "Blue"]
	if skin then
		return skin[1], skin[2], skin[3]
	end
	local base = typeof(value) == "Color3" and value or Config.Colors[value]
	return Core.Lighten(base, 0.45), base, Core.Darken(base, 0.45)
end

function Skin.Corner(parent: Instance, px: number?)
	return Core.Make("UICorner", { CornerRadius = UDim.new(0, px or Config.Corner), Parent = parent })
end

function Skin.Stroke(parent: Instance, strokeColor: Color3?, thickness: number?)
	return Core.Make("UIStroke", {
		Name = "Outer", Color = strokeColor or Config.Colors.Outline, Thickness = thickness or Config.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = parent,
	})
end

-- White rim drawn just inside a gui's edge.
function Skin.Rim(parent: GuiObject, transparency: number?)
	return Core.Make("UIStroke", {
		Name = "Rim", Color = WHITE, Thickness = Config.Rim, Transparency = transparency or Config.RimTransparency,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

-- Vertical gradient between two colours (defaults derived from one base colour).
function Skin.Gradient(gui: GuiObject, top, bottom: Color3?)
	if not bottom then
		top, bottom = palette(top)
	end
	gui.BackgroundColor3 = WHITE
	local gradient = gui:FindFirstChildOfClass("UIGradient") or Core.Make("UIGradient", { Rotation = 90, Parent = gui })
	gradient.Color = ColorSequence.new(top, bottom)
	return gradient
end

-- Turns a gui into a pack face; returns the Face frame that content goes in. The diagonal shine
-- stripes are opt-in (only the HUD menu buttons and window title bars use them).
function Skin.Skin(gui: GuiObject, value, corner: number?, shine: boolean?)
	local top, bottom, lip = palette(value)
	gui.BackgroundColor3 = lip
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	Skin.Corner(gui, corner)
	Skin.Stroke(gui)
	local face = Core.Make("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -Config.Lip), BorderSizePixel = 0, ZIndex = gui.ZIndex, Parent = gui })
	Skin.Corner(face, corner)
	Skin.Gradient(face, top, bottom)
	Skin.Rim(face)
	local texture = Core.Make("ImageLabel", {
		Name = "Texture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.Texture,
		ImageTransparency = Config.TextureTransparency, ScaleType = Enum.ScaleType.Tile, TileSize = Config.TextureTile, ZIndex = gui.ZIndex, Parent = face,
	})
	Skin.Corner(texture, corner)
	Core.Make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.84, 0.04), Parent = texture })
	if shine then
		local stripes = Core.Make("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = gui.ZIndex, Parent = face })
		Skin.Corner(stripes, corner)
		Core.Make("UIGradient", { Rotation = 21, Transparency = SHINE, Parent = stripes })
	end
	return face
end

function Skin.SetColor(gui: GuiObject, value)
	local top, bottom, lip = palette(value)
	gui.BackgroundColor3 = lip
	Skin.Gradient(gui.Face, top, bottom)
end

function Skin.SetOutline(gui: GuiObject, strokeColor: Color3, thickness: number?)
	gui.Outer.Color = strokeColor
	gui.Outer.Thickness = thickness or Config.Stroke
end

-- Slowly spinning rays behind an icon (the pack's item-cell glow).
function Skin.Sunburst(parent: GuiObject, tint: Color3?, props)
	props = props or {}
	local rays = Core.Make("ImageLabel", {
		Name = "Sunburst", Size = props.Size or UDim2.fromScale(1.2, 1.2), Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = Config.Sunburst, ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = tint or WHITE, ImageTransparency = props.Transparency or 0.3, ZIndex = props.ZIndex or parent.ZIndex, Parent = parent,
	})
	TweenService:Create(rays, TweenInfo.new(Config.SunburstSpin, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	return rays
end

return Skin
