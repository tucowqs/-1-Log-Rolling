--[[
	GiftService — gifts (GiftConfig). GiftPick { Key, UserId } remembers who the buyer's next gift of Key is for; the
	"Gift" grant kind (ShopMath gift items, receipts for ShopConfig Gift product ids) then grants the target item to that
	player through ShopService.GrantItem (the same grant a normal purchase runs), toasting both sides. Nobody picked or the
	recipient gone: the buyer gets it (a paid receipt is never lost).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GiftConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local DataService = require(script.Parent.DataService)
local NotifyService = require(script.Parent.NotifyService)
local ShopService = require(script.Parent.ShopService)

local GiftService = {}

local T = Config.Text
local pending: { [Player]: { [string]: number } } = {} -- buyer -> item key -> recipient UserId

local function pick(player: Player, payload)
	local key = type(payload) == "table" and payload.Key
	local to = key and ShopMath.GiftOf(key) and Players:GetPlayerByUserId(tonumber(payload.UserId) or 0)
	if to and to ~= player then
		pending[player] = pending[player] or {}
		pending[player][key] = to.UserId
	end
end

local function grant(buyer: Player, buyerData, item): string
	local target = ShopMath.Items[item.Target]
	local id = (pending[buyer] or {})[item.Target]
	local to = id and Players:GetPlayerByUserId(id)
	local toData = to and DataService.Get(to)
	if not toData then
		if id then
			NotifyService.Send(buyer, T.Fallback:format("They", target.Def.Name), "Info")
		end
		return ShopService.GrantItem(buyer, buyerData, target.Key)
	end
	pending[buyer][item.Target] = nil
	local text = ShopService.GrantItem(to, toData, target.Key)
	DataService.Changed(to)
	Net.Get("ShopPurchased"):Fire(to, { Key = target.Key })
	NotifyService.Send(to, T.Received:format(buyer.DisplayName, text), "Success")
	return T.Sent:format(target.Def.Name, to.DisplayName)
end

function GiftService.Start()
	ShopService.RegisterGrant("Gift", grant)
	Net.Get("GiftPick"):Connect(pick)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return GiftService
