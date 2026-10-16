--[[
	Spotlight — dims the whole screen except around one GUI button. The dim is ONE hole-shaped Frame (transparent, rounded)
	that follows the button, with a UIStroke of a massive thickness: the stroke is the dimming. Nothing is Active, so it never
	blocks input; the button underneath stays clickable. The hole breathes (grows / shrinks) while it shows.
	  Spotlight.new(name, config)   config = TutorialConfig.Dim
	  spot:Set(button?)             a GuiObject lights it, nil fades the dim out
]]
local RunService = game:GetService("RunService")

local Ui = require(script.Parent.Ui)

local Spotlight = {}
Spotlight.__index = Spotlight

function Spotlight.new(name: string, config)
	local self = setmetatable({ Config = config, Bind = name .. "Hole", Target = nil }, Spotlight)
	self.Gui = Ui.Screen(name, config.Order)
	-- where this ScreenGui's (0, 0) really is on screen: gui insets differ per ScreenGui, so positions are taken relative to it
	self.Origin = Ui.Make("Frame", { Name = "Origin", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false, Parent = self.Gui })
	self.Hole = Ui.Make("Frame", { Name = "Hole", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Active = false, Visible = false, Parent = self.Gui })
	Ui.Make("UICorner", { CornerRadius = UDim.new(0, config.Radius), Parent = self.Hole })
	self.Stroke = Ui.Make("UIStroke", { Thickness = config.Thickness, Color = config.Color, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = self.Hole })
	return self
end

-- Keep the hole over the (tweening) button, breathing in and out.
function Spotlight:Follow()
	local C, button = self.Config, self.Target
	local size = button.AbsoluteSize
	local pad = C.Pad + C.Grow * (0.5 - 0.5 * math.cos(os.clock() * math.tau / C.Period))
	self.Hole.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	local origin = self.Origin.AbsolutePosition
	self.Hole.Position = UDim2.fromOffset(button.AbsolutePosition.X + size.X / 2 - origin.X, button.AbsolutePosition.Y + size.Y / 2 - origin.Y)
end

function Spotlight:Set(button: GuiObject?)
	if button == self.Target then
		return
	end
	self.Target = button
	if button then
		self.Gui.ScreenInsets = button:FindFirstAncestorOfClass("ScreenGui").ScreenInsets -- same coordinate space as the button
		self:Follow()
		self.Hole.Visible = true
		RunService:BindToRenderStep(self.Bind, Enum.RenderPriority.Last.Value, function()
			self:Follow()
		end)
	else
		RunService:UnbindFromRenderStep(self.Bind)
	end
	local tween = Ui.Tween(self.Stroke, self.Config.Fade, { Transparency = if button then self.Config.Transparency else 1 })
	if not button then
		tween.Completed:Once(function()
			if not self.Target then
				self.Hole.Visible = false
			end
		end)
	end
end

return Spotlight
