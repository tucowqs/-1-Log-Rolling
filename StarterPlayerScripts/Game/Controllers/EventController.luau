--[[
	EventController — the event countdown sign over the boards of the local player's world (EventConfig): "HALLOWEEN EVENT IN
	2D 14H" in the pack's 3D text, ticking every second, then "... IS LIVE!" until Ends, then hidden.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Config = require(ReplicatedStorage.Shared.Config.EventConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local WorldLabel = require(ReplicatedStorage.Shared.Modules.WorldLabel)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)

local EventController = {}

local player = Players.LocalPlayer

local function span(seconds: number): string
	local days, hours, minutes = seconds // 86400, seconds % 86400 // 3600, seconds % 3600 // 60
	return if days > 0 then ("%dD %dH"):format(days, hours) else ("%dH %dM"):format(hours, minutes)
end

function EventController.Start()
	local anchor = Ui.Make("Part", { Name = "EventSign", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.one, Parent = workspace })
	local gui = Ui.Make("BillboardGui", { Name = "EventSign", Adornee = anchor, LightInfluence = 0, MaxDistance = 500, ResetOnSpawn = false })
	WorldLabel.Apply(gui, Config.Billboard)
	local label = UiPack.Get("StatText")
	label.Size, label.Position, label.AnchorPoint, label.Parent = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), gui
	for _, layer in { label, label:FindFirstChild("Color") } do
		layer.TextXAlignment = Enum.TextXAlignment.Center
	end
	UiPack.TextGradient(label, Config.Text.Gradient)
	gui.Parent = player:WaitForChild("PlayerGui")
	local function place()
		anchor.Position = BalanceConfig.Track.Origin + Worlds.Offset(Worlds.Of(player)) + Config.Pos
	end
	ClientState.On("World", place)
	place()
	task.spawn(function()
		while true do
			local now = os.time()
			gui.Enabled = now < Config.Ends
			if now < Config.At then
				UiPack.Text(label, Config.Text.Countdown:format(Config.Name, span(Config.At - now)))
			else
				UiPack.Text(label, Config.Text.Live:format(Config.Name))
			end
			task.wait(1)
		end
	end)
end

return EventController
