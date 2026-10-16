--[[
	UiCore — plumbing under the UI kit: build instances from a props table, tweens, bounce
	helpers, and Fit(): scales a top-level container designed at UIConfig.Design pixels to
	the current viewport with its own UIScale (never on the full-screen root).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.UIConfig)

local UiCore = {}

local fitted = {} -- UIScale instances to keep in step with the viewport

function UiCore.Make(className: string, props)
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

function UiCore.Screen(name: string, order: number): ScreenGui
	return UiCore.Make("ScreenGui", {
		Name = name,
		DisplayOrder = order,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

local function viewportScale(): number
	local size = workspace.CurrentCamera.ViewportSize
	local scale = math.min(size.X / Config.Design.X, size.Y / Config.Design.Y)
	return math.clamp(scale, Config.MinScale, Config.MaxScale)
end

-- Scales a pixel-designed container (and everything in it) to the viewport.
function UiCore.Fit(container: GuiObject): UIScale
	local scale = UiCore.Make("UIScale", { Name = "Fit", Scale = viewportScale(), Parent = container })
	table.insert(fitted, scale)
	return scale
end

function UiCore.Tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- The UIScale to animate. The engine only honours ONE UIScale per gui, so a fitted container
-- animates its own Fit; anything else gets a "Bounce" one.
function UiCore.BounceScale(gui: GuiObject): UIScale
	return gui:FindFirstChild("Fit") or gui:FindFirstChild("Bounce") or UiCore.Make("UIScale", { Name = "Bounce", Parent = gui })
end

-- The scale a BounceScale settles at: the viewport scale for Fit, otherwise 1.
function UiCore.Rest(scale: UIScale): number
	return scale.Name == "Fit" and viewportScale() or 1
end

-- Quick pop: grows from `from` (fraction of rest) with a springy overshoot.
function UiCore.Pop(gui: GuiObject, from: number?)
	local bounce = UiCore.BounceScale(gui)
	local rest = UiCore.Rest(bounce)
	bounce.Scale = rest * (from or 0.6)
	UiCore.Tween(bounce, Config.Tween.Bounce, { Scale = rest }, Enum.EasingStyle.Back)
end

function UiCore.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function UiCore.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local scale = viewportScale()
	for index = #fitted, 1, -1 do
		local fit = fitted[index]
		if fit.Parent then
			fit.Scale = scale
		else
			table.remove(fitted, index)
		end
	end
end)

return UiCore
