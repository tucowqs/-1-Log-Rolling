--[[
	BoostMath — the one source of truth for the boost multipliers (BoostConfig), read from player attributes so the
	server (Progress / RollService payouts) and the client (HUD multiplier label) compute the same number.
	  BoostMath.Potion(player, kind) -> 1 or the potion's Mult while it runs (attribute <kind>BoostUntil > server time)
	  BoostMath.Speed(player)        -> the Speed-gain multiplier from passes, the Speed potion, friends and the trail
	  BoostMath.Wins(player)         -> the Wins-payout multiplier from passes, the Wins potion and friends
	  BoostMath.Left(player, kind)   -> seconds the potion still runs (0 = off)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BoostConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local BoostMath = {}

function BoostMath.Left(player: Player, kind: string): number
	local until_ = player:GetAttribute(Config.Potions[kind].Attribute) or 0
	return math.max(0, until_ - workspace:GetServerTimeNow())
end

function BoostMath.Potion(player: Player, kind: string): number
	return if BoostMath.Left(player, kind) > 0 then Config.Potions[kind].Mult else 1
end

local function passes(player: Player, kind: string): number
	local mult = 1
	for _, key in Config.Passes[kind] do
		if player:GetAttribute(ShopConfig.Passes[key].Attribute) == true then
			mult *= Config.PassMult
		end
	end
	return mult
end

function BoostMath.Speed(player: Player): number
	local extra = (player:GetAttribute(Config.Friends.Attribute) or 0) + (player:GetAttribute(Config.TrailAttribute) or 0)
	return passes(player, "Speed") * BoostMath.Potion(player, "Speed") * (1 + extra)
end

function BoostMath.Wins(player: Player): number
	return passes(player, "Wins") * BoostMath.Potion(player, "Wins") * (1 + (player:GetAttribute(Config.Friends.Attribute) or 0))
end

return BoostMath
