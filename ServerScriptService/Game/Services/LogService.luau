--[[
	LogService — buying and equipping logs. The client sends only a log id; price, ownership and the Wins balance are
	all checked here (DataService.Spend never yields, so purchases can't race). Pedestals near spawn (LogPadService) call LogService.Touch. Owned logs live in data.Logs[id],
	the equipped one in data.Equipped; the client sees both through the snapshot. A log can't be changed mid-run.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

local LogService = {}

local function logFrom(payload)
	return typeof(payload) == "table" and typeof(payload.Id) == "string" and Curves.LogById[payload.Id] or nil
end

local function buy(player: Player, payload)
	local log, data = logFrom(payload), DataService.Get(player)
	if not log or not data or data.Logs[log.Id] then
		return
	end
	if player:GetAttribute("Running") then
		return
	end
	if not DataService.Spend(player, log.Price) then
		NotifyService.Send(player, `Need {NumberFormat.Commas(log.Price)} Wins for the {log.Name}!`, "Error")
		return
	end
	data.Logs[log.Id] = true
	data.Equipped = log.Id
	DataService.Changed(player)
	DataService.Sync(player)
	Net.Get("LogBought"):Fire(player, { Id = log.Id })
	NotifyService.Send(player, `Bought and equipped the {log.Name}!`, "Success") -- the Success toast plays the Purchase sound
end

local function equip(player: Player, payload)
	local log, data = logFrom(payload), DataService.Get(player)
	if not log or not data or not data.Logs[log.Id] or player:GetAttribute("Running") then
		return
	end
	data.Equipped = log.Id
	DataService.Changed(player)
	DataService.Sync(player)
end

-- Touching a pedestal: buy the log if it isn't owned yet (needs the Wins), else equip it.
function LogService.Touch(player: Player, id: string)
	local log, data = Curves.LogById[id], DataService.Get(player)
	if not log or not data or data.Equipped == id or player:GetAttribute("Running") then
		return
	end
	if data.Logs[id] then
		equip(player, { Id = id })
		NotifyService.Send(player, `Equipped the {log.Name}!`, "Success")
	else
		buy(player, { Id = id })
	end
end

function LogService.Start()
	Net.Get("BuyLog"):Connect(buy)
	Net.Get("EquipLog"):Connect(equip)
end

return LogService
