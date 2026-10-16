--[[
	SteerController — steer the log you are rolling. Hold A / D (or the arrow keys), or press and drag left / right on the
	screen (mouse or touch; the further you drag from where you started, the harder you steer; let go to hold your line).
	Input is a value D in -1..1, applied to your own replay AT ONCE and sent to the server as { T, D } (T = run clock now);
	the server re-simulates (accepting T up to Physics.Steer.Lag old) and echoes it to everyone else. Only sends on change, at most Physics.Steer.MaxPerSecond.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RunController = require(script.Parent.RunController)

local SteerController = {}

local S = Config.Physics.Steer
local held = { Left = false, Right = false }
local dragStart: Vector3? = nil
local dragValue = 0
local sent, lastSend = 0, 0

local KEYS = {
	[Enum.KeyCode.A] = "Left", [Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.D] = "Right", [Enum.KeyCode.Right] = "Right",
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function wanted(): number
	local key = (if held.Left then 1 else 0) - (if held.Right then 1 else 0) -- inverted: A steers the log towards +lane
	if key ~= 0 then
		return key
	end
	return -math.round(dragValue * 10) / 10
end

function SteerController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		local side = KEYS[input.KeyCode]
		if side and not UserInputService:GetFocusedTextBox() then
			held[side] = true
		elseif isPointer(input) and not processed then
			dragStart, dragValue = input.Position, 0
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragValue = math.clamp((input.Position.X - dragStart.X) / S.DragPixels, -1, 1)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local side = KEYS[input.KeyCode]
		if side then
			held[side] = false
		elseif isPointer(input) then
			dragStart, dragValue = nil, 0
		end
	end)
	RunService.Heartbeat:Connect(function()
		local time = RunController.Time()
		if not time then
			sent = 0 -- the next run starts straight
			return
		end
		local value = wanted()
		if value ~= sent and os.clock() - lastSend >= 1 / S.MaxPerSecond then
			sent, lastSend = value, os.clock()
			local at = RunController.Steer(value)
			if at then
				Net.Get("Steer"):Fire({ T = at, D = value })
			end
		end
	end)
end

return SteerController
