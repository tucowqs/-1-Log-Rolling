--[[
	TreadmillGuideController — after a rebirth, sends the player to the best treadmill they can use (the highest Mult whose Rebirths
	requirement they now meet): a sticky toast (BalanceConfig.Training.Guide) plus the tutorial's arrow beam and marker. Both stop the
	moment they start running on that treadmill (the "Training" attribute), so there is no further prompting. The beam hides while a roll
	or a window is up. Session only: it is not saved, and it stays quiet while the first-time tutorial runs.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local GuidePointer = require(ReplicatedStorage.Shared.Modules.GuidePointer)
local ClientState = require(script.Parent.Parent.State.ClientState)
local NotifyController = require(script.Parent.NotifyController)

local TreadmillGuideController = {}

local G = Config.Training.Guide
local player = Players.LocalPlayer
local pointer
local target: string? = nil -- the treadmill id being pointed at
local toast = nil

-- The best treadmill usable with this many rebirths.
local function best(rebirths: number)
	local pick
	for _, def in Curves.Treadmills do -- in the player's world, never a Robux zone
		if not def.Pass and def.World == Worlds.Of(player) and def.Rebirths <= rebirths and (not pick or def.Mult > pick.Mult) then
			pick = def
		end
	end
	return pick
end

local function stop()
	target = nil
	NotifyController.Dismiss(toast)
	toast = nil
	pointer:Update(nil)
end

local function begin(payload)
	local def = best(payload.Rebirths)
	if not def or player:GetAttribute("Tutorial") ~= nil then
		return
	end
	NotifyController.Dismiss(toast)
	target = def.Id
	toast = NotifyController.Toast(G.Text:format(Emphasis.Em(def.Name, "Success")), "Success", true, G.Header)
end

local function update()
	if not target then
		return
	end
	if player:GetAttribute("Training") == target then
		stop() -- they are on it
		return
	end
	local rows = workspace:FindFirstChild("Training")
	local model = rows and rows:FindFirstChild(target)
	local busy = player:GetAttribute("Running") or ClientState.MenuOpen() ~= nil
	pointer:Update(not busy and model and model.PrimaryPart or nil, G.Marker)
end

function TreadmillGuideController.Start()
	pointer = GuidePointer.new("TreadGuide")
	ClientState.On("RebirthDone", begin)
	RunService.RenderStepped:Connect(update)
end

return TreadmillGuideController
