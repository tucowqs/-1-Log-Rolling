--[[
	RunHudController — the run's own HUD, built from GameUI pack parts:
	  ROLL!        the big green one-tap launch button. Idle only (not rolling, not lifting, no window open), and it tweens up
	               from the bottom edge while you stand in Workspace.RollZone (the pad by the drop-off) and back out when you
	               leave. It only asks the server to launch (Launch bridge).
	  metres       the distance rolled, top of the screen: it counts up toward the real value and shakes harder the faster you go
	  log health   the log's size as a bar at the very top of the screen: a clone of the XP bar, blue -> red as the log shrinks, LOG HEALTH over its centre; it breaks when empty
	The in-run indicators read RunController.Local() every frame; nothing here touches the network except Launch.
	Mobile: large touch targets, Fit-scaled design px, DeviceSafeInsets.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local RunController = require(script.Parent.RunController)
local RunLayout = require(script.Parent.Parent.Run.RunLayout)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)

local RunHudController = {}

local player = Players.LocalPlayer
local rollButton: GuiButton
local indicators: Frame
local meters: TextLabel
local health
local shown, lastWhole = 0, -1 -- the counted-up metres on screen, and the whole number last written to the label
local METER_POS = UDim2.fromScale(0.5, 0.3)
local COUNT_RATE, SHAKE = 9, { Base = 1.5, Speed = 7, Tilt = 2.5 } -- count-up speed (1/s); shake px at rest / extra at full speed; tilt degrees at full speed

local H = Config.Feel.HealthBar
local healthFill: Frame

local ROLL_SHOWN, ROLL_HIDDEN = UDim2.new(0.5, 0, 1, -220), UDim2.new(0.5, 0, 1, 160) -- on screen / parked below the bottom edge
local inZone = false -- standing in Workspace.RollZone (the pad by the drop-off edge)

local function refreshRoll()
	local idle = not player:GetAttribute("Running") and not player:GetAttribute("Training") and ClientState.MenuOpen() == nil
		and player:GetAttribute("Loaded") == true and not RunController.Local()
	rollButton.Visible = idle
	if not idle then
		rollButton.Position = ROLL_HIDDEN
	elseif inZone then
		Ui.Tween(rollButton, 0.4, { Position = ROLL_SHOWN }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		Ui.Tween(rollButton, 0.3, { Position = ROLL_HIDDEN }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
end

-- The pad of the player's own world (WorldsConfig RollZone: "RollZone" in World 1, "RollZone2" ...).
local function watchZone()
	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local zone = workspace:FindFirstChild(Worlds.Get(Worlds.Of(player)).RollZone) :: BasePart?
		local now = false
		if root and zone then
			local local_ = zone.CFrame:PointToObjectSpace(root.Position)
			now = math.abs(local_.X) <= zone.Size.X / 2 and math.abs(local_.Z) <= zone.Size.Z / 2 and math.abs(local_.Y) <= 12
		end
		if now ~= inZone then
			inZone = now
			refreshRoll()
		end
	end)
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, kind: string): TextLabel
	local text = UiPack.Get("StatText")
	text.Name, text.Size, text.Position, text.AnchorPoint, text.ZIndex, text.Parent = name, size, position, Vector2.new(0.5, 0.5), 12, parent
	UiPack.TextGradient(text, kind)
	return text
end

local function tint(value: number)
	local color = if value > 0.5 then H.Purple:Lerp(H.Blue, (value - 0.5) * 2) else H.Red:Lerp(H.Purple, value * 2)
	healthFill.UIGradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color)
end

-- A copy of the hand-built XP bar (so it always matches it), its level / XP texts swapped for one centred LOG HEALTH label.
local function buildHealth(parent: Instance): Frame
	local bar = game:GetService("StarterGui"):WaitForChild("Main"):WaitForChild("Bottom"):WaitForChild("BarFrame"):WaitForChild("Bar"):Clone()
	bar.Name, bar.AnchorPoint, bar.Position, bar.Size = "LogHealth", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, H.Top), UDim2.fromOffset(H.Size.X, H.Size.Y)
	bar.Level:Destroy()
	for _, label in { bar.XP, bar.XP.Color } do
		label.Text = H.Text
		label.TextXAlignment = Enum.TextXAlignment.Center
	end
	healthFill = bar.Effect
	healthFill.Size = UDim2.new(1, 0, healthFill.Size.Y.Scale, healthFill.Size.Y.Offset)
	bar.Parent = parent
	Ui.Fit(bar)
	return bar
end

local function update(dt: number)
	local run = RunController.Local()
	indicators.Visible = run ~= nil
	health.Visible = run ~= nil
	if not run then
		shown, lastWhole = 0, -1
		return
	end
	local life = math.clamp((run.Size - Config.Shrink.MinSize) / (1 - Config.Shrink.MinSize), 0, 1)
	healthFill.Size = UDim2.new(life, 0, healthFill.Size.Y.Scale, healthFill.Size.Y.Offset)
	tint(life)
	shown += (run.S * Config.Track.MetersPerStud - shown) * (1 - math.exp(-dt * COUNT_RATE)) -- the count-up
	local whole = math.floor(shown + 0.5)
	if whole ~= lastWhole then
		lastWhole = whole
		UiPack.Text(meters, `{NumberFormat.Commas(whole)} m`)
	end
	local amount = SHAKE.Base + SHAKE.Speed * run.Speed01 -- the shake
	meters.Position = METER_POS + UDim2.fromOffset((math.random() - 0.5) * 2 * amount, (math.random() - 0.5) * 2 * amount)
	meters.Rotation = (math.random() - 0.5) * 2 * SHAKE.Tilt * run.Speed01
end

function RunHudController.Start()
	local gui = Ui.Screen("RunHud", 5)
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Ui.Make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	rollButton = UiPack.Button("Green", "ROLL!", function()
		Net.Get("Launch"):Fire({ Seed = RunLayout.ForLaunch() })
	end, { Parent = root, Name = "Roll", Size = UDim2.fromOffset(300, 96), AnchorPoint = Vector2.new(0.5, 1), Position = ROLL_HIDDEN })
	Ui.Fit(rollButton) -- each piece scales itself from its design px (UiCore.Fit)
	Ui.Pulse(rollButton)
	indicators = Ui.Make("Frame", { Name = "Indicators", Size = UDim2.fromOffset(520, 120), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
		BackgroundTransparency = 1, Visible = false, Parent = root })
	Ui.Fit(indicators)
	meters = label(indicators, "Meters", UDim2.fromScale(1, 0.62), METER_POS, "White")
	meters.TextXAlignment = Enum.TextXAlignment.Center
	for _, layer in meters:GetDescendants() do
		if layer:IsA("TextLabel") then
			layer.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	UiPack.Text(meters, "0 m")
	health = buildHealth(root)
	health.Visible = false
	RunService.RenderStepped:Connect(update)
	for _, name in { "Running", "Training", "Loaded" } do
		player:GetAttributeChangedSignal(name):Connect(refreshRoll)
	end
	ClientState.On("Menu", refreshRoll)
	ClientState.On("RunBreak", refreshRoll)
	refreshRoll()
	task.spawn(watchZone)
end

return RunHudController
