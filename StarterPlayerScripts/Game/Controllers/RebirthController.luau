--[[
	RebirthController — the Rebirth window (the pack's Rebirth shell via PackViews/RebirthView, menu "Rebirth", opened by the
	Rebirth button in the HUD's left column). It shows the current multiplier, the next one, a progress bar of how many levels
	the player has toward the max level and a REBIRTH button (grey until max level, green when ready). The press only asks the
	server (RebirthService re-checks); "RebirthDone" closes the window, celebrates and is relayed to ClientState for the level bar.
	Numbers and texts: RebirthConfig; maths: RebirthMath.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RebirthView = require(ReplicatedStorage.Shared.Modules.PackViews.RebirthView)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local NotifyController = require(script.Parent.NotifyController)

local RebirthController = {}

local T = Config.Text
local player = Players.LocalPlayer
local view

local function mult(rebirths: number): string
	return "x" .. NumberFormat.Abbreviate(RebirthMath.Mult(rebirths))
end

local function refresh()
	local rebirths, level = player:GetAttribute("Rebirths") or 0, player:GetAttribute("Level") or 1
	local max = RebirthMath.MaxLevel(rebirths)
	local ready = level >= max
	view:Set({
		Now = T.Current, NowValue = mult(rebirths),
		Next = T.Next, NextValue = mult(rebirths + 1),
		Need = T.Need:format(max),
		Desc = if ready then T.Ready:format(NumberFormat.Abbreviate(RebirthMath.Mult(rebirths + 1))) else T.Progress:format(level, max),
		Share = math.clamp(level / max, 0, 1),
		Ready = ready,
		Button = T.Button,
	})
end

local function done(payload)
	ClientState.CloseMenu()
	ClientState.Emit("RebirthDone", payload) -- the level bar resets
	NotifyController.Toast(T.Done:format(payload.Rebirths, NumberFormat.Abbreviate(RebirthMath.Mult(payload.Rebirths))), "Success")
	UiPack.Celebrate.Play(player:WaitForChild("PlayerGui"):WaitForChild("Main"), {})
end

function RebirthController.Start()
	Net.Get("RebirthDone"):Connect(done)
	view = RebirthView.new({ Window = { OnClose = ClientState.CloseMenu }, Icon = IconPick.Image("Speed"), Tile = "Blue", OnRebirth = function()
		Net.Get("Rebirth"):Fire({})
	end })
	ClientState.RegisterMenu(Config.Menu, function()
		refresh()
		view:Open()
	end, function()
		view:Close()
	end)
	for _, attribute in { "Level", "Rebirths" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

return RebirthController
