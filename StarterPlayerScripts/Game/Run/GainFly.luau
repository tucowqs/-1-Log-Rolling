--[[
	GainFly — the "[speed icon] +N" notification, shared by the treadmills and the log run's bumps / ramps:
	it pops in at a random spot near the screen centre, holds, pulls back and springs (bouncy) into the Speed label at the bottom
	of the screen, shrinking away as it lands, and the label bumps (SpeedLabelController.Bump). Numbers: BalanceConfig.Feel.GainFly.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local SpeedLabelController = require(script.Parent.Parent.Controllers.SpeedLabelController)

local GainFly = {}

local P = Config.Feel.GainFly
local gui: ScreenGui?
local active = 0

function GainFly.Play(text: string)
	if active >= P.Max then
		return
	end
	if not gui then
		local made = Ui.Screen("GainFly", 6)
		made.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui = made
	end
	local screen = gui :: ScreenGui
	active += 1
	local holder = Ui.Make("Frame", { Name = "Gain", Size = UDim2.fromOffset(P.Width, P.Height), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Parent = screen })
	local scale = Instance.new("UIScale")
	scale.Scale, scale.Parent = 0, holder
	Ui.Icon(holder, "Speed", { Size = UDim2.fromScale(0.34, 1), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5) })
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint, label.Parent = UDim2.fromScale(0.64, 0.9), UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5), holder
	UiPack.Text(label, text)
	UiPack.TextGradient(label, "LightBlue")
	local size = screen.AbsoluteSize
	local start = Vector2.new(size.X * (P.StartX[1] + math.random() * (P.StartX[2] - P.StartX[1])), size.Y * (P.StartY[1] + math.random() * (P.StartY[2] - P.StartY[1])))
	holder.Position = UDim2.fromOffset(start.X, start.Y)
	local born = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - born
		if t < P.PopTime then -- pop in with an overshoot
			scale.Scale = TweenService:GetValue(t / P.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			return
		end
		local a = (t - P.PopTime - P.Hold) / P.FlyTime
		if a < 0 then
			scale.Scale = 1
			return
		end
		local target = SpeedLabelController.Target()
		if a >= 1 or not target then
			connection:Disconnect()
			holder:Destroy()
			active -= 1
			SpeedLabelController.Bump()
			return
		end
		local goal = target - screen.AbsolutePosition
		local move = TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.In) -- pulls back first, then springs forward
		local at = start:Lerp(goal, move)
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		scale.Scale = 1 - TweenService:GetValue(math.max(0, (a - P.ShrinkFrom) / (1 - P.ShrinkFrom)), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
end

return GainFly
