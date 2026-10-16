--[[
	SpeedLines — white streaks that rush outward along the edges of the screen. While the log rolls they stream constantly
	(SpeedLines.Update(dt, speed01) every frame, speed01 = nil when no run is live), faster the quicker the log goes; a hit
	(SpeedLines.Burst(kind)) fires a flurry of bigger streaks and swells the stream (longer, denser, brighter) before it
	settles. Each streak is a thin radial bar on a ring just outside the middle of the screen that slides toward the edge
	while it fades. Numbers: BalanceConfig.Feel.SpeedLines.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local SpeedLines = {}

local S = Config.Feel.SpeedLines
local random = Random.new()
local gui: ScreenGui?
local swell = { Size = 1, Rate = 1, Alpha = nil, Hold = 0 } -- the current hit swell (decays back to 1)
local owed = 0 -- fractional streaks owed to the constant stream

local function screen(): ScreenGui
	if not gui then
		local made = Ui.Screen("SpeedLines", 4)
		made.IgnoreGuiInset = true
		gui = made
	end
	return gui :: ScreenGui
end

local function streak(length: number, time: number, alpha: number)
	local ang = random:NextNumber(0, math.tau)
	local dir = Vector2.new(math.cos(ang), math.sin(ang))
	local from = random:NextNumber(S.Inner[1], S.Inner[2])
	local to = from + random:NextNumber(S.Travel[1], S.Travel[2])
	-- positions are screen fractions on an ellipse (the lines run to the corners as well as the sides)
	local function at(r: number): UDim2
		return UDim2.fromScale(0.5 + dir.X * r * 0.5, 0.5 + dir.Y * r * 0.5)
	end
	local line = Ui.Make("Frame", { Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = S.Color, BorderSizePixel = 0,
		Size = UDim2.fromOffset(length, S.Thickness * (1 + (swell.Size - 1) * 0.35)), Position = at(from), Rotation = math.deg(math.atan2(dir.Y, dir.X)),
		BackgroundTransparency = 1, Parent = screen() })
	local fade = Instance.new("UIGradient") -- tapered ends
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = line
	time *= random:NextNumber(0.75, 1.1)
	TweenService:Create(line, TweenInfo.new(time * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = alpha }):Play()
	task.delay(time * 0.3, function()
		TweenService:Create(line, TweenInfo.new(time * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	end)
	local move = TweenService:Create(line, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = at(to) })
	move.Completed:Once(function()
		line:Destroy()
	end)
	move:Play()
end

local function cruise()
	local C = S.Cruise
	local length = random:NextNumber(C.Length[1], C.Length[2]) * swell.Size
	streak(length, C.Time * (1 + (swell.Size - 1) * 0.3), math.min(C.Alpha, swell.Alpha or 1))
end

function SpeedLines.Burst(kind: string)
	local spec = S.Kinds[kind]
	swell = { Size = math.max(swell.Size, spec.Size), Rate = math.max(swell.Rate, spec.Rate), Alpha = spec.Alpha, Hold = spec.Hold }
	for _ = 1, spec.Count do
		cruise()
	end
end

function SpeedLines.Update(dt: number, speed01: number?)
	if swell.Hold > 0 then
		swell.Hold -= dt
	else
		local k = math.exp(-S.Fade * dt)
		swell.Size, swell.Rate = 1 + (swell.Size - 1) * k, 1 + (swell.Rate - 1) * k
		if swell.Size < 1.02 then
			swell.Size, swell.Rate, swell.Alpha = 1, 1, nil
		end
	end
	if not speed01 then
		owed = 0
		return
	end
	owed += S.Cruise.Rate * (S.Cruise.Min + (1 - S.Cruise.Min) * speed01) * swell.Rate * dt
	while owed >= 1 do
		owed -= 1
		cruise()
	end
end

return SpeedLines
