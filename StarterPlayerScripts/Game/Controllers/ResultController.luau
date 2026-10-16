--[[
	ResultController — what happens when a log breaks. No result window: the camera lingers on the splinters for
	Feel.BreakHold seconds, then the server puts the player back at the lobby spawn (ReturnSpawn) and the camera pans
	there quickly (Feel.ReturnPan). The trophies then fly into the Wins stat (UiPack.Celebrate) and, as they land, the
	stat counts up to the new total (Feel.WinsCount). The Wins number is frozen from the run's start (HudStatsController.Hold)
	so the count-up is seen here and not when the server pays at the break. The numbers all come from the server's payload.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local RunCamera = require(script.Parent.Parent.Run.RunCamera)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HudStatsController = require(script.Parent.HudStatsController)
local RunController = require(script.Parent.RunController)

local ResultController = {}

local F = Config.Feel
local pending: any = nil

local function countUp()
	HudStatsController.Release("Wins", F.WinsCount)
end

-- Small white [trophy] +N in the middle of the screen: pops in, rises and fades out. Yields until it is gone.
local function notifier(hud: ScreenGui, anchor: TextLabel?, wins: number)
	local height = hud.AbsoluteSize.Y * 0.1
	local holder = Ui.Make("Frame", { Name = "WinsNotifier", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 400,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, height), Position = UDim2.fromScale(0.5, 0.5) })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.VerticalAlignment, layout.Padding = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center, UDim.new(0, height * 0.2)
	layout.Parent = holder
	local icon = Ui.Make("ImageLabel", { Image = IconPick.Image("Trophy"), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 400,
		Size = UDim2.fromOffset(height, height), Parent = holder })
	local label = Ui.Make("TextLabel", { Text = "+" .. NumberFormat.Abbreviate(wins), BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1),
		TextSize = height * 0.8, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, height), ZIndex = 400, Parent = holder })
	if anchor then
		label.FontFace = anchor.FontFace
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color, stroke.Parent = 3, Color3.fromRGB(30, 30, 40), label
	holder.Parent = hud
	Ui.Pop(holder, 0.3)
	task.wait(0.4)
	Ui.Tween(holder, F.NotifyTime, { Position = UDim2.new(0.5, 0, 0.5, -hud.AbsoluteSize.Y * 0.07) })
	Ui.Tween(icon, F.NotifyTime, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Ui.Tween(label, F.NotifyTime, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Ui.Tween(stroke, F.NotifyTime, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(F.NotifyTime)
	holder:Destroy()
end

local function celebrate(wins: number)
	local hud = UiPack.Hud()
	local target = hud:FindFirstChild("Wins", true)
	if not target then
		countUp()
		return
	end
	notifier(hud, target:FindFirstChild("Amount", true), wins) -- fades out before the trophies fly
	local landed = false
	UiPack.Celebrate.Play(hud, { Images = { IconPick.Image("Trophy") }, Target = target, OnArrive = function()
		if not landed then
			landed = true
			countUp() -- the first trophy to land starts the count
		end
	end })
end

-- Waits for the server's teleport (the root jumps far from where the log broke), then returns the root.
local function awaitSpawn(from: Vector3): BasePart?
	local started = os.clock()
	while os.clock() - started < 1.5 do
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - from).Magnitude > 30 then
			return root
		end
		task.wait()
	end
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function sequence(result)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	Net.Get("ReturnSpawn"):Fire({})
	root = awaitSpawn(if root then root.Position else Vector3.zero)
	if pending ~= result then
		return -- rolled again meanwhile
	end
	pending = nil
	if root then
		local at = root.Position
		local behind = -root.CFrame.LookVector * 14
		RunCamera.Pan(CFrame.lookAt(at + behind + Vector3.new(0, 6, 0), at + Vector3.new(0, 2, 0)), F.ReturnPan)
	end
	RunController.Release()
	celebrate(result.Wins)
end

function ResultController.Start()
	ClientState.On("RunStart", function()
		pending = nil -- a new run began: drop a stale result
		HudStatsController.Hold("Wins", 40) -- the break pays Wins; show them counting up back at the spawn
	end)
	ClientState.On("RunResult", function(result)
		pending = result
		task.delay(F.BreakHold, function()
			if pending == result then
				sequence(result)
			end
		end)
	end)
end

return ResultController
