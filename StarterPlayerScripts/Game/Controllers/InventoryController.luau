--[[
	InventoryController — the "Items" window (menu "Inventory", PackViews/ListView): every potion kind with its count and
	time left (BoostConfig; USE fires UsePotion), then every owned log (BalanceConfig.Logs; EQUIP fires EquipLog, so the
	limited Reaper Relic and logs far from the pads can be equipped anywhere). Draws ClientState.Data only.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local BoostConfig = require(ReplicatedStorage.Shared.Config.BoostConfig)
local BoostMath = require(ReplicatedStorage.Shared.Modules.BoostMath)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local ListView = require(ReplicatedStorage.Shared.Modules.PackViews.ListView)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Worlds = require(ReplicatedStorage.Shared.Modules.Worlds)
local ClientState = require(script.Parent.Parent.State.ClientState)

local InventoryController = {}

local MENU = "Inventory"
local player = Players.LocalPlayer
local view

local function potionRows(rows)
	local potions = ClientState.Data.Potions or {}
	for order, kind in BoostConfig.PotionOrder do
		local def, count = BoostConfig.Potions[kind], potions[kind] or 0
		local left = BoostMath.Left(player, kind)
		local text = `x{def.Mult} for {def.Minutes} min\nYou have {count}` .. (if left > 0 then `  ({NumberFormat.Clock(left)} left)` else "")
		table.insert(rows, { Key = "Potion" .. kind, Order = order, Title = def.Name, Text = text, Icon = IconPick.Image(def.Icon),
			Button = if count > 0 then "USE" else "NONE", Color = if count > 0 then "Green" else "Gray", OnPress = function()
				if count > 0 then
					Net.Get("UsePotion"):Fire({ Kind = kind })
				end
			end })
	end
end

local function logRows(rows)
	local owned, equipped = ClientState.Data.Logs or {}, ClientState.Data.Equipped
	for index, log in BalanceConfig.Logs do
		if owned[log.Id] then
			local on = equipped == log.Id
			table.insert(rows, { Key = "Log" .. log.Id, Order = 100 + index, Title = log.Name,
				Text = `+{NumberFormat.Abbreviate(Curves.LogMult(log.Id, owned))} Speed per hit\nLasts {math.floor(Curves.Life(log, Worlds.Of(player)) + 0.5)}s here`,
				Art = { Models = { { Path = "Logs." .. log.Id } }, Spin = "Turn", Rays = log.Rays },
				Button = if on then "EQUIPPED" else "EQUIP", Color = if on then "Blue" else "Green", OnPress = function()
					if not on then
						Net.Get("EquipLog"):Fire({ Id = log.Id })
					end
				end })
		end
	end
end

local function refresh()
	local rows = {}
	potionRows(rows)
	logRows(rows)
	view:Set(rows)
end

function InventoryController.Start()
	view = ListView.new(MENU, { Window = { OnClose = ClientState.CloseMenu } })
	ClientState.RegisterMenu(MENU, function()
		refresh()
		view:Open()
	end, function()
		view:Close()
	end)
	ClientState.On("Data", function()
		if ClientState.MenuOpen() == MENU then
			refresh()
		end
	end)
	task.spawn(function() -- potion timers tick while the window is open
		while true do
			task.wait(1)
			if ClientState.MenuOpen() == MENU then
				refresh()
			end
		end
	end)
end

return InventoryController
