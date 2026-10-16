--[[
	PurchaseService — the one place in-game currency is spent. Charge() validates and deducts atomically
	(no yields), logs the analytics sink, and tells the player why a purchase failed. The owning system
	applies the result (an upgrade tier, a slot).
	  PurchaseService.Charge(player, cost, what, quiet?) -> bool
	quiet: skip the "purchased!" toast when the screen already shows the result (a card that updates and
	bounces). A failed purchase always says what's missing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopConfig)
local DataConfig = require(ReplicatedStorage.Shared.Config.DataConfig)
local Em = require(ReplicatedStorage.Shared.Modules.Emphasis).Em
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local DataService = require(script.Parent.DataService)
local FunnelService = require(script.Parent.FunnelService)
local NotifyService = require(script.Parent.NotifyService)

local PurchaseService = {}

function PurchaseService.Charge(player: Player, cost: number, what: string, quiet: boolean?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if not DataService.Spend(player, cost) then
		local missing = NumberFormat.Abbreviate(cost - data[DataConfig.Currency])
		NotifyService.Send(player, Config.NotEnough:format(Em(missing, "Error"), Em(what)), "Error")
		return false
	end
	FunnelService.Economy(player, "Sink", cost, "Shop", what)
	if not quiet then
		NotifyService.Send(player, Config.Purchased:format(Em(what, "Success")), "Success")
	end
	return true
end

function PurchaseService.Start() end

return PurchaseService
