--[[
	SpeedLabelController — the "100 Speed" readout in the hand-built bottom HUD (StarterGui.Main.Bottom.MultFrame.Speed.Text;
	like every hand-built label it has a "Color" child that mirrors the text). It follows the player's "Speed" attribute, the
	same value the level bar counts as XP.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local BoostMath = require(ReplicatedStorage.Shared.Modules.BoostMath)
local PetMath = require(ReplicatedStorage.Shared.Modules.PetMath)

local SpeedLabelController = {}

local label: TextLabel?
local multLabel: TextLabel?

-- Where the gain popups fly to (the label's screen-space centre), and the little scale bump when one lands.
function SpeedLabelController.Target(): Vector2?
	return if label and label.Parent then label.AbsolutePosition + label.AbsoluteSize / 2 else nil
end

function SpeedLabelController.Bump()
	local frame = label and label.Parent
	if not frame then
		return
	end
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	scale.Scale = 1
	local up = TweenService:Create(scale, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.22 })
	up.Completed:Once(function()
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	up:Play()
end

function SpeedLabelController.Start()
	local player = Players.LocalPlayer
	label = player:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("Bottom"):WaitForChild("MultFrame"):WaitForChild("Speed"):WaitForChild("Text")
	multLabel = label.Parent.Parent.Mult.Text
	local function setBoth(target: TextLabel, text: string)
		target.Text = text
		local color = target:FindFirstChild("Color")
		if color then
			color.Text = text
		end
	end
	local function refresh()
		local text = `{NumberFormat.Abbreviate(math.floor(player:GetAttribute("Speed") or 0))} Speed`
		setBoth(label, text)
	end
	local function refreshMult()
		-- rebirths x (1 + equipped pets) x boosts (passes, potion, friends, trail: BoostMath)
		local total = PetMath.Total(player:GetAttribute("Rebirths") or 0, player:GetAttribute("PetBonus") or 0) * BoostMath.Speed(player)
		setBoth(multLabel, Config.Text.Mult:format(if total < 100 then PetMath.Format(total) else NumberFormat.Abbreviate(total)))
	end
	player:GetAttributeChangedSignal("Speed"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refreshMult)
	player:GetAttributeChangedSignal("PetBonus"):Connect(refreshMult)
	for _, name in { "PassSpeed2x", "SpeedBoostUntil", "FriendBoost", "TrailBoost" } do
		player:GetAttributeChangedSignal(name):Connect(refreshMult)
	end
	task.spawn(function() -- the potion running out changes nothing replicated: re-check now and then
		while true do
			task.wait(2)
			refreshMult()
		end
	end)
	refresh()
	refreshMult()
end

return SpeedLabelController
