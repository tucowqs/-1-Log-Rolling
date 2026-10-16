--[[
	HudStatusController — the bottom-right status chips of the HUD (HudConfig.Status): a right-aligned,
	bottom-aligned row in HudController.Group("Status"). Each config chip (UiPack.Chip) shows only while its
	player attribute (a server-time "until" timestamp) is ahead, captioned with the time left; a chip with a
	Menu opens it (on Tab). Game controllers add their own chips (a live event, ...) to HudStatusController.Row().
	Everything reads attributes, so nothing is sent over the network.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.HudConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local ClientState = require(script.Parent.Parent.State.ClientState)
local HudController = require(script.Parent.HudController)

local HudStatusController = {}

local S = Config.Status
local player = Players.LocalPlayer

-- The Status group's right-aligned, bottom-aligned row (LayoutOrder decides the order, right to left by config).
function HudStatusController.Row(): Frame
	local group = HudController.Group("Status")
	if not group:FindFirstChildOfClass("UIListLayout") then
		Ui.Make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(S.Gap, 0),
			Parent = group })
	end
	return group
end

local function chip(order: number, def)
	local gui = UiPack.Chip({ Icon = def.Icon, Gradient = def.Gradient or "Orange", OnClick = def.Menu and function()
		ClientState.OpenMenu(def.Menu, def.Tab)
	end }, { Parent = HudStatusController.Row(), Name = def.Name, Size = def.Size, LayoutOrder = -order })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = gui })
	gui.Visible = false
	return gui
end

function HudStatusController.Start()
	local chips = {}
	for order, def in S.Chips do
		chips[def] = chip(order, def)
	end
	task.spawn(function() -- a loop inside Start would read as a HANGING Start
		while next(chips) do
			local now = workspace:GetServerTimeNow()
			for def, gui in chips do
				local left = (player:GetAttribute(def.Attribute) or 0) - now
				gui.Visible = left > 0
				UiPack.SetLabel(gui, def.Text:format(NumberFormat.Clock(left)))
			end
			task.wait(S.Refresh)
		end
	end)
end

return HudStatusController
