--[[
	ChestService — the free group chest (ChestConfig). ChestClaim {}: in the group (or GroupId 0) and Cooldown passed since
	data.ChestAt -> pays Reward (MonetizeService.Bundle). The next claim time is the attribute "ChestReadyAt" (server time) for
	the billboard's countdown.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ChestConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local DataService = require(script.Parent.DataService)
local MonetizeService = require(script.Parent.MonetizeService)
local NotifyService = require(script.Parent.NotifyService)

local ChestService = {}

local T = Config.Text

local function readyAt(data): number
	return (data.ChestAt or 0) + Config.Cooldown
end

local function inGroup(player: Player): boolean
	if Config.GroupId == 0 then
		return true
	end
	local ok, result = pcall(player.IsInGroup, player, Config.GroupId)
	return ok and result
end

local function claim(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local left = readyAt(data) - os.time()
	if left > 0 then
		return NotifyService.Send(player, T.NotYet:format(NumberFormat.Clock(left)), "Error")
	end
	if not inGroup(player) then
		return NotifyService.Send(player, T.NeedGroup, "Error")
	end
	data.ChestAt = os.time()
	player:SetAttribute("ChestReadyAt", workspace:GetServerTimeNow() + Config.Cooldown)
	NotifyService.Send(player, T.Claimed:format(Em(MonetizeService.Bundle(player, data, Config.Reward), "Success")), "Success")
end

function ChestService.Start()
	DataService.OnLoaded(function(player, data)
		player:SetAttribute("ChestReadyAt", workspace:GetServerTimeNow() + math.max(0, readyAt(data) - os.time()))
	end)
	Net.Get("ChestClaim"):Connect(claim)
end

return ChestService
