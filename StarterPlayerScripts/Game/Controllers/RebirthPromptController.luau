--[[
	RebirthPromptController — nudges the player to rebirth once they reach the level cap (RebirthMath.MaxLevel):
	  1. Dim     the screen is dimmed except around the HUD Rebirth button until they open the Rebirth window. The dim is ONE hole-shaped
	             Frame (transparent, rounded) that follows the button, with a UIStroke of a massive thickness: the stroke is the dimming.
	             It never blocks input (nothing Active), and only shows while idle (not rolling, no window open).
	  2. Seen    the Rebirth window is open: no dim.
	  3. Pulse   the window was closed without rebirthing: the HUD button pulses (endless) until they actually rebirth.
	Rebirthing drops them below the cap again, which resets everything. Numbers: RebirthConfig.Prompt.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)

local RebirthPromptController = {}

local P = Config.Prompt
local player = Players.LocalPlayer
local button: GuiObject
local hole: Frame, stroke: UIStroke
local phase: string? = nil -- nil (not at the cap) | "Dim" | "Seen" | "Pulse"
local dimmed = false
local pulseTween: Tween? = nil

local function atCap(): boolean
	return player:GetAttribute("Loaded") == true and (player:GetAttribute("Level") or 1) >= RebirthMath.MaxLevel(player:GetAttribute("Rebirths") or 0)
end

-- Keep the hole over the (tweening) HUD button, breathing in and out.
local function follow()
	local size = button.AbsoluteSize
	local pad = P.Dim.Pad + P.Frame.Grow * (0.5 - 0.5 * math.cos(os.clock() * math.tau / P.Frame.Period)) -- the frame around the button breathes while the dim shows
	hole.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	hole.Position = UDim2.fromOffset(button.AbsolutePosition.X + size.X / 2, button.AbsolutePosition.Y + size.Y / 2)
end

local function setDim(on: boolean)
	if on == dimmed then
		return
	end
	dimmed = on
	if on then
		follow()
		hole.Visible = true
		RunService:BindToRenderStep("RebirthPromptHole", Enum.RenderPriority.Last.Value, follow)
	else
		RunService:UnbindFromRenderStep("RebirthPromptHole")
	end
	local tween = Ui.Tween(stroke, P.Dim.Fade, { Transparency = if on then P.Dim.Transparency else 1 })
	if not on then
		tween.Completed:Once(function()
			if not dimmed then
				hole.Visible = false
			end
		end)
	end
end

local function setPulse(on: boolean)
	if on == (pulseTween ~= nil) then
		return
	end
	local scale = Ui.BounceScale(button)
	if on then
		pulseTween = TweenService:Create(scale, TweenInfo.new(P.Pulse.Period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = Ui.Rest(scale) * P.Pulse.Scale })
		pulseTween:Play()
	else
		pulseTween:Cancel()
		pulseTween = nil
		Ui.Tween(scale, 0.15, { Scale = Ui.Rest(scale) })
	end
end

local function refresh()
	local menu = ClientState.MenuOpen()
	if not atCap() then
		phase = nil
	elseif menu == Config.Menu then
		phase = "Seen"
	elseif phase == "Seen" then
		phase = "Pulse" -- closed without rebirthing
	elseif phase == nil then
		phase = "Dim"
	end
	setDim(phase == "Dim" and menu == nil and player:GetAttribute("Running") ~= true)
	setPulse(phase == "Pulse")
end

function RebirthPromptController.Start()
	local gui = Ui.Screen("RebirthDim", P.Dim.Order)
	hole = Ui.Make("Frame", { Name = "Hole", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Active = false, Visible = false, Parent = gui })
	Ui.Make("UICorner", { CornerRadius = UDim.new(0, P.Dim.Radius), Parent = hole })
	stroke = Ui.Make("UIStroke", { Thickness = P.Dim.Thickness, Color = P.Dim.Color, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = hole })
	button = UiPack.Hud():WaitForChild("Left"):WaitForChild("Rebirth")
	for _, attribute in { "Level", "Rebirths", "Running", "Loaded" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	ClientState.On("Menu", refresh)
	refresh()
end

return RebirthPromptController
