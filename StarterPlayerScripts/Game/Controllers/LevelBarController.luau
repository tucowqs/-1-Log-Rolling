--[[
	LevelBarController — drives the level / XP bar from the hand-built GUI at StarterGui.Main.Bottom.BarFrame
	(Bar.Effect = the fill, Bar.Level = level text, Bar.XP = XP text; each text has a "Color" child that mirrors it).
	Speed and XP are one value: every bump / ramp hit and every treadmill tick advances it (RunController relays the server's batched RunHits, TrainingController the TrainResult; the saved Level / LevelHits
	sync it on load), the fill eases to the new share, and a level up celebrates: the bar fills, a LEVEL UP! banner
	pops with confetti and a chime, and the bar starts the next level. XP needed per level: Curves.XPForLevel.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local CameraZoom = require(script.Parent.Parent.Run.CameraZoom)
local SoundController = require(script.Parent.SoundController)

local LevelBarController = {}

local gui, fill, levelLabel, xpLabel
local shown = { Level = nil, Hits = nil, Share = 0 }
local CELEBRATE_COOLDOWN = 5 -- seconds between full level-up celebrations
local celebratedAt, streak, activeBanner = -math.huge, 0, nil

-- At the rebirth level cap the bar stays full and reads MAX.
local function maxed(level: number): boolean
	return level >= RebirthMath.MaxLevel(Players.LocalPlayer:GetAttribute("Rebirths") or 0)
end

local function share(level: number, hits: number): number
	if maxed(level) then
		return 1
	end
	return math.clamp(hits / Curves.XPForLevel(level, Players.LocalPlayer:GetAttribute("Rebirths") or 0), 0, 1)
end

local function setLabel(label: TextLabel, text: string)
	label.Text = text
	local color = label:FindFirstChild("Color") -- the gradient-coloured copy that sits on top
	if color then
		color.Text = text
	end
end

local function setText(level: number, hits: number)
	setLabel(levelLabel, "Level " .. level)
	setLabel(xpLabel, if maxed(level) then "MAX" else `{NumberFormat.Abbreviate(math.floor(hits))}/{NumberFormat.Abbreviate(Curves.XPForLevel(level, Players.LocalPlayer:GetAttribute("Rebirths") or 0))}`)
end

local function banner(streak: number)
	local label = UiPack.Get("StatText")
	label.AnchorPoint, label.Position, label.Size, label.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.7, 0.2), 60
	UiPack.Text(label, if streak > 1 then `Level Up! [{streak}x]` else "Level Up!")
	UiPack.TextGradient(label, "Gold")
	for _, item in { label, table.unpack(label:GetDescendants()) } do -- the box is wide: centre the text in it
		if item:IsA("TextLabel") then
			item.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	label.Parent = gui
	Ui.Pop(label, 0.3)
	if activeBanner then -- a repeat level up replaces the banner in place
		activeBanner:Destroy()
	end
	activeBanner = label
	task.delay(1.6, function()
		for _, item in label:GetDescendants() do
			if item:IsA("TextLabel") then
				Ui.Tween(item, 0.4, { TextTransparency = 1 })
			elseif item:IsA("UIStroke") then
				Ui.Tween(item, 0.4, { Transparency = 1 })
			end
		end
		Ui.Tween(label, 0.4, { TextTransparency = 1 })
		task.delay(0.45, label.Destroy, label)
	end)
end

-- The full celebration plays once per cooldown; level ups inside it only bump the banner's multiplier.
local function levelUp()
	local now = os.clock()
	if now - celebratedAt < CELEBRATE_COOLDOWN then
		streak += 1
		banner(streak)
		return
	end
	celebratedAt, streak = now, 1
	SoundController.Play(Config.SoundNames.LevelUp)
	banner(streak)
	CameraZoom.Pulse()
	UiPack.Celebrate.Play(gui, {})
end

local function setFill(x: number)
	fill.Size = UDim2.new(x, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
end

local function tweenFill(x: number, time: number, style: Enum.EasingStyle?)
	Ui.Tween(fill, time, { Size = UDim2.new(x, 0, fill.Size.Y.Scale, fill.Size.Y.Offset) }, style)
end

local function update(level: number, hits: number, animate: boolean)
	local target = share(level, hits)
	if shown.Level and level > shown.Level and animate then
		tweenFill(1, 0.2)
		task.delay(0.22, function()
			setFill(0)
			tweenFill(target, 0.3)
		end)
		levelUp()
	elseif animate then
		tweenFill(target, 0.25, Enum.EasingStyle.Quad)
	else
		setFill(target)
	end
	shown.Level, shown.Hits, shown.Share = level, hits, target
	setText(level, hits)
end

function LevelBarController.Start()
	gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")
	local bar = gui:WaitForChild("Bottom"):WaitForChild("BarFrame"):WaitForChild("Bar")
	fill, levelLabel, xpLabel = bar:WaitForChild("Effect"), bar:WaitForChild("Level"), bar:WaitForChild("XP")
	setFill(0)
	setText(1, 0)
	ClientState.On("Data", function()
		local level, hits = ClientState.Data.Level or 1, ClientState.Data.LevelHits or 0
		if not shown.Level then
			update(level, hits, false) -- the first snapshot snaps
		elseif shown.Level ~= level or shown.Hits ~= hits then
			update(level, hits, true) -- the server moved it (a snapshot can land before or after the batched RunHits): animate, and a level up still celebrates once
		end
	end)
	for _, event in { "RunHits", "TrainResult", "RebirthDone" } do
		ClientState.On(event, function(p)
			update(p.Level, p.LevelHits, true)
		end)
	end
end

return LevelBarController
