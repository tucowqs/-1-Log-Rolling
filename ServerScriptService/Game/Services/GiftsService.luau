--[[
	GiftsService — free playtime gifts (GiftsConfig). Each player's session starts on load (attribute "SessionStart", server
	time); GiftClaim { Index } pays gift Index once per session once its Minutes have passed. The claimed list is the player
	attribute "GiftsClaimed" (comma list of indexes) so the client draws CLAIMED without a snapshot.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GiftsConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)
local MonetizeService = require(script.Parent.MonetizeService)
local NotifyService = require(script.Parent.NotifyService)

local GiftsService = {}

local claimed: { [Player]: { [number]: boolean } } = {}

local function claim(player: Player, payload)
	local data = DataService.Get(player)
	local index = type(payload) == "table" and tonumber(payload.Index)
	local gift = index and Config.Gifts[index]
	local mine = claimed[player]
	if not (data and gift and mine) or mine[index] then
		return
	end
	if workspace:GetServerTimeNow() - (player:GetAttribute("SessionStart") or math.huge) < gift.Minutes * 60 - 1 then
		return
	end
	mine[index] = true
	local list = {}
	for i in mine do
		table.insert(list, tostring(i))
	end
	player:SetAttribute("GiftsClaimed", table.concat(list, ","))
	NotifyService.Send(player, Em(MonetizeService.Bundle(player, data, gift.Reward), "Success"), "Success")
end

function GiftsService.Start()
	DataService.OnLoaded(function(player)
		claimed[player] = {}
		player:SetAttribute("SessionStart", workspace:GetServerTimeNow())
		player:SetAttribute("GiftsClaimed", "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		claimed[player] = nil
	end)
	Net.Get("GiftClaim"):Connect(claim)
end

return GiftsService
