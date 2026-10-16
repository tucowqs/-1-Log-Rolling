--[[
	HudStatsController — the bottom-left stats of the HUD (HudConfig.Stats / Cash): pack components in
	HudController.Group("Stats"), all from player attributes the server mirrors. Only the game's MAIN currencies,
	packed tight (standing rule):
	  Stats  rows of UiPack.StatRow (icon + 3D gradient number), named so celebrations / gates find Hud.Stats.<Name>
	  Cash   the big 3D number (UiPack.Cash) counting to each new value, every gain floating a "+$N" right of it;
	         its "+" opens HudConfig.Cash.Menu on its Tab. The first value after the save loads snaps (no float).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.HudConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HudController = require(script.Parent.HudController)

local HudStatsController = {}

local player = Players.LocalPlayer
local holds: { [string]: number } = {} -- attribute -> hold token: the stat keeps its old number until Release
local applies: { [string]: (number?) -> () } = {}

local function fade(gui: Instance, time: number)
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") then
			Ui.Tween(item, time, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		elseif item:IsA("UIStroke") then
			Ui.Tween(item, time, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
end

-- "+$400" (a copy of the cash label) pops just RIGHT of the cash row, clear of the stats above it, rises and fades.
local function float(hud: ScreenGui, row: GuiObject, anchor: TextLabel, text: string)
	local F = Config.Float
	local holder = Ui.Make("Frame", { Name = "Float", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), ZIndex = 50,
		Size = UDim2.fromOffset(anchor.AbsoluteSize.X, anchor.AbsoluteSize.Y), Rotation = math.random(-F.Tilt, F.Tilt) })
	local copy = anchor:Clone()
	copy.Size, copy.Position, copy.AnchorPoint, copy.Parent = UDim2.fromScale(1, 1), UDim2.new(), Vector2.zero, holder
	UiPack.Text(copy, text)
	local at = row.AbsolutePosition - hud.AbsolutePosition
	holder.Position = UDim2.fromOffset(at.X + row.AbsoluteSize.X + F.Gap + math.random() * anchor.AbsoluteSize.X * F.Jitter,
		at.Y + row.AbsoluteSize.Y / 2)
	holder.Parent = hud
	Ui.Pop(holder, 0.5)
	Ui.Tween(holder, F.Time, { Position = holder.Position - UDim2.fromScale(0, F.Rise) })
	fade(holder, F.Time)
	task.delay(F.Time, holder.Destroy, holder)
end

-- A pack 3D label that counts to each new value of a player attribute; onGain(amount) on every rise.
local function counter(label: TextLabel, attribute: string, format: (number) -> string, onGain: ((number) -> ())?)
	local shown = Instance.new("NumberValue")
	shown.Value = player:GetAttribute(attribute) or 0
	local last = shown.Value
	-- Before the save loads the attribute is nil: its first value is a snap, not a gain to count up and float.
	local seeded = player:GetAttribute(attribute) ~= nil
	shown.Changed:Connect(function(value)
		UiPack.Text(label, format(math.floor(value + 0.5)))
	end)
	UiPack.Text(label, format(shown.Value))
	local function apply(time: number?)
		local real = player:GetAttribute(attribute) or 0
		if not seeded then
			seeded, last, shown.Value = true, real, real
			return
		end
		if onGain and real > last then
			onGain(real - last)
		end
		last = real
		Ui.Tween(shown, time or Config.Count, { Value = real })
	end
	applies[attribute] = apply
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if not holds[attribute] then
			apply()
		end
	end)
end

local function stats(group: Frame)
	for order, def in Config.Stats do
		local props = table.clone(def.Box)
		props.Parent, props.Name, props.LayoutOrder = group, def.Name, order
		local row = UiPack.StatRow(def.Icon, def.Text, props)
		local fmt = def.Format
		counter(row.Amount, def.Attribute, function(n)
			local text = NumberFormat.Abbreviate(n)
			return if fmt then fmt:format(text) else text
		end)
	end
end

-- Freeze a stat's displayed number (the server value keeps changing underneath); Release counts it up to the real value
-- over `time`. A hold expires on its own after `maxSeconds` so a stat can never stay frozen.
function HudStatsController.Release(attribute: string, time: number?)
	if holds[attribute] then
		holds[attribute] = nil
		if applies[attribute] then
			applies[attribute](time)
		end
	end
end

function HudStatsController.Hold(attribute: string, maxSeconds: number)
	local token = (holds[attribute] or 0) + 1
	holds[attribute] = token
	task.delay(maxSeconds, function()
		if holds[attribute] == token then
			HudStatsController.Release(attribute)
		end
	end)
end

function HudStatsController.Start()
	local group = HudController.Group("Stats")
	stats(group)
	local C = Config.Cash
	if not C then
		return -- this game's currencies are all stat rows (HudConfig.Stats)
	end
	local props = table.clone(C.Box)
	props.Parent, props.Name = group, "Cash"
	local cash = UiPack.Cash({ OnPlus = function()
		ClientState.OpenMenu(C.Menu, C.Tab)
	end }, props)
	counter(cash.Amount, C.Attribute, NumberFormat.Money, function(gain)
		float(UiPack.Hud(), cash, cash.Amount, "+" .. NumberFormat.Money(gain))
	end)
end

return HudStatsController
