--[[
	BoostService — potions and the friend boost (BoostConfig; the multipliers themselves are BoostMath, applied where
	Speed is gained (Progress.AddSpeed) and Wins are paid (RollService)).
	  BoostService.Give(player, data, kind, count)   adds potions to data.Potions (shop bundles, codes, chests, gifts)
	  UsePotion { Kind }   drinks one: <kind>BoostUntil = max(now, current end) + Minutes (stacks)
	A running potion's time is saved as data.BoostLeft[kind] seconds on leave and restarts on join, so it only ticks
	in game. FriendBoost = PerFriend x Roblox friends in this server (capped), recomputed on every join / leave.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BoostConfig)
local BoostMath = require(ReplicatedStorage.Shared.Modules.BoostMath)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)

local BoostService = {}

local friendCache: { [string]: boolean } = {} -- "a:b" (smaller id first) -> friends

local function setUntil(player: Player, kind: string, seconds: number)
	local now = workspace:GetServerTimeNow()
	player:SetAttribute(Config.Potions[kind].Attribute, if seconds > 0 then now + seconds else nil)
end

function BoostService.Give(player: Player, data, kind: string, count: number)
	assert(Config.Potions[kind], "unknown potion " .. kind)
	data.Potions[kind] = (data.Potions[kind] or 0) + count
	DataService.Sync(player)
end

local function use(player: Player, payload)
	local data = DataService.Get(player)
	local kind = type(payload) == "table" and payload.Kind
	local def = data and Config.Potions[kind]
	if not def then
		return
	end
	if (data.Potions[kind] or 0) < 1 then
		return NotifyService.Send(player, Config.Text.None:format(def.Name), "Error")
	end
	data.Potions[kind] -= 1
	setUntil(player, kind, BoostMath.Left(player, kind) + def.Minutes * 60)
	DataService.Sync(player)
	NotifyService.Send(player, Config.Text.Used:format(Em(def.Name, "Success"), NumberFormat.Clock(BoostMath.Left(player, kind))), "Success")
end

local function friends(a: Player, b: Player): boolean
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

local function refreshFriends()
	local list = Players:GetPlayers()
	for _, player in list do
		local count = 0
		for _, other in list do
			if other ~= player and other.Parent and friends(player, other) then
				count += 1
			end
		end
		if player.Parent then
			player:SetAttribute(Config.Friends.Attribute, math.min(count * Config.Friends.PerFriend, Config.Friends.Max))
		end
	end
end

function BoostService.Start()
	DataService.AddSnapshot("Potions")
	DataService.OnPrepare(function(_, data)
		data.Potions = data.Potions or {}
		data.BoostLeft = data.BoostLeft or {}
	end)
	DataService.OnLoaded(function(player, data)
		for kind, seconds in data.BoostLeft do
			if Config.Potions[kind] then
				setUntil(player, kind, seconds)
			end
		end
	end)
	DataService.OnLeaving(function(player, data)
		for kind in Config.Potions do
			data.BoostLeft[kind] = BoostMath.Left(player, kind)
		end
	end)
	Net.Get("UsePotion"):Connect(use)
	Players.PlayerAdded:Connect(function()
		task.defer(refreshFriends)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshFriends)
	end)
	task.spawn(refreshFriends)
end

return BoostService
