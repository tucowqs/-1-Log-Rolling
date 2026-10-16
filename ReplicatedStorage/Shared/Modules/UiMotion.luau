--[[
	UiMotion — the kit's movement: windows spring open (and their title icon wobbles in) and
	shrink away on close, grid cells pop in one after another, and idle sway / pulse loops that
	keep HUD icons and badges alive. Timings live in UIConfig.Motion.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.UIConfig)
local Core = require(script.Parent.UiCore)

local M = Config.Motion
local Motion = {}

local tokens = {} -- gui -> number; a newer open/close cancels an older close's hide

local function bump(gui: GuiObject): number
	tokens[gui] = (tokens[gui] or 0) + 1
	return tokens[gui]
end

function Motion.Open(gui: GuiObject)
	bump(gui)
	local scale = Core.BounceScale(gui)
	local rest = Core.Rest(scale)
	gui.Visible = true
	scale.Scale = rest * M.OpenFrom
	Core.Tween(scale, M.Open, { Scale = rest }, Enum.EasingStyle.Back)
	local icon = gui:FindFirstChild("TitleBar") and gui.TitleBar:FindFirstChild("Icon")
	if icon then
		local settle = icon:GetAttribute("Rotation") or icon.Rotation
		icon:SetAttribute("Rotation", settle)
		icon.Rotation = M.IconWobbleFrom
		Core.Tween(icon, M.IconWobble, { Rotation = settle }, Enum.EasingStyle.Elastic)
	end
end

function Motion.Close(gui: GuiObject)
	if not gui.Visible then
		return
	end
	local token = bump(gui)
	local scale = Core.BounceScale(gui)
	local rest = Core.Rest(scale)
	Core.Tween(scale, M.Close, { Scale = rest * M.CloseTo }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
		if tokens[gui] == token then
			gui.Visible = false
			scale.Scale = rest
		end
	end)
end

-- A layout places cells by their SCALED size, so a cell growing from 0 in a wrapping grid makes
-- the rows reflow every frame (cards jump between rows = flicker). So a cell grows inside an
-- invisible full-size slot that the layout sees instead; the slot copies the cell's Visible and
-- LayoutOrder, so code that shows / hides / orders the cell keeps working. Returns the cell.
local SLOT = "StaggerSlot"

local function slotted(child: GuiObject): GuiObject
	if not child:GetAttribute(SLOT) then
		local slot = Instance.new("Frame")
		slot.Name, slot.Size, slot.LayoutOrder, slot.ZIndex = child.Name, child.Size, child.LayoutOrder, child.ZIndex
		slot.Visible, slot.BackgroundTransparency = child.Visible, 1
		slot:SetAttribute(SLOT, true)
		for _, constraint in child:GetChildren() do
			if constraint:IsA("UIAspectRatioConstraint") or constraint:IsA("UISizeConstraint") then
				constraint:Clone().Parent = slot
			end
		end
		slot.Parent = child.Parent
		child.AnchorPoint, child.Position, child.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
		child.Parent = slot
		for _, property in { "Visible", "LayoutOrder" } do
			child:GetPropertyChangedSignal(property):Connect(function()
				slot[property] = child[property]
			end)
		end
		return child
	end
	return child:FindFirstChildWhichIsA("GuiObject")
end

-- Grows the visible cells / rows of a grid or list into place one after another, in layout
-- order. opts: Delay (seconds before the first, e.g. to let a window land), Tilt (degrees each
-- cell swings in from, alternating sides).
function Motion.Stagger(container: Instance, opts)
	opts = opts or {}
	local cells = {}
	local layout = container:FindFirstChildOfClass("UIListLayout") -- a grid places cells by index: no reflow
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			table.insert(cells, layout and slotted(child) or child)
		end
	end
	table.sort(cells, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	local tilt = opts.Tilt or 0
	for i, cell in cells do
		local scale = Core.BounceScale(cell)
		local rest = Core.Rest(scale)
		local settle = cell:GetAttribute("Rotation") or cell.Rotation
		cell:SetAttribute("Rotation", settle)
		scale.Scale = 0
		cell.Rotation = settle + (i % 2 == 0 and tilt or -tilt)
		task.delay((opts.Delay or 0) + math.min(i - 1, M.StaggerMax) * M.Stagger, function()
			Core.Tween(scale, M.StaggerTime, { Scale = rest }, Enum.EasingStyle.Back)
			Core.Tween(cell, M.StaggerTime, { Rotation = settle }, Enum.EasingStyle.Back)
		end)
	end
end

-- Endless gentle rocking about the gui's current rotation.
function Motion.Sway(gui: GuiObject, phase: number?)
	local base = gui.Rotation
	gui.Rotation = base - M.SwayAngle
	task.delay(phase or 0, function()
		TweenService:Create(gui, TweenInfo.new(M.SwayPeriod, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = base + M.SwayAngle }):Play()
	end)
end

-- Endless heartbeat pulse (badges, alerts).
function Motion.Pulse(gui: GuiObject)
	local scale = Core.BounceScale(gui)
	TweenService:Create(scale, TweenInfo.new(M.PulsePeriod, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = Core.Rest(scale) * M.PulseScale }):Play()
end

return Motion
